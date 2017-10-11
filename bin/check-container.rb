#! /usr/bin/env ruby
#
#   check-container
#
# DESCRIPTION:
#   This is a simple check script for Sensu to check that a Docker container is
#   running. You can pass in either a container id or a container name.
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#
# USAGE:
#   check-container.rb -h /var/run/docker.sock -c c92d402a5d14
#   CheckDockerContainer OK: c92d402a5d14 is running on /var/run/docker.sock.
#
#   check-container.rb -h /var/run/docker.sock -c circle_burglar
#   CheckDockerContainer CRITICAL: circle_burglar is not running on /var/run/docker.sock
#
# NOTES:
#     => State.running == true   -> OK
#     => State.running == false  -> CRITICAL
#     => Not Found               -> CRITICAL
#     => Can't connect to Docker -> WARNING
#     => Other exception         -> WARNING
#
# LICENSE:
#   Copyright 2014 Sonian, Inc. and contributors. <support@sensuapp.org>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'sensu-plugins-docker/client_helpers'

#
# Check Docker Container
#
class CheckDockerContainer < Sensu::Plugin::Check::CLI
  option :docker_host,
         short: '-h DOCKER_HOST',
         long: '--host DOCKER_HOST',
         description: 'Docker API URI. https://host, https://host:port, http://host, http://host:port, host:port, unix:///path',
         default: '127.0.0.1:2375'

  option :container,
         short: '-c CONTAINER',
         long: '--container CONTAINER',
         required: true
  option :tag,
         short: '-t TAG',
         long: '--tag TAG'

  def run
    @client = DockerApi.new(config[:docker_host])
    path = "/containers/#{config[:container]}/json"
    response = @client.call(path, false)
    if response.code.to_i == 404
      critical "Container #{config[:container]} is not running on #{@client.uri}"
    end
    body = parse_json(response)
    container_running = body['State']['Running']
    if container_running
      if config[:tag]
        image = body['Config']['Image']
        match = image.match(/^(?:([^\/]+)\/)?(?:([^\/]+)\/)?([^@:\/]+)(?:[@:](.+))?$/)
        unless match && match[4] == config[:tag]
          critical "#{config[:container]}'s tag is '#{match[4]}', especting '#{config[:tag]}'"
        end
      end
      ok "#{config[:container]} is running on #{@client.uri}."
    else
      critical "#{config[:container]} is #{body['State']['Status']} on #{@client.uri}."
    end
  end
end
