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
    return :updating if updating?
    return :healthy if config_file_valid? && last_update.present?

    :unknown
  end

  def updating?
    # Check if the ddns-updater container is currently running/updating
    # This could be determined by checking container status or file timestamps
    false # Placeholder for now
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
  after_update :regenerate_config_if_enabled

  private

  def regenerate_config_if_enabled
    generate_config_file! if enabled? && (
      saved_change_to_attribute?(:enabled) ||
      saved_change_to_attribute?(:base_domain) ||
      saved_change_to_attribute?(:aws_access_key_id) ||
      saved_change_to_attribute?(:aws_secret_access_key) ||
      saved_change_to_attribute?(:aws_region) ||
      saved_change_to_attribute?(:route53_hosted_zone_id)
    )
  end
end
