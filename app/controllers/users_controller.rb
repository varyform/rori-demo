class UsersController < ApplicationController
  before_action :set_user, only: %i[ show edit update destroy ]

  def index
    @users = User.includes(:projects).order(:name)
  end

  def show
    @projects = @user.projects.order(updated_at: :desc)
  end

  def new
    @user = User.new
  end

  def edit
  end

  def create
    @user = User.new(user_params)

    if @user.save
      redirect_to @user
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @user.update(user_params)
      redirect_to @user
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @user.destroy!
    redirect_to users_path, status: :see_other
  end

  private
    def set_user
      @user = User.find(params.expect(:id))
    end

    def user_params
      params.expect(user: [ :name, :email ])
    end
end
