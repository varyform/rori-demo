# The palette's nested "Pick theme…" list, rendered into the same frame as the root commands.
class Rori::Commands::ThemesController < ApplicationController
  layout false

  def index
    @commands = Rori::Command.themes(current: helpers.current_theme)
    render "rori/commands/index"
  end
end
