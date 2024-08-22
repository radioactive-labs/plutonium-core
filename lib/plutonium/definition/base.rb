# frozen_string_literal: true

require "phlexi-form"

module Plutonium
  module Definition
    # Base class for Plutonium definitions
    #
    # @abstract Subclass and override {#customize_fields}, {#customize_inputs},
    #   {#customize_filters}, {#customize_scopes}, and {#customize_sorters}
    #   to implement custom behavior.
    #
    # @example
    #   class MyDefinition < Plutonium::Definition::Base
    #     field :name, as: :string
    #     input :email, as: :email
    #     filter :status, type: :select, collection: %w[active inactive]
    #     scope :active, default: true
    #     sorter :created_at
    #
    #     def customize_fields
    #       field :custom_field, as: :integer
    #     end
    #   end
    #
    # @note This class is not thread-safe. Ensure proper synchronization
    #   if used in a multi-threaded environment.
    class Base
      include DefineableProperties

      class Form < Phlexi::Form::Base
      end

      defineable_property :field
      defineable_property :input
      defineable_property :filter
      defineable_property :scope
      defineable_property :sorter

      def initialize
        super
      end

      private

      def form_class
        self.class::Form
      end
    end
  end
end
