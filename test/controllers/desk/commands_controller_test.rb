require "test_helper"

class Desk::CommandsControllerTest < ActionDispatch::IntegrationTest
  test "lists route, record and desk commands in the palette frame" do
    get desk_commands_path, headers: { "Turbo-Frame" => "commands" }

    assert_response :success
    assert_select "turbo-frame#commands li.palette__item[data-url=?]", new_user_path, text: /New user/
    assert_select "li.palette__item[data-url=?]", user_path(users(:ada)), text: /Ada Lovelace/
    assert_select "li.palette__item[data-desk-action=overview]"
    assert_select "li.palette__item[data-source=workspaces]", text: /Move column to workspace/
    assert_select "li[data-desk-action=close_window] kbd.palette__shortcut", text: "⌥W"
    assert_select "li[data-desk-action=reopen_window][data-shortcut=?]", "⌥⇧T"
    assert_select "li[data-desk-action=new_workspace] kbd", count: 0
    assert_select "li.palette__item[data-url$='/edit']", count: 0, message: "routes with params never become commands"
  end

  test "shortcuts follow the native shell's modifier" do
    get desk_commands_path, headers: { "User-Agent" => "Mozilla/5.0 (Macintosh) AppleWebKit/605.1.15 (KHTML, like Gecko) DeskApp/0.1" }

    assert_select "li[data-desk-action=close_window] kbd", text: "⌘W"
    assert_select "li[data-desk-action=center_column] kbd", text: "⌘⇧C"
  end
end
