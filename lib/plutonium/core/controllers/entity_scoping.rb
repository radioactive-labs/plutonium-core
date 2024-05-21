module Plutonium
  module Core
    module Controllers
      module EntityScoping
        extend ActiveSupport::Concern

        included do
          before_action :remember_scoped_entity
          helper_method :current_scoped_entity
        end

        private

        def scoped_to_entity?
          current_engine.scoped_to_entity?
        end

        def scoped_entity_strategy
          current_engine.scoped_entity_strategy
        end

        def scoped_entity_class
          ensure_legal_entity_scoping_method_access! :scoped_entity_class

          current_engine.scoped_entity_class
        end

        def scoped_entity_param_key
          ensure_legal_entity_scoping_method_access! :scoped_entity_param_key

          current_engine.scoped_entity_param_key
        end

        def scoped_entity_session_key
          ensure_legal_entity_scoping_method_access! :scoped_entity_session_key

          :"#{current_package.name.underscore}__scoped_entity_id"
        end

        def current_scoped_entity
          ensure_legal_entity_scoping_method_access! :current_scoped_entity

          return unless current_user.present?

          @current_scoped_entity ||= case scoped_entity_strategy
          when :path
            scoped_entity_class
              .associated_with(current_user)
              .from_path_param(request.path_parameters[scoped_entity_param_key])
              .first! # Raise NotFound if user does not have access to the entity or it does not exist
          when Symbol
            send scoped_entity_strategy
          else
            raise NotImplementedError, "unknown scoped entity strategy: #{scoped_entity_strategy.inspect}"
          end
        end

        def remember_scoped_entity
          return unless scoped_to_entity?

          session[scoped_entity_session_key] = current_scoped_entity.to_global_id.to_s
        end

        def remembered_scoped_entity
          ensure_legal_entity_scoping_method_access! :remembered_scoped_entity

          @remembered_scoped_entity ||= GlobalID::Locator.locate session[scoped_entity_session_key]
        end

        def ensure_legal_entity_scoping_method_access!(method)
          return if scoped_to_entity?

          raise NotImplementedError, "this request is not scoped to an entity\n\n" \
                                     "add the `scope_to_entity YourEntityRecord` directive in " \
                                     "#{current_engine} or implement #{self.class}##{method}"
        end
      end
    end
  end
end
