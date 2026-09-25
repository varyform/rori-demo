# The desk: a niri-style window manager for Rails pages (tiled turbo-frame
# windows, ⌘K palette, Ghostty themes). Everything desk-specific lives under
# this namespace — app/*/desk, app/javascript/desk, app/assets/stylesheets/desk,
# config/routes/desk.rb, config/locales/desk.en.yml — so it can be lifted into
# an engine later. Apps configure it in config/initializers/desk.rb.
module Desk
  # Model class names whose most recent records are listed in ⌘K.
  mattr_accessor :records, default: []
  mattr_accessor :record_limit, default: 25

  # Extra palette entries: callables returning Desk::Command(s), evaluated on
  # every palette open (so they can list fresh data).
  mattr_accessor :commands, default: []

  mattr_accessor :themes_directory, default: Rails.root.join("vendor/themes/ghostty")
  mattr_accessor :themes_stylesheet, default: Rails.root.join("app/assets/stylesheets/desk/themes.css")
  mattr_accessor :theme_cookie, default: "theme"

  # Keyboard: desk action (desk_controller.js#perform) → key chords, written as
  # `KeyboardEvent#code` names joined with modifiers. `Mod` stands for
  # `Desk.modifier` — Alt in the browser, where ⌘ combos belong to the browser;
  # a native shell (e.g. Tauri) can switch to Meta. `Digit*` binds 1–9 to the
  # nth workspace. Chords never fire inside text fields; Esc leaves the field.
  MODIFIERS = { "Alt" => "⌥", "Meta" => "⌘", "Control" => "⌃" }.freeze
  mattr_accessor :modifier, default: "Alt"
  mattr_accessor :keymap, default: {
    focus_left: %w[ Mod+ArrowLeft Mod+KeyH ],
    focus_right: %w[ Mod+ArrowRight Mod+KeyL ],
    focus_up: %w[ Mod+ArrowUp Mod+KeyK ],
    focus_down: %w[ Mod+ArrowDown Mod+KeyJ ],
    move_left: %w[ Mod+Shift+ArrowLeft Mod+Shift+KeyH ],
    move_right: %w[ Mod+Shift+ArrowRight Mod+Shift+KeyL ],
    move_up: %w[ Mod+Shift+ArrowUp Mod+Shift+KeyK ],
    move_down: %w[ Mod+Shift+ArrowDown Mod+Shift+KeyJ ],
    switch_to_workspace: %w[ Mod+Digit* ],
    move_to_workspace: %w[ Mod+Shift+Digit* ],
    consume_left: %w[ Mod+BracketLeft ],
    consume_right: %w[ Mod+BracketRight ],
    cycle_width: %w[ Mod+KeyR ],
    full_width: %w[ Mod+KeyF ],
    center_column: %w[ Mod+KeyC ],
    overview: %w[ Mod+KeyO ],
    close_window: %w[ Mod+KeyW ],
    reopen_window: %w[ Mod+Shift+KeyT ]
  }.freeze

  # Blender-style hover keys (opt-in): once the pointer deliberately moves onto
  # an inactive window, these bare keys act on that window without taking focus
  # — even while you're typing in a field elsewhere. They stay armed until the
  # pointer rests for `hover_timeout` seconds, leaves, or another key is typed.
  # No hjkl/arrows here: they'd shadow text entry and page scrolling.
  mattr_accessor :hover_keys, default: false
  mattr_accessor :hover_timeout, default: 1.5
  mattr_accessor :hover_keymap, default: {
    close_window: %w[ KeyW ],
    reopen_window: %w[ KeyU ],
    cycle_width: %w[ KeyR ],
    full_width: %w[ KeyF ],
    center_column: %w[ KeyC ],
    consume_left: %w[ BracketLeft ],
    consume_right: %w[ BracketRight ],
    move_left: %w[ Shift+KeyH ],
    move_right: %w[ Shift+KeyL ],
    move_to_workspace: %w[ Digit* ]
  }.freeze

  class << self
    def configure = yield(self)

    # The keymap with `Mod` spelled out, as desk_controller.js matches it.
    def resolved_keymap
      raise ArgumentError, "Desk.modifier must be one of #{MODIFIERS.keys.join(", ")}" unless MODIFIERS.key?(modifier)

      keymap.transform_values { |chords| Array(chords).map { it.sub(/\AMod\+/, "#{modifier}+") } }
    end

    def modifier_symbol = MODIFIERS.fetch(modifier)

    def resolved_hover_keymap = hover_keys ? hover_keymap : {}
  end
end
