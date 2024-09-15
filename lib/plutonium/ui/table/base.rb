# frozen_string_literal: true

module Plutonium
  module UI
    module Table
      class Base < Phlexi::Table::Base
        include Plutonium::UI::Component::Behaviour

        class Display < Plutonium::UI::Display::Base; end
      end
    end
  end
end
