import { Controller } from "@hotwired/stimulus"

const ONE_YEAR = 60 * 60 * 24 * 365

// Applies "wallpaper" commands (UI › Wallpaper › safe | cover | off): classes on
// <body> switch between the photo inside the desk, behind the bars too, or none.
// Like rori-theme, the list previews as you move and reverts if you don't pick;
// the choice lives in a cookie so the server renders it on load.
export default class extends Controller {
  static values = { cookie: String, mode: String }

  run({ detail: { action, param } }) {
    if (action !== "wallpaper") return
    this.modeValue = param
    document.cookie = `${this.cookieValue}=${encodeURIComponent(param)}; path=/; max-age=${ONE_YEAR}; samesite=lax`
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

  #apply(mode) {
    // Without a photo on the page (Rori.wallpapers off) there's nothing to show.
    const photo = this.element.style.getPropertyValue("--rori-wallpaper") !== ""
    this.element.classList.toggle("has-wallpaper", photo && mode !== "off")
    this.element.classList.toggle("wallpaper-cover", mode === "cover")
  }
}
