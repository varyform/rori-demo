namespace :demo do
  desc "Empty the app's tables and load the seeds again (the public demo's nightly reset)"
  task replant: :environment do
    DemoResetJob.perform_now
    puts "Replanted: #{User.count} users, #{Project.count} projects, #{Service.count} services"
  end
end
