require 'net_http_unix'
require 'json'

class DockerApi
  def initialize(uri = nil)
    @client = nil
    @docker_uri = uri || ENV['DOCKER_URL'] || ENV['DOCKER_HOST'] || '/var/run/docker.sock'
    if @docker_uri.sub!(%r{^(unix://)?/}, '')
      @docker_uri = 'unix:///' + @docker_uri
      @client = NetX::HTTPUnix.new(@docker_uri)
    else
      protocol = %r{^(https?|tcp)://}.match(@docker_uri) || 'http://'
      @docker_uri.sub!(protocol.to_s, '')
      split_host = @docker_uri.split ':'
      @client = if split_host.length == 2
                  NetX::HTTPUnix.new("#{protocol}#{split_host[0]}", split_host[1])
                else
                  NetX::HTTPUnix.new("#{protocol}#{@docker_uri}", 2375)
                end
    end
    @client.start
  end

  def uri
    @docker_uri
  end

  def call(path, halt = true, limit = 10)
    raise ArgumentError, "HTTP redirect too deep. Last url called : #{path}" if limit.zero?
    if %r{^unix:///} =~ @docker_uri
      request = Net::HTTP::Get.new path.to_s
    else
      uri = URI("#{@docker_uri}#{path}")
      request = Net::HTTP::Get.new uri.request_uri
    end
    response = @client.request(request)
    case response
    when Net::HTTPSuccess     then response
    when Net::HTTPRedirection then call(response['location'], true, limit - 1)
    else
      return response.error! unless halt == false
      return response
    end
  end

  def parse(path, halt = true, limit = 10)
    parsed = parse_json(call(path, halt, limit))
    parsed
  end
end

def parse_json(response)
  parsed = nil
  begin
    parsed = JSON.parse(response.read_body)
  rescue JSON::ParserError => e
    raise "JSON Error: #{e.inspect}"
  end
  parsed
end
