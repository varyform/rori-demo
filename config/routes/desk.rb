# The blank desk (Desk::DesktopsController) is mounted by the app, usually as `root`.
namespace :desk do
  resources :commands, only: :index
  # Nested command lists, shared by ⌘K and the terminal.
  namespace :commands do
    resource :ui, only: :show, controller: "ui"
    resources :themes, only: :index
    resources :wallpapers, only: :index
  end
end
