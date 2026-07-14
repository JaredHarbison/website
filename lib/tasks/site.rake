namespace :site do
  desc "Build and validate the static GitHub Pages artifact"
  task build: :environment do
    output_path = StaticSite::Builder.new.build
    StaticSite::Validator.new(output_path: output_path).validate!

    puts "Built and validated #{output_path}"
  end
end
