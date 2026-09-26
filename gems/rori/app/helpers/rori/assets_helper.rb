module Rori::AssetsHelper
  # The desk's stylesheets. Propshaft's `stylesheet_link_tag :app` only globs
  # the host's app/assets, so the shell links these right after it — after the
  # host's tokens and `@layer` order (_init.css), which the desk's CSS relies on.
  def rori_stylesheet_link_tags(**options)
    paths = Rails.application.assets.load_path.asset_paths_by_glob("#{Rori::Engine.root.join("app/assets")}/**/*.css")
    stylesheet_link_tag(*paths, **options)
  end
end
