require "test_helper"

class DesktopsControllerTest < ActionDispatch::IntegrationTest
  test "root is a blank desk with no window" do
    get root_path

    assert_response :success
    assert_select "main.viewport .wallpaper"
    assert_select "main.viewport dialog.win", count: 0
    assert_select "template[data-desk-target=template] dialog.win"
    assert_select "dialog.palette turbo-frame#commands[src=?][loading=lazy]", commands_path
  end
end
