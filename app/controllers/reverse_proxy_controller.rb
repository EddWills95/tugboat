class ReverseProxyController < ApplicationController
  def index
    @status = CaddyService.status
    raw_config = CaddyService.instance.get_config
    @proxy_config = JSON.pretty_generate(raw_config[:json]) if raw_config[:json]
  end

  def reload
    CaddyService.instance.reload
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

  def clean
    CaddyService.instance.delete_config
    redirect_to reverse_proxy_path, notice: "Caddy config cleaned."
  end
end
