import { Controller } from "@hotwired/stimulus"

const GAP = 12
const STORAGE_KEY = "rori"
const WIDTHS = [1 / 3, 1 / 2, 2 / 3]
const SIZES = { sm: 1 / 3, md: 1 / 2, lg: 2 / 3, xl: 1 }
const MODAL_WIDTHS = { sm: 440, md: 640, lg: 900, xl: 1200 }
const MODIFIERS = ["Control", "Alt", "Meta", "Shift"]
const FIELDS = "input, textarea, select, [contenteditable]"
// Chrome can leave focus on a field inside a dialog that just closed (the
// palette); nobody is typing there, so it mustn't swallow desk keys.
const typing = (target) => Boolean(target.closest?.(FIELDS) && !target.closest("dialog:not([open])"))
const CLOSED_LIMIT = 20
// A resting pointer that jitters less than this doesn't re-arm hover keys.
const HOVER_JITTER = 4

const clamp = (n, min, max) => Math.max(min, Math.min(n, max))

// Scrollable tiling (niri/PaperWM): each workspace is an endless horizontal strip
// of columns, each column stacks one or more windows, workspaces stack vertically.
//
// Every window is a <dialog> around a <turbo-frame refresh="morph">, so links and
// forms inside it navigate just that window. Pages describe how they want to be
// shown with a <template data-window-meta> (Rori::WindowHelper#window), re-read on every
// frame load. New windows load hidden in `floating` and are placed once their page
// says where they belong; modals stay there, shown with showModal().
export default class extends Controller {
  static targets = ["viewport", "stack", "floating", "window", "template", "workspaces", "minimap"]
  static values = {
    rootUrl: String, loadError: String, workspaceGroup: String, newWorkspaceLabel: String, discardPrompt: String,
    keymap: Object, hoverKeymap: Object, hoverTimeout: { type: Number, default: 1500 }, native: Boolean,
  }

  initialize() {
    this.offsets = new WeakMap()      // workspace → strip scroll offset
    this.spans = new WeakMap()        // workspace → { spans, total } from the last layout
    this.lastFocus = new WeakMap()    // workspace → window
    this.lastInColumn = new WeakMap() // column → window
    this.histories = new WeakMap()    // window → back stack
    this.pendingReloads = new Set()
    this.closed = []                  // recently closed windows, for reopen_window
    this.overview = false
  }

  connect() {
    this.element.classList.add("is-booting")
    this.#restore()
    requestAnimationFrame(() => requestAnimationFrame(() => this.element.classList.remove("is-booting")))
  }

  // Chord ("Alt+Shift+Digit2") → { action, digit } from Rori.keymap (see app/models/desk.rb).
  keymapValueChanged(keymap) {
    this.bindings = this.#bindingsFrom(keymap)
  }

  // Rori.hover_keymap: bare keys for the window under the pointer (empty when off).
  hoverKeymapValueChanged(keymap) {
    this.hoverBindings = this.#bindingsFrom(keymap)
  }

  // Entry points ---------------------------------------------------------------

  command({ detail: { url, action, param, newWindow } }) {
    if (url) return this.#spawn(url, { reuse: !newWindow })
    this.#perform(action, { workspace: param })
  }

  // Client-side command lists (Rori::Command `source:`), for ⌘K and the terminal:
  // workspaces only exist in the browser.
  commandSource({ detail }) {
    if (detail.source !== "workspaces" || !this.#focusIn(this.current)) return

    const item = (label, param) => ({ label, group: this.workspaceGroupValue, action: "move_to_workspace", param })
    detail.items = [
      ...this.#workspaces().filter((ws) => ws !== this.current).map((ws) => item(this.#workspaceLabel(ws), ws.dataset.name)),
      item(this.newWorkspaceLabelValue, ""),
    ]
  }

  // rori_link_to (data-turbo-frame="_top") and any other top-level visit open a window instead.
  interceptVisit(event) {
    event.preventDefault()
    this.#spawn(event.detail.url, { reuse: true })
  }

  // Remember which windows a refresh came from; their stream sources live inside them.
  streamMessage(event) {
    if (!event.target.matches?.("turbo-cable-stream-source")) return
    if (typeof event.data === "string" && event.data.includes('action="refresh"')) {
      const win = event.target.closest(".rori-win")
      if (win) this.pendingReloads.add(win)
    }
  }

  // A page refresh would morph the whole body and drop client-opened windows,
  // so refreshes reload (and morph) only the affected window frames.
  streamRender(event) {
    if (event.target.getAttribute?.("action") !== "refresh") return
    event.detail.render = () => this.#reloadSoon()
  }

  keydown(event) {
    // Surfaces that own the keyboard (the terminal) opt out of every desk key.
    if (event.target.closest?.("[data-rori-keys=off]")) return
    if (this.#emptyDeskKey(event)) return
    if (this.#bareKey(event)) return
    if (event.key === "Escape") return this.#escape(event)

    const binding = this.bindings.get(this.#chord(event))
    // Chords edit text inside fields (⌥← jumps a word, ⌘← to line start): leave them be.
    if (!binding || typing(event.target)) return

    event.preventDefault()
    this.#perform(binding.action, { workspace: this.#workspaceAt(binding.digit) })
    if (this.focused && !this.focused.contains(document.activeElement)) this.focused.focus({ preventScroll: true })
  }

  // Blender-style: after the pointer deliberately moves onto an inactive window,
  // bare hover keys act on that window (even while a field elsewhere has focus)
  // until the pointer rests for hoverTimeout, leaves, or you type anything else.
  hover(event) {
    if (!this.hoverBindings?.size || this.overview || !["mouse", "pen"].includes(event.pointerType)) return
    this.pointer = [event.clientX, event.clientY]
    const win = event.target.closest(".rori-col > .rori-win")
    if (!win || win === this.focused) return this.#disarm()
    if (win !== this.armed && this.restingAt &&
      Math.hypot(event.clientX - this.restingAt[0], event.clientY - this.restingAt[1]) < HOVER_JITTER) return
    this.#arm(win)
  }

  unhover() {
    this.#disarm()
  }

  // Esc closes the overview, or hands focus from a field back to its window so
  // the keymap applies again. In modals Esc keeps closing the modal.
  #escape(event) {
    if (this.overview) {
      event.preventDefault()
      return this.toggleOverview()
    }
    const win = event.target.closest?.(".rori-win")
    if (win && !win.matches(":modal") && typing(event.target)) {
      event.preventDefault()
      return win.focus({ preventScroll: true })
    }
    // Native shell: WebKit hands an Esc the page didn't claim to the window, and
    // a macOS full-screen window leaves full screen — even when the Esc also
    // closed a modal (its default action). So claim every Esc and close the
    // topmost modal ourselves, the way the browser would.
    if (this.nativeValue && !event.defaultPrevented) {
      event.preventDefault()
      this.#cancelTopModal()
    }
  }

  // What Esc does to a modal <dialog>: a cancelable `cancel`, then close unless
  // a listener objected (modal windows handle cancel themselves, see #cancel).
  #cancelTopModal() {
    const modal = [...document.querySelectorAll("dialog:modal")].at(-1)
    if (modal?.dispatchEvent(new Event("cancel", { cancelable: true }))) modal.close()
  }

  // Bare keys (Rori.hover_keymap) act on the armed hovered window — even while a
  // field elsewhere has focus — or, when no field has focus, on the focused
  // window (vim-style normal mode). Held-down repeats never count.
  #bareKey(event) {
    if (!this.hoverBindings?.size || MODIFIERS.includes(event.key)) return false

    const armed = this.armed?.isConnected ? this.armed : null
    const binding = this.hoverBindings.get(this.#chord(event))
    const blocked = event.repeat || event.isComposing || this.overview || document.querySelector("dialog:modal")
    if (!binding || blocked) {
      if (this.armed) this.#disarm()
      return false
    }
    if (!armed && typing(event.target)) return false

    event.preventDefault()
    this.#perform(binding.action, { win: armed || undefined, workspace: this.#workspaceAt(binding.digit) })

    if (armed) armed.isConnected && armed.closest(".rori-workspace") === this.current ? this.#arm(armed) : this.#disarm()
    else if (this.focused && !this.focused.contains(document.activeElement)) this.focused.focus({ preventScroll: true })
    return true
  }

  // On an empty workspace there's nothing for keys to act on, so Space or Enter
  // opens ⌘K — the one useful next step. Buttons and links keep their own.
  #emptyDeskKey(event) {
    if (!["Space", "Enter", "NumpadEnter"].includes(event.code) || event.repeat || event.defaultPrevented) return false
    if (event.metaKey || event.ctrlKey || event.altKey || event.shiftKey) return false
    if (this.current?.querySelector(".rori-win") || this.overview || document.querySelector("dialog:modal")) return false
    if (typing(event.target) || event.target.closest?.("button, a, summary")) return false

    event.preventDefault()
    this.dispatch("open-palette")
    return true
  }

  #arm(win) {
    if (win !== this.armed) {
      this.armed?.classList.remove("is-armed")
      win.classList.add("is-armed")
      this.armed = win
    }
    this.restingAt = null
    clearTimeout(this.armTimer)
    this.armTimer = setTimeout(() => this.#disarm(), this.hoverTimeoutValue)
  }

  // Re-arming needs fresh movement from where the pointer is now.
  #disarm() {
    clearTimeout(this.armTimer)
    this.armed?.classList.remove("is-armed")
    this.armed = null
    this.restingAt = this.pointer
  }

  // Every desk action, whether from a key or a ⌘K command. `win` defaults to the
  // focused window; `workspace` is a workspace name, "" meaning a new one.
  #perform(action, { win, workspace } = {}) {
    const target = () => (workspace ? this.#workspace(workspace) : null)
    const actions = {
      focus_left: () => this.#focusDirection("left"),
      focus_right: () => this.#focusDirection("right"),
      focus_up: () => this.#focusDirection("up"),
      focus_down: () => this.#focusDirection("down"),
      move_left: () => this.#move("left", win),
      move_right: () => this.#move("right", win),
      move_up: () => this.#move("up", win),
      move_down: () => this.#move("down", win),
      switch_to_workspace: () => this.#switchTo(target() || this.#newWorkspace()),
      move_to_workspace: () => this.#moveToWorkspace(target(), win),
      new_workspace: () => this.#switchTo(this.#newWorkspace()),
      consume_left: () => this.#consumeOrExpel(-1, win),
      consume_right: () => this.#consumeOrExpel(1, win),
      cycle_width: () => this.#cycleWidth(win),
      full_width: () => this.#toggleFullWidth(win),
      center_column: () => this.#center(win),
      overview: () => this.toggleOverview(),
      close_window: () => this.#remove(win || this.focused),
      reopen_window: () => this.#reopen(),
      toggle_terminal: () => this.dispatch("toggle-terminal"),
    }
    actions[action]?.()
  }

  #bindingsFrom(keymap) {
    const bindings = new Map()
    for (const [action, chords] of Object.entries(keymap)) {
      for (const chord of chords) {
        const digits = chord.endsWith("Digit*") ? [1, 2, 3, 4, 5, 6, 7, 8, 9] : [null]
        for (const digit of digits) {
          const spelled = digit ? chord.replace(/\*$/, digit) : chord
          bindings.set(this.#normalize(spelled.split("+")), { action, digit })
        }
      }
    }
    return bindings
  }

  #chord(event) {
    return this.#normalize([...MODIFIERS.filter((key) => event.getModifierState(key)), event.code])
  }

  #normalize(keys) {
    const code = keys.at(-1)
    return [...MODIFIERS.filter((key) => keys.includes(key)), code].join("+")
  }

  // Digit bindings address the nth workspace; past the last one means a new one ("").
  #workspaceAt(digit) {
    return digit ? (this.#workspaces()[digit - 1]?.dataset.name ?? "") : undefined
  }

  // Horizontal wheel / trackpad swipes scroll the strip; focus follows once it settles.
  wheel(event) {
    if (this.overview || event.ctrlKey) return
    const horizontal = Math.abs(event.deltaX) > Math.abs(event.deltaY)
    const delta = horizontal ? event.deltaX : event.shiftKey ? event.deltaY : 0
    if (!delta || (horizontal && this.#scrollsSideways(event.target))) return
    event.preventDefault()

    const ws = this.current
    this.offsets.set(ws, (this.offsets.get(ws) || 0) + delta)
    this.element.classList.add("is-scrolling")
    this.#layoutStrip(ws, { reveal: false })
    this.#renderMinimap()

    clearTimeout(this.wheelTimer)
    this.wheelTimer = setTimeout(() => {
      this.element.classList.remove("is-scrolling")
      const win = this.#mostVisible(ws)
      if (win && win !== this.focused) this.focus(win)
    }, 160)
  }

  toggleOverview() {
    this.overview = !this.overview
    this.layout()
  }

  save() {
    const workspaces = this.#workspaces().map((ws) => {
      const columns = this.#columns(ws)
      const focused = this.#focusIn(ws)
      const column = focused ? columns.indexOf(focused.closest(".rori-col")) : -1
      return {
        name: ws.dataset.name,
        focus: focused ? [column, this.#windowsIn(columns[column]).indexOf(focused)] : null,
        columns: columns.map((col) => ({
          w: Number(col.dataset.w),
          windows: this.#windowsIn(col).map((win) => ({ url: this.#src(win), mode: win.dataset.mode, size: win.dataset.size })),
        })),
      }
    })
    sessionStorage.setItem(STORAGE_KEY, JSON.stringify({ current: this.current?.dataset.name, workspaces }))
  }

  // Window actions -------------------------------------------------------------

  focus(win) {
    if (win && win === this.armed) this.#disarm()
    if (win) {
      const ws = this.#wsOf(win)
      if (ws) {
        this.current = ws
        this.lastFocus.set(ws, win)
        this.lastInColumn.set(win.closest(".rori-col"), win)
      }
      if (this.#title(win).textContent) document.title = this.#title(win).textContent
    }
    this.focused = win || null
    this.windowTargets.forEach((other) => other.classList.toggle("is-focused", other === win))
    this.#syncUrl(win)
    this.#prune()
    this.layout()
  }

  // Pointer or keyboard (Tab / focusin) entering a window makes it the focused one.
  focusWindow(event) {
    const win = this.#win(event)
    // Focus on the <dialog> itself is programmatic: dialog.show() moves focus to
    // the window it opens (e.g. every window a reload restores, sometimes after
    // the restore has finished). Only focus inside the content is the user's.
    if (event.type === "focusin" && event.target === win) return
    if (this.overview) {
      if (event.type !== "pointerdown") return
      event.preventDefault()
      this.overview = false
      return this.focus(win)
    }
    if (win === this.focused) return

    // Revealing the column now would slide it under the pointer mid-click and
    // the click would land elsewhere; scroll once the button is released.
    if (event.type === "pointerdown") this.#holdRevealUntilPointerUp()
    this.focus(win)
  }

  // Edited forms are skipped by broadcast reloads (see #busy).
  markDirty(event) {
    event.target.form?.toggleAttribute("data-rori-dirty", true)
  }

  layout() {
    const H = this.viewportTarget.clientHeight
    const workspaces = this.#workspaces()
    workspaces.forEach((ws) => this.#layoutStrip(ws))

    if (this.overview) {
      const V = this.viewportTarget.clientWidth
      const widest = Math.max(V, ...workspaces.map((ws) => this.spans.get(ws).total))
      const scale = Math.min(0.5, (V * 0.92) / widest, 0.92 / workspaces.length)
      const x = (V - widest * scale) / 2
      const y = (H - H * workspaces.length * scale) / 2
      this.stackTarget.style.transform = `translate(${x}px, ${y}px) scale(${scale})`
    } else {
      this.stackTarget.style.transform = `translateY(${-workspaces.indexOf(this.current) * H}px)`
    }

    this.element.classList.toggle("is-overview", this.overview)
    this.viewportTarget.classList.toggle("is-empty", !this.current.querySelector(".rori-win"))
    this.#renderWorkspaces()
    this.#renderMinimap()
  }

  frameLoaded(event) {
    const win = this.#win(event)
    if (event.target === this.#frame(win)) this.#applyMeta(win)
  }

  frameMissing(event) {
    const win = this.#win(event)
    if (event.target !== this.#frame(win)) return
    event.preventDefault()

    const message = document.createElement("p")
    message.className = "rori-win__error"
    message.textContent = this.loadErrorValue
    event.target.replaceChildren(message)
    this.#title(win).textContent = event.detail.response.status
    win.classList.remove("is-loading")
    if (!win.dataset.placed) {
      win.dataset.placed = "1"
      this.#place(win, "tile", "md")
    }
    this.focus(win)
  }

  // Esc on a modal window closes it for good.
  cancel(event) {
    event.preventDefault()
    this.#remove(this.#win(event))
  }

  close(event) {
    this.#remove(this.#win(event))
  }

  toggleFullWidth(event) {
    if (event.target.closest("button")) return
    this.focus(this.#win(event))
    this.#toggleFullWidth()
  }

  back(event) {
    const win = this.#win(event)
    const stack = this.histories.get(win) || []
    if (stack.length < 2) return
    stack.pop()
    this.#frame(win).setAttribute("src", stack.pop())
  }

  detach(event) {
    const url = this.#src(this.#win(event))
    if (url) window.open(url, "_blank", "noopener")
  }

  // Placement ------------------------------------------------------------------

  #spawn(url, { reuse = false, into = null } = {}) {
    const win = this.templateTarget.content.firstElementChild.cloneNode(true)
    const frame = this.#frame(win)
    frame.id = `win_${crypto.randomUUID().slice(0, 8)}`
    frame.setAttribute("src", url)
    win.dataset.reuse = reuse
    win.classList.add("is-loading")
      ; (into || this.floatingTarget).append(win)
    if (!into) setTimeout(() => this.#revealIfSlow(win), 600)
    return win
  }

  #applyMeta(win) {
    const template = this.#frame(win).querySelector(":scope > template[data-window-meta]")
    if (!template) return

    const meta = JSON.parse(template.dataset.windowMeta)
    const first = !win.dataset.placed
    const wasModal = win.dataset.mode === "modal"
    win.dataset.key = meta.key || ""
    this.#title(win).textContent = meta.title
    win.classList.remove("is-loading")

    // Reuse: a freshly opened window, or a modal that finished (e.g. redirected to
    // a show page), takes the place of the existing window with the same key.
    const reusable = meta.key && meta.mode !== "modal" && (wasModal || (first && win.dataset.reuse === "true"))
    const twin = reusable && this.windowTargets.find((other) =>
      other !== win && other.dataset.key === meta.key && other.dataset.mode !== "modal")
    win.dataset.reuse = false
    if (twin) return this.#takeOver(win, twin)

    if (first) {
      win.dataset.placed = "1"
      this.#place(win, meta.mode, meta.size, this.#hintedWorkspace(meta.workspace))
    } else if (meta.mode !== win.dataset.mode) {
      this.#place(win, meta.mode, meta.size, this.#wsOf(win) || this.current)
    }
    this.#pushHistory(win)

    if (first || wasModal !== (meta.mode === "modal")) return this.focus(win)
    if (win === this.focused) this.#syncUrl(win)
    this.layout()
  }

  #place(win, mode = "tile", size = "md", ws = this.current) {
    win.dataset.mode = mode
    win.dataset.size = size

    if (mode === "modal") {
      if (win.open && !win.matches(":modal")) win.close()
      this.#moveTo(win, this.floatingTarget)
      win.style.width = `${MODAL_WIDTHS[size] || MODAL_WIDTHS.sm}px`
      if (!win.open) {
        win.returnFocus = document.activeElement // see #remove
        win.showModal()
      }
      return
    }

    if (win.matches(":modal")) win.close()
    win.style.width = ""
    const width = mode === "fullscreen" ? 1 : SIZES[size] || SIZES.md
    const col = win.closest(".rori-col")
    if (col) col.dataset.w = width
    else this.#moveTo(win, this.#newColumnIn(ws, width))
    this.#open(win)
  }

  // The loaded window takes the twin's slot and back-history, so to the user it
  // looks like the twin navigated.
  #takeOver(win, twin) {
    if (win.matches(":modal")) win.close()
    win.dataset.mode = twin.dataset.mode
    win.dataset.size = twin.dataset.size
    win.dataset.placed = "1"
    this.histories.set(win, [...(this.histories.get(twin) || [])])
    this.#moveTo(win, twin.parentElement, twin)
    twin.remove()
    this.#open(win)
    this.#pushHistory(win)
    this.focus(win)
  }

  #revealIfSlow(win) {
    if (!win.isConnected || win.dataset.placed) return
    win.dataset.placed = "1"
    this.#place(win, "tile", "md")
    this.focus(win)
  }

  // Every close (×, keys, Esc on a modal, ⌘K) ends here. Unsaved edits ask
  // first; tiled windows can be brought back with reopen_window.
  #remove(win) {
    if (!win) return
    if (win.querySelector("form[data-rori-dirty]") && !window.confirm(this.discardPromptValue)) return

    const col = win.closest(".rori-col")
    const neighbour = col && (win.nextElementSibling || win.previousElementSibling ||
      this.#remembered(col.nextElementSibling) || this.#remembered(col.previousElementSibling))
    if (col && this.#src(win)) this.#rememberClosed(win, col)
    // Removing a modal (unlike dialog.close()) doesn't hand focus back to what
    // opened it — e.g. the terminal prompt a `new user` came from.
    const returnFocus = win.matches(":modal") ? win.returnFocus : null

    win.remove()
    if (col && !col.querySelector(".rori-win")) col.remove()
    if (win !== this.focused && this.focused?.isConnected) this.layout()
    else this.focus(neighbour || this.#focusIn(this.current) || this.current.querySelector(".rori-win"))
    if (returnFocus?.isConnected && returnFocus.checkVisibility()) returnFocus.focus({ preventScroll: true })
  }

  #rememberClosed(win, col) {
    const ws = this.#wsOf(col)
    this.closed.push({
      url: this.#src(win), mode: win.dataset.mode, size: win.dataset.size, w: col.dataset.w,
      workspace: ws.dataset.name, index: this.#columns(ws).indexOf(col),
    })
    if (this.closed.length > CLOSED_LIMIT) this.closed.shift()
  }

  // Brings the last closed window back as a column where it was.
  #reopen() {
    const entry = this.closed.pop()
    if (!entry) return

    const ws = this.#workspace(entry.workspace) || this.current
    const col = this.#createColumn(entry.w)
    const at = this.#columns(ws)[entry.index]
    at ? at.before(col) : this.#strip(ws).append(col)
    const win = this.#spawn(entry.url, { into: col })
    Object.assign(win.dataset, { placed: "1", mode: entry.mode, size: entry.size })
    this.#open(win)
    this.focus(win)
  }

  #moveTo(win, parent, before = null) {
    // Re-inserting a modal dialog would drop it from the top layer.
    if (win.parentElement === parent && !before) return
    const col = win.closest(".rori-col")
    parent.insertBefore(win, before)
    if (col && col !== parent && !col.querySelector(".rori-win")) col.remove()
  }

  #open(win) {
    if (!win.open && win.isConnected) win.dataset.mode === "modal" ? win.showModal() : win.show()
  }

  #restore() {
    const saved = this.#load()
    const here = location.pathname + location.search
    const main = this.windowTargets.find((win) => this.#frame(win).id === "win_main")
    let mainPlaced = false

    for (const { name, columns = [], focus } of saved.workspaces || []) {
      const ws = this.#createWorkspace(name)
      columns.forEach(({ w, windows = [] }, c) => {
        const col = this.#createColumn(w)
        this.#strip(ws).append(col)
        windows.filter(({ url }) => url).forEach(({ url, mode, size }, r) => {
          const reuseMain = main && !mainPlaced && url === here
          const win = reuseMain ? main : this.#spawn(url, { into: col })
          if (reuseMain) { col.append(main); mainPlaced = true }
          Object.assign(win.dataset, { placed: "1", mode: mode || "tile", size: size || "md" })
          this.#open(win)
          if (focus?.[0] === c && focus?.[1] === r) this.lastFocus.set(ws, win)
        })
        if (!col.children.length) col.remove()
      })
    }

    this.current = this.#workspace(saved.current) || this.#workspaces()[0] || this.#createWorkspace("1")
    if (!main) return this.#switchTo(this.current)
    this.#applyMeta(main)
    this.focus(main)
  }

  // Navigation -----------------------------------------------------------------

  #focusDirection(direction) {
    const win = this.#focusIn(this.current)
    if (!win) {
      if (direction === "up" || direction === "down") this.#stepWorkspace(direction)
      return
    }
    const col = win.closest(".rori-col")
    if (direction === "left") return this.focus(this.#remembered(col.previousElementSibling) || win)
    if (direction === "right") return this.focus(this.#remembered(col.nextElementSibling) || win)

    const next = direction === "up" ? win.previousElementSibling : win.nextElementSibling
    next ? this.focus(next) : this.#stepWorkspace(direction)
  }

  // Past the last workspace there is always an empty one to go to.
  #stepWorkspace(direction) {
    const workspaces = this.#workspaces()
    const i = workspaces.indexOf(this.current)
    if (direction === "up" && i > 0) this.#switchTo(workspaces[i - 1])
    if (direction === "down") {
      const below = workspaces[i + 1] || (this.current.querySelector(".rori-win") && this.#newWorkspace())
      if (below) this.#switchTo(below)
    }
  }

  // Window actions below act on `win` — the focused window by default, or the
  // hovered one for hover keys — and only move focus when it was the focused one.

  #move(direction, win = this.#focusIn(this.current)) {
    if (!win) return
    const col = win.closest(".rori-col")

    const workspaces = this.#workspaces()
    const i = workspaces.indexOf(this.current)
    if (direction === "up") return i > 0 && this.#moveToWorkspace(workspaces[i - 1], win)
    if (direction === "down") return this.#moveToWorkspace(workspaces[i + 1], win)

    if (direction === "left") col.previousElementSibling?.before(col)
    else col.nextElementSibling?.after(col)
    this.#settle(win)
  }

  // Moves the window's column to `target` — a new workspace when missing. Focus
  // follows only if the column holds the focused window.
  #moveToWorkspace(target, win = this.#focusIn(this.current)) {
    if (!win || target === this.#wsOf(win)) return

    target ||= this.#newWorkspace()
    const col = win.closest(".rori-col")
    const anchor = this.#focusIn(target)?.closest(".rori-col")
    anchor ? anchor.after(col) : this.#strip(target).append(col)
    this.#windowsIn(col).forEach((other) => this.#open(other))
    col.contains(this.focused) ? this.focus(this.focused) : this.#settle(win)
  }

  // niri's consume-or-expel: a window alone in its column joins the neighbouring
  // column; a stacked window leaves into a new column on that side.
  #consumeOrExpel(side, win = this.#focusIn(this.current)) {
    if (!win) return
    const col = win.closest(".rori-col")

    if (this.#windowsIn(col).length > 1) {
      const fresh = this.#createColumn(col.dataset.w)
      side < 0 ? col.before(fresh) : col.after(fresh)
      fresh.append(win)
    } else {
      const target = side < 0 ? col.previousElementSibling : col.nextElementSibling
      if (!target) return
      target.append(win)
      col.remove()
    }
    this.#open(win)
    this.#settle(win)
  }

  #settle(win) {
    win === this.focused ? this.focus(win) : this.layout()
  }

  #cycleWidth(win = this.#focusIn(this.current)) {
    const col = win?.closest(".rori-col")
    if (!col) return
    col.dataset.w = WIDTHS.find((width) => width > Number(col.dataset.w) + 0.01) || WIDTHS[0]
    delete col.dataset.previous
    this.layout()
  }

  #toggleFullWidth(win = this.#focusIn(this.current)) {
    const col = win?.closest(".rori-col")
    if (!col) return
    if (Number(col.dataset.w) === 1) {
      col.dataset.w = col.dataset.previous || SIZES.md
      delete col.dataset.previous
    } else {
      col.dataset.previous = col.dataset.w
      col.dataset.w = 1
    }
    this.layout()
  }

  #center(win = this.#focusIn(this.current)) {
    const ws = this.current
    const col = win?.closest(".rori-col")
    if (!col || this.#wsOf(col) !== ws) return
    const [left, right] = this.spans.get(ws).spans[this.#columns(ws).indexOf(col)]
    this.offsets.set(ws, left - (this.viewportTarget.clientWidth - (right - left)) / 2)
    this.#layoutStrip(ws, { reveal: false })
    this.#renderMinimap()
  }

  #layoutStrip(ws, { reveal = true } = {}) {
    const V = this.viewportTarget.clientWidth
    const columns = this.#columns(ws)
    let x = GAP
    const spans = columns.map((col) => {
      const width = Math.round(Number(col.dataset.w) * (V - GAP) - GAP)
      col.style.width = `${width}px`
      const span = [x, x + width]
      x += width + GAP
      return span
    })

    let offset = this.offsets.get(ws) || 0
    const focused = columns.indexOf(this.#focusIn(ws)?.closest(".rori-col"))
    if (reveal && !this.holdingReveal && focused >= 0) {
      const [left, right] = spans[focused]
      if (right + GAP > offset + V) offset = right + GAP - V
      if (left - GAP < offset) offset = left - GAP
    }
    offset = clamp(offset, 0, Math.max(0, x - V))

    this.offsets.set(ws, offset)
    this.spans.set(ws, { spans, total: x })
    this.#strip(ws).style.transform = this.overview ? "none" : `translateX(${-offset}px)`
  }

  #reloadSoon() {
    clearTimeout(this.reloadTimer)
    this.reloadTimer = setTimeout(() => {
      const windows = this.pendingReloads.size ? [...this.pendingReloads] : this.windowTargets
      this.pendingReloads.clear()
      windows.filter((win) => win.isConnected && !this.#busy(win)).forEach((win) => this.#frame(win).reload())
    }, 100)
  }

  #holdRevealUntilPointerUp() {
    this.holdingReveal = true
    const release = () => {
      removeEventListener("pointerup", release)
      removeEventListener("pointercancel", release)
      this.holdingReveal = false
      this.layout()
    }
    addEventListener("pointerup", release)
    addEventListener("pointercancel", release)
  }

  // Don't morph a form out from under the user: modals, windows being typed in
  // and windows with unsaved edits (even when you've moved on) are skipped.
  #busy(win) {
    return win.dataset.mode === "modal" ||
      Boolean(win.querySelector("form[data-rori-dirty]")) ||
      Boolean(win.contains(document.activeElement) && document.activeElement.closest("form"))
  }

  #pushHistory(win) {
    const url = this.#src(win)
    const stack = this.histories.get(win) || []
    if (url && stack.at(-1) !== url) stack.push(url)
    this.histories.set(win, stack)
    this.#part(win, "back").disabled = stack.length < 2
  }

  #syncUrl(win) {
    const url = (win && this.#src(win)) || this.rootUrlValue
    if (url !== location.pathname + location.search) history.replaceState(history.state, "", url)
  }

  // Workspaces -----------------------------------------------------------------

  #switchTo(ws) {
    this.current = ws
    this.focus(this.#focusIn(ws) || ws.querySelector(".rori-win"))
  }

  #hintedWorkspace(name) {
    if (!name) return this.current
    return name === "new" ? this.#newWorkspace() : this.#workspace(name) || this.#createWorkspace(name)
  }

  #createWorkspace(name) {
    const ws = document.createElement("section")
    ws.className = "rori-workspace"
    ws.dataset.name = name
    const strip = document.createElement("div")
    strip.className = "rori-strip"
    ws.append(strip)
    this.stackTarget.append(ws)
    return ws
  }

  #newWorkspace() {
    const numbers = this.#workspaces().map((ws) => ws.dataset.name).filter((name) => /^\d+$/.test(name)).map(Number)
    return this.#createWorkspace(String(Math.max(0, ...numbers) + 1))
  }

  // Empty workspaces disappear once you leave them.
  #prune() {
    this.#workspaces().forEach((ws) => {
      if (ws !== this.current && !ws.querySelector(".rori-win")) ws.remove()
    })
  }

  // Chrome ---------------------------------------------------------------------

  #renderWorkspaces() {
    this.workspacesTarget.replaceChildren(...this.#workspaces().map((ws, i) => {
      const button = document.createElement("button")
      button.type = "button"
      button.className = "rori-workspace-button"
      button.textContent = this.#workspaceLabel(ws, i)
      if (ws === this.current) button.setAttribute("aria-current", "true")
      button.addEventListener("click", () => {
        this.overview = false
        this.#switchTo(ws)
      })
      return button
    }))
  }

  #renderMinimap() {
    const ws = this.current
    const V = this.viewportTarget.clientWidth
    const offset = this.offsets.get(ws) || 0
    const { spans = [] } = this.spans.get(ws) || {}

    this.minimapTarget.replaceChildren(...this.#columns(ws).map((col, i) => {
      const [left, right] = spans[i] || [0, 0]
      const button = document.createElement("button")
      button.type = "button"
      button.className = "rori-minimap__col"
      button.style.width = `${Number(col.dataset.w) * 72}px`
      button.title = this.#windowsIn(col).map((win) => this.#title(win).textContent).join(" + ")
      button.classList.toggle("is-visible", left >= offset - 1 && right <= offset + V + 1)
      this.#windowsIn(col).forEach((win) => {
        const cell = document.createElement("span")
        cell.classList.toggle("is-focused", win === this.focused)
        button.append(cell)
      })
      button.addEventListener("click", () => this.focus(this.#remembered(col)))
      return button
    }))
  }

  // Lookups --------------------------------------------------------------------

  #workspaces() {
    return [...this.stackTarget.children]
  }

  // Position, plus the name when a page gave the workspace one ("2 projects").
  #workspaceLabel(ws, i = this.#workspaces().indexOf(ws)) {
    const name = ws.dataset.name
    return /^\d+$/.test(name) ? String(i + 1) : `${i + 1} ${name}`
  }

  #workspace(name) {
    return this.#workspaces().find((ws) => ws.dataset.name === name)
  }

  #strip(ws) {
    return ws.firstElementChild
  }

  #columns(ws) {
    return [...this.#strip(ws).children]
  }

  #createColumn(width) {
    const col = document.createElement("div")
    col.className = "rori-col"
    col.dataset.w = width
    return col
  }

  #newColumnIn(ws, width) {
    const col = this.#createColumn(width)
    const anchor = this.#focusIn(ws)?.closest(".rori-col")
    anchor ? anchor.after(col) : this.#strip(ws).append(col)
    return col
  }

  #windowsIn(col) {
    return col ? [...col.querySelectorAll(":scope > .rori-win")] : []
  }

  #wsOf(win) {
    return win.closest(".rori-workspace")
  }

  #focusIn(ws) {
    const win = this.lastFocus.get(ws)
    return win?.isConnected && this.#wsOf(win) === ws ? win : null
  }

  #remembered(col) {
    if (!col) return null
    const win = this.lastInColumn.get(col)
    return win?.parentElement === col ? win : col.querySelector(".rori-win")
  }

  #mostVisible(ws) {
    const V = this.viewportTarget.clientWidth
    const offset = this.offsets.get(ws) || 0
    const { spans } = this.spans.get(ws)
    let best = null
    let bestSeen = 0
    this.#columns(ws).forEach((col, i) => {
      const [left, right] = spans[i]
      const seen = Math.min(right, offset + V) - Math.max(left, offset)
      if (seen > bestSeen) [best, bestSeen] = [col, seen]
    })
    return this.#remembered(best)
  }

  // Content under the pointer that scrolls sideways itself (a wide table) keeps
  // the swipe. Only real scrollers count: clipped boxes like .rori-workspace are
  // wider inside than out but don't scroll, and treating them as scrollers
  // made swipes over the bare desk do nothing.
  #scrollsSideways(target) {
    for (let el = target; el && el !== this.viewportTarget; el = el.parentElement) {
      if (el.scrollWidth > el.clientWidth && ["auto", "scroll"].includes(getComputedStyle(el).overflowX)) return true
    }
    return false
  }

  #win(event) {
    return event.target.closest(".rori-win")
  }

  #frame(win) {
    return win.querySelector(":scope > .rori-win__body > turbo-frame")
  }

  #part(win, name) {
    return win.querySelector(`:scope > .rori-win__bar [data-window-part="${name}"]`)
  }

  #title(win) {
    return this.#part(win, "title")
  }

  #src(win) {
    const src = this.#frame(win)?.getAttribute("src")
    if (!src) return null
    const url = new URL(src, location.href)
    return url.pathname + url.search
  }

  #load() {
    try {
      return JSON.parse(sessionStorage.getItem(STORAGE_KEY)) || {}
    } catch {
      return {}
    }
  }
}
