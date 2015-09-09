#!/usr/bin/env ruby
#
#   check-marathon-task
#
# DESCRIPTION:
#   This plugin checks that the given Mesos/Marathon task is running properly
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
#   check-marathon-task.rb -s mesos-a,mesos-b,mesos-c -p 8080 -t mywebsite -i 5
#   CheckMarathonTask OK: 5/5 mywebsite tasks running
#
#   check-marathon-task.rb -s mesos-a,mesos-b,mesos-c -p 8080 -t mywebsite -i 5
#   CheckMarathonTask CRITICAL: 3/5 mywebsite tasks running
#
# NOTES:
#
# LICENSE:
#   Copyright 2015, Antoine POPINEAU (antoine.popineau@appscho.com)
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'net/http'
require 'json'

class MarathonTaskCheck < Sensu::Plugin::Check::CLI
  check_name 'CheckMarathonTask'

  option :server,  short: '-s SERVER', long: '--server SERVER', required: true
  option :port, short: '-p PORT', long: '--port PORT', default: 8080
  option :task,  short: '-t TASK', long: '--task TASK', required: true
  option :instances, short: '-i INSTANCES', long: '--instances INSTANCES', required: true, proc: proc(&:to_i)

  def run
    if config[:instances] == 0
      unknown 'number of instances should be an integer'
    end

    failures = []
    config[:server].split(',').each do |s|
      begin
        url = URI.parse("http://#{s}:#{config[:port]}/v2/tasks?state=running")
        req = Net::HTTP::Get.new(url)
        req.add_field('Accept', 'application/json')
        r = Net::HTTP.new(url.host, url.port).start do |h|
          h.request(req)
        end

        tasks = JSON.parse(r.body)['tasks']
        tasks.select! do |t|
          t['appId'] == "/#{config[:task]}"
        end

        message = "#{tasks.length}/#{config[:instances]} #{config[:task]} tasks running"

        if tasks.length < config[:instances]
          critical message
        end

        ok message
      rescue Errno::ECONNREFUSED, SocketError
        failures << "Marathon on #{s} could not be reached"
      rescue
        failures << "error caught trying to reach Marathon on #{s}"
      end
    end

    unknown "marathon task state could not be retrieved:\n" << failures.join("\n")
  end
end
