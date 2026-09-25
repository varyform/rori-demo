require "test_helper"

class ServicesControllerTest < ActionDispatch::IntegrationTest
  test "index lists services" do
    get_in_window services_path

    assert_response :success
    assert_equal [ "Services", "services" ], window_meta.values_at("title", "key")
    assert_select "td a", text: "api-gateway"
  end

  test "the form is a large tiled window, not a modal" do
    get_in_window new_service_path

    assert_equal({ "size" => "lg", "mode" => "tile", "key" => "services", "title" => "New service" }, window_meta)
    assert_select "fieldset.form-section", count: 5
    assert_select "select#service_region option[selected][value=fra1]"
  end

  test "create redirects to the service" do
    assert_difference -> { Service.count } do
      post services_path, params: { service: { name: "mailer", region: "lon1", size: "small", replicas: 2,
        branch: "main", health_check_path: "/up", user_id: users(:ada).id, environment: "SMTP_HOST=mail\n" } }
    end

    assert_redirected_to service_path(Service.last)
    assert_equal %w[ SMTP_HOST ], Service.last.environment_keys
  end

  test "invalid submissions re-render every section with the typed values and errors" do
    post services_path, params: { service: { name: "Bad Name", region: "fra1", size: "small", replicas: 50,
      branch: "main", health_check_path: "/up", user_id: users(:oleh).id, environment: "OK=1\nnot an assignment" } },
      headers: { "Turbo-Frame" => "win_test" }

    assert_response :unprocessable_entity
    assert_equal "New service", window_meta["title"]
    assert_select "#service_name[value=?]", "Bad Name"
    assert_select ".service_name .error", text: /lowercase letters/
    assert_select ".service_replicas .error"
    assert_select ".service_environment .error", text: /not an assignment/
  end

  test "edit is titled after the saved name" do
    get_in_window edit_service_path(services(:gateway))

    assert_equal "Edit api-gateway", window_meta["title"]
  end

  test "show lists environment keys but not values" do
    get_in_window service_path(services(:gateway))

    assert_select "code", text: "DATABASE_URL"
    assert_no_match "postgres://", response.body
  end

  test "update and destroy" do
    patch service_path(services(:worker)), params: { service: { replicas: 4 } }
    assert_redirected_to service_path(services(:worker))
    assert_equal 4, services(:worker).reload.replicas

    assert_difference -> { Service.count }, -1 do
      delete service_path(services(:worker))
    end
    assert_redirected_to services_path
  end
end
