# app/services/docker_service.rb
require "docker"

class DockerService
  # Only allow safe container names: letters, numbers, dashes, underscores
  SAFE_NAME_REGEX = /\A[a-zA-Z0-9_-]+\z/

  def self.sanitise_name(name)
    raise ArgumentError, "Invalid container name" unless name.match?(SAFE_NAME_REGEX)
    name
  end

  def self.container_status(name)
    name = sanitise_name(name)
    container = Docker::Container.get(name)
    container.info["State"]
  rescue Docker::Error::NotFoundError
    "not_found"
  end

  def self.stop_container(name)
    name = sanitise_name(name)
    container = Docker::Container.get(name)
    container.stop
    true
  rescue Docker::Error::NotFoundError
    false
  end

  def self.container_logs(name, tail: 100)
    name = sanitise_name(name)
    container = Docker::Container.get(name)
    container.logs(stdout: true, stderr: true, tail: tail)
  rescue Docker::Error::NotFoundError
    "Logs unavailable. Container not found."
  end

  def self.run_container(name, port_mapping, image)
    name = sanitise_name(name)
    # Only allow safe image names and port mappings
    raise ArgumentError, "Invalid image name" unless image.match?(SAFE_NAME_REGEX)
    raise ArgumentError, "Invalid port mapping" unless port_mapping.match?(/\A[0-9]+:[0-9]+\z/)
    Docker::Container.create("name" => name, "Image" => image, "HostConfig" => { "PortBindings" => { port_mapping.split(":")[1] => [ { "HostPort" => port_mapping.split(":")[0] } ] } })
    container = Docker::Container.get(name)
    container.start
    true
  rescue Docker::Error::NotFoundError, Docker::Error::ServerError, ArgumentError
    false
  end

  def self.remove_container(name)
    name = sanitise_name(name)
    container = Docker::Container.get(name)
    container.delete(force: true)
    true
  rescue Docker::Error::NotFoundError
    false
  end

  def self.start_container(name)
    name = sanitise_name(name)
    container = Docker::Container.get(name)
    container.start
    true
  rescue Docker::Error::NotFoundError
    false
  end

  def self.container_exists?(name)
    name = sanitise_name(name)
    Docker::Container.get(name)
    true
  rescue Docker::Error::NotFoundError
    false
  end

  # Add more Docker actions as needed, always sanitising input
end
