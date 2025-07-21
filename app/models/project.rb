class Project < ApplicationRecord
  # Validations
  validates :name, presence: true
  validates :docker_image, presence: true
  validates :internal_port, presence: true, numericality: { greater_than: 0, less_than: 65536 }
  validates :external_port, presence: true, numericality: { greater_than: 0, less_than: 65536 }
  validates :subdomain, format: { with: /\A[a-z0-9\-]+\z/i }, allow_blank: true
  validates :subdomain, uniqueness: true, allow_blank: true
  validates :custom_domain, format: { with: /\A[a-z0-9\-\.]+\z/i }, allow_blank: true

  # Callbacks
  after_save :update_reverse_proxy

  # Set default status after initialization
  after_initialize :set_default_status, if: :new_record?

  def container_name
    "tugboat-#{name.downcase.gsub(/[^a-z0-9\-_]/, '_')}-#{id}"
  end

  def port=(value)
    self.external_port = value
    self.internal_port = value unless internal_port.present?
  end

  def live_status
    result = `docker inspect -f '{{.State.Status}}' #{container_name} 2>/dev/null`.strip
    result.present? ? result : "not created"
  end

  def is_running
    live_status == "running"
  end

  def start
    container_name = self.container_name
    success = system("docker start #{container_name} > /dev/null 2>&1")
    update(status: success ? "running" : "error")
    success
  end

  def stop
    container_name = self.container_name
    success = system("docker stop #{container_name} > /dev/null 2>&1")
    update(status: success ? "stopped" : "error")
    success
  end

  # Domain and URL methods
  def full_domain
    return custom_domain if custom_domain.present?
    return "#{subdomain}.#{ddns_settings.base_domain}" if subdomain.present? && ddns_settings.configured?
    nil
  end

  def url
    return nil unless full_domain
    protocol = ssl_enabled? ? "https" : "http"
    "#{protocol}://#{full_domain}"
  end

  def update_reverse_proxy
    Rails.logger.info "Updating Caddy configuration for project: #{name}"
    if self.subdomain.present?
      local_project_url = "#{self.container_name}:#{self.internal_port}"
      ReverseProxyService.add_new_config_block("http://#{self.subdomain}.localhost", local_project_url)
    else
      Rails.logger.info "No subdomain set for project #{@project.name}, skipping Caddy configuration."
    end
  end

  private
  def set_default_status
    self.status ||= "not_deployed"
  end

  def ddns_settings
    @ddns_settings ||= DdnsSettings.instance
  end
end
