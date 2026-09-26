# Demo of a slow server-side command (Rori.command :reindex_search): there's
# no search index, so it just takes a while and then notifies every open desk.
class ReindexSearchJob < ApplicationJob
  def perform(seconds = 5)
    sleep seconds
    count = User.count + Project.count + Service.count
    Rori.notify I18n.t("reindex_search.finished"), I18n.t("reindex_search.records", count:), kind: :success
  end
end
