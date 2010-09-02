Emacs = App.new
require 'rum/barrel/emacs'
class << Emacs
  def activate
    System.script 'tell application "Emacs"
                     activate
                   end tell'
  end
end

Textmate = App.new
class << Textmate
  def open_file(path, line=nil)
    args = []
    args.concat ['-l', line.to_s] if line
    args << path
    system('mate', *args)
  end
end
