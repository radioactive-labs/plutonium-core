# frozen_string_literal: true

require "plutonium/testing/dsl"
require "plutonium/testing/auth_helpers"

module Plutonium
  module Testing
    module NestedResource
      extend ActiveSupport::Concern
      include Plutonium::Testing::DSL
      include Plutonium::Testing::AuthHelpers

      class_methods do
        def resource_tests_for(*args, **kwargs)
          super
          install_nested_tests!
        end

        def install_nested_tests!
          test "nested: index lists records from current parent" do
            create_resource!(parent: parent_record!)
            get scoped_index_path(parent_record!)
            assert_response :success
          end

          test "nested: show on sibling-tenant record returns 404" do
            sibling = create_resource!(parent: other_parent_record!)
            get "#{scoped_index_path(parent_record!)}/#{sibling.id}"
            assert_includes [404, 302], response.status,
              "Expected sibling-tenant record to be inaccessible (404 or redirect), got #{response.status}"
          end
        end
      end

      def parent_record!
        raise NotImplementedError, "Override #parent_record! to return the current tenant"
      end

      def other_parent_record!
        raise NotImplementedError, "Override #other_parent_record! to return a sibling tenant"
      end

      def create_resource!(parent:)
        raise NotImplementedError, "Override #create_resource!(parent:) to return a persisted record under the given parent"
      end

      private

      def scoped_index_path(parent)
        "#{current_path_prefix}/#{parent.id}/#{resource_collection}"
      end

      def resource_collection
        self.class.resource_tests_config.fetch(:resource).model_name.collection
      end
    end
  end
end
