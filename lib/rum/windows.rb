require 'rum/windows/system'
require 'rum/windows/keyboard_hook'
require 'rum/windows/keyboard'
require 'rum/windows/gui'
require 'rum/windows/app'
require 'rum/windows/layouts'

module Rum
  Platform = :windows

  def self.restart_platform_specific
    Rum::Server.stop
    System.spawn_in_terminal('ruby', $PROGRAM_NAME)
    sleep 0.01 # This prevents a strange lag. Wow.
    System.terminal_window.close
  end

  class HotkeyProcessor
    def inhibit_modifier_action
      System.send_keypress @layout['control']
    end
  end
end

