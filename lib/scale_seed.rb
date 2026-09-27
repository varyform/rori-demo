# Scale data on top of the seeds, for checking how the desk holds up with real
# volumes: long lists in windows, ⌘K's record search, broadcast refreshes on
# big pages. Bulk inserts (validations and callbacks skipped, like fixtures —
# so no broadcasts fire). Re-runnable: each run adds on top, with unique
# emails and service names continuing from the current maximum ids. The same
# `seed` always grows the same world.
#
# Used by `bin/rails db:seed:scale` (development) and the public demo's
# replant (DemoResetJob).
class ScaleSeed
  COUNTS = { users: 50, projects: 200, services: 100 }.freeze
  SEED = 20_260_925

  FIRST_NAMES = %w[Ada Grace Linus Margaret Ken Barbara Dennis Frances Alan Radia Guido Yukihiro Anders Brendan Sophie Tim].freeze
  LAST_NAMES = %w[Lovelace Hopper Torvalds Hamilton Thompson Liskov Ritchie Allen Turing Perlman Rossum Matsumoto Hejlsberg Eich Wilson Lee].freeze
  ADJECTIVES = %w[quiet rapid amber silent paper static tidy lunar copper hollow brisk plain].freeze
  NOUNS = %w[harbor ledger engine atlas beacon garden relay compass orchard lantern ferry quarry].freeze
  SERVICE_WORDS = %w[api auth billing search mailer worker gateway indexer cache scheduler webhooks reports].freeze

  def self.plant(...) = new(...).plant

  # `log` gets a line per stage (e.g. method(:puts)); silent by default.
  def initialize(users: COUNTS[:users], projects: COUNTS[:projects], services: COUNTS[:services], seed: SEED, log: nil)
    @counts = { users:, projects:, services: }
    @random = Random.new(seed)
    @log = log || ->(_) { }
    @now = Time.current
  end

  def plant
    @log.("Scaling: #{@counts.map { |kind, count| "#{count} #{kind}" }.join(", ")}")
    plant_users
    plant_projects
    plant_services
  end

  private
    # Spread over three months so "recently updated" ordering has depth.
    def stamp
      created = @now - @random.rand(1..90).days
      [ created, created + @random.rand(0..72).hours ]
    end

    def pick(list, count = nil) = count ? list.sample(count, random: @random) : list.sample(random: @random)

    # Emails continue from the highest id, so reruns never collide.
    def plant_users
      @log.("Users…")
      first_id = (User.maximum(:id) || 0) + 1
      rows = Array.new(@counts[:users]) do |i|
        created, updated = stamp
        name = "#{pick(FIRST_NAMES)} #{pick(LAST_NAMES)}"
        { name:, email: "#{name.parameterize}.#{first_id + i}@scale.example", created_at: created, updated_at: updated }
      end
      rows.each_slice(1_000) { User.insert_all!(it, record_timestamps: false) }

      # Owners are drawn from everyone, so earlier (seed) users get scale data too.
      user_ids = User.pluck(:id)
      raise ArgumentError, "no users to own projects and services" if user_ids.empty?
      prolific = user_ids.sample([ user_ids.size / 10, 1 ].max, random: @random)
      # A few prolific owners, a long tail (weighted pick).
      @owner = -> { @random.rand < 0.4 ? pick(prolific) : pick(user_ids) }
    end

    def plant_projects
      @log.("Projects…")
      rows = Array.new(@counts[:projects]) do |i|
        created, updated = stamp
        { name: "#{pick(ADJECTIVES).capitalize} #{pick(NOUNS)} #{i + 1}",
          status: pick(Project::STATUSES), user_id: @owner.(),
          description: ("Scale seed project. #{pick(NOUNS, 3).join(", ").capitalize}." if @random.rand < 0.6),
          created_at: created, updated_at: updated }
      end
      rows.each_slice(2_000) { Project.insert_all!(it, record_timestamps: false) }
    end

    # Names must stay unique and hostname-safe.
    def plant_services
      @log.("Services…")
      first_id = (Service.maximum(:id) || 0) + 1
      rows = Array.new(@counts[:services]) do |i|
        created, updated = stamp
        word = pick(SERVICE_WORDS)
        env = %W[RAILS_ENV=production LOG_LEVEL=info DATABASE_URL=postgres://db/#{word} REDIS_URL=redis://cache:6379]
        { name: "#{word}-#{first_id + i}", user_id: @owner.(),
          repository: ("https://github.com/scale/#{word}" if @random.rand < 0.8),
          branch: @random.rand < 0.8 ? "main" : "feat/#{pick(NOUNS)}",
          region: pick(Service::REGIONS), size: pick(Service::SIZES),
          replicas: @random.rand(1..6), autoscale: @random.rand < 0.3,
          health_check_path: @random.rand < 0.8 ? "/up" : "/health",
          environment: pick(env, @random.rand(0..env.size)).map { "#{it}\n" }.join.presence,
          notes: ("Scale seed service." if @random.rand < 0.2),
          created_at: created, updated_at: updated }
      end
      rows.each_slice(1_000) { Service.insert_all!(it, record_timestamps: false) }
    end
end
