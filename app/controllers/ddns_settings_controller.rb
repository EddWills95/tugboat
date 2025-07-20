class DdnsSettingsController < ApplicationController
  before_action :set_ddns_settings

  def index
    # Show DDNS configuration form
  end

  def update
    if @ddns_settings.update(ddns_settings_params)
      redirect_to ddns_settings_path, notice: "DDNS settings updated successfully."
    else
      render :index, status: :unprocessable_entity
    end
  end

  def toggle_service
    enabled = params[:enabled] == "true"

    if DdnsService.toggle_service!(enabled)
      status_text = enabled ? "enabled" : "disabled"
      redirect_to ddns_settings_path, notice: "DDNS service #{status_text} successfully."
    else
      redirect_to ddns_settings_path, alert: "Failed to toggle DDNS service."
    end
  end

  def start_service
    if DdnsService.start_service!
      redirect_to ddns_settings_path, notice: "DDNS service started successfully."
    else
      redirect_to ddns_settings_path, alert: "Failed to start DDNS service. Check configuration."
    end
  end

  def stop_service
    if DdnsService.stop_service!
      redirect_to ddns_settings_path, notice: "DDNS service stopped successfully."
    else
      redirect_to ddns_settings_path, alert: "Failed to stop DDNS service."
    end
  end

  def restart_service
    if DdnsService.restart_service!
      redirect_to ddns_settings_path, notice: "DDNS service restarted successfully."
    else
      redirect_to ddns_settings_path, alert: "Failed to restart DDNS service."
    end
  end

  private

  def set_ddns_settings
    @ddns_settings = DdnsSettings.instance
  end

  def ddns_settings_params
    params.require(:ddns_settings).permit(
      :enabled, :base_domain, :aws_access_key_id, :aws_secret_access_key,
      :aws_region, :route53_hosted_zone_id, :update_interval
    )
  end
end
