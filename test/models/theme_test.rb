require "test_helper"

class ThemeTest < ActiveSupport::TestCase
  test "themes.css is up to date with vendor/themes" do
    assert_equal Theme.stylesheet, Theme::STYLESHEET.read, "run `bin/rails themes:build`"
  end

  test "parses ghostty files into semantic tokens" do
    nord = Theme.find("nord")

    assert_equal "Nord", nord.name
    assert nord.dark?
    assert_equal Theme::Color.from_hex("#2e3440").to_s, nord.tokens["--color-surface"].to_s
    assert_equal Theme::Color.from_hex("#bf616a").to_s, nord.tokens["--color-danger"].to_s
    assert_operator nord.tokens["--color-canvas"].lightness, :<, nord.tokens["--color-surface"].lightness
  end

  test "tells light themes from dark ones" do
    assert_not Theme.find("catppuccin-latte").dark?
    assert Theme.find("catppuccin-mocha").dark?
  end

  test "find ignores unknown and blank slugs" do
    assert_nil Theme.find("nope")
    assert_nil Theme.find("")
    assert_nil Theme.find(nil)
  end

  test "converts sRGB hex to oklch" do
    assert_equal "oklch(1.0000 0.0000 0.00)", Theme::Color.from_hex("#ffffff").to_s
    assert_equal "oklch(0.0000 0.0000 0.00)", Theme::Color.from_hex("#000000").to_s
    assert_equal "oklch(0.6280 0.2577 29.23)", Theme::Color.from_hex("#ff0000").to_s
  end
end
