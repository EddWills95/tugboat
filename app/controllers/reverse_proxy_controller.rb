class ReverseProxyController < ApplicationController
  def index
    @status = CaddyService.instance.status
    raw_config = CaddyService.instance.get_config
    @proxy_config = JSON.pretty_generate(raw_config[:json]) if raw_config[:json]
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
