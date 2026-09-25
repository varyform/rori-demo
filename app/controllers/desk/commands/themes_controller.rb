# The palette's nested "Pick theme…" list, rendered into the same frame as the root commands.
class Desk::Commands::ThemesController < ApplicationController
  layout false

  def index
    @commands = Desk::Command.themes(current: helpers.current_theme)
    render "desk/commands/index"
  end
end
