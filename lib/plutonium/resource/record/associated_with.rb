# frozen_string_literal: true

module Plutonium
  module Resource
    module Record
      module AssociatedWith
        extend ActiveSupport::Concern

        included do
          scope :associated_with, ->(record) do
            # If scoping to same class, just match by ID (e.g., Team scoped to Team)
            # Compare by name to handle Rails class reloading (different object_id after reload)
            if klass.name == record.class.name
              pk = klass.primary_key
              return where(pk => record.public_send(pk))
            end

            named_scope = :"associated_with_#{record.model_name.singular}"
            return send(named_scope, record) if respond_to?(named_scope)

            own_association = klass.find_association_from_self_to_record(record)
            if own_association
              return klass.query_based_on_association(own_association, record)
            end

            record_association = klass.find_association_to_self_from_record(record)
            if record_association
              Plutonium.logger.warn do
                [
                  "Using indirect association from #{record.class} to #{klass.name}",
                  "via '#{record_association.name}'.",
                  "This may result in poor query performance for large datasets",
                  "as it requires loading records to perform the association.",
                  "",
                  "Consider defining a direct association or implementing",
                  "a custom scope '#{named_scope}' for better performance."
                ].join("\n")
              end
              return where(id: record.public_send(record_association.name))
            end

            klass.raise_unresolvable_association_error(record, named_scope)
          end
        end

        class_methods do
          def find_association_from_self_to_record(record)
            reflect_on_all_associations.find do |assoc|
              assoc.klass.name == record.class.name unless assoc.polymorphic?
            rescue
              assoc.check_validity!
              raise
            end
          end

          def find_association_to_self_from_record(record)
            record.class.reflect_on_all_associations.find do |assoc|
              assoc.klass.name == name
            rescue
              assoc.check_validity!
              raise
            end
          end

          def query_based_on_association(assoc, record)
            case assoc.macro
            when :has_one
              joins(assoc.name).where(assoc.name => {record.class.primary_key => record})
            when :belongs_to
              where(assoc.name => record)
            when :has_many
              joins(assoc.name).where(assoc.name => {record.class.primary_key => record})
            else
              raise NotImplementedError, "associated_with->##{assoc.macro}"
            end
          end

          def raise_unresolvable_association_error(record, named_scope)
            raise "Could not resolve the association between '#{name}' and '#{record.class.name}'\n\n" \
                  "Define\n" \
                  " 1. the associations between the models\n" \
                  " 2. a named scope on #{name} e.g.\n\n" \
                  "scope :#{named_scope}, ->(#{record.model_name.singular}) { do_something_here }"
          end
        end
      end
    end
  end
end
