require 'socket'

module Rum
  class Remote
    def initialize(port=Remote.default_port)
      @connection = Connection.new(TCPSocket.open('127.0.0.1', port))
    end

    def eval code
      @connection.dispatch code
      @connection.receive
    end

    def disconnect
      @connection.close
    end

    def self.default_port
      if (port = ENV['RUM_PORT'].to_i) and port.nonzero?
        port
      else
        1994
      end
    end

    module Connection
      module Messaging
        # Assumes message is not larger than 4,3 GB ((2**(4*8) - 1) bytes)
        def dispatch(msg)
          msg.encode! Encoding::UTF_8
          msg.force_encoding Encoding::BINARY
          write([msg.length].pack('N') + msg)
        end
        
        def receive
          if message_size = read(4) # sizeof (N)
            message_size = message_size.unpack('N')[0]	
            read(message_size).force_encoding(Encoding::UTF_8)
          end
        end
      end
      
      def Connection.new(stream)
        stream.extend Messaging
      end
    end
  end
end
