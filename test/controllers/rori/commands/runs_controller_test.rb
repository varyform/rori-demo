require "test_helper"

# The engine's own suite covers running commands in general; this checks the
# demo's reindex_search wiring (initializer, locale, job).
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

  test "the job notifies every open desk when it's done" do
    assert_broadcasts Rori.notifications_stream, 1 do
      ReindexSearchJob.perform_now(0)
    end
  end
end
