module Rum
  class App
    include System

    @@apps = {}
    
    def self.add(app)
      @@apps[app.binary] = app
    end
    
    def self.remove(app)
      @@apps.delete(app.binary)
    end

    def self.apps
      @@apps
    end

    def self.for_exe(exe)
      @@apps[exe.downcase]
    end

    attr_accessor :path, :binary, :matcher

    def initialize(path, *matcher)
      @path = append_path_to_programfiles_if_relative(path)
      @binary = File.basename(@path).sub(/\.exe$/, '').downcase
      @matcher = WindowMatcher.new(*matcher)
      App.add(self)
    end

    def append_path_to_programfiles_if_relative(path)
      if path !~ /^\w:|^%/
        path = File.join(ENV['PROGRAMFILES'].gsub("\\", '/'), path)
      end
      path
    end

    def binary=(bin)
      App.remove(self)
      @binary = bin.downcase
      App.add(self)
    end

    # Returns 'true' if the application window could be activated instantly.
    def activate
      window = @matcher.find
      if window
        window.show
      else
        run
        false
      end
    end

    def run
      start @path
    end

    def to_matcher
      @matcher
    end

    def active?
      @matcher.active?
    end

    def window
      @matcher.find
    end
  end
end
