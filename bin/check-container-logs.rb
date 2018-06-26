#! /usr/bin/env ruby
#
#   check-container-logs
#
# DESCRIPTION:
#   Checks docker logs for specified strings
#   with the option to ignore lines if they contain specified substrings.
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: net_http_unix
#
# USAGE:
#   # Check only one container
#   check-container-logs.rb -H /tmp/docker.sock -N logspout -r 'problem sending' -r 'i/o timeout' -i 'Remark:' -i 'The configuration is'
#   => 1 container running = OK
#   => 4 container running = CRITICAL
#
#   # Check multiple containers
#   check-container-logs.rb -H /tmp/docker.sock -N logspout -N logtest -r 'problem sending' -r 'i/o timeout' -i 'Remark:' -i 'The configuration is'
#   => 1 container running = OK
#   => 4 container running = CRITICAL
#
#   # Check all containers
#   check-container-logs.rb -H /tmp/docker.sock -r 'problem sending' -r 'i/o timeout' -i 'Remark:' -i 'The configuration is'
#   => 1 containers running = OK
#   => 4 containers running = CRITICAL
#
# NOTES:
#   The API parameter required to use the limited lookback (-t) was introduced
#   the Docker server API version 1.19. This check may still work on older API
#   versions if you don't want to limit the timestamps of logs.
#
# LICENSE:
#   Author: Nathan Newman  <newmannh@gmail.com>, Kel Cecil <kelcecil@praisechaos.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'sensu-plugins-docker/client_helpers'

class ContainerLogChecker < Sensu::Plugin::Check::CLI
  option :docker_host,
         description: 'Docker API URI. https://host, https://host:port, http://host, http://host:port, host:port, unix:///path',
         short: '-H DOCKER_HOST',
         long: '--docker-host DOCKER_HOST'

  option :container,
         description: 'name of container; can be used multiple times. /!\ All running containers will be check if this options is not provided',
         short: '-N CONTAINER',
         long: '--container-name CONTAINER',
         default: [],
         proc: proc { |flag| (@options[:container][:accumulated] ||= []).push(flag) }

  option :red_flags,
         description: 'String whose presence (case-insensitive by default) in a log line indicates an error; can be used multiple times',
         short: '-r ERR_STRING',
         long: '--red-flag ERR_STRING',
         default: [],
         proc: proc { |flag| (@options[:red_flags][:accumulated] ||= []).push(flag) }

  option :ignore_list,
         description: 'String whose presence (case-insensitive by default) in a log line indicates the line should be ignored; can be used multiple times',
         short: '-i IGNSTR',
         long: '--ignore-lines-with IGNSTR',
         default: [],
         proc: proc { |flag| (@options[:ignore_list][:accumulated] ||= []).push(flag) }

  option :case_sensitive,
         description: 'indicates all red_flag and ignore_list substring matching should be case-sensitive instead of the default case-insensitive',
         short: '-c',
         long: '--case-sensitive',
         boolean: true

  option :hours_ago,
         description: 'Amount of time in hours to look back for log strings',
         short: '-t HOURS',
         long: '--hours-ago HOURS',
         required: false

  option :seconds_ago,
         description: 'Amount of time in seconds to look back for log strings',
         short: '-s SECONDS',
         long: '--seconds-ago SECONDS',
         required: false

  option :check_all,
         description: 'If all containers are checked (no container name provided with -n) , check offline containers too',
         short: '-a',
         long: '--all',
         default: false,
         boolean: true

  option :disable_stdout,
         description: 'Disable the check on STDOUT logs. By default both STDERR and STDOUT are checked',
         short: '-1',
         long: '--no-stdout',
         default: true,
         boolean: true,
         proc: proc { false } # used to negate the false(default)->true boolean option behaviour to true(default)->false

  option :disable_stderr,
         description: 'Disable the check on STDERR logs. By default both STDERR and STDOUT are checked',
         short: '-2',
         long: '--no-stderr',
         default: true,
         boolean: true,
         proc: proc { false } # used to negate the false(default)->true boolean option behaviour to true(default)->false

  def calculate_timestamp(seconds_ago = nil)
    seconds_ago = yield if block_given?
    (Time.now - seconds_ago).to_i
  end

  def process_docker_logs(container_name)
    path = "/containers/#{container_name}/logs?stdout=#{config[:disable_stdout]}&stderr=#{config[:disable_stderr]}&timestamps=true"
    if config.key? :hours_ago
      timestamp = calculate_timestamp { config[:hours_ago].to_i * 3600 }
    elsif config.key? :seconds_ago
      timestamp = calculate_timestamp config[:seconds_ago].to_i
    end
    path = "#{path}&since=#{timestamp}"
    response = @client.call(path, false)
    if response.code.to_i == 404
      critical "Container '#{container_name}' not found on #{@client.uri}"
    end
    yield remove_headers response.read_body
  end

  def remove_headers(raw_logs)
    lines = raw_logs.split("\n")
    lines.map! do |line|
      # Check only logs generated with the 8 bits control
      if !line.nil? && line.bytesize > 8 && /^(0|1|2)000$/ =~ line.byteslice(0, 4).unpack('C*').join('')
        # Remove the first 8 bits and ansii colors too
        line.byteslice(8, line.bytesize).gsub(/\x1b\[[\d;]*?m/, '')
      end
    end
    # We want the most recent logs lines first
    lines.compact.reverse.join("\n")
  end

  def includes_any?(str, array_of_substrings)
    array_of_substrings.each do |substring|
      return true if str.include? substring
    end
    false
  end

  def detect_problem(logs)
    whiteflags = config[:ignore_list]
    redflags = config[:red_flags]
    unless config[:case_sensitive]
      logs = logs.downcase
      whiteflags.map!(&:downcase)
      redflags.map!(&:downcase)
    end

    logs.split("\n").each do |line|
      return line if !includes_any?(line, whiteflags) && includes_any?(line, redflags)
    end
    nil
  end

  def run
    @client = DockerApi.new(config[:docker_host])
    problem = []
    problem_string = nil
    path = "/containers/json?all=#{config[:check_all]}"
    containers = config[:container]
    if config[:container].none?
      warn_msg = %(
        Collecting logs from all containers is dangerous and could lead to sensu client hanging depending on volume of logs.
        This not recommended for production environments.
      ).gsub(/\s+/, ' ').strip
      message warn_msg
    end
    containers = @client.parse(path).map { |p| p['Names'][0].delete('/') } if containers.none?
    critical 'Check all containers was asked but no containers was found' if containers.none?
    containers.each do |container|
      process_docker_logs container do |log_chunk|
        problem_string = detect_problem(log_chunk)
        break unless problem_string.nil?
      end
      problem << "\tError found inside container : '#{container}'\n\t\t#{problem_string}" unless problem_string.nil?
    end
    problem_string = problem.join("\n")
    critical "Container(s) logs indicate problems :\n#{problem_string}" unless problem.none?
    containers_string = containers.join(', ')
    ok "No errors detected from logs inside container(s) : \n#{containers_string}"
  end
end
