# frozen_string_literal: true

require "plutonium/testing/dsl"

module Plutonium
  module Testing
    module ResourceModel
      extend ActiveSupport::Concern
      include Plutonium::Testing::DSL

      class_methods do
        def resource_tests_for(*args, **kwargs)
          super
          install_model_tests!
        end

        def install_model_tests!
          cfg = resource_tests_config

          if (assoc = cfg[:associated_with])
            test "model: associated_with(#{assoc}) scope filters records" do
              record = model_test_record
              parent = record.public_send(assoc)
              scoped = record.class.associated_with(parent)
              assert_includes scoped.to_a, record
            end
          end

          if cfg[:sgid_routing]
            test "model: SGID round-trip locates record" do
              record = model_test_record
              sgid = record.to_sgid.to_s
              found = GlobalID::Locator.locate_signed(sgid)
              assert_equal record, found
            end
          end

          Array(cfg[:has_cents]).each do |attr|
            test "model: has_cents :#{attr} provides cents accessor" do
              record = model_test_record
              assert record.respond_to?(attr), "Expected ##{attr}"
              assert record.respond_to?("#{attr}_cents"), "Expected ##{attr}_cents"
            end
          end
        end
      end

      def model_test_record
        raise NotImplementedError, "Override #model_test_record to return a persisted record"
      end
    end
  end
end
