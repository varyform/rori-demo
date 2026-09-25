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

  def self.configure = yield(self)
end
