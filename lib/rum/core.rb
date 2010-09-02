require 'rum/hotkey_core'
require 'rum/help'
require 'rum/gui'
require 'rum/barrel'
require 'thread'

case RUBY_DESCRIPTION
when /mswin|mingw/ then require 'rum/windows'
when /MacRuby/     then require 'rum/mac'
else raise "Platform not yet supported: #{RUBY_PLATFORM}"
end

Encoding.default_external = Encoding::UTF_8

module Rum
  autoload :Server, 'rum/server'
  
  class << self
    attr_writer :layout
    attr_reader :hotkey_set, :hotkey_processor, \
                :work_queue, :worker_thread

    def layout
      @layout ||= Layouts.default_layout
    end
    
    def setup
      return if setup_completed?
      @hotkey_set = HotkeySet.new(layout)
      @hotkey_processor = HotkeyProcessor.new(@hotkey_set)
    end

    def setup_completed?
      !!@hotkey_set
    end

    def start
      setup
      Thread.abort_on_exception = true
      @work_queue = Action.work_queue = Queue.new
      @worker_thread = start_worker_thread(@work_queue)

      KeyboardHook.start &@hotkey_processor.method(:process_event)
    end

    def stop
      KeyboardHook.stop
    end

    def start_worker_thread(queue)
      Thread.new do
        while action = queue.deq
          begin
            action.call
          rescue => exception
            display_exception exception
          end
        end
      end
    end

    def display_exception(exception)
      error_message = ["#{exception.class}:", exception,
                       '', *exception.backtrace].join("\n")

      file, line = parse_stack_frame(exception.backtrace.first)
      if file
        file = File.expand_path(file)
        callback = lambda do
          Gui.message("Click here to jump to the last error:\n\n#{file}:#{line}") do
            Gui.message error_message, :sticky
            Gui.open_file file, line
          end
        end
      end
      
      Gui.message error_message, :sticky, &callback
    end

    def switch_worker_thread
      return unless Thread.current == @worker_thread
      old = @work_queue
      new = @work_queue = Action.work_queue = Queue.new
      new.enq(old.deq) until old.length == 0
      @worker_thread = start_worker_thread(new)
      old.enq nil # Signal the worker thread to stop
    end
  end

  WorkingDir = Dir.pwd
  
  def restart
    Dir.chdir WorkingDir
    if Thread.current == Rum::Server.thread
      Thread.new do
        sleep 0.01 # Allow server to respond. Slightly hacky.
        restart_platform_specific
      end
      true
    else
      restart_platform_specific
    end
  end
  
  def show
    System.terminal_window.show
  end

  def hide
    System.terminal_window.hide
  end
end
