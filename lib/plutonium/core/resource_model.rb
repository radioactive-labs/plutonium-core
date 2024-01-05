module Plutonium
  module Core
    module ResourceModel
      def self.included(base)
        base.send :scope, :from_path_param, ->(param) { where(id: param) }
        base.send :extend, ClassMethods
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
      end
    end
  end
end
