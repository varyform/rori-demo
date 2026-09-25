require "test_helper"

class Desk::Commands::UiControllerTest < ActionDispatch::IntegrationTest
  teardown { Desk.wallpapers = false }

  test "the root palette nests UI, which nests theme and wallpaper" do
    get desk_commands_path
    assert_select "li[data-children=?]", desk_commands_ui_path, text: /UI/

    get desk_commands_ui_path
    assert_select "li[data-children=?]", desk_commands_themes_path, text: /Theme/
    assert_select "li[data-children=?]", desk_commands_wallpapers_path, count: 0

    Desk.wallpapers = true
    get desk_commands_ui_path
    assert_select "li[data-children=?]", desk_commands_wallpapers_path, text: /Wallpaper/
  end

  test "wallpaper modes are commands with the current one marked" do
    cookies[Desk.wallpaper_cookie] = "cover"
    get desk_commands_wallpapers_path

    assert_select "li[data-desk-action=wallpaper]", count: 3
    assert_select "li[data-param=cover][data-current]", text: /Cover bars/
    assert_select "li[data-param=safe]:not([data-current])"
  end
end
