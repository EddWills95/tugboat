class ProjectsController < ApplicationController
  before_action :set_project, only: %i[ show edit update destroy deploy start stop logs refresh_logs ]

  # GET /projects or /projects.json
  def index
    @projects = Project.all
  end

  # GET /projects/1 or /projects/1.json
  def show
    @status = DockerService.container_status(@project.container_name)
    if @status == "running"
      @logs = DockerService.container_logs(@project.container_name)
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
    container_name = @project.container_name
    port_mapping = @project.port_mapping
    image = @project.docker_image
    DockerService.remove_container(container_name)
    success = DockerService.run_container(container_name, port_mapping, image)
    @project.update(status: success ? "running" : "error")
    redirect_to @project, notice: success ? "Deployment started!" : "Deployment failed!"
  end

  def start
    success = DockerService.start_container(@project.container_name)
    redirect_to @project, notice: success ? "Project started successfully!" : "Failed to start project."
  end

  def stop
    success = DockerService.stop_container(@project.container_name)
    redirect_to @project, notice: success ? "Project stopped successfully!" : "Failed to stop project."
  end

  def logs
    @logs = DockerService.container_logs(@project.container_name)
  rescue => e
    @logs = "Failed to fetch logs: #{e.message}"
  end

  def container_status(container_name)
    DockerService.container_status(container_name)
  end

  def refresh_logs
    @logs = if @project.live_status == "running"
              DockerService.container_logs(@project.container_name)
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
      success = DockerService.remove_container(@project.container_name)
      redirect_to @projects, notice: (!success ? "Failed to start project." : nil)
    end

    def should_redeploy?
      return false if @project.status == "not_deployed"
      DockerService.container_exists?(@project.container_name)
    end

    def redeploy_container
      container_name = @project.container_name
      port_mapping = @project.port_mapping
      image = @project.docker_image
      DockerService.remove_container(container_name)
      success = DockerService.run_container(container_name, port_mapping, image)
      @project.update(status: success ? "running" : "error")
      success
    end
end
