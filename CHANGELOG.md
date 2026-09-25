# Changelog

Notable changes to the desk, newest first. Each entry names who it's for:
**Users** (people working in the desk) and **Developers** (apps building on it).

## Unreleased

### Added
- **Users:** Services — a larger, multi-section form (source, runtime, health check, environment, notes) that opens as a ⅔-width column instead of a modal; fields go two-up in wide windows.
- **Users:** hovering a field in an inactive window highlights it; one click activates the window and puts the cursor in that field.
- **Users:** tabbing into another window makes it the active one.
- **Users:** `⌥⇧1–9` moves the focused column to workspace 1–9 (creating it if needed) and follows it there.
- **Users:** ⌘K → "Move column to workspace…" lists the other workspaces plus "New workspace".
- **Developers:** window pages lay out against the window width (`container-type: inline-size` on the window body), so `@container` queries adapt to column width.
- **Developers:** nested palette lists can come from the browser: give a `Desk::Command` a `source:` and answer the `desk-palette:source` event with `detail.items`.

### Fixed
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
