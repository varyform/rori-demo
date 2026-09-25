module ThemeHelper
  # theme_controller.js stores the pick in this cookie so the server can render
  # it on <html> and pages don't flash the default theme on load.
  THEME_COOKIE = "theme"

  def current_theme
    Theme.find(cookies[THEME_COOKIE])
  end
end
