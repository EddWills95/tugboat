require "net/http"
require "uri"
require "json"

class CaddyService
  CADDY_API_URL = ENV.fetch("CADDY_API_URL", "http://localhost:2019")

  def self.status
    DockerService.container_status("tugboat-caddy")
  end

  def self.reload
    uri = URI.parse("#{CADDY_API_URL}/load")
    request = Net::HTTP::Post.new(uri)
    request.body = get_config
    request.content_type = "application/json"
    Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(request)
    end
  end

  def self.start
    DockerService.start_container("tugboat-caddy")
  end

  def self.stop
    DockerService.stop_container("tugboat-caddy")
  end

  def self.get_config
    config_path = Rails.root.join("config", "Caddyfile")
    File.exist?(config_path) ? File.read(config_path) : ""
  end
end
