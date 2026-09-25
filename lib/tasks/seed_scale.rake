# Scale data on top of (or instead of) db:seed, for checking how the desk
# holds up with real volumes: long lists in windows, ⌘K's record search,
# broadcast refreshes on big pages. Bulk inserts (validations and callbacks
# skipped, like fixtures — so no broadcasts fire), then prints the totals.
#
#   bin/rails db:seed:scale                        # 200 users, 2k projects, 300 services
#   USERS=50 PROJECTS=500 SERVICES=100 bin/rails db:seed:scale
#   SEED=42 bin/rails db:seed:scale                # a different, still repeatable world
#
# Development (and its test) only; re-runnable — each run adds on top, with
# unique emails and service names continuing from the current maximum ids.
namespace :db do
  namespace :seed do
    desc "Add scale data (users, projects, services) for checking lists and search at volume"
    task scale: :environment do
      abort "db:seed:scale is for development only" unless Rails.env.local?

      counts = {
        users: Integer(ENV.fetch("USERS", 200)),
        projects: Integer(ENV.fetch("PROJECTS", 2_000)),
        services: Integer(ENV.fetch("SERVICES", 300))
      }
      random = Random.new(Integer(ENV.fetch("SEED", 20_260_925)))
      now = Time.current
      # Spread over three months so "recently updated" ordering has depth.
      stamp = -> { created = now - random.rand(1..90).days; [ created, created + random.rand(0..72).hours ] }
      puts "Scaling: #{counts.map { |kind, count| "#{count} #{kind}" }.join(", ")}"

      first_names = %w[Ada Grace Linus Margaret Ken Barbara Dennis Frances Alan Radia Guido Yukihiro Anders Brendan Sophie Tim]
      last_names = %w[Lovelace Hopper Torvalds Hamilton Thompson Liskov Ritchie Allen Turing Perlman Rossum Matsumoto Hejlsberg Eich Wilson Lee]
      adjectives = %w[quiet rapid amber silent paper static tidy lunar copper hollow brisk plain]
      nouns = %w[harbor ledger engine atlas beacon garden relay compass orchard lantern ferry quarry]
      service_words = %w[api auth billing search mailer worker gateway indexer cache scheduler webhooks reports]

      # --- Users: emails continue from the highest id, so reruns never collide.
      puts "Users…"
      first_user_id = (User.maximum(:id) || 0) + 1
      user_rows = Array.new(counts[:users]) do |i|
        created, updated = stamp.call
        name = "#{first_names.sample(random: random)} #{last_names.sample(random: random)}"
        { name: name, email: "#{name.parameterize}.#{first_user_id + i}@scale.example",
          created_at: created, updated_at: updated }
      end
      user_rows.each_slice(1_000) { |slice| User.insert_all!(slice, record_timestamps: false) }
      # Owners are drawn from everyone, so earlier (seed) users get scale data too.
      user_ids = User.pluck(:id)
      abort "No users to own projects and services" if user_ids.empty?

      # --- Projects: a few prolific owners, a long tail (weighted pick).
      puts "Projects…"
      prolific = user_ids.sample([ user_ids.size / 10, 1 ].max, random: random)
      owner = -> { random.rand < 0.4 ? prolific.sample(random: random) : user_ids.sample(random: random) }
      project_rows = Array.new(counts[:projects]) do |i|
        created, updated = stamp.call
        { name: "#{adjectives.sample(random: random).capitalize} #{nouns.sample(random: random)} #{i + 1}",
          status: Project::STATUSES.sample(random: random), user_id: owner.call,
          description: ("Scale seed project. #{nouns.sample(3, random: random).join(", ").capitalize}." if random.rand < 0.6),
          created_at: created, updated_at: updated }
      end
      project_rows.each_slice(2_000) { |slice| Project.insert_all!(slice, record_timestamps: false) }

      # --- Services: names must stay unique and hostname-safe.
      puts "Services…"
      first_service_id = (Service.maximum(:id) || 0) + 1
      service_rows = Array.new(counts[:services]) do |i|
        created, updated = stamp.call
        word = service_words.sample(random: random)
        env = %w[RAILS_ENV=production LOG_LEVEL=info DATABASE_URL=postgres://db/#{word} REDIS_URL=redis://cache:6379]
        { name: "#{word}-#{first_service_id + i}", user_id: owner.call,
          repository: ("https://github.com/scale/#{word}" if random.rand < 0.8),
          branch: random.rand < 0.8 ? "main" : "feat/#{nouns.sample(random: random)}",
          region: Service::REGIONS.sample(random: random), size: Service::SIZES.sample(random: random),
          replicas: random.rand(1..6), autoscale: random.rand < 0.3,
          health_check_path: random.rand < 0.8 ? "/up" : "/health",
          environment: env.sample(random.rand(0..env.size), random: random).map { "#{it}\n" }.join.presence,
          notes: ("Scale seed service." if random.rand < 0.2),
          created_at: created, updated_at: updated }
      end
      service_rows.each_slice(1_000) { |slice| Service.insert_all!(slice, record_timestamps: false) }

      puts "Now: #{User.count} users, #{Project.count} projects, #{Service.count} services"
    end
  end
end
