require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "standard/rake"

task default: %i[spec standard]

task :assets do
  puts ">>>>>>>"
  `npm run js:prod`
end

Rake::Task["release"].enhance do
  puts "%^%@#^&*&^&*&}"
  Rake::Task["assets"].execute
end
