import { Controller } from "@hotwired/stimulus"

const USAGE_KEY = "desk:palette:usage"

// Subsequence match: every query character must appear in order. Consecutive
// runs and word starts score higher; shorter labels win ties.
function score(text, query) {
  query = query.trim().toLowerCase()
  if (!query) return 1
  text = text.toLowerCase()

  let total = 0
  let from = 0
  let previous = -2
  for (const char of query) {
    if (char === " ") continue
    const at = text.indexOf(char, from)
    if (at < 0) return 0
    total += 1
    if (at === previous + 1) total += 3
    if (at === 0 || " /-_".includes(text[at - 1])) total += 2
    previous = at
    from = at + 1
  }
  return total - text.length / 100
}

// ⌘K command palette. Command lists are server-rendered into a turbo-frame
// (the root list is fetched on every open so new records show up) and ranked
// client-side, with a bonus for commands you run often. Enter pressed while a
// list is still arriving runs once it lands.
//
// Commands with `data-children` are nested lists: picking one swaps the frame
// to that URL and pushes a breadcrumb; Backspace on an empty query or Esc goes
// back up. Runs are handed out as `desk-palette:run`, the selection as
// `desk-palette:preview` (e.g. live theme preview), and `desk-palette:closed`
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
    this.inputTarget.value = ""
    this.dialogTarget.showModal()
    this.#go([])
    this.filter()
  }

  close() {
    this.pendingRun = null
    this.dialogTarget.close()
  }

  closed() {
    this.dispatch("closed")
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

    const pending = this.pendingRun
    this.pendingRun = null
    if (pending && this.selected) this.#run(this.selected, pending.newWindow)
  }

  filter() {
    const query = this.inputTarget.value
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
      if (this.navigating) this.pendingRun = { newWindow }
      else if (this.selected) this.#run(this.selected, newWindow)
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

    const { children: src, source } = item.dataset
    if (src || source) {
      return this.#go([...this.stack, { label: item.querySelector(".palette__label").firstChild.textContent.trim(), src, source }])
    }
    this.close()
    this.dispatch("run", { detail: this.#detail(item, { newWindow }) })
  }

  // Shows the list at the end of `stack` (the root list when empty).
  #go(stack) {
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
  // exists in the browser: `desk-palette:source` asks, the listener fills
  // `detail.items` with { label, group, action, param }.
  #showSourceList(source) {
    const { detail } = this.dispatch("source", { detail: { source, items: [] } })
    const list = document.createElement("ul")
    list.className = "palette__list"
    list.setAttribute("role", "listbox")
    list.dataset.deskPaletteTarget = "list"
    list.append(...detail.items.map((attributes) => this.#buildItem(attributes)))

    this.navigating = false
    this.frameTarget.removeAttribute("src")
    this.frameTarget.replaceChildren(list)
    this.filter()
    this.inputTarget.focus()
  }

  #buildItem({ label, group, action, param }) {
    const item = this.itemTemplateTarget.content.firstElementChild.cloneNode(true)
    Object.assign(item.dataset, { deskAction: action, param: param ?? "", search: `${label} ${group}` })
    item.querySelector(".palette__label").textContent = label
    item.querySelector(".palette__group").textContent = group
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
    if (item && this.dialogTarget.open) this.dispatch("preview", { detail: this.#detail(item) })
  }

  #detail(item, extra = {}) {
    const { url, deskAction: action, param } = item.dataset
    return { url, action, param, ...extra }
  }

  #id(item) {
    const { url, deskAction, param, children, source } = item.dataset
    return url || children || source || [deskAction, param].filter((part) => part !== undefined).join(":")
  }

  #usage() {
    try {
      return JSON.parse(localStorage.getItem(USAGE_KEY)) || {}
    } catch {
      return {}
    }
  }
}
