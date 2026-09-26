# The "UI ›" list: appearance settings, each a nested list of its own.
class Rori::Commands::UiController < ApplicationController
  layout false

  def show
    @commands = Rori::Command.ui
    render "rori/commands/index"
  end
end
