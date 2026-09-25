# Reapplied after every code reload: Desk's settings live in a reloadable module.
Rails.application.config.to_prepare do
  Desk.configure do |desk|
    desk.records = %w[ User Project Service ]
    desk.hover_keys = true
    desk.wallpapers = !Rails.env.test? # remote images; tests turn it on where needed
  end
end
