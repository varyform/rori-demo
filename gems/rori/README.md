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

### Your own themes and wallpapers

```ruby
Rori.configure do |rori|
  rori.themes_folder = "config/themes"   # Ghostty theme files (relative to Rails.root)
  rori.wallpapers = true
  rori.wallpapers_folder = "wallpapers"  # app/assets/images/wallpapers/*.{jpg,png,webp,avif}
end
```

- **Themes:** any Ghostty theme file (e.g. from
  [iTerm2-Color-Schemes/ghostty](https://github.com/mbadolato/iTerm2-Color-Schemes/tree/master/ghostty))
  dropped into the folder shows up in UI › Theme next to the bundled ones; a
  file with a bundled theme's name replaces it. No build step — their CSS is
  rendered into the page.
- **Wallpapers:** the folder is a path inside the app's asset load path, so
  images are fingerprinted and served by Propshaft. When set, its images
  replace the bundled Unsplash photos.
- UI › Wallpaper › **Next wallpaper** swaps the photo in place; **Pin
  wallpaper** keeps the current one across launches (toggle).

The bundled themes are compiled into the gem's `themes.css`; after changing
`Rori.themes_directory`, run `bin/rails rori:themes:build`.

## Customising the look

The desk's chrome reads only its own `--rori-*` tokens, and each one defaults
to your token of the same meaning. So there are three levels, from broad to
precise:

1. **Your design tokens** — set them as usual; the desk follows:
   ```css
   :root { --radius: 4px; --radius-sm: 2px; --gap: 8px; --font-sans: "Inter", sans-serif; }
   ```
   Supported: `--color-canvas|surface|ink|ink-muted|line|primary|on-primary|success|danger|hover|backdrop`,
   `--gap`, `--radius`, `--radius-sm`, `--ease`, `--motion`, `--font-sans`, `--font-mono`.
2. **Desk-only tokens** — change the desk without touching your pages:
   ```css
   @layer overrides {        /* any layer AFTER `rori`, or unlayered */
     :root { --rori-radius: 0; --rori-gap: 16px; }
   }
   ```
3. **Components** — every chrome element has a `rori-` class
   (`.rori-win`, `.rori-win__bar`, `.rori-menubar`, `.rori-statusbar`,
   `.rori-palette`, `.rori-terminal`, `.rori-col`…):
   ```css
   @layer overrides {
     .rori-win { border-radius: 0; box-shadow: none; }
     .rori-win__bar { height: 26px; }
   }
   ```

**The one rule: overrides must come after the `rori` layer.** Cascade layers
beat specificity, so a rule in a layer *before* `rori` loses even with a more
specific selector — and so does a `--rori-*` token set there, since
`rori.tokens` defines them on `:root` too. Put overrides in a later layer
(`components`, `utilities`, a dedicated `overrides`) or leave them unlayered.
Overriding your own tokens (level 1) works from any layer, because the desk
only reads them.

Themes set the `--color-*` tokens, so a theme picked in UI › Theme wins over
level-1 colours; use level 2 (`--rori-ink`, `--rori-surface`…) for colours a
theme mustn't change.

## Tests

The host app's test suite covers the desk (`test/{controllers,models}/rori`).
