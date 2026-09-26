require "test_helper"

class Rori::WallpaperTest < ActiveSupport::TestCase
  teardown do
    Rori.wallpapers = false
    Rori.wallpapers_folder = nil
  end

  test "is off unless configured" do
    assert_nil Rori::Wallpaper.pick
  end

  test "picks a vendored photo when on, or the pinned one while it's in the pool" do
    Rori.wallpapers = true
    pool = Rori::Wallpaper.all

    assert_includes pool, Rori::Wallpaper.pick
    assert pool.size >= 10
    assert_equal pool.last, Rori::Wallpaper.pick(pool.last.id)
    assert_includes pool, Rori::Wallpaper.pick("gone-from-the-pool")
  end

  test "sizes Unsplash CDN urls, with a hi-dpi variant and a credit link" do
    wallpaper = Rori::Wallpaper.new(id: "1418065460487-3e41a6c84dc5")

    assert_equal "https://images.unsplash.com/photo-1418065460487-3e41a6c84dc5?auto=format&fit=crop&w=1920&q=75", wallpaper.url(1920)
    assert_match %r{\Aimage-set\(url\(".+w=1920.+"\) 1x, url\(".+w=3200.+"\) 2x\)\z}, wallpaper.css_image
    assert_equal wallpaper.url(3200), wallpaper.credit_url
  end

  test "a wallpapers folder takes the images under it from the asset path" do
    Rori.wallpapers_folder = "wallpapers/"
    paths = %w[ wallpapers/b.jpg wallpapers/a.webp wallpapers/notes.txt other/c.png wallpapersx/d.jpg rori/layout.css ]

    local = Rori::Wallpaper.local(paths)
    assert_equal %w[ wallpapers/a.webp wallpapers/b.jpg ], local.map(&:id)
    assert local.all?(&:local)
    assert_nil local.first.credit_url
  end

  test "serializes what the client needs to swap it in" do
    wallpaper = Rori::Wallpaper.new(id: "1418065460487-3e41a6c84dc5")

    assert_equal %w[ credit id image ], wallpaper.as_json.keys.map(&:to_s).sort
  end
end
