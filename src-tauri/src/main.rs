#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use tauri::menu::{Menu, PredefinedMenuItem, Submenu};

// A thin native window around the Rails desk. The webview's user agent carries
// "DeskApp" (tauri.conf.json), which makes Rails render the ⌘ keymap.
fn main() {
    tauri::Builder::default()
        .menu(|app| {
            // Only the app and Edit menus. Edit keeps ⌘C/⌘V/⌘X/⌘Z/⌘A working in
            // the webview; leaving out File, Window and Hide frees ⌘W, ⌘M and ⌘H
            // for the desk's keymap (menu shortcuts win over the page).
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
            Menu::with_items(app, &[&app_menu, &edit_menu])
        })
        .run(tauri::generate_context!())
        .expect("error while running the Desk app");
}
