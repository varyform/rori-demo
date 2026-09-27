require "test_helper"

class DemoResetJobTest < ActiveJob::TestCase
  SMALL = { users: 4, projects: 6, services: 3 }

  test "puts the seeds back, with the scale data on top, whatever visitors did" do
    User.create!(name: "Visitor", email: "visitor@example.com").projects.create!(name: "Graffiti", status: "idea")
    services(:gateway).update!(replicas: 20)
    projects(:desk).destroy

    DemoResetJob.perform_now(scale: SMALL)

    # Scale rows are recognisable: @scale.example emails, numbered names.
    assert_equal %w[ ada@example.com oleh@example.com ], User.pluck(:email).grep_v(/@scale\.example\z/).sort
    assert_equal [ "Analytical Engine", "Blog", "Desk UI", "Dotfiles" ], Project.pluck(:name).grep_v(/ \d+\z/).sort
    assert_equal 3, Service.find_by!(name: "api-gateway").replicas
    assert_equal [ 2 + 4, 4 + 6, 3 + 3 ], [ User.count, Project.count, Service.count ]
  end

  test "grows the same world every night" do
    world = -> { [ User.order(:id).pluck(:name), Project.order(:id).pluck(:name, :status), Service.order(:id).pluck(:region, :replicas) ] }
    DemoResetJob.perform_now(scale: SMALL)
    first = world.()

    DemoResetJob.perform_now(scale: SMALL)

    assert_equal first, world.()
  end

  test "plants ScaleSeed's full volume by default" do
    DemoResetJob.perform_now

    assert_equal 2 + ScaleSeed::COUNTS[:users], User.count
    assert_equal 4 + ScaleSeed::COUNTS[:projects], Project.count
    assert_equal 3 + ScaleSeed::COUNTS[:services], Service.count
  end

  test "leaves Rails' own bookkeeping alone" do
    DemoResetJob.perform_now(scale: SMALL)

    assert ActiveRecord::Base.connection_pool.schema_migration.versions.any?
    assert_equal "test", ActiveRecord::Base.connection_pool.internal_metadata[:environment]
  end
end
