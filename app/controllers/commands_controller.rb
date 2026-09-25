class CommandsController < ApplicationController
  layout false

  def index
    @commands = Command.all
  end
end
