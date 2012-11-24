framework "ApplicationServices"
framework "#{File.dirname(__FILE__)}/keyboard_hook/KeyboardHook.framework"
framework 'Cocoa'

module KeyboardHook
  def self.start &block
    @tap = EventTap.new
    @tap.on_event &block
    NSApplication.sharedApplication.run()
  end

  def self.stop
    # Todo: cleanup, unregister hook
    NSApplication.sharedApplication.terminate(nil)
  end
end

class EventTap
  def handleKeyEvent(event)
    event if @proc.call(event)
  end

  def on_event(&proc)
    @proc = proc
  end
end

class Event
  def set_event_source(source)
    CGEventSetSource(eventRef, source)
  end

  def set_keycode(code)
    set_integer_value_field(KCGKeyboardEventKeycode, code)
  end

  def down?
    down != 0
  end

  def keycode
    get_integer_value_field(KCGKeyboardEventKeycode)
  end

  def id
    get_integer_value_field(KCGKeyboardEventKeycode)
  end

  def to_s
    "#{down? ? 'Down' : 'Up'}: Id #{id}"
  end

  def set_integer_value_field(field, value)
    CGEventSetIntegerValueField(eventRef, field, value)
  end

  def get_integer_value_field(field)
    CGEventGetIntegerValueField(eventRef, field)
  end

  def get_user_data
    CGEventGetIntegerValueField(eventRef, KCGEventSourceUnixProcessID)
  end

  def get_flags
    CGEventGetFlags(eventRef)
  end

  def set_flags(flags)
    CGEventSetFlags(eventRef, flags)
  end
end
