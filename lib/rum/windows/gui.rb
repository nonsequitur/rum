module Rum
  module Gui
    def goto path
      if File.directory? path
        System.start path
      else
        Gui.message "Can't visit a file in Windows Explorer."
      end
    end
    
    def open_file file, line=nil
      System.start file
    end

    private

    def browse_backend url
      System.start url
    end

    module WindowsDialogs
      private
      def alert_backend text, title
        System.message_box text, title
      end
      
      def message_backend text, title, sticky, callback
        alert text, title
      end

      def read_backend text, title, initial_value
        System.input_box text, title, initial_value
      end
    end

    use WindowsDialogs

    module Growl
      Message = 'message'

      private
      
      def message_backend(text, title, sticky, callback)
        unless title
          title = text
          text = nil
        end
        # ruby_gntp raises an error when 'title' is nil or pure whitespace.
        title = 'empty text' if title.to_s.strip.empty?
        if callback
          on_click = lambda { |event| callback.call if event[:callback_result] == "CLICK" }
        end
        
        Growl.client.notify(name: Message, title: title,
                            text: text, sticky: sticky, &on_click)
      end
      
      module_function
      
      def auto_setup
        require 'ruby_gntp'
        @growl = GNTP.new("Rum")
        @growl.register(notifications: [{name: Message, enabled: true}])
        true
      rescue Errno::ECONNREFUSED # Growl not running
        @growl = nil
      end

      def client
        @growl or auto_setup and @growl
      end
    end

    module EmacsInteraction
      private
      
      def interaction(*args)
        emacs = Emacs.window
        return '' unless emacs
        unless (emacs_already_active = emacs.active?)
          old = System.active_window
          emacs.move(400, 400, 800, 300)
          emacs.show
        end
        result = unpack(Emacs.funcall(*args))
        unless emacs_already_active
          wait { old.active? } unless old.show
          emacs.maximize
        end
        result
      end

      def unpack(output)
        # If we don't get a string back something has gone wrong.
        raise 'emacs returned no string: ' << output unless output[0] == ?"
        # The first line contains the status (1 or 0),
        # the second line contains additional output.
        # See telemacs-format-output.
        output = Emacs.unquote(output)
        if output =~ /\n$/
          ''
        else
          output = output.split(/\n/)
          output[1] or (output[0] == '1' ?  true : nil)
        end
      end

      def choose_backend prompt, choices
        prompt = prompt ? Emacs.quote(prompt) : 'nil'
        fn = 'selekt-external-fast'
        result = interaction(fn, prompt, *choices.map { |item| Emacs.quote(item.to_s) })
        choices[result.to_i] if result
      end
    end
  end
end
