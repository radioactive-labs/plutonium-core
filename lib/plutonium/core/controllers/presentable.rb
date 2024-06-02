module Plutonium
  module Core
    module Controllers
      module Presentable
        extend ActiveSupport::Concern

        included do
          helper_method :presentable_attributes
        end

        private

        def resource_presenter(resource_class, resource_record)
          presenter_class = "#{resource_class}Presenter".constantize
          presenter_class.new resource_context, resource_record
        end

        def current_presenter
          @current_presenter ||= resource_presenter resource_class, @resource_record
        end

        def presentable_attributes
          @presentable_attributes ||= begin
            presentable_attributes = permitted_attributes
            presentable_attributes -= [scoped_entity_param_key, :"#{scoped_entity_param_key}_id"] if scoped_to_entity?
            presentable_attributes -= [parent_input_param, :"#{parent_input_param}_id"] if current_parent.present?
            presentable_attributes
          end
        end

        def build_collection
          Plutonium::Core::Ui::Collection.new(
            resource_class:,
            records: @resource_records,
            fields: current_presenter.defined_renderers_for(*presentable_attributes),
            actions: current_presenter.actions,
            pager: @pagy,
            search_object: @search_object
          )
        end

        def build_detail
          Plutonium::Core::Ui::Detail.new(
            resource_class:,
            record: resource_record,
            fields: current_presenter.defined_renderers_for(*presentable_attributes),
            associations: current_presenter.defined_association_renderers_for(*permitted_associations),
            actions: current_presenter.actions
          )
        end

        def build_form
          Plutonium::Core::Ui::Form.new(
            record: resource_record,
            inputs: current_presenter.defined_inputs_for(*presentable_attributes)
          )
        end
      end
    end
  end
end
