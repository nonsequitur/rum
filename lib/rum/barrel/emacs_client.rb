require 'socket'

# Ruby implementation of
# emacs_source/lib-src/emacsclient.c

class EmacsClient
  def eval(elisp)
    socket = connect
    socket.puts "-eval #{quote(elisp)}"
    result = unquote(socket.read)
    socket.close
    format(result)
  end

  def format(str)
    str[/.*? (.*)/, 1]
  end

  def quote str
    r = str.gsub(/&|^-/, '&\&').gsub("\n", '&n').gsub(' ', '&_')
  end

  def unquote str
    str.gsub(/&(.)/) do
      case $1
      when 'n'; "\n"
      when '_'; ' '
      else $1
      end
    end
  end

  if RUBY_PLATFORM =~ /mswin|mingw/
    attr_accessor :ip, :port, :auth_string

    def initialize
      @server_file = File.join(ENV['HOME'], '.emacs.d', 'server', 'server')
      read_config
    end
    
    def read_config
      @server_active = File.exists? @server_file
      return unless @server_active
      lines = File.readlines(@server_file)
      @ip, @port = lines.first.match(/(.*?):(\d+)/).captures
      @auth_string = lines.last
    end

    def create_socket
      return unless @server_active
      begin
      	socket = TCPSocket.open(@ip, @port)
        socket.write "-auth #@auth_string "
        socket
      rescue SystemCallError
      end
    end

    def connect
      create_socket or (read_config and create_socket) \
      or raise "Can't connect to Emacs Server."
    end
  else # Unix
    def initialize
      @socket_path = File.join(ENV['TMPDIR'], "emacs#{Process::Sys.geteuid}", 'server')
    end

    def connect
      UNIXSocket.open(@socket_path)
    rescue SystemCallError => error
      raise "Can't connect to Emacs Server\n" << error.message
    end
  end
end
