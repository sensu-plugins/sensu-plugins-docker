#! /usr/bin/env ruby
#
#   metrics-docker-info
#
# DESCRIPTION:
#
# This check gather certain general stats from Docker (number of CPUs, number of containers, images...)
# Supports the stats feature of the docker remote api ( docker server 1.5 and newer )
# Supports connecting to docker remote API over Unix socket or TCP
# Based on metrics-docker-stats by @paulczar
#
#
# OUTPUT:
#   metric-data
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#
# USAGE:
#   Gather stats using unix socket:
#   metrics-docker-info.rb -p unix -H /var/run/docker.sock
#
#   Gather stats from localhost using TCP:
#   metrics-docker-info.rb -p http -H localhost:2375
#
#   See metrics-docker-info.rb --help for full usage flags
#
# NOTES:
#
# LICENSE:
#   Copyright 2017 Alfonso Casimiro. Github @alcasim
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/metric/cli'
require 'sensu-plugins-docker/client_helpers'

class DockerStatsMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: "#{Socket.gethostname}.docker"

  option :docker_host,
         description: 'Docker API URI. https://host, https://host:port, http://host, http://host:port, host:port, unix:///path',
         short: '-H DOCKER_HOST',
         long: '--docker-host DOCKER_HOST',
         default: '/var/run/docker.sock'

  option :docker_protocol,
         description: 'http or unix',
         short: '-p PROTOCOL',
         long: '--protocol PROTOCOL',
         default: 'unix'

  def run
    @timestamp = Time.now.to_i
    @client = DockerApi.new(config[:docker_host])
    path = '/info'
    infolist = @client.parse(path)
    filtered_list = infolist.select { |key, _value| key.match(/NCPU|NFd|Containers|Images|NGoroutines|NEventsListener|MemTotal/) }
    filtered_list.each do |key, value|
      output "#{config[:scheme]}.#{key}", value, @timestamp
    end
    ok
  end
end
