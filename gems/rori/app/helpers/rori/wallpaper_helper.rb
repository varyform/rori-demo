module Rori::WallpaperHelper
  # This page load's photo (the pinned one, else random), or nil when
  # Rori.wallpapers is off.
  def rori_wallpaper
    return @rori_wallpaper if defined?(@rori_wallpaper)
    @rori_wallpaper = Rori::Wallpaper.pick(cookies[Rori.wallpaper_pin_cookie])
  end

  # A pin whose photo left the pool no longer counts.
  def rori_wallpaper_pinned? = Rori.wallpapers && Rori::Wallpaper.find(cookies[Rori.wallpaper_pin_cookie]).present?

  # safe | cover | off, picked from UI › Wallpaper (rori-wallpaper stores the cookie).
  def rori_wallpaper_mode = Rori::Wallpaper.mode(cookies[Rori.wallpaper_cookie])

  def rori_wallpaper_classes
    class_names("has-wallpaper" => rori_wallpaper && rori_wallpaper_mode != "off",
      "wallpaper-cover" => rori_wallpaper_mode == "cover")
  end
end
