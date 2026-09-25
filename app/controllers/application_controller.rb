class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Desk windows are turbo-frames with generated ids, so frame requests get a
  # layout that wraps the page in whichever frame asked for it. Full page loads
  # render the desk shell with the page as its first window.
  layout -> { turbo_frame_request? ? "window" : "application" }

  helper_method :windowed?

  private
    def windowed? = true
end
