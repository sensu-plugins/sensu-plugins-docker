#! /usr/bin/env ruby
#
#   docker-container-metrics
#
# DESCRIPTION:
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
#
# metrics-docker-container.rb -H /var/run/docker.sock -n
#   docker.host.sensu.sh.rss 1 1508825823
#   docker.host.sensu.sh.vsize 1572864 1508825823
#   docker.host.sensu.sh.nswap 0 1508825823
#   docker.host.sensu.sh.pctmem 0.0 1508825823
#   docker.host.sensu.sh.fd 0 1508825823
#   docker.host.sensu.sh.cpu 0 1508825823
#
# metrics-docker-container.rb -H https://127.0.0.1:2376
#   docker.host.ff5240e079488d248c021f8da5d13074a6a9db72ffaf1129eded445f4e16cf50.sh.rss 183 1508825793
#   docker.host.ff5240e079488d248c021f8da5d13074a6a9db72ffaf1129eded445f4e16cf50.sh.vsize 4616192 1508825793
#   docker.host.ff5240e079488d248c021f8da5d13074a6a9db72ffaf1129eded445f4e16cf50.sh.nswap 0 1508825793
#   docker.host.ff5240e079488d248c021f8da5d13074a6a9db72ffaf1129eded445f4e16cf50.sh.pctmem 0.01 1508825793
#   docker.host.ff5240e079488d248c021f8da5d13074a6a9db72ffaf1129eded445f4e16cf50.sh.fd 0 1508825793
#   docker.host.ff5240e079488d248c021f8da5d13074a6a9db72ffaf1129eded445f4e16cf50.sh.cpu 0 1508825793
#
# NOTES:
#
# LICENSE:
#   Copyright 2014 Michal Cichra. Github @mikz
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/metric/cli'
require 'sensu-plugins-docker/client_helpers'
require 'pathname'
require 'sys/proctable'

#
# Docker Container Metrics
#
class DockerContainerMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: "docker.#{Socket.gethostname}"

  option :cgroup_path,
         description: 'path to cgroup mountpoint',
         short: '-c PATH',
         long: '--cgroup PATH',
         default: '/sys/fs/cgroup'

  option :docker_host,
         description: 'Docker API URI. https://host, https://host:port, http://host, http://host:port, host:port, unix:///path',
         short: '-H DOCKER_HOST',
         long: '--docker-host DOCKER_HOST'

  option :cgroup_template,
         description: 'cgroup_template',
         short: '-T TPL_STRING',
         long: '--cgroup-template TPL_STRING',
         default: 'cpu/docker/%{container}/cgroup.procs'

  option :friendly_names,
         description: 'use friendly name if available',
         short: '-n',
         long: '--names',
         boolean: true,
         default: false

  def run
    @client = DockerApi.new(config[:docker_host])
    container_metrics
    ok
  end

  def container_metrics
    cgroup = "#{config[:cgroup_path]}/#{config[:cgroup_template]}"

    timestamp = Time.now.to_i
    ps = Sys::ProcTable.ps.group_by(&:pid)
    sleep(1)
    ps2 = Sys::ProcTable.ps.group_by(&:pid)

    fields = [:rss, :vsize, :nswap, :pctmem]

    path = '/containers/json'
    containers = @client.parse(path)

    containers.each do |container|
      path = Pathname(format(cgroup, container: container['Id']))
      pids = path.readlines.map(&:to_i)

      container_name = if config[:friendly_names]
                         container['Names'][0].delete('/')
                       else
                         container['Id']
                       end

      processes = ps.values_at(*pids).flatten.compact.group_by(&:comm)
      processes2 = ps2.values_at(*pids).flatten.compact.group_by(&:comm)

      processes.each do |comm, process|
        prefix = "#{config[:scheme]}.#{container_name}.#{comm}"
        fields.each do |field|
          output "#{prefix}.#{field}", process.map(&field).reduce(:+), timestamp
        end
        # this check requires a lot of permissions, even root maybe?
        output "#{prefix}.fd", process.map { |p| p.fd.keys.count }.reduce(:+), timestamp

        second = processes2[comm]
        cpu = second.map { |p| p.utime + p.stime }.reduce(:+) - process.map { |p| p.utime + p.stime }.reduce(:+)
        output "#{prefix}.cpu", cpu, timestamp
      end
    end
  end
end
