# The "UI ›" list: appearance settings, each a nested list of its own.
class Desk::Commands::UiController < ApplicationController
  layout false

  def show
    @commands = Desk::Command.ui
    render "desk/commands/index"
  end
end
