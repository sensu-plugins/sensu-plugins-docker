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
#   check-container-logs.rb -H /tmp/docker.sock -n logspout -r 'problem sending' -r 'i/o timeout' -i 'Remark:' -i 'The configuration is'
#   => 1 container running = OK
#   => 4 container running = CRITICAL
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
         description: 'Docker socket to connect. TCP: "host:port" or Unix: "/path/to/docker.sock" (default: "127.0.0.1:2375")',
         short: '-H DOCKER_HOST',
         long: '--docker-host DOCKER_HOST',
         default: '127.0.0.1:2375'

  option :container,
         description: 'name of container',
         short: '-n CONTAINER',
         long: '--container-name CONTAINER',
         required: true

  option :red_flags,
         description: 'substring whose presence (case-insensitive by default) in a log line indicates an error; can be used multiple t
imes',
         short: '-r "error occurred" -r "problem encountered" -r "error status"',
         long: '--red-flag "error occurred" --red-flag "problem encountered" --red-flag "error status"',
         default: [],
         proc: proc { |flag| (@options[:red_flags][:accumulated] ||= []).push(flag) }

  option :ignore_list,
         description: 'substring whose presence (case-insensitive by default) in a log line indicates the line should be ignored; can
be used multiple times',
         short: '-i "configuration:" -i "# Remark:"',
         long: '--ignore-lines-with "configuration:" --ignore-lines-with "# remark:"',
         default: [],
         proc: proc { |flag| (@options[:ignore_list][:accumulated] ||= []).push(flag) }

  option :case_sensitive,
         description: 'indicates all red_flag and ignore_list substring matching should be case-sensitive instead of the default case-
insensitive',
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

  def calculate_timestamp(seconds_ago = nil)
    seconds_ago = yield if block_given?
    (Time.now - seconds_ago).to_i
  end

  def process_docker_logs(container_name)
    client = create_docker_client
    path = "/containers/#{container_name}/logs?stdout=true&stderr=true"
    if config.key? :hours_ago
      timestamp = calculate_timestamp { config[:hours_ago].to_i * 3600 }
    elsif config.key? :seconds_ago
      timestamp = calculate_timestamp config[:seconds_ago].to_i
    end
    path = "#{path}&since=#{timestamp}"
    req = Net::HTTP::Get.new path

    client.request req do |response|
      response.read_body do |chunk|
        yield remove_headers chunk
      end
    end
  end

  def remove_headers(raw_logs)
    lines = raw_logs.split("\n")
    lines.map! { |line| line.byteslice(8, line.bytesize) }
    lines.join("\n")
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
    container = config[:container]
    process_docker_logs(container) do |log_chunk|
      problem = detect_problem log_chunk
      critical "#{container} container logs indicate problem: '#{problem}'." unless problem.nil?
    end
    ok "No errors detected from #{container} container logs."
  end
end
