module Desk::WallpaperHelper
  # This page load's photo, or nil when Desk.wallpapers is off.
  def desk_wallpaper
    return @desk_wallpaper if defined?(@desk_wallpaper)
    @desk_wallpaper = Desk::Wallpaper.random
  end

  # safe | cover | off, picked from UI › Wallpaper (desk-wallpaper stores the cookie).
  def desk_wallpaper_mode = Desk::Wallpaper.mode(cookies[Desk.wallpaper_cookie])

  def desk_wallpaper_classes
    class_names("has-wallpaper" => desk_wallpaper && desk_wallpaper_mode != "off",
      "wallpaper-cover" => desk_wallpaper_mode == "cover")
  end
end
