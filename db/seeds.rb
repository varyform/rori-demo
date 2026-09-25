oleh = User.find_or_create_by!(email: "oleh@example.com") { it.name = "Oleh" }
ada = User.find_or_create_by!(email: "ada@example.com") { it.name = "Ada Lovelace" }

{
  "Desk UI" => [ oleh, "active", "Window manager on top of Turbo frames." ],
  "Dotfiles" => [ oleh, "done", nil ],
  "Blog" => [ oleh, "paused", "Static site, rewrite pending." ],
  "Analytical Engine" => [ ada, "idea", "Notes on the engine.\n\nNote G first." ]
}.each do |name, (user, status, description)|
  Project.find_or_create_by!(name: name) do |project|
    project.user = user
    project.status = status
    project.description = description
  end
end
