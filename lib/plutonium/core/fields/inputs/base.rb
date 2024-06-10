module Plutonium
  module Core
    module Fields
      module Inputs
        class Base
          include Plutonium::Core::Renderable

          attr_reader :name

          # Initializes the Base input class with a name and user-defined options.
          #
          # @param name [String] the name of the input field.
          # @param user_options [Hash] user-defined options for the input field.
          def initialize(name, **user_options)
            @name = name
            @user_options = user_options
          end

          # Collects parameters matching the input field's name with multi-parameter attributes.
          #
          # @param params [Hash] the parameters to collect from.
          # @return [Hash] the collected parameters.
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
            keys = params.select { |key, _| regex.match?(key) }.keys
            params.slice(*keys)
          end

          # Sets the form and record objects on the input field.
          #
          # @param form [Object] the form object.
          # @param record [Object] the record object.
          # @param render_options [Hash] additional options for rendering.
          def with(form:, record:, **render_options)
            @form = form
            @record = record
            @render_options = render_options
            @options = build_options(render_options)

            self
          end

          private

          # Returns input-specific options, can be overridden by subclasses.
          #
          # @return [Hash] the input-specific options.
          def input_options
            {}
          end

          # Returns the parameter name for the input field.
          #
          # @return [String] the parameter name.
          def param
            name
          end

          # Raises an error if #options is accessed before rendering.
          #
          # @raise [RuntimeError] if accessed before rendering.
          # @return [Hash] the rendering options.
          def options
            raise "cannot access #options before calling #with" unless defined?(@options)

            @options
          end

          # Raises an error if #form is accessed before rendering.
          #
          # @raise [RuntimeError] if accessed before rendering.
          # @return [Object] the form object.
          def form
            raise "cannot access #form before calling #with" unless defined?(@form)

            @form
          end

          # Raises an error if #record is accessed before rendering.
          #
          # @raise [RuntimeError] if accessed before rendering.
          # @return [Object] the record object.
          def record
            raise "cannot access #record before calling #with" unless defined?(@record)

            @record
          end

          # Builds the options for rendering by merging input options, user options, and render options.
          #
          # @param render_options [Hash] additional options for rendering.
          # @return [Hash] the merged options.
          def build_options(render_options)
            input_options.deep_merge(@user_options).deep_merge(render_options)
          end
        end
      end
    end
  end
end
