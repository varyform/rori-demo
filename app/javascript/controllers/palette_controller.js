import { Controller } from "@hotwired/stimulus"

const USAGE_KEY = "palette:usage"

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

// ⌘K command palette. Command lists are server-rendered into a lazy
// turbo-frame (reloaded on every open so new records show up) and ranked
// client-side, with a bonus for commands you run often.
//
// Commands with `data-children` are nested lists: picking one swaps the frame
// to that URL and pushes a breadcrumb; Backspace on an empty query or Esc goes
// back up. Runs are handed out as `palette:run`, the selection as
// `palette:preview` (e.g. live theme preview), and `palette:closed` on close.
export default class extends Controller {
  static targets = ["dialog", "input", "frame", "list", "item", "empty", "crumbs"]

  connect() {
    this.root = this.frameTarget.getAttribute("src")
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
    this.inputTarget.focus()
    if (this.stack.length) this.#go([])
    else if (this.frameTarget.hasAttribute("complete")) this.frameTarget.reload()
    this.filter()
  }

  close() {
    this.dialogTarget.close()
  }

  closed() {
    this.dispatch("closed")
  }

  backdrop(event) {
    if (event.target === this.dialogTarget) this.close()
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
    this.emptyTarget.hidden = visible.length > 0 || !this.frameTarget.hasAttribute("complete")

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
    } else if (event.key === "Enter" && this.selected && !this.frameTarget.hasAttribute("busy")) {
      event.preventDefault()
      this.#run(this.selected, event.shiftKey || event.metaKey || event.ctrlKey)
    } else if (this.stack.length && (event.key === "Escape" || (event.key === "Backspace" && !this.inputTarget.value))) {
      event.preventDefault()
      this.#go(this.stack.slice(0, -1))
    }
  }

  pick(event) {
    this.#run(event.currentTarget, event.shiftKey || event.metaKey || event.ctrlKey)
  }

  hover(event) {
    if (this.selected !== event.currentTarget) this.#select(event.currentTarget)
  }

  #run(item, newWindow) {
    const usage = this.#usage()
    const id = this.#id(item)
    usage[id] = (usage[id] || 0) + 1
    localStorage.setItem(USAGE_KEY, JSON.stringify(usage))

    if (item.dataset.children) {
      return this.#go([...this.stack, { label: item.querySelector(".palette__label").firstChild.textContent.trim(), src: item.dataset.children }])
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
    this.frameTarget.setAttribute("src", stack.at(-1)?.src || this.root)
    this.inputTarget.focus()
  }

  #select(item) {
    this.itemTargets.forEach((other) => other.setAttribute("aria-selected", other === item))
    this.selected = item
    item?.scrollIntoView({ block: "nearest" })
    if (item) this.dispatch("preview", { detail: this.#detail(item) })
  }

  #detail(item, extra = {}) {
    const { url, deskAction: action, param } = item.dataset
    return { url, action, param, ...extra }
  }

  #id(item) {
    const { url, deskAction, param, children } = item.dataset
    return url || children || [deskAction, param].filter((part) => part !== undefined).join(":")
  }

  #usage() {
    try {
      return JSON.parse(localStorage.getItem(USAGE_KEY)) || {}
    } catch {
      return {}
    }
  }
}
