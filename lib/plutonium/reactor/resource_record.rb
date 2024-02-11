module Plutonium
  module Reactor
    module ResourceRecord
      extend ActiveSupport::Concern

      included do
        scope :from_path_param, ->(param) { where(id: param) }
        scope :for_parent, ->(parent) { all }
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
