import { Controller } from "@hotwired/stimulus"

const ONE_YEAR = 60 * 60 * 24 * 365

// Applies palette "theme" commands. Moving through the theme list previews
// each one; closing the palette without picking reverts to the saved theme.
// The pick lives in a cookie so the server renders it on <html> (no flash).
export default class extends Controller {
  static values = { cookie: String }

  run({ detail: { action, param } }) {
    if (action !== "theme") return
    this.#apply(param)
    document.cookie = `${this.cookieValue}=${encodeURIComponent(param)}; path=/; max-age=${param ? ONE_YEAR : 0}; samesite=lax`
  }

  preview({ detail: { action, param } }) {
    action === "theme" ? this.#apply(param) : this.revert()
  }

  revert() {
    this.#apply(this.#saved())
  }

  #apply(slug) {
    const root = document.documentElement
    if (slug) root.dataset.theme = slug
    else delete root.dataset.theme
  }

  #saved() {
    const pair = document.cookie.split("; ").find((entry) => entry.startsWith(`${this.cookieValue}=`))
    return pair ? decodeURIComponent(pair.split("=")[1]) : ""
  }
}
