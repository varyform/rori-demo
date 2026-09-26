require "test_helper"

class Rori::KeymapTest < ActiveSupport::TestCase
  teardown { Rori.modifier = "Alt" }

  test "resolves Mod to the configured modifier" do
    assert_equal %w[ Alt+ArrowLeft Alt+KeyH ], Rori.resolved_keymap[:focus_left]

    Rori.modifier = "Meta"
    assert_equal %w[ Meta+Shift+Digit* ], Rori.resolved_keymap[:move_to_workspace]
    assert_equal "⌘", Rori.modifier_symbol
  end

  test "the native shell's user agent gets ⌘, with ⌘C left to Copy" do
    assert_equal "Alt", Rori.modifier_for("Mozilla/5.0 … Safari/605.1.15")
    assert_equal "Meta", Rori.modifier_for("Mozilla/5.0 … (KHTML, like Gecko) DeskApp/0.1")
    assert_equal "Alt", Rori.modifier_for(nil)

    assert_equal %w[ Meta+Shift+KeyC ], Rori.resolved_keymap("Meta")[:center_column]
    assert_equal %w[ Alt+KeyC ], Rori.resolved_keymap("Alt")[:center_column]
  end

  test "rejects unknown modifiers" do
    Rori.modifier = "Hyper"

    assert_raises(ArgumentError) { Rori.resolved_keymap }
  end
end
