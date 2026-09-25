# An optional background photo behind the strips (Desk.wallpapers). One is
# picked at random per full page load — the desk's "launch"; window frames
# never re-render the shell, so it stays put while you work.
class Desk::Wallpaper < Data.define(:id)
  CDN = "https://images.unsplash.com"

  class << self
    def all = YAML.load_file(Desk.wallpapers_file).map { new(id: it.to_s) }

    def random
      all.sample if Desk.wallpapers
    end
  end

  # imgix resizes on the fly; image-set lets hi-dpi screens take the sharper one.
  def url(width) = "#{CDN}/photo-#{id}?auto=format&fit=crop&w=#{width}&q=75"

  def css_image = "image-set(url(\"#{url(1920)}\") 1x, url(\"#{url(3200)}\") 2x)"
end
