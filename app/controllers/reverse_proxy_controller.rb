class ReverseProxyController < ApplicationController
  def index
    @caddy_status = CaddyService.status
    @caddy_config = CaddyService.get_config
  end

  def reload
    CaddyService.reload
    redirect_to reverse_proxy_path, notice: "Caddy config reloaded."
  end

  def start
    CaddyService.start
    redirect_to reverse_proxy_path, notice: "Caddy started."
  end

  def stop
    CaddyService.stop
    redirect_to reverse_proxy_path, notice: "Caddy stopped."
  end
end
