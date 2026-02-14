# frozen_string_literal: true

return unless ENV["GENERATOR_TESTS"]

require "test_helper"
require "rails/generators/test_case"
require "generators/pu/pkg/portal/portal_generator"

class PortalGeneratorTest < Rails::Generators::TestCase
  include GeneratorTestHelper

  tests Pu::Pkg::PortalGenerator
  destination Rails.root

  def setup
    git_ensure_clean_dummy_app
  end

  test "generates portal with public access" do
    run_generator ["test", "--public"]

    assert_file "packages/test_portal/lib/engine.rb" do |content|
      assert_match(/module TestPortal/, content)
      assert_match(/include Plutonium::Portal::Engine/, content)
      assert_no_match(/scope_to_entity/, content)
    end

    assert_file "packages/test_portal/app/controllers/test_portal/concerns/controller.rb" do |content|
      assert_match(/include Plutonium::Auth::Public/, content)
    end
  end

  test "generates portal with rodauth auth" do
    run_generator ["test", "--auth=user"]

    assert_file "packages/test_portal/app/controllers/test_portal/concerns/controller.rb" do |content|
      assert_match(/include Plutonium::Auth::Rodauth\(:user\)/, content)
    end
  end

  test "generates portal with byo auth" do
    run_generator ["test", "--byo"]

    assert_file "packages/test_portal/app/controllers/test_portal/concerns/controller.rb" do |content|
      assert_match(/def current_user/, content)
      assert_match(/raise NotImplementedError/, content)
    end
  end

  test "generates portal with entity scoping" do
    run_generator ["test", "--public", "--scope=Organization"]

    assert_file "packages/test_portal/lib/engine.rb" do |content|
      assert_match(/scope_to_entity Organization, strategy: :path/, content)
    end
  end

  test "generates portal with auth and entity scoping" do
    run_generator ["test", "--auth=admin", "--scope=Account"]

    assert_file "packages/test_portal/lib/engine.rb" do |content|
      assert_match(/scope_to_entity Account, strategy: :path/, content)
    end

    assert_file "packages/test_portal/app/controllers/test_portal/concerns/controller.rb" do |content|
      assert_match(/include Plutonium::Auth::Rodauth\(:admin\)/, content)
    end
  end

  test "camelizes scope class name" do
    run_generator ["test", "--public", "--scope=user_organization"]

    assert_file "packages/test_portal/lib/engine.rb" do |content|
      assert_match(/scope_to_entity UserOrganization, strategy: :path/, content)
    end
  end
end
