require "test_helper"

class DemoResetJobTest < ActiveJob::TestCase
  test "puts the seeds back, whatever visitors did" do
    User.create!(name: "Visitor", email: "visitor@example.com").projects.create!(name: "Graffiti", status: "idea")
    services(:gateway).update!(replicas: 20)
    projects(:desk).destroy

    DemoResetJob.perform_now

    assert_equal %w[ ada@example.com oleh@example.com ], User.order(:email).pluck(:email)
    assert_equal [ "Analytical Engine", "Blog", "Desk UI", "Dotfiles" ], Project.order(:name).pluck(:name)
    assert_equal 3, Service.find_by!(name: "api-gateway").replicas
  end
end
