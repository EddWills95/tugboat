require "net/http"
require "uri"
require "json"


class CaddyService < BaseService
  CONFIG_PATH = Rails.root.join("data", "caddy_config.json")
  @endpoint = "http://localhost:2019"

  # On initialization, load config from file if it exists
  def initialize
    super
    @endpoint = "http://localhost:2019"
  end

  def start
    super
    wait_for_service_ready
    if File.exist?(CONFIG_PATH)
      load_config_from_file
    else
      create_default_config
    end
  rescue StandardError => e
    Rails.logger.error "CaddyService: Failed to start Caddy - #{e.message}"
    raise e
  end

  # Overwrite the base class to save the config before teardown
  def stop
    save_config_to_file
    super
  end

  def service_name
    "caddy"
  end

  def docker_name
    "tugboat-#{service_name}"
  end

  def has_proxy?(container_name)
    response = get_config_by_id(container_name)
    response[:code] == 200 && response[:json].present?
  end

  def add_proxy(hostname, upstream_url, container_name)
    # Get current config from Caddy
    response = get_config
    config = response[:json] || {}

    # Ensure the routes array exists
    listen = config.dig("apps", "http", "servers", "default", "listen") || [ ":80" ]
    routes = config.dig("apps", "http", "servers", "default", "routes") || []

    # Remove any existing route with the same @id
    routes.reject! { |r| r["@id"] == container_name }

    # Add the new route
    routes << {
      "@id" => container_name,
      "match" => [ { "host" => [ hostname ] } ],
      "handle" => [
        {
          "handler" => "reverse_proxy",
          "upstreams" => [ { "dial" => upstream_url } ]
        }
      ]
    }

    # Patch only the routes array to avoid overwriting other config
    patch_body = {
      "apps" => {
        "http" => {
          "servers" => {
            "default" => {
              "listen" => listen,
              "routes" => routes
            }
          }
        }
      }
    }
    patch_config("", patch_body)
  end

  # Remove a proxy route by container_name (container_name)
  def remove_proxy(container_name)
    # Find the index of the route with the given @id
    response = get_config
    config = response[:json] || {}
    routes = config.dig("apps", "http", "servers", "default", "routes") || []
    idx = routes.find_index { |r| r["@id"] == container_name }
    return unless idx

    # Caddy API: DELETE /config/apps/http/servers/default/routes/{index}
    path = "apps/http/servers/default/routes/#{idx}"
    delete_config(path)
  end

  # Get current config (optionally at a path)
  def get_config(path = nil)
    Rails.logger.info "CaddyService: Getting config at path: #{path || 'root'}"
    uri = URI.join(@endpoint, "/config/#{path}")
    req = Net::HTTP::Get.new(uri)
    response = send_request(uri, req)
    Rails.logger.info "CaddyService: Get config response - Code: #{response[:code]}"
    puts "Response", response
    response
  end

  def get_config_by_id(container_name)
    Rails.logger.info "CaddyService: Getting config for container_name: #{container_name}"
    uri = URI.join(@endpoint, "/id/#{container_name}")
    req = Net::HTTP::Get.new(uri)
    response = send_request(uri, req)
    Rails.logger.info "CaddyService: Get config by ID response - Code: #{response[:code]}"
    response
  end

  # Patch config at a given path (partial update)
  def patch_config(path, patch_body)
    Rails.logger.info "CaddyService: Patching config at path: #{path}"
    uri = URI.join(@endpoint, "/config/#{path}")
    req = Net::HTTP::Patch.new(uri)
    req["Content-Type"] = "application/json"
    req.body = patch_body.is_a?(String) ? patch_body : patch_body.to_json
    response = send_request(uri, req)
    Rails.logger.info "CaddyService: Patch config response - Code: #{response[:code]}"
    response
  end

  # Delete config at a specific path using DELETE /config/{path}
  def delete_config(path = nil)
    Rails.logger.info "CaddyService: Deleting config at path: #{path}"
    uri = URI.join(@endpoint, "/config/#{path}")
    req = Net::HTTP::Delete.new(uri)
    response = send_request(uri, req)
    Rails.logger.info "CaddyService: Delete config response - Code: #{response[:code]}"
    response
  end

  def put_config(path, config_body)
    Rails.logger.info "CaddyService: Putting config at path: #{path}"
    uri = URI.join(@endpoint, "/config/#{path}")
    req = Net::HTTP::Put.new(uri)
    req["Content-Type"] = "application/json"
    # Ensure config_body is not a hash with the path as a key
    if config_body.is_a?(Hash) && config_body.keys == [ path ]
      config_body = config_body[path]
    end
    req.body = config_body.is_a?(String) ? config_body : config_body.to_json
    response = send_request(uri, req)
    Rails.logger.info "CaddyService: Put config response - Code: #{response[:code]}"
    response
  end

  private
  # Helper to send HTTP requests
  def send_request(uri, req)
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
      res = http.request(req)
      {
        code: res.code.to_i,
        body: res.body,
        json: (JSON.parse(res.body) rescue nil)
      }
    end
  rescue StandardError => e
    Rails.logger.error "CaddyService: Request failed - #{e.class}: #{e.message}"
    {
      code: 0,
      body: nil,
      json: nil,
      error: e.message
    }
  end

  # Save current Caddy config to JSON file
  def save_config_to_file
    response = get_config
    if response[:code] == 200 && response[:body].present?
      FileUtils.mkdir_p(File.dirname(CONFIG_PATH))
      File.write(CONFIG_PATH, response[:body])
      Rails.logger.info "CaddyService: Saved config to #{CONFIG_PATH}"
    else
      Rails.logger.warn "CaddyService: Could not save config, response: #{response.inspect}"
    end
  end

  # Load config from JSON file and POST to /load
  def load_config_from_file
    if File.exist?(CONFIG_PATH)
      config_json = File.read(CONFIG_PATH)
      Rails.logger.info "CaddyService: Loading config from file: #{CONFIG_PATH}"
      uri = URI.join(@endpoint, "/load")
      req = Net::HTTP::Post.new(uri)
      req["Content-Type"] = "application/json"
      req.body = config_json
      response = send_request(uri, req)
      Rails.logger.info "CaddyService: Loaded config from file, response: #{response[:code]}"
      response
    else
      Rails.logger.warn "CaddyService: No config file found at #{CONFIG_PATH}"
      nil
    end
  end

  def create_default_config
    Rails.logger.info "CaddyService: Creating default config"
    default_config = {
      "apps" => {
        "http" => {
          "servers" => {
            "default" => {
              "listen" => [ ":80" ],
              "routes" => []
            }
          }
        }
      }
    }
    put_config("", default_config)
  rescue StandardError => e
    Rails.logger.error "CaddyService: Failed to create default config - #{e.message}"
  end

  def wait_for_service_ready
    max_attempts = 30
    attempt = 0
    loop do
      attempt += 1
      begin
        uri = URI.join(@endpoint, "/config/")
        req = Net::HTTP::Get.new(uri)
        response = send_request(uri, req)
        break if response[:code] == 200
      rescue StandardError => e
        Rails.logger.debug "CaddyService: Waiting for service (attempt #{attempt}/#{max_attempts}): #{e.message}"
      end

      if attempt >= max_attempts
        raise "CaddyService: Service failed to start after #{max_attempts} attempts"
      end

      sleep 1
    end
    Rails.logger.info "CaddyService: Service is ready after #{attempt} attempts"
  end
end
