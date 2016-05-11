require 'net_http_unix'

def create_docker_client
  client = nil
  if config[:docker_host][0] == '/'
    host = 'unix://' + config[:docker_host]
    client = NetX::HTTPUnix.new(host)
  else
    split_host = config[:docker_host].split ':'
    client = if split_host.length == 2
               NetX::HTTPUnix.new(split_host[0], split_host[1])
             else
               NetX::HTTPUnix.new(config[:docker_host], 2375)
             end
  end

  client
end
