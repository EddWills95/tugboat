
class BaseService
  DOCKER_NAME = "tugboat-caddy"

  def self.start
    DockerService.start_container(DOCKER_NAME)
  end

  def self.stop
    DockerService.stop_container(DOCKER_NAME)
  end

  def self.status
    DockerService.container_status("tugboat-caddy")
  end
end
