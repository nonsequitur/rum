module Rum
  module Gui
    autoload :Growl, 'rum/mac/gui/growl'

    def open_file path, line=nil
      NSWorkspace.sharedWorkspace.openFile(File.expand_path(path))
    end

    def goto path
      # reveal in finder
      System.start '-R', path
    end

    private

    def browse_backend url
      url = NSURL.URLWithString(url)
      NSWorkspace.sharedWorkspace.openURL(url)
    end

    binary = File.join(File.dirname(__FILE__),
                       'gui/CocoaDialog.app/Contents/MacOS/CocoaDialog')
    CocoaDialog.setup binary
    use CocoaDialog
  end
end
