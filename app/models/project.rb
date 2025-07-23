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


  def status
    DockerService.instance.container_status(container_name)
  end


  def is_running
    live_status == "running"
  end


  def start
    DockerService.instance.start_container(container_name)
  end


  def stop
    DockerService.instance.stop_container(container_name)
  end

  def update_reverse_proxy
    Rails.logger.info "Updating Caddy configuration for project: #{name}"

    existing_config = CaddyService.instance.get_config(container_name)

    if saved_change_to_subdomain? && existing_config
      # If the subdomain has changed, we need to remove the old proxy
      CaddyService.instance.delete_config("id/#{container_name}")
    end

    # Create/recreate configuration for current domain
    if subdomain.present?
      CaddyService.instance.add_proxy(
        "#{subdomain}.localhost",
        "#{container_name}:#{internal_port}",
        container_name
      )
    end

    # Reload Caddy configuration
    # CaddyConfig.reload
  end

  private
  def set_default_status
    self.status ||= "not_deployed"
  end

  def ddns_settings
    @ddns_settings ||= DdnsSettings.instance
  end
end
