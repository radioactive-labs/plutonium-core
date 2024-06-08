require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "standard/rake"

task default: %i[spec standard]

task :assets do
  `npm run build`
end

# https://stackoverflow.com/questions/15707940/rake-before-task-hook
Rake::Task["build"].enhance ["assets"]
