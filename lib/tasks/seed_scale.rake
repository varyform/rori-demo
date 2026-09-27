# Scale data on top of (or instead of) db:seed (see ScaleSeed), then prints
# the totals.
#
#   bin/rails db:seed:scale                        # 50 users, 200 projects, 100 services
#   USERS=200 PROJECTS=2000 SERVICES=300 bin/rails db:seed:scale
#   SEED=42 bin/rails db:seed:scale                # a different, still repeatable world
#
# Development (and its test) only; the public demo gets its scale data from
# the replant (DemoResetJob, bin/kamal replant).
namespace :db do
  namespace :seed do
    desc "Add scale data (users, projects, services) for checking lists and search at volume"
    task scale: :environment do
      abort "db:seed:scale is for development only" unless Rails.env.local?

      ScaleSeed.plant(
        users: Integer(ENV.fetch("USERS", ScaleSeed::COUNTS[:users])),
        projects: Integer(ENV.fetch("PROJECTS", ScaleSeed::COUNTS[:projects])),
        services: Integer(ENV.fetch("SERVICES", ScaleSeed::COUNTS[:services])),
        seed: Integer(ENV.fetch("SEED", ScaleSeed::SEED)),
        log: method(:puts))
      puts "Now: #{User.count} users, #{Project.count} projects, #{Service.count} services"
    end
  end
end
