# An OKLCH color. Theme files are sRGB hex; the app's CSS speaks oklch().
class Rori::Theme::Color < Data.define(:lightness, :chroma, :hue)
  class << self
    # sRGB hex → linear RGB → OKLab → OKLCH (https://bottosson.github.io/posts/oklab/).
    def from_hex(hex)
      r, g, b = hex.delete_prefix("#").scan(/../).map { linear(it.to_i(16) / 255.0) }

      l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
      m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
      s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)

      lab_l = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
      lab_a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
      lab_b = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s

      new(lightness: lab_l, chroma: Math.hypot(lab_a, lab_b), hue: Math.atan2(lab_b, lab_a) * 180 / Math::PI % 360)
    end

    private
      def linear(channel) = channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055)**2.4
  end

  def darken(amount) = with(lightness: (lightness - amount).clamp(0, 1))

  # Near-greys have no meaningful hue; pin it so rounding noise doesn't churn the stylesheet.
  def to_s
    hue = chroma < 0.002 ? 0 : self.hue
    format("oklch(%.4f %.4f %.2f)", lightness, chroma, hue)
  end
end
