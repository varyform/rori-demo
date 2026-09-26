// The desk's Stimulus controllers, registered under a `desk` prefix so they
// can't collide with the app's own (a plain `palette` or `theme`, say).
import DeskController from "desk/desk_controller"
import PaletteController from "desk/palette_controller"
import ThemeController from "desk/theme_controller"
import ClockController from "desk/clock_controller"
import WallpaperController from "desk/wallpaper_controller"
import TerminalController from "desk/terminal_controller"

export function registerDesk(application) {
  application.register("desk", DeskController)
  application.register("desk-palette", PaletteController)
  application.register("desk-theme", ThemeController)
  application.register("desk-clock", ClockController)
  application.register("desk-wallpaper", WallpaperController)
  application.register("desk-terminal", TerminalController)
}
