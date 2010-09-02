module KeyboardHook
  class Event
    attr_reader :id, :scancode
    def initialize(id, scancode, down)
      @id = id
      @scancode = scancode
      @down = down
    end

    def down?
      @down
    end

    def to_s
      "#{@down ? 'Down' : 'Up'}: VKCode #@id, Scancode #@scancode"
    end
  end
end

require_relative 'keyboard_hook.so'
