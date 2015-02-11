lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'date'


if RUBY_VERSION < '2.0.0'
  require 'sensu-plugins-docker'
else
  require_relative 'lib/sensu-plugins-docker'
end

pvt_key = '~/.ssh/gem-private_key.pem'

Gem::Specification.new do |s|
  s.name                   = 'sensu-plugins-docker'
  s.version                = SensuPluginsDocker::VERSION
  s.authors                = ["Yieldbot, Inc. and contributors"]
  s.email                  = '<sensu-users@googlegroups.com>'
  s.homepage               = 'https://github.com/sensu-plugins/sensu-plugins-docker'
  s.summary                = ''
  s.description            = ''
  s.license                = 'MIT'
  s.date                   = Date.today.to_s
  s.files                  = Dir.glob('{bin,lib}/**/*') + %w(LICENSE README.md CHANGELOG.md)
  s.executables            = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files             = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths          = ["lib"]
  s.cert_chain             = ["certs/sensu-plugins.pem"]
  s.signing_key            = File.expand_path(pvt_key) if $PROGRAM_NAME =~ /gem\z/
  s.platform               = ruby
  s.required_ruby_version  = '>= 1.9.3'

  
  s.add_development_dependency 'codeclimate-test-reporter' 'XXX'
  
  s.add_development_dependency 'rubocop' '~> 0.17.0'
  
  s.add_development_dependency 'rspec' '~> 3.1'
  
  s.add_development_dependency 'bundler' '~> 1.7'
  
  s.add_development_dependency 'rake' '~> 10.0'
  
  s.add_development_dependency 'github-markup' 'XXX'
  
  s.add_development_dependency 'redcarpet' 'XXX'
  
  s.add_development_dependency 'yard' 'XXX'
  
  s.add_development_dependency 'pry' 'XXX'
  
end
