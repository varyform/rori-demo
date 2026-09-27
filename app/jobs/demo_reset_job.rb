# The public demo's replant: every table in the app's database is emptied and
# the seeds go back in, whatever visitors created, edited or deleted. Nightly
# from config/recurring.yml; by hand with `bin/kamal replant`
# (bin/rails demo:replant).
#
# Not db:seed:replant: that also truncates the queue, cache and cable
# databases (wiping Solid Queue under its own feet) and refuses to run in
# production. This touches only the primary database, in one transaction.
class DemoResetJob < ApplicationJob
  def perform
    ApplicationRecord.with_connection do |connection|
      internal = [ connection.pool.schema_migration.table_name, connection.pool.internal_metadata.table_name ]
      ApplicationRecord.transaction do
        connection.truncate_tables(*(connection.tables - internal))
        Rails.application.load_seed
      end
    end
  end
end
