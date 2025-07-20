class DdnsService
  def self.toggle_service!(enabled)
    settings = DdnsSettings.instance
    settings.update!(enabled: enabled)
  end

  def self.start_service!
    settings = DdnsSettings.instance
    return false unless settings.enabled? && settings.configured?

    settings.start_container!
  end

  def self.stop_service!
    settings = DdnsSettings.instance
    settings.stop_container!
  end

  def self.restart_service!
    settings = DdnsSettings.instance
    return false unless settings.enabled? && settings.configured?

    settings.restart_container!
  end

  def self.status
    DdnsSettings.instance.status
  end

  def self.container_logs(lines: 50)
    # Get the last N lines of logs from the ddns-updater container
    `docker logs --tail #{lines} tugboat-ddns 2>&1`.strip
  rescue
    "Unable to retrieve container logs"
  end

  def self.container_stats
    # Get basic stats about the container
    if DdnsSettings.instance.container_running?
      stats = `docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" tugboat-ddns 2>/dev/null`.strip
      stats.lines[1..-1].join("\n") if stats.lines.length > 1
    else
      "Container not running"
    end
  rescue
    "Unable to retrieve container stats"
  end
end
