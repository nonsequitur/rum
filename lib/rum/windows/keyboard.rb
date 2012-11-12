require 'strscan'

module Rum
  module Keyboard
    extend self

    def type(key_sequence, *args)
      release_core_modifiers unless args.include? :blind
      type_sequence(key_sequence, args.include?(:slow))
    end

    def type!(key_sequence, *args)
      release_core_modifiers unless args.include? :blind
      type_sequence_literally(key_sequence, args.include?(:slow))
    end

    def type_unicode(key_sequence, *args)
      release_core_modifiers unless args.include? :blind
      type_sequence_unicode(key_sequence, args.include?(:slow))
    end

    def release_core_modifiers
      Rum.hotkey_processor.release_core_modifiers
    end

    private

    def type_sequence_literally(key_sequence, slow)
      key_sequence.chars.each do |char|
        if (key = Rum.layout[char])
          System.send_keypress key
          sleep 0.01 if slow
        elsif (translation = Rum.layout.translations[char])
          type_sequence(translation, slow)
        end
      end
    end

    def type_sequence(key_sequence, slow)
      s = StringScanner.new(key_sequence)
      pressed_keys = []
      while (char = s.getch)
        case char
        when '\\'
          (char = s.getch) and down_and_up(char, slow)
        when '('
          key = s.scan(/[^() ]+/)
          s.skip /\ /
          down key
          pressed_keys << key
        when ')'
          up pressed_keys.pop
        else
          down_and_up(char, slow)
        end
        sleep 0.01 if slow
      end
      pressed_keys.reverse_each { |key| up key }
    end

    def type_sequence_unicode(key_sequence, slow)
      s = StringScanner.new(key_sequence)
      pressed_keys = []
      while (char = s.getch)
        case char
        when '\\'
          (char = s.getch) and System.send_unicode_char(char)
        when '('
          key = s.scan(/[^() ]+/)
          s.skip /\ /
          down key
          pressed_keys << key
        when ')'
          up pressed_keys.pop
        else
          System.send_unicode_char(char)
        end
        sleep 0.01 if slow
      end
      pressed_keys.reverse_each { |key| up key }
    end

    def down(key)
      send_key key, true
    end

    def up(key)
      send_key key, false
    end

    def down_and_up(char, slow)
      if (key = Rum.layout[char])
        System.send_keypress key
      elsif (key_sequence = Rum.layout.translations[char])
        type_sequence(key_sequence, slow)
      end
    end

    def send_key(key_alias, down)
      if key = Rum.layout[key_alias]
        System.send_key_event key, down
      end
    end
  end
end
