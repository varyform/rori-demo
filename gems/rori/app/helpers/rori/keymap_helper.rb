module Rori::KeymapHelper
  KEY_SYMBOLS = {
    "Alt" => "⌥", "Meta" => "⌘", "Control" => "⌃", "Shift" => "⇧",
    "ArrowLeft" => "←", "ArrowRight" => "→", "ArrowUp" => "↑", "ArrowDown" => "↓",
    "BracketLeft" => "[", "BracketRight" => "]", "Backquote" => "`", "Enter" => "↵", "Space" => "␣"
  }.freeze

  # Alt in a browser, ⌘ inside the native shell (see Rori.native_user_agent).
  def rori_modifier = Rori.modifier_for(request.user_agent)

  def rori_native? = Rori.native?(request.user_agent)

  # The first chord bound to a desk action, as symbols ("⌥⇧T"), or nil.
  def rori_shortcut(action)
    chord = Rori.resolved_keymap(rori_modifier)[action&.to_sym]&.first
    chord && rori_chord_symbols(chord)
  end

  # "Alt+Shift+KeyT" → "⌥⇧T", "Meta+Digit*" → "⌘1–9".
  def rori_chord_symbols(chord)
    chord.split("+").map { |key| KEY_SYMBOLS.fetch(key) { key.sub(/\A(Key|Digit)/, "").sub("*", "1–9") } }.join
  end
end
