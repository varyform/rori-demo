require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 900 ]

  # Capybara clears sessionStorage and only then leaves the page, and the desk
  # saves its layout on pagehide — so each test would restore the previous
  # test's windows. Clear again after the desk's own pagehide listener runs.
  teardown do
    execute_script("addEventListener('pagehide', () => sessionStorage.clear())") if current_url.start_with?("http")
  end

  private
    def run_command(query, new_window: false)
      find("body").send_keys [ :meta, "k" ]
      within "dialog.palette" do
        find(".palette__input").set(query)
        assert_selector ".palette__item[aria-selected=true]"
        find(".palette__input").send_keys(new_window ? [ :shift, :enter ] : :enter)
      end
      assert_no_selector "dialog.palette[open]"
    end

    def press(*keys)
      find("body").send_keys [ :alt, *keys ]
    end

    # Keys go to whatever has focus (a field, a window), like a real keyboard.
    def type_into_focus(keys)
      *modifiers, key = Array(keys)
      actions = page.driver.browser.action
      modifiers.each { actions.key_down(it) }
      actions.send_keys(key)
      modifiers.reverse_each { actions.key_up(it) }
      actions.perform
    end

    def window_titled(title)
      find("dialog.win[open]", text: title) { it.find(".win__title").text == title }
    end

    def assert_focused(title)
      assert_selector "dialog.win.is-focused .win__title", exact_text: title
    end

    def assert_workspace(name)
      assert_selector ".workspace-button[aria-current]", text: name
    end

    # Window edges measured from the viewport edges, once animations settle: [left, top, right, bottom].
    def window_insets(window)
      sleep 0.4
      evaluate_script(<<~JS, window)
        ((win) => {
          const w = win.getBoundingClientRect(), v = document.querySelector(".viewport").getBoundingClientRect()
          return [w.left - v.left, w.top - v.top, v.right - w.right, v.bottom - w.bottom].map(Math.round)
        })(arguments[0])
      JS
    end
end
