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
    docker_service.start_container(docker_name)
  end

  def stop
    docker_service.stop_container(docker_name)
  end

  def restart
    docker_service.restart_container(docker_name)
  end

  def status
    docker_service.container_status(docker_name)
  end

  private
  def docker_service
    @docker_service ||= DockerService.instance
  end
end
