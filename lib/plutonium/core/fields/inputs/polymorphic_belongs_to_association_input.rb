module Plutonium
  module Core
    module Fields
      module Inputs
        class PolymorphicBelongsToAssociationInput < SimpleFormAssociationInput
          def render
            form.input param, **options
          end

          private

          def param
            :"#{reflection.name}_sgid"
          end

          def input_options
            collection = @user_options.delete(:collection).presence || associated_classes
            {
              as: :grouped_select,
              collection:,
              label: reflection.name.to_s.humanize,
              group_label_method: :first,
              group_method: :last, include_blank: "Select One"
            }
          end

          def associated_classes
            Plutonium.eager_load_rails!

            associated_classes = []
            ActiveRecord::Base.descendants.each do |model|
              next unless model.table_exists?
              model.reflect_on_all_associations(:has_many).each do |association|
                if association.options[:as] == reflection.name
                  associated_classes << model
                end
              end
            end

            associated_classes.map { |klass|
              [klass.name, klass.all]
            }.to_h
          end
        end
      end
    end
  end
end
