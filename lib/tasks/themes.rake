namespace :themes do
  desc "Compile vendor/themes/ghostty into app/assets/stylesheets/themes.css"
  task build: :environment do
    Theme::STYLESHEET.write(Theme.stylesheet)
    puts "Wrote #{Theme.all.size} themes to #{Theme::STYLESHEET.relative_path_from(Rails.root)}"
  end
end
