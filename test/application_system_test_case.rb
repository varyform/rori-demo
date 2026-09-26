require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 900 ]

  # The desk saves its layout to sessionStorage when a page is left, which can
  # happen after Capybara's own reset clears storage — so a test could restore
  # the previous test's windows. Start every test from clean storage instead,
  # cleared on a same-origin page that has no desk to save anything.
  setup do
    visit rails_health_check_path
    execute_script("sessionStorage.clear(); localStorage.clear()")
  end

  private
    def run_command(query, new_window: false)
      find("body").send_keys [ :meta, "k" ]
      within "dialog.rori-palette" do
        find(".rori-palette__input").set(query)
        assert_selector ".rori-palette__item[aria-selected=true]"
        find(".rori-palette__input").send_keys(new_window ? [ :shift, :enter ] : :enter)
      end
      assert_no_selector "dialog.rori-palette[open]"
    end

    def press(*keys)
      find("body").send_keys [ :alt, *keys ]
    end

    def terminal_run(line)
      input = find(".rori-terminal__input")
      input.set(line)
      input.send_keys :enter
      assert_selector ".rori-terminal__entry--echo", text: line
    end

    def boxes(*elements)
      sleep 0.4 # strip and width transitions
      elements.map { |element| evaluate_script("arguments[0].getBoundingClientRect().toJSON()", element) }
    end

    # The page reads the timeout on load, so this wraps the visit.
    def with_hover_timeout(seconds)
      previous = Rori.hover_timeout
      Rori.hover_timeout = seconds
      yield
    ensure
      Rori.hover_timeout = previous
    end

    def focused_field_id = evaluate_script("document.activeElement.id")

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
      find("dialog.rori-win[open]", text: title) { it.find(".rori-win__title").text == title }
    end

    def assert_focused(title)
      assert_selector "dialog.rori-win.is-focused .rori-win__title", exact_text: title
    end

    def assert_workspace(name)
      assert_selector ".rori-workspace-button[aria-current]", text: name
    end

    # Window edges measured from the viewport edges, once animations settle: [left, top, right, bottom].
    def window_insets(window)
      sleep 0.4
      evaluate_script(<<~JS, window)
        ((win) => {
          const w = win.getBoundingClientRect(), v = document.querySelector(".rori-viewport").getBoundingClientRect()
          return [w.left - v.left, w.top - v.top, v.right - w.right, v.bottom - w.bottom].map(Math.round)
        })(arguments[0])
      JS
    end
end
