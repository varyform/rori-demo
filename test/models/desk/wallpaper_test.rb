require "test_helper"

class Desk::WallpaperTest < ActiveSupport::TestCase
  teardown { Desk.wallpapers = false }

  test "is off unless configured" do
    assert_nil Desk::Wallpaper.random
  end

  test "picks a vendored photo when on" do
    Desk.wallpapers = true

    assert_includes Desk::Wallpaper.all, Desk::Wallpaper.random
    assert Desk::Wallpaper.all.size >= 10
  end

  test "sizes Unsplash CDN urls, with a hi-dpi variant" do
    wallpaper = Desk::Wallpaper.new(id: "1418065460487-3e41a6c84dc5")

    assert_equal "https://images.unsplash.com/photo-1418065460487-3e41a6c84dc5?auto=format&fit=crop&w=1920&q=75", wallpaper.url(1920)
    assert_match %r{\Aimage-set\(url\(".+w=1920.+"\) 1x, url\(".+w=3200.+"\) 2x\)\z}, wallpaper.css_image
  end
end
