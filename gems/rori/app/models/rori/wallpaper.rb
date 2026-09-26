# An optional background photo behind the strips (Rori.wallpapers). One is
# picked at random per full page load — the desk's "launch"; window frames
# never re-render the shell, so it stays put while you work.
class Rori::Wallpaper < Data.define(:id)
  CDN = "https://images.unsplash.com"

  # safe: inside the desk only; cover: behind the menu and status bars too.
  MODES = %w[ safe cover off ].freeze

  class << self
    def all = YAML.load_file(Rori.wallpapers_file).map { new(id: it.to_s) }

    def random
      all.sample if Rori.wallpapers
    end

    def mode(value) = MODES.include?(value) ? value : MODES.first
  end

  # imgix resizes on the fly; image-set lets hi-dpi screens take the sharper one.
  def url(width) = "#{CDN}/photo-#{id}?auto=format&fit=crop&w=#{width}&q=75"

  def css_image = "image-set(url(\"#{url(1920)}\") 1x, url(\"#{url(3200)}\") 2x)"
end
