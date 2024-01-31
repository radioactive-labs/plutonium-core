module Plutonium
  module Core
    class Action
      RouteOptions = Data.define :action, :method, :options do
        def initialize(action: nil, method: :get, options: {})
          super
        end
      end

      attr_reader :name, :label, :icon, :route_options, :confirmation, :turbo_frame, :action_class

      def initialize(name, label: nil, icon: nil, route_options: nil, confirmation: nil, turbo_frame: nil, action_class: nil)
        @name = name
        @icon = icon
        @label = label || name.to_s.humanize
        @route_options = route_options || RouteOptions.new
        @turbo_frame = turbo_frame
        @action_class = action_class
      end

      def collection_action?
        false
      end

      def collection_record_action?
        false
      end

      def record_action?
        false
      end

      def bulk_action?
        false
      end
    end
  end
end
