ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

module DeskTestHelper
  # Requests the page the way a desk window does: inside a named turbo-frame.
  def get_in_window(path, frame: "win_test")
    get path, headers: { "Turbo-Frame" => frame }
  end

  def window_meta(frame: "win_test")
    template = css_select("turbo-frame##{frame} > template[data-window-meta]").first
    assert template, "expected window meta inside turbo-frame##{frame}"
    JSON.parse(template["data-window-meta"])
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) { include DeskTestHelper }
