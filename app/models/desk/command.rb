# A command-palette entry. Running it either opens `url` in a desk window,
# fires a client-side `action` (with an optional `param`) that the desk or
# theme controller picks up, or drills into a nested list: served at the
# `children` URL, or built in the browser from a named `source` for state the
# server can't see (see desk-palette's `source` event).
class Desk::Command < Data.define(:label, :group, :url, :action, :param, :children, :source, :current)
  ACTIONS = %w[ overview new_workspace cycle_width full_width center_column close_window reopen_window ].freeze

  class << self
    def all = routes + records + actions + [ workspace_mover, theme_picker ] + app_commands

    # Every parameterless GET route becomes a command once it has a label under
    # `desk.commands.routes.<controller>.<action>` — adding the locale key opts it in.
    def routes
      Rails.application.routes.routes.filter_map do |route|
        controller, action = route.defaults.values_at(:controller, :action)
        next unless controller && route.verb == "GET" && route.required_parts.empty?

        key = "desk.commands.routes.#{controller.tr("/", ".")}.#{action}"
        new(label: I18n.t(key), group: group(:open), url: route.format({})) if I18n.exists?(key)
      end.uniq(&:url)
    end

    # The most recently updated records of every model in `Desk.records`.
    def records
      Desk.records.map(&:constantize).flat_map do |model|
        model.order(updated_at: :desc).limit(Desk.record_limit).map do |record|
          new(label: record.to_s, group: model.model_name.human, url: url_helpers.polymorphic_path(record))
        end
      end
    end

    def actions
      ACTIONS.map { new(label: I18n.t(it, scope: "desk.commands.actions"), group: group(:desk), action: it) }
    end

    def workspace_mover
      new(label: I18n.t("desk.commands.workspaces.move"), group: group(:desk), source: "workspaces")
    end

    def theme_picker
      new(label: I18n.t("desk.commands.themes.pick"), group: group(:desk), children: url_helpers.desk_commands_themes_path)
    end

    # `param: ""` is the built-in theme (no data-theme attribute).
    def themes(current:)
      default = new(label: I18n.t("desk.commands.themes.default"), group: I18n.t("desk.commands.themes.auto"),
        action: "theme", param: "", current: current.nil?)

      [ default ] + Desk::Theme.all.map do |theme|
        new(label: theme.name, group: I18n.t(theme.dark? ? "dark" : "light", scope: "desk.commands.themes"),
          action: "theme", param: theme.slug, current: theme.slug == current&.slug)
      end
    end

    private
      def app_commands = Desk.commands.flat_map { Array(it.call) }

      def group(name) = I18n.t(name, scope: "desk.commands.groups")

      def url_helpers = Rails.application.routes.url_helpers
  end

  def initialize(label:, group:, url: nil, action: nil, param: nil, children: nil, source: nil, current: false) = super

  def to_partial_path = "desk/commands/command"
end
