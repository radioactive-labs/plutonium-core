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
      # @example With custom scope
      #   filter :user, with: :association, class_name: User, scope: ->(s) { s.active }
      #
      class Association < Filter
        def initialize(class_name: nil, resource_class: nil, scope: nil, multiple: true, **)
          super(**)
          @class_name = class_name
          @resource_class = resource_class
          @scope_proc = scope
          @multiple = multiple
        end

        def humanize_value(value)
          return "" if value.blank?
          ids = decode_ids(value)
          return "" if ids.empty?
          records = association_class.where(id: ids)
          records.map { |r| r.respond_to?(:to_label) ? r.to_label : r.to_s }.join(", ")
        rescue
          Array(value).reject(&:blank?).join(", ")
        end

        def apply(scope, value:)
          return scope if value.blank?
          ids = decode_ids(value)
          return scope if ids.empty?
          scope.where("#{key}_id": ids)
        end

        def customize_inputs
          input :value,
            as: :resource_select,
            association_class: association_class,
            multiple: @multiple,
            include_blank: @multiple ? false : "All"
        end

        private

        # Accepts either an SGID (the new default sent by ResourceSelect)
        # or a raw id (legacy URLs). Returns the underlying record ids.
        def decode_ids(value)
          Array(value).reject(&:blank?).filter_map { |v| decode_id(v) }
        end

        def decode_id(value)
          gid = SignedGlobalID.parse(value)
          return gid.model_id if gid
          value
        rescue
          value
        end

        private

        def association_class
          @association_class ||= resolve_class_name || detect_class_from_reflection || infer_class_from_key
        end

        def resolve_class_name
          return nil unless @class_name

          @class_name.is_a?(String) ? @class_name.constantize : @class_name
        end

        def detect_class_from_reflection
          return nil unless @resource_class

          reflection = @resource_class.reflect_on_association(key)
          reflection&.klass
        end

        def infer_class_from_key
          key.to_s.classify.constantize
        end
      end
    end
  end
end
