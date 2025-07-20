class Project < ApplicationRecord
  # Validations
  validates :name, presence: true
  validates :docker_image, presence: true
  validates :internal_port, presence: true, numericality: { greater_than: 0, less_than: 65536 }
  validates :external_port, presence: true, numericality: { greater_than: 0, less_than: 65536 }

  # Set default status after initialization
  after_initialize :set_default_status, if: :new_record?

  def container_name
    "tugboat-#{name.downcase.gsub(/[^a-z0-9\-_]/, '_')}-#{id}"
  end

  # Port mapping string for Docker
  def port_mapping
    return nil unless internal_port && external_port
    "#{external_port}:#{internal_port}"
  end

  # Legacy port method for backward compatibility
  def port
    external_port
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

  private

  def set_default_status
    self.status ||= "not_deployed"
  end
end
