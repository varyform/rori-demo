require "test_helper"

class Desk::Commands::ThemesControllerTest < ActionDispatch::IntegrationTest
  test "lists the default and every vendored theme as theme commands" do
    get desk_commands_themes_path, headers: { "Turbo-Frame" => "commands" }

    assert_response :success
    assert_select "turbo-frame#commands li.palette__item[data-desk-action=theme]", count: 1 + Desk::Theme.all.size
    assert_select "li[data-param=''][data-current]", text: /Default/
    assert_select "li[data-param=nord]", text: /Nord\s*Dark/
  end

  test "marks the theme from the cookie as current" do
    cookies[Desk.theme_cookie] = "rose-pine-dawn"
    get desk_commands_themes_path

    assert_select "li[data-current]", count: 1
    assert_select "li[data-param=rose-pine-dawn][data-current]", text: /Light/
  end

  test "the root palette links to the theme list" do
    get desk_commands_path

    assert_select "li[data-children=?]", desk_commands_themes_path, text: /Pick theme/
  end

  test "the page renders the saved theme and ignores unknown ones" do
    cookies[Desk.theme_cookie] = "nord"
    get root_path
    assert_select "html[data-theme=nord]"

    cookies[Desk.theme_cookie] = "<script>"
    get root_path
    assert_select "html[data-theme]", count: 0
  end
end
