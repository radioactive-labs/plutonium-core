module Plutonium
  module Reactor
    module ResourceRecord
      extend ActiveSupport::Concern

      included do
        scope :from_path_param, ->(param) { where(id: param) }

        scope :associated_with, ->(record) do
          custom_scope = :"associated_with_#{record.model_name.singular}"
          return send(custom_scope, record) if respond_to?(custom_scope)

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
            else
              joins(own_association.name).where(own_association.klass.table_name.to_sym => record)
            end
          elsif (record_association = record.class.reflect_on_all_associations.find { |assoc| assoc.klass == klass })
            # TODO: add a warning here about a potentially poor performing query
            where(id: record.send(record_association.name))
          else
            raise "Could not resolve association between '#{klass.name}' and '#{record.class.name}'"
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

        def resource_fields
          @resource_fields ||= begin
            belongs_to = reflect_on_all_associations(:belongs_to).map { |assoc| assoc.name.to_sym }
            has_one = reflect_on_all_associations(:has_one).map { |assoc| assoc.name.to_sym }
            has_many = reflect_on_all_associations(:has_many).map { |assoc| assoc.name.to_sym }
            content_columns = self.content_columns.map { |col| col.name.to_sym }
            belongs_to + has_one + content_columns + has_many
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
