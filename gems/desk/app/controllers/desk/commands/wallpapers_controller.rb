# "UI › Wallpaper ›": how (or whether) the wallpaper shows.
class Desk::Commands::WallpapersController < ApplicationController
  layout false

  def index
    @commands = Desk::Command.wallpapers(current: helpers.desk_wallpaper_mode)
    render "desk/commands/index"
  end
end
