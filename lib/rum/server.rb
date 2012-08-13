require 'rum/remote'

module Rum
  module Server
    module_function

    # This makes it easier for code to check if it runs inside the server thread.
    def thread
      @thread
    end

    def start
      return if @thread
      @thread = Thread.new do
        @server = TCPServer.new('127.0.0.1', Remote.default_port)
        puts "Server started."
        begin
          loop do
            @connection = Remote::Connection.new(@server.accept)
            handle(@connection)
            @connection.close
          end
        ensure # clean up when thread gets killed
          close_connections
        end
      end
    end

    # Temporary hack.
    # MacRuby crashes on the ensure clause above when
    # the server thread is killed.
    # This function allows for manually closing the connections.
    def close_connections
      [@server, @connection].compact.each { |e| e.close unless e.closed? }
    end

    def stop
      if @thread
        @thread.kill
        # Kill can return before the thread has finished execution. A Ruby bug?
        @thread.join
        @thread = nil
      end
    end

    EvalBinding = TOPLEVEL_BINDING

    def handle(connection)
      return nil unless message = connection.receive
      result = begin
                 eval(message, EvalBinding).inspect
               rescue Exception => exception
                 error_message(exception)
               end
      connection.dispatch(result)
    rescue SystemCallError # connection errors
    end

    def error_message(exception)
      # Hide the internals from the backtrace
      backtrace = exception.backtrace.reject { |frame| frame =~ /^#{__FILE__}/ }
      msg = ["Rum-Server: Evaluation Error."]
      msg << "#{exception.class}: #{exception}"
      msg += backtrace
      msg.join "\n"
    end

    module IRBCompletion
      Glue = 'binding = Rum::Server::EvalBinding
              workspace = Struct.new(:binding).new(binding)
              context = Struct.new(:workspace).new(workspace)
              @CONF = { MAIN_CONTEXT: context }

              def IRB.conf
                @CONF
              end'

      def self.setup
        unless defined? IRB
          # Since version 0.7, MacRuby ships with an incompatible IRB
          # distribution called dietirb. Mac Rum includes a partial
          # copy of the original IRB.
          require Rum::Platform == :mac ? 'rum/mac/irb/completion' : 'irb/completion'
          IRB.module_eval(Glue)
        end
      end
    end

    IRBCompletion.setup
  end
end
