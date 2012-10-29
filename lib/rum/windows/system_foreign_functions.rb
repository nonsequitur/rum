require_relative 'system.so'
# The C-extension defines:
# Rum::System (module methods)
#        enum_windows
#        keybd_event
#        get_console_window
# Rum::System::Window (class instance methods)
#        show
#        exe_path
#        ...
# Rum::System::Desktop (module methods)
#        top
#        right
#        bottom
#        left
# Rum::System::Screen (module methods)
#        width
#        height
# Rum::System::Clipboard (module methods)
#        install_watcher
#        evaluate_watcher

require 'win32/api'
require 'win32/clipboard'

module Rum
  module System
    def self.snake_case str
      str.gsub(/([a-z])([A-Z0-9])/, '\1_\2').downcase
    end

    def self.def_api(function_name, parameters, return_value, rename=nil)
      api = Win32::API.new function_name, parameters, return_value, 'user32'
      define_method(rename || snake_case(function_name)) do |*args|
        api.call *args
      end
    end

    def_api 'FindWindow',          'PP', 'L'
    def_api 'FindWindowEx',        'LLPP', 'L'
    def_api 'SendMessage',         'LLLP', 'L', :send_with_buffer
    def_api 'SendMessage',         'LLLL', 'L'
    def_api 'PostMessage',         'LLLL', 'L'
    def_api 'GetDlgItem',          'LL', 'L'
    def_api 'GetWindowRect',       'LP', 'I'
    def_api 'SetCursorPos',        'LL', 'I'
    def_api 'mouse_event',         'LLLLL', 'V'
    def_api 'IsWindow',            'L', 'L'
    def_api 'IsWindowVisible',     'L', 'L'
    def_api 'SetForegroundWindow', 'L', 'L'

    def_api 'GetWindowLong',       'LI', 'L'
    def_api 'GetForegroundWindow', 'V', 'L'
    def_api 'GetClassName',        'LPI', 'I'
    def_api 'GetWindowText',       'LPI', 'I'
    def_api 'GetWindowTextW',      'LPI', 'I'
    def_api 'ShowWindow',          'LI', 'I'
    def_api 'SetForegroundWindow', 'L', 'I'
    def_api 'IsIconic',            'L', 'L'
    def_api 'IsZoomed',            'L', 'L'
    def_api 'SetWindowPos',        'LLIIIII', 'I'
    def_api 'MoveWindow',          'LIIIIB', 'L'

    ShellExecute = Win32::API.new('ShellExecute', 'LPPPPI', 'L', 'shell32')
    def start command, parameters=0
      command.encode!(Encoding::WINDOWS_1252)
      parameters.encode!(Encoding::WINDOWS_1252) if parameters != 0
      ShellExecute.call(0, 'open', command, parameters, 0, 1)
    end

    WM_COMMAND    = 0x0111
    WM_SYSCOMMAND = 0x0112

    SC_CLOSE    = 0xF060
    SC_RESTORE  = 0xF120;
    SC_MAXIMIZE = 0xF030;
    SC_MINIMIZE = 0xF020;

    WM_GETTEXT = 0x000D
    EM_GETSEL  = 0x00B0
    EM_SETSEL  = 0x00B1
    SW_HIDE             = 0
    SW_SHOWNORMAL       = 1
    SW_NORMAL           = 1
    SW_SHOWMINIMIZED    = 2
    SW_SHOWMAXIMIZED    = 3
    SW_MAXIMIZE         = 3
    SW_SHOWNOACTIVATE   = 4
    SW_SHOW             = 5
    SW_MINIMIZE         = 6
    SW_SHOWMINNOACTIVE  = 7
    SW_SHOWNA           = 8
    SW_RESTORE          = 9
    SW_SHOWDEFAULT      = 10
    SW_FORCEMINIMIZE    = 11
    SW_MAX              = 11

    SWP_NOMOVE     = 2
    SWP_NOSIZE     = 1
    HWND_TOPMOST   = -1
    HWND_NOTOPMOST = -2
    GWL_EXSTYLE    = -20
    WS_EX_TOPMOST  = 8
  end
end

module Win32
  class Clipboard
    def self.get
      self.open
      return '' unless IsClipboardFormatAvailable(UNICODETEXT)
      handle = GetClipboardData(UNICODETEXT)
      clip_data = 0.chr * GlobalSize(handle)
      memcpy(clip_data, handle, clip_data.size)
      clip_data.force_encoding(Encoding::UTF_16LE)
      clip_data.encode!(Encoding::UTF_8, invalid: :replace, replace: '', \
                        universal_newline: true)
      clip_data[ /^[^\0]*/ ]
    ensure
      self.close
    end

    def self.set str
      data = str.encode(Encoding::UTF_16LE, crlf_newline: true)
      data.force_encoding Encoding::BINARY
      set_data(data, UNICODETEXT)
    end

    def self.html_format
      @html_format ||= register_format('HTML Format')
    end

    def self.get_html
      html = html_format
      self.open
      if IsClipboardFormatAvailable(html)
        handle = GetClipboardData(html)
        clip_data = 0.chr * GlobalSize(handle)
        memcpy(clip_data, handle, clip_data.size)
        clip_data.force_encoding(Encoding::UTF_8)
        clip_data = clip_data[ /^[^\0]*/ ]
      end
    ensure
      self.close
    end

    def self.set_html str
      data = str + "\0"
      data.force_encoding Encoding::BINARY
      set_data(data, html_format)
    end
  end
end
