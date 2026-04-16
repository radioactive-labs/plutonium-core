require "bundler/gem_tasks"
require "rake/testtask"
require "standard/rake"

# Load custom rake tasks
Dir.glob("lib/tasks/**/*.rake").each { |r| load r }

task default: %i[test standard]

task :assets do
  `yarn build`
end

# https://stackoverflow.com/questions/15707940/rake-before-task-hook
Rake::Task["build"].enhance ["assets"]

# Unit + integration tests (safe to run together)
Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.test_files = FileList["test/**/*_test.rb"]
    .exclude("test/generators/**/*_test.rb")
    .exclude("test/system/**/*_test.rb")
  t.verbose = true
end

# System tests — require a browser (headless Chrome) and run real Turbo/JS.
Rake::TestTask.new("test:system") do |t|
  t.libs << "test"
  t.test_files = FileList["test/system/**/*_test.rb"]
  t.verbose = true
end

# Generator tests — each file runs in its own process because git checkout
# in teardown corrupts the loaded Rails environment for other test classes.
task :test_generators do
  failures = []

  FileList["test/generators/**/*_test.rb"].sort.each do |test_file|
    puts "\n=== #{test_file} ==="
    unless system(Gem.ruby, "-w", "-Ilib:test", test_file)
      failures << test_file
    end
  end

  if failures.any?
    abort "\nGenerator test failures:\n  #{failures.join("\n  ")}"
  else
    puts "\nAll generator test files passed."
  end
end

# Run both sequentially
task test_all: [:test, :test_generators]

task :check_appraisal do
  unless ENV["BUNDLE_GEMFILE"]&.include?("gemfiles/")
    warn "\n⚠️  Tests should be run through Appraisal for the correct gem environment:"
    warn "   bundle exec appraisal rails-8.1 rake test"
    warn "   bundle exec appraisal rake test  # runs all Rails versions\n\n"
  end
end

Rake::Task["test"].enhance [:check_appraisal]
Rake::Task["test_generators"].enhance [:check_appraisal]
