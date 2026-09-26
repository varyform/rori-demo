module Rori::ThemeHelper
  # rori-theme (theme_controller.js) stores the pick in `Rori.theme_cookie` so the
  # server can render it on <html> and pages don't flash the default theme.
  def current_theme
    Rori::Theme.find(cookies[Rori.theme_cookie])
  end
end
