require "application_system_test_case"

class DeskTest < ApplicationSystemTestCase
  test "blank desk; a ⌘K modal form becomes the new user's column" do
    visit root_path
    assert_text "Nothing open"

    run_command "new user"
    within "dialog.win:modal" do
      fill_in "Name", with: "Grace"
      fill_in "Email", with: "grace@example.com"
      click_on "Create User"
    end

    assert_no_selector "dialog.win:modal"
    assert_selector ".col dialog.win", text: "Grace"
    assert_current_path user_path(User.find_by!(email: "grace@example.com"))
  end

  test "a hovered desk link opens its window (hover prefetch must not leak into window frames)" do
    visit users_path
    within(window_titled("Users")) do
      find("a", text: "New user").hover
      sleep 0.3
      click_on "New user"
    end

    assert_selector "dialog.win:modal", text: "Name"
    assert_no_text "couldn't be shown"
  end

  test "invalid modal submissions keep the modal up with field errors" do
    visit root_path
    run_command "new user"
    within "dialog.win:modal" do
      fill_in "Email", with: users(:oleh).email
      click_on "Create User"
      assert_selector ".user_name .error"
      assert_selector ".user_email .error"
    end
  end

  test "opening a page whose key is taken reuses that window; back returns" do
    visit root_path
    run_command "users"
    window_titled "Users"

    run_command "oleh"
    window_titled "Oleh"
    assert_selector ".col", count: 1

    click_on "Back"
    window_titled "Users"
  end

  test "new windows open as a column right of the focused one and the strip scrolls to it" do
    visit users_path
    users = window_titled("Users")
    run_command "oleh", new_window: true
    oleh = window_titled("Oleh")

    assert_focused "Oleh"
    assert_equal 12, window_insets(oleh)[2], "focused column is fully visible at the right edge"
    assert_operator window_insets(users)[0], :<, 0, "strip scrolled the first column partly off-screen"

    press :left
    assert_focused "Users"
    assert_equal 12, window_insets(users)[0]
  end

  test "column widths cycle and go full width" do
    visit users_path
    users = window_titled("Users")
    width = -> { 1400 - window_insets(users).values_at(0, 2).sum }

    assert_in_delta (1400 - 12) * 2 / 3.0 - 12, width.call, 2
    press "r"
    assert_in_delta (1400 - 12) / 3.0 - 12, width.call, 2
    press "f"
    assert_in_delta 1400 - 24, width.call, 2
  end

  test "alt+[ stacks a window into the neighbouring column, alt+] expels it" do
    visit users_path
    run_command "oleh", new_window: true
    window_titled "Oleh"
    assert_selector ".col", count: 2

    press "["
    assert_selector ".col", count: 1
    assert_selector ".col > dialog.win", count: 2

    press "]"
    assert_selector ".col", count: 2
  end

  test "pages choose their workspace and mode; workspaces stack vertically" do
    visit root_path
    run_command "dashboard"
    assert_workspace "overview"
    assert_equal [ 12, 0, 12, 12 ], window_insets(window_titled("Dashboard"))

    run_command "projects"
    assert_workspace "projects"
    window_titled "Projects"

    press :up
    assert_workspace "overview"
    assert_focused "Dashboard"
  end

  test "alt+shift+digit and ⌘K move the focused column between workspaces" do
    visit users_path
    run_command "oleh", new_window: true
    window_titled "Oleh"

    press :shift, "2"
    assert_workspace "2"
    assert_focused "Oleh"
    assert_selector ".workspace[data-name='2'] .col", count: 1, visible: :all

    find("body").send_keys [ :meta, "k" ]
    within "dialog.palette" do
      find(".palette__input").set("move")
      assert_selector ".palette__item[aria-selected=true]", text: "Move column to workspace"
      find(".palette__input").send_keys :enter

      assert_selector ".palette__crumbs", text: "Move column to workspace… ›"
      assert_selector ".palette__item", count: 2
      find(".palette__input").set("1")
      assert_selector ".palette__item[aria-selected=true]", text: "1"
      find(".palette__input").send_keys :enter
    end

    assert_workspace "1"
    assert_focused "Oleh"
    assert_selector ".workspace-button", count: 1
    assert_selector ".col", count: 2
  end

  test "a field hovered in an inactive window lights up; one click activates the window and focuses it" do
    visit new_service_path
    form = window_titled("New service")
    run_command "oleh", new_window: true
    assert_focused "Oleh"
    assert_operator window_insets(form)[0], :<, 0, "the form is partly scrolled off-screen"

    branch = find("#service_branch")
    branch.hover
    assert_equal "solid", evaluate_script("getComputedStyle(arguments[0]).outlineStyle", branch)

    branch.click
    assert_focused "New service"
    assert_equal "service_branch", evaluate_script("document.activeElement.id")
    assert_equal 12, window_insets(form)[0], "the strip scrolled the form into view after the click"
  end

  test "desk chords are text editing inside a field; Esc leaves the field and they work again" do
    visit users_path
    run_command "new service"
    window_titled "New service"
    assert_equal "service_name", evaluate_script("document.activeElement.id")

    type_into_focus [ :alt, :left ]
    assert_focused "New service"

    type_into_focus :escape
    assert_equal "DIALOG", evaluate_script("document.activeElement.tagName")
    type_into_focus [ :alt, :left ]
    assert_focused "Users"
  end

  test "the keymap modifier is configurable" do
    Desk.modifier = "Control"
    visit users_path
    run_command "oleh", new_window: true
    assert_focused "Oleh"
    assert_selector ".statusbar__hint kbd", text: "⌃←→↑↓"

    type_into_focus [ :alt, :left ]
    assert_focused "Oleh"
    type_into_focus [ :control, :left ]
    assert_focused "Users"
  ensure
    Desk.modifier = "Alt"
  end

  test "hover keys: w over an inactive window closes it while a field elsewhere keeps focus; reopen brings it back" do
    with_hover_timeout(3) do
      editing_with_users_beside

      find("dialog.win .win__title", exact_text: "Users").hover
      assert_selector "dialog.win.is-armed .win__armed"
      type_into_focus "w"

      assert_no_selector "dialog.win .win__title", exact_text: "Users"
      assert_equal [ "service_name", "api-gateway" ], evaluate_script("[document.activeElement.id, document.activeElement.value]")

      type_into_focus :escape
      type_into_focus [ :alt, :shift, "t" ]
      window_titled "Users"
    end
  end

  test "hover keys disarm once the pointer rests; then letters go to the field" do
    with_hover_timeout(0.3) do
      editing_with_users_beside

      find("dialog.win .win__title", exact_text: "Users").hover
      assert_selector "dialog.win.is-armed"
      assert_no_selector "dialog.win.is-armed", wait: 2
      type_into_focus "w"

      assert_equal "api-gatewayw", find("#service_name").value
      window_titled "Users"
    end
  end

  test "typing any other key disarms; hover keys need fresh pointer movement" do
    with_hover_timeout(3) do
      editing_with_users_beside

      find("dialog.win .win__title", exact_text: "Users").hover
      assert_selector "dialog.win.is-armed"
      type_into_focus "x"
      assert_no_selector "dialog.win.is-armed"
      type_into_focus "w"

      assert_equal "api-gatewayxw", find("#service_name").value
      window_titled "Users"
    end
  end



  test "hover keys stay off while a modal is open" do
    with_hover_timeout(3) do
      visit users_path
      run_command "oleh", new_window: true
      window_titled "Oleh"
      run_command "new project"
      assert_selector "dialog.win:modal"

      find("dialog.win .win__title", exact_text: "Users").hover
      type_into_focus "w"

      assert_equal "w", find("#project_name").value
      window_titled "Users"
    end
  end

  test "outside fields, bare keys act on the focused window; in a field they type" do
    visit projects_path
    window_titled "Projects"

    type_into_focus "w"
    assert_no_selector "dialog.win[open]"

    type_into_focus "u"
    window_titled "Projects"

    run_command "new project"
    assert_selector "dialog.win:modal #project_name:focus"
    type_into_focus "w"
    assert_equal "w", find("#project_name").value
    window_titled "Projects"
  end

  test "a window with a focused field wears an <input> badge: outside its edge, or inside when full width" do
    visit users_path
    run_command "new service"
    form = window_titled("New service")
    assert_equal "service_name", evaluate_script("document.activeElement.id")

    side = find(".typing-badge--side", text: "<input>")
    assert_no_selector ".typing-badge--inside"
    window_box, badge_box = boxes(form, side)
    assert_in_delta window_box["left"], badge_box["right"], 1, "hangs off the left edge"
    assert_operator badge_box["top"], :>, window_box["top"]

    type_into_focus :escape
    assert_no_selector ".typing-badge"

    find("#service_name").click
    type_into_focus :escape
    type_into_focus [ :alt, "f" ]
    find("#service_name").click
    inside = find(".typing-badge--inside", text: "<input>")
    assert_no_selector ".typing-badge--side"
    window_box, badge_box = boxes(form, inside)
    assert_operator badge_box["left"], :>, window_box["left"]
    assert_operator badge_box["bottom"], :<, window_box["bottom"]
  end

  test "the side badge flips to the right edge when the window touches the viewport's left" do
    visit new_service_path
    form = window_titled("New service")
    find("#service_name").click

    window_box, badge_box = boxes(form, find(".typing-badge--side"))
    assert_in_delta window_box["right"], badge_box["left"], 1
  end

  test "closing a window with unsaved edits asks first" do
    visit new_service_path
    fill_in "Name", with: "draft"

    dismiss_confirm(/unsaved changes/) { click_button "Close" }
    window_titled "New service"

    accept_confirm(/unsaved changes/) { click_button "Close" }
    assert_no_selector "dialog.win[open]"
  end

  test "tabbing into another window focuses it" do
    visit users_path
    run_command "oleh", new_window: true
    assert_focused "Oleh"

    execute_script("document.querySelector('dialog.win:not(.is-focused) a').focus()")
    assert_focused "Users"
  end

  test "a form with unsaved edits is not reloaded by broadcasts" do
    visit new_service_path
    fill_in "Name", with: "half-typed"
    run_command "users", new_window: true
    window_titled "Users"
    execute_script("document.activeElement.blur()")

    # No stream source inside the form window, so this refresh reloads every window.

    execute_script("Turbo.renderStreamMessage('<turbo-stream action=\"refresh\"></turbo-stream>')")
    sleep 0.5

    assert_equal "half-typed", find("#service_name").value
  end

  test "overview zooms out; clicking a window focuses it" do
    visit users_path
    run_command "dashboard"
    assert_workspace "overview"

    press "o"
    assert_selector "body.is-overview"
    window_titled("Users").click
    assert_no_selector "body.is-overview"
    assert_focused "Users"
  end

  test "reload restores columns into their workspaces" do
    visit root_path
    run_command "users"
    window_titled "Users"
    run_command "projects"
    assert_workspace "projects"

    refresh
    window_titled "Projects"
    assert_workspace "projects"

    find(".workspace-button", text: "1").click
    window_titled "Users"
  end

  test "broadcast refreshes morph the listening window without dropping the others" do
    visit root_path
    run_command "users"
    window_titled "Users"
    run_command "desk ui"
    window_titled "Desk UI"
    assert_selector "turbo-cable-stream-source[connected]", count: 2, visible: :all

    User.create!(name: "Linus", email: "linus@example.com")
    Turbo::StreamsChannel.broadcast_refresh_to(:users)

    find(".workspace-button", text: "1").click
    within(window_titled("Users")) { assert_text "Linus" }
    find(".workspace-button", text: "projects").click
    window_titled "Desk UI"
  end

  test "nested theme picker previews on the way, reverts on close and persists a pick" do
    visit root_path
    find("body").send_keys [ :meta, "k" ]
    within "dialog.palette" do
      find(".palette__input").set("theme")
      assert_selector ".palette__item[aria-selected=true]", text: "Pick theme"
      find(".palette__input").send_keys :enter

      assert_selector ".palette__crumbs", text: "Pick theme… ›"
      assert_selector ".palette__item[aria-selected=true][data-current]", text: "Default"
      find(".palette__input").send_keys :down
    end
    assert_selector "html[data-theme=catppuccin-latte]", visible: :all

    within("dialog.palette") { find(".palette__input").send_keys :escape }
    assert_selector "dialog.palette .palette__item", text: "Pick theme"
    assert_no_selector "dialog.palette .palette__crumbs"
    within("dialog.palette") { find(".palette__input").send_keys :escape }
    assert_no_selector "dialog.palette[open]"
    assert_no_selector "html[data-theme]", visible: :all

    find("body").send_keys [ :meta, "k" ]
    within "dialog.palette" do
      find(".palette__input").set("theme")
      assert_selector ".palette__item[aria-selected=true]", text: "Pick theme"
      find(".palette__input").send_keys :enter
      assert_selector ".palette__crumbs"
      find(".palette__input").set("nord")
      assert_selector ".palette__item[aria-selected=true]", text: "Nord"
      find(".palette__input").send_keys :enter
    end
    # The selection already previews Nord; the closed palette means the pick itself ran and was saved.
    assert_no_selector "dialog.palette[open]"
    assert_selector "html[data-theme=nord]", visible: :all

    refresh
    assert_selector "html[data-theme=nord]", visible: :all
  end

  private
    # A service edit form (name field focused) with the users list beside it.
    def editing_with_users_beside
      visit edit_service_path(services(:gateway))
      window_titled "Edit api-gateway"
      run_command "users", new_window: true
      window_titled "Users"
      find("#service_name").click
      assert_focused "Edit api-gateway"
      execute_script("document.activeElement.setSelectionRange(99, 99)")
    end

    def boxes(*elements)
      sleep 0.4 # strip and width transitions
      elements.map { |element| evaluate_script("arguments[0].getBoundingClientRect().toJSON()", element) }
    end

    # The page reads the timeout on load, so this wraps the visit.
    def with_hover_timeout(seconds)
      previous = Desk.hover_timeout
      Desk.hover_timeout = seconds
      yield
    ensure
      Desk.hover_timeout = previous
    end

  public

  test "Esc closes a modal window" do
    visit new_project_path
    assert_selector "dialog.win:modal"

    find("dialog.win:modal").send_keys :escape
    assert_no_selector "dialog.win[open]"
    assert_current_path root_path
  end
end
