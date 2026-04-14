# frozen_string_literal: true

require "plutonium/testing/dsl"
require "plutonium/testing/auth_helpers"

module Plutonium
  module Testing
    module ResourceCrud
      extend ActiveSupport::Concern
      include Plutonium::Testing::DSL
      include Plutonium::Testing::AuthHelpers

      class_methods do
        def resource_tests_for(*args, **kwargs)
          super
          install_crud_tests!
        end

        def install_crud_tests!
          define_crud_test :index do
            create_resource!
            get "#{current_path_prefix}/#{resource_path}"
            assert_response :success
          end

          define_crud_test :show do
            record = create_resource!
            get "#{current_path_prefix}/#{resource_path}/#{record.id}"
            assert_response :success
          end

          define_crud_test :new do
            get "#{current_path_prefix}/#{resource_path}/new"
            assert_response :success
          end

          define_crud_test :create do
            assert_difference -> { resource_class.count }, 1 do
              post "#{current_path_prefix}/#{resource_path}", params: {param_key => valid_create_params}
            end
            assert_response :redirect
          end

          define_crud_test :edit do
            record = create_resource!
            get "#{current_path_prefix}/#{resource_path}/#{record.id}/edit"
            assert_response :success
          end

          define_crud_test :update do
            record = create_resource!
            patch "#{current_path_prefix}/#{resource_path}/#{record.id}", params: {param_key => valid_update_params}
            assert_response :redirect
            valid_update_params.each do |attr, value|
              next if value.is_a?(String) && value.start_with?("gid://")  # skip SGID assoc fields
              assert_equal value, record.reload.public_send(attr),
                "Expected ##{attr} to be updated to #{value.inspect}"
            end
          end

          define_crud_test :destroy do
            record = create_resource!
            assert_difference -> { resource_class.count }, -1 do
              delete "#{current_path_prefix}/#{resource_path}/#{record.id}"
            end
          end
        end

        def define_crud_test(action, &block)
          cfg = resource_tests_config
          return unless cfg[:actions].include?(action)
          return if cfg[:skip].include?(action)
          test("crud: #{action}", &block)
        end
      end

      def create_resource!
        raise NotImplementedError, "Override #create_resource! to return a persisted record"
      end

      def valid_create_params
        raise NotImplementedError, "Override #valid_create_params to return a Hash of valid attributes for POST"
      end

      def valid_update_params
        raise NotImplementedError, "Override #valid_update_params to return a Hash of valid attributes for PATCH"
      end

      private

      def resource_class
        self.class.resource_tests_config.fetch(:resource)
      end

      def resource_path
        resource_class.model_name.collection
      end

      def param_key
        resource_class.model_name.param_key
      end
    end
  end
end
