module Plutonium
  module Resource
    class Definition < Plutonium::Definition::Base
      class_attribute :modal_mode, default: :slideover, instance_accessor: false

      def self.modal(mode)
        raise ArgumentError, "modal must be :centered or :slideover, got #{mode.inspect}" unless [:centered, :slideover].include?(mode)
        self.modal_mode = mode
      end

      def modal
        self.class.modal_mode
      end
    end
  end
end
