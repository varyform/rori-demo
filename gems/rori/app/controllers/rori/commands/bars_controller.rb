# "UI › Menu bar ›": top or bottom.
class Rori::Commands::BarsController < ApplicationController
  layout false

  def index
    @commands = Rori::Command.bars(current: helpers.rori_bars)
    render "rori/commands/index"
  end
end
