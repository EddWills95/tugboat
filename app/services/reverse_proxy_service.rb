require "net/http"
require "uri"
require "json"

class ReverseProxyService < BaseService
  def self.service_name
    "reverse-proxy"
  end

  def self.reload
    # Use the recommended docker exec reload command for Docker deployments
    begin
      result = system("docker exec tugboat-reverse-proxy caddy reload --config /config/Caddyfile")
      if result
        Rails.logger.info "Successfully reloaded Caddy configuration"
        true
      else
        Rails.logger.error "Failed to reload Caddy configuration"
        false
      end
    rescue => e
      Rails.logger.error "Failed to reload Caddy configuration: #{e.message}"
      false
    end
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

    Rails.logger.info "Adding new Caddy config block for domain: #{domain}, local URL: #{local_project_url}"

    # Add this to the Caddyfile and reload automatically
    append_to_config(new_config)
  end

  def self.append_to_config(new_config)
    current_config = get_config
    updated_config = "#{current_config}\n#{new_config}\n"

    File.write(Rails.root.join("data", "proxy", "Caddyfile"), updated_config)
    
    # Automatically reload Caddy after updating the configuration
    reload
  end

  def self.health_check
    # Check if the container is running
    status = DockerService.container_status(docker_name)
    status == "running"
  end
end
