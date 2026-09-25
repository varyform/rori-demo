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

// ⌘K command palette. Commands are server-rendered into a lazy turbo-frame
// (reloaded on every open so new records show up) and ranked client-side,
// with a bonus for commands you run often. Runs are handed to the desk via a
// `palette:run` event.
export default class extends Controller {
  static targets = ["dialog", "input", "frame", "list", "item", "empty"]

  keydown(event) {
    if (!(event.metaKey || event.ctrlKey) || event.key.toLowerCase() !== "k") return
    event.preventDefault()
    this.dialogTarget.open ? this.close() : this.open()
  }

  open() {
    this.inputTarget.value = ""
    this.dialogTarget.showModal()
    this.inputTarget.focus()
    if (this.frameTarget.hasAttribute("complete")) this.frameTarget.reload()
    this.filter()
  }

  close() {
    this.dialogTarget.close()
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

    if (this.hasListTarget) this.listTarget.append(...visible.map(({ item }) => item))
    this.emptyTarget.hidden = visible.length > 0 || !this.frameTarget.hasAttribute("complete")
    this.#select(visible[0]?.item)
  }

  navigate(event) {
    const items = this.itemTargets.filter((item) => !item.hidden)
    const index = items.indexOf(this.selected)

    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault()
      const next = event.key === "ArrowDown" ? index + 1 : index - 1
      this.#select(items[(next + items.length) % items.length])
    } else if (event.key === "Enter" && this.selected) {
      event.preventDefault()
      this.#run(this.selected, event.shiftKey || event.metaKey || event.ctrlKey)
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

    this.close()
    this.dispatch("run", { detail: { url: item.dataset.url, action: item.dataset.deskAction, newWindow } })
  }

  #select(item) {
    this.itemTargets.forEach((other) => other.setAttribute("aria-selected", other === item))
    this.selected = item
    item?.scrollIntoView({ block: "nearest" })
  }

  #id(item) {
    return item.dataset.url || item.dataset.deskAction
  }

  #usage() {
    try {
      return JSON.parse(localStorage.getItem(USAGE_KEY)) || {}
    } catch {
      return {}
    }
  }
}
