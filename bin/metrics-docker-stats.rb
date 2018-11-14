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
#   metrics-docker-stats.rb -H /var/run/docker.sock
#
#   Gather stats from all containers on a host using HTTP:
#   metrics-docker-stats.rb -H localhost:2375
#
#   Gather stats from a specific container using socket:
#   metrics-docker-stats.rb -H /var/run/docker.sock -N 5bf1b82382eb
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
require 'sensu-plugins-docker/client_helpers'

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
         short: '-N CONTAINER',
         long: '--container-name CONTAINER',
         default: ''

  option :docker_host,
         description: 'Docker API URI. https://host, https://host:port, http://host, http://host:port, host:port, unix:///path',
         short: '-H DOCKER_HOST',
         long: '--docker-host DOCKER_HOST'

  option :friendly_names,
         description: 'use friendly name if available',
         short: '-n',
         long: '--names',
         boolean: true,
         default: false

  option :name_parts,
         description: 'Partial names by spliting and returning at index(es).
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
         short: '-e ENV_VARS',
         long: '--environment-tags ENV_VARS'

  option :ioinfo,
         description: 'enable IO Docker metrics',
         short: '-i',
         long: '--ioinfo',
         boolean: true,
         default: false

  option :cpupercent,
         description: 'add cpu usage percentage metric',
         short: '-P',
         long: '--percentage',
         boolean: true,
         default: false

  def run
    @timestamp = Time.now.to_i
    @client = DockerApi.new(config[:docker_host])

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
      value.delete!('/') if key == 'name'
      output "#{config[:scheme]}.#{container}.#{key}", value, @timestamp
    end
    if config[:ioinfo]
      blkio_stats(stats['blkio_stats']).each do |key, value|
        output "#{config[:scheme]}.#{container}.#{key}", value, @timestamp
      end
    end
    output "#{config[:scheme]}.#{container}.cpu_stats.usage_percent", calculate_cpu_percent(stats), @timestamp if config[:cpupercent]
  end

  def list_containers
    list = []
    path = '/containers/json'
    containers = @client.parse(path)

    containers.each do |container|
      list << if config[:friendly_names]
                container['Names'][-1].delete('/')
              elsif config[:name_parts]
                container['Names'][-1].delete('/')
              else
                container['Id']
              end
    end
    list
  end

  def container_stats(container)
    path = "/containers/#{container}/stats?stream=0"
    response = @client.call(path)
    if response.code.to_i == 404
      critical "#{config[:container]} is not running on #{@client.uri}"
    end
    parse_json(response)
  end

  def container_tags(container)
    tags = ''
    path = "/containers/#{container}/json"
    response = @client.call(path)
    if response.code.to_i == 404
      critical "#{config[:container]} is not running on #{@client.uri}"
    end
    inspect = parse_json(response)
    tag_list = config[:environment_tags].split(',')
    tag_list.each do |value|
      tags << inspect['Config']['Env'].select { |tag| tag.to_s.match(/#{value}=/) }.first.to_s.gsub(/#{value}=/, '') + '.'
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

  def calculate_cpu_percent(stats)
    cpu_percent = 0.0
    previous_cpu = stats['precpu_stats']['cpu_usage']['total_usage']
    previous_system = stats['precpu_stats']['system_cpu_usage']
    cpu_delta = stats['cpu_stats']['cpu_usage']['total_usage'] - previous_cpu
    system_delta = stats['cpu_stats']['system_cpu_usage'] - previous_system
    if system_delta > 0 && cpu_delta > 0
      number_of_cpu = stats['cpu_stats']['cpu_usage']['percpu_usage'].length
      cpu_percent = (cpu_delta.to_f / system_delta.to_f) * number_of_cpu * 100
    end
    format('%.2f', cpu_percent)
  end
end
