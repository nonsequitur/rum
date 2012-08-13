# encoding: utf-8

module Rum
  module Layouts
    module_function

    def default_layout
      us
    end

    # /System/Library/Frameworks/Carbon.framework/.../Events.h
    def core
      core = Layout.new

      [['return', "\n", 36],
       ['tab', 48],
       ['space', ' ', 49],
       ['delete', 51],
       ['escape', 53],
       ['rightcommand', 54],
       ['command', 55],
       ['shift', 56],
       ['capslock', 57],
       ['option', 58],
       ['control', 59],
       ['rightshift', 60],
       ['rightoption', 61],
       ['rightcontrol', 62],
       ['function', 63],
       ['f17', 64],
       ['volumeup', 72],
       ['volumedown', 73],
       ['mute', 74],
       ['f18', 79],
       ['f19', 80],
       ['f20', 90],
       ['f5', 96],
       ['f6', 97],
       ['f7', 98],
       ['f3', 99],
       ['f8', 100],
       ['f9', 101],
       ['f11', 103],
       ['f13', 105],
       ['f16', 106],
       ['f14', 107],
       ['f10', 109],
       ['f12', 111],
       ['f15', 113],
       ['help', 114],
       ['home', 115],
       ['pageup', 116],
       ['forward_delete', 117],
       ['f4', 118],
       ['end', 119],
       ['f2', 120],
       ['pagedown', 121],
       ['f1', 122],
       ['leftarrow', 123],
       ['rightarrow', 124],
       ['downarrow', 125],
       ['uparrow', 126]].each { |key| core.add *key }

      core
    end

    def basic
      basic = core

      [['decimal', 65],
       ['multiply', 67],
       ['add', 69],
       ['numlock', 71],
       ['divide', 75],
       ['numpadenter', 76],
       ['subtract', 78],
       ['numpad0', 82],
       ['numpad1', 83],
       ['numpad2', 84],
       ['numpad3', 85],
       ['numpad4', 86],
       ['numpad5', 87],
       ['numpad6', 88],
       ['numpad7', 89],
       ['numpad8', 91],
       ['numpad9', 92],
       ['apps', 110]].each { |key| basic.add *key }

      basic.remap 'rightshift', 'shift'
      basic.remap 'rightcontrol', 'control'
      basic.remap 'rightoption', 'option'
      basic.remap 'rightcommand', 'command'

      basic.rename 'uparrow', 'up'
      basic.rename 'rightarrow', 'right'
      basic.rename 'downarrow', 'down'
      basic.rename 'leftarrow', 'left'
      basic.rename 'help', 'insert'
      basic.alias  'insert', 'help'
      basic.rename 'delete', 'backspace'
      basic.rename 'forward_delete', 'delete'
      basic.rename 'return', 'enter'
      basic.alias  'enter', 'return'
      basic.rename 'capslock', 'caps'

      basic.alias  'f13', 'print'
      basic.alias  'f14', 'scroll'
      basic.alias  'f15', 'pause'

      basic.alias 'command', 'cmd'
      basic.alias 'function', 'fn'

      %w{command control option shift function}.each do |key|
        basic.core_modifier key
      end

      basic
    end

    def us
      us = basic
      %w{a s d f h g z x c v § b q w e r y t 1 2 3 4 6
         5 = 9 7 - 8 0 ] o u [ i p _ l j _ k ; _ , / n m .}.each_with_index do |key, id|
        us.add key, id unless key == '_'
      end

      us.add "'", 39
      us.add '\\', 42
      us.add '`', 50

      us
    end

    def german
      german = basic
      %w{a s d f h g z x c v ^ b q w e r y t 1 2 3 4 6
         5 ´ 9 7 ß 8 0 + o u ü i p _ l j ä k ö # , - n m .}.each_with_index do |key, id|
        german.add key, id unless key == '_'
      end

      german.add '<', 50

      german
    end
  end
end
