#! /usr/bin/env ruby
#
#   check-docker-container
#
# DESCRIPTION:
# This is a simple check script for Sensu to check the number of a Docker Container
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
#   check-docker-container.rb -w 3 -c 3
#   => 1 container running = OK.
#   => 4 container running = CRITICAL
#
#   check-docker-container.rb -H /var/run/docker.sock -w 3 -c 3
#   => 1 container running = OK.
#   => 4 container running = CRITICAL
#
#   check-docker-container.rb -H https://127.0.0.1:2376  -w 3 -c 3
#   => 1 container running = OK.
#   => 4 container running = CRITICAL
#
# NOTES:
#
# LICENSE:
#   Author Yohei Kawahara  <inokara@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'sensu-plugins-docker/client_helpers'

#
# Check Docker Containers
#
class CheckDockerContainers < Sensu::Plugin::Check::CLI
  option :docker_host,
         description: 'Docker API URI. https://host, https://host:port, http://host, http://host:port, host:port, unix:///path',
         short: '-H DOCKER_HOST',
         long: '--docker-host DOCKER_HOST'

  option :warn_over,
         short: '-W N',
         long: '--warn-over N',
         description: 'Trigger a warning if over a number',
         proc: proc(&:to_i)

  option :crit_over,
         short: '-C N',
         long: '--critical-over N',
         description: 'Trigger a critical if over a number',
         proc: proc(&:to_i)

  option :warn_under,
         short: '-w N',
         long: '--warn-under N',
         description: 'Trigger a warning if under a number',
         proc: proc(&:to_i),
         default: 1

  option :crit_under,
         short: '-c N',
         long: '--critical-under N',
         description: 'Trigger a critical if under a number',
         proc: proc(&:to_i),
         default: 1

  def under_message(crit_under, count)
    "Less than #{crit_under} containers running. #{count} running."
  end

  def over_message(crit_over, count)
    "More than #{crit_over} containers running. #{count} running."
  end

  def evaluate_count(count)
    # #YELLOW
    if config.key?(:crit_under) && count < config[:crit_under]
      critical under_message(config[:crit_under], count)
    # #YELLOW
    elsif config.key?(:crit_over) && count > config[:crit_over]
      critical over_message(config[:crit_over], count)
    # #YELLOW
    elsif config.key?(:warn_under) && count < config[:warn_under]
      warning under_message(config[:warn_under], count)
    # #YELLOW
    elsif config.key?(:warn_over) && count > config[:warn_over]
      warning over_message(config[:warn_over], count)
    else
      ok
    end
  end

  def run
    @client = DockerApi.new(config[:docker_host])
    containers = @client.parse('/containers/json')
    evaluate_count containers.size
  end
end
