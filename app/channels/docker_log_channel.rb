# app/channels/docker_log_channel.rb
class DockerLogChannel < ApplicationCable::Channel
  def subscribed
    @container_name = params[:container]
    stream_from "docker_logs_#{@container_name}"

    @thread = Thread.new do
      container = Docker::Container.get(@container_name)

      container.streaming_logs(
        stdout: true,
        stderr: true,
        follow: true,
        tail: "50" # or "all"
      ) do |_stream, chunk|
        chunk.each_line do |line|
          ActionCable.server.broadcast("docker_logs_#{@container_name}", { log: line.strip })
        end
      end
    rescue => e
      Rails.logger.error "Error streaming logs: #{e.message}"
    end
  end

  def unsubscribed
    @thread&.kill
  end
end
