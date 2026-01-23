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

# https://juincc.medium.com/how-to-setup-minitest-for-your-gems-development-f29c4bee13c2
Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList["test/**/*_test.rb"]
  t.verbose = true
end

# Warn users to run tests through Appraisal
Rake::Task["test"].enhance do
  # This runs after test completes successfully - no action needed
end

task :check_appraisal do
  unless ENV["BUNDLE_GEMFILE"]&.include?("gemfiles/")
    warn "\n⚠️  Tests should be run through Appraisal for the correct gem environment:"
    warn "   bundle exec appraisal rails-8.1 rake test"
    warn "   bundle exec appraisal rake test  # runs all Rails versions\n\n"
  end
end

Rake::Task["test"].enhance [:check_appraisal]
