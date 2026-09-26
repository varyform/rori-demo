import { Controller } from "@hotwired/stimulus"

const ONE_YEAR = 60 * 60 * 24 * 365

// Applies the UI › Wallpaper commands:
//   wallpaper (safe | cover | off) — classes on <body>: the photo inside the
//     desk, behind the bars too, or none. Previews as you move through the
//     list and reverts if you don't pick, like rori-theme.
//   wallpaper_next — the next photo in the pool, swapped in place.
//   wallpaper_pin  — keep the current photo across launches (toggles).
// Mode and pin live in cookies so the server renders them on load.
export default class extends Controller {
  static targets = ["credit"]
  static values = { cookie: String, mode: String, pinCookie: String, pool: Array, current: String, pinned: Boolean }

  run({ detail: { action, param } }) {
    if (action === "wallpaper") {
      this.modeValue = param
      this.#setCookie(this.cookieValue, param)
    } else if (action === "wallpaper_next") {
      this.#next()
    } else if (action === "wallpaper_pin") {
      this.pinnedValue = !this.pinnedValue
      this.#setCookie(this.pinCookieValue, this.pinnedValue ? this.currentValue : "")
    }
  }

  preview({ detail: { action, param } }) {
    action === "wallpaper" ? this.#apply(param) : this.revert()
  }

  revert() {
    this.#apply(this.modeValue)
  }

  modeValueChanged(mode) {
    this.#apply(mode)
  }

  #next() {
    const pool = this.poolValue
    if (pool.length < 2) return
    const index = pool.findIndex(({ id }) => id === this.currentValue)
    const wallpaper = pool[(index + 1) % pool.length]

    this.element.style.setProperty("--rori-wallpaper", wallpaper.image)
    this.currentValue = wallpaper.id
    if (this.pinnedValue) this.#setCookie(this.pinCookieValue, wallpaper.id)
    if (this.hasCreditTarget) {
      this.creditTarget.hidden = !wallpaper.credit
      if (wallpaper.credit) this.creditTarget.href = wallpaper.credit
    }
    this.#apply(this.modeValue)
  }

  #apply(mode) {
    // Without a photo on the page (Rori.wallpapers off) there's nothing to show.
    const photo = this.element.style.getPropertyValue("--rori-wallpaper") !== ""
    this.element.classList.toggle("has-wallpaper", photo && mode !== "off")
    this.element.classList.toggle("wallpaper-cover", mode === "cover")
  }

  // An empty value removes the cookie.
  #setCookie(name, value) {
    document.cookie = `${name}=${encodeURIComponent(value)}; path=/; max-age=${value ? ONE_YEAR : 0}; samesite=lax`
  }
}
