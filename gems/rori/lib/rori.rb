require "rails"
require "turbo-rails"
require "stimulus-rails"
require "importmap-rails"
require "propshaft"
require "haml"

require "rori/version"
require "rori/engine"

# The desk: a niri-style window manager for Rails pages (tiled turbo-frame
# windows, ⌘K palette and terminal, Ghostty themes). A Rails engine; see the
# README for wiring it into a host app. Configure in an initializer:
#
#   Rori.configure do |desk|
#     desk.records = %w[ User Project ]
#     desk.hover_keys = true
#   end
module Rori
  # Shown in the menubar and the <title> of the bare desk.
  mattr_accessor :app_name, default: "Rori"

  # Model class names whose most recent records are listed in ⌘K.
  mattr_accessor :records, default: []
  mattr_accessor :record_limit, default: 25

  # Extra palette entries: callables returning Rori::Command(s), evaluated on
  # every palette open (so they can list fresh data).
  mattr_accessor :commands, default: []

  # Server-side commands registered with `Rori.command`, by name.
  Runnable = Data.define(:name, :confirm, :block) do
    def label = I18n.t(name, scope: "rori.commands.custom")

    def call = block.call
  end
  mattr_accessor :runnables, default: {}

  # `Rori.notify` broadcasts here; every open desk subscribes (turbo_stream_from).
  mattr_accessor :notifications_stream, default: "rori_notifications"

  # Ghostty themes compiled by `bin/rails rori:themes:build`; both default to
  # the ones bundled with the gem (paths resolve lazily, after boot).
  mattr_writer :themes_directory, :themes_stylesheet
  mattr_accessor :theme_cookie, default: "theme"

  # The app's own Ghostty theme files (a directory, relative to Rails.root or
  # absolute), listed alongside the bundled ones; same name replaces a bundled
  # theme. No build step: their CSS is rendered into the shell.
  mattr_accessor :themes_folder

  # Optional background photos (off by default): a random one per page load,
  # unless one is pinned (UI › Wallpaper › Pin).
  mattr_accessor :wallpapers, default: false
  mattr_writer :wallpapers_file
  mattr_accessor :wallpaper_cookie, default: "wallpaper"
  mattr_accessor :wallpaper_pin_cookie, default: "wallpaper_pin"

  # UI › Menu bar (top | bottom) and the dismissible empty-desk hint.
  mattr_accessor :bars_cookie, default: "bars"
  mattr_accessor :hint_cookie, default: "hint"

  # The app's own wallpapers: a folder in its asset path (e.g. "wallpapers" for
  # app/assets/images/wallpapers). When set, its images replace the bundled
  # Unsplash photos.
  mattr_accessor :wallpapers_folder

  def self.themes_directory = @@themes_directory || Engine.root.join("vendor/themes/ghostty")

  def self.themes_stylesheet = @@themes_stylesheet || Engine.root.join("app/assets/stylesheets/rori/themes.css")

  def self.wallpapers_file = @@wallpapers_file || Engine.root.join("vendor/wallpapers/unsplash.yml")

  # The terminal (⌘K as a command line) opens with this bare key outside text
  # fields — KeyboardEvent#code, like the keymap — and with `toggle_terminal`.
  mattr_accessor :terminal_key, default: "Backquote"

  # Keyboard: desk action (rori_controller.js#perform) → key chords, written as
  # `KeyboardEvent#code` names joined with modifiers. `Mod` stands for
  # `Rori.modifier` — Alt in the browser, where ⌘ combos belong to the browser;
  # a native shell (e.g. Tauri) can switch to Meta. `Digit*` binds 1–9 to the
  # nth workspace. Chords never fire inside text fields; Esc leaves the field.
  MODIFIERS = { "Alt" => "⌥", "Meta" => "⌘", "Control" => "⌃" }.freeze
  mattr_accessor :modifier, default: "Alt"

  # The native shell (src-tauri) marks its webview's user agent; there ⌘ combos
  # aren't taken by a browser, so pages rendered for it use `native_modifier`.
  mattr_accessor :native_user_agent, default: "RoriApp"
  mattr_accessor :native_modifier, default: "Meta"

  # Per-modifier replacements for chords the platform already owns: with ⌘,
  # ⌘C is Copy in the native Edit menu, which fires before the page sees it.
  mattr_accessor :keymap_overrides, default: {
    "Meta" => { center_column: %w[ Mod+Shift+KeyC ] }
  }.freeze
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
    reopen_window: %w[ Mod+Shift+KeyT ],
    toggle_terminal: %w[ Mod+Backquote ],
    shortcuts: %w[ Mod+Shift+Slash ]
  }.freeze

  # Bare keys (opt-in). Blender-style: once the pointer deliberately moves onto
  # an inactive window, they act on that window without taking focus — even
  # while you're typing in a field elsewhere — until the pointer rests for
  # `hover_timeout` seconds, leaves, or another key is typed. Otherwise, when
  # no field has focus, they act on the focused window.
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

    # A command that runs on the server, listed in ⌘K and the terminal under
    # Run and labelled by `rori.commands.custom.<name>` in the app's locale:
    #
    #   rori.command :reindex_search, confirm: true do
    #     SearchReindexJob.perform_later
    #     "Reindexing…"
    #   end
    #
    # The block runs inside the request, so hand slow work to a job (which can
    # `Rori.notify` when it's done). A String it returns becomes the
    # notification's text. `confirm: true` asks first: ↵ twice in ⌘K, y in the
    # terminal.
    def command(name, confirm: false, &block)
      runnables[name.to_s] = Runnable.new(name: name.to_s, confirm:, block:)
    end

    # A notification in the corner of every open desk, e.g. from a job:
    #   Rori.notify "Search reindexed", "1,204 records", kind: :success
    def notify(title, body = nil, kind: :info) = Notification.new(title:, body:, kind:).broadcast

    # The keymap with `Mod` spelled out, as rori_controller.js matches it.
    def resolved_keymap(modifier = self.modifier)
      raise ArgumentError, "Rori modifier must be one of #{MODIFIERS.keys.join(", ")}" unless MODIFIERS.key?(modifier)

      keymap.merge(keymap_overrides.fetch(modifier, {}))
        .transform_values { |chords| Array(chords).map { it.sub(/\AMod\+/, "#{modifier}+") } }
    end

    def modifier_symbol(modifier = self.modifier) = MODIFIERS.fetch(modifier)

    def native?(user_agent) = user_agent.to_s.include?(native_user_agent)

    def modifier_for(user_agent) = native?(user_agent) ? native_modifier : modifier

    def resolved_hover_keymap = hover_keys ? hover_keymap : {}
  end
end
