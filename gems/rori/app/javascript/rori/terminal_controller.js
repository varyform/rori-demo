import { Controller } from "@hotwired/stimulus"
import { CommandIndex, isNested } from "rori/command_index"

const BUS = "rori-command"
const HISTORY_KEY = "rori:terminal:history"
const HISTORY_LIMIT = 100
const SUGGESTIONS = 8
const FIELDS = "input, textarea, select, [contenteditable]"

const format = (template, values) => template.replace(/%\{(\w+)\}/g, (_, key) => values[key] ?? "")
// "Pick theme…" → "pick-theme": one word per label, so a trail reads as words.
const token = (label) => label.toLowerCase().replace(/[…›✓]/g, "").trim().replace(/\s+/g, "-")
const words = (trail) => trail.map(({ label }) => token(label)).join(" ")

// A drop-down command line over the same command tree as ⌘K: the same
// server-rendered lists, client-side sources, fuzzy matcher and command bus.
// Input matches whole paths through the tree, so `ui wallpaper cover` and
// just `uthen` (UI › Theme › Nord) both work; a path ending on a nested item
// lists it. Opens with Rori.terminal_key outside text fields.
export default class extends Controller {
  static targets = ["panel", "output", "input", "suggestions"]
  static values = { root: String, key: String, prompt: String, messages: Object }

  connect() {
    this.history = this.#loadHistory()
    this.cursor = this.history.length
  }

  keydown(event) {
    if (event.code !== this.keyValue || event.metaKey || event.ctrlKey || event.altKey) return
    const inTerminal = this.panelTarget.contains(event.target)
    // A field in a closed dialog (see rori_controller.js `typing`) isn't being typed in.
    if (!inTerminal && event.target.closest?.(FIELDS) && !event.target.closest("dialog:not([open])")) return
    if (document.querySelector("dialog:modal")) return
    event.preventDefault()
    this.toggle()
  }

  toggle() {
    this.panelTarget.hidden ? this.open() : this.close()
  }

  open() {
    this.returnFocus = document.activeElement
    this.#reindex()
    this.panelTarget.hidden = false
    if (!this.outputTarget.childElementCount) this.#print(this.messagesValue.welcome, "muted")
    this.inputTarget.focus()
    this.suggest()
  }

  close() {
    this.panelTarget.hidden = true
    this.suggestionsTarget.replaceChildren()
    if (this.returnFocus?.isConnected) this.returnFocus.focus({ preventScroll: true })
  }

  navigate(event) {
    if (event.key === "Escape") {
      event.preventDefault()
      this.close()
    } else if (event.key === "Enter") {
      event.preventDefault()
      this.#submit()
    } else if (event.key === "Tab") {
      event.preventDefault()
      this.#complete()
    } else if (event.key === "ArrowUp" || event.key === "ArrowDown") {
      event.preventDefault()
      this.#recall(event.key === "ArrowUp" ? -1 : 1)
    }
  }

  async suggest() {
    const query = this.inputTarget.value.trim()
    const ticket = (this.ticket = (this.ticket || 0) + 1)
    const suggested = query
      ? await this.index.search(query, { limit: SUGGESTIONS })
      : (await this.index.list({ children: this.rootValue })).map((item) => ({ item, trail: [item] }))
    if (ticket !== this.ticket) return

    this.suggested = suggested
    this.suggestionsTarget.replaceChildren(...suggested.slice(0, SUGGESTIONS).map(({ item, trail }, i) => {
      const li = document.createElement("li")
      li.className = "rori-terminal__suggestion"
      li.toggleAttribute("aria-selected", i === 0)
      const label = document.createElement("span")
      label.textContent = words(trail) + (isNested(item) ? " ›" : "")
      const group = document.createElement("span")
      group.className = "rori-terminal__group"
      group.textContent = (item.current ? "✓ " : "") + item.group
      li.append(label, group)
      return li
    }))
  }

  // Tab: spell out the best match's whole path.
  #complete() {
    const best = this.suggested?.[0]
    if (!best) return
    this.inputTarget.value = words(best.trail) + (isNested(best.item) ? " " : "")
    this.suggest()
  }

  async #submit() {
    const line = this.inputTarget.value.trim()
    this.inputTarget.value = ""
    this.#print(`${this.promptValue} ${line}`, "echo")
    if (!line) return this.suggest()
    this.#remember(line)

    if (line === "clear") {
      this.outputTarget.replaceChildren()
    } else if (line === "help") {
      this.#printList(this.messagesValue.help, await this.index.list({ children: this.rootValue }))
    } else {
      await this.#run(line)
    }
    this.suggest()
  }

  async #run(query) {
    const [best] = await this.index.search(query, { limit: 1 })
    if (!best) return this.#print(format(this.messagesValue.no_match, { query }), "error")

    const { item, trail } = best
    const path = trail.map(({ label }) => label).join(" › ")
    if (isNested(item)) return this.#printList(format(this.messagesValue.list, { path }), await this.index.list(item))

    this.dispatch("run", { prefix: BUS, detail: { url: item.url, action: item.action, param: item.param, newWindow: false } })
    this.#print(format(item.url ? this.messagesValue.opened : this.messagesValue.ran, { path }), "ok")
    this.#reindex() // runs change state: the current theme, workspaces, records
  }

  #reindex() {
    this.index = new CommandIndex(this.rootValue, {
      source: (source) => this.dispatch("source", { prefix: BUS, detail: { source, items: [] } }).detail.items,
    })
  }

  #print(text, kind) {
    const line = document.createElement("div")
    line.className = `rori-terminal__entry rori-terminal__entry--${kind}`
    line.textContent = text
    this.outputTarget.append(line)
    this.outputTarget.scrollTop = this.outputTarget.scrollHeight
  }

  #printList(heading, items) {
    this.#print(heading, "muted")
    if (!items.length) return this.#print(this.messagesValue.empty, "muted")
    for (const item of items) {
      const nested = isNested(item) ? " ›" : ""
      this.#print(`  ${token(item.label)}${nested}  ${item.current ? "✓ " : ""}${item.group}`, "item")
    }
  }

  #recall(step) {
    if (!this.history.length) return
    this.cursor = Math.max(0, Math.min(this.history.length, this.cursor + step))
    this.inputTarget.value = this.history[this.cursor] ?? ""
    this.suggest()
  }

  #remember(line) {
    this.history = [...this.history.filter((entry) => entry !== line), line].slice(-HISTORY_LIMIT)
    this.cursor = this.history.length
    localStorage.setItem(HISTORY_KEY, JSON.stringify(this.history))
  }

  #loadHistory() {
    try {
      return JSON.parse(localStorage.getItem(HISTORY_KEY)) || []
    } catch {
      return []
    }
  }
}
