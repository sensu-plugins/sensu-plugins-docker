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
         description: 'location of docker api, host:port or /path/to/docker.sock',
         short: '-H DOCKER_HOST',
         long: '--docker-host DOCKER_HOST',
         default: '/var/run/docker.sock'

  option :docker_protocol,
         description: 'http or unix',
         short: '-p PROTOCOL',
         long: '--protocol PROTOCOL',
         default: 'unix'

  option :friendly_names,
         description: 'use friendly name if available',
         short: '-n',
         long: '--names',
         boolean: true,
         default: false

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
    image = `docker inspect -f {{.Config.Image}} #{container}`.gsub(/.*?\//,'').gsub(/:.*/,'').strip
    dotted_stats = Hash.to_dotted_hash stats
    dotted_stats.each do |key, value|
      next if key == 'read' # unecessary timestamp
      next if key.start_with? 'blkio_stats' # array values, figure out later
      output "#{config[:scheme]}.#{image}.#{container[0..12]}.#{key}", value, @timestamp
    end
  end

  def docker_api_no_stream(path)
    if config[:docker_protocol] == 'unix'
      NetX::HTTPUnix.start("unix://#{config[:docker_host]}") do |http|
        request = Net::HTTP::Get.new "/#{path}"
        http.request request do |response|
          @response = JSON.parse(response.body)
        end
      end
      return @response
    else
      uri = URI("#{config[:docker_protocol]}://#{config[:docker_host]}/#{path}")
      Net::HTTP.start(uri.host, uri.port) do |http|
        request = Net::HTTP::Get.new uri.request_uri
        http.request request do |response|
          @response = JSON.parse(response.body)
        end
      end
      return @response
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
    path = 'containers/json?format=\'{{.Id}}\''
    @containers = docker_api_no_stream(path)

    @containers.each do |container|
      if config[:friendly_names]
        list << container['Names'][0].gsub('/', '')
      else
        list << container['Id']
      end
    end
    list
  end

  def container_stats(container)
    path = "containers/#{container}/stats"
    @stats = docker_api(path)
  end
end
