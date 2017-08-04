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

  option :name_parts,
         description: 'Partial names by spliting and returning at index(es). \
                       eg. -m 3,4 my-docker-container-process_name-b2ffdab8f1aceae85300 for process_name.b2ffdab8f1aceae85300',
         short: '-m index',
         long: '--match index'

  option :delim,
         description: 'the deliminator to use with -m',
         short: '-d',
         long: '--deliminator',
         default: '-'

  option :environment_tags,
         description: 'Name of environment variables on each container to be appended to metric name, separated by commas',
         short: '-e ENVIRONMENT_VARIABLES',
         long: '--environment-tags ENVIRONMENT_VARIABLES'

  option :ioinfo,
         description: 'enable IO Docker metrics',
         short: '-i',
         long: '--ioinfo',
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
      scheme = ''
      unless config[:environment_tags].nil?
        scheme << container_tags(container)
      end
      if config[:name_parts]
        config[:name_parts].split(',').each do |key|
          scheme << '.' unless scheme == ''
          scheme << container.split(config[:delim])[key.to_i]
        end
      else
        scheme << container
      end
      output_stats(scheme, stats)
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
    if config[:ioinfo]
      blkio_stats(stats['blkio_stats']).each do |key, value|
        output "#{config[:scheme]}.#{container}.#{key}", value, @timestamp
      end
    end
  end

  def docker_api(path)
    if config[:docker_protocol] == 'unix'
      session = NetX::HTTPUnix.new("unix://#{config[:docker_host]}")
      request = Net::HTTP::Get.new "/#{path}"
    else
      uri = URI("#{config[:docker_protocol]}://#{config[:docker_host]}/#{path}")
      session = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Get.new uri.request_uri
    end

    session.start do |http|
      http.request request do |response|
        response.value
        return JSON.parse(response.read_body)
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
              elsif config[:name_parts]
                container['Names'][0].delete('/')
              else
                container['Id']
              end
    end
    list
  end

  def container_stats(container)
    path = "containers/#{container}/stats?stream=0"
    @stats = docker_api(path)
  end

  def container_tags(container)
    tags = ''
    path = "containers/#{container}/json"
    @inspect = docker_api(path)
    tag_list = config[:environment_tags].split(',')
    tag_list.each do |value|
      tags << @inspect['Config']['Env'].select { |tag| tag.to_s.match(/#{value}=/) }.first.gsub(/#{value}=/, '') + '.'
    end
    tags
  end

  def blkio_stats(io_stats)
    stats_out = {}
    io_stats.each do |stats_type, stats_vals|
      stats_vals.each do |value|
        stats_out["#{stats_type}.#{value['op']}.#{value['major']}.#{value['minor']}"] = value['value']
      end
    end
    stats_out
  end
end
