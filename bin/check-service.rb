#! /usr/bin/env ruby
#
#   check-service
#
# DESCRIPTION:
#   This is a simple check script for Sensu to check that a Docker service is
#   running all of it's intended tasks. You can pass in either a service id or a service name.
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
#   check-service.rb -H /var/run/docker.sock -N c92d402a5d14
#   CheckDockerService OK: c92d402a5d14 is running on /var/run/docker.sock.
#
#   check-service.rb -H https://127.0.0.1:2376 -N circle_burglar
#   CheckDockerService CRITICAL: circle_burglar is not running on https://127.0.0.1:2376
#
# NOTES:
#     => .Replicas == number of service's tasks -> OK
#     => .Replicas != number of service's tasks -> CRITICAL
#     => Not Found                              -> CRITICAL
#     => Can't connect to Docker                -> WARNING
#     => Other exception                        -> WARNING
#
# LICENSE:
#   Copyright 2014 Sonian, Inc. and contributors. <support@sensuapp.org>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'sensu-plugins-docker/client_helpers'

#
# Check Docker Service
#
class CheckDockerService < Sensu::Plugin::Check::CLI
  option :docker_host,
         short: '-H DOCKER_HOST',
         long: '--docker-host DOCKER_HOST',
         description: 'Docker API URI. https://host, https://host:port, http://host, http://host:port, host:port, unix:///path'

  option :service,
         short: '-N SERVICE',
         long: '--service-name service',
         required: true

  option :tag,
         short: '-t TAG',
         long: '--tag TAG'

  option :allowexited,
         short: '-x',
         long: '--allow-exited',
         boolean: true,
         description: 'Do not raise alert if service has exited without error'

  def run
    # Connect a client to the remote/local docker socket
    @client = DockerApi.new(config[:docker_host])

    # Call /services and get the service we want to check
    path = "/services?filters=%7B%22name%22%3A%7B%22#{config[:service]}%22%3Atrue%7D%7D"
    response = @client.call(path, false)
    if response.code.to_i == 404
      critical "service #{config[:service]} is not running on #{@client.uri} bb"
    end

    # Pass the number of replicas the service should be running
    body = parse_json(response)
    intended_replicas = body[0]['Spec']['Mode']['Replicated']['Replicas']

    # Call /tasks to get the number of running replicas (this is how `docker service ls` works)
    running_replicas = 0
    path = "/tasks?filters=%7B%22name%22%3A%7B%22#{config[:service]}%22%3Atrue%7D%7D"
    response = @client.call(path, false)
    if response.code.to_i == 404
      critical "service #{config[:service]} is not running on #{@client.uri}, tasks not found"
    end

    # Traverse the tasks and check if the state is running
    tasks = parse_json(response)
    tasks.each do |task|
      if task['Status']['State'] == 'running'
        running_replicas += 1
      end
    end

    # If the number of running replicas is not what the service expects, return critical
    if intended_replicas != running_replicas
      critical "service #{config[:service]} is not running the intended number of replicas"
    end
    ok "#{config[:service]} is running correctly on #{@client.uri}."
  end
end
