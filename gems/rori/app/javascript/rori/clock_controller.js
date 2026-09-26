import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.tick()
    this.timer = setInterval(() => this.tick(), 10_000)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  tick() {
    const now = new Date()
    this.element.dateTime = now.toISOString()
    this.element.textContent = now.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })
  }
}
