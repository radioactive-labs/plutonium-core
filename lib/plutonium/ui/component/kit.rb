# frozen_string_literal: true

require "phlex"

module Plutonium
  module UI
    module Component
      # Component Kit automatically handles component instantiation and rendering
      # through a convention-based approach using Build* methods.
      #
      # @example Basic component usage
      #   class MyView
      #     include Plutonium::UI::Component::Kit
      #
      #     def template
      #       PageHeader(title: "Dashboard")
      #       TabList(items: tabs)
      #       Panel(class: "mt-4") do
      #         content
      #       end
      #     end
      #   end
      #
      # @example Adding a new component
      #   def BuildCustomComponent(title:, **options)
      #     Plutonium::UI::CustomComponent.new(
      #       title: title,
      #       **options
      #     )
      #   end
      #
      # @note All components are automatically rendered when called without the 'Build' prefix.
      #       For example, calling `TabList(...)` will internally call `BuildTabList(...)` and
      #       render the result.
      module Kit
        extend ActiveSupport::Concern

        def method_missing(method_name, *args, **kwargs, &block)
          build_method = "Build#{method_name}"

          if self.class.method_defined?(build_method)
            render send(build_method, *args, **kwargs, &block)
          else
            super
          end
        end

        def respond_to_missing?(method_name, include_private = false)
          build_method = "Build#{method_name}"
          self.class.method_defined?(build_method) || super
        end

        def BuildBreadcrumbs(...) = Plutonium::UI::Breadcrumbs.new(...)

        def BuildSkeletonTable(...) = Plutonium::UI::SkeletonTable.new(...)

        def BuildBlock(...) = Plutonium::UI::Block.new(...)

        def BuildPanel(...) = Plutonium::UI::Panel.new(...)

        def BuildFrameNavigatorPanel(...) = Plutonium::UI::FrameNavigatorPanel.new(...)

        def BuildTabList(...) = Plutonium::UI::TabList.new(...)

        def BuildDynaFrameHost(...) = Plutonium::UI::DynaFrame::Host.new(...)

        def BuildDynaFrameContent(...) = Plutonium::UI::DynaFrame::Content.new(...)

        def BuildPageHeader(...) = Plutonium::UI::PageHeader.new(...)

        def BuildActionButton(...) = Plutonium::UI::ActionButton.new(...)

        def BuildEmptyCard(...) = Plutonium::UI::EmptyCard.new(...)

        def BuildTableSearchBar(...) = Plutonium::UI::Table::Components::SearchBar.new(...)

        def BuildTableScopesBar(...) = Plutonium::UI::Table::Components::ScopesBar.new(...)

        def BuildTableInfo(...) = Plutonium::UI::Table::Components::PagyInfo.new(...)

        def BuildTablePagination(...) = Plutonium::UI::Table::Components::PagyPagination.new(...)

        def BuildColorModeSelector(...) = Plutonium::UI::ColorModeSelector.new(...)
      end
    end
  end
end
