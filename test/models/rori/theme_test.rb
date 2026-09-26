require "test_helper"

class Rori::ThemeTest < ActiveSupport::TestCase
  test "themes.css is up to date with vendor/themes" do
    assert_equal Rori::Theme.stylesheet, Rori.themes_stylesheet.read, "run `bin/rails rori:themes:build`"
  end

  test "parses ghostty files into semantic tokens" do
    nord = Rori::Theme.find("nord")

    assert_equal "Nord", nord.name
    assert nord.dark?
    assert_equal Rori::Theme::Color.from_hex("#2e3440").to_s, nord.tokens["--color-surface"].to_s
    assert_equal Rori::Theme::Color.from_hex("#bf616a").to_s, nord.tokens["--color-danger"].to_s
    assert_operator nord.tokens["--color-canvas"].lightness, :<, nord.tokens["--color-surface"].lightness
  end

  test "tells light themes from dark ones" do
    assert_not Rori::Theme.find("catppuccin-latte").dark?
    assert Rori::Theme.find("catppuccin-mocha").dark?
  end

  test "find ignores unknown and blank slugs" do
    assert_nil Rori::Theme.find("nope")
    assert_nil Rori::Theme.find("")
    assert_nil Rori::Theme.find(nil)
  end

  test "an app themes folder adds themes and replaces bundled ones by name, outside the compiled file" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "Paper"), "background = #f4f1ea\nforeground = #2b2b2b\npalette = 1=#b3261e\npalette = 2=#2e7d32\npalette = 3=#b26a00\npalette = 4=#1f5fa8\n")
      File.write(File.join(dir, "Nord"), File.read(Rori.themes_directory.join("Nord")).sub("background = #2e3440", "background = #000000"))
      Rori.themes_folder = dir

      assert_equal "Paper", Rori::Theme.find("paper").name
      assert_not Rori::Theme.find("paper").dark?
      assert_equal Rori::Theme::Color.from_hex("#000000").to_s, Rori::Theme.find("nord").tokens["--color-surface"].to_s
      assert_equal 1, Rori::Theme.all.count { it.slug == "nord" }
      assert_no_match "paper", Rori::Theme.stylesheet
      assert_match %r{\A@layer rori\.themes \{.*:root\[data-theme="paper"\]}m, Rori::Theme.css(Rori::Theme.local)
    end
  ensure
    Rori.themes_folder = nil
  end

  test "converts sRGB hex to oklch" do
    assert_equal "oklch(1.0000 0.0000 0.00)", Rori::Theme::Color.from_hex("#ffffff").to_s
    assert_equal "oklch(0.0000 0.0000 0.00)", Rori::Theme::Color.from_hex("#000000").to_s
    assert_equal "oklch(0.6280 0.2577 29.23)", Rori::Theme::Color.from_hex("#ff0000").to_s
  end
end
