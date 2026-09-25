# The blank desk (Desk::DesktopsController) is mounted by the app, usually as `root`.
namespace :desk do
  resources :commands, only: :index
  namespace :commands do
    resources :themes, only: :index
  end
end
