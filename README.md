# Desk

A niri-style window manager for Rails pages: every page opens as a window in
scrolling column strips, driven from ⌘K, a drop-down terminal (`` ` ``) and
the keyboard. The desk itself is the [rori](https://github.com/varyform/rori)
engine gem (see its README); this app is its demo host, configured in
`config/initializers/rori.rb`.
See `CHANGELOG.md` for what it does.

## Setup

```sh
bin/setup                 # toolchain, gems, crates, database, seeds; then bin/dev
```

The toolchain (Ruby, Rust and the Tauri CLI for the native app) is pinned in
`mise.toml`; with [mise](https://mise.jdx.dev) installed, `bin/setup` installs
it and runs everything through it. Without mise, provide those tools yourself.
System tests also need Chrome.

## Running

```sh
bin/dev                   # http://desk.localhost:3030 — the only allowed host
```

Native macOS app (⌘ as the shortcut modifier), with `bin/dev` running:

```sh
cd src-tauri && cargo tauri dev
```

## Data

```sh
bin/rails db:seed         # a few users, projects and services
bin/rails db:seed:scale   # + 200 users, 2,000 projects, 300 services
```

`db:seed:scale` bulk-inserts data for checking lists, ⌘K search and live
refreshes at volume. Development only; each run adds on top. Sizes and the
random seed are configurable:

```sh
USERS=50 PROJECTS=500 SERVICES=100 bin/rails db:seed:scale
SEED=42 bin/rails db:seed:scale          # a different, still repeatable data set
```

## Tests

```sh
bin/ci                    # style, security audits, tests, seeds
bin/rails test:system     # browser tests (headless Chrome), not part of bin/ci
```

To work on the gem alongside the app, point Bundler at a local checkout (the
Gemfile keeps the GitHub source; `Gemfile.lock` follows the checkout's HEAD):

```sh
bundle config set --local local.rori ../rori   # absolute path is safest
bundle config unset --local local.rori         # back to GitHub
```

Themes are compiled from the gem's `vendor/themes/ghostty`: after adding one,
run `bin/rails rori:themes:build`.
