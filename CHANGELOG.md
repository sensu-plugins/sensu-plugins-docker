#Change Log
This project adheres to [Semantic Versioning](http://semver.org/).

This CHANGELOG follows the format listed at [Keep A Changelog](http://keepachangelog.com/)

## [Unreleased]

### Changed
- dependencies: use net\_http\_unix = 0.2.2

## [1.1.2] - 2016-06-20
### Changed
- dependencies: use sensu-plugin ~> 1.2.0, docker-api = 1.21.0

## [1.1.1] - 2016-06-10
### Fixed
- metrics-docker-stats.rb: Fix error from trying to collect stats with multiple values. Stats that return array values are now excluded. (#29)

### Changed
- improved help messages
- check-container.rb: issue a critical event if container state != running

## [1.1.0] - 2016-06-03
### Added
- check-container-logs.rb: added `-s|--seconds-ago` option to be able to set time interval more precisely

## [1.0.0] - 2016-05-24
Note: this release changes how connections are made to the Docker API and also
changes some options. Review your check commands before deploying this version.

### Added
- Added check-container-logs.rb to check docker logs for matching strings
- Support for Ruby 2.3.0
- metrics-docker-container.rb: add option to override the default path to cgroup.proc

### Removed
- Support for Ruby 1.9.3

### Changed
- check-docker-container.rb: output the number of running containers
- Refactor to connect to the Docker API socket directly instead of using the `docker` or `docker-api` gems
- Update to rubocop 0.40 and cleanup

## [0.0.4] - 2015-08-10
### Changed
- updated dependencies (added missing dependency `sys-proctable`)
- added docker metrics using docker api

## [0.0.3] - 2015-07-14
### Changed
- updated sensu-plugin gem to 1.2.0

## [0.0.2] - 2015-06-02
### Fixed
- added binstubs

### Changed
- removed cruft from /lib

## 0.0.1 - 2015-04-30
### Added
- initial release

[Unreleased]: https://github.com/sensu-plugins/sensu-plugins-docker/compare/1.1.3...HEAD
[1.1.3]: https://github.com/sensu-plugins/sensu-plugins-docker/compare/1.1.2...1.1.3
[1.1.2]: https://github.com/sensu-plugins/sensu-plugins-docker/compare/1.1.1...1.1.2
[1.1.1]: https://github.com/sensu-plugins/sensu-plugins-docker/compare/1.1.0...1.1.1
[1.1.0]: https://github.com/sensu-plugins/sensu-plugins-docker/compare/1.0.0...1.1.0
[1.0.0]: https://github.com/sensu-plugins/sensu-plugins-docker/compare/0.0.4...1.0.0
[0.0.4]: https://github.com/sensu-plugins/sensu-plugins-docker/compare/0.0.3...0.0.4
[0.0.3]: https://github.com/sensu-plugins/sensu-plugins-docker/compare/0.0.2...0.0.3
[0.0.2]: https://github.com/sensu-plugins/sensu-plugins-docker/compare/0.0.1...0.0.2
