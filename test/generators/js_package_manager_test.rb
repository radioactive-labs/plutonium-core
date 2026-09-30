# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "rails/generators"
require "generators/pu/lib/plutonium_generators"

# Exercises Concerns::JsPackageManager through a bare generator, away from the
# dummy app, so each case controls exactly which lockfiles exist.
class JsPackageManagerProbe < Rails::Generators::Base
  include PlutoniumGenerators::Generator
end

class JsPackageManagerTest < ActiveSupport::TestCase
  def setup
    @dir = Dir.mktmpdir("pu-js-pm")
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  test "detects the manager from its lockfile" do
    {
      "bun.lock" => :bun,
      "bun.lockb" => :bun,
      "pnpm-lock.yaml" => :pnpm,
      "package-lock.json" => :npm,
      "yarn.lock" => :yarn
    }.each do |lockfile, expected|
      FileUtils.rm_f(Dir.glob(File.join(@dir, "*")))
      touch(lockfile)

      assert_equal expected, probe.send(:js_package_manager), "#{lockfile} should select #{expected}"
    end
  end

  # The field report: `rails new -j esbuild` on a machine with bun installed
  # produces bun.lock, then a hardcoded `yarn add` added yarn.lock next to it.
  # jsbundling-rails reads bun.lock first, and so must we.
  test "prefers bun when both bun.lock and yarn.lock exist" do
    touch("bun.lock")
    touch("yarn.lock")

    assert_equal :bun, probe.send(:js_package_manager)
  end

  test "builds one add command per manager with every package inline" do
    packages = ["@radioactive-labs/plutonium@^1.2.3", "tailwindcss@latest", "postcss"]

    assert_equal "bun add @radioactive-labs/plutonium@^1.2.3 tailwindcss@latest postcss", probe_for(:bun).send(:js_add_command, packages)
    assert_equal "yarn add @radioactive-labs/plutonium@^1.2.3 tailwindcss@latest postcss", probe_for(:yarn).send(:js_add_command, packages)
    assert_equal "npm install @radioactive-labs/plutonium@^1.2.3 tailwindcss@latest postcss", probe_for(:npm).send(:js_add_command, packages)
    assert_equal "pnpm add @radioactive-labs/plutonium@^1.2.3 tailwindcss@latest postcss", probe_for(:pnpm).send(:js_add_command, packages)
  end

  test "builds install and run commands per manager" do
    assert_equal "bun install", probe_for(:bun).send(:js_install_command)
    assert_equal "npm ci", probe_for(:npm).send(:js_install_command)
    assert_equal "yarn install", probe_for(:yarn).send(:js_install_command)
    assert_equal "pnpm install", probe_for(:pnpm).send(:js_install_command)

    assert_equal "bun run build", probe_for(:bun).send(:js_run_command, "build")
    assert_equal "npm run build", probe_for(:npm).send(:js_run_command, "build")
    assert_equal "yarn build", probe_for(:yarn).send(:js_run_command, "build")
    assert_equal "pnpm run build", probe_for(:pnpm).send(:js_run_command, "build")
  end

  test "yarn_berry? reads the major version of the yarn the app resolves to" do
    assert probe_for(:yarn, yarn: "4.9.2").send(:yarn_berry?)
    assert probe_for(:yarn, yarn: "2.4.3").send(:yarn_berry?)
    refute probe_for(:yarn, yarn: "1.22.22").send(:yarn_berry?)
    refute probe_for(:yarn, yarn: nil).send(:yarn_berry?), "no yarn on PATH must not be treated as berry"
    refute probe_for(:bun, yarn: "4.9.2").send(:yarn_berry?), "yarn version is irrelevant outside yarn apps"
  end

  test "ensure_yarn_node_modules_linker creates .yarnrc.yml for yarn 2+" do
    probe_for(:yarn, yarn: "4.9.2").send(:ensure_yarn_node_modules_linker)

    assert_equal "nodeLinker: node-modules\n", File.read(File.join(@dir, ".yarnrc.yml"))
  end

  test "ensure_yarn_node_modules_linker appends to an existing .yarnrc.yml that has no linker" do
    File.write(File.join(@dir, ".yarnrc.yml"), "enableTelemetry: false\n")

    probe_for(:yarn, yarn: "4.9.2").send(:ensure_yarn_node_modules_linker)

    assert_equal "enableTelemetry: false\nnodeLinker: node-modules\n", File.read(File.join(@dir, ".yarnrc.yml"))
  end

  test "ensure_yarn_node_modules_linker leaves an explicit linker alone and warns about pnp" do
    File.write(File.join(@dir, ".yarnrc.yml"), "nodeLinker: pnp\n")

    output = capture_stdout { probe_for(:yarn, yarn: "4.9.2").send(:ensure_yarn_node_modules_linker) }

    assert_equal "nodeLinker: pnp\n", File.read(File.join(@dir, ".yarnrc.yml"))
    assert_match(/Plug'n'Play/, output)
  end

  test "ensure_yarn_node_modules_linker is a no-op for yarn 1 and other managers" do
    probe_for(:yarn, yarn: "1.22.22").send(:ensure_yarn_node_modules_linker)
    probe_for(:bun, yarn: "4.9.2").send(:ensure_yarn_node_modules_linker)

    refute File.exist?(File.join(@dir, ".yarnrc.yml"))
  end

  private

  def probe
    JsPackageManagerProbe.new([], {}, destination_root: @dir)
  end

  def probe_for(manager, yarn: "1.22.22")
    probe.tap do |p|
      p.define_singleton_method(:js_package_manager) { manager }
      p.define_singleton_method(:yarn_version) { yarn }
    end
  end

  def touch(name)
    FileUtils.touch(File.join(@dir, name))
  end

  def capture_stdout
    out = StringIO.new
    original = $stdout
    $stdout = out
    yield
    out.string.gsub(/\e\[[0-9;]*m/, "")
  ensure
    $stdout = original
  end
end
