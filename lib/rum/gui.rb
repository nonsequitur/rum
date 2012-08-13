module Rum
  module Gui
    extend self

    def self.use gui_module, *methods
      if methods.empty?
        include gui_module
        extend self
        gui_module.auto_setup if gui_module.respond_to? :auto_setup
      else
        methods.each do |method|
          method = gui_module.method(method)
          define_method(method.name) do |*args, &block|
            method.call(*args, &block)
          end
        end
      end
    end

    def message text, *args, &callback
      sticky = !!args.delete(:sticky)
      title  = args.first
      message_backend(text, title, sticky, callback)
    end

    def alert text, title=nil
      Rum.switch_worker_thread
      title ||= 'Rum'
      alert_backend(text, title)
    end

    def read(text='', args=nil)
      Rum.switch_worker_thread
      if text.is_a? Hash
        args = text
        text = nil
      end
      if args
        default = args[:default]
        title   = args[:title]
      end
      read_backend(text, (title or 'Rum'), default)
    end

    def choose prompt=nil, choices
      Rum.switch_worker_thread
      choose_backend(prompt, choices)
    end

    def browse url
      url = 'http://' + url unless url =~ /^\w+:\/\//
      browse_backend url
    end

    module CocoaDialog
      private

      def alert_backend prompt, title
        result = dialog('ok-msgbox', '--text', prompt.to_s, '--title', title.to_s)
        result.first == '1'
      end

      def message_backend text, title, sticky, callback
        alert text, title
      end

      def read_backend text, title, default
        text    = ['--informative-text', text.to_s] if text
        title   = ['--title', title.to_s]   if title
        default = ['--text',  default.to_s] if default
        result  = dialog('standard-inputbox', *text, *default, *title)
        result.shift == '1' ? result.join(' ') : ''
      end

      def choose_backend prompt, choices
        prompt = ['--text', prompt.to_s] if prompt
        result = dialog('standard-dropdown', '--items', *choices.map(&:to_s), *prompt)
        choices[result[1].to_i] if result.first == '1'
      end

      def dialog *args
        IO.popen([@@binary, *args]) { |p| p.read }.split
      end

      def self.setup binary=nil
        unless binary
          raise ArgumentError, 'Please provide a path to the CocoaDialog binary.'
        end
        @@binary = binary
      end
    end
  end
end
