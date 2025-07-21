require "net/http"
require "uri"
require "json"

class CaddyService < BaseService
  CADDY_API_URL = ENV.fetch("CADDY_API_URL", "http://localhost:2019")

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

  def self.add_new_config_block(domain, local_project_url)
    new_config = %(
      #{domain} {
        reverse_proxy #{local_project_url}
      }
    )

    # Add this to the Caddyfile
    CaddyService.append_to_config(new_config)
  end

  def self.append_to_config(new_config)
    current_config = get_config
    updated_config = "#{current_config}\n#{new_config}\n"

    File.write(Rails.root.join("config", "Caddyfile"), updated_config)
    reload
  end

  def self.find_configuration_for_domain(domain)
    config = get_config
    return nil if config.blank?

    # Look for domain blocks in the Caddyfile
    lines = config.split("\n")
    in_domain_block = false
    domain_config = []

    lines.each do |line|
      stripped_line = line.strip

      if stripped_line.start_with?(domain) && stripped_line.include?("{")
        in_domain_block = true
        domain_config << stripped_line
      elsif in_domain_block
        domain_config << line
        if stripped_line == "}"
          break
        end
      end
    end

    domain_config.empty? ? nil : domain_config.join("\n")
  end

  def delete_config_block_for_domain(domain)
    config = get_config
    return if config.blank?

    # Remove domain block from the Caddyfile
    lines = config.split("\n")
    updated_lines = []
    in_domain_block = false

    lines.each do |line|
      stripped_line = line.strip

      if stripped_line.start_with?(domain) && stripped_line.include?("{")
        in_domain_block = true
      elsif in_domain_block
        next if stripped_line == "}"
        next
      end

      updated_lines << line unless in_domain_block && stripped_line == "}"
    end

    File.write(Rails.root.join("config", "Caddyfile"), updated_lines.join("\n"))
    reload
  end
end
