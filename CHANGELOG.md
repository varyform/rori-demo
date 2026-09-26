# Changelog

Notable changes to the desk, newest first. Each entry names who it's for:
**Users** (people working in the desk) and **Developers** (apps building on it).

## Unreleased

### Added
- **Users:** the macOS app toggles full screen with fn/Globe+F or ⌃⌘F (View → Toggle Full Screen).
- **Users:** on an empty desk, Space or Enter opens ⌘K.
- **Developers:** `bin/rails db:seed:scale` bulk-adds users, projects and services (`USERS=200 PROJECTS=2000 SERVICES=300` by default, `SEED=` for a different repeatable world) to check lists, ⌘K search and refreshes at volume. Development only; each run adds on top.
- **Users:** fuzzy matching spans nested lists in ⌘K and the terminal: `uthen` finds UI › Theme › Nord, `uwc` UI › Wallpaper › Cover bars. Matches are ranked by word and segment starts, runs and gaps (best alignment, not first letters found), shallow paths first when equally good.
- **Users:** a drop-down terminal on `` ` `` (outside text fields; `Desk.terminal_key`, or `⌥``/`⌘`` and ⌘K "Toggle terminal"). It runs every ⌘K command with the same matching: words walk the nested lists (`ui wallpaper cover`, `new user`, `oleh`), Tab completes one level at a time, ↑↓ recall history, `help` lists the top level, `clear` wipes the scrollback.
- **Users:** ⌘K / terminal → UI › Theme and UI › Wallpaper › Safe (inside the desk) | Cover bars (behind the menu and status bars too) | Off, remembered across launches.
- **Developers:** ⌘K and the terminal share one command bus (`desk-command:run|preview|closed|source`, was `desk-palette:*`) and one fuzzy matcher (`desk/fuzzy.js`).
- **Users:** optional wallpapers (`Desk.wallpapers`): a random landscape photo from Unsplash on each launch, tinted toward the current theme and credited in the status bar.
- **Users:** the macOS app zooms like a browser: View → Zoom In / Zoom Out / Actual Size (`⌘=`, `⌘-`, `⌘0`), in steps from 50% to 300%.
- **Users:** the window whose text field has focus wears a green `<input>` tag on its left edge (right edge when there's no room; inside the bottom-left corner of full-width windows), so it's clear keys will type rather than drive the desk.
- **Users:** a native macOS app (`src-tauri`, `cargo tauri dev`) wrapping the desk, where ⌘ is the shortcut modifier (⌘←→ focus, ⌘1–9 workspaces, ⌘W close…; centre column is ⌘⇧C since ⌘C copies).
- **Developers:** development runs on exactly one origin, `http://desk.localhost:3030`; other hosts get 403. Pages served to the app's user agent (`Desk.native_user_agent`) use `Desk.native_modifier`, with `Desk.keymap_overrides` for chords the platform owns.
- **Users:** Blender-style hover keys (opt-in, `Desk.hover_keys`): move the pointer onto an inactive window and bare keys act on it — `W` close, `U` reopen, `R` width, `F` full, `C` centre, `[` `]` stack, `⇧H`/`⇧L` move, `1–9` send to workspace — while the cursor stays in your field. The target shows "keys → here"; it disarms when the pointer rests (`Desk.hover_timeout`, 1.5 s), leaves, or you type any other key.
- **Users:** with no text field focused, the same bare keys act on the focused window (`W` closes it, `U` reopens…); held-down repeats are ignored.
- **Users:** closed windows can be reopened where they were: `⌥⇧T`, hover `U`, or ⌘K "Reopen closed window".
- **Users:** closing a window with unsaved edits asks first.
- **Users:** Services — a larger, multi-section form (source, runtime, health check, environment, notes) that opens as a ⅔-width column instead of a modal; fields go two-up in wide windows.
- **Users:** hovering a field in an inactive window highlights it; one click activates the window and puts the cursor in that field.
- **Users:** tabbing into another window makes it the active one.
- **Users:** Esc inside a window's field hands focus back to the window, so desk shortcuts work again without reaching for the mouse (⌥←/→ keep jumping words while you type).
- **Developers:** shortcuts live in one table, `Desk.keymap` (action → `KeyboardEvent#code` chords), with `Mod` standing for `Desk.modifier` (`Alt` by default; `Meta` or `Control` for a native shell such as Tauri). ⌘K commands and shortcuts share the same actions, and the status-bar hint shows the configured modifier.
- **Users:** `⌥⇧1–9` moves the focused column to workspace 1–9 (creating it if needed) and follows it there.
- **Users:** ⌘K → "Move column to workspace…" lists the other workspaces plus "New workspace".
- **Developers:** window pages lay out against the window width (`container-type: inline-size` on the window body), so `@container` queries adapt to column width.
- **Developers:** nested palette lists can come from the browser: give a `Desk::Command` a `source:` and answer the `desk-palette:source` event with `detail.items`.

### Fixed
- **Users:** in the macOS app, Esc no longer takes the window out of full screen — also when it's closing a modal; it still closes dialogs, leaves fields and exits the overview.
- **Users:** after running a ⌘K command, the next bare key or shortcut (`W`, `⌥W`, `` ` ``…) no longer occasionally does nothing: focus left behind in the closed palette's search box was treated as typing.
- **Users:** table row lines now run to the window's edges instead of stopping short at its padding; text stays aligned with the rest of the window.
- **Users:** zoomed in (or on narrow screens), focused windows were only partly revealed: the page grew wider than the window to fit the status-bar hint, so the desk scrolled against the wrong width.
- **Users:** a form with unsaved edits is no longer reset when a live update refreshes its window.
- **Users:** clicking a partly off-screen window no longer misses: the strip scrolls it into view after the click, not during it.
- **Users:** the palette no longer shows the parent list under a nested list's breadcrumb when a slow response lands late.
- **Users:** Enter pressed while a palette list is loading now runs once the list arrives instead of being dropped.
- **Users:** a resting mouse pointer no longer steals the palette selection from the keyboard when the list re-renders.

## 2026-09-25

### Added
- **Users:** a niri-style desk — pages open as windows in endlessly scrolling column strips, one strip per workspace, stacked vertically; keyboard focus/move, column widths, stacking, overview and a minimap.
- **Users:** ⌘K command palette with fuzzy search over pages, records and desk actions; frequently used commands rank higher.
- **Users:** 14 Ghostty colour themes, picked from ⌘K → "Pick theme…" with live preview.
- **Users:** the layout survives a reload; broadcast updates refresh only the windows showing the changed data.
- **Developers:** pages declare how they're shown (`window size:, mode:, workspace:, key:`); windows with the same key are reused.
- **Developers:** everything desk-specific lives under the `Desk` namespace and is configured in `config/initializers/desk.rb`.

### Fixed
- **Users:** opening a hovered link in a new window no longer shows "couldn't be shown" (Turbo hover prefetch is disabled).
- **Users:** 1Password's inline menu no longer covers form fields.
