# A command-palette entry. Running it either opens `url` in a desk window,
# fires a client-side `action` (with an optional `param`) that the desk or
# theme controller picks up, or drills into a nested list: served at the
# `children` URL, or built in the browser from a named `source` for state the
# server can't see (see rori-palette's `source` event).
class Rori::Command < Data.define(:label, :group, :url, :action, :param, :children, :source, :current)
  ACTIONS = %w[ overview new_workspace cycle_width full_width center_column close_window reopen_window toggle_terminal ].freeze

  class << self
    def all = routes + records + actions + [ workspace_mover, theme_picker, ui_menu ] + app_commands

    # Every parameterless GET route becomes a command once it has a label under
    # `desk.commands.routes.<controller>.<action>` — adding the locale key opts it in.
    def routes
      Rails.application.routes.routes.filter_map do |route|
        controller, action = route.defaults.values_at(:controller, :action)
        next unless controller && route.verb == "GET" && route.required_parts.empty?

        key = "rori.commands.routes.#{controller.tr("/", ".")}.#{action}"
        new(label: I18n.t(key), group: group(:open), url: route.format({})) if I18n.exists?(key)
      end.uniq(&:url)
    end

    # The most recently updated records of every model in `Rori.records`.
    def records
      Rori.records.map(&:constantize).flat_map do |model|
        model.order(updated_at: :desc).limit(Rori.record_limit).map do |record|
          new(label: record.to_s, group: model.model_name.human, url: url_helpers.polymorphic_path(record))
        end
      end
    end

    def actions
      ACTIONS.map { new(label: I18n.t(it, scope: "rori.commands.actions"), group: group(:rori), action: it) }
    end

    def workspace_mover
      new(label: I18n.t("rori.commands.workspaces.move"), group: group(:rori), source: "workspaces")
    end

    def theme_picker
      new(label: I18n.t("rori.commands.themes.pick"), group: group(:rori), children: url_helpers.rori_commands_themes_path)
    end

    def ui_menu
      new(label: I18n.t("rori.commands.ui.label"), group: group(:rori), children: url_helpers.rori_commands_ui_path)
    end

    # "UI ›": one nested list per appearance setting.
    def ui
      theme = new(label: I18n.t("rori.commands.ui.theme"), group: group(:ui), children: url_helpers.rori_commands_themes_path)
      wallpaper = new(label: I18n.t("rori.commands.ui.wallpaper"), group: group(:ui), children: url_helpers.rori_commands_wallpapers_path)
      Rori.wallpapers ? [ theme, wallpaper ] : [ theme ]
    end

    def wallpapers(current:)
      Rori::Wallpaper::MODES.map do |mode|
        new(label: I18n.t(mode, scope: "rori.commands.wallpapers"), group: I18n.t("rori.commands.ui.wallpaper"),
          action: "wallpaper", param: mode, current: mode == current)
      end
    end

    # `param: ""` is the built-in theme (no data-theme attribute).
    def themes(current:)
      default = new(label: I18n.t("rori.commands.themes.default"), group: I18n.t("rori.commands.themes.auto"),
        action: "theme", param: "", current: current.nil?)

      [ default ] + Rori::Theme.all.map do |theme|
        new(label: theme.name, group: I18n.t(theme.dark? ? "dark" : "light", scope: "rori.commands.themes"),
          action: "theme", param: theme.slug, current: theme.slug == current&.slug)
      end
    end

    private
      def app_commands = Rori.commands.flat_map { Array(it.call) }

      def group(name) = I18n.t(name, scope: "rori.commands.groups")

      def url_helpers = Rails.application.routes.url_helpers
  end

  def initialize(label:, group:, url: nil, action: nil, param: nil, children: nil, source: nil, current: false) = super

  def to_partial_path = "rori/commands/command"
end
