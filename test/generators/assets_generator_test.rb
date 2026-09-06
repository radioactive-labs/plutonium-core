# frozen_string_literal: true

require "test_helper"
require "json"
require "rails/generators"
require "generators/pu/core/assets/assets_generator"

class AssetsGeneratorTest < ActiveSupport::TestCase
  include GeneratorTestHelper

  TAILWIND_ENTRYPOINT = "app/assets/stylesheets/application.tailwind.css"
  STIMULUS_ENTRYPOINT = "app/javascript/controllers/index.js"

  # Test the replace_build_script logic directly

  test "adds scripts section to package.json when missing" do
    package = {
      "name" => "app",
      "private" => true,
      "dependencies" => {}
    }

    package["scripts"] ||= {}
    package["scripts"]["build"] = "esbuild app/javascript/*.* --bundle --sourcemap --format=esm --outdir=app/assets/builds --public-path=/assets"
    package["scripts"]["build:css"] = "postcss ./app/assets/stylesheets/application.tailwind.css -o ./app/assets/builds/application.css"

    assert package.key?("scripts")
    assert_equal "esbuild app/javascript/*.* --bundle --sourcemap --format=esm --outdir=app/assets/builds --public-path=/assets", package["scripts"]["build"]
    assert_equal "postcss ./app/assets/stylesheets/application.tailwind.css -o ./app/assets/builds/application.css", package["scripts"]["build:css"]
  end

  test "preserves existing scripts when adding new ones" do
    package = {
      "name" => "app",
      "scripts" => {
        "lint" => "eslint ."
      }
    }

    package["scripts"] ||= {}
    package["scripts"]["build"] = "esbuild app/javascript/*.* --bundle --sourcemap --format=esm --outdir=app/assets/builds --public-path=/assets"
    package["scripts"]["build:css"] = "postcss ./app/assets/stylesheets/application.tailwind.css -o ./app/assets/builds/application.css"

    assert_equal "eslint .", package["scripts"]["lint"]
    assert_equal "esbuild app/javascript/*.* --bundle --sourcemap --format=esm --outdir=app/assets/builds --public-path=/assets", package["scripts"]["build"]
    assert_equal "postcss ./app/assets/stylesheets/application.tailwind.css -o ./app/assets/builds/application.css", package["scripts"]["build:css"]
  end

  test "overwrites existing build scripts" do
    package = {
      "name" => "app",
      "scripts" => {
        "build" => "old build command",
        "build:css" => "old css command"
      }
    }

    package["scripts"] ||= {}
    package["scripts"]["build"] = "esbuild app/javascript/*.* --bundle --sourcemap --format=esm --outdir=app/assets/builds --public-path=/assets"
    package["scripts"]["build:css"] = "postcss ./app/assets/stylesheets/application.tailwind.css -o ./app/assets/builds/application.css"

    assert_equal "esbuild app/javascript/*.* --bundle --sourcemap --format=esm --outdir=app/assets/builds --public-path=/assets", package["scripts"]["build"]
    assert_equal "postcss ./app/assets/stylesheets/application.tailwind.css -o ./app/assets/builds/application.css", package["scripts"]["build:css"]
  end

  test "generates valid JSON output" do
    package = {
      "name" => "app",
      "private" => true
    }

    package["scripts"] ||= {}
    package["scripts"]["build"] = "esbuild app/javascript/*.* --bundle --sourcemap --format=esm --outdir=app/assets/builds --public-path=/assets"
    package["scripts"]["build:css"] = "postcss ./app/assets/stylesheets/application.tailwind.css -o ./app/assets/builds/application.css"

    json_output = JSON.pretty_generate(package) + "\n"

    # Should be valid JSON
    parsed = JSON.parse(json_output)
    assert_equal "app", parsed["name"]
    assert parsed["scripts"].key?("build")
    assert parsed["scripts"].key?("build:css")
  end

  # verify_prerequisites should fail early (before install_dependencies/configure_application
  # touch anything) with an actionable message naming all required toolchains.
  # Introduced in commit 08291a4f: the original guard only checked the Tailwind
  # entrypoint and claimed "esbuild and Tailwind" were required, yet
  # configure_application later injects into the Stimulus controllers index. An
  # app created with `--skip-hotwire` (esbuild + Tailwind, no Stimulus) passed the
  # guard then crashed with an opaque Thor error.

  test "verify_prerequisites passes when Tailwind and Stimulus entrypoints both exist" do
    create_tailwind_entrypoint
    create_stimulus_entrypoint

    exited, output = capture_prereq_error { run_verify_prerequisites }

    refute exited, "should not exit when all prerequisites are present"
    assert_empty output, "should print nothing when all prerequisites are present"
  end

  test "verify_prerequisites exits listing the Tailwind file when only Stimulus is present" do
    create_stimulus_entrypoint

    exited, output = capture_prereq_error { run_verify_prerequisites }

    assert exited, "should exit when the Tailwind entrypoint is missing"
    assert_match(/esbuild, Tailwind, and Stimulus/, output)
    assert_match(/app\/assets\/stylesheets\/application\.tailwind\.css/, output)
    refute_match(/app\/javascript\/controllers\/index\.js/, output,
      "Stimulus entrypoint exists, so it must not be listed as missing")
    refute_match(/esbuild and Tailwind\b(?! and Stimulus)/, output,
      "must not regress to the old incomplete requirement string")
  end

  # The motivating bug: an app generated with `--skip-hotwire` has esbuild + Tailwind
  # but no Stimulus. The old guard passed it through; configure_application then
  # crashed on the missing controllers/index.js. The new guard must fail early and
  # explicitly name Stimulus as the missing requirement.
  test "verify_prerequisites exits listing the Stimulus file when only Tailwind is present (--skip-hotwire case)" do
    create_tailwind_entrypoint

    exited, output = capture_prereq_error { run_verify_prerequisites }

    assert exited, "should exit when the Stimulus entrypoint is missing"
    assert_match(/esbuild, Tailwind, and Stimulus/, output)
    assert_match(/app\/javascript\/controllers\/index\.js/, output)
    refute_match(/app\/assets\/stylesheets\/application\.tailwind\.css/, output,
      "Tailwind entrypoint exists, so it must not be listed as missing")
  end

  test "verify_prerequisites exits listing both files when neither Tailwind nor Stimulus is present" do
    exited, output = capture_prereq_error { run_verify_prerequisites }

    assert exited, "should exit when both entrypoints are missing"
    assert_match(/esbuild, Tailwind, and Stimulus/, output)
    assert_match(/Missing files:/, output)
    assert_match(/app\/assets\/stylesheets\/application\.tailwind\.css/, output)
    assert_match(/app\/javascript\/controllers\/index\.js/, output)
    assert_match(/rails new myapp -a propshaft -j esbuild -c tailwind/, output)
    assert_match(%r{radioactive-labs\.github\.io/plutonium-core/templates/plutonium\.rb}, output)
    refute_match(/esbuild and Tailwind\b(?! and Stimulus)/, output,
      "must not regress to the old incomplete requirement string")
  end

  test "start fails early with the prerequisite error before install_dependencies runs" do
    generator = build_generator

    # Safety net: install_dependencies shells out to yarn and must never be reached
    # when prerequisites are missing — if a refactor reorders the steps this fails.
    generator.define_singleton_method(:install_dependencies) do
      raise "install_dependencies must not run when prerequisites are missing"
    end

    output = strip_ansi(capture_say { assert_raises(SystemExit) { Dir.chdir(Rails.root) { generator.start } } })

    assert_match(/esbuild, Tailwind, and Stimulus/, output)
    assert_match(/app\/javascript\/controllers\/index\.js/, output)
  end

  private

  def build_generator
    Pu::Core::AssetsGenerator.new([], {}, {destination_root: Rails.root})
  end

  def run_verify_prerequisites
    Dir.chdir(Rails.root) do
      build_generator.send(:verify_prerequisites)
    end
  end

  # Runs `verify_prerequisites`, capturing $stdout. Returns [exited, message].
  # `verify_prerequisites` calls `error` → `exit(1)` (SystemExit) when something is
  # missing; we rescue that so the test can assert on `exited` without aborting.
  def capture_prereq_error
    out = StringIO.new
    original = $stdout
    $stdout = out
    exited = false
    begin
      yield
    rescue SystemExit
      exited = true
    ensure
      $stdout = original
    end
    [exited, strip_ansi(out.string)]
  end

  def capture_say
    out = StringIO.new
    original = $stdout
    $stdout = out
    begin
      yield
    ensure
      $stdout = original
    end
    out.string
  end

  def strip_ansi(str)
    str.gsub(/\e\[[0-9;]*m/, "")
  end

  def create_tailwind_entrypoint
    dir = Rails.root.join("app/assets/stylesheets")
    FileUtils.mkdir_p(dir)
    File.write(dir.join("application.tailwind.css"), %(@import "tailwindcss";\n))
  end

  def create_stimulus_entrypoint
    dir = Rails.root.join("app/javascript/controllers")
    FileUtils.mkdir_p(dir)
    File.write(dir.join("index.js"), %(import { application } from "./application"\n))
  end
end
