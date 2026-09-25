require "test_helper"

class Desk::CommandsControllerTest < ActionDispatch::IntegrationTest
  test "lists route, record and desk commands in the palette frame" do
    get desk_commands_path, headers: { "Turbo-Frame" => "commands" }

    assert_response :success
    assert_select "turbo-frame#commands li.palette__item[data-url=?]", new_user_path, text: /New user/
    assert_select "li.palette__item[data-url=?]", user_path(users(:ada)), text: /Ada Lovelace/
    assert_select "li.palette__item[data-desk-action=overview]"
    assert_select "li.palette__item[data-url$='/edit']", count: 0, message: "routes with params never become commands"
  end
end
