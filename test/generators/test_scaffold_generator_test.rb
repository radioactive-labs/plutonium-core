# frozen_string_literal: true

require "test_helper"
require "rails/generators/test_case"
require "generators/pu/test/scaffold/scaffold_generator"

class TestScaffoldGeneratorTest < Rails::Generators::TestCase
  tests Pu::Test::ScaffoldGenerator
  destination File.expand_path("../../tmp/pu_test_scaffold", __dir__)
  setup :prepare_destination

  test "generates one file per portal" do
    run_generator %w[Blogging::Post --portals=admin org --dest=main_app]
    assert_file "test/integration/admin_portal/blogging_post_test.rb"
    assert_file "test/integration/org_portal/blogging_post_test.rb"
  end

  test "respects --concerns" do
    run_generator %w[Blogging::Post --portals=admin --concerns=crud policy --dest=main_app]
    assert_file "test/integration/admin_portal/blogging_post_test.rb" do |c|
      assert_match(/include Plutonium::Testing::ResourceCrud/, c)
      assert_match(/include Plutonium::Testing::ResourcePolicy/, c)
      refute_match(/ResourceDefinition/, c)
    end
  end

  test "wires parent via --parent" do
    run_generator %w[Blogging::Post --portals=org --parent=organization --dest=main_app]
    assert_file "test/integration/org_portal/blogging_post_test.rb" do |c|
      assert_match(/parent: :organization/, c)
    end
  end

  test "writes to package directory with --dest=<package>" do
    run_generator %w[Blogging::Post --portals=admin --dest=blogging]
    assert_file "packages/blogging/test/integration/admin_portal/blogging_post_test.rb"
  end
end
