module Plutonium
  module Core
    class Action
      RouteOptions = Data.define :action, :method, :options do
        def initialize(action: nil, method: :get, options: {})
          super
        end
      end

      attr_reader :name, :label, :icon, :route_options, :confirmation, :turbo_frame, :action_class

      def initialize(name, label: nil, icon: nil, route_options: nil,
                           confirmation: nil, turbo_frame: nil, action_class: nil,
                           collection_action: false, collection_record_action: false,
                           record_action: false, bulk_action: false)
        @name = name
        @icon = icon
        @label = label || name.to_s.humanize
        @route_options = route_options || RouteOptions.new
        @turbo_frame = turbo_frame
        @action_class = action_class
        @collection_action = collection_action
        @collection_record_action = collection_record_action
        @record_action = record_action
        @bulk_action = bulk_action
      end

      def collection_action?
        @collection_action
      end

      def collection_record_action?
        @collection_record_action
      end

      def record_action?
        @record_action
      end

      def bulk_action?
        @bulk_action
      end
    end
  end
end
