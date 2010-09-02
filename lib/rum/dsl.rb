include Rum
include System
include Keyboard

module Rum
  class Action
    def register
      Rum.hotkey_set.register(self)
    end
    
    def unregister
      Rum.hotkey_set.unregister(self)
    end
  end

  class FileLocation
    def initialize(file, line)
      @file = file
      @line = line
    end

    def self.from_stack_frame(frame)
      file, line = Rum.parse_stack_frame(frame)
      if file
        file = File.expand_path(file) if File.dirname(file) == '.'
        new(file, line)
      end
    end

    def show
      Gui.open_file(@file, @line)
      true
    end
  end
end

module GuiMixin
  # Delegating to Gui instead of directly including Gui avoids dealing
  # with module hierarchy corner cases that appear when other modules
  # are later dynamically included into Gui via Gui.use.
  [:message, :alert, :read, :choose, :open_file, :browse, :goto].each do |method_name|
    define_method(method_name) do |*args, &block|
      Gui.send(method_name, *args, &block)
    end
    private method_name
  end
end
include GuiMixin

def wait(timeout=5, interval=0.01)
  start = Time.new
  loop do
    return true if yield
    sleep interval
    return false if Time.new - start > timeout
  end
end

class String
  def do(*options, &action)
    repeated = true
    options.reject! do |option|
      case option
      when :no_repeat
        repeated = false
      when String
        action = lambda { Keyboard.type option }
      end
    end
    if (condition = options.first) and condition.respond_to? :to_matcher
      matcher = condition.to_matcher
      condition = lambda { matcher.active? }
    end
    location = FileLocation.from_stack_frame(caller.first)
    Rum.hotkey_set.add_hotkey(self, action, condition, repeated, location)
  end

  def unregister
    Rum.hotkey_set.remove_hotkey(self)
  end

  def translate condition=nil, to
    if condition and condition.respond_to? :to_matcher
      matcher = condition.to_matcher
      condition = lambda { matcher.active? }
    end
    Rum.hotkey_set.add_translation(self, to, condition,
                                   FileLocation.from_stack_frame(caller.first))
  end
end

class String
  # Prepare a special version of #do that is only active when the user
  # calls #do for the first time.
  # After running Rum.setup it calls and restores the default version of #do.
  alias :old_do :do
  def do(*args, &block)
    Rum.setup
    String.class_eval do
      alias :do :old_do
      undef_method :old_do
    end
    action = self.do(*args, &block)
    # The original location has been invalidated by the
    # extra call to #do. Replace it.
    action.location = FileLocation.from_stack_frame(caller.first)
    action
  end
end
