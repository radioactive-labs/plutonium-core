# frozen_string_literal: true

module Plutonium
  module UI
    module Table
      class Base < Phlexi::Table::Base
        include Plutonium::UI::Component::Behaviour
      end
    end
  end
end
