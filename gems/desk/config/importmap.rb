# The desk's Stimulus controllers; the host registers them with
# `import { registerDesk } from "desk"`.
pin_all_from Desk::Engine.root.join("app/javascript/desk"), under: "desk"
