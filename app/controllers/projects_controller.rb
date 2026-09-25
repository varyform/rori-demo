class ProjectsController < ApplicationController
  before_action :set_project, only: %i[ show edit update destroy ]

  def index
    @projects = Project.includes(:user).order(updated_at: :desc)
  end

  def show
  end

  def new
    @project = Project.new(user_id: params[:user_id])
  end

  def edit
  end

  def create
    @project = Project.new(project_params)

    if @project.save
      redirect_to @project
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @project.update(project_params)
      redirect_to @project
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @project.destroy!
    redirect_to projects_path, status: :see_other
  end

  private
    def set_project
      @project = Project.find(params.expect(:id))
    end

    def project_params
      params.expect(project: [ :name, :status, :description, :user_id ])
    end
end
