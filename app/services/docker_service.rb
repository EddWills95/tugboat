# app/services/docker_service.rb
require "docker"
require "singleton"

class DockerService
  include Singleton

  def get_container(name)
    Docker::Container.get(name)
  rescue Docker::Error::NotFoundError
    Rails.logger.error "Container #{name} not found."
    nil
  end

  def container_status(name)
    container = get_container(name)
    if container.nil?
      return "not_found"
    end

    container.info["State"]["Status"]
  rescue => e
    Rails.logger.error "Error getting container status for #{name}: #{e.message}"
    "error"
  end

  def start_container(name)
    container = get_container(name)
    return false unless container

    container.start
    true
  rescue => e
    Rails.logger.error "Error starting container #{name}: #{e.message}"
    false
  end

  def stop_container(name)
    container = get_container(name)
    return false unless container

    container.stop
    true
  rescue => e
    Rails.logger.error "Error stopping container #{name}: #{e.message}"
    false
  end

  def restart_container(name)
    container = get_container(name)
    container.restart
    true
  end

  def deploy_container(name, image, internal_port, external_port)
    # Remove existing container if it exists
    if container_exists?(name)
      remove_container(name)
    end

    options = {
      "name" => name,
      "Image" => image,
      "NetworkMode" => "tugboat-network"
    }

    if internal_port && external_port
      options["ExposedPorts"] = {
        "#{internal_port}/tcp" => {}
      }
      options["HostConfig"] = {
        "PortBindings" => {
          "#{internal_port}/tcp" => [
            {
              "HostPort" => external_port.to_s
            }
          ]
        },
        "NetworkMode" => "tugboat-network"
      }
    end

    container = Docker::Container.create(options)
    container.start
    true
  rescue => e
    Rails.logger.error "Error deploying container #{name}: #{e.message}"
    false
  end

  def remove_container(name)
    container = get_container(name)
    container.delete(force: true)
    true
  rescue Docker::Error::NotFoundError
    false
  end

  def container_exists?(name)
    !!get_container(name)
  end

  def container_logs(name, tail: 100)
    container = get_container(name)
    return "Container not found." unless container

    logs = container.logs(stdout: true, stderr: true, tail: tail)
    logs.force_encoding("UTF-8").encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
  rescue => e
    Rails.logger.error "Error fetching logs for container #{name}: #{e.message}"
    "Error fetching logs."
  end
end
