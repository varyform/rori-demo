#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::sync::Mutex;
use tauri::menu::{Menu, MenuItem, PredefinedMenuItem, Submenu};
use tauri::Manager;

// Browser-like zoom steps; ACTUAL_SIZE is 100%.
const ZOOM_LEVELS: [f64; 13] = [
    0.5, 0.67, 0.75, 0.8, 0.9, 1.0, 1.1, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0,
];
const ACTUAL_SIZE: usize = 5;

struct Zoom(Mutex<usize>);

// A thin native window around the Rails desk. The webview's user agent carries
// "DeskApp" (tauri.conf.json), which makes Rails render the ⌘ keymap.
fn main() {
    tauri::Builder::default()
        .manage(Zoom(Mutex::new(ACTUAL_SIZE)))
        .menu(|app| {
            // App, Edit and View only. Edit keeps ⌘C/⌘V/⌘X/⌘Z/⌘A working in the
            // webview; leaving out File, Window and Hide frees ⌘W, ⌘M and ⌘H for
            // the desk's keymap (menu shortcuts win over the page). ⌘= ⌘- ⌘0 zoom
            // the page; the desk keymap uses none of them.
            let app_menu = Submenu::with_items(
                app,
                "Desk",
                true,
                &[
                    &PredefinedMenuItem::about(app, None, None)?,
                    &PredefinedMenuItem::separator(app)?,
                    &PredefinedMenuItem::quit(app, None)?,
                ],
            )?;
            let edit_menu = Submenu::with_items(
                app,
                "Edit",
                true,
                &[
                    &PredefinedMenuItem::undo(app, None)?,
                    &PredefinedMenuItem::redo(app, None)?,
                    &PredefinedMenuItem::separator(app)?,
                    &PredefinedMenuItem::cut(app, None)?,
                    &PredefinedMenuItem::copy(app, None)?,
                    &PredefinedMenuItem::paste(app, None)?,
                    &PredefinedMenuItem::select_all(app, None)?,
                ],
            )?;
            let view_menu = Submenu::with_items(
                app,
                "View",
                true,
                &[
                    &MenuItem::with_id(app, "zoom_in", "Zoom In", true, Some("CmdOrCtrl+="))?,
                    &MenuItem::with_id(app, "zoom_out", "Zoom Out", true, Some("CmdOrCtrl+-"))?,
                    &MenuItem::with_id(
                        app,
                        "zoom_reset",
                        "Actual Size",
                        true,
                        Some("CmdOrCtrl+0"),
                    )?,
                ],
            )?;
            Menu::with_items(app, &[&app_menu, &edit_menu, &view_menu])
        })
        .on_menu_event(|app, event| {
            let zoom = app.state::<Zoom>();
            let mut level = zoom.0.lock().unwrap();
            *level = match event.id().as_ref() {
                "zoom_in" => (*level + 1).min(ZOOM_LEVELS.len() - 1),
                "zoom_out" => level.saturating_sub(1),
                "zoom_reset" => ACTUAL_SIZE,
                _ => return,
            };
            if let Some(window) = app.get_webview_window("main") {
                let _ = window.set_zoom(ZOOM_LEVELS[*level]);
            }
        })
        .run(tauri::generate_context!())
        .expect("error while running the Desk app");
}
