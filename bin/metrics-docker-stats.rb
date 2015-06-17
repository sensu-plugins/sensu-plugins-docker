#! /usr/bin/env ruby
#
#   docker-container-metrics
#
# DESCRIPTION:
#
# Supports the stats feature of the docker remote api ( docker server 1.5 and newer )
# Currently only supports when docker is listening on tcp port.
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
#   #YELLOW
#
# NOTES:
#
# LICENSE:
#   Copyright 2015 Paul Czarkowski. Github @paulczar
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'
require 'net/http'
require 'json'

class Hash
  def self.to_dotted_hash(hash, recursive_key = '')
    hash.each_with_object({}) do |(k, v), ret|
      key = recursive_key + k.to_s
      if v.is_a? Hash
        ret.merge! to_dotted_hash(v, key + '.')
      else
        ret[key] = v
      end
    end
  end
end

class DockerStatsMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: "#{Socket.gethostname}.docker"

  option :container,
         description: 'Name of container to collect metrics for',
         short: '-c CONTAINER',
         long: '--container CONTAINER',
         default: ''

  option :docker_host,
         description: 'location of docker api, host:port or /path/to/docker.sock',
         short: '-H DOCKER_HOST',
         long: '--docker-host DOCKER_HOST',
         default: '127.0.0.1:2375'

  option :docker_protocol,
         description: 'http or unix',
         short: '-p PROTOCOL',
         long: '--protocol PROTOCOL',
         default: 'http'

  def run
    @timestamp = Time.now.to_i

    if config[:container] != ''
      list = [config[:container]]
    else
      list = list_containers
    end
    list.each do |container|
      stats = container_stats(container)
      output_stats(container, stats)
    end
    ok
  end

  def output_stats(container, stats)
    dotted_stats = Hash.to_dotted_hash stats
    dotted_stats.each do |key, value|
      next if key == 'read' # unecessary timestamp
      next if key.start_with? 'blkio_stats' # array values, figure out later
      output "#{config[:scheme]}.#{container}.#{key}", value, @timestamp
    end
  end

  def docker_uri
    "#{config[:docker_protocol]}://#{config[:docker_host]}"
  end

  def list_containers
    list = []
    uri = URI("#{docker_uri}/containers/json")
    Net::HTTP.start(uri.host, uri.port) do |http|
      request = Net::HTTP::Get.new uri.request_uri
      http.request request do |response|
        @containers = JSON.parse(response.read_body)
      end
    end
    @containers.each do |container|
      list << container['Id']
    end
    list
  end

  def container_stats(container)
    uri = URI("#{docker_uri}/containers/#{container}/stats")
    begin
      Net::HTTP.start(uri.host, uri.port) do |http|
        request = Net::HTTP::Get.new uri.request_uri
        http.request request do |response|
          response.read_body do |chunk|
            @stats = JSON.parse(chunk)
            http.finish
          end
        end
      end
    rescue NoMethodError
      # using http.finish to prematurely kill the stream causes this exception.
      return @stats
    end
  end
end
