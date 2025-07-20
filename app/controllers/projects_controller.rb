class ProjectsController < ApplicationController
  before_action :set_project, only: %i[ show edit update destroy ]

  # GET /projects or /projects.json
  def index
    @projects = Project.all
  end

  # GET /projects/1 or /projects/1.json
  def show
    @project = Project.find(params[:id])
    @status = container_status(@project.container_name)

    if @status == :running
      @logs = `docker logs --tail 100 #{Shellwords.escape(@project.container_name)} 2>&1`
    else
      @logs = "Logs unavailable. Container is not running."
    end
  end

  # GET /projects/new
  def new
    @project = Project.new
  end

  # GET /projects/1/edit
  def edit
  end

  # POST /projects or /projects.json
  def create
    @project = Project.new(project_params)

    respond_to do |format|
      if @project.save
        format.html { redirect_to @project, notice: "Project was successfully created." }
        format.json { render :show, status: :created, location: @project }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /projects/1 or /projects/1.json
  def update
    respond_to do |format|
      if @project.update(project_params)
        # Automatically redeploy the container if it was previously deployed
        if should_redeploy?
          redeploy_container
          format.html { redirect_to @project, notice: "Project was successfully updated and redeployed!" }
        else
          format.html { redirect_to @project, notice: "Project was successfully updated." }
        end
        format.json { render :show, status: :ok, location: @project }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /projects/1 or /projects/1.json
  def destroy
    if container_status(@project.container_name) == :running
      @project.stop
    end

    @project.destroy!

    respond_to do |format|
      format.html { redirect_to projects_path, status: :see_other, notice: "Project was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  def deploy
    @project = Project.find(params[:id])
    container_name = @project.container_name
    port_mapping = @project.port_mapping
    image = @project.docker_image

    # Stop and remove any existing container
    system("docker rm -f #{container_name} > /dev/null 2>&1")

    # Run the new container with proper port mapping
    success = system("docker run -d --name #{container_name} -p #{port_mapping} #{image}")

    @project.update(status: success ? "running" : "error")

    redirect_to @project, notice: success ? "Deployment started!" : "Deployment failed!"
  end

  def start
    @project = Project.find(params[:id])
    success = @project.start
    redirect_to @project, notice: success ? "Project started successfully!" : "Failed to start project."
  end

  def stop
    @project = Project.find(params[:id])
    success = @project.stop
    redirect_to @project, notice: success ? "Project stopped successfully!" : "Failed to stop project."
  end

  def logs
    @project = Project.find(params[:id])
    container_name = @project.container_name

    @logs = `docker logs --tail 100 #{container_name} 2>&1`
  rescue => e
    @logs = "Failed to fetch logs: #{e.message}"
  end

  def container_status(container_name)
    info = `docker ps -a --filter "name=#{container_name}" --format "{{.Status}}"`.strip

    return :not_found if info.empty?
    return :running if info.start_with?("Up")
    :stopped
  end

  def refresh_logs
    @project = Project.find(params[:id])
    @logs = if @project.live_status == "running"
              `docker logs --tail 100 #{Shellwords.escape(@project.container_name)} 2>&1`
    else
              "Logs unavailable. Container is not running."
    end
    render partial: "logs", locals: { logs: @logs }
  end


  private
    def set_project
      @project = Project.find(params[:id])
    end

    def project_params
      params.require(:project).permit(:name, :docker_image, :port, :internal_port, :external_port, :status)
    end

    def delete_docker_container
      container_name = "tugboat-#{@project.id}"
      success = system("docker rm -f #{container_name} > /dev/null 2>&1")
      redirect_to @projects, notice: if !success then "Failed to start project." end
    end

    def should_redeploy?
      # Only redeploy if the container exists (has been deployed before)
      # and the project has deployment-affecting changes
      return false if @project.status == "not_deployed"

      # Check if the container exists
      container_exists = system("docker inspect #{@project.container_name} > /dev/null 2>&1")
      container_exists
    end

    def redeploy_container
      container_name = @project.container_name
      port_mapping = @project.port_mapping
      image = @project.docker_image

      # Stop and remove existing container
      system("docker rm -f #{container_name} > /dev/null 2>&1")

      # Run the new container with updated configuration
      success = system("docker run -d --name #{container_name} -p #{port_mapping} #{image}")

      @project.update(status: success ? "running" : "error")
      success
    end
end
