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

  test "wallpapers are optional: none by default, a random photo with credit when on" do
    get root_path
    assert_select "body.has-wallpaper", count: 0
    assert_select ".statusbar__credit", count: 0

    Desk.wallpapers = true
    get root_path
    assert_select "body.has-wallpaper:not(.wallpaper-cover)[style*=?]", "--desk-wallpaper: image-set(url(\"https://images.unsplash.com/photo-"
    assert_select "a.statusbar__credit[target=_blank][href^=?]", "https://images.unsplash.com/photo-", text: "Photo · Unsplash"
  ensure
    Desk.wallpapers = false
  end

  test "the wallpaper mode cookie picks safe, cover or off; unknown values fall back to safe" do
    Desk.wallpapers = true
    { "cover" => "body.has-wallpaper.wallpaper-cover", "off" => "body:not(.has-wallpaper)", "bogus" => "body.has-wallpaper:not(.wallpaper-cover)" }.each do |mode, selector|
      cookies[Desk.wallpaper_cookie] = mode
      get root_path
      assert_select selector
    end
  ensure
    Desk.wallpapers = false
  end

  test "the native shell gets the ⌘ keymap and hint" do
    get root_path, headers: { "User-Agent" => "Mozilla/5.0 (Macintosh) AppleWebKit/605.1.15 (KHTML, like Gecko) DeskApp/0.1" }

    keymap = JSON.parse(css_select("body").first["data-desk-keymap-value"])
    assert_equal %w[ Meta+ArrowLeft Meta+KeyH ], keymap["focus_left"]
    assert_select ".statusbar__hint kbd", text: "⌘←→↑↓"
    assert_select "body[data-desk-native-value=true]"
  end

  test "browsers aren't the native shell" do
    get root_path

    assert_select "body[data-desk-native-value=false]"
  end
end
