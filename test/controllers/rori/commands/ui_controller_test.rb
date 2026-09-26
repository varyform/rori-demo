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

  test "UI › Menu bar lists top and bottom with the current one marked" do
    get rori_commands_ui_path
    assert_select "li[data-children=?]", rori_commands_bars_path, text: /Menu bar/

    cookies[Rori.bars_cookie] = "bottom"
    get rori_commands_bars_path
    assert_select "li[data-rori-action=bars]", count: 2
    assert_select "li[data-param=bottom][data-current]", text: /Bottom/
  end

  test "the root palette has Keyboard shortcuts with its chord" do
    get rori_commands_path

    assert_select "li[data-rori-action=shortcuts] kbd", text: "⌥?"
  end

  test "wallpaper modes are commands with the current one marked" do
    cookies[Rori.wallpaper_cookie] = "cover"
    get rori_commands_wallpapers_path

    assert_select "li[data-rori-action=wallpaper]", count: 3
    assert_select "li[data-param=cover][data-current]", text: /Cover menu bar/
    assert_select "li[data-param=safe]:not([data-current])"
    assert_select "li[data-rori-action=wallpaper_next]", text: /Next wallpaper/
    assert_select "li[data-rori-action=wallpaper_pin]:not([data-current])", text: /Pin wallpaper/
  end

  test "a pinned wallpaper is marked, and the desk renders it instead of a random one" do
    Rori.wallpapers = true
    pinned = Rori::Wallpaper.all.last
    cookies[Rori.wallpaper_pin_cookie] = pinned.id

    get rori_commands_wallpapers_path
    assert_select "li[data-rori-action=wallpaper_pin][data-current]"

    get root_path
    assert_select "body[data-rori-wallpaper-current-value=?][data-rori-wallpaper-pinned-value=true]", pinned.id
    assert_select "body[style*=?]", pinned.url(1920)
    pool = JSON.parse(css_select("body").first["data-rori-wallpaper-pool-value"])
    assert_equal Rori::Wallpaper.all.map(&:id), pool.map { it["id"] }
  end

  test "local themes are rendered inline, so the picker can preview them" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "Paper"), "background = #f4f1ea\nforeground = #2b2b2b\npalette = 1=#b3261e\npalette = 2=#2e7d32\npalette = 3=#b26a00\npalette = 4=#1f5fa8\n")
      Rori.themes_folder = dir

      get root_path
      assert_select "head style", text: /:root\[data-theme="paper"\]/
      get rori_commands_themes_path
      assert_select "li[data-param=paper]", text: /Paper/
    end
  ensure
    Rori.themes_folder = nil
  end
end
