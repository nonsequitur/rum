# encoding: utf-8

module Rum
  module Layouts
    module_function

    def default_layout
      us
    end

    def core
      # http://msdn.microsoft.com/en-us/library/dd375731%28VS.85%29.aspx
      core = Layout.new
      # 0-9
      10.times { |i| core.add i.to_s, 48+i }
      # a-z
      26.times { |i| core.add (97+i).chr, 65+i }
      # f1-f24
      1.upto(24) { |i| core.add "f#{i}", 111+i }

      [['lbutton', 0x01],
       ['rbutton', 0x02],
       ['cancel', 0x03],
       ['mbutton', 0x04],
       ['back', 0x08],
       ['tab', 0x09],
       ['clear', 0x0C],
       ['return', "\n", 0x0D],
       ['shift', 0x10],
       ['control', 0x11],
       ['menu', 0x12],
       ['pause', 0x13],
       ['capital', 0x14],
       ['hangul', 0x15],
       ['junja', 0x17],
       ['final', 0x18],
       ['hanja', 0x19],
       ['kanji', 0x19],
       ['escape', 0x1B],
       ['convert', 0x1C],
       ['nonconvert', 0x1D],
       ['accept', 0x1E],
       ['modechange', 0x1F],
       ['space', ' ', 0x20],
       ['prior', 0x21],
       ['next', 0x22],
       ['end', 0x23],
       ['home', 0x24],
       ['left', 0x25],
       ['up', 0x26],
       ['right', 0x27],
       ['down', 0x28],
       ['select', 0x29],
       ['print', 0x2A],
       ['execute', 0x2B],
       ['snapshot', 0x2C],
       ['insert', 0x2D],
       ['delete', 0x2E],
       ['help', 0x2F],
       ['lwin', 0x5B],
       ['rwin', 0x5C],
       ['apps', 0x5D],
       ['numpad0', 0x60],
       ['numpad1', 0x61],
       ['numpad2', 0x62],
       ['numpad3', 0x63],
       ['numpad4', 0x64],
       ['numpad5', 0x65],
       ['numpad6', 0x66],
       ['numpad7', 0x67],
       ['numpad8', 0x68],
       ['numpad9', 0x69],
       ['multiply', 0x6A],
       ['add', 0x6B],
       ['separator', 0x6C],
       ['subtract', 0x6D],
       ['decimal', 0x6E],
       ['divide', 0x6F],
       ['numlock', 0x90],
       ['scroll', 0x91],
       ['lshift', 0xA0],
       ['rshift', 0xA1],
       ['lcontrol', 0xA2],
       ['rcontrol', 0xA3],
       ['lmenu', 0xA4],
       ['rmenu', 0xA5],
       ['processkey', 0xE5],
       ['attn', 0xF6],
       ['crsel', 0xF7],
       ['exsel', 0xF8],
       ['ereof', 0xF9],
       ['play', 0xFA],
       ['zoom', 0xFB],
       ['noname', 0xFC],
       ['pa1', 0xFD],
       ['oem_clear', 0xFE],
       ['browser_back', 0xA6],
       ['browser_forward', 0xA7],
       ['browser_refresh', 0xA8],
       ['browser_stop', 0xA9],
       ['browser_search', 0xAA],
       ['browser_favorites', 0xAB],
       ['browser_home', 0xAC],
       ['volume_mute', 0xAD],
       ['volume_down', 0xAE],
       ['volume_up', 0xAF],
       ['media_next_track', 0xB0],
       ['media_prev_track', 0xB1],
       ['media_stop', 0xB2],
       ['media_play_pause', 0xB3],
       ['launch_mail', 0xB4],
       ['launch_media_select', 0xB5],
       ['launch_app1', 0xB6],
       ['launch_app2', 0xB7],
       ['oem_plus', 0xBB],
       [',', 'oem_comma', 0xBC],
       ['-', 'oem_minus', 0xBD],
       ['.', 'oem_period', 0xBE],
       ['oem_1', 0xBA],
       ['oem_2', 0xBF],
       ['oem_3', 0xC0],
       ['oem_4', 0xDB],
       ['oem_5', 0xDC],
       ['oem_6', 0xDD],
       ['oem_7', 0xDE],
       ['oem_8', 0xDF],
       ['oem_102', 0xE2],
       ['processkey', 0xE5],
       ['packet', 0xE]].each { |key| core.add *key }

      core
    end

    def basic
      basic = core

      basic.remap 'lcontrol', 'rcontrol', 'control'
      basic.remap 'rmenu', 'lmenu'
      basic.remap 'lshift', 'rshift', 'shift'
      basic.remap 'rwin', 'lwin'

      basic.alias 'control', 'ctrl'
      basic.alias 'control', 'c'
      basic.rename 'lmenu', 'alt'
      basic.alias 'alt', 'a'
      basic.alias 'shift', 's'
      basic.rename 'lwin', 'win'
      basic.rename 'back', 'backspace'
      basic.rename 'return', 'enter'
      basic.alias 'enter', 'return'
      basic.rename 'capital', 'caps'
      basic.rename 'prior', 'pageup'
      basic.rename 'next', 'pagedown'
      basic.rename 'snapshot', 'print'


      %w{shift control alt win}.each { |key| basic.core_modifier key }

      basic.action_modifier 'alt'
      basic.action_modifier 'win'

      basic.add :extended, 'alt-extended', basic['alt'].id
      basic.add :extended, 'left-extended', basic['left'].id
      basic.add :extended, 'right-extended', basic['right'].id

      shift_translations = ('a'..'z').map { |key| [key.upcase, key] }
      shift_translations.each do |from, to|
        basic.translations[from] = "(shift #{to})"
      end
      basic
    end

    def us
      us = basic
      us.rename 'oem_plus', '='
      us.rename 'oem_1', ';'
      us.rename 'oem_2', '/'
      us.rename 'oem_3', '`'
      us.rename 'oem_4', '['
      us.rename 'oem_5', '\\'
      us.rename 'oem_6', ']'
      us.rename 'oem_7', "'"
      us.rename 'oem_102', '\\'

      shift_translations = <<END.scan(/(\S) (\S)/)
~ `   $ 4   * 8   + =    " '
! 1   % 5   ( 9   } ]    < ,
@ 2   ^ 6   ) 0   | \    > .
# 3   & 7   _ -   : ;    ? /
END
      shift_translations.each do |from, to|
        us.translations[from] = "(shift #{to})"
      end
      us
    end

    def german
      german = basic
      german.rename 'oem_plus', '+'
      german.rename 'oem_1', 'ü'
      german.rename 'oem_2', '#'
      german.rename 'oem_3', 'ö'
      german.rename 'oem_4', 'ß'
      german.rename 'oem_5', '^'
      german.rename 'oem_6', '´'
      german.rename 'oem_7', 'ä'
      german.rename 'oem_102', '<'

      shift_translations = <<END.scan(/(\S) (\S)/)
° ^   $ 4   ( 8   ` ´    ; ,
! 1   % 5   ) 9   * +    : .
" 2   & 6   = 0   ' #    _ -
§ 3   / 7   ? ß   > <
END
      shift_translations.each do |from, to|
        german.translations[from] = "(shift #{to})"
      end

      altgr_translations = <<END.scan(/(\S) (\S)/)
² 2   ] 9   € e
³ 3   } 0   ~ +
{ 7   \\ ß  | <
[ 8   @ q   µ m
END
      altgr_translations.each do |from, to|
        german.translations[from] = "(ctrl (alt-extended #{to}))"
      end

      german
    end
  end
end
