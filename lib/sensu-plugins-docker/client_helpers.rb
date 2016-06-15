require 'net_http_unix'
require 'net/https'

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
    if ENV['SSL_KEY'] != nil and ENV['SSL_CERT'] != nil
      client.use_ssl = true
      client.verify_mode = OpenSSL::SSL::VERIFY_NONE
      client.cert = OpenSSL::X509::Certificate.new File.read ENV['SSL_CERT']
      client.key = OpenSSL::PKey::RSA.new File.read ENV['SSL_KEY']
    end
  end

  client
end
