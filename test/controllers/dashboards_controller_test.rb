require "test_helper"

class DashboardsControllerTest < ActionDispatch::IntegrationTest
  test "asks for fullscreen in its own workspace" do
    get_in_window dashboard_path

    assert_response :success
    assert_equal [ "fullscreen", "overview", "Dashboard" ], window_meta.values_at("mode", "workspace", "title")
    assert_select ".stats__item", count: 1 + Project::STATUSES.size
  end
end
