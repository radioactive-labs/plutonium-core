# frozen_string_literal: true

module Plutonium
  module Wizard
    # Controller concern that gates access behind a **one-time wizard** (§9).
    #
    # +ensure_wizard_completed(WizardClass)+ installs a +before_action+ that, for a
    # +one_time+ wizard, checks whether the current principal has a durable
    # completion marker (a +completed+ session row). If not, it stashes the intended
    # destination and redirects into the wizard's entry step; once the wizard's own
    # finalize records the marker, the gate lets the user through and the controller
    # bounces back to the stashed destination (PRG, wired in {Controller}).
    #
    #   class DashboardController < AdminPortal::PlutoniumController
    #     include Plutonium::Wizard::Gate
    #     ensure_wizard_completed OnboardingWizard
    #   end
    #
    # **Completion keying** follows the wizard's +one_time_scope+ (§9):
    #
    # - +once_per: :user+ (default) → keyed by +owner: current_user+. This is the
    #   primary, fully-supported case.
    # - +once_per: :anchor+ → keyed by +anchor:+, resolved via
    #   {#wizard_gate_anchor} (override it to supply the anchor record; the default
    #   raises, since there is no generic way to know which record a gate is about).
    #
    # **Entry URL** (§5.3): the wizard's first step of its synthesized route. The
    # default {#wizard_entry_path} derives the +register_wizard+ helper name from the
    # wizard class (`<name>_wizard_path(step: <first_step_key>)`); override it for a
    # custom mount.
    module Gate
      extend ActiveSupport::Concern

      class_methods do
        # Install the gating +before_action+. Extra options (e.g. +only:/except:+)
        # are forwarded to +before_action+.
        def ensure_wizard_completed(wizard_class, **before_action_opts)
          before_action(**before_action_opts) do
            enforce_wizard_completion!(wizard_class)
          end
        end
      end

      private

      # The before_action body: pass through when completed, else stash + redirect.
      def enforce_wizard_completion!(wizard_class)
        return if wizard_completed?(wizard_class)

        session[:return_to] ||= request.fullpath
        redirect_to wizard_entry_path(wizard_class)
      end

      def wizard_completed?(wizard_class)
        wizard_gate_store.completed?(**wizard_completion_key(wizard_class))
      end

      # The +completed?+ lookup key for this wizard, keyed per +one_time_scope+.
      def wizard_completion_key(wizard_class)
        case wizard_class.one_time_scope
        when :anchor
          {wizard: wizard_class.name, anchor: wizard_gate_anchor(wizard_class)}
        else
          {wizard: wizard_class.name, owner: current_user}
        end
      end

      # Resolve the anchor for a +once_per: :anchor+ gate. There is no generic way to
      # know which record a gate is about, so override this in the host controller
      # (e.g. return the current tenant/workspace). The default raises rather than
      # silently mis-keying the completion check.
      def wizard_gate_anchor(wizard_class)
        raise NotImplementedError,
          "#{self.class} must override #wizard_gate_anchor to gate the " \
          "once_per: :anchor wizard #{wizard_class.name}"
      end

      def wizard_gate_store
        Plutonium::Wizard::Store::ActiveRecord.new
      end

      # The entry URL for the wizard's first step (§5.3). Derives the
      # +register_wizard+ route helper name (`<name>_wizard`) and calls it with the
      # wizard's first step. Override for a custom mount / helper name.
      def wizard_entry_path(wizard_class)
        helper = wizard_entry_path_helper(wizard_class)
        first_step = wizard_class.steps.first&.key
        public_send(helper, step: first_step)
      end

      def wizard_entry_path_helper(wizard_class)
        name = wizard_class.name.demodulize.underscore.sub(/_wizard\z/, "")
        :"#{name}_wizard_path"
      end
    end
  end
end
