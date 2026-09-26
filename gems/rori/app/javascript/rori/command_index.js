import { score } from "rori/fuzzy"

const MAX_DEPTH = 4
// Each level deeper costs this much, so "theme" still prefers "Pick theme…"
// over "UI › Theme", while "uthen" (only a deep path fits) still finds Nord.
const DEPTH_PENALTY = 1.5

// A command list as the palette renders it (rori/commands/index), as data.
export function parseList(html) {
  const page = new DOMParser().parseFromString(html, "text/html")
  return [...page.querySelectorAll(".rori-palette__item")].map((item) => ({
    label: item.querySelector(".rori-palette__label").firstChild.textContent.trim(),
    group: item.querySelector(".rori-palette__group").lastChild.textContent.trim(),
    url: item.dataset.url,
    action: item.dataset.deskAction,
    param: item.dataset.param,
    children: item.dataset.children,
    source: item.dataset.source,
    shortcut: item.dataset.shortcut,
    current: "current" in item.dataset,
  }))
}

export const isNested = (item) => Boolean(item.children || item.source)

// What running an entry does; entries reachable by two paths share it.
const target = (item) => item.url || item.children || item.source || `${item.action}:${item.param ?? ""}`

// Every command reachable from the root list, flattened with its trail
// ("UI › Theme › Nord"), so a query matches whole paths instead of one level
// at a time. Server lists are fetched once per index; `source` answers
// browser-only lists (workspaces) the way the command bus does.
export class CommandIndex {
  constructor(root, { source }) {
    this.root = root
    this.source = source
    this.lists = new Map()
  }

  list({ children, source }) {
    if (source) return Promise.resolve(this.source(source))
    if (!this.lists.has(children)) {
      this.lists.set(children, fetch(children, { headers: { Accept: "text/html", "Turbo-Frame": "commands" } })
        .then((response) => response.text())
        .then(parseList))
    }
    return this.lists.get(children)
  }

  entries() {
    this.crawl ||= this.#crawl({ children: this.root }, [], new Set([this.root]))
    return this.crawl
  }

  // Best entries for `query`, one per target, best first. `bonus(item)` adds
  // to an entry's score (the palette's frecency).
  async search(query, { limit = 20, bonus = () => 0 } = {}) {
    const ranked = (await this.entries())
      .map((entry, index) => {
        const match = score(entry.text, query)
        return { ...entry, index, score: match && match - (entry.trail.length - 1) * DEPTH_PENALTY + bonus(entry.item) }
      })
      .filter(({ score }) => score > 0)
      .sort((a, b) => b.score - a.score || a.index - b.index)

    const seen = new Set()
    return ranked.filter(({ item }) => !seen.has(target(item)) && seen.add(target(item))).slice(0, limit)
  }

  async #crawl(node, trail, visited) {
    const items = await this.list(node)
    const branches = await Promise.all(items.map(async (item) => {
      const path = [...trail, item]
      const entry = { item, trail: path, text: path.map(({ label }) => label).join(" › ") }
      const key = item.children || item.source
      if (!key || path.length >= MAX_DEPTH || visited.has(key)) return [entry]
      return [entry, ...(await this.#crawl(item, path, new Set([...visited, key])))]
    }))
    return branches.flat()
  }
}
