Rori.configure do |rori|
  rori.app_name = "Desk"
  rori.native_user_agent = "DeskApp" # src-tauri/tauri.conf.json
  rori.records = %w[ User Project Service ]
  rori.hover_keys = true
  rori.wallpapers = !Rails.env.test? # remote images; tests turn it on where needed

  rori.command :reindex_search, confirm: true do
    ReindexSearchJob.perform_later
    I18n.t("reindex_search.started")
  end
end
