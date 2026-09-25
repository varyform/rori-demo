require "test_helper"

class Desk::KeymapTest < ActiveSupport::TestCase
  teardown { Desk.modifier = "Alt" }

  test "resolves Mod to the configured modifier" do
    assert_equal %w[ Alt+ArrowLeft Alt+KeyH ], Desk.resolved_keymap[:focus_left]

    Desk.modifier = "Meta"
    assert_equal %w[ Meta+Shift+Digit* ], Desk.resolved_keymap[:move_to_workspace]
    assert_equal "⌘", Desk.modifier_symbol
  end

  test "the native shell's user agent gets ⌘, with ⌘C left to Copy" do
    assert_equal "Alt", Desk.modifier_for("Mozilla/5.0 … Safari/605.1.15")
    assert_equal "Meta", Desk.modifier_for("Mozilla/5.0 … (KHTML, like Gecko) DeskApp/0.1")
    assert_equal "Alt", Desk.modifier_for(nil)

    assert_equal %w[ Meta+Shift+KeyC ], Desk.resolved_keymap("Meta")[:center_column]
    assert_equal %w[ Alt+KeyC ], Desk.resolved_keymap("Alt")[:center_column]
  end

  test "rejects unknown modifiers" do
    Desk.modifier = "Hyper"

    assert_raises(ArgumentError) { Desk.resolved_keymap }
  end
end
