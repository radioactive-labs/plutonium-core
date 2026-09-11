# frozen_string_literal: true

require "test_helper"
require "rails/generators"
require "rails/generators/test_case"
require "generators/pu/gem/dotenv/dotenv_generator"
require "shellwords"

# Test-only subclass that disables shelling out to `bundle install`, which the
# real generator invokes via `bundle!`. Keeping `bundle!` protected preserves
# Thor::Group's behavior of *not* invoking it as a generator step.
#
# `source_root` is re-declared because Thor stores it in a class-instance
# variable (`@source_root`) that subclasses do NOT inherit — without this, the
# generator cannot locate its templates and `copy_file` fails.
class TestableDotenvGenerator < Pu::Gem::DotenvGenerator
  source_root Pu::Gem::DotenvGenerator.source_root

  protected

  def bundle!
    # no-op: avoid running `bundle install` during tests
  end
end

# Static / structural assertions that lock down the generator's source and
# templates. These act as a fast regression guard for the `.env.test.local`
# unignore bug (commit 666a0c1d).
class DotenvGeneratorSourceTest < ActiveSupport::TestCase
  GENERATOR_PATH = File.expand_path(
    "../../lib/generators/pu/gem/dotenv/dotenv_generator.rb", __dir__
  )

  def setup
    @source = File.read(GENERATOR_PATH)
  end

  test "dotenv generator exists and has correct namespace" do
    assert defined?(Pu::Gem::DotenvGenerator)
    assert Pu::Gem::DotenvGenerator < Rails::Generators::Base
  end

  test "dotenv generator includes PlutoniumGenerators::Generator" do
    assert Pu::Gem::DotenvGenerator.include?(PlutoniumGenerators::Generator)
  end

  test "dotenv generator has source_root set" do
    assert Pu::Gem::DotenvGenerator.source_root.present?
    assert File.directory?(Pu::Gem::DotenvGenerator.source_root)
  end

  test "gitignore call does not unignore .env.test.local (secrets file)" do
    # The bug (commit 666a0c1d) added "!/.env.test.local" to the gitignore
    # directive, overriding Rails' default "/.env*" and making test secrets
    # trackable. This assertion fails if that negation is reintroduced.
    refute_match(/!\/\.env\.test\.local/, @source,
      ".env.test.local must stay ignored by Rails' default /.env* — never negated in gitignore")
  end

  test "gitignore call still unignores the safe, non-secret files" do
    assert_match(/!\/\.env["'\s]/, @source, "shared .env (no secrets) must be unignored")
    assert_match(/!\/\.env\.template/, @source, ".env.template must be unignored")
    assert_match(/!\/\.env\.local\.template/, @source, ".env.local.template must be unignored")
  end

  test "generator still copies .env.test.local (so it exists locally but stays ignored)" do
    assert_match(/"\.env\.test\.local"/, @source,
      "the generator should still copy .env.test.local — it just must not unignore it")
  end
end

# Template-content assertions. The `.env.test.local` template explicitly
# instructs users to add secrets, which is why it must remain git-ignored.
class DotenvTemplateTest < ActiveSupport::TestCase
  TEMPLATES_DIR = File.expand_path(
    "../../lib/generators/pu/gem/dotenv/templates", __dir__
  )

  test "all expected template files exist" do
    %w[.env .env.local .env.template .env.local.template .env.test.local].each do |f|
      assert File.exist?(File.join(TEMPLATES_DIR, f)), "missing template: #{f}"
    end
  end

  test ".env.test.local template indicates it holds secrets" do
    content = File.read(File.join(TEMPLATES_DIR, ".env.test.local"))
    assert_match(/Secrets for testing/i, content,
      "the test-local template must clearly indicate it stores secrets (hence must be ignored)")
  end

  test ".env.local template indicates it holds secrets" do
    content = File.read(File.join(TEMPLATES_DIR, ".env.local"))
    assert_match(/Secrets for development/i, content)
  end

  test "shared .env template warns NOT to put secrets there" do
    content = File.read(File.join(TEMPLATES_DIR, ".env.template"))
    assert_match(/Secrets should NOT be added here/i, content)
  end

  test ".env.local.template does not direct users to add real secrets" do
    content = File.read(File.join(TEMPLATES_DIR, ".env.local.template"))
    refute_match(/add real secrets here/i, content)
    assert_match(/Secrets for development should be added here/i, content)
  end
end

# Behavioral test: actually run the generator against a freshly seeded
# Rails-style project in a temp dir (with a real git repo) and verify the
# resulting `.gitignore` + `git check-ignore` behavior end to end.
class DotenvGeneratorBehaviorTest < Rails::Generators::TestCase
  tests TestableDotenvGenerator
  destination File.expand_path("../../tmp/pu_gem_dotenv", __dir__)
  setup :prepare_destination

  # Seed a minimal Rails-style project skeleton: a Rails default `.gitignore`
  # (which ignores `/.env*`), a Gemfile anchored on the rails gem, and a real
  # git repo so we can evaluate ignore rules via `git check-ignore`.
  setup do
    File.write(File.join(destination_root, ".gitignore"), "/.env*\n")
    File.write(File.join(destination_root, "Gemfile"), %(gem "rails", "~> 8.1"\n))
    Dir.chdir(destination_root) do
      raise "git init failed" unless system("git init -q", out: File::NULL, err: File::NULL)
      system("git config user.email test@example.com", out: File::NULL, err: File::NULL)
      system("git config user.name Test", out: File::NULL, err: File::NULL)
    end
  end

  # `git check-ignore <path>` (no -v): exit 0 => path IS ignored, exit 1 =>
  # path is trackable (not ignored). Note: with `-v`, exit 0 merely means a
  # pattern matched — including negations — so it does NOT reflect ignore
  # status; we use `-v` only to inspect the deciding pattern (see #ignore_match).
  def ignored?(path)
    Dir.chdir(destination_root) { `git check-ignore #{Shellwords.escape(path)}` }
    $?.success?  # true => ignored
  end

  # Verbose output for `path`, e.g. ".gitignore:1:/.env*\t.env.test.local".
  # The printed pattern is the LAST (deciding) match; if it starts with `!`
  # the path is un-ignored, otherwise it is ignored.
  def ignore_match(path)
    Dir.chdir(destination_root) { `git check-ignore -v #{Shellwords.escape(path)}` }
  end

  test "creates all dotenv files and the required-env initializer" do
    run_generator
    %w[.env .env.local .env.template .env.local.template .env.test.local].each do |f|
      assert_file f
    end
    assert_file "config/initializers/001_ensure_required_env.rb"
  end

  test "adds the dotenv gem to the Gemfile" do
    run_generator
    gemfile = File.read(File.join(destination_root, "Gemfile"))
    assert_match(/gem ["']dotenv["'], groups: %i\[development test\]/, gemfile)
    assert_match(/gem ["']rails["']/, gemfile)
  end

  test ".gitignore does not contain a negation for .env.test.local" do
    run_generator
    gitignore = File.read(File.join(destination_root, ".gitignore"))
    refute_match(/!\/\.env\.test\.local/, gitignore,
      ".env.test.local must not be unignored (it holds test secrets)")
  end

  test ".gitignore unignores only the safe non-secret files" do
    run_generator
    gitignore = File.read(File.join(destination_root, ".gitignore"))
    assert_match(/^!\/\.env$/, gitignore)
    assert_match(/^!\/\.env\.template$/, gitignore)
    assert_match(/^!\/\.env\.local\.template$/, gitignore)
    # Secret files must NOT be negated
    refute_match(/!\/\.env\.local$/, gitignore)
    refute_match(/!\/\.env\.test\.local$/, gitignore)
  end

  test ".env.test.local is ignored by git (secret file stays untracked)" do
    run_generator
    assert ignored?(".env.test.local"),
      ".env.test.local must be ignored by git (Rails' /.env* must win)"
  end

  test ".env.local is ignored by git (dev secret file stays untracked)" do
    run_generator
    assert ignored?(".env.local"), ".env.local must be ignored by git"
  end

  test ".env, .env.template and .env.local.template are trackable (not ignored)" do
    run_generator
    %w[.env .env.template .env.local.template].each do |f|
      refute ignored?(f), "#{f} should be trackable (unignored by the generator)"
    end
  end

  test "git check-ignore -v shows Rails' /.env* deciding .env.test.local (not a negation)" do
    run_generator
    output = ignore_match(".env.test.local")
    assert_match(/\/\.env\*/, output,
      "the deciding pattern should be the non-negated /.env*")
    refute_match(/!\/\.env\.test\.local/, output,
      "no negation for .env.test.local should be present")
  end

  test "real secrets placed in .env.test.local cannot be git-added" do
    run_generator
    secret_file = File.join(destination_root, ".env.test.local")
    File.write(secret_file, "SECRET_KEY=supersecret123\n")
    Dir.chdir(destination_root) do
      # `git add` of an ignored file is refused unless --force is used.
      add_succeeded = system("git add .env.test.local", out: File::NULL, err: File::NULL)
      refute add_succeeded,
        "git add of .env.test.local should be refused because it is git-ignored"
    end
  end

  test "generator is idempotent (no duplicate gitignore directives on re-run)" do
    run_generator
    run_generator
    gitignore = File.read(File.join(destination_root, ".gitignore"))
    assert_equal 1, gitignore.scan(/^!\/\.env$/).size
    assert_equal 1, gitignore.scan(/^!\/\.env\.template$/).size
    assert_equal 1, gitignore.scan(/^!\/\.env\.local\.template$/).size
    assert_equal 0, gitignore.scan("!/.env.test.local").size
  end
end
