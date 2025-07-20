class ProjectsController < ApplicationController
  before_action :set_project, only: %i[ show edit update destroy ]

  # GET /projects or /projects.json
  def index
    @projects = Project.all
  end

  # GET /projects/1 or /projects/1.json
  def show
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
        format.html { redirect_to @project, notice: "Project was successfully updated." }
        format.json { render :show, status: :ok, location: @project }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /projects/1 or /projects/1.json
  def destroy
    @project.destroy!

    respond_to do |format|
      format.html { redirect_to projects_path, status: :see_other, notice: "Project was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  def deploy
    @project = Project.find(params[:id])
    container_name = "tugboat-#{@project.id}"
    port = @project.port
    image = @project.docker_image

    # Stop and remove any existing container
    system("docker rm -f #{container_name} > /dev/null 2>&1")

    # Run the new container
    success = system("docker run -d --name #{container_name} -p #{port}:80 #{image}")

    @project.update(status: success ? "running" : "error")

    redirect_to @project, notice: success ? "Deployment started!" : "Deployment failed!"
  end

  def start
    @project = Project.find(params[:id])
    container_name = "tugboat-#{@project.id}"
    success = system("docker start #{container_name} > /dev/null 2>&1")
    @project.update(status: success ? "running" : "error")
    redirect_to @project, notice: if !success then "Failed to start project." end
  end

  def stop
    @project = Project.find(params[:id])
    container_name = "tugboat-#{@project.id}"
    success = system("docker stop #{container_name} > /dev/null 2>&1")
    @project.update(status: success ? "stopped" : "error")
    redirect_to @project, notice: if !success then "Failed to start project." end
  end


  private
    # Use callbacks to share common setup or constraints between actions.
    def set_project
      @project = Project.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def project_params
      params.expect(project: [ :name, :docker_image, :port, :status ])
    end
end
