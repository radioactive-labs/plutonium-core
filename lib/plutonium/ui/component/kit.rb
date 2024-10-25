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

        def EmptyCard(...) = render Plutonium::UI::EmptyCard.new(...)

        def TableSearchBar(...) = render Plutonium::UI::Table::Components::SearchBar.new(...)

        def TableFilterBar(...) = render Plutonium::UI::Table::Components::FilterBar.new(...)

        def TableScopesBar(...) = render Plutonium::UI::Table::Components::ScopesBar.new(...)

        def TableInfo(...) = render Plutonium::UI::Table::Components::PagyInfo.new(...)

        def TablePagination(...) = render Plutonium::UI::Table::Components::PagyPagination.new(...)
      end
    end
  end
end
