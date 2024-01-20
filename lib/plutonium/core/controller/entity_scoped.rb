module Plutonium
  module Core
    module Controller
      module EntityScopedd
        def self.to(scoped_entity_class)
          mod = Module.new
          mod.module_eval <<-RUBY, __FILE__, __LINE__ + 1
          extend ActiveSupport::Concern

          included do
            before_action :remember_scoped_entity
            helper_method :current_scoped_entity
          end

          private

          def scoped_to_entity?
            true
          end

          def scoped_entity_class
            #{scoped_entity_class}
          end

          def scoped_entity_session_key
            :scoped_entity_id
          end

          def remember_scoped_entity
            return unless scoped_to_entity? && current_scoped_entity.present?

            session[scoped_entity_session_key] = current_scoped_entity.to_global_id.to_s
          end

          def remembered_scoped_entity
            @remembered_scoped_entity ||= begin
              GlobalID::Locator.locate session[scoped_entity_session_key] if session[scoped_entity_session_key].present?
            end
          end

          def scoped_entity_param_key
            scope_param_key = scoped_entity_class.model_name.singular_route_key
            scope_param_key = :"\#{scope_param_key}_id"
          end

          def current_scoped_entity
            return unless current_user.present?

            # Raise NotFound if user does not have access to the entity or it does not exist
            @current_scoped_entity ||= scoped_entity_class \
                                          .for_parent(current_user) \
                                          .from_path_param(request.path_parameters.require(scoped_entity_param_key)) \
                                          .first!
          end

          define_singleton_method(:to_s) { "Plutonium::Core::Controller::EntityScoped(#{scoped_entity_class})" }
          define_singleton_method(:inspect) { "Plutonium::Core::Controller::EntityScoped(#{scoped_entity_class})" }
          RUBY
          mod
        end
      end
    end
  end
end
