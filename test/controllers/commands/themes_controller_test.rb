require "test_helper"

class Commands::ThemesControllerTest < ActionDispatch::IntegrationTest
  test "lists the default and every vendored theme as theme commands" do
    get commands_themes_path, headers: { "Turbo-Frame" => "commands" }

    assert_response :success
    assert_select "turbo-frame#commands li.palette__item[data-desk-action=theme]", count: 1 + Theme.all.size
    assert_select "li[data-param=''][data-current]", text: /Default/
    assert_select "li[data-param=nord]", text: /Nord\s*Dark/
  end

  test "marks the theme from the cookie as current" do
    cookies[ThemeHelper::THEME_COOKIE] = "rose-pine-dawn"
    get commands_themes_path

    assert_select "li[data-current]", count: 1
    assert_select "li[data-param=rose-pine-dawn][data-current]", text: /Light/
  end

  test "the root palette links to the theme list" do
    get commands_path

    assert_select "li[data-children=?]", commands_themes_path, text: /Pick theme/
  end

  test "the page renders the saved theme and ignores unknown ones" do
    cookies[ThemeHelper::THEME_COOKIE] = "nord"
    get root_path
    assert_select "html[data-theme=nord]"

    cookies[ThemeHelper::THEME_COOKIE] = "<script>"
    get root_path
    assert_select "html[data-theme]", count: 0
  end
end
