# app/services/docker_service.rb
require "docker"

class DockerService
  def self.get_container(name)
    Docker::Container.get(name)
  rescue Docker::Error::NotFoundError
    Rails.logger.error "Container #{name} not found."
    nil
  end

  def self.container_status(name)
    container = get_container(name)
    if container.nil?
      return nil
    end

    container.info["State"]["Status"]
  end

  def self.start_container(name)
    container = get_container(name)
    container.start
    true
  end

  def self.deploy_container(name, image, internal_port, external_port)
    options = {
      "name" => name,
      "Image" => image
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
        }
      }
    end

    container = Docker::Container.create(options)
    container.start
  end

  def self.stop_container(name)
    container = get_container(name)
    container.stop
    true
  end

  def self.container_logs(name, tail: 100)
    container = get_container(name)
    container.logs(stdout: true, stderr: true, tail: tail)
  rescue Docker::Error::NotFoundError
    "Logs unavailable. Container not found."
  end

  def self.stream_container_logs(name, tail: 100)
    container = get_container(name)
    return unless container
    begin
      container.streaming_logs(stdout: true, stderr: true, tail: tail) do |stream, chunk|
        yield "#{stream}: #{chunk}"
      end
    rescue Docker::Error::NotFoundError
      yield "Logs unavailable. Container not found."
    end
  end


  def self.remove_container(name)
    container = get_container(name)
    container.delete(force: true)
    true
  rescue Docker::Error::NotFoundError
    false
  end

  def self.container_exists?(name)
    !!get_container(name)
  end




  # Add more Docker actions as needed, always sanitising input
end
