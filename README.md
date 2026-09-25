# Desk

A niri-style window manager for Rails pages: every page opens as a window in
scrolling column strips, driven from ⌘K, a drop-down terminal (`` ` ``) and
the keyboard. Everything desk-specific lives under the `Desk` namespace and is
configured in `config/initializers/desk.rb`; see `CHANGELOG.md` for what it does.

## Setup

```sh
bin/setup                 # gems, database, seeds
```

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

Themes are compiled from `vendor/themes/ghostty`: after adding one, run
`bin/rails desk:themes:build`.
