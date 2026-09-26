require "test_helper"

class Rori::Commands::UiControllerTest < ActionDispatch::IntegrationTest
  teardown { Rori.wallpapers = false }

  test "the root palette nests UI, which nests theme and wallpaper" do
    get rori_commands_path
    assert_select "li[data-children=?]", rori_commands_ui_path, text: /UI/

    get rori_commands_ui_path
    assert_select "li[data-children=?]", rori_commands_themes_path, text: /Theme/
    assert_select "li[data-children=?]", rori_commands_wallpapers_path, count: 0

    Rori.wallpapers = true
    get rori_commands_ui_path
    assert_select "li[data-children=?]", rori_commands_wallpapers_path, text: /Wallpaper/
  end

  test "wallpaper modes are commands with the current one marked" do
    cookies[Rori.wallpaper_cookie] = "cover"
    get rori_commands_wallpapers_path

    assert_select "li[data-rori-action=wallpaper]", count: 3
    assert_select "li[data-param=cover][data-current]", text: /Cover bars/
    assert_select "li[data-param=safe]:not([data-current])"
  end
end
