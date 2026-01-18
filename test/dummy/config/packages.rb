Dir.glob(File.expand_path("../packages/**/lib/engine.rb", __dir__)) { |package| load package }
