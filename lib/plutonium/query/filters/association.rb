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
        def initialize(class_name: nil, scope: nil, multiple: true, **)
          super(**)
          @class_name = class_name
          @scope_proc = scope
          @multiple = multiple
        end

        def humanize_value(value)
          return "" if value.blank?
          ids = decode_ids(value)
          return "" if ids.empty?
          # Resolve labels through the same scope-honouring relation that the
          # dropdown (ResourceSelect#authorized_relation) and the typeahead
          # (Typeahead#filter_association) already enforce. A bare
          # `association_class.where(id: ids)` here would widen past the
          # configured `scope:` and let a crafted `?q[<key>][value]=<out-of-scope
          # id>` render the hidden record's `to_label` into the active-filter
          # pill even though the matching filter was dropped at submission.
          records = scoped_relation.where(id: ids)
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
            include_blank: @multiple ? false : "All",
            scope: @scope_proc
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

        # The relation used to resolve `humanize_value` labels, narrowed by the
        # configured `scope:` exactly like ResourceSelect#apply_scope and
        # Typeahead#apply_scope. The arity dispatch — Symbol, zero-arg Proc
        # (kanban form `-> { ... }`), one-arg Proc (documented form
        # `->(s) { s.active }`), nil — must stay in lock-step with those two
        # sites; any divergence re-opens the leak this method closes. Unsupported
        # scope types raise ArgumentError loudly rather than silently widening.
        def scoped_relation
          relation = association_class.all
          case @scope_proc
          when Symbol then relation.public_send(@scope_proc)
          when Proc then @scope_proc.arity.zero? ? relation.instance_exec(&@scope_proc) : @scope_proc.call(relation)
          when nil then relation
          else raise ArgumentError, "Unsupported association scope: #{@scope_proc.inspect} (expected Symbol, Proc, or nil)"
          end
        end
      end
    end
  end
end
