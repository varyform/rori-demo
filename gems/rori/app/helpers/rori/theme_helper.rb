module Rori::ThemeHelper
  # rori-theme (theme_controller.js) stores the pick in `Rori.theme_cookie` so the
  # server can render it on <html> and pages don't flash the default theme.
  def current_theme
    Rori::Theme.find(cookies[Rori.theme_cookie])
  end

  # The app's own themes (Rori.themes_folder), inline: every one, so the palette
  # can preview them. After the desk's stylesheets, so rori.themes is in order.
  def rori_local_themes_style_tag
    themes = Rori::Theme.local
    tag.style(Rori::Theme.css(themes).html_safe, nonce: content_security_policy_nonce) if themes.any?
  end
end
