require_relative 'system_foreign_functions'

module Rum
  module System
    extend self
    
    def send_key_event key, down
      extended, id = key.id.divmod 2**9
      extended = (extended == 1)
      keybd_event id, down, 0, extended
    end

    def send_keypress key
      send_key_event key, true
      send_key_event key, false
    end

    def active_window_handles
      Enumerator.new(self, :enum_windows)
    end

    def active_windows
      Enumerator.new do |yielder|
        enum_windows { |handle| yielder.yield Window.new(handle) }
      end
    end

    def active_window
      Window.new get_foreground_window
    end
    
    def terminal_window
      Window.new get_console_window
    end

    def spawn_in_terminal(*args)
      if args.delete :close_if_successful
        close_window = '/c'
        # if there's an error, ask for input to keep the shell window alive
        args.concat %w(|| set /p name= Abort)
      else
        close_window = '/k'
      end
      if args.delete(:wait)
        Rum.switch_worker_thread
        wait = '/wait'
      end
      system('start', *wait, 'cmd', close_window, *args)
    end

    # returns a copy
    def c_string obj
      str = obj.to_s + "\0"
      str.encode(Encoding::UTF_16LE) 
    end

    def message_box message, title=''
      message_box_internal(c_string(message), c_string(title))
    end

    def input_box text, title, default_text
      buffer_size = 2048
      buffer = default_text.to_s.encode Encoding::UTF_16LE
      buffer.force_encoding Encoding::BINARY
      if buffer.length >= buffer_size
        buffer << "\0\0"
      else
        buffer << "\0" * (buffer_size - buffer.length)
      end

      length = input_box_internal(c_string(text), c_string(title), buffer)
      if length == 0
        ''
      else
        result = buffer[0, length*2]
        result.force_encoding(Encoding::UTF_16LE).encode(Encoding::UTF_8)
      end
    end

    def get_selection
      Clipboard.preserve { Clipboard.get_selection }
    end

    class Window
      include System
      
      attr_reader :handle
      
      def initialize(handle)
        @handle = handle
      end

      def == other
        return false unless other.respond_to? :handle
        @handle == other.handle
      end
      
      def active?
        self.handle == get_foreground_window
      end

      def close
        post_message @handle, WM_SYSCOMMAND, SC_CLOSE, 0
      end

      def hide
        show_window(@handle, SW_HIDE)
      end

      def zoomed?
        is_zoomed(@handle) == 1 ? true : false
      end

      def toggle_maximized
        zoomed? ? restore : maximize
      end

      def maximize
        post_message @handle, WM_SYSCOMMAND, SC_MAXIMIZE, 0
      end
      
      def minimize
        post_message @handle, WM_SYSCOMMAND, SC_MINIMIZE, 0
      end

      def restore
        post_message @handle, WM_SYSCOMMAND, SC_RESTORE, 0
      end

      def file_dialog?
        class_name == '#32770'
      end

      def office_file_dialog?
        class_name =~ /^bosa_sdm/
      end

      def toggle_always_on_top
        window_style = get_window_long(@handle, GWL_EXSTYLE)
        return if window_style == 0
        topmost_or_not = if (window_style & WS_EX_TOPMOST == WS_EX_TOPMOST)
                           HWND_NOTOPMOST
                         else
                           HWND_TOPMOST
                         end
        set_window_pos(@handle, topmost_or_not, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE)
      end

      def move(x, y, width, height)
        restore if zoomed?
        move_window(@handle, x, y, width, height, 1)
      end
      
      def title(max_length = 1024)
        buffer = "\0" * (max_length * 2)
        length = get_window_text_w(@handle, buffer, buffer.length)
        result = (length == 0 ? '' : buffer[0..(length * 2 - 1)])
        result.force_encoding(Encoding::UTF_16LE)
        result.encode(Encoding::UTF_8, invalid: :replace)
      end
      
      def class_name(max_length = 2048)
        buffer = "\0" * max_length
        length = get_class_name(@handle, buffer, buffer.length)
        length == 0 ? '' : buffer[0..length - 1]
      end
      
      def text(max_length = 2048)
        buffer = '\0' * max_length
        length = send_with_buffer @handle, WM_GETTEXT, buffer.length, buffer
        length == 0 ? '' : buffer[0..length - 1]
      end

      def child(id)
        result = case id
                 when String
                   by_title = find_window_ex @handle, 0, nil, id.gsub('_', '&')
                   by_class = find_window_ex @handle, 0, id, nil
                   by_title > 0 ? by_title : by_class
                 when Fixnum
                   get_dlg_item @handle, id
                 else
                   0
                 end
        
        raise "Control '#{id}' not found" if result == 0
        Window.new result
      end

      def kill_task
        system("taskkill /F /IM #{exe_name}.exe")
      end
      
      def report
        "Title: #{title}\nClass: #{class_name}"
      end

      def self.[] arg, class_name=nil
        if arg.is_a? Hash
          WindowMatcher.new(arg[:title], arg[:class_name])
        else
          WindowMatcher.new(arg, class_name)
        end
      end
    end

    class WindowMatcher
      include System
      attr_reader :specs
      
      def initialize title=nil, class_name=nil
        @specs = { title: title, class_name: class_name }
        raise 'No specifications given.' unless @specs.values.any?
        @specs.each do |spec, value|
          if value.is_a? Regexp
            @specs[spec] = Regexp.new(value.source, Regexp::IGNORECASE)
          end
        end
      end

      def comparison_method obj
        if obj.is_a? Regexp then :=~ else :== end
      end
      
      def matches? window
        @specs.all? do |spec, value|
          not value or value.send(comparison_method(value), window.send(spec))
        end
      end

      def active?
        matches? active_window
      end

      def to_matcher
        self
      end

      def [] spec
        @specs[spec]
      end

      def find
        if @specs.values.any? { |spec| spec.is_a? Regexp }
          active_windows.detect { |window| matches? window }
        else
          handle = find_window @specs[:class_name], @specs[:title]
          Window.new(handle) unless handle == 0
        end
      end
    end
    
    module Clipboard
      extend self
      
      def get
        Win32::Clipboard.get
      end
    
      def set str
        Win32::Clipboard.set str
      end

      def preserve
        old_content = get
        yield
      ensure
        set old_content
      end

      # def copy
      #   watcher = install_watcher
      #   Keyboard.type '(ctrl c)'
      #   evaluate_watcher(watcher, 400) # Timeout: 400 msec
      # end

      def wait_for_change
        watcher = install_watcher
        begin
          yield
        ensure
          result = evaluate_watcher(watcher, 400)
        end
        result
      end

      def copy
        wait_for_change { Keyboard.type '(ctrl c)' }
      end

      def paste
        Keyboard.type '(ctrl v)'
      end
      
      def get_selection
        Clipboard.get if Clipboard.copy
      end

      def append
        clip = Clipboard.get
        if (selection = get_selection)
          clip << "\n" << selection
        end
      ensure
        Clipboard.set clip
      end
    end
  end
end

