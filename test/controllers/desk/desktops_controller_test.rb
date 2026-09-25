require "test_helper"

class Desk::DesktopsControllerTest < ActionDispatch::IntegrationTest
  test "root is a blank desk with no window" do
    get root_path

    assert_response :success
    assert_select "main.viewport .wallpaper"
    assert_select "main.viewport dialog.win", count: 0
    assert_select "template[data-desk-target=template] dialog.win"
    assert_select "body[data-desk-palette-root-value=?]", desk_commands_path
    keymap = JSON.parse(css_select("body").first["data-desk-keymap-value"])
    assert_equal Desk.resolved_keymap.stringify_keys, keymap
    assert_select "dialog.palette turbo-frame#commands:not([src])"
  end
end
