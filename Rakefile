require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "standard/rake"

task default: %i[spec standard]

task :assets do
  puts "assets >>>>>>>"
  `npm run js:prod`
end

Rake::Task["release"].enhance [Rake::Task["assets"]] do
  puts "after >>>>>>>>"
end
