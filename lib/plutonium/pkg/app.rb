# frozen_string_literal: true

module Plutonium
  module Pkg
    module App
      extend ActiveSupport::Concern
      include Plutonium::Pkg::Base
      include Plutonium::Application::Engine

      included do
        isolate_namespace to_s.deconstantize.constantize
      end
    end
  end
end
