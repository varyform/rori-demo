# Runs a server-side command (`Rori.command`) picked in ⌘K or the terminal,
# answering with its notification as a turbo stream (rori-notifications#run).
class Rori::Commands::RunsController < ApplicationController
  def create
    runnable = Rori.runnables[params.expect(:name)]
    return head :not_found unless runnable

    notification = run(runnable)
    render turbo_stream: turbo_stream.append("rori-notifications", partial: "rori/notification", locals: { notification: }),
      status: notification.sticky? ? :unprocessable_entity : :ok
  end

  private
    def run(runnable)
      result = runnable.call
      Rori::Notification.new(title: runnable.label, body: result.is_a?(String) ? result : t(".done"), kind: :success)
    rescue => error
      Rails.error.report(error, handled: true)
      # The exception's message may reveal internals; only local environments show it.
      Rori::Notification.new(title: runnable.label, body: Rails.env.local? ? error.message : t(".failed"), kind: :error)
    end
end
