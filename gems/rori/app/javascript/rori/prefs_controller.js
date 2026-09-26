import { Controller } from "@hotwired/stimulus"

const ONE_YEAR = 60 * 60 * 24 * 365

// Small cookie-backed preferences, applied as classes on <body> so the server
// renders them on load too:
//   bars (UI › Menu bar › top | bottom) — previews while browsing the list and
//     reverts if you don't pick, like themes.
//   the empty-desk hint — dismissed from the hint, brought back from the
//     keyboard shortcuts modal (which this controller also opens).
export default class extends Controller {
  static targets = ["shortcuts", "hintToggle"]
  static values = { barsCookie: String, bars: String, hintCookie: String }

  run({ detail: { action, param } }) {
    if (action !== "bars") return
    this.barsValue = param
    this.#setCookie(this.barsCookieValue, param)
  }

  preview({ detail: { action, param } }) {
    action === "bars" ? this.#applyBars(param) : this.revert()
  }

  revert() {
    this.#applyBars(this.barsValue)
  }

  barsValueChanged(bars) {
    this.#applyBars(bars)
  }

  openShortcuts() {
    if (this.shortcutsTarget.open) return this.shortcutsTarget.close()
    this.hintToggleTarget.checked = !this.element.classList.contains("hint-hidden")
    this.shortcutsTarget.showModal()
  }

  closeShortcuts() {
    this.shortcutsTarget.close()
  }

  shortcutsBackdrop(event) {
    if (event.target === this.shortcutsTarget) this.closeShortcuts()
  }

  dismissHint() {
    this.#setHint(false)
  }

  toggleHint() {
    this.#setHint(this.hintToggleTarget.checked)
  }

  #setHint(shown) {
    this.element.classList.toggle("hint-hidden", !shown)
    this.#setCookie(this.hintCookieValue, shown ? "" : "hidden")
  }

  #applyBars(bars) {
    this.element.classList.toggle("bars-bottom", bars === "bottom")
  }

  // An empty value removes the cookie.
  #setCookie(name, value) {
    document.cookie = `${name}=${encodeURIComponent(value)}; path=/; max-age=${value ? ONE_YEAR : 0}; samesite=lax`
  }
}
