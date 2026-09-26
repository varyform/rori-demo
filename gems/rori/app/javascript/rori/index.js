// The desk's Stimulus controllers, registered under a `desk` prefix so they
// can't collide with the app's own (a plain `palette` or `theme`, say).
import RoriController from "rori/rori_controller"
import PaletteController from "rori/palette_controller"
import ThemeController from "rori/theme_controller"
import ClockController from "rori/clock_controller"
import WallpaperController from "rori/wallpaper_controller"
import TerminalController from "rori/terminal_controller"

export function registerRori(application) {
  application.register("rori", RoriController)
  application.register("rori-palette", PaletteController)
  application.register("rori-theme", ThemeController)
  application.register("rori-clock", ClockController)
  application.register("rori-wallpaper", WallpaperController)
  application.register("rori-terminal", TerminalController)
}
