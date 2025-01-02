# frozen_string_literal: true

# lib/plutonium/resource/associations.rb
module Plutonium
  module Resource
    module Record
      module FieldNames
        extend ActiveSupport::Concern

        class_methods do
          def resource_field_names
            return @resource_field_names if defined?(@resource_field_names) && !Rails.env.local?

            @resource_field_names = gather_resource_field_names
          end

          def belongs_to_association_field_names
            return @belongs_to_association_field_names if defined?(@belongs_to_association_field_names) && !Rails.env.local?

            @belongs_to_association_field_names = reflect_on_all_associations(:belongs_to).map(&:name)
          end

          def has_one_association_field_names
            return @has_one_association_field_names if defined?(@has_one_association_field_names) && !Rails.env.local?

            @has_one_association_field_names = reflect_on_all_associations(:has_one)
              .map { |assoc| (!/_attachment$|_blob$/.match?(assoc.name)) ? assoc.name : nil }
              .compact
          end

          def has_many_association_field_names
            return @has_many_association_field_names if defined?(@has_many_association_field_names) && !Rails.env.local?

            @has_many_association_field_names = reflect_on_all_associations(:has_many)
              .map { |assoc| (!/_attachments$|_blobs$/.match?(assoc.name)) ? assoc.name : nil }
              .compact
          end

          def has_one_attached_field_names
            return @has_one_attached_field_names if defined?(@has_one_attached_field_names) && !Rails.env.local?

            @has_one_attached_field_names = if respond_to?(:reflect_on_all_attachments)
              reflect_on_all_attachments
                .select { |a| a.macro == :has_one_attached }
                .map(&:name)
            else
              []
            end
          end

          def has_many_attached_field_names
            return @has_many_attached_field_names if defined?(@has_many_attached_field_names) && !Rails.env.local?

            @has_many_attached_field_names = if respond_to?(:reflect_on_all_attachments)
              reflect_on_all_attachments
                .select { |a| a.macro == :has_many_attached }
                .map(&:name)
            else
              []
            end
          end

          def content_column_field_names
            return @content_column_field_names if defined?(@content_column_field_names) && !Rails.env.local?

            @content_column_field_names = content_columns.map { |col| col.name.to_sym }
          end

          private

          def gather_resource_field_names
            belongs_to_association_field_names +
              has_one_attached_field_names +
              has_one_association_field_names +
              has_many_attached_field_names +
              has_many_association_field_names +
              content_column_field_names
          end
        end
      end
    end
  end
end
