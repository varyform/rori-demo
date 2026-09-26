module Rori::PrefsHelper
  BAR_POSITIONS = %w[ top bottom ].freeze

  # Where the menu bar sits (UI › Menu bar): top or bottom edge.
  def rori_bars = BAR_POSITIONS.include?(cookies[Rori.bars_cookie]) ? cookies[Rori.bars_cookie] : BAR_POSITIONS.first

  # The empty-desk hint was dismissed (brought back from the shortcuts modal).
  def rori_hint_hidden? = cookies[Rori.hint_cookie] == "hidden"

  def rori_body_classes
    class_names(rori_wallpaper_classes, "bars-bottom" => rori_bars == "bottom", "hint-hidden" => rori_hint_hidden?)
  end
end
