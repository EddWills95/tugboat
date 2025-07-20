class Project < ApplicationRecord
  def container_name
    "tugboat-#{id}"
  end

  def live_status
    result = `docker inspect -f '{{.State.Status}}' #{container_name} 2>/dev/null`.strip
    result.present? ? result : "not created"
  end

  def is_running
    live_status == "running"
  end
end
