require 'rake/clean'

CLEAN.include('ext/windows/keyboard_hook/*',
              'ext/windows/system/*',
              'ext/mac/keyboard_hook/build',
              '*.gem',
              '**/.DS_Store')
CLEAN.exclude('.c', '.h', 'extconf.rb')

CLOBBER.include('lib/rum/windows/keyboard_hook.so',
                'lib/rum/windows/system.so',
                'lib/rum/mac/keyboard_hook/KeyboardHook.framework',
                'doc/doc.html')

MAC_BINARIES = ['lib/rum/mac/keyboard_hook/KeyboardHook.framework',
                'lib/rum/mac/gui/Growl.framework',
                'lib/rum/mac/gui/CocoaDialog.app']

WINDOWS_BINARIES = ['lib/rum/windows/keyboard_hook.so',
                    'lib/rum/windows/system.so']

namespace :ext do
  namespace :windows do
    InstallDir = 'lib/rum/windows'

    extensions = [['ext/windows/keyboard_hook', 'keyboard_hook'],
                  ['ext/windows/system', 'system', 'input_box',
                   'autohotkey_stuff', 'clipboard_watcher']]

    extensions.each do |dir, ext, *deps|

      extconf = "#{dir}/extconf.rb"

      deps.map! do |dependency|
        source = "#{dir}/#{dependency}.c"
        obj    = "#{dir}/#{dependency}.obj"
        file source do
          # Trigger automatic compiling of source in make
          rm obj if File.exists? obj
        end
        source
      end

      file "#{InstallDir}/#{ext}.so" => ["#{dir}/#{ext}.c", extconf, *deps] do
        Dir.chdir(dir) do
          ruby 'extconf.rb'
          system 'nmake'
          system "mt -manifest #{ext}.so.manifest -outputresource:#{ext}.so;2"
        end
        mv "#{dir}/#{ext}.so", InstallDir
      end
    end

    task :keyboard_hook => 'lib/rum/windows/keyboard_hook.so'
    task :system        => 'lib/rum/windows/system.so'
  end
  task :windows => ['windows:keyboard_hook', 'windows:system']

  namespace :mac do
    keyboard_hook = 'lib/rum/mac/keyboard_hook/KeyboardHook.framework'
    xcode_output  = 'ext/mac/keyboard_hook/build/release/KeyboardHook.framework'

    file keyboard_hook => xcode_output do
      rm_r keyboard_hook if File.exists? keyboard_hook
      cp_r xcode_output, keyboard_hook
    end

    file xcode_output => FileList['ext/mac/keyboard_hook/*.m'] do
      Dir.chdir('ext/mac/keyboard_hook') { system 'xcodebuild' }
    end

    task :keyboard_hook => keyboard_hook
  end
  task :mac => 'mac:keyboard_hook'
end

namespace :gem do
  def common_spec
    spec = eval(IO.read('rum.gemspec'))
    yield spec
  end

  def build(spec)
    Gem::Builder.new(spec).build
  end

  task :windows do
    # mingw32 and mswin32 binaries can be used interchangeably
    platforms = ['x86-mingw32', 'x86-mswin32-60']
    files = FileList['**/*'].exclude(*CLEAN.to_a, *MAC_BINARIES)

    platforms.each do |platform|
      common_spec do |spec|
        spec.files = files
        spec.add_dependency('ruby_gntp', '>= 0.3.4')
        spec.add_dependency('win32-api', '>= 1.4.8')
        spec.add_dependency('win32-clipboard', '>= 0.5.2')
        spec.platform = platform
        build(spec)
      end
    end
  end

  task :mac do
    common_spec do |spec|
      spec.platform = 'universal-darwin-10'
      spec.files = FileList['**/*'].exclude(*CLEAN.to_a, *WINDOWS_BINARIES)
      build(spec)
    end
  end

  task :publish do

  end
end
task :gem => ['gem:windows', 'gem:mac']

namespace :doc do
  doc = 'doc/doc.html'
  doc_files = ['doc/resources/doc.haml', 'doc/resources/intro.rb', 'doc/basic.rb',
               'doc/example.rb','doc/reference.rb']
  task :build => doc

  build_script = 'doc/resources/build.rb'
  file doc => [*doc_files, build_script] do
    require_relative build_script
    Doc.new(*doc_files, dir: File.dirname(__FILE__), output: doc).build
  end
end
task :doc => 'doc:build'

case RUBY_PLATFORM
when /mswin|mingw/   then task :ext => 'ext:windows'
when /darwin/  then task :ext => 'ext:mac'
else raise 'Platform not supported.'
end
task :build => [:ext, :doc]
