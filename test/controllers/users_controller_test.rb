require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "full page load renders the desk with the page as its first window" do
    get users_path

    assert_response :success
    assert_select "main.rori-viewport .rori-floating > dialog.rori-win[open] turbo-frame#win_main[src=?][complete]", users_path
    assert_equal "users", window_meta(frame: "win_main")["key"]
  end

  test "index in a window asks for a large window keyed by controller" do
    get_in_window users_path

    assert_response :success
    assert_select "main.rori-viewport", count: 0
    assert_equal({ "size" => "lg", "mode" => "tile", "key" => "users", "title" => "Users" }, window_meta)
  end

  test "show is titled after the user and shares the users key" do
    get_in_window user_path(users(:oleh))

    assert_equal [ "Oleh", "users" ], window_meta.values_at("title", "key")
    assert_select "a[href=?][data-turbo-frame=_top]", project_path(projects(:desk))
  end

  test "new opens as an unkeyed modal" do
    get_in_window new_user_path

    assert_equal({ "size" => "sm", "mode" => "modal", "key" => nil, "title" => "New user" }, window_meta)
  end

  test "create redirects to the user" do
    assert_difference -> { User.count } do
      post users_path, params: { user: { name: "Grace", email: "grace@example.com" } }, headers: { "Turbo-Frame" => "win_test" }
    end

    assert_redirected_to user_path(User.last)
  end

  test "invalid create re-renders the modal inside the requesting frame" do
    post users_path, params: { user: { name: "", email: users(:oleh).email } }, headers: { "Turbo-Frame" => "win_test" }

    assert_response :unprocessable_entity
    assert_equal [ "modal", "New user" ], window_meta.values_at("mode", "title")
    assert_select ".user_name .error"
    assert_select ".user_email .error"
  end

  test "update redirects to the user" do
    patch user_path(users(:ada)), params: { user: { name: "Ada King" } }

    assert_redirected_to user_path(users(:ada))
    assert_equal "Ada King", users(:ada).reload.name
  end

  test "destroy removes the user and their projects" do
    assert_difference -> { User.count } => -1, -> { Project.count } => -1 do
      delete user_path(users(:oleh))
    end

    assert_redirected_to users_path
  end
end
