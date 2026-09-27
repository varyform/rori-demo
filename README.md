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

## Deploying the public demo

Kamal, one server, SQLite on a volume, jobs inside Puma, TLS from Let's
Encrypt. The image goes through Kamal's local registry, so no registry
account is needed; the server needs Docker-compatible SSH access and a DNS
record for the hostname.

```sh
cp .env.deploy.example .env.deploy   # server, hostname; gitignored
bin/kamal setup           # first time
bin/kamal deploy          # after that
```

`config/deploy.yml` loads `.env.deploy` itself (Kamal doesn't read `.env`
files); variables set in the shell take precedence.

Visitors can create, edit and delete anything; `DemoResetJob` empties the
app's tables and puts the seeds back every night at 04:00 UTC
(`config/recurring.yml`). `bin/kamal replant` does it right away
(`bin/rails demo:replant` locally — it wipes your development data too). Notifications from
server-side commands reach every open desk, so all visitors see each other's
"Search reindexed".

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

The app uses the released gem from rubygems.org. To work on the gem alongside
it, point the Gemfile at a checkout next to this app for as long as you need
(and leave `Gemfile` and `Gemfile.lock` out of commits meanwhile):

```ruby
gem "rori", path: "../rori"   # instead of gem "rori", "~> 0.1"; then bundle install
```

Themes are compiled from the gem's `vendor/themes/ghostty`: after adding one,
run `bin/rails rori:themes:build`.
