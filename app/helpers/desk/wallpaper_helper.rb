module Desk::WallpaperHelper
  # This page load's photo, or nil when Desk.wallpapers is off.
  def desk_wallpaper
    return @desk_wallpaper if defined?(@desk_wallpaper)
    @desk_wallpaper = Desk::Wallpaper.random
  end
end
