## Sensu-Plugins-docker

[![Build Status](https://travis-ci.org/sensu-plugins/sensu-plugins-docker.svg?branch=master)](https://travis-ci.org/sensu-plugins/sensu-plugins-docker)
[![Gem Version](https://badge.fury.io/rb/sensu-plugins-docker.svg)](http://badge.fury.io/rb/sensu-plugins-docker)
[![Code Climate](https://codeclimate.com/github/sensu-plugins/sensu-plugins-docker/badges/gpa.svg)](https://codeclimate.com/github/sensu-plugins/sensu-plugins-docker)
[![Test Coverage](https://codeclimate.com/github/sensu-plugins/sensu-plugins-docker/badges/coverage.svg)](https://codeclimate.com/github/sensu-plugins/sensu-plugins-docker)
[![Dependency Status](https://gemnasium.com/sensu-plugins/sensu-plugins-docker.svg)](https://gemnasium.com/sensu-plugins/sensu-plugins-docker)
## Functionality

## Files
 * check-contsainer.rb
 * check-docker-container.rb
 * metrics-docker-container.rb

## Usage

## Installation

Add the public key (if you haven’t already) as a trusted certificate

```
gem cert --add <(curl -Ls https://raw.githubusercontent.com/sensu-plugins/sensu-plugins.github.io/master/certs/sensu-plugins.pem)
gem install sensu-plugins-docker -P MediumSecurity
```

You can also download the key from /certs/ within each repository.

#### Rubygems

`gem install sensu-plugins-docker`

#### Bundler

Add *sensu-plugins-docker* to your Gemfile and run `bundle install` or `bundle update`

#### Chef

Using the Sensu **sensu_gem** LWRP
```
sensu_gem 'sensu-plugins-docker' do
  options('--prerelease')
  version '0.0.1.alpha.1'
end
```

Using the Chef **gem_package** resource
```
gem_package 'sensu-plugins-docker' do
  options('--prerelease')
  version '0.0.1.alpha.1'
end
```

## Notes
