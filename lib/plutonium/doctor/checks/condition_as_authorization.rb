# frozen_string_literal: true

module Plutonium
  module Doctor
    module Checks
      # An action whose only user check is its `condition:`.
      #
      # `condition:` decides whether a button renders. The policy decides
      # whether the action may run. `Action::Base#condition_met?` says so in as
      # many words — "NOT an authorization boundary; a hidden action still has a
      # live route" — but the two read alike at the call site, and putting the
      # role check in the condition is a natural mistake to make. The button
      # disappears, the author sees the behaviour they asked for, and the route
      # goes on accepting a direct POST from anyone the policy allows.
      #
      # Nothing can raise here: a `condition:` that mentions the current user is
      # perfectly legal, and often deliberate — a condition may narrow an
      # already-authorized action for presentation. Only the pairing is
      # suspicious, so both halves have to hold:
      #
      #   1. the condition reads like an authorization decision, and
      #   2. the policy predicate does not.
      #
      # A predicate that delegates (`def publish? = update?`) counts as not
      # deciding: the app wrote it, but it answers a different question than the
      # condition does, so the condition is still the only place the user is
      # being checked.
      #
      # A predicate that does not exist at all belongs to {MissingPolicyRule};
      # reporting it here too would say one thing twice.
      class ConditionAsAuthorization < Check
        def self.severity = :warning

        # Tokens that make a snippet read as an authorization decision rather
        # than a presentation one. Applied to both halves, which is what keeps
        # the check symmetric: whatever counts as "checking the user" in a
        # condition counts as "checking the user" in a policy too.
        #
        # A heuristic, and only ever decides whether to SPEAK — never what is
        # true. The report quotes the source so the reader judges it at a glance.
        AUTHORIZATION_TOKENS = /\b(?:current_user|user|admin|role|owner|permission|allowed_to\?|can_|policy)\b/

        # How far past a declaration to read when quoting it. Long enough for a
        # realistic lambda or method body, short enough that a runaway read
        # cannot happen.
        SOURCE_WINDOW = 5

        def call
          target.definition.defined_actions.filter_map do |name, action|
            next if action.condition.nil?

            predicate = :"#{name}?"
            # Undefined entirely — MissingPolicyRule owns that finding.
            next unless defined_predicate?(predicate)

            condition = source_of(action.condition.source_location)
            next unless condition&.match?(AUTHORIZATION_TOKENS)
            next if policy_checks_the_user?(predicate)

            build_finding(name, predicate, condition)
          end
        end

        private

        def defined_predicate?(predicate)
          target.policy_class.method_defined?(predicate) ||
            target.policy_class.private_method_defined?(predicate)
        end

        # Whether the policy's own answer for this action looks at the user.
        #
        # A framework default never does — Plutonium's predicates delegate among
        # themselves down to `create?`/`read?`, which an application overrides
        # without reference to any particular action. Anything the application
        # wrote is judged by the same token list as the condition.
        def policy_checks_the_user?(predicate)
          method = target.policy_class.instance_method(predicate)
          return false if framework_owned?(method)

          source = source_of(method.source_location)
          # Unreadable source is treated as deciding, so an unquotable policy
          # keeps the check quiet rather than guessing about it.
          return true if source.nil?

          source.match?(AUTHORIZATION_TOKENS)
        end

        def framework_owned?(method)
          method.owner.name.to_s.start_with?("Plutonium::", "ActionPolicy::")
        end

        def build_finding(name, predicate, condition)
          finding(
            subject: "#{target.resource_class}##{name}",
            message: "`#{name}` checks the user in `condition:`, but `#{predicate}` does not",
            details: <<~TEXT
              The condition reads as an authorization rule:

              #{condition.strip.gsub(/^/, "    ")}

              `condition:` only decides whether the button renders. The route stays live, so a
              direct request runs the action for anyone `#{predicate}` allows. Move the rule
              into #{target.policy_class}:

                  def #{predicate}
                    user.admin?   # whatever the condition was deciding
                  end

              Keep the `condition:` as well if it is also doing presentation work.
            TEXT
          )
        end

        # The source lines at a [file, line] pair, for quoting in the report.
        #
        # Best effort by construction: source built somewhere unreadable (an
        # eval, a stripped deployment) yields nil, and the caller decides what
        # silence means. Both callers here choose the quiet direction.
        def source_of(location)
          file, line = location
          return unless file && line && File.readable?(file)

          File.foreach(file).drop(line - 1).first(SOURCE_WINDOW).join
        rescue SystemCallError
          nil
        end
      end
    end
  end
end
