# frozen_string_literal: true

require "phlex"

module Plutonium
  module UI
    module Component
      module Kit
        extend ActiveSupport::Concern

        def Breadcrumbs(...) = render Plutonium::UI::Breadcrumbs.new(...)

        def SkeletonTable(...) = render Plutonium::UI::SkeletonTable.new(...)

        def Block(...) = render Plutonium::UI::Block.new(...)

        def Panel(...) = render Plutonium::UI::Panel.new(...)

        def FrameNavigatorPanel(...) = render Plutonium::UI::FrameNavigatorPanel.new(...)

        def DynaFrameHost(...) = render Plutonium::UI::DynaFrame::Host.new(...)

        def DynaFrameContent(...) = render Plutonium::UI::DynaFrame::Content.new(...)

        def PageHeader(...) = render Plutonium::UI::PageHeader.new(...)

        def ActionButton(...) = render Plutonium::UI::ActionButton.new(...)

        def EmptyCard(...) = render Plutonium::UI::EmptyCard.new(...)

        def TableSearchBar(...) = render Plutonium::UI::Table::Components::SearchBar.new(...)

        def TableScopesBar(...) = render Plutonium::UI::Table::Components::ScopesBar.new(...)

        def TableInfo(...) = render Plutonium::UI::Table::Components::PagyInfo.new(...)

        def TablePagination(...) = render Plutonium::UI::Table::Components::PagyPagination.new(...)

        def ColorModeSelector(...) = render Plutonium::UI::ColorModeSelector.new(...)
      end
    end
  end
end
