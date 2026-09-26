# The blank desk (Rori::DesktopsController) is mounted by the app, usually as `root`.
namespace :rori do
  resources :commands, only: :index
  # Nested command lists, shared by ⌘K and the terminal.
  namespace :commands do
    resource :ui, only: :show, controller: "ui"
    resources :themes, only: :index
    resources :wallpapers, only: :index
  end
end
