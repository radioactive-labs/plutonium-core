module Plutonium
  module Reactor
    module ResourceRecord
      extend ActiveSupport::Concern

      included do
        scope :from_path_param, ->(param) { where(id: param) }

        scope :associated_with, ->(record) do
          named_scope = :"associated_with_#{record.model_name.singular}"
          return send(named_scope, record) if respond_to?(named_scope)

          # TODO: add logging
          if (own_association = reflect_on_all_associations.find { |assoc| assoc.klass == record.class })
            case own_association.macro
            when :has_one
              joins(own_association.name).where({
                own_association.name.to_sym => {
                  record.class.primary_key => record.id
                }
              })
            when :belongs_to
              where(own_association.name => record)
            when :has_many
              joins(own_association.name).where(own_association.klass.table_name.to_sym => record)
            else
              raise Net::HTTPNotImplemented, "associated_with->##{own_association.macro}"
            end
          elsif (record_association = record.class.reflect_on_all_associations.find { |assoc| assoc.klass == klass })
            # TODO: add a warning here about a potentially poor performing query
            where(id: record.send(record_association.name))
          else
            raise "Could not resolve the association between '#{klass.name}' and '#{record.class.name}'\n\n" \
                  "Define\n" \
                  " 1. the associations between the models\n" \
                  " 2. a named scope e.g.\n\n" \
                  "scope :#{named_scope}, ->(#{record.model_name.singular}) { do_something_here }"
          end
        end
      end

      module ClassMethods
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

        # Ransack

        def ransackable_attributes(_auth_object = nil)
          _ransackers.keys
        end

        def ransackable_associations(_auth_object = nil)
          [] # reflect_on_all_associations.map { |a| a.name.to_s }
        end

        def ransortable_attributes(auth_object = nil)
          ransackable_attributes(auth_object) + %w[id created_at updated_at]
        end

        def ransackable_scopes(_auth_object = nil)
          []
        end

        def resource_field_names
          @resource_field_names ||= belongs_to_association_field_names + has_one_association_field_names +
            has_many_association_field_names + content_column_field_names
        end

        def belongs_to_association_field_names
          @belongs_to_association_field_names ||= reflect_on_all_associations(:belongs_to).map { |assoc| assoc.name.to_sym }
        end

        def has_one_association_field_names
          @has_one_association_field_names ||= reflect_on_all_associations(:has_one).map { |assoc| assoc.name.to_sym }
        end

        def has_many_association_field_names
          @has_many_association_field_names ||= reflect_on_all_associations(:has_many).map { |assoc| assoc.name.to_sym }
        end

        def content_column_field_names
          @content_column_field_names ||= content_columns.map { |col| col.name.to_sym }
        end

        def has_many_association_routes
          @has_many_association_routes ||= reflect_on_all_associations(:has_many).map { |assoc| assoc.klass.model_name.plural }
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
