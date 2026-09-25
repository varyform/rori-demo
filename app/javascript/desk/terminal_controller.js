import { Controller } from "@hotwired/stimulus"
import { score } from "desk/fuzzy"

const BUS = "desk-command"
const HISTORY_KEY = "desk:terminal:history"
const HISTORY_LIMIT = 100
const SUGGESTIONS = 8
const FIELDS = "input, textarea, select, [contenteditable]"

const format = (template, values) => template.replace(/%\{(\w+)\}/g, (_, key) => values[key] ?? "")
// "Pick theme…" → "pick-theme": one word per label, so completions stay single tokens.
const token = (label) => label.toLowerCase().replace(/[…›✓]/g, "").trim().replace(/\s+/g, "-")

// A drop-down command line over the same command tree as ⌘K: the same
// server-rendered lists (fetched and parsed), the same client-side sources,
// the same fuzzy matcher. Words walk the nesting — `ui wallpaper cover` is
// UI › Wallpaper › Cover bars — and runs go out on desk-command:run like
// the palette's. Opens with Desk.terminal_key outside text fields.
export default class extends Controller {
  static targets = ["panel", "output", "input", "suggestions"]
  static values = { root: String, key: String, prompt: String, messages: Object }

  connect() {
    this.lists = new Map()
    this.history = this.#loadHistory()
    this.cursor = this.history.length
  }

  keydown(event) {
    if (event.code !== this.keyValue || event.metaKey || event.ctrlKey || event.altKey) return
    const inTerminal = this.panelTarget.contains(event.target)
    if (!inTerminal && event.target.closest?.(FIELDS)) return
    if (document.querySelector("dialog:modal")) return
    event.preventDefault()
    this.toggle()
  }

  toggle() {
    this.panelTarget.hidden ? this.open() : this.close()
  }

  open() {
    this.returnFocus = document.activeElement
    this.lists.clear()
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

  // Candidates for the word being typed, at the level the earlier words reached.
  async suggest() {
    const { words, partial } = this.#split(this.inputTarget.value)
    const ticket = (this.ticket = (this.ticket || 0) + 1)
    const { list, error } = await this.#resolve(words)
    if (ticket !== this.ticket) return

    this.suggested = error || !list ? [] : partial ? this.#rank(list, partial) : list
    this.suggestionsTarget.replaceChildren(...this.suggested.slice(0, SUGGESTIONS).map((item, i) => {
      const li = document.createElement("li")
      li.className = "terminal__suggestion"
      li.toggleAttribute("aria-selected", i === 0)
      const label = document.createElement("span")
      label.textContent = token(item.label) + (item.children || item.source ? " ›" : "")
      const group = document.createElement("span")
      group.className = "terminal__group"
      group.textContent = (item.current ? "✓ " : "") + item.group
      li.append(label, group)
      return li
    }))
  }

  // Tab: replace the word being typed with the best candidate.
  #complete() {
    const best = this.suggested?.[0]
    if (!best) return
    const { words } = this.#split(this.inputTarget.value)
    const nested = best.children || best.source
    this.inputTarget.value = [...words, token(best.label)].join(" ") + (nested ? " " : "")
    this.suggest()
  }

  async #submit() {
    const line = this.inputTarget.value.trim()
    this.inputTarget.value = ""
    this.#print(`${this.promptValue} ${line}`, "echo")
    if (!line) return this.suggest()
    this.#remember(line)

    const words = line.split(/\s+/)
    if (words[0] === "clear") {
      this.outputTarget.replaceChildren()
      return this.suggest()
    }
    if (words[0] === "help") {
      this.#printList(this.messagesValue.help, await this.#list({ children: this.rootValue }))
      return this.suggest()
    }

    const { path, list, error } = await this.#resolve(words)
    if (error) {
      this.#print(format(this.messagesValue.no_match, error), "error")
    } else {
      const item = path.at(-1)
      const trail = path.map(({ label }) => label).join(" › ")
      if (list) {
        this.#printList(format(this.messagesValue.list, { path: trail }), list)
      } else {
        this.dispatch("run", { prefix: BUS, detail: { url: item.url, action: item.action, param: item.param, newWindow: false } })
        this.#print(format(item.url ? this.messagesValue.opened : this.messagesValue.ran, { path: trail }), "ok")
        this.lists.clear() // runs change state (current theme, workspaces, records)
      }
    }
    this.suggest()
  }

  // Walks the words through nested lists. Labels contain spaces ("New user"),
  // so each step takes the most words that still match something at that
  // level. Returns the path and, when it ends on a nested item, that item's list.
  async #resolve(words) {
    let list = await this.#list({ children: this.rootValue })
    const path = []
    let rest = words
    while (rest.length) {
      const step = this.#step(list, rest)
      const level = path.at(-1)?.label || this.messagesValue.root
      if (!step) return { path, error: { word: rest[0], list: level } }

      path.push(step.item)
      rest = rest.slice(step.used)
      const nested = step.item.children || step.item.source
      if (!nested) return rest.length ? { path, error: { word: rest[0], list: step.item.label } } : { path, list: null }
      list = await this.#list(step.item)
    }
    return { path, list }
  }

  #step(list, words) {
    for (let used = words.length; used > 0; used--) {
      const best = this.#rank(list, words.slice(0, used).join(" "))[0]
      if (best) return { item: best, used }
    }
    return null
  }

  #rank(list, query) {
    return list
      .map((item, index) => ({ item, index, score: score(item.label, query) }))
      .filter(({ score }) => score > 0)
      .sort((a, b) => b.score - a.score || a.index - b.index)
      .map(({ item }) => item)
  }

  // Server lists are the palette's own HTML (desk/commands/index), parsed once
  // per open; client sources are asked on the command bus, like the palette does.
  async #list({ children, source }) {
    if (source) {
      const { detail } = this.dispatch("source", { prefix: BUS, detail: { source, items: [] } })
      return detail.items
    }
    if (!this.lists.has(children)) this.lists.set(children, this.#fetchList(children))
    return this.lists.get(children)
  }

  async #fetchList(url) {
    const response = await fetch(url, { headers: { Accept: "text/html", "Turbo-Frame": "commands" } })
    const html = new DOMParser().parseFromString(await response.text(), "text/html")
    return [...html.querySelectorAll(".palette__item")].map((item) => ({
      label: item.querySelector(".palette__label").firstChild.textContent.trim(),
      group: item.querySelector(".palette__group").lastChild.textContent.trim(),
      url: item.dataset.url,
      action: item.dataset.deskAction,
      param: item.dataset.param,
      children: item.dataset.children,
      source: item.dataset.source,
      current: "current" in item.dataset,
    }))
  }

  #split(value) {
    const words = value.trimStart().split(/\s+/)
    const partial = words.pop() ?? ""
    return { words: words.filter(Boolean), partial }
  }

  #print(text, kind) {
    const line = document.createElement("div")
    line.className = `terminal__entry terminal__entry--${kind}`
    line.textContent = text
    this.outputTarget.append(line)
    this.outputTarget.scrollTop = this.outputTarget.scrollHeight
  }

  #printList(heading, items) {
    this.#print(heading, "muted")
    if (!items.length) return this.#print(this.messagesValue.empty, "muted")
    for (const item of items) {
      const nested = item.children || item.source ? " ›" : ""
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
