# frozen_string_literal: true

require "test_helper"

# Unit-covers the `wizard` definition macro: it synthesizes a launch action,
# placing it as a record action for anchored wizards and a resource action for
# non-anchored ones (no bulk).
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

  class AnchoredDefinition < Plutonium::Resource::Definition
    wizard :configure, AnchoredW
  end

  class CreateDefinition < Plutonium::Resource::Definition
    wizard :onboard, CreateW
  end

  def test_anchored_wizard_becomes_record_action
    action = AnchoredDefinition.new.defined_actions[:configure]
    assert action, "expected a :configure action to be synthesized"
    assert action.record_action?
    refute action.resource_action?
    assert_equal :get, action.route_options.method
  end

  def test_non_anchored_wizard_becomes_resource_action
    action = CreateDefinition.new.defined_actions[:onboard]
    assert action
    refute action.record_action?
    assert action.resource_action?
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
    action = AnchoredDefinition.new.defined_actions[:configure]
    assert_respond_to action.route_options.url_resolver, :to_proc
  end
end
