Desk.configure do |desk|
  desk.records = %w[ User Project Service ]
  desk.hover_keys = true
  desk.wallpapers = !Rails.env.test? # remote images; tests turn it on where needed
end
