# An optional background photo behind the strips (Rori.wallpapers). One is
# picked at random per full page load — the desk's "launch" — unless one is
# pinned; window frames never re-render the shell, so it stays put while you
# work. UI › Wallpaper › Next swaps it in place (rori-wallpaper).
#
# The pool is the bundled Unsplash photos (hotlinked, resized by their CDN), or
# the images in the app's own `Rori.wallpapers_folder` asset folder.
class Rori::Wallpaper < Data.define(:id, :local)
  CDN = "https://images.unsplash.com"
  IMAGE = /\.(jpe?g|png|webp|avif)\z/i

  # safe: inside the desk only; cover: behind the menu bar too.
  MODES = %w[ safe cover off ].freeze

  class << self
    def all = Rori.wallpapers_folder ? local : unsplash

    def unsplash = YAML.load_file(Rori.wallpapers_file).map { new(id: it.to_s) }

    # Images under the folder, as asset logical paths (`paths` for tests).
    def local(paths = asset_paths)
      prefix = "#{Rori.wallpapers_folder.to_s.delete_suffix("/")}/"
      paths.select { it.start_with?(prefix) && it.match?(IMAGE) }.sort.map { new(id: it, local: true) }
    end

    def find(id) = id.presence && all.find { it.id == id }

    # The pinned one if it's still in the pool, a random one otherwise.
    def pick(pinned = nil)
      (find(pinned) || all.sample) if Rori.wallpapers
    end

    def mode(value) = MODES.include?(value) ? value : MODES.first

    private
      def asset_paths = Rails.application.assets.load_path.assets.map { it.logical_path.to_s }
  end

  def initialize(id:, local: false) = super

  # imgix resizes on the fly; image-set lets hi-dpi screens take the sharper one.
  def url(width) = "#{CDN}/photo-#{id}?auto=format&fit=crop&w=#{width}&q=75"

  def css_image
    local ? %(url("#{ActionController::Base.helpers.asset_path(id)}")) : %(image-set(url("#{url(1920)}") 1x, url("#{url(3200)}") 2x))
  end

  # Where the status-bar credit links: the full photo on Unsplash; local
  # wallpapers are the app's own and get no credit.
  def credit_url = (url(3200) unless local)

  # What rori-wallpaper needs to swap it in without a reload.
  def as_json(*) = { id:, image: css_image, credit: credit_url }
end
