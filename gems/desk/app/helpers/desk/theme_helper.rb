module Desk::ThemeHelper
  # desk-theme (theme_controller.js) stores the pick in `Desk.theme_cookie` so the
  # server can render it on <html> and pages don't flash the default theme.
  def current_theme
    Desk::Theme.find(cookies[Desk.theme_cookie])
  end
end
