module Desk::KeymapHelper
  KEY_SYMBOLS = {
    "Alt" => "⌥", "Meta" => "⌘", "Control" => "⌃", "Shift" => "⇧",
    "ArrowLeft" => "←", "ArrowRight" => "→", "ArrowUp" => "↑", "ArrowDown" => "↓",
    "BracketLeft" => "[", "BracketRight" => "]", "Backquote" => "`", "Enter" => "↵", "Space" => "␣"
  }.freeze

  # Alt in a browser, ⌘ inside the native shell (see Desk.native_user_agent).
  def desk_modifier = Desk.modifier_for(request.user_agent)

  def desk_native? = Desk.native?(request.user_agent)

  # The first chord bound to a desk action, as symbols ("⌥⇧T"), or nil.
  def desk_shortcut(action)
    chord = Desk.resolved_keymap(desk_modifier)[action&.to_sym]&.first
    chord && desk_chord_symbols(chord)
  end

  # "Alt+Shift+KeyT" → "⌥⇧T", "Meta+Digit*" → "⌘1–9".
  def desk_chord_symbols(chord)
    chord.split("+").map { |key| KEY_SYMBOLS.fetch(key) { key.sub(/\A(Key|Digit)/, "").sub("*", "1–9") } }.join
  end
end
