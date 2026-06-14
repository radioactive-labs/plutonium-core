# frozen_string_literal: true

require "test_helper"

# Regression coverage for the package engine view-path neutralization.
#
# Package engines neutralize Rails' built-in `add_view_paths` initializer so a
# package's app/views isn't appended to the global ActionController/ActionMailer
# lookup (Plutonium resolves package views per-controller). This MUST be done in
# a real initializer (before :add_view_paths), NOT in `before_configuration`:
# that hook can fire before all sibling package engines are loaded (it does in
# development), and reaching into Rails.application.initializers there memoizes
# Rails.application.railties early — permanently dropping the not-yet-loaded
# packages from the autoload paths (the classic `uninitialized constant
# Blogging::Post` boot failure in `rails server` under RAILS_ENV=development).
class Plutonium::Package::EngineTest < Minitest::Test
  PACKAGE_ENGINES = [Blogging::Engine, Catalog::Engine, OrgPortal::Engine].freeze

  def test_neutralizes_via_initializer_not_before_configuration
    PACKAGE_ENGINES.each do |engine|
      init = engine.initializers.find { |i| i.name == :plutonium_neutralize_add_view_paths }
      refute_nil init,
        "#{engine} must neutralize add_view_paths via a named initializer (not before_configuration)"
      assert_equal :add_view_paths, init.before,
        "neutralization must run before :add_view_paths"
    end
  end

  def test_all_package_engines_are_registered_railties
    registered = Rails.application.send(:railties).map { |r| r.class }
    PACKAGE_ENGINES.each do |engine|
      assert_includes registered, engine,
        "#{engine} must be a registered railtie so Rails adds its app/* autoload paths"
    end
  end

  def test_package_views_are_not_appended_to_global_lookup
    global = ActionController::Base.view_paths.map(&:to_s)
    package_views = global.grep(%r{/packages/[^/]+/app/views})
    assert_empty package_views,
      "package app/views must not leak into the global view lookup: #{package_views.inspect}"
  end
end
