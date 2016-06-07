#! /usr/bin/env ruby
#
#   metrics-docker-stats
#
# DESCRIPTION:
#
# Supports the stats feature of the docker remote api ( docker server 1.5 and newer )
# Supports connecting to docker remote API over Unix socket or TCP
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
#   Gather stats from all containers on a host using socket:
#   metrics-docker-stats.rb -p unix -H /var/run/docker.sock
#
#   Gather stats from all containers on a host using TCP:
#   metrics-docker-stats.rb -p http -H localhost:2375
#
#   Gather stats from a specific container using socket:
#   metrics-docker-stats.rb -p unix -H /var/run/docker.sock -c 5bf1b82382eb
#
#   See metrics-docker-stats.rb --help for full usage flags
#
# NOTES:
#
# LICENSE:
#   Copyright 2015 Paul Czarkowski. Github @paulczar
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/metric/cli'
require 'socket'
require 'net_http_unix'
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
         description: 'Docker socket to connect. TCP: "host:port" or Unix: "/path/to/docker.sock" (default: "127.0.0.1:2375")',
         short: '-H DOCKER_HOST',
         long: '--docker-host DOCKER_HOST',
         default: '127.0.0.1:2375'

  option :docker_protocol,
         description: 'http or unix',
         short: '-p PROTOCOL',
         long: '--protocol PROTOCOL',
         default: 'http'

  option :friendly_names,
         description: 'use friendly name if available',
         short: '-n',
         long: '--names',
         boolean: true,
         default: false

  def run
    @timestamp = Time.now.to_i

    list = if config[:container] != ''
             [config[:container]]
           else
             list_containers
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
      next if value.is_a?(Array)
      output "#{config[:scheme]}.#{container}.#{key}", value, @timestamp
    end
  end

  def docker_api(path)
    if config[:docker_protocol] == 'unix'
      begin
        NetX::HTTPUnix.start("unix://#{config[:docker_host]}") do |http|
          request = Net::HTTP::Get.new "/#{path}"
          http.request request do |response|
            response.read_body do |chunk|
              @response = JSON.parse(chunk)
              http.finish
            end
          end
        end
      rescue NoMethodError
        # using http.finish to prematurely kill the stream causes this exception.
        return @response
      end
    else
      uri = URI("#{config[:docker_protocol]}://#{config[:docker_host]}/#{path}")
      begin
        Net::HTTP.start(uri.host, uri.port) do |http|
          request = Net::HTTP::Get.new uri.request_uri
          http.request request do |response|
            response.read_body do |chunk|
              @response = JSON.parse(chunk)
              http.finish
            end
          end
        end
      rescue NoMethodError
        # using http.finish to prematurely kill the stream causes this exception.
        return @response
      end
    end
  end

  def list_containers
    list = []
    path = 'containers/json'
    @containers = docker_api(path)

    @containers.each do |container|
      list << if config[:friendly_names]
                container['Names'][0].delete('/')
              else
                container['Id']
              end
    end
    list
  end

  def container_stats(container)
    path = "containers/#{container}/stats"
    @stats = docker_api(path)
  end
end
