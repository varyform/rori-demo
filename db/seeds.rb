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

{
  "api-gateway" => { user: oleh, region: "fra1", size: "medium", replicas: 3, autoscale: true,
    repository: "https://github.com/oleh/api-gateway", environment: "RAILS_ENV=production\nLOG_LEVEL=info\n" },
  "billing-worker" => { user: oleh, region: "ams3", branch: "fix/retry-queue", health_check_path: "/health" },
  "search-indexer" => { user: ada, region: "fra1", size: "large", replicas: 2, notes: "BM25 rewrite in progress." }
}.each do |name, attributes|
  Service.find_or_create_by!(name: name) { it.assign_attributes(attributes) }
end
