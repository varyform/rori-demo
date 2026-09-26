require "test_helper"

class Rori::Commands::RunsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  include ActionCable::TestHelper

  test "runs the command and answers with its notification" do
    assert_enqueued_with job: ReindexSearchJob do
      post rori_commands_runs_path, params: { name: "reindex_search" }, as: :turbo_stream
    end

    assert_response :success
    assert_select "turbo-stream[action=append][target=rori-notifications] template" do
      assert_select ".rori-notification--success[role=status]"
      assert_select ".rori-notification__title", "Reindex search"
      assert_select ".rori-notification__body", /Reindexing in the background/
    end
  end

  test "a failing command answers with a sticky error notification" do
    with_runnable(:explode, -> { raise "boom" }) do
      post rori_commands_runs_path, params: { name: "explode" }, as: :turbo_stream
    end

    assert_response :unprocessable_entity
    assert_select ".rori-notification--error.rori-notification--sticky[role=alert] .rori-notification__body", "boom"
  end

  test "a command without a message reports Done" do
    with_runnable(:quiet, -> { 42 }) do
      post rori_commands_runs_path, params: { name: "quiet" }, as: :turbo_stream
    end

    assert_select ".rori-notification__body", "Done"
  end

  test "unknown commands are not found" do
    post rori_commands_runs_path, params: { name: "nope" }, as: :turbo_stream

    assert_response :not_found
  end

  test "the job notifies every open desk when it's done" do
    assert_broadcasts Rori.notifications_stream, 1 do
      ReindexSearchJob.perform_now(0)
    end
  end

  private
    def with_runnable(name, block)
      I18n.backend.store_translations(:en, rori: { commands: { custom: { name => name.to_s.humanize } } })
      Rori.command(name, &block)
      yield
    ensure
      Rori.runnables.delete(name.to_s)
    end
end
