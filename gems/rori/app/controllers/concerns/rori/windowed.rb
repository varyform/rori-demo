# Renders every page as a desk window. Frame requests get a layout that wraps
# the page in whichever window frame asked for it (their ids are generated);
# full page loads get the desk shell with the page as its first window.
# Controllers that render the bare desk instead override `windowed?`.
module Rori::Windowed
  extend ActiveSupport::Concern

  included do
    layout -> { turbo_frame_request? ? "rori/window" : "rori/shell" }
    helper_method :windowed?
  end

  private
    def windowed? = true
end
