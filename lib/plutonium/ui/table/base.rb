# frozen_string_literal: true

require "phlexi-form"

module Plutonium
  module UI
    module Table
      class Base < Phlexi::Table::Base
        include Plutonium::UI::Component::Behaviour
      end
    end
  end
end
