class ReverseProxyController < ApplicationController
  def index
    @status = CaddyService.instance.status
    raw_config = CaddyService.instance.get_config
    @proxy_config = JSON.pretty_generate(raw_config[:json]) if raw_config[:json]

    # Format proxy routes for pretty display: hostname => dial, with project link
    @proxy_routes = []
    routes = raw_config.dig(:json, "apps", "http", "servers", "default", "routes") || []
    routes.each do |route|
      host = route.dig("match", 0, "host", 0)
      upstream = route.dig("handle", 0, "upstreams", 0, "dial")
      container_id = route["@id"]
      # Extract project id from container name (format: tugboat-<name>-<id>)
      project_id = container_id.to_s.split("-").last
      project = Project.find_by(id: project_id)
      @proxy_routes << {
        host: host,
        dial: upstream,
        project: project
      }
    end
    @upstreams = CaddyService.instance.get_reverse_proxy_upstreams
  end

  def start
    CaddyService.instance.start
    redirect_to reverse_proxy_path, notice: "Caddy started."
  end

  def stop
    CaddyService.instance.stop
    redirect_to reverse_proxy_path, notice: "Caddy stopped."
  end

  def clean
    CaddyService.instance.delete_config
    redirect_to reverse_proxy_path, notice: "Caddy config cleaned."
  end
end
