require "test_helper"

class Desk::KeymapTest < ActiveSupport::TestCase
  teardown { Desk.modifier = "Alt" }

  test "resolves Mod to the configured modifier" do
    assert_equal %w[ Alt+ArrowLeft Alt+KeyH ], Desk.resolved_keymap[:focus_left]

    Desk.modifier = "Meta"
    assert_equal %w[ Meta+Shift+Digit* ], Desk.resolved_keymap[:move_to_workspace]
    assert_equal "⌘", Desk.modifier_symbol
  end

  test "rejects unknown modifiers" do
    Desk.modifier = "Hyper"

    assert_raises(ArgumentError) { Desk.resolved_keymap }
  end
end
