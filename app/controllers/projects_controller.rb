class ProjectsController < ApplicationController
  before_action :set_project, only: %i[ show edit update destroy deploy start stop]

  # GET /projects or /projects.json
  def index
    @projects = Project.all
  end

  # GET /projects/1 or /projects/1.json
  def show
    puts @project.inspect

    @needs_deploy = !DockerService.container_exists?(@project.container_name)
    @status = DockerService.container_status(@project.container_name)

    @project_url = "http://#{@project.subdomain}.localhost"

    # @ddns_base_domain = DdnsSettings.instance_values["base_domain"]

    Rails.logger.info "Container status for #{@project.container_name}: #{@status}"
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
    if @project.update(project_params)
      redirect_to @project, notice: "Project was successfully updated."
    else
      render :edit, status: :unprocessable_entity
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
    internal_port = @project.internal_port
    external_port = @project.external_port
    image = @project.docker_image

    success = DockerService.deploy_container(container_name, image, internal_port, external_port)
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

  def container_status(container_name)
    DockerService.container_status(container_name)
  end

  private
    def set_project
      @project = Project.find(params[:id])
    end

    def project_params
      params.require(:project).permit(:name, :docker_image, :port, :internal_port, :external_port, :status, :subdomain)
    end

    def delete_docker_container
      success = DockerService.remove_container(@project.container_name)
      redirect_to @projects, notice: (!success ? "Failed to start project." : nil)
    end

    def should_redeploy?
      return false if @project.status == "not_deployed"
      DockerService.container_exists?(@project.container_name)
    end
end
