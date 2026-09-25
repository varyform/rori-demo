# A command-palette entry: either opens a URL in a desk window or runs a
# client-side desk action (see desk_controller.js#command).
class Command < Data.define(:label, :group, :url, :action)
  DESK_ACTIONS = %w[ overview new_workspace cycle_width full_width center_column close_window ].freeze
  RECORD_LIMIT = 25

  class << self
    def all = routes + records + desk_actions

    # Every parameterless GET route becomes a command once it has a label under
    # `commands.routes.<controller>.<action>` — adding the locale key opts it in.
    def routes
      Rails.application.routes.routes.filter_map do |route|
        controller, action = route.defaults.values_at(:controller, :action)
        next unless controller && route.verb == "GET" && route.required_parts.empty?

        key = "commands.routes.#{controller.tr("/", ".")}.#{action}"
        new(label: I18n.t(key), group: I18n.t("commands.groups.open"), url: route.format({}), action: nil) if I18n.exists?(key)
      end.uniq(&:url)
    end

    def records
      [ User, Project ].flat_map do |model|
        model.order(updated_at: :desc).limit(RECORD_LIMIT).map do |record|
          new(label: record.to_s, group: model.model_name.human, url: url_helpers.polymorphic_path(record), action: nil)
        end
      end
    end

    def desk_actions
      DESK_ACTIONS.map do |action|
        new(label: I18n.t(action, scope: "commands.desk"), group: I18n.t("commands.groups.desk"), url: nil, action: action)
      end
    end

    private
      def url_helpers = Rails.application.routes.url_helpers
  end

  def to_partial_path = "commands/command"
end
