module Rum
  module System
    extend self

    def applescript src
      pointer = Pointer.new_with_type("@")
      as = NSAppleScript.alloc.initWithSource(src)
      as.executeAndReturnError(pointer)
    end

    def start *args
      system 'open', *args
    end

    def escape_shell_word str
      if str.empty? or %r{\A[0-9A-Za-z+,./:=@_-]+\z} =~ str
        str
      else
        result = ''
        str.scan(/('+)|[^']+/) {
          if $1
            result << %q{\'} * $1.length
          else
            result << "'#{$&}'"
          end
        }
        result
      end
    end

    def applescript_quote_string str
      str.gsub!('\\', '\\\\\\\\')
      str.gsub!('"', '\\"')
      '"' << str << '"'
    end

    def spawn_in_terminal(*args)
      close = args.delete :close_if_successful
      command = args.map { |arg| escape_shell_word(arg) }.join(' ')
      command << ';[ $? -eq 0 ] && exit' if close
      command = applescript_quote_string(command)
      applescript 'tell application "Terminal" to do script ' + command
    end
  end
end
