# frozen_string_literal: true

module Plutonium
  module Portal
    module Engine
      extend ActiveSupport::Concern
      include Plutonium::Engine
      include Plutonium::Package::Engine

      included do
        isolate_namespace to_s.deconstantize.constantize
      end
    end
  end
end
