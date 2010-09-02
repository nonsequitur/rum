require 'rum/mac/system'
require 'rum/mac/keyboard_hook'
require 'rum/mac/gui'
require 'rum/mac/layouts'
require 'rum/mac/app'

module Rum
  Platform = :mac
  
  def self.restart_platform_specific
    Rum::Server.close_connections
    exec(RUBY_ENGINE, $PROGRAM_NAME)
  end

  module Keyboard
    # not yet implemented
  end
end
