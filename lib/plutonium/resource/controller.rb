require "action_controller"
require "pagy"
require_relative "../routing/mapper_extensions"

module Plutonium
  module Resource
    # Controller module to handle resource actions and concerns
    module Controller
      extend ActiveSupport::Concern
      include Pagy::Method
      include Plutonium::Core::Controller
      include Plutonium::Resource::Controllers::Defineable
      include Plutonium::Resource::Controllers::Authorizable
      include Plutonium::Resource::Controllers::Presentable
      include Plutonium::Resource::Controllers::Queryable
      include Plutonium::Resource::Controllers::CrudActions
      include Plutonium::Resource::Controllers::KanbanActions
      include Plutonium::Resource::Controllers::InteractiveActions
      include Plutonium::Resource::Controllers::WizardActions
      include Plutonium::Resource::Controllers::Typeahead
      include Plutonium::Resource::Controllers::ExportCsv
      include Plutonium::StructuredInputs::ParamsConcern

      included do
        after_action { response.headers.merge!(@pagy.headers_hash) if @pagy }

        helper_method :current_parent, :current_nested_association, :resource_record!, :resource_record?, :resource_param_key, :resource_class,
          :singular_resource_context?, :singular_resource_route_for?

        # Use class_attribute for proper inheritance
        class_attribute :_resource_class, instance_accessor: false
      end

      class_methods do
        # include Plutonium::Lib::SmartCache

        # Sets the resource class for the controller
        # @param [ActiveRecord::Base] resource_class The resource class
        def controller_for(resource_class)
          self._resource_class = resource_class
        end

        # Gets the resource class for the controller
        # @return [ActiveRecord::Base] The resource class
        def resource_class
          return _resource_class if _resource_class

          base_name = name.to_s.gsub(/^#{current_package}::/, "").gsub(/Controller$/, "")
          singularized_name = base_name.singularize.camelize

          # Use singularize + camelize to respect custom inflections
          singularized_name.constantize
        rescue NameError
          # Check if inflection is the issue (e.g., PostMetadata -> PostMetadatum)
          if base_name != singularized_name && base_name.camelize.safe_constantize
            raise NameError, <<~MSG.squish
              Failed to determine the resource class for #{name}.
              Rails singularized "#{base_name}" to "#{singularized_name}", but "#{base_name.camelize}" exists.
              Add an inflection rule to config/initializers/inflections.rb.
              See: https://radioactive-labs.github.io/plutonium-core/guides/troubleshooting
            MSG
          end

          raise NameError, "Failed to determine the resource class. Please call `controller_for(MyResource)` in #{name}."
        end
        # memoize_unless_reloading :resource_class
      end

      private

      # Override to prepend parent label for nested resources in the browser tab title.
      # e.g., "John Doe › Authored Comments"
      def set_page_title(page_title)
        @page_title = if current_parent
          "#{current_parent.to_label} › #{page_title}"
        else
          page_title
        end
      end

      def resource_class
        if current_parent
          # Nested route: resource_class must come from route config
          current_resource_route_config&.dig(:resource_class) or
            raise "No resource_class found in route config for nested route"
        else
          self.class.resource_class
        end
      end

      def resource_record_relation
        @resource_record_relation ||= begin
          resource_route_config = current_resource_route_config
          if resource_route_config[:route_type] == :resource
            current_authorized_scope
          elsif params[:id]
            current_authorized_scope.from_path_param(params[:id])
          else
            current_authorized_scope.none
          end
        end
      end

      def current_resource_route_config
        # The nested registration when the route says it is nested, and the
        # top-level one otherwise. Previously rebuilt the nested lookup key from
        # the parent's class and the association — which meant resolving the
        # parent first, and reconstructing a string the router was already
        # carrying.
        @current_resource_route_config ||=
          current_nested_route_config ||
          current_engine.routes.resource_route_config_for(resource_class.model_name.plural)[0]
      end

      # Returns true if current resource is registered as a singular route
      # (e.g., `resource :profile` vs `resources :users`)
      # @return [Boolean]
      def singular_resource_context?
        current_resource_route_config&.[](:route_type) == :resource
      end

      # The same question asked about another resource — a breadcrumb needs to
      # know whether the parent it is linking to has an index before it builds a
      # collection URL for one.
      # @param resource_class [Class]
      # @return [Boolean]
      def singular_resource_route_for?(resource_class)
        current_engine.routes.singular_resource_route?(resource_class.model_name.plural)
      end

      # The association this request is nested through, as declared by the
      # route. Previously scraped out of the request path by looking for a
      # "nested_" segment, which meant stripping format extensions and could
      # not survive a parent that contributes no id parameter.
      # @return [Symbol, nil] The association name
      def current_nested_association
        current_nested_route_config&.[](:association_name)
      end

      def resource_record!
        @resource_record ||= resource_record_relation.first!
      end

      def resource_record?
        @resource_record ||= resource_record_relation.first
      end

      # Returns the submitted resource parameters
      # @return [Hash] The submitted resource parameters
      def submitted_resource_params
        # Use existing record (cloned) for context during param extraction, or new instance for create
        # Pass form_action: false to prevent form from trying to generate URL (cloned record has id: nil)
        extraction_record = resource_record?&.dup || resource_class.new
        @submitted_resource_params ||= begin
          # Pre-populate from submitted params so condition: procs evaluate against submitted
          # values during extraction. Without this, a select whose choices: depend on a sibling
          # attribute would see nil for that sibling (fresh/cloned record) and resolve to empty
          # choices, causing AcceptsChoices to nullify a valid submitted value.
          # attribute_names covers DB columns and `attribute :` declarations.
          # The union with respond_to? also covers attr_accessor virtual attributes.
          submitted = params[resource_param_key]&.to_unsafe_h || {}
          base_keys = extraction_record.attribute_names.map(&:to_s)
          # Also include attr_accessor virtual attributes not in attribute_names.
          # Exclude AR association writers — they expect object instances, not param strings.
          extra_keys = (submitted.keys.map(&:to_s) - base_keys).select { |k|
            extraction_record.respond_to?("#{k}=") &&
              extraction_record.class.reflect_on_association(k.to_sym).nil?
          }
          # Never assign attachment/file inputs to the throwaway extraction_record:
          # the submitted value is a single-read Rack upload (UploadedFile), and a
          # Shrine attacher consumes it to EOF on assign — so the later
          # `resource_class.new(resource_params)` would re-read a closed stream
          # ("IOError: closed stream"). Active Storage escaped this because its
          # attachment reflects as an association (excluded above); Shrine's virtual
          # `file=` accessor does not, so exclude file inputs explicitly. The value
          # still reaches create/update via `extract_input` (which reads params, not
          # this record), so nothing is dropped — the file is just read once, later.
          assign_keys = (base_keys | extra_keys) - attachment_input_keys
          extraction_record.assign_attributes(submitted.slice(*assign_keys))
          extracted = build_form(extraction_record, form_action: false)
            .extract_input(params, view_context:)[resource_param_key.to_sym].compact
          clean_structured_inputs(current_definition, extracted)
        end
      end

      # Attachment/file input names (as Strings) declared on the current
      # definition — inputs whose `as:` is a file type (`:file`/`:uppy`/
      # `:attachment`). Excluded from the extraction-record pre-assignment so a
      # single-read Rack upload isn't consumed before create/update reads it.
      def attachment_input_keys
        current_definition.defined_inputs.filter_map { |name, config|
          name.to_s if Plutonium::Definition::InputAliases.file_input?(config.dig(:options, :as))
        }
      end

      # Returns the resource parameters, including scoped and parent parameters
      # @return [Hash] The resource parameters
      def resource_params
        @resource_params ||= begin
          input_params = submitted_resource_params.dup
          override_entity_scoping_params(input_params)
          override_parent_params(input_params)

          input_params
        end
      end

      # Returns the resource parameter key
      # @return [Symbol] The resource parameter key (for form params)
      def resource_param_key
        resource_class.model_name.param_key
      end

      # Creates a resource context
      # @return [Plutonium::Resource::Context] The resource context
      def resource_context
        Plutonium::Resource::Context.new(
          resource_class:,
          parent: current_parent,
          scope: scoped_to_entity? ? current_scoped_entity : nil
        )
      end

      # Creates a resource definition
      # @param [Class] resource_class The resource class
      # @return [Object] The resource definition
      def resource_definition(resource_class)
        definition_class = [current_package, "#{resource_class}Definition"].compact.join("::").constantize
        definition_class.new
      rescue NameError
        super
      end

      # Applies submitted resource params if they have been passed
      def maybe_apply_submitted_resource_params!
        ensure_get_request
        resource_record!.attributes = submitted_resource_params if params[resource_param_key]
      end

      # Returns the current parent based on path parameters
      # @return [ActiveRecord::Base, nil] The current parent
      # The record this request is nested under, if any.
      #
      # The route says which parent it nests under (see
      # Plutonium::Routing::PARENT_KEY_PARAM); all that is
      # left is to load it. A plural parent narrows by the id in the path. A
      # singular parent has no id to narrow by — it is whichever record the
      # viewer's scope resolves to, the same rule resource_record_relation
      # applies when the current resource is itself singular.
      #
      # Memoised through `defined?` so a genuine nil is remembered rather than
      # re-resolved on every call.
      def current_parent
        return @current_parent if defined?(@current_parent)

        @current_parent = begin
          parent_class = current_parent_class
          if parent_class
            scope = authorized_scope(parent_class.all, context: {entity_scope: entity_scope_for_authorize})
            scope = scope.from_path_param(params[parent_route_param]) if parent_route_param
            scope.first!.tap { |parent| authorize! parent, to: :read? }
          end
        end
      end

      # The parent resource class, taken from the registration rather than
      # re-derived from a name. Registration had the class in hand; carrying the
      # name instead would mean looking it back up by a string that two
      # differently-namespaced resources can share.
      # @return [Class, nil]
      def current_parent_class
        current_nested_route_config&.[](:parent_class)
      end

      # The registration for the nesting this request arrived through, if any.
      # @return [Hash, nil]
      def current_nested_route_config
        return @current_nested_route_config if defined?(@current_nested_route_config)

        nested_key = request.path_parameters[Plutonium::Routing::NESTED_KEY_PARAM]
        @current_nested_route_config =
          nested_key && current_engine.routes.resource_route_config_lookup[nested_key]
      end

      # Returns the parent route parameter
      # @return [Symbol, nil] The parent route parameter
      def parent_route_param
        @parent_route_param ||= request.path_parameters.keys.reverse.find { |key| /_id$/.match? key }
      end

      # Returns the parent input parameter (the belongs_to association name on the child)
      # Finds the belongs_to association on the child that matches the parent's foreign key
      # @return [Symbol, nil] The parent input parameter
      def parent_input_param
        return unless current_parent

        unless current_nested_association
          raise "parent exists but current_nested_association is nil - routing misconfiguration"
        end

        parent_assoc = current_parent.class.reflect_on_association(current_nested_association)
        unless parent_assoc
          raise "#{current_parent.class} does not have association :#{current_nested_association}"
        end

        # Try inverse_of first (if explicitly set)
        return parent_assoc.inverse_of.name.to_sym if parent_assoc.inverse_of

        # Fall back to finding belongs_to by foreign key
        foreign_key = parent_assoc.foreign_key.to_s
        child_assoc = resource_class.reflect_on_all_associations(:belongs_to).find do |assoc|
          assoc.foreign_key.to_s == foreign_key && assoc.klass == current_parent.class
        end
        child_assoc&.name&.to_sym
      end

      # Ensures the method is a GET request
      def ensure_get_request
        unless request.method == "GET"
          raise "🚨🚨🚨 This should be called from actions that are not persisting this data"
        end
      end

      # Overrides entity scoping parameters
      # @param [Hash] input_params The input parameters
      def override_entity_scoping_params(input_params)
        return unless scoped_to_entity?

        # Use the detected association if available, otherwise fall back to param_key
        assoc_name = scoped_entity_association || scoped_entity_param_key

        if input_params.key?(assoc_name) || resource_class.method_defined?(:"#{assoc_name}=")
          input_params[assoc_name] = current_scoped_entity
        end

        if input_params.key?(:"#{assoc_name}_id") || resource_class.method_defined?(:"#{assoc_name}_id=")
          input_params[:"#{assoc_name}_id"] = current_scoped_entity.id
        end
      end

      # Overrides parent parameters
      # @param [Hash] input_params The input parameters
      def override_parent_params(input_params)
        if current_parent
          if input_params.key?(parent_input_param) || resource_class.method_defined?(:"#{parent_input_param}=")
            input_params[parent_input_param] = current_parent
          end

          if input_params.key?(:"#{parent_input_param}_id") || resource_class.method_defined?(:"#{parent_input_param}_id=")
            input_params[:"#{parent_input_param}_id"] = current_parent.id
          end
        end
      end

      # Constructs resource URL arguments
      # @param [Array] args The URL arguments
      # @param [Hash] kwargs The keyword arguments
      # @return [Array] The URL arguments
      def resource_url_args_for(*, **kwargs)
        kwargs[:parent] = current_parent unless kwargs.key?(:parent)
        # Pass the current association when in a nested context
        if kwargs[:parent] && !kwargs.key?(:association) && current_nested_association
          kwargs[:association] = current_nested_association
        end
        super
      end
    end
  end
end
