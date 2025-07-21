require "net/http"
require "uri"
require "json"

class ReverseProxyService < BaseService
  PROXY_API_URL = ENV.fetch("PROXY_API_URL", "http://localhost:2019")

  def self.service_name
    "reverse-proxy"
  end

  def self.reload
    DockerService.restart_container(docker_name)
  end

  def self.start
    DockerService.start_container(docker_name)
  end

  def self.stop
    DockerService.stop_container(docker_name)
  end

  def self.get_config
    config_path = Rails.root.join("data", "proxy", "Caddyfile")
    File.exist?(config_path) ? File.read(config_path) : ""
  end

  def self.add_new_config_block(domain, local_project_url)
    new_config = %(
#{domain} {
  reverse_proxy #{local_project_url}
}
    )

    Rails.logger.info "Adding new Caddy config block for domain: #{domain}, local URL: #{local_project_url}, #{new_config}"

    # Add this to the Caddyfile
    ReverseProxyService.append_to_config(new_config)
  end

  def self.append_to_config(new_config)
    current_config = get_config
    updated_config = "#{current_config}\n#{new_config}\n"

    File.write(Rails.root.join("data", "proxy", "Caddyfile"), updated_config)
    reload
  end
end
