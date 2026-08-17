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

  # This task DESTROYS uncommitted work under test/dummy — `git checkout --` plus
  # `git clean -fd`, unconditionally, after every file. That is required (see
  # below) but it is not something to discover afterwards, so refuse to start on
  # a dirty tree. Set FORCE=1 to run anyway; CI checkouts are clean and never
  # trip this.
  dirty = `git status --porcelain -- test/dummy`.strip
  if !dirty.empty? && ENV["FORCE"] != "1"
    abort <<~MSG
      test/dummy has uncommitted changes:

      #{dirty.lines.map { |l| "  #{l}" }.join}
      This task git-restores and git-cleans test/dummy between generator test
      files, which would discard them. Commit or stash first, or re-run with
      FORCE=1 to accept the loss.
    MSG
  end

  # Between files, not just inside them. A generator that shells out — e.g.
  # `generate "pu:pkg:package"` — goes through Rails' `generate` action, which
  # passes abort_on_failure: true, so Thor calls `abort` in the test process
  # when the child fails. SystemExit skips minitest's teardown, so anything the
  # test wrote into test/dummy survives; since every generator test file boots
  # the dummy app at require time, one aborted file would take down every file
  # after it. Cleaning here can't be skipped by an aborting child.
  #
  # An at_exit hook inside the tests cannot do this job: minitest runs the whole
  # suite from its own at_exit, and handlers fire LIFO, so a hook registered
  # later runs before any test does.
  restore_dummy_app = lambda do
    system("git", "checkout", "--", "test/dummy", out: File::NULL, err: File::NULL)
    system("git", "clean", "-fd", "test/dummy", out: File::NULL, err: File::NULL)
  end

  FileList["test/generators/**/*_test.rb"].sort.each do |test_file|
    puts "\n=== #{test_file} ==="
    # in: File::NULL — prevents a stray sub-generator prompt from hanging on the inherited TTY.
    unless system(Gem.ruby, "-w", "-Ilib:test", test_file, in: File::NULL)
      failures << test_file
    end
    restore_dummy_app.call
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
