namespace :desk do
  namespace :themes do
    desc "Compile Desk.themes_directory (Ghostty themes) into Desk.themes_stylesheet"
    task build: :environment do
      Desk.themes_stylesheet.write(Desk::Theme.stylesheet)
      puts "Wrote #{Desk::Theme.all.size} themes to #{Desk.themes_stylesheet.relative_path_from(Rails.root)}"
    end
  end
end
