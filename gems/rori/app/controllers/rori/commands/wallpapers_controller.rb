# "UI › Wallpaper ›": how (or whether) the wallpaper shows, next and pin.
class Rori::Commands::WallpapersController < ApplicationController
  layout false

  def index
    @commands = Rori::Command.wallpapers(current: helpers.rori_wallpaper_mode, pinned: helpers.rori_wallpaper_pinned?)
    render "rori/commands/index"
  end
end
