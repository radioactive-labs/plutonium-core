# frozen_string_literal: true

module Plutonium
  module Rbac
    module Policy
      # Prepended onto every RBAC policy class AND each subclass (via
      # inherited), so a subclass's own permitted_attributes_for_* override is
      # wrapped too. Filtering twice up the chain is harmless (idempotent).
      module AttributeFilter
        READ_SIDE = %i[read index show export].freeze
        WRITE_SIDE = %i[create update new edit].freeze

        (READ_SIDE + WRITE_SIDE).each do |action|
          mode = READ_SIDE.include?(action) ? :read : :write
          define_method(:"permitted_attributes_for_#{action}") do
            rbac_filter_attributes(super(), mode)
          end
        end

        private

        def rbac_filter_attributes(attributes, mode)
          restricted = self.class.rbac_restricted_attribute_names
          return attributes if restricted.empty?

          attributes.reject do |attribute|
            restricted.include?(attribute) && !granted?("#{rbac_resource_key}.#{attribute}.#{mode}")
          end
        end
      end
    end
  end
end
