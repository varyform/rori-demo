# A command-palette entry. Running it either opens `url` in a desk window,
# fires a client-side `action` (with an optional `param`) that the desk or
# theme controller picks up, or — when it has `children` — drills into the
# nested command list served at that URL.
class Command < Data.define(:label, :group, :url, :action, :param, :children, :current)
  DESK_ACTIONS = %w[ overview new_workspace cycle_width full_width center_column close_window ].freeze
  RECORD_LIMIT = 25

  class << self
    def all = routes + records + desk_actions + [ theme_picker ]

    # Every parameterless GET route becomes a command once it has a label under
    # `commands.routes.<controller>.<action>` — adding the locale key opts it in.
    def routes
      Rails.application.routes.routes.filter_map do |route|
        controller, action = route.defaults.values_at(:controller, :action)
        next unless controller && route.verb == "GET" && route.required_parts.empty?

        key = "commands.routes.#{controller.tr("/", ".")}.#{action}"
        new(label: I18n.t(key), group: I18n.t("commands.groups.open"), url: route.format({})) if I18n.exists?(key)
      end.uniq(&:url)
    end

    def records
      [ User, Project ].flat_map do |model|
        model.order(updated_at: :desc).limit(RECORD_LIMIT).map do |record|
          new(label: record.to_s, group: model.model_name.human, url: url_helpers.polymorphic_path(record))
        end
      end
    end

    def desk_actions
      DESK_ACTIONS.map do |action|
        new(label: I18n.t(action, scope: "commands.desk"), group: I18n.t("commands.groups.desk"), action: action)
      end
    end

    def theme_picker
      new(label: I18n.t("commands.themes.pick"), group: I18n.t("commands.groups.desk"), children: url_helpers.commands_themes_path)
    end

    # `param: ""` is the built-in theme (no data-theme attribute).
    def themes(current:)
      default = new(label: I18n.t("commands.themes.default"), group: I18n.t("commands.themes.auto"),
        action: "theme", param: "", current: current.nil?)

      [ default ] + Theme.all.map do |theme|
        new(label: theme.name, group: I18n.t(theme.dark? ? "dark" : "light", scope: "commands.themes"),
          action: "theme", param: theme.slug, current: theme.slug == current&.slug)
      end
    end

    private
      def url_helpers = Rails.application.routes.url_helpers
  end

  def initialize(label:, group:, url: nil, action: nil, param: nil, children: nil, current: false) = super

  def to_partial_path = "commands/command"
end
