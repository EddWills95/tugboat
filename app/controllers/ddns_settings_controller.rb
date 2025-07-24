require "net/http"
require "json"

class DdnsSettingsController < ApplicationController
  def index
    @status = DdnsService.instance.status
    @config_json = DdnsService.instance.get_config
    @current_ip = DdnsService.instance.get_current_wan_ip
    @settings_ui = DdnsService.instance.local_admin_ui_url
  end

  def create
    DdnsService.instance.save_config(params)
    redirect_to ddns_settings_path, notice: "DDNS settings updated."
  end

  def start
    DdnsService.instance.start
    redirect_to ddns_settings_path, notice: "DDNS service started."
  end

  def stop
    DdnsService.instance.stop
    redirect_to ddns_settings_path, notice: "DDNS service stopped."
  end
end
