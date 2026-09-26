require "test_helper"

class Rori::DesktopsControllerTest < ActionDispatch::IntegrationTest
  test "root is a blank desk with no window" do
    get root_path

    assert_response :success
    assert_select "main.rori-viewport .rori-wallpaper"
    assert_select "main.rori-viewport dialog.rori-win", count: 0
    assert_select "template[data-rori-target=template] dialog.rori-win"
    assert_select "body[data-rori-palette-root-value=?]", rori_commands_path
    keymap = JSON.parse(css_select("body").first["data-rori-keymap-value"])
    assert_equal Rori.resolved_keymap.stringify_keys, keymap
    assert_select "dialog.rori-palette turbo-frame#commands:not([src])"
  end

  test "wallpapers are optional: none by default, a random photo with credit when on" do
    get root_path
    assert_select "body.has-wallpaper", count: 0
    assert_select ".rori-menubar__credit", count: 0

    Rori.wallpapers = true
    get root_path
    assert_select "body.has-wallpaper:not(.wallpaper-cover)[style*=?]", "--rori-wallpaper: image-set(url(\"https://images.unsplash.com/photo-"
    assert_select "a.rori-menubar__credit[target=_blank][href^=?]", "https://images.unsplash.com/photo-", text: "Photo · Unsplash"
  ensure
    Rori.wallpapers = false
  end

  test "the wallpaper mode cookie picks safe, cover or off; unknown values fall back to safe" do
    Rori.wallpapers = true
    { "cover" => "body.has-wallpaper.wallpaper-cover", "off" => "body:not(.has-wallpaper)", "bogus" => "body.has-wallpaper:not(.wallpaper-cover)" }.each do |mode, selector|
      cookies[Rori.wallpaper_cookie] = mode
      get root_path
      assert_select selector
    end
  ensure
    Rori.wallpapers = false
  end

  test "the native shell gets the ⌘ keymap, hint and shortcuts" do
    get root_path, headers: { "User-Agent" => "Mozilla/5.0 (Macintosh) AppleWebKit/605.1.15 (KHTML, like Gecko) DeskApp/0.1" }

    keymap = JSON.parse(css_select("body").first["data-rori-keymap-value"])
    assert_equal %w[ Meta+ArrowLeft Meta+KeyH ], keymap["focus_left"]
    assert_select ".rori-wallpaper__hint kbd", text: "⌘?"
    assert_select ".rori-menubar__shortcuts kbd", text: "⌘?"
    assert_select "dialog.rori-shortcuts dd kbd", text: "⌘←"
    assert_select "body[data-rori-native-value=true]"
  end

  test "browsers aren't the native shell" do
    get root_path

    assert_select "body[data-rori-native-value=false]"
    assert_select ".rori-wallpaper__hint kbd", text: "⌥?"
  end

  test "the shortcuts modal lists the keymap by section, and bare keys only when on" do
    get root_path

    assert_select "dialog.rori-shortcuts h3", text: "Workspaces"
    assert_select "dialog.rori-shortcuts dt", text: "Send column to workspace"
    assert_select "dialog.rori-shortcuts dd kbd", text: "⌥⇧1–9"
    assert_select "dialog.rori-shortcuts h3", text: "Bare keys"
    assert_select "dialog.rori-shortcuts input[type=checkbox][data-rori-prefs-target=hintToggle]"

    Rori.hover_keys = false
    get root_path
    assert_select "dialog.rori-shortcuts h3", text: "Bare keys", count: 0
  ensure
    Rori.hover_keys = true
  end

  test "the bar position and a dismissed hint come from cookies" do
    get root_path
    assert_select "body:not(.bars-bottom):not(.hint-hidden)[data-rori-prefs-bars-value=top]"

    cookies[Rori.bars_cookie] = "bottom"
    cookies[Rori.hint_cookie] = "hidden"
    get root_path
    assert_select "body.bars-bottom.hint-hidden[data-rori-prefs-bars-value=bottom]"

    cookies[Rori.bars_cookie] = "sideways"
    get root_path
    assert_select "body:not(.bars-bottom)"
  end
end
