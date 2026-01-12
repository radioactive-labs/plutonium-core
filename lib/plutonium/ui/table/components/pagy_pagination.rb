# frozen_string_literal: true

module Plutonium
  module UI
    module Table
      module Components
        class PagyPagination < Plutonium::UI::Component::Base
          include Pagy::Frontend

          def initialize(pagy)
            @pagy = pagy
          end

          def view_template
            nav(aria_label: "Page navigation", class: "flex justify-center mt-4") do
              ul(class: "inline-flex -space-x-px text-sm") do
                prev_link
                page_links
                next_link
              end
            end
          end

          private

          def prev_link
            li do
              if @pagy.prev
                a(href: page_url(@pagy.prev), class: link_classes(true)) {
                  render Phlex::TablerIcons::ChevronLeft.new
                }
              else
                button(class: disabled_link_classes(true), aria_disabled: "true") {
                  render Phlex::TablerIcons::ChevronLeft.new
                }
              end
            end
          end

          def next_link
            li do
              if @pagy.next
                a(href: page_url(@pagy.next), class: link_classes(false, true)) {
                  render Phlex::TablerIcons::ChevronRight.new
                }
              else
                button(class: disabled_link_classes(false, true), aria_disabled: "true") {
                  render Phlex::TablerIcons::ChevronRight.new
                }
              end
            end
          end

          def page_links
            @pagy.series.each do |item|
              li do
                case item
                when Integer
                  page_link(item)
                when String
                  current_page_link(item)
                when :gap
                  gap_link
                end
              end
            end
          end

          def page_link(page)
            a(href: page_url(page), class: link_classes) { page.to_s }
          end

          def current_page_link(page)
            button(class: current_link_classes, aria_current: "page") { page.to_s }
          end

          def gap_link
            button(class: link_classes, aria_disabled: "true") { "..." }
          end

          def link_classes(first = false, last = false)
            classes = ["flex", "items-center", "justify-center", "px-3", "h-8", "leading-tight", "text-gray-500", "bg-white", "border", "border-gray-300", "hover:bg-gray-100", "hover:text-gray-700", "dark:bg-gray-800", "dark:border-gray-700", "dark:text-gray-400", "dark:hover:bg-gray-700", "dark:hover:text-white"]
            classes << "rounded-s-lg" if first
            classes << "rounded-e-lg" if last
            classes.join(" ")
          end

          def current_link_classes
            "flex items-center justify-center px-3 h-8 text-blue-600 border border-gray-300 bg-blue-50 hover:bg-blue-100 hover:text-blue-700 dark:border-gray-700 dark:bg-gray-700 dark:text-white cursor-not-allowed"
          end

          def disabled_link_classes(first = false, last = false)
            classes = link_classes(first, last).split
            classes << "opacity-50" << "cursor-not-allowed"
            classes.join(" ")
          end

          def page_url(page)
            pagy_url_for(@pagy, page)
          end
        end
      end
    end
  end
end
