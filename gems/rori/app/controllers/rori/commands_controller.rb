class Rori::CommandsController < ApplicationController
  layout false

  def index
    @commands = Rori::Command.all
  end
end
