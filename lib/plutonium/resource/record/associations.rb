# frozen_string_literal: true

# lib/plutonium/resource/associations.rb
module Plutonium
  module Resource
    module Record
      module Associations
        extend ActiveSupport::Concern

        class_methods do
          def belongs_to(name, scope = nil, **options)
            super
            include_secure_association_methods(:belongs_to, name)
          end

          def has_one(name, scope = nil, **options)
            super
            include_secure_association_methods(:has_one, name)
          end

          def has_many(name, scope = nil, **options)
            super
            include_secure_association_methods(:has_many, name)
          end

          def has_and_belongs_to_many(name, scope = nil, **options)
            super
            include_secure_association_methods(:has_and_belongs_to_many, name)
          end

          private

          def include_secure_association_methods(association_type, name)
            mod = Module.new
            mod.module_eval <<-RUBY, __FILE__, __LINE__ + 1
              extend ActiveSupport::Concern

              #{generate_sgid_methods(association_type, name)}

              define_singleton_method(:to_s) { "Plutonium::Resource::Record::Associations::#{association_type.to_s.camelize}(:#{name})" }
              define_singleton_method(:inspect) { "Plutonium::Resource::Record::Associations::#{association_type.to_s.camelize}(:#{name})" }
            RUBY
            include mod
          end

          def generate_sgid_methods(association_type, name)
            case association_type
            when :belongs_to, :has_one
              generate_singular_sgid_methods(name)
            when :has_many, :has_and_belongs_to_many
              generate_collection_sgid_methods(name)
            end
          end

          def generate_singular_sgid_methods(name)
            <<-RUBY
              def #{name}_sgid
                #{name}&.to_signed_global_id
              end

              def #{name}_sgid=(sgid)
                self.#{name} = GlobalID::Locator.locate_signed(sgid)
              end
            RUBY
          end

          def generate_collection_sgid_methods(name)
            <<-RUBY
              def #{name.to_s.singularize}_sgids
                #{name}.map(&:to_signed_global_id)
              end

              def #{name.to_s.singularize}_sgids=(sgids)
                self.#{name} = GlobalID::Locator.locate_many_signed(sgids)
              end

              def add_#{name.to_s.singularize}_sgid(sgid)
                record = GlobalID::Locator.locate_signed(sgid)
                #{name} << record if record
              end

              def remove_#{name.to_s.singularize}_sgid(sgid)
                record = GlobalID::Locator.locate_signed(sgid)
                #{name}.delete(record) if record
              end
            RUBY
          end
        end
      end
    end
  end
end
