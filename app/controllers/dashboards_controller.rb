class DashboardsController < ApplicationController
  def show
    @user_count = User.count
    @status_counts = Project.group(:status).count
    @recent_projects = Project.includes(:user).order(updated_at: :desc).limit(8)
  end
end
