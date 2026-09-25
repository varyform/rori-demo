require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  test "index asks for the projects workspace" do
    get_in_window projects_path

    assert_response :success
    assert_equal [ "projects", "projects" ], window_meta.values_at("workspace", "key")
  end

  test "show gets a window per record" do
    project = projects(:desk)
    get_in_window project_path(project)

    assert_equal [ "Desk UI", "project_#{project.id}" ], window_meta.values_at("title", "key")
  end

  test "new preselects the owner passed from a user window" do
    get_in_window new_project_path(user_id: users(:ada).id)

    assert_equal "modal", window_meta["mode"]
    assert_select "select#project_user_id option[selected][value=?]", users(:ada).id.to_s
  end

  test "form fields opt out of 1Password" do
    get_in_window new_project_path

    fields = css_select("form.simple_form input, form.simple_form select, form.simple_form textarea").reject { it["type"] == "hidden" }
    assert_equal %w[ project_name project_status project_user_id project_description ], fields.map { it["id"] }
    assert fields.all? { it.key?("data-1p-ignore") }
  end

  test "create redirects to the project" do
    assert_difference -> { Project.count } do
      post projects_path, params: { project: { name: "Notes", status: "idea", user_id: users(:oleh).id } }
    end

    assert_redirected_to project_path(Project.last)
  end

  test "invalid update re-renders the edit modal" do
    patch project_path(projects(:desk)), params: { project: { name: "" } }, headers: { "Turbo-Frame" => "win_test" }

    assert_response :unprocessable_entity
    assert_equal "Edit project", window_meta["title"]
  end

  test "destroy redirects to the list" do
    assert_difference -> { Project.count }, -1 do
      delete project_path(projects(:engine))
    end

    assert_redirected_to projects_path
  end
end
