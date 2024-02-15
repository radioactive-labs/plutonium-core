module Plutonium
  module Core
    module Controllers
      module Presentable
        extend ActiveSupport::Concern

        included do
          helper_method :presentable_attributes
        end

        private

        def resource_presenter(resource_class)
          raise NotImplementedError, "#{self.class}#resource_presenter"
        end

        def current_presenter
          resource_presenter resource_class
        end

        def presentable_attributes
          @presentable_attributes ||= begin
            presentable_attributes = permitted_attributes
            presentable_attributes -= [scoped_entity_param_key, :"#{scoped_entity_param_key}_id"] if scoped_to_entity?
            presentable_attributes -= [parent_param_key, parent_param_key.to_s.gsub(/_id$/, "").to_sym] if current_parent.present?
            presentable_attributes
          end
        end

        def build_collection
          Plutonium::Core::UI::Collection.new(
            resource_class:,
            records: @resource_records,
            fields: current_presenter.defined_renderers_for(presentable_attributes),
            actions: current_presenter.actions,
            pagination: @pagy,
            search_object: @ransack
          )
        end

        def build_detail
          Plutonium::Core::UI::Detail.new(
            resource_class:,
            record: resource_record,
            fields: current_presenter.defined_renderers_for(presentable_attributes),
            actions: current_presenter.actions
          )
        end

        def build_form
          Plutonium::Core::UI::Form.new(
            record: resource_record,
            inputs: current_presenter.defined_inputs_for(presentable_attributes)
          )
        end
      end
    end
  end
end
