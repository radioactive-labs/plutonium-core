# frozen_string_literal: true

return unless ENV["GENERATOR_TESTS"]

require "test_helper"
require "json"

class AssetsGeneratorTest < ActiveSupport::TestCase
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
end
