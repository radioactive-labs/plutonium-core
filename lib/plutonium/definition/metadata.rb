# frozen_string_literal: true

module Plutonium
  module Definition
    # Adds the `metadata` DSL — a list of field names rendered in the
    # show page's right-side panel as label/value rows. Opt-in: when no
    # `metadata` call is made, the show page stays full-width with no
    # aside.
    #
    # @example
    #   class PostDefinition < Plutonium::Definition::Base
    #     metadata :created_at, :updated_at, :author, :state
    #   end
    module Metadata
      extend ActiveSupport::Concern

      included do
        class_attribute :defined_metadata_fields, default: [], instance_accessor: false
      end

      class_methods do
        # Declares the fields rendered in the show page metadata panel.
        # Each name is looked up in `defined_fields` for display config
        # (label/format), so a field can have custom formatting in the
        # main show body and the panel without redeclaring.
        #
        # @param names [Array<Symbol>]
        def metadata(*names)
          self.defined_metadata_fields = names.flatten.map(&:to_sym)
        end
      end

      # class_attribute is declared with instance_accessor: false; expose
      # an instance reader that delegates so callers with a definition
      # instance (e.g. `current_definition`) can ask without poking the
      # class directly. Mirrors Definition::Views.
      def defined_metadata_fields = self.class.defined_metadata_fields
    end
  end
end
