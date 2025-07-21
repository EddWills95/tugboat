
class BaseService
  def self.service_name
    "base"
  end

  def self.docker_name
    "tugboat-#{service_name}"
  end

  def self.start
    DockerService.start_container(docker_name)
  end

  def self.stop
    DockerService.stop_container(docker_name)
  end

  def self.status
    status = DockerService.container_status(docker_name)
    puts status
    status
  end
end
