# The palette's nested "Pick theme…" list, rendered into the same frame as the root commands.
class Commands::ThemesController < ApplicationController
  layout false

  def index
    @commands = Command.themes(current: helpers.current_theme)
    render "commands/index"
  end
end
