# A notification in the desk's corner (rori/_notification): the result of a
# server-side command, or anything the app sends with `Rori.notify`.
# Errors stay until dismissed; the rest fade out on their own.
class Rori::Notification < Data.define(:title, :body, :kind)
  KINDS = %i[ info success error ].freeze

  def initialize(title:, body: nil, kind: :info)
    kind = kind.to_sym
    raise ArgumentError, "notification kind must be one of #{KINDS.join(", ")}" unless KINDS.include?(kind)

    super
  end

  def sticky? = kind == :error

  def broadcast
    Turbo::StreamsChannel.broadcast_append_to Rori.notifications_stream,
      target: "rori-notifications", partial: "rori/notification", locals: { notification: self }
  end
end
