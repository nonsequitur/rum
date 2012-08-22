# encoding: utf-8

module Rum
  class Path
    def self.contents dir
      paths = []
      dir = File.join(dir, '')
      dir_dots = /(?:^|\/)\.\.?$/ # /.. or /.
      Dir.glob(dir + '**/*', File::FNM_DOTMATCH).each do |path|
        sub_path = path[(dir.length)..-1].encode(Encoding::UTF_8, \
                                                 Encoding::ISO_8859_1)
        paths << sub_path unless sub_path =~ dir_dots
      end
      paths
    end

    def self.select dir
      path = Gui.choose(nil, contents(dir))
      (File.join(dir, path)) if path
    end

    def self.run path
      if File.extname(path) == '.rb'
        eval(IO.read(path))
      else
        start path
      end
    end

    def self.select_and_run dir
      path = select(dir)
      run path if path
    end

    def self.sanitize path
      path.gsub(/[\/\\|?*><":]/, '-')
    end

    def self.normalize path
      path.gsub('\\', '/')
    end
  end

  module AppDir
    class << self
      attr_accessor :base_dir

      def get(exe)
        File.join(@base_dir, exe, '')
      end

      def get_or_create(exe)
        dir = get(exe)
        if File.exists? dir
          dir
        else
          prompt = "App-Dir für #{exe.capitalize} anlegen?"
          if "Erzeugen" == Gui.choose(prompt, ["Erzeugen", "Nicht erzeugen"])
            Dir.mkdir dir
            dir
          end
        end
      end

      def current
        get_or_create(active_window.exe_name)
      end

      def visit
        dir = current
        Gui.goto dir if dir
      end

      def select
        dir = current
        Path.select_and_run dir if dir
      end
    end
  end

  module Commands
    class Command
      def initialize(name, proc, location)
        @name = name
        @proc = proc
        @location = location
      end

      def to_s
        @name
      end

      def run
        @proc.call
      end

      def visit
        @location.visit if @location
      end
    end

    class << self
      attr_accessor :default_tag
      attr_accessor :commands
      Commands.commands = {}

      def command(name, *args, &block)
        args = args.first
        tag = args[:tag] if args
        tags = []
        tags << tag if tag
        tags << default_tag
        tags.uniq!

        location = FileLocation.from_stack_frame(caller.first)

        if args and (hotkey = args[:hotkey])
          apps = tags.select { |tag| tag.is_a? App }
          apps.each do |app|
            action = hotkey.do(app, &block)
            action.location = location
          end
        end

        cmd = Command.new(name, block, location)
        tags.each do |tag|
          commands_for_tag = (@commands[tag] ||= {})
          commands_for_tag[name] = cmd
        end
      end

      def [] (tag=nil)
        if (cmds = @commands[tag])
          cmds.values
        else
          []
        end
      end

      def select(tag=nil)
        cmd = select_command(self[tag])
        cmd.run if cmd
      end

      TIMER_DURATION = 10
      def select_command(commands)
        cmd = Gui.choose(nil, commands)
        if @visit_timer
          timer_active = (Time.now-@visit_timer) <= TIMER_DURATION
          cmd.visit if cmd and timer_active
          @visit_timer = nil
        else
          cmd
        end
      end

      def visit_next_command
        @visit_timer = Time.now
      end

      def for_active_window
        cmds = []
        exe = active_window.exe_name
        app = App.for_exe(exe)
        cmds.concat self[app] if app
        if (dir = AppDir.get(exe))
          cmds.concat Path.contents(dir)
        end
        if (chosen = select_command(cmds))
          case chosen
          when String
            Path.run(dir + chosen)
          else
            chosen.run
          end
        end
      end
    end
  end

  def Commands(tag=nil, &block)
    Commands.default_tag = tag
    Commands.instance_eval(&block)
  ensure
    Commands.default_tag = nil
  end
end
