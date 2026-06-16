# frozen_string_literal: true

require "test_helper"

# Unit-covers the `wizard` definition macro: it synthesizes a launch action and
# registers the wizard. Placement mirrors interactions — an anchored wizard becomes
# a RECORD action (its URL targets the resource's auto-mounted member wizard route),
# a non-anchored wizard becomes a RESOURCE (collection) action. The macro also keeps
# a `registered_wizards` registry the resource-mounted WizardActions concern reads.
class Plutonium::Definition::WizardsTest < Minitest::Test
  class AnchoredW < Plutonium::Wizard::Base
    anchored with: Organization
    step(:a) { attribute :x, :string }
    review label: "R"
    def execute = succeed(anchor)
  end

  class CreateW < Plutonium::Wizard::Base
    step(:a) { attribute :x, :string }
    review label: "R"
    def execute = succeed(true)
  end

  class CreateDefinition < Plutonium::Resource::Definition
    wizard :onboard, CreateW
  end

  class ConfigureDefinition < Plutonium::Resource::Definition
    wizard :configure, AnchoredW
  end

  def test_anchored_wizard_becomes_record_action
    action = ConfigureDefinition.new.defined_actions[:configure]
    assert action
    assert action.record_action?
    refute action.resource_action?
    assert_equal :get, action.route_options.method
  end

  def test_anchored_wizard_is_registered
    reg = ConfigureDefinition.registered_wizards.fetch(:configure)
    assert_equal AnchoredW, reg[:wizard_class]
    assert reg[:record_action]
  end

  def test_non_anchored_wizard_is_registered_as_collection
    reg = CreateDefinition.registered_wizards.fetch(:onboard)
    assert_equal CreateW, reg[:wizard_class]
    refute reg[:record_action]
  end

  def test_non_anchored_wizard_becomes_resource_action
    action = CreateDefinition.new.defined_actions[:onboard]
    assert action
    refute action.record_action?
    assert action.resource_action?
    assert_equal :get, action.route_options.method
  end

  def test_record_action_override
    defn = Class.new(Plutonium::Resource::Definition) do
      wizard :archive, CreateW, record_action: true
    end
    action = defn.new.defined_actions[:archive]
    assert action.record_action?
    refute action.resource_action?
  end

  def test_url_resolver_is_a_proc
    action = CreateDefinition.new.defined_actions[:onboard]
    assert_respond_to action.route_options.url_resolver, :to_proc
  end

  def test_register_wizard_raises_for_anchored_wizard
    routes = ActionDispatch::Routing::RouteSet.new
    error = assert_raises(ArgumentError) do
      routes.draw { register_wizard AnchoredW, at: "configure" }
    end
    assert_match(/anchored wizards are not mounted portal-level/, error.message)
  end

  def test_register_wizard_allows_non_anchored_wizard
    routes = ActionDispatch::Routing::RouteSet.new
    routes.draw { register_wizard CreateW, at: "onboard" }
    assert routes.url_helpers.respond_to?(:onboard_wizard_path)
  end
end
