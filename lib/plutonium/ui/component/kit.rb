# frozen_string_literal: true

require "phlex"

module Plutonium
  module UI
    module Component
      module Kit
        extend ActiveSupport::Concern

        def Breadcrumbs(...) = render Plutonium::UI::Breadcrumbs.new(...)

        def DynaFrameContent(...) = render Plutonium::UI::DynaFrame::Content.new(...)

        def PageHeader(...) = render Plutonium::UI::PageHeader.new(...)

        def ActionButton(...) = render Plutonium::UI::ActionButton.new(...)
      end
    end
  end
end
