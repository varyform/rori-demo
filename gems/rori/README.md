# Rori

A niri-style window manager for Rails pages — a "desk" of windows. Every
page opens as a window in endlessly scrolling column strips, one strip per workspace; ⌘K and a
drop-down terminal (`` ` ``) run one fuzzy-matched command tree; a keymap
with a configurable modifier (⌘ in a native shell) and optional hover keys
drive the windows. Ghostty themes and Unsplash wallpapers included.

A Rails engine (not isolated): it wraps the host's own controllers and views.

## Requirements

Rails 8 with Propshaft, importmap, Turbo and Stimulus; HAML.

## Wiring it into an app

```ruby
# Gemfile
gem "rori", path: "gems/rori"

# app/controllers/application_controller.rb — every page renders as a window
class ApplicationController < ActionController::Base
  include Rori::Windowed
end

# config/routes.rb
Rails.application.routes.draw do
  draw :rori                  # ⌘K / terminal command lists
  root "rori/desktops#show"   # the blank desk
end

# config/initializers/rori.rb
Rori.configure do |rori|
  rori.records = %w[ User Project ]   # recent records listed in ⌘K
end
```

```js
// app/javascript/controllers/index.js
import { registerRori } from "rori"
registerRori(application)
```

Pages declare how they're shown with `window size:, mode:, workspace:, key:`
(see `Rori::WindowHelper`); links that should open a window use
`rori_link_to`. A parameterless GET route shows up in ⌘K once it has a
label under `rori.commands.routes.<controller>.<action>` in the app's locale.

## CSS

The desk's CSS lives in its own cascade layer, `rori` (sub-layers
`rori.reset`, `rori.tokens`, `rori.base`, `rori.layout`, `rori.components`,
`rori.themes`), so it never mixes into the host's layers. Place it among
yours with one name:

```css
@layer reset, base, rori, layout, components, utilities;
```

Unmentioned, it lands after your layers (it loads later).

It needs nothing from the host: its components use only `--rori-*` tokens,
each falling back from a host token when present — `--color-canvas`,
`--color-surface`, `--color-ink`, `--color-ink-muted`, `--color-line`,
`--color-primary`, `--color-on-primary`, `--color-success`, `--color-danger`,
`--color-hover`, `--color-backdrop`, `--gap`, `--radius`, `--radius-sm`,
`--ease`, `--motion`, `--font-sans`, `--font-mono` — to a built-in default.
Themes set those host tokens, so they re-colour the host's pages as well.

## What the host provides

- **Page styles** (buttons, forms, tables); the desk styles only its chrome.
- **Head tags** (favicons…): override `app/views/layouts/rori/_head.html.haml`.

## Configuration

See `lib/rori.rb` for everything: `app_name`, `records`, `commands`, `keymap`,
`modifier` / `native_modifier` / `native_user_agent`, `hover_keys`,
`terminal_key`, `wallpapers`, theme and wallpaper files and cookies.

After adding a Ghostty theme file to `Rori.themes_directory`, run
`bin/rails rori:themes:build`.

## Tests

The host app's test suite covers the desk (`test/{controllers,models}/rori`).
