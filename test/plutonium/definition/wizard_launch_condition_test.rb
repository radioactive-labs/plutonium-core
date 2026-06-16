# frozen_string_literal: true

require "test_helper"

# Covers the launch-action `condition:` the `wizard` macro synthesizes (§9):
# a ONE-TIME wizard's launch action is auto-hidden once the current user has
# already completed it (a retained `completed` session row exists at the wizard's
# recomputed `instance_key`). Repeatable wizards get NO completion condition, and
# an author-supplied `condition:` composes (AND-ed) with the completion check.
#
# Hits the DB (the completion check is `Store#completed?`), so it runs under
# ActiveSupport::TestCase with the `plutonium_wizard_sessions` table.
class Plutonium::Definition::WizardLaunchConditionTest < ActiveSupport::TestCase
  # One-time, keyed by the current_user → non-anchored resource action.
  class PerUserOneTimeWizard < Plutonium::Wizard::Base
    concurrency_key { current_user }
    one_time
    step(:a) { attribute :x, :string }
    review label: "R"
    def execute = succeed
  end

  # One-time, keyed by the anchor → anchored record action.
  class PerAnchorOneTimeWizard < Plutonium::Wizard::Base
    anchored with: Organization
    concurrency_key { anchor }
    one_time
    step(:a) { attribute :x, :string }
    review label: "R"
    def execute = succeed(anchor)
  end

  # No concurrency_key / not one_time → repeatable, no completion condition.
  class RepeatableWizard < Plutonium::Wizard::Base
    step(:a) { attribute :x, :string }
    review label: "R"
    def execute = succeed
  end

  class PerUserDefinition < Plutonium::Resource::Definition
    wizard :welcome, PerUserOneTimeWizard
  end

  class PerAnchorDefinition < Plutonium::Resource::Definition
    wizard :configure, PerAnchorOneTimeWizard
  end

  class RepeatableDefinition < Plutonium::Resource::Definition
    wizard :restart, RepeatableWizard
  end

  # Minimal host controller surface the condition leans on: `scoped_to_entity?` +
  # `current_scoped_entity` (read off `controller`). This host is non-scoped, so
  # the folded tenant is nil — matching the driving layer / gate.
  class HostController
    def scoped_to_entity? = false
    def current_scoped_entity = nil
  end

  # Minimal stand-in for the view context the ConditionContext delegates to:
  # exposes `current_user` (a helper method) and `controller`.
  ViewContext = Struct.new(:current_user, :controller)

  def view_for(user)
    ViewContext.new(user, HostController.new)
  end

  def action_for(definition_class, name)
    definition_class.new.defined_actions.fetch(name)
  end

  def complete_at(wizard_class, instance_key)
    Plutonium::Wizard::Session.create!(
      wizard: wizard_class.name, instance_key: instance_key, status: "completed"
    )
  end

  setup do
    Plutonium::Wizard::Session.delete_all
    Organization.delete_all
    @user = Organization.create!(name: "User-#{SecureRandom.hex(4)}")
  end

  # ---- one-time, per-user (resource action) ----

  test "per-user one-time launch shows when not completed, hides after completion" do
    action = action_for(PerUserDefinition, :welcome)
    assert action.condition_met?(view_for(@user)), "shown before completion"

    key = Plutonium::Wizard.compute_instance_key(
      wizard_class: PerUserOneTimeWizard, current_user: @user,
      current_scoped_entity: nil, anchor: nil, wizard_token: nil
    )
    complete_at(PerUserOneTimeWizard, key)

    refute action.condition_met?(view_for(@user)), "hidden after completion"
  end

  test "per-user completion for a DIFFERENT user does not hide the launch" do
    action = action_for(PerUserDefinition, :welcome)
    other = Organization.create!(name: "Other-#{SecureRandom.hex(4)}")

    other_key = Plutonium::Wizard.compute_instance_key(
      wizard_class: PerUserOneTimeWizard, current_user: other,
      current_scoped_entity: nil, anchor: nil, wizard_token: nil
    )
    complete_at(PerUserOneTimeWizard, other_key)

    assert action.condition_met?(view_for(@user)), "@user has not completed it"
  end

  # ---- one-time, anchored (record action) ----

  test "anchored one-time launch shows when not completed, hides after completion for that anchor" do
    action = action_for(PerAnchorDefinition, :configure)
    anchor = Organization.create!(name: "Anchor-#{SecureRandom.hex(4)}")

    assert action.condition_met?(view_for(@user), record: anchor), "shown before completion"

    key = Plutonium::Wizard.compute_instance_key(
      wizard_class: PerAnchorOneTimeWizard, current_user: @user,
      current_scoped_entity: nil, anchor: anchor, wizard_token: nil
    )
    complete_at(PerAnchorOneTimeWizard, key)

    refute action.condition_met?(view_for(@user), record: anchor), "hidden after completion for this anchor"
  end

  test "anchored completion for one anchor does not hide the launch on a different anchor" do
    action = action_for(PerAnchorDefinition, :configure)
    anchor_a = Organization.create!(name: "A-#{SecureRandom.hex(4)}")
    anchor_b = Organization.create!(name: "B-#{SecureRandom.hex(4)}")

    key_a = Plutonium::Wizard.compute_instance_key(
      wizard_class: PerAnchorOneTimeWizard, current_user: @user,
      current_scoped_entity: nil, anchor: anchor_a, wizard_token: nil
    )
    complete_at(PerAnchorOneTimeWizard, key_a)

    refute action.condition_met?(view_for(@user), record: anchor_a)
    assert action.condition_met?(view_for(@user), record: anchor_b)
  end

  # ---- repeatable: no completion condition ----

  test "repeatable wizard launch has no completion condition and is always shown" do
    action = action_for(RepeatableDefinition, :restart)
    assert_nil action.condition, "no condition synthesized for a repeatable wizard"
    assert action.condition_met?(view_for(@user))
  end

  # ---- author-supplied condition composes (AND) ----

  test "author condition composes: false author condition hides regardless of completion" do
    defn = Class.new(Plutonium::Resource::Definition) do
      wizard :welcome, PerUserOneTimeWizard, condition: -> { false }
    end
    action = defn.new.defined_actions.fetch(:welcome)
    refute action.condition_met?(view_for(@user)), "author false hides even when not completed"
  end

  test "author condition composes: true author condition + completed hides" do
    defn = Class.new(Plutonium::Resource::Definition) do
      wizard :welcome, PerUserOneTimeWizard, condition: -> { true }
    end
    action = defn.new.defined_actions.fetch(:welcome)
    assert action.condition_met?(view_for(@user)), "author true + not completed → shown"

    key = Plutonium::Wizard.compute_instance_key(
      wizard_class: PerUserOneTimeWizard, current_user: @user,
      current_scoped_entity: nil, anchor: nil, wizard_token: nil
    )
    complete_at(PerUserOneTimeWizard, key)

    refute action.condition_met?(view_for(@user)), "author true + completed → hidden"
  end

  test "author condition composes on a repeatable wizard: only the author condition applies" do
    defn = Class.new(Plutonium::Resource::Definition) do
      wizard :restart, RepeatableWizard, condition: -> { current_user.present? }
    end
    action = defn.new.defined_actions.fetch(:restart)
    assert action.condition_met?(view_for(@user))
    refute action.condition_met?(view_for(nil))
  end
end
