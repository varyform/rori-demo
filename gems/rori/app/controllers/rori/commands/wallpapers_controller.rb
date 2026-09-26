# "UI › Wallpaper ›": how (or whether) the wallpaper shows.
class Rori::Commands::WallpapersController < ApplicationController
  layout false

  def index
    @commands = Rori::Command.wallpapers(current: helpers.rori_wallpaper_mode)
    render "rori/commands/index"
  end
end
