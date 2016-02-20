#Change Log
This project adheres to [Semantic Versioning](http://semver.org/).

This CHANGELOG follows the format listed at [Keep A Changelog](http://keepachangelog.com/)

## [Unreleased]
### Added
- Added check-container-logs.rb to check docker logs for matching strings 

### Changed
- check-docker-container.rb: output the number of running containers

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

[Unreleased]: https://github.com/sensu-plugins/sensu-plugins-docker/compare/0.0.4...HEAD
[0.0.4]: https://github.com/sensu-plugins/sensu-plugins-docker/compare/0.0.3...0.0.4
[0.0.3]: https://github.com/sensu-plugins/sensu-plugins-docker/compare/0.0.2...0.0.3
[0.0.2]: https://github.com/sensu-plugins/sensu-plugins-docker/compare/0.0.1...0.0.2
