module Plutonium
  module Core
    module Associations
      module Renderers
        class Base
          include Plutonium::Core::Renderable

          attr_reader :name, :reflection

          def initialize(name, reflection:, **user_options)
            @name = name
            @reflection = reflection
            @user_options = user_options
          end

          # Sets the record object on the renderer and merges render options.
          #
          # @param record [Object] the record object.
          # @param render_options [Hash] additional options for rendering.
          # @return [self] the renderer instance.
          def with(record:, **render_options)
            @record = record
            @render_options = render_options
            @options = build_options(render_options)

            self
          end

          private

          # Returns the merged options for rendering.
          #
          # @raise [RuntimeError] if accessed before rendering.
          # @return [Hash] the merged options.
          def options
            raise "cannot access #options before calling #with" unless defined?(@options)

            @options
          end

          # Returns the record object.
          #
          # @raise [RuntimeError] if accessed before rendering.
          # @return [Object] the record object.
          def record
            raise "cannot access #record before calling #with" unless defined?(@record)

            @record
          end

          def renderer_options
            {}
          end

          def label
            options[:label] || record.class.human_attribute_name(name)
          end

          # Returns the value of the record's attribute corresponding to the renderer's name.
          #
          # @return [Object] the value of the attribute.
          def value
            record.public_send(name)
          end

          # Builds the options for rendering by merging renderer options, user options, and render options.
          #
          # @param render_options [Hash] additional options for rendering.
          # @return [Hash] the merged options.
          def build_options(render_options)
            renderer_options.deep_merge(@user_options).deep_merge(render_options)
          end
        end
      end
    end
  end
end
