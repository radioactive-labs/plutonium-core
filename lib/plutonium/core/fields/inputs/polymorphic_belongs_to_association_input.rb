module Plutonium
  module Core
    module Fields
      module Inputs
        class PolymorphicBelongsToAssociationInput < SimpleFormAssociationInput
          def render(f, record, **opts)
            opts = options.deep_merge opts
            f.input param, **opts
          end

          private

          def param
            :"#{reflection.name}_sgid"
          end

          def input_options
            {
              as: :grouped_select,
              label: reflection.name.to_s.humanize,
              collection: associated_classes.map { |klass|
                            [klass.name, klass.all]
                          }.to_h,
              group_label_method: :first,
              group_method: :last, include_blank: "Select One"
            }
          end

          def associated_classes
            Rails.application.eager_load! unless Rails.application.config.eager_load

            associated_classes = []
            ActiveRecord::Base.descendants.each do |model|
              next unless model.table_exists?
              model.reflect_on_all_associations(:has_many).each do |association|
                if association.options[:as] == reflection.name
                  associated_classes << model.name
                end
              end
            end
            associated_classes
          end
        end
      end
    end
  end
end
