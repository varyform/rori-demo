namespace :rori do
  namespace :themes do
    desc "Compile Rori.themes_directory (Ghostty themes) into Rori.themes_stylesheet"
    task build: :environment do
      Rori.themes_stylesheet.write(Rori::Theme.stylesheet)
      puts "Wrote #{Rori::Theme.all.size} themes to #{Rori.themes_stylesheet.relative_path_from(Rails.root)}"
    end
  end
end
