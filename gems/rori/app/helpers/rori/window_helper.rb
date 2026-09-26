module Rori::WindowHelper
  # Declares how the current page wants to be shown on the desk. The window
  # layout serializes it into a <template data-window-meta>, which the desk
  # (rori_controller.js) reads on every frame load:
  #
  #   size:      column width :sm ⅓ | :md ½ | :lg ⅔ | :xl full (default :md);
  #              for modals, the dialog width
  #   mode:      :tile (a new column next to the focused one) | :modal |
  #              :fullscreen (a full-width column)            (default :tile)
  #   workspace: "name" (found or created) | :new               (first load only)
  #   key:       windows sharing a key are reused when opened
  #              (default controller_path, nil for modals)
  def window(**options)
    @window_options = options
  end

  def window_title
    content_for(:title) || t("#{controller_path.tr("/", ".")}.#{template_action}.title")
  end

  def window_meta_tag
    options = { size: :md, mode: :tile }.merge(@window_options || {})
    options[:key] = options.fetch(:key) { controller_path unless options[:mode] == :modal }
    tag.template(data: { window_meta: options.merge(title: window_title) })
  end

  # Opens the URL through the desk (a new or reused window) instead of
  # navigating the current one. Without JavaScript it's a plain full-page link.
  def rori_link_to(name, url, **options)
    link_to name, url, **options, data: { **options.fetch(:data, {}), turbo_frame: "_top" }
  end

  private
    # 422 re-renders run under create/update but show the new/edit template.
    def template_action = { "create" => "new", "update" => "edit" }.fetch(action_name, action_name)
end
