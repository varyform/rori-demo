require "test_helper"

# The engine's own suite covers the palette in general; this checks what the
# demo configures in config/initializers/rori.rb.
class Rori::CommandsControllerTest < ActionDispatch::IntegrationTest
  test "the palette lists the demo's pages, records and server-side command" do
    get rori_commands_path, headers: { "Turbo-Frame" => "commands" }

    assert_response :success
    assert_select "turbo-frame#commands li.rori-palette__item[data-url=?]", new_user_path, text: /New user/
    assert_select "li.rori-palette__item[data-url=?]", user_path(users(:ada)), text: /Ada Lovelace/
    assert_select "li.rori-palette__item[data-url=?]", project_path(projects(:desk)), text: /#{projects(:desk).name}/
    assert_select "li.rori-palette__item[data-run=reindex_search][data-confirm]", text: /Reindex search/
  end

  test "the Tauri shell's user agent (src-tauri/tauri.conf.json) gets ⌘ shortcuts" do
    get rori_commands_path, headers: { "User-Agent" => "Mozilla/5.0 (Macintosh) AppleWebKit/605.1.15 (KHTML, like Gecko) DeskApp/0.1" }

    assert_select "li[data-rori-action=close_window] kbd", text: "⌘W"
  end
end
