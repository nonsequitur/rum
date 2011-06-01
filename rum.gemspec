require 'rubygems'

Gem::Specification.new do |spec|
  spec.name       = 'rum'
  spec.version    = '0.0.1'
  spec.author     = 'nonsequitur'
  spec.license    = 'MIT'
  spec.homepage   = 'http://nonsequitur.github.com/rum'
  spec.summary    = 'A cross-platform Hotkey and Macro utility, running on Windows and Mac OS.'
  spec.required_ruby_version = '>= 1.9.1'

  spec.executables << 'rum-client'
  spec.extra_rdoc_files = ['README']
end
