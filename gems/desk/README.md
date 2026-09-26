# Desk

A niri-style window manager for Rails pages. Every page opens as a window in
endlessly scrolling column strips, one strip per workspace; ⌘K and a
drop-down terminal (`` ` ``) run one fuzzy-matched command tree; a keymap
with a configurable modifier (⌘ in a native shell) and optional hover keys
drive the windows. Ghostty themes and Unsplash wallpapers included.

A Rails engine (not isolated): it wraps the host's own controllers and views.

## Requirements

Rails 8 with Propshaft, importmap, Turbo and Stimulus; HAML.

## Wiring it into an app

```ruby
# Gemfile
gem "desk", path: "gems/desk"

# app/controllers/application_controller.rb — every page renders as a window
class ApplicationController < ActionController::Base
  include Desk::Windowed
end

# config/routes.rb
Rails.application.routes.draw do
  draw :desk                  # ⌘K / terminal command lists
  root "desk/desktops#show"   # the blank desk
end

# config/initializers/desk.rb
Desk.configure do |desk|
  desk.records = %w[ User Project ]   # recent records listed in ⌘K
end
```

```js
// app/javascript/controllers/index.js
import { registerDesk } from "desk"
registerDesk(application)
```

Pages declare how they're shown with `window size:, mode:, workspace:, key:`
(see `Desk::WindowHelper`); links that should open a window use
`desk_link_to`. A parameterless GET route shows up in ⌘K once it has a
label under `desk.commands.routes.<controller>.<action>` in the app's locale.

## What the host provides

- **Design tokens** in its own CSS, loaded before the desk's (the shell links
  `stylesheet_link_tag :app` first): `@layer reset, base, layout, components,
  utilities`, the `--color-*` semantic tokens, `--gap`, `--radius`,
  `--radius-sm`, `--ease`, `--motion`, `--font-sans`, `--font-mono`. Themes
  override the colour tokens.
- **Page styles** (buttons, forms, tables); the desk styles only its chrome.
- **Head tags** (favicons…): override `app/views/layouts/desk/_head.html.haml`.

## Configuration

See `lib/desk.rb` for everything: `app_name`, `records`, `commands`, `keymap`,
`modifier` / `native_modifier` / `native_user_agent`, `hover_keys`,
`terminal_key`, `wallpapers`, theme and wallpaper files and cookies.

After adding a Ghostty theme file to `Desk.themes_directory`, run
`bin/rails desk:themes:build`.

## Tests

The host app's test suite covers the desk (`test/{controllers,models}/desk`).
