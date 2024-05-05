module Plutonium
  module Resource
    module Record
      extend ActiveSupport::Concern

      included do
        scope :from_path_param, ->(param) { where(id: param) }

        scope :associated_with, ->(record) do
          named_scope = :"associated_with_#{record.model_name.singular}"
          return send(named_scope, record) if respond_to?(named_scope)

          # TODO: add suppport for polymorphic associations
          # TODO: add logging
          # TODO: memoize this

          if (own_association = reflect_on_all_associations.find { |assoc| assoc.klass.name == record.class.name })
            case own_association.macro
            when :has_one
              joins(own_association.name).where({
                own_association.name => {
                  record.class.primary_key => record.id
                }
              })
            when :belongs_to
              where(own_association.name => record)
            when :has_many
              joins(own_association.name).where(own_association.klass.table_name => record)
            else
              raise NotImplementedError, "associated_with->##{own_association.macro}"
            end
          elsif (record_association = record.class.reflect_on_all_associations.find { |assoc| assoc.klass.name == klass.name })
            # TODO: add a warning here about a potentially poor performing query
            where(id: record.send(record_association.name))
          else
            raise "Could not resolve the association between '#{klass.name}' and '#{record.class.name}'\n\n" \
                  "Define\n" \
                  " 1. the associations between the models\n" \
                  " 2. a named scope on #{klass.name} e.g.\n\n" \
                  "scope :#{named_scope}, ->(#{record.model_name.singular}) { do_something_here }"
          end
        end
      end

      class_methods do
        def resource_field_names
          @resource_field_names ||= belongs_to_association_field_names +
            has_one_attached_field_names + has_one_association_field_names +
            has_many_attached_field_names + has_many_association_field_names +
            content_column_field_names
        end

        def belongs_to(name, scope = nil, **options)
          super(name, scope, **options)

          if options[:polymorphic]
            mod = Module.new
            mod.module_eval <<-RUBY, __FILE__, __LINE__ + 1
              extend ActiveSupport::Concern

              def #{name}_sgid
                #{name}&.to_signed_global_id
              end

              def #{name}_sgid=(sgid)
                self.#{name} = GlobalID::Locator.locate_signed(sgid)
              end

              define_singleton_method(:to_s) { "Plutonium::Polymormorphic::BelongsTo(:#{name})" }
              define_singleton_method(:inspect) { "Plutonium::Polymormorphic::BelongsTo(:#{name})" }
            RUBY
            include mod
          end
        end

        def belongs_to_association_field_names
          @belongs_to_association_field_names ||= reflect_on_all_associations(:belongs_to).map(&:name)
        end

        def has_one_association_field_names
          @has_one_association_field_names ||= reflect_on_all_associations(:has_one)
            .map { |assoc| /_attachment$|_blob$/.match?(assoc.name) ? nil : assoc.name }
            .compact
        end

        def has_many_association_field_names
          @has_many_association_field_names ||= reflect_on_all_associations(:has_many)
            .map { |assoc| /_attachments$|_blobs$/.match?(assoc.name) ? nil : assoc.name }
            .compact
        end

        def has_one_attached_field_names
          @has_one_attached_field_names ||= if respond_to?(:reflect_on_all_attachments)
            reflect_on_all_attachments
              .map { |a| (a.macro == :has_one_attached) ? a.name : nil }
              .compact
          else
            []
          end
        end

        def has_many_attached_field_names
          @has_many_attached_field_names ||= if respond_to?(:reflect_on_all_attachments)
            reflect_on_all_attachments
              .map { |a| (a.macro == :has_many_attached) ? a.name : nil }
              .compact
          else
            []
          end
        end

        def content_column_field_names
          @content_column_field_names ||= content_columns.map { |col| col.name.to_sym }
        end

        def has_many_association_routes
          @has_many_association_routes ||= reflect_on_all_associations(:has_many).map { |assoc| assoc.klass.model_name.plural }
        end

        def all_nested_attributes_options
          unless Rails.env.local?
            return @all_nested_attributes_options if defined?(@all_nested_attributes_options)
          end

          @all_nested_attributes_options = reflect_on_all_associations.map do |association|
            setter_method = "#{association.name}_attributes="
            if method_defined?(setter_method)
              [association.name, {
                **nested_attributes_options[association.name],
                macro: association.macro,
                class: association.polymorphic? ? nil : association.klass
              }]
            end
          end.compact.to_h
        end

        #
        # Returns the strong parameters definition for the given attribute names
        #
        # @param [Array] *attributes Attribute names
        #
        # @return [Array] A strong parameters compatible array e.g.
        #   [:title, :body, {:images=>[]}, {:docs=>[]}]
        #
        def strong_parameters_for(*attributes)
          # attributes that are passed but we do not have a model/database backed definition for e.g. virtual attributes.
          # if they are passed and we are not expecting them, our inputs will filter them out as they apply an additional level
          # of filtering
          unbacked = attributes - strong_parameters_definition.keys

          # attributes backed by some model/database definition
          # {:name=>{:name=>nil}, :body=>{:body=>nil}, :cover_image=>{:cover_image=>nil}, :comments=>{:comment_ids=>[]}}
          backed = strong_parameters_definition.
            # {:name=>{:name=>nil}, :comments=>{:comment_ids=>[]}, :cover_image=>{:cover_image=>nil}}
            slice(*attributes).
            # [{:name=>nil}, {:comment_ids=>[]}, {:cover_image=>nil}]
            values.
            # {:name=>nil, :comment_ids=>[], :cover_image=>nil}
            reduce(:merge)&.
            # [:name, {:comment_ids=>[]}, :cover_image]
            map { |key, value| value.nil? ? key : {key => value} } || {}

          unbacked + backed
        end

        private

        def strong_parameters_definition
          unless Rails.env.local?
            return @strong_parameters if defined?(@strong_parameters)
          end

          @strong_parameters = begin
            # Columns

            content_column_parameters = content_column_field_names.map do |name|
              column = columns_hash[name.to_s]

              type = nil
              type = [] if column&.try(:array?)
              type = {} if [:json, :jsonb].include?(column&.type)

              [name, {name => type}]
            end
            parameters = content_column_parameters.to_h

            # Associations

            parameters.merge! reflect_on_all_associations(:belongs_to)
              .map { |reflection|
                                input_param = reflection.respond_to?(:options) ? reflection.options[:foreign_key] : :"#{reflection.name}_id"
                                [reflection.name, {input_param => nil}]
                              }
              .to_h

            parameters.merge! has_many_association_field_names
              .map { |name| [name, {"#{name.to_s.singularize}_ids": []}] }
              .to_h

            # Attachments

            parameters.merge! has_many_attached_field_names.map { |name| [name, {name => []}] }.to_h

            parameters.merge! has_one_attached_field_names.map { |name| [name, {name => nil}] }.to_h

            # Nested Attributes

            parameters.merge! all_nested_attributes_options.keys
              .map { |name| [name, {"#{name}_attributes" => {}}] }
              .to_h

            # e.g.
            # {:name=>{:name=>nil}, :cover_image=>{:cover_image=>nil}, :user=>{:user_id=>nil} :comments=>{:comment_ids=>[]}}
            parameters
          end
        end

        # Path parameters

        def path_parameter(param_name)
          param_name = param_name.to_sym

          scope :from_path_param, ->(param) { where(param_name => param) }

          define_method :to_param do
            return nil unless persisted?

            send param_name
          end
        end

        def dynamic_path_parameter(param_name)
          param_name = param_name.to_sym

          scope :from_path_param, ->(param) { where(id: param.split("-").first) }

          define_method :to_param do
            return nil unless persisted?

            "#{id}-#{send(param_name)}".parameterize
          end
        end
      end

      def to_label
        %i[name title].each do |method|
          name = send(method) if respond_to?(method)
          return name if name.present?
        end

        "#{model_name.human} ##{to_param}"
      end
    end
  end
end
