class DdnsSettings < ApplicationRecord
  self.primary_key = "primary_key"

  validates :base_domain, presence: true, format: { with: /\A[a-z0-9\-\.]+\z/i }, if: :enabled?
  validates :aws_access_key_id, presence: true, if: :enabled?
  validates :aws_secret_access_key, presence: true, if: :enabled?
  validates :route53_hosted_zone_id, presence: true, if: :enabled?
  validates :update_interval, presence: true, numericality: { greater_than: 60 }

  def self.instance
    first_or_create(primary_key: "singleton")
  end

  def status
    return :disabled unless enabled?
    return :error if last_error.present?
    return :updating if container_running? && needs_update?
    return :healthy if container_running? && config_file_valid?
    return :stopped if !container_running? && configured?

    :unknown
  end

  def updating?
    # Check if the ddns-updater container is currently running/updating
    container_running?
  end

  def container_running?
    # Check if the ddns-updater container is running
    result = system("docker ps --filter 'name=tugboat-ddns' --filter 'status=running' -q | grep -q .")
    result == true
  end

  def container_exists?
    # Check if the ddns-updater container exists (running or stopped)
    result = system("docker ps -a --filter 'name=tugboat-ddns' -q | grep -q .")
    result == true
  end

  def start_container!
    return false unless enabled? && configured?

    # Generate config file first
    return false unless generate_config_file!

    begin
      if container_exists?
        # Start existing container
        system("docker start tugboat-ddns")
      else
        # Run new container (should be handled by docker-compose)
        system("docker-compose up -d ddns-updater")
      end

      update!(last_error: nil)
      true
    rescue => e
      update!(last_error: "Failed to start container: #{e.message}")
      false
    end
  end

  def stop_container!
    begin
      if container_running?
        system("docker stop tugboat-ddns")
        update!(last_error: nil)
      end
      true
    rescue => e
      update!(last_error: "Failed to stop container: #{e.message}")
      false
    end
  end

  def restart_container!
    stop_container!
    sleep(2) # Give it a moment to stop
    start_container!
  end

  def needs_update?
    return false unless enabled?

    !config_file_valid?
  end

  def update_dns_record!
    # This method now generates the config file for ddns-updater
    generate_config_file!
  end

  def config_file_path
    Rails.root.join("data", "ddns", "config.json")
  end

  def generate_config_file!
    return false unless enabled? && valid?

    config = {
      settings: [
        {
          provider: "route53",
          domain: base_domain,
          host: "*", # Wildcard for all subdomains
          aws_access_key_id: aws_access_key_id,
          aws_secret_access_key: aws_secret_access_key,
          aws_region: aws_region,
          zone_id: route53_hosted_zone_id
        }
      ],
      backup: {
        period: "24h",
        directory: "/updater/data"
      },
      db: {
        type: "json",
        file: "/updater/data/db.json"
      },
      web: {
        enabled: true,
        listening_port: 8000,
        root_url: "/",
        log_level: "info"
      },
      health: {
        server: {
          enabled: true,
          listening_port: 9999
        }
      }
    }

    # Ensure directory exists
    FileUtils.mkdir_p(config_file_path.dirname)

    # Write config file
    File.write(config_file_path, JSON.pretty_generate(config))

    # Clear any previous errors
    update!(last_error: nil, last_update: Time.current)

    true
  rescue => e
    update!(last_error: e.message)
    false
  end

  def config_file_exists?
    File.exist?(config_file_path)
  end

  def config_file_valid?
    return false unless config_file_exists?

    config = JSON.parse(File.read(config_file_path))
    config.dig("settings", 0, "provider") == "route53" &&
    config.dig("settings", 0, "domain") == base_domain
  rescue
    false
  end

  def configured?
    enabled? &&
    base_domain.present? &&
    aws_access_key_id.present? &&
    aws_secret_access_key.present? &&
    route53_hosted_zone_id.present?
  end

  # Callback to regenerate config when settings change
  after_update :manage_container_state

  private

  def manage_container_state
    if saved_change_to_attribute?(:enabled)
      if enabled?
        # DDNS was just enabled - start the container
        start_container! if configured?
      else
        # DDNS was just disabled - stop the container
        stop_container!
      end
    elsif enabled? && config_settings_changed?
      # Settings changed while enabled - restart container with new config
      generate_config_file!
      restart_container! if container_running?
    end
  end

  def config_settings_changed?
    saved_change_to_attribute?(:base_domain) ||
    saved_change_to_attribute?(:aws_access_key_id) ||
    saved_change_to_attribute?(:aws_secret_access_key) ||
    saved_change_to_attribute?(:aws_region) ||
    saved_change_to_attribute?(:route53_hosted_zone_id)
  end
end
