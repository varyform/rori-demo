import { Controller } from "@hotwired/stimulus"
import { score } from "rori/fuzzy"
import { CommandIndex } from "rori/command_index"

const USAGE_KEY = "rori:palette:usage"
// Shared with the terminal: whoever runs commands listens on rori-command:*.
const BUS = "rori-command"

// ⌘K command palette. Command lists are server-rendered into a turbo-frame
// (the root list is fetched on every open so new records show up) and ranked
// client-side, with a bonus for commands you run often. Enter pressed while a
// list is still arriving runs once it lands.
//
// Commands with `data-children` are nested lists: picking one swaps the frame
// to that URL and pushes a breadcrumb; Backspace on an empty query or Esc goes
// back up. Runs are handed out as `rori-command:run`, the selection as
// `rori-command:preview` (e.g. live theme preview), and `rori-command:closed`
// on close.
export default class extends Controller {
  static targets = ["dialog", "input", "frame", "list", "item", "itemTemplate", "empty", "crumbs"]
  static values = { root: String }

  connect() {
    this.stack = []
  }

  keydown(event) {
    if (!(event.metaKey || event.ctrlKey) || event.key.toLowerCase() !== "k") return
    event.preventDefault()
    this.dialogTarget.open ? this.close() : this.open()
  }

  open() {
    this.returnFocus = document.activeElement
    this.inputTarget.value = ""
    this.dialogTarget.showModal()
    // Flattened tree for top-level queries, crawled in the background.
    this.index = new CommandIndex(this.rootValue, {
      source: (source) => this.dispatch("source", { prefix: BUS, detail: { source, items: [] } }).detail.items,
    })
    this.index.entries()
    this.#go([])
    this.filter()
  }

  // Every close goes through here (Esc included, see navigate), so focus is back
  // on the page before the next keystroke: Chrome sometimes leaves it on the
  // closed dialog's input, where the next key would vanish.
  close() {
    this.pendingRun = null
    this.dialogTarget.close()
    if (!this.dialogTarget.contains(document.activeElement)) return
    const back = this.returnFocus
    back?.isConnected && back !== document.body ? back.focus({ preventScroll: true }) : document.activeElement.blur()
  }

  closed() {
    this.dispatch("closed", { prefix: BUS })
  }

  backdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }

  // The new list is in: rank it, then run an Enter that was waiting for it.
  loaded() {
    // A response that had already arrived still renders after its request was
    // cancelled, so a stale list can land after drilling in; put the right one back.
    const top = this.stack.at(-1)
    if (top?.source) return this.#showSourceList(top.source)
    const expected = top?.src || this.rootValue
    if (this.#path(this.frameTarget.getAttribute("src")) !== this.#path(expected)) {
      return this.frameTarget.setAttribute("src", expected)
    }

    this.navigating = false
    this.filter()
    this.#runPending()
  }

  filter() {
    const query = this.inputTarget.value
    // At the top, queries match whole paths through the tree ("uthen" → UI › Theme › Nord).
    if (!this.stack.length && query.trim()) return this.#searchPaths(query)
    this.#clearPathResults()
    const usage = this.#usage()
    const ranked = this.itemTargets.map((item, i) => {
      item.dataset.index ||= i
      const match = score(item.dataset.search, query)
      item.hidden = match <= 0
      return { item, score: match + Math.log2(1 + (usage[this.#id(item)] || 0)), match }
    })
    const visible = ranked
      .filter(({ match }) => match > 0)
      .sort((a, b) => b.score - a.score || a.item.dataset.index - b.item.dataset.index)

    // Nested lists keep their server order, so a browsed list reads the same every time.
    if (this.hasListTarget && (query.trim() || !this.stack.length)) this.listTarget.append(...visible.map(({ item }) => item))
    this.emptyTarget.hidden = visible.length > 0 || this.#loading()

    const current = !query.trim() && visible.find(({ item }) => "current" in item.dataset)
    this.#select((current || visible[0])?.item)
  }

  navigate(event) {
    const items = this.itemTargets.filter((item) => !item.hidden)
    const index = items.indexOf(this.selected)

    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault()
      const next = event.key === "ArrowDown" ? index + 1 : index - 1
      this.#select(items[(next + items.length) % items.length])
    } else if (event.key === "Enter") {
      event.preventDefault()
      const newWindow = event.shiftKey || event.metaKey || event.ctrlKey
      if (this.navigating || this.searching) this.pendingRun = { newWindow }
      else if (this.selected) this.#run(this.selected, newWindow)
    } else if (event.key === "Escape" && !this.stack.length) {
      event.preventDefault()
      this.close()
    } else if (this.stack.length && (event.key === "Escape" || (event.key === "Backspace" && !this.inputTarget.value))) {
      event.preventDefault()
      this.#go(this.stack.slice(0, -1))
    }
  }

  pick(event) {
    this.#run(event.currentTarget, event.shiftKey || event.metaKey || event.ctrlKey)
  }

  // Browsers fire mousemove when a list re-renders under a resting pointer; only
  // a real move may take the selection from the keyboard.
  hover(event) {
    const pointer = `${event.screenX},${event.screenY}`
    const moved = this.pointer !== undefined && this.pointer !== pointer
    this.pointer = pointer
    if (moved && this.selected !== event.currentTarget) this.#select(event.currentTarget)
  }

  #run(item, newWindow) {
    const usage = this.#usage()
    const id = this.#id(item)
    usage[id] = (usage[id] || 0) + 1
    localStorage.setItem(USAGE_KEY, JSON.stringify(usage))

    const { children: src, source, trail } = item.dataset
    if (trail && (src || source)) {
      return this.#go([...this.stack, ...JSON.parse(trail).map(({ label, children, source }) => ({ label, src: children, source }))])
    }
    if (src || source) {
      return this.#go([...this.stack, { label: item.querySelector(".rori-palette__label").firstChild.textContent.trim(), src, source }])
    }
    this.close()
    this.dispatch("run", { prefix: BUS, detail: this.#detail(item, { newWindow }) })
  }

  async #searchPaths(query) {
    const ticket = (this.ticket = (this.ticket || 0) + 1)
    this.searching = true
    const usage = this.#usage()
    const results = await this.index.search(query, { limit: 30, bonus: (item) => Math.log2(1 + (usage[this.#idOf(item)] || 0)) })
    if (ticket !== this.ticket || !this.dialogTarget.open) return

    this.searching = false
    // Until the root list has loaded there's nowhere to put results; loaded() refilters.
    if (!this.hasListTarget) return
    this.itemTargets.forEach((item) => { item.hidden = true })
    this.#clearPathResults()
    const items = results.map(({ item, trail, text }) => {
      const trailData = trail.map(({ label, children, source }) => ({ label, children, source }))
      const built = this.#buildItem({ ...item, label: text, trail: JSON.stringify(trailData) })
      built.dataset.pathResult = ""
      return built
    })
    this.listTarget.prepend(...items)
    this.emptyTarget.hidden = items.length > 0
    this.#select(items[0])
    this.#runPending()
  }

  #clearPathResults() {
    this.ticket = (this.ticket || 0) + 1
    this.searching = false
    this.itemTargets.filter((item) => "pathResult" in item.dataset).forEach((item) => item.remove())
  }

  #runPending() {
    if (this.navigating || this.searching) return
    const pending = this.pendingRun
    this.pendingRun = null
    if (pending && this.selected) this.#run(this.selected, pending.newWindow)
  }

  // Shows the list at the end of `stack` (the root list when empty).
  #go(stack) {
    this.#clearPathResults()
    this.stack = stack
    this.inputTarget.value = ""
    this.crumbsTarget.hidden = !stack.length
    this.crumbsTarget.textContent = stack.map(({ label }) => `${label} ›`).join(" ")
    const top = stack.at(-1)
    if (top?.source) return this.#showSourceList(top.source)

    // Until the new list arrives the old one is still showing; don't run it.
    this.navigating = true
    this.pendingRun = null
    this.frameTarget.setAttribute("src", top?.src || this.rootValue)
    this.inputTarget.focus()
  }

  // A nested list another controller provides at runtime, for state that only
  // exists in the browser: `rori-command:source` asks, the listener fills
  // `detail.items` with { label, group, action, param }.
  #showSourceList(source) {
    const { detail } = this.dispatch("source", { prefix: BUS, detail: { source, items: [] } })
    const list = document.createElement("ul")
    list.className = "rori-palette__list"
    list.setAttribute("role", "listbox")
    list.dataset.roriPaletteTarget = "list"
    list.append(...detail.items.map((attributes) => this.#buildItem(attributes)))

    this.navigating = false
    this.frameTarget.removeAttribute("src")
    this.frameTarget.replaceChildren(list)
    this.filter()
    this.inputTarget.focus()
  }

  #buildItem({ label, group, action, param, url, children, source, trail, current, shortcut }) {
    const item = this.itemTemplateTarget.content.firstElementChild.cloneNode(true)
    const data = { roriAction: action, param: param ?? "", url, children, source, trail, shortcut, search: `${label} ${group}` }
    for (const [key, value] of Object.entries(data)) if (value !== undefined) item.dataset[key] = value
    if (current) item.dataset.current = ""
    item.querySelector(".rori-palette__label").textContent = label + (children || source ? " ›" : "")
    const groupElement = item.querySelector(".rori-palette__group")
    groupElement.textContent = (current ? "✓ " : "") + group
    if (shortcut) {
      const kbd = document.createElement("kbd")
      kbd.className = "rori-palette__shortcut"
      kbd.textContent = shortcut
      groupElement.before(kbd)
    }
    return item
  }

  #path(url) {
    if (!url) return null
    const { pathname, search } = new URL(url, location.href)
    return pathname + search
  }

  #loading() {
    const frame = this.frameTarget
    return frame.hasAttribute("busy") || (frame.hasAttribute("src") && !frame.hasAttribute("complete"))
  }

  #select(item) {
    this.itemTargets.forEach((other) => other.setAttribute("aria-selected", other === item))
    this.selected = item
    item?.scrollIntoView({ block: "nearest" })
    // A list can finish loading after the palette closed; previewing then would undo the pick.
    if (item && this.dialogTarget.open) this.dispatch("preview", { prefix: BUS, detail: this.#detail(item) })
  }

  #detail(item, extra = {}) {
    const { url, roriAction: action, param } = item.dataset
    return { url, action, param, ...extra }
  }

  #id(item) {
    const { url, roriAction: action, param, children, source } = item.dataset
    return this.#idOf({ url, action, param, children, source })
  }

  #idOf({ url, action, param, children, source }) {
    return url || children || source || [action, param].filter((part) => part !== undefined).join(":")
  }

  #usage() {
    try {
      return JSON.parse(localStorage.getItem(USAGE_KEY)) || {}
    } catch {
      return {}
    }
  }
}
