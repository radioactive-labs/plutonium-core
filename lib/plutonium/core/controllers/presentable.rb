module Plutonium
  module Core
    module Controllers
      module Presentable
        extend ActiveSupport::Concern

        private

        def resource_presenter(resource_class)
          raise NotImplementedError, "resource_presenter"
        end

        def current_presenter
          @current_presenter ||= resource_presenter resource_class
        end

        def build_collection
          Plutonium::Core::UI::Collection.new(
            resource_class:,
            records: @resource_records,
            fields: current_presenter.renderers_for(current_permitted_attributes),
            actions: current_presenter.actions,
            pagination: @pagy,
            search_object: @ransack
          )
        end

        def build_detail
          Plutonium::Core::UI::Detail.new(
            resource_class:,
            record: resource_record,
            fields: current_presenter.renderers_for(current_permitted_attributes),
            actions: current_presenter.actions
          )
        end

        def build_form
          Plutonium::Core::UI::Form.new(
            record: resource_record,
            inputs: current_presenter.inputs_for(current_permitted_attributes)
          )
        end
      end
    end
  end
end
