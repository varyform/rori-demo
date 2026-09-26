require "application_system_test_case"
require "rake"

# Five end-to-end journeys that each prove one claim about the desk, across
# features rather than one feature at a time (desk_test.rb covers those).
class JourneysTest < ApplicationSystemTestCase
  # 1. Keyboard only: from a blank desk to a created record and back to it,
  #    never touching the mouse, with focus always where the next key needs it.
  test "the whole loop works from the keyboard alone" do
    visit root_path
    assert_text "Nothing open"

    type_into_focus :space
    type_into_focus "users"
    assert_selector ".palette__item[aria-selected=true]", text: "Users"
    type_into_focus :enter
    window_titled "Users"

    type_into_focus [ :meta, "k" ]
    type_into_focus "new user"
    assert_selector ".palette__item[aria-selected=true]", text: "New user"
    type_into_focus :enter
    assert_selector "dialog.win:modal #user_name:focus"
    type_into_focus "Grace Hopper"
    type_into_focus :tab
    type_into_focus "grace@example.com"
    type_into_focus :enter

    # The modal became the user's window, taking over the Users one (same key).
    window_titled "Grace Hopper"
    assert_selector ".col dialog.win", count: 1
    type_into_focus "w"
    assert_text "Nothing open"
    type_into_focus [ :alt, :shift, "t" ]
    window_titled "Grace Hopper"
    assert_equal "grace@example.com", User.find_by!(name: "Grace Hopper").email
  end

  # 2. Work is never lost: a half-filled form survives switching away, live
  #    updates, a stray single-key close and a reload of the neighbours.
  test "unsaved form input survives everything that could wipe it" do
    with_hover_timeout(3) do
      visit new_service_path
      window_titled "New service"
      fill_in "Name", with: "mailer"
      fill_in "Health check path", with: "/healthz"

      run_command "users", new_window: true
      window_titled "Users"
      execute_script("document.activeElement.blur()")
      User.create!(name: "Linus", email: "linus@example.com")
      Turbo::StreamsChannel.broadcast_refresh_to(:users)
      execute_script("Turbo.renderStreamMessage('<turbo-stream action=\"refresh\"></turbo-stream>')")
      within(window_titled("Users")) { assert_text "Linus" }

      find("dialog.win .win__title", exact_text: "New service").hover
      assert_selector "dialog.win.is-armed"
      dismiss_confirm(/unsaved changes/) { type_into_focus "w" }
      form = window_titled("New service")

      assert_equal [ "mailer", "/healthz" ], [ find("#service_name").value, find("#service_health_check_path").value ]
      within(form) do
        select "Oleh", from: "Owner"
        click_on "Create Service"
      end
      window_titled "mailer"
      assert_equal "/healthz", Service.find_by!(name: "mailer").health_check_path
    end
  end

  # 3. Layout is spatial and it sticks: pages place themselves, the keyboard
  #    moves between them without the mouse, and a reload restores all of it.
  test "workspaces and columns arrange themselves and survive a reload" do
    visit users_path
    run_command "oleh", new_window: true
    window_titled "Oleh"
    run_command "projects"
    assert_workspace "projects"
    run_command "dashboard"
    assert_workspace "overview"
    assert_equal [ 12, 12, 12, 12 ], window_insets(window_titled("Dashboard"))

    press "1"
    assert_workspace "1"
    assert_focused "Oleh"
    press :left
    assert_focused "Users"
    assert_equal 12, window_insets(window_titled("Users"))[0], "the focused column is fully on screen"
    assert_selector ".minimap__col", count: 2

    refresh
    assert_workspace "1"
    assert_selector ".workspace-button", count: 3
    window_titled "Users"
    window_titled "Oleh"
    find(".workspace-button", text: "projects").click
    window_titled "Projects"
  end

  # 4. One command tree, every surface: ⌘K, the terminal, shortcuts and hover
  #    keys drive the same actions, and fuzzy paths reach anything in a word.
  test "every surface runs the same commands, and anything is a few letters away" do
    visit projects_path
    window_titled "Projects"


    type_into_focus [ :alt, "w" ]
    assert_text "Nothing open"

    type_into_focus "`"
    terminal_run "reopen"
    window_titled "Projects"
    terminal_run "uthen"
    assert_selector "html[data-theme=nord]", visible: :all
    type_into_focus :escape

    type_into_focus [ :meta, "k" ]
    type_into_focus "uthed"
    assert_selector ".palette__item[aria-selected=true]", text: "UI › Theme › Default"
    type_into_focus :enter
    # Selecting already previewed Default; a closed palette means the pick ran.
    assert_no_selector "dialog.palette[open]"
    assert_no_selector "html[data-theme]", visible: :all

    type_into_focus "w"
    assert_text "Nothing open"
    type_into_focus :space
    type_into_focus "reopen"
    assert_selector ".palette__item[aria-selected=true]", text: "Reopen closed window"
    type_into_focus :enter
    window_titled "Projects"
  end

  # 5. It holds up: thousands of rows, zoomed in, and it still fits the screen,
  #    reveals what's focused, keeps tables edge to edge and finds records fast.
  test "at volume and zoomed in, it still fits, reveals and finds" do
    Rails.application.load_tasks unless Rake::Task.task_defined?("db:seed:scale")
    with_env(USERS: 50, PROJECTS: 1_500, SERVICES: 50) { capture_io { Rake::Task["db:seed:scale"].invoke } }
    # ⌘K lists the Desk.record_limit most recently updated records per model.
    needle = Project.order(updated_at: :desc).first

    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 1120, height: 720, deviceScaleFactor: 1.25, mobile: false)
    visit projects_path
    projects = window_titled("Projects")
    assert_selector "dialog.win tbody tr", minimum: 1_500

    run_command needle.name, new_window: true
    window_titled needle.name
    assert_equal evaluate_script("innerWidth"), evaluate_script("document.querySelector('.viewport').clientWidth")
    assert_equal 12, window_insets(window_titled(needle.name))[2]

    projects.find(".win__title").click
    body, table = boxes(projects.find(".win__body"), projects.find("table.table"))
    assert_in_delta body["left"], table["left"], 1
    assert_in_delta body["right"], table["right"], 1

    started = Time.current
    type_into_focus [ :meta, "k" ]
    type_into_focus needle.name.split.first(2).join(" ")
    assert_selector ".palette__item", text: needle.name
    assert_operator Time.current - started, :<, 3, "⌘K finds a record among thousands within seconds"
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  private
    def with_env(values)
      previous = values.to_h { |key, _| [ key.to_s, ENV[key.to_s] ] }
      values.each { |key, value| ENV[key.to_s] = value.to_s }
      yield
    ensure
      previous.each { |key, value| ENV[key] = value }
    end
end
