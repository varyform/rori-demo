require "test_helper"
require "rake"

class SeedScaleTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("db:seed:scale")
    Rake::Task["db:seed:scale"].reenable
  end

  test "adds the requested volumes, and every row would pass validation" do
    assert_difference -> { User.count } => 12, -> { Project.count } => 40, -> { Service.count } => 15 do
      run_scale USERS: 12, PROJECTS: 40, SERVICES: 15
    end

    # insert_all skips validations, so check the generated data would pass them.
    [ User, Project, Service ].each do |model|
      invalid = model.all.reject(&:valid?)
      assert_empty invalid.map { [ it.id, it.errors.full_messages ] }, "#{model} rows from db:seed:scale are invalid"
    end
  end

  test "is re-runnable: a second run adds on top without unique-key collisions" do
    run_scale USERS: 5, PROJECTS: 5, SERVICES: 5
    Rake::Task["db:seed:scale"].reenable

    assert_difference -> { User.count } => 5, -> { Service.count } => 5 do
      run_scale USERS: 5, PROJECTS: 5, SERVICES: 5
    end
  end

  private
    def run_scale(**counts)
      previous = counts.to_h { |key, _| [ key.to_s, ENV[key.to_s] ] }
      counts.each { |key, value| ENV[key.to_s] = value.to_s }
      capture_io { Rake::Task["db:seed:scale"].invoke }
    ensure
      previous.each { |key, value| ENV[key] = value }
    end
end
