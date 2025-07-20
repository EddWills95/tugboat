# DDNS Integration Plan for Tugboat

## Overview

Integrate Dynamic DNS functionality to automatically update a single DNS record (AWS Route53) with the server's current IP, and use Caddy as a reverse proxy to route subdomains to specific containerized projects.

## Architecture

### Core Components

1. **Global DDNS Service** - Updates Route53 with current server IP
2. **Caddy Reverse Proxy** - Routes subdomains to project containers
3. **Rails Domain Management** - Configure subdomains for projects
4. **Automatic Caddyfile Generation** - Auto-configure Caddy when projects change

### Traffic Flow

```
Internet → DNS (Route53) → Server IP → Caddy → Project Container
         *.yourdomain.com → 1.2.3.4 → :80/:443 → :project_port
```

## Implementation Steps

### Phase 1: Database Schema

```ruby
# Migration: Add subdomain support to projects
class AddSubdomainToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :subdomain, :string
    add_column :projects, :custom_domain, :string
    add_column :projects, :ssl_enabled, :boolean, default: true

    add_index :projects, :subdomain, unique: true
  end
end

# New Model: DdnsSettings (Global configuration)
class CreateDdnsSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :ddns_settings, id: false do |t|
      t.string :primary_key, default: 'singleton', primary_key: true
      t.boolean :enabled, default: false
      t.string :base_domain
      t.string :aws_access_key_id
      t.string :aws_secret_access_key
      t.string :aws_region, default: 'us-east-1'
      t.string :route53_hosted_zone_id
      t.integer :update_interval, default: 300 # 5 minutes
      t.timestamp :last_update
      t.string :current_ip
      t.timestamps
    end
  end
end
```

### Phase 2: Rails Models

```ruby
# app/models/ddns_settings.rb
class DdnsSettings < ApplicationRecord
  self.primary_key = 'primary_key'

  validates :base_domain, presence: true, format: { with: /\A[a-z0-9\-\.]+\z/i }
  validates :aws_access_key_id, presence: true
  validates :aws_secret_access_key, presence: true
  validates :route53_hosted_zone_id, presence: true

  def self.instance
    first_or_create(primary_key: 'singleton')
  end

  def needs_update?
    last_update.nil? ||
    last_update < update_interval.seconds.ago ||
    current_ip != fetch_current_ip
  end

  def update_dns_record!
    new_ip = fetch_current_ip
    return false if current_ip == new_ip

    if Route53Service.update_record(self, new_ip)
      update!(current_ip: new_ip, last_update: Time.current)
      CaddyConfigService.regenerate_config
      true
    else
      false
    end
  end

  private

  def fetch_current_ip
    # Multiple IP detection services for reliability
    services = [
      'https://api.ipify.org',
      'https://checkip.amazonaws.com',
      'https://icanhazip.com'
    ]

    services.each do |service|
      begin
        response = Net::HTTP.get_response(URI(service))
        return response.body.strip if response.code == '200'
      rescue
        next
      end
    end

    nil
  end
end

# app/models/project.rb additions
class Project < ApplicationRecord
  # ...existing code...

  validates :subdomain, format: { with: /\A[a-z0-9\-]+\z/i }, allow_blank: true
  validates :subdomain, uniqueness: true, allow_blank: true
  validates :custom_domain, format: { with: /\A[a-z0-9\-\.]+\z/i }, allow_blank: true

  after_save :regenerate_caddy_config, if: :subdomain_changed?
  after_destroy :regenerate_caddy_config

  def full_domain
    return custom_domain if custom_domain.present?
    return nil if subdomain.blank?

    settings = DdnsSettings.instance
    "#{subdomain}.#{settings.base_domain}"
  end

  def url
    return nil unless full_domain
    protocol = ssl_enabled? ? 'https' : 'http'
    "#{protocol}://#{full_domain}"
  end

  private

  def regenerate_caddy_config
    CaddyConfigService.regenerate_config
  end
end
```

### Phase 3: AWS Route53 Integration

```ruby
# app/services/route53_service.rb
require 'aws-sdk-route53'

class Route53Service
  def self.update_record(ddns_settings, ip_address)
    client = Aws::Route53::Client.new(
      access_key_id: ddns_settings.aws_access_key_id,
      secret_access_key: ddns_settings.aws_secret_access_key,
      region: ddns_settings.aws_region
    )

    # Update the A record for the base domain and wildcard
    change_batch = {
      changes: [
        {
          action: 'UPSERT',
          resource_record_set: {
            name: ddns_settings.base_domain,
            type: 'A',
            ttl: 300,
            resource_records: [{ value: ip_address }]
          }
        },
        {
          action: 'UPSERT',
          resource_record_set: {
            name: "*.#{ddns_settings.base_domain}",
            type: 'A',
            ttl: 300,
            resource_records: [{ value: ip_address }]
          }
        }
      ]
    }

    response = client.change_resource_record_sets(
      hosted_zone_id: ddns_settings.route53_hosted_zone_id,
      change_batch: change_batch
    )

    Rails.logger.info "Route53 DNS updated: #{response.change_info.id}"
    true
  rescue Aws::Route53::Errors::ServiceError => e
    Rails.logger.error "Route53 update failed: #{e.message}"
    false
  end
end

# app/services/caddy_config_service.rb
class CaddyConfigService
  CADDYFILE_PATH = Rails.root.join('data', 'caddy', 'Caddyfile')

  def self.regenerate_config
    config = generate_caddyfile
    ensure_directory_exists
    File.write(CADDYFILE_PATH, config)
    reload_caddy
  end

  private

  def self.generate_caddyfile
    settings = DdnsSettings.instance
    projects = Project.where.not(subdomain: nil)

    config = []

    # Global options
    config << "{\n  email admin@#{settings.base_domain}\n}\n\n"

    # Main domain redirect
    config << "#{settings.base_domain} {\n"
    config << "  respond \"Tugboat - Container Management Platform\"\n"
    config << "}\n\n"

    # Project subdomains
    projects.each do |project|
      next unless project.subdomain.present? && project.status == 'running'

      domain = project.custom_domain.presence || "#{project.subdomain}.#{settings.base_domain}"
      config << "#{domain} {\n"
      config << "  reverse_proxy localhost:#{project.external_port}\n"
      config << "}\n\n"
    end

    config.join
  end

  def self.ensure_directory_exists
    FileUtils.mkdir_p(File.dirname(CADDYFILE_PATH))
  end

  def self.reload_caddy
    # Reload Caddy configuration
    system('docker exec tugboat-caddy caddy reload --config /etc/caddy/Caddyfile')
  end
end

# app/jobs/ddns_update_job.rb
class DdnsUpdateJob < ApplicationJob
  queue_as :default

  def perform
    settings = DdnsSettings.instance
    return unless settings.needs_update?

    if settings.update_dns_record!
      Rails.logger.info "DDNS updated successfully: #{settings.current_ip}"
    else
      Rails.logger.error "DDNS update failed"
    end
  end
end
```

### Phase 4: Docker Compose Integration

```yaml
# docker-compose.yml updates
services:
  web:
    # ...existing config...
    depends_on:
      - db
      - redis
      - caddy

  caddy:
    image: caddy:2-alpine
    container_name: tugboat-caddy
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./data/caddy/Caddyfile:/etc/caddy/Caddyfile
      - ./data/caddy/data:/data
      - ./data/caddy/config:/config
    restart: unless-stopped
    networks:
      - tugboat-network

  # Scheduled DDNS updates
  ddns-cron:
    image: alpine:latest
    container_name: tugboat-ddns-cron
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    command: |
      sh -c "
        apk add --no-cache curl docker-cli &&
        echo '*/5 * * * * curl -X POST http://web:3000/api/ddns/update' | crontab - &&
        crond -f
      "
    depends_on:
      - web
    restart: unless-stopped
    networks:
      - tugboat-network

networks:
  tugboat-network:
    driver: bridge
```

### Phase 4: Configuration Management

```ruby
# app/services/ddns_config_service.rb
class DdnsConfigService
  CONFIG_PATH = Rails.root.join('data', 'ddns', 'config.json')

  def self.generate_config
    projects = Project.where(ddns_enabled: true)

    config = {
      settings: projects.map(&:ddns_configuration).compact
    }

    ensure_directory_exists
    File.write(CONFIG_PATH, JSON.pretty_generate(config))
    reload_ddns_service
  end

  private

  def self.ensure_directory_exists
    FileUtils.mkdir_p(File.dirname(CONFIG_PATH))
  end

  def self.reload_ddns_service
    # Restart the DDNS container to pick up new config
    system('docker restart tugboat-ddns')
  end
end

# app/jobs/ddns_update_job.rb
class DdnsUpdateJob < ApplicationJob
  def perform(project)
    DdnsConfigService.generate_config
  end
end
```

### Phase 5: User Interface

```erb
<!-- app/views/projects/_ddns_form.html.erb -->
<div class="space-y-4">
  <div class="flex items-center">
    <%= form.check_box :ddns_enabled, class: "mr-2" %>
    <%= form.label :ddns_enabled, "Enable Dynamic DNS" %>
  </div>

  <div id="ddns-config" style="<%= 'display: none;' unless @project.ddns_enabled? %>">
    <div>
      <%= form.label :domain, "Domain" %>
      <%= form.text_field :domain, placeholder: "app.example.com", class: "w-full border rounded px-3 py-2" %>
    </div>

    <div>
      <%= form.label :ddns_provider, "DNS Provider" %>
      <%= form.select :ddns_provider,
          options_from_collection_for_select(DdnsProvider.active, :name, :display_name, @project.ddns_provider),
          { prompt: "Select a provider" },
          { class: "w-full border rounded px-3 py-2" } %>
    </div>

    <div id="provider-config">
      <!-- Dynamic provider-specific configuration fields -->
    </div>
  </div>
</div>

<script>
  document.addEventListener('DOMContentLoaded', function() {
    const checkbox = document.querySelector('#project_ddns_enabled');
    const config = document.querySelector('#ddns-config');

    checkbox.addEventListener('change', function() {
      config.style.display = this.checked ? 'block' : 'none';
    });
  });
</script>
```

## Benefits

1. **Flexibility** - Support for 50+ DNS providers via ddns-updater
2. **Reliability** - Battle-tested DDNS engine
3. **Integration** - Seamless Rails interface
4. **Automation** - Automatic DNS updates when projects start/stop
5. **Monitoring** - Built-in health checks and web UI
6. **Scalability** - Can handle multiple projects and domains

## Next Steps

1. Create database migrations for DDNS fields
2. Add DDNS service to docker-compose.yml
3. Implement Rails models and services
4. Create user interface for DDNS configuration
5. Add automated DNS updates to project lifecycle
6. Test with popular providers (Cloudflare, Route53, etc.)

## Security Considerations

- Store API tokens encrypted in the database
- Validate domain ownership before allowing DDNS setup
- Rate limit DNS update requests
- Audit log for DNS changes
- Secure the DDNS web UI (authentication proxy)
