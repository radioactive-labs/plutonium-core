module Plutonium
  module Core
    module Fields
      class Input
        class << self
          def for_resource_attribute(resource_class, attr_name, type: nil, **)
            # column = resource_class.column_for_attribute attr_name if resource_class.respond_to? :column_for_attribute
            # if resource_class.respond_to? :reflect_on_association
            #   attachment = resource_class.reflect_on_association(:"#{attr_name}_attachment") || resource_class.reflect_on_association(:"#{attr_name}_attachments")
            #   association = resource_class.reflect_on_association(attr_name)
            # end

            # type ||= :slim_select if options.key? :collection

            # if attachment.present?
            #   type ||= :attachment
            #   options[:multiple] = true if options[:multiple].nil? && attachment.macro == :has_many
            # elsif association.present?
            #   type ||= :association
            # elsif column.present?
            #   type ||= column.type
            #   options[:multiple] = column.array? if options[:multiple].nil? && column.respond_to?(:array?)
            # end

            if resource_class.try(:reflect_on_association, attr_name).present?
              Plutonium::Core::Fields::Inputs::AssociationInput.new(resource_class, attr_name, **)
            else
              Plutonium::Core::Fields::Inputs::BasicInput.new(resource_class, attr_name, **)
            end
          end
        end

        attr_reader :resource_class, :name, :user_options

        def initialize(resource_class, name, **user_options)
          @resource_class = resource_class
          @name = name
          @user_options = user_options
        end

        def input_options = {}.freeze

        def options = @options ||= input_options.deep_merge(@user_options)

        def render(f, record) = raise NotImplementedError, "#{self.class} must implement #render"

        def param = name

        def collect(params)
          # Handles multi parameter attributes
          # https://www.cookieshq.co.uk/posts/rails-spelunking-date-select
          # https://www.cookieshq.co.uk/posts/multiparameter-attributes

          # Matches
          # - parameter
          # - parameter(1)
          # - parameter(2)
          # - parameter(1i)
          # - parameter(2f)
          regex = /^#{param}(\(\d+[if]?\))?$/

          params.select { |key| regex.match? key }
        end
      end
    end
  end
end
