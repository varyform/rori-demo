class Desk::CommandsController < ApplicationController
  layout false

  def index
    @commands = Desk::Command.all
  end
end
