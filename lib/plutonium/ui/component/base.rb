# frozen_string_literal: true

require "phlex"

module Plutonium
  module UI
    module Component
      class Base < (defined?(::ApplicationComponent) ? ::ApplicationComponent : Phlex::HTML)
        include Plutonium::UI::Component::Behaviour
      end
    end
  end
end
