require "test_helper"

class Desk::CommandTest < ActiveSupport::TestCase
  test "lists recent records only for the configured models" do
    with_desk(records: %w[ Project ]) do
      labels = Desk::Command.records.map(&:label)

      assert_includes labels, projects(:desk).name
      assert_not_includes labels, users(:oleh).name
    end
  end

  test "includes app commands from Desk.commands" do
    extra = -> { Desk::Command.new(label: "Deploy", group: "Ops", url: "/deploys") }

    with_desk(commands: [ extra ]) do
      assert_includes Desk::Command.all.map(&:label), "Deploy"
    end
  end

  private
    def with_desk(**settings)
      previous = settings.to_h { |key, _| [ key, Desk.public_send(key) ] }
      settings.each { |key, value| Desk.public_send(:"#{key}=", value) }
      yield
    ensure
      previous.each { |key, value| Desk.public_send(:"#{key}=", value) }
    end
end
