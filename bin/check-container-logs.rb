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
#   gem: docker
#   gem: docker-api
#
# USAGE:
#   check-container-logs.rb -H /tmp/docker.sock -p unix -n logspout -r 'problem sending' -r 'i/o timeout' -i 'Remark:' -i 'The configuration is'
#   => 1 container running = OK
#   => 4 container running = CRITICAL
#
# NOTES:
#
# LICENSE:
#   Author Nathan Newman  <newmannh@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'socket'
require 'net_http_unix'
require 'json'

class ContainerLogChecker < Sensu::Plugin::Check::CLI

  $red_flags = []
  $white_flags = []

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

  option :container,
    description: 'name of container',
    short: '-n CONTAINER',
    long: '--container-name CONTAINER',
    required: true

  option :red_flags,
    description: 'substring whose presence (case-insensitive by default) in a log line indicates an error; can be used multiple times',
    short: '-r "error occurred" -r "problem encountered" -r "error status"',
    long: '--red-flag "error occurred" --red-flag "problem encountered" --red-flag "error status"',
    proc: Proc.new { |flag| $red_flags << flag }

  option :ignore_list,
    description: 'substring whose presence (case-insensitive by default) in a log line indicates the line should be ignored; can be used multiple times',
    short: '-i "configuration:" -i "# Remark:"',
    long: '--ignore-lines-with "configuration:" --ignore-lines-with "# remark:"',
    proc: Proc.new { |flag| $white_flags << flag }

  option :case_sensitive,
    description: 'indicates all red_flag and ignore_list substring matching should be case-sensitive instead of the default case-insensitive',
    short: '-c',
    long: '--case-sensitive',
    boolean: true

  def process_docker_logs(containerName)
    path = "containers/#{containerName}/attach?logs=1&stream=0&stdout=1&stderr=1"
    req = Net::HTTP::Post.new "/#{path}"
    if config[:docker_protocol] == 'unix'
      client = NetX::HTTPUnix.new("unix://#{config[:docker_host]}")
    else
      client = Net::HTTP.new("#{config[:docker_protocol]}://#{config[:docker_host]}")
    end
    client.request req do |response|
      response.read_body do |chunk|
        yield remove_headers chunk
      end
    end
  end

  def remove_headers(raw_logs)
    lines = raw_logs.split("\n")
    lines.map! { |line| line.byteslice(8, line.bytesize) }
    return lines.join("\n")
  end

  def includesAny?(str, arrayOfSubstrings)
    arrayOfSubstrings.each do |substring|
      if str.include? substring then return true end
    end
    return false
  end

  def detect_problem(logs)
    whiteflags = $white_flags
    redflags = $red_flags
    if !config[:case_sensitive]
      logs = logs.downcase
      whiteflags.map!{ |f| f.downcase }
      redflags.map!{ |f| f.downcase }
    end

    logs.split("\n").each do |line|
      if (!includesAny?(line, whiteflags) && includesAny?(line, redflags)) then return line end
    end
    return nil
  end

  def run
    container = config[:container]
    process_docker_logs(container) do |log_chunk|
      problem = detect_problem log_chunk
      if !problem.nil? then critical "#{container} container logs indicate problem: '#{problem}'." end
    end
    ok "No errors detected from #{container} container logs."
  end
end
