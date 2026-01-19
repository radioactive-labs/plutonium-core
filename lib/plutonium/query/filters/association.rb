module Plutonium
  module Query
    module Filters
      # Select filter for association records
      #
      # @example Basic - infers Category class from :category key
      #   filter :category, with: :association
      #
      # @example With explicit class
      #   filter :author, with: :association, class_name: User
      #
      # @example With multiple selection
      #   filter :tags, with: :association, class_name: Tag, multiple: true
      #
      class Association < Filter
        def initialize(class_name: nil, multiple: false, **)
          super(**)
          @association_class = class_name
          @multiple = multiple
        end

        def apply(scope, value:)
          return scope if value.blank?

          foreign_key = :"#{key}_id"
          if @multiple && value.is_a?(Array)
            scope.where(foreign_key => value.reject(&:blank?))
          else
            scope.where(foreign_key => value)
          end
        end

        def customize_inputs
          input :value,
            as: :resource_select,
            association_class: association_class,
            multiple: @multiple,
            include_blank: @multiple ? false : "All"
        end

        private

        def association_class
          @association_class || key.to_s.classify.constantize
        end
      end
    end
  end
end
