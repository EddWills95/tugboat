class Project < ApplicationRecord
  def container_name
    "tugboat-#{name.downcase.gsub(/[^a-z0-9\-_]/, '_')}-#{id}"
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
end
