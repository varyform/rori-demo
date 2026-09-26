require "application_system_test_case"

# Renders the gem README's media into ../rori/docs: still screenshots and an
# animated tour. Not a test and not part of CI — a scripted browser session
# that happens to use the system-test harness (server, headless Chrome, a
# throwaway database). Needs network for the Unsplash wallpaper, and cwebp,
# img2webp and ImageMagick (brew install webp imagemagick).
#
#   bin/rails test script/readme_media.rb                   # everything
#   bin/rails test script/readme_media.rb -n test_animation  # just the tour
#   KEEP_FRAMES=1 …                                          # keep tmp/readme_frames
class ReadmeMedia < ApplicationSystemTestCase
  DOCS = Rails.root.join("../rori/docs")
  WALLPAPER = "1464822759023-fed622ff2c3b"
  CAST = {
    "Grace Hopper" => [ [ "COBOL compiler", "done" ], [ "Nanoseconds talk", "active" ] ],
    "Linus Torvalds" => [ [ "Kernel", "active" ], [ "Git", "done" ] ],
    "Margaret Hamilton" => [ [ "Apollo guidance", "done" ] ],
    "Ken Thompson" => [ [ "Unix", "done" ], [ "Go", "active" ] ],
    "Barbara Liskov" => [ [ "CLU", "done" ] ],
    "Dennis Ritchie" => [ [ "C compiler", "done" ] ],
    "Frances Allen" => [ [ "Optimizing compiler", "paused" ] ],
    "Alan Turing" => [ [ "Bombe", "done" ], [ "Morphogenesis", "idea" ] ],
    "Radia Perlman" => [ [ "Spanning tree", "done" ] ],
    "Guido van Rossum" => [ [ "Python", "active" ] ],
    "Yukihiro Matsumoto" => [ [ "Ruby", "active" ], [ "mruby", "paused" ] ],
    "Sophie Wilson" => [ [ "ARM", "done" ] ],
    "Tim Berners-Lee" => [ [ "World Wide Web", "done" ], [ "Solid", "idea" ] ]
  }

  driven_by :selenium, using: :headless_chrome, screen_size: [ 1440, 1043 ] do |options| # a 1440×900 viewport
    options.add_argument("--force-device-scale-factor=2")
    options.add_argument("--hide-scrollbars")
  end

  setup do
    Rails.application.load_seed
    CAST.each do |name, projects|
      user = User.create!(name:, email: "#{name.split.first.downcase}@example.com")
      projects.each { |title, status| user.projects.create!(name: title, status:) }
    end
    ada = User.find_by!(email: "ada@example.com")
    ada.projects.create!(name: "Note G", status: "active")
    ada.projects.create!(name: "Difference Engine", status: "paused")
    Rori.wallpapers = true
    FileUtils.mkdir_p(DOCS.join("screenshots"))

    visit "/up"
    { wallpaper_pin: WALLPAPER, theme: "catppuccin-mocha", wallpaper: "cover" }.each do |name, value|
      page.driver.browser.manage.add_cookie(name: name.to_s, value:)
    end
  end

  teardown { Rori.wallpapers = false }

  test "screenshots" do
    build_desk
    shot "desk"

    open_palette "uthen"
    shot "palette"
    find(".rori-palette__input").send_keys :escape

    type_into_focus "`"
    terminal_run "help"
    terminal_run "ui wallpaper cover"
    terminal_run "reindex"
    terminal_run "y"
    assert_selector ".rori-notification--success"
    find(".rori-terminal__input").set("new u")
    sleep 0.4
    shot "terminal"
    find(".rori-terminal__input").send_keys :escape
    execute_script("document.querySelectorAll('.rori-notification').forEach((n) => n.remove())")

    run_command "dashboard", new_window: true
    assert_selector "dialog.rori-win[open]", text: "Dashboard"
    type_into_focus [ :alt, "o" ]
    shot "overview"
    type_into_focus [ :alt, "o" ]
    type_into_focus [ :alt, "1" ]

    run_command "rose pine dawn"
    settle
    shot "theme-light"
    run_command "catppuccin mocha"

    find(".rori-menubar__shortcuts").click
    assert_selector "dialog.rori-shortcuts[open]"
    shot "shortcuts"
    find("dialog.rori-shortcuts").send_keys :escape

    focus_title "api-gateway"
    within(window_titled("api-gateway")) { click_on "Edit" }
    window_titled "Edit api-gateway"
    type_into_focus :escape # out of the autofocused field, or ⌥R types ®
    set_width "Edit api-gateway", 2 / 3r
    find("#service_name").click
    find("dialog.rori-win .rori-win__title", exact_text: "Ada Lovelace").hover
    assert_selector ".rori-win.is-armed"
    shot "hover-keys"
  end

  # A storyboard more than a screen recording: a frame per step (plus a few
  # mid-transition ones), each held for as long as it needs to be read.
  test "animation" do
    @frames = []
    visit root_path
    assert_text "Nothing open"
    frame 1600

    palette_typing "users"
    find(".rori-palette__input").send_keys :enter
    frames_while_moving
    window_titled "Users"
    frame 1000

    [ "ada lovelace", "api-gateway" ].each do |query|
      palette_typing query
      find(".rori-palette__input").send_keys [ :shift, :enter ]
      frames_while_moving
      frame 900
    end

    2.times do
      type_into_focus [ :alt, :left ]
      frames_while_moving
      frame 700
    end

    type_into_focus [ :alt, "o" ]
    frames_while_moving
    frame 1600
    type_into_focus [ :alt, "o" ]
    frames_while_moving
    frame 600

    type_into_focus "`"
    frames_while_moving(2)
    "ui theme rose dawn".each_char { |char| find(".rori-terminal__input").send_keys(char); frame 70 }
    frame 600
    find(".rori-terminal__input").send_keys :enter
    frame 1200
    find(".rori-terminal__input").send_keys :escape
    frames_while_moving(2)
    frame 2400

    render_animation "demo"
  end

  private
    # Workspace 1: users (two stacked in one column) and a service running off
    # the right edge; the projects open into their own workspace.
    def build_desk
      visit users_path
      window_titled "Users"
      run_command "oleh", new_window: true
      window_titled "Oleh"
      run_command "ada lovelace", new_window: true
      window_titled "Ada Lovelace"
      type_into_focus [ :alt, "[" ]
      run_command "api-gateway", new_window: true
      window_titled "api-gateway"
      run_command "projects", new_window: true
      window_titled "Projects"
      run_command "desk ui", new_window: true
      window_titled "Desk UI"
      type_into_focus [ :alt, "1" ]
      set_width "Users", 1 / 3r
      set_width "Ada Lovelace", 1 / 3r
      set_width "api-gateway", 1 / 2r
      focus_title "Ada Lovelace"
      type_into_focus [ :alt, "c" ]
      settle
    end

    # Cycles the window's column width (⌥R) until it's `width` of the viewport.
    def set_width(title, width)
      focus_title title
      3.times do
        current = evaluate_script("Number(document.querySelector('.rori-win.is-focused').closest('.rori-col').dataset.w)")
        break if (current - width).abs < 0.01
        type_into_focus [ :alt, "r" ]
        sleep 0.3
      end
    end

    # Walks focus along the strip (⌥←/⌥→), since off-screen windows can't be
    # clicked; a window stacked in the reached column is then clicked.
    def focus_title(title)
      focused = -> { evaluate_script("document.querySelector('.rori-win.is-focused .rori-win__title')?.textContent") }
      in_column = -> { evaluate_script("[...document.querySelector('.rori-win.is-focused').closest('.rori-col').querySelectorAll('.rori-win__title')].some((t) => t.textContent === #{title.to_json})") }
      8.times { break if in_column.(); type_into_focus [ :alt, :left ]; sleep 0.2 }
      12.times { break if in_column.(); type_into_focus [ :alt, :right ]; sleep 0.2 }
      find("dialog.rori-win .rori-win__title", exact_text: title).click unless focused.() == title
      assert_equal title, focused.()
    end

    def open_palette(query)
      find("body").send_keys [ :meta, "k" ]
      find(".rori-palette__input").set(query)
      assert_selector ".rori-palette__item[aria-selected=true]"
      sleep 0.5
    end

    def palette_typing(query)
      find("body").send_keys [ :meta, "k" ]
      assert_selector "dialog.rori-palette[open]"
      frame 300
      query.each_char { |char| find(".rori-palette__input").send_keys(char); frame 70 }
      assert_selector ".rori-palette__item[aria-selected=true]"
      sleep 0.3
      frame 700
    end

    def settle
      execute_script("document.activeElement?.blur()")
      sleep 0.8
    end

    def shot(name)
      sleep 0.6 # transitions
      png = DOCS.join("screenshots/#{name}.png")
      page.save_screenshot(png)
      webp(png, DOCS.join("screenshots/#{name}.webp"))
    end

    # Frames grabbed back to back while a transition runs (a grab takes about as
    # long as a 60 fps frame times ten, so these are a few in-between states).
    def frames_while_moving(count = 3)
      count.times { frame 90 }
      sleep 0.3
    end

    def frame(duration)
      path = Rails.root.join("tmp/readme_frames/#{format("%03d", @frames.size)}.png")
      FileUtils.mkdir_p(path.dirname)
      page.save_screenshot(path)
      @frames << [ path, duration ]
    end

    # Half size (the README shows it at ~900px), lossy, looping.
    def render_animation(name)
      @frames.each { |path, _| system("magick", path.to_s, "-resize", "50%", path.to_s, exception: true) }
      args = @frames.flat_map { |path, duration| [ "-d", duration.to_s, path.to_s ] }
      out = DOCS.join("#{name}.webp")
      system("img2webp", "-loop", "0", "-lossy", "-q", "80", "-m", "6", *args, "-o", out.to_s, exception: true)
      FileUtils.rm_rf(Rails.root.join("tmp/readme_frames")) unless ENV["KEEP_FRAMES"]
      puts "#{name}.webp: #{@frames.size} frames, #{File.size(out) / 1024} KB"
    end

    def webp(png, out)
      system("cwebp", "-quiet", "-q", "88", png.to_s, "-o", out.to_s, exception: true)
      FileUtils.rm(png)
      puts "#{out.basename}: #{File.size(out) / 1024} KB"
    end
end
