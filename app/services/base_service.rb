require "singleton"

class BaseService
  include Singleton

  def service_name
    "base"
  end

  def docker_name
    "tugboat-#{service_name}"
  end

  def start
    DockerService.start_container(docker_name)
  end

  def stop
    DockerService.stop_container(docker_name)
  end

  def status
    DockerService.container_status(docker_name)
  end
end
