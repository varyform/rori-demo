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
    assert_select "main.viewport.has-wallpaper", count: 0
    assert_select ".statusbar__credit", count: 0

    Desk.wallpapers = true
    get root_path
    assert_select "main.viewport.has-wallpaper[style*=?]", "--desk-wallpaper: image-set(url(\"https://images.unsplash.com/photo-"
    assert_select "a.statusbar__credit[target=_blank][href^=?]", "https://images.unsplash.com/photo-", text: "Photo · Unsplash"
  ensure
    Desk.wallpapers = false
  end

  test "the native shell gets the ⌘ keymap and hint" do
    get root_path, headers: { "User-Agent" => "Mozilla/5.0 (Macintosh) AppleWebKit/605.1.15 (KHTML, like Gecko) DeskApp/0.1" }

    keymap = JSON.parse(css_select("body").first["data-desk-keymap-value"])
    assert_equal %w[ Meta+ArrowLeft Meta+KeyH ], keymap["focus_left"]
    assert_select ".statusbar__hint kbd", text: "⌘←→↑↓"
  end
end
