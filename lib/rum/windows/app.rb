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

    def initialize(path, *args)
      x64 = args.delete :x64
      @path = append_path_to_programfiles_if_relative(path, x64)
      @binary = File.basename(@path).sub(/\.exe$/, '').downcase
      @matcher = WindowMatcher.new(*args)
      App.add(self)
    end

    PROGRAM_FILES     = ENV['PROGRAMFILES'].gsub('\\', '/')
    PROGRAM_FILES_X64 = ENV['ProgramW6432'].gsub('\\', '/')

    def append_path_to_programfiles_if_relative(path, x64)
      if path !~ /^\w:|^%/
        program_files = x64 ? PROGRAM_FILES_X64 : PROGRAM_FILES
        path = File.join(program_files, path)
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
