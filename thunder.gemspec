lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'thunder/version'

Gem::Specification.new do |gem|
  gem.name          = 'thunder'
  gem.version       = Thunder::VERSION
  gem.authors       = ['Travis Dempsey', 'Dan Simonson', 'Chris Howe']
  gem.email         = ['coders@infochimps.com']
  gem.licenses      = ['Apache 2.0']
  gem.homepage      = 'https://github.com/infochimps-platform/thunder.git'
  gem.summary       = 'Ruby CLI for AWS CloudFormation and Openstack'
  gem.description   = <<-DESC.gsub(/^ {4}/, '').chomp
    Thunder is a Ruby CLI which provides a unified interface between
    Amazon CloudFormation and Openstack Heat.
  DESC

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(/^bin/){ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(/^(test|spec|features)/)
  gem.require_paths = ['lib']

  gem.add_development_dependency('bundler', '~> 1.6')

  gem.add_dependency('activesupport', '~> 4.1.5')
  gem.add_dependency('aws-sdk',       '~> 1.50.0')
  gem.add_dependency('cfndsl',        '~> 0.1.4')
  gem.add_dependency('fog',           '~> 1.27.0')
  gem.add_dependency('formatador',    '~> 0.2.5')
  gem.add_dependency('parseconfig',   '~> 1.0.4')
  gem.add_dependency('rest-client',   '~> 1.7.2')
  gem.add_dependency('sshkey',        '~> 1.6.1')
  gem.add_dependency('thor',          '~> 0.19.1')
end
