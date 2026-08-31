# frozen_string_literal: true

module Plutonium
  module Doctor
    module Checks
      # An action whose policy predicate nobody defined.
      #
      # `Action::Base#permitted_by?` asks `policy.allowed_to?(:"#{name}?")`, and
      # ActionPolicy answers `false` for a rule that does not exist rather than
      # raising. So the button never renders, and nothing anywhere says why —
      # the author sees a missing button and goes looking in the definition,
      # which is the one file that is correct.
      #
      # For an interactive action this is also the difference between hidden and
      # denied: the route is mounted either way, so a direct POST is refused by
      # the same missing predicate that hid the button. That is the safe
      # direction, which is precisely why nothing raises and why this check has
      # to exist.
      #
      # Hidden actions are exempt, and not as a concession. `hidden: true` means
      # the action renders on no surface at all, so there is no button whose
      # absence could be mistaken for a styling problem — the failure this check
      # describes cannot happen. It is also how the framework builds a kanban
      # column's `enter_interaction`: deliberately predicate-less, because the
      # drop that reaches it is authorized by `kanban_move?` instead. A check
      # that flagged those would be wrong about the framework's own output on
      # every board.
      class MissingPolicyRule < Check
        def self.severity = :error

        def call
          target.definition.defined_actions.filter_map do |name, action|
            next if action.hidden?

            predicate = :"#{name}?"
            next if target.policy_class.method_defined?(predicate) ||
              target.policy_class.private_method_defined?(predicate)

            finding(
              subject: "#{target.resource_class}##{name}",
              message: "#{kind(action)} `#{name}` has no `#{predicate}` in #{target.policy_class}",
              details: <<~TEXT
                ActionPolicy answers false for a rule that is not defined, so this action
                never renders and the omission is silent.#{" "}

                Add the predicate to #{target.policy_class}:

                    def #{predicate}
                      update?   # or whatever authorizes this action
                    end
              TEXT
            )
          end
        end

        private

        def kind(action)
          if action.bulk_action? then "Bulk action"
          elsif action.record_action? || action.collection_record_action? then "Record action"
          elsif action.resource_action? then "Resource action"
          else "Action"
          end
        end
      end
    end
  end
end
