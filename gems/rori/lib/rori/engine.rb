module Rori
  # Not isolated: the desk wraps the host app's own pages, so its controllers
  # inherit the app's ApplicationController (which includes Rori::Windowed),
  # its helpers join the app's, and its route file is drawn into the app's
  # routes with `draw :desk` (engines add config/routes to the draw paths).
  # Views, locales, rake tasks and app/assets come along the usual engine way.
  class Engine < ::Rails::Engine
    # Propshaft picks up app/assets; the Stimulus controllers live in
    # app/javascript, which only the host app gets by default.
    initializer "rori.assets" do |app|
      app.config.assets.paths << root.join("app/javascript") if app.config.respond_to?(:assets)
    end

    initializer "rori.importmap", before: "importmap" do |app|
      app.config.importmap.paths << root.join("config/importmap.rb")
      app.config.importmap.cache_sweepers << root.join("app/javascript")
    end
  end
end
