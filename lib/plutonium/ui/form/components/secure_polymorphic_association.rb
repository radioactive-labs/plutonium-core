# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      module Components
        class SecurePolymorphicAssociation < SecureAssociation
          protected

          def build_attributes
            attributes.fetch(:group_method) { attributes[:group_method] = :last }
            super
          end

          def choices
            @choices ||= begin
              Plutonium.eager_load_rails!
              collection = if (user_choices = attributes.delete(:choices))
                user_choices
              else
                associated_classes.map { |klass|
                  [
                    klass.model_name.human.pluralize,
                    @skip_authorization ? choices_from_association(klass) : authorized_resource_scope(klass, relation: choices_from_association(klass))
                  ]
                }.to_h
              end
              build_choice_mapper(collection)
            end
          end

          def associated_classes
            Plutonium.eager_load_rails!

            associated_classes = []
            ActiveRecord::Base.descendants.each do |model_klass|
              next if !model_klass.table_exists? || model_klass.abstract_class?

              (model_klass.reflect_on_all_associations(:has_many) + model_klass.reflect_on_all_associations(:has_one)).each do |association|
                if association.options[:as] == association_reflection.name
                  associated_classes << model_klass
                end
              end
            end
            associated_classes
          end

          def render_add_button
          end
        end
      end
    end
  end
end
