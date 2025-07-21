class ReverseProxyController < ApplicationController
  def index
    @caddy_status = ReverseProxyService.status
    @caddy_config = ReverseProxyService.get_config
  end

  def reload
    ReverseProxyService.reload
    redirect_to reverse_proxy_path, notice: "Caddy config reloaded."
  end

  def start
    ReverseProxyService.start
    redirect_to reverse_proxy_path, notice: "Caddy started."
  end

  def stop
    ReverseProxyService.stop
    redirect_to reverse_proxy_path, notice: "Caddy stopped."
  end
end
