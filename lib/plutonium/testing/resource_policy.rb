# frozen_string_literal: true

require "plutonium/testing/dsl"

module Plutonium
  module Testing
    module ResourcePolicy
      extend ActiveSupport::Concern
      include Plutonium::Testing::DSL

      class_methods do
        def resource_tests_for(*args, **kwargs)
          super
          install_policy_tests!
        end

        def install_policy_tests!
          test "policy: matrix is asserted for every (action × role)" do
            matrix = policy_matrix
            roles = policy_roles
            record = policy_record
            policy_klass = policy_class_for(record)

            matrix.each do |action, allowed_roles|
              roles.each do |role_sym, account_proc|
                account = instance_exec(&account_proc)
                policy = policy_klass.new(record: record, user: account, **policy_context)
                expected = allowed_roles.include?(role_sym)
                actual = policy.public_send("#{action}?")
                assert_equal expected, actual,
                  "#{policy_klass}#{action}? for #{role_sym}: expected #{expected}, got #{actual}"
              end
            end
          end

          test "policy: relation_scope returns AR::Relation per role" do
            record = policy_record
            policy_klass = policy_class_for(record)
            policy_roles.each do |role_sym, account_proc|
              account = instance_exec(&account_proc)
              policy = policy_klass.new(record: record.class, user: account, **policy_context)
              scope = policy.apply_scope(record.class.all, type: :active_record_relation)
              assert_kind_of ActiveRecord::Relation, scope, "relation_scope must return AR::Relation for #{role_sym}"
            end
          end
        end
      end

      def policy_roles
        raise NotImplementedError, "Override #policy_roles to return Hash{role_sym => -> { account }}"
      end

      def policy_record
        raise NotImplementedError, "Override #policy_record to return a persisted record"
      end

      def policy_matrix
        raise NotImplementedError, "Override #policy_matrix to return Hash{action_sym => [role_syms]}"
      end

      def policy_context
        {entity_scope: nil}
      end

      private

      def policy_class_for(record)
        "#{record.class.name}Policy".constantize
      end
    end
  end
end
