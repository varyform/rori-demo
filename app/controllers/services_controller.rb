class ServicesController < ApplicationController
  before_action :set_service, only: %i[ show edit update destroy ]

  def index
    @services = Service.includes(:user).order(:name)
  end

  def show
  end

  def new
    @service = Service.new(region: Service::REGIONS.first)
  end

  def edit
  end

  def create
    @service = Service.new(service_params)

    if @service.save
      redirect_to @service
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @service.update(service_params)
      redirect_to @service
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @service.destroy!
    redirect_to services_path, status: :see_other
  end

  private
    def set_service
      @service = Service.find(params.expect(:id))
    end

    def service_params
      params.expect(service: [ :name, :repository, :branch, :region, :size, :replicas, :autoscale,
        :health_check_path, :environment, :notes, :user_id ])
    end
end
