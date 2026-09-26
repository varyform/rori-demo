module Rori::KeymapHelper
  KEY_SYMBOLS = {
    "Alt" => "⌥", "Meta" => "⌘", "Control" => "⌃", "Shift" => "⇧",
    "ArrowLeft" => "←", "ArrowRight" => "→", "ArrowUp" => "↑", "ArrowDown" => "↓",
    "BracketLeft" => "[", "BracketRight" => "]", "Backquote" => "`", "Slash" => "/",
    "Enter" => "↵", "Space" => "␣"
  }.freeze

  # The keyboard shortcuts modal, in reading order; keymap actions missing from
  # Rori.keymap (an app removed them) are skipped.
  SHORTCUT_SECTIONS = {
    focus: %i[ focus_left focus_right focus_up focus_down ],
    move: %i[ move_left move_right move_up move_down ],
    workspaces: %i[ switch_to_workspace move_to_workspace ],
    columns: %i[ consume_left consume_right cycle_width full_width center_column overview ],
    windows: %i[ close_window reopen_window toggle_terminal shortcuts ]
  }.freeze

  # Alt in a browser, ⌘ inside the native shell (see Rori.native_user_agent).
  def rori_modifier = Rori.modifier_for(request.user_agent)

  def rori_native? = Rori.native?(request.user_agent)

  # The first chord bound to a desk action, as symbols ("⌥⇧T"), or nil.
  def rori_shortcut(action)
    chord = Rori.resolved_keymap(rori_modifier)[action&.to_sym]&.first
    chord && rori_chord_symbols(chord)
  end

  # "Alt+Shift+KeyT" → "⌥⇧T", "Meta+Digit*" → "⌘1–9", "Meta+Shift+Slash" → "⌘?".
  def rori_chord_symbols(chord)
    keys = chord.split("+")
    keys = keys - %w[ Shift Slash ] + [ "?" ] if (keys & %w[ Shift Slash ]).size == 2
    keys.map { |key| KEY_SYMBOLS.fetch(key) { key.sub(/\A(Key|Digit)/, "").sub("*", "1–9") } }.join
  end

  # [ [section, [ [action, ["⌥←", "⌥H"]], … ]], … ] for the shortcuts modal.
  def rori_shortcut_sections
    keymap = Rori.resolved_keymap(rori_modifier)
    SHORTCUT_SECTIONS.filter_map do |section, actions|
      rows = actions.filter_map { |action| [ action, keymap[action].map { rori_chord_symbols(it) } ] if keymap[action] }
      [ section, rows ] if rows.any?
    end
  end

  # Bare keys (Rori.hover_keymap) as [ [action, ["W"]], … ], empty when off.
  def rori_hover_shortcuts
    Rori.resolved_hover_keymap.map { |action, chords| [ action, chords.map { rori_chord_symbols(it) } ] }
  end
end
