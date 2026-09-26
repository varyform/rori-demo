import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

const STREAM = "text/vnd.turbo-stream.html"

// Corner notifications (rori/_notifications). They arrive as turbo streams
// appended to the stack: a server-side command's result (run here, from
// `rori-command:run`) or a `Rori.notify` broadcast. The stack is a manual
// popover, open while it holds any. Each notification fades out on its own
// (a CSS animation, paused while the pointer is on the stack) unless sticky.
export default class extends Controller {
  static targets = ["stack", "notification", "failure"]
  static values = { url: String }

  async run({ detail: { run } }) {
    if (!run) return
    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        body: new URLSearchParams({ name: run }),
        headers: { Accept: STREAM, "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content },
      })
      if (!response.headers.get("Content-Type")?.startsWith(STREAM)) throw new Error(`${response.status}`)
      Turbo.renderStreamMessage(await response.text())
    } catch {
      this.stackTarget.append(this.failureTarget.content.cloneNode(true))
    }
  }

  notificationTargetConnected() {
    if (!this.stackTarget.matches(":popover-open")) this.stackTarget.showPopover()
  }

  notificationTargetDisconnected() {
    if (!this.hasNotificationTarget && this.stackTarget.matches(":popover-open")) this.stackTarget.hidePopover()
  }

  dismiss({ target }) {
    target.closest(".rori-notification").remove()
  }

  expire({ target, animationName }) {
    if (animationName === "rori-notification-out") target.remove()
  }
}
