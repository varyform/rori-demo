# The public demo's nightly reset (config/recurring.yml, production only):
# whatever visitors created, edited or deleted goes, and the seeds come back.
class DemoResetJob < ApplicationJob
  def perform
    ActiveRecord::Base.transaction do
      [ Service, Project, User ].each(&:delete_all)
      Rails.application.load_seed
    end
  end
end
