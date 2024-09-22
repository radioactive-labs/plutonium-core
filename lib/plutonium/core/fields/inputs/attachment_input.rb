module Plutonium
  module Core
    module Fields
      module Inputs
        class AttachmentInput < SimpleFormInput
          attr_reader :reflection

          def initialize(name, reflection:, **)
            @reflection = reflection
            super(name, **)
          end

          private

          def input_options
            options = {attachment: true} # enable the attachment component
            options[:input_html] = {multiple: true} if reflection.macro == :has_many_attached
            options
          end
        end
      end
    end
  end
end
