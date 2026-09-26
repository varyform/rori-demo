require_relative "lib/rori/version"

Gem::Specification.new do |spec|
  spec.name        = "rori"
  spec.version     = Rori::VERSION
  spec.authors     = [ "Oleh Khomei" ]
  spec.summary     = "A niri-style window manager for Rails pages: tiled Turbo-frame windows, ⌘K, a terminal and the keyboard."
  spec.description = <<~TEXT
    Every page of a Rails app opens as a window in endlessly scrolling column
    strips, one strip per workspace. Pages say how they want to be shown
    (size, modal, full width, workspace, reuse key); ⌘K and a drop-down
    terminal run the same fuzzy-matched command tree; a keymap with a
    configurable modifier (⌘ in a native shell) and optional Blender-style
    hover keys drive the windows. Ghostty colour themes and Unsplash
    wallpapers included. The host app keeps its own controllers and views.
  TEXT
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.4"

  spec.files = Dir["{app,config,lib,vendor}/**/*", "README.md"]
  spec.require_paths = [ "lib" ]

  spec.add_dependency "rails", ">= 8.0"
  spec.add_dependency "turbo-rails", ">= 2.0"
  spec.add_dependency "stimulus-rails", ">= 1.3"
  spec.add_dependency "importmap-rails", ">= 2.0"
  spec.add_dependency "propshaft", ">= 1.1"
  spec.add_dependency "haml", ">= 6.0"
end
