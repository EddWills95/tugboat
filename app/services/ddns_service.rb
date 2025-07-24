class DdnsService < BaseService
  ## Define the Class methods and attributes
  CONFIG_PATH = Rails.root.join("data", "ddns", "config.json")

  def service_name
    "ddns"
  end

  def docker_name
    "tugboat-#{service_name}"
  end

  def local_admin_ui_url
    "http://localhost:8000"
  end

  ## Config methods
  def get_config
    File.exist?(CONFIG_PATH) ? File.read(CONFIG_PATH) : "{}"
  end

  def save_config(params)
    File.write(CONFIG_PATH, params[:config_json])
  end

  ## UI Methods
  def get_current_wan_ip
    begin
      uri = URI("https://api.ipify.org?format=json")
      response = Net::HTTP.get(uri)
      @current_ip = JSON.parse(response)["ip"]
    rescue
      @current_ip = "Unavailable"
    end
  end


  private
  def set_config_path
    @config_path = Rails.root.join("data", "ddns", "config.json")
  end
end
