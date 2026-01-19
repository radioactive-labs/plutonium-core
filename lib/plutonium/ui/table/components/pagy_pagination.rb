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
            nav(aria_label: "Page navigation", class: "flex justify-center mt-6") do
              ul(class: "inline-flex items-center gap-1 text-sm") do
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
            base = "flex items-center justify-center w-9 h-9 text-[var(--pu-text-muted)] bg-[var(--pu-surface)] border border-[var(--pu-border)] hover:bg-[var(--pu-surface-alt)] hover:text-[var(--pu-text)] transition-colors"
            classes = [base]
            classes << "rounded-l-lg" if first
            classes << "rounded-r-lg" if last
            classes << "rounded-lg" if !first && !last
            classes.join(" ")
          end

          def current_link_classes
            "flex items-center justify-center w-9 h-9 text-white bg-primary-600 border border-primary-600 rounded-lg font-medium cursor-default"
          end

          def disabled_link_classes(first = false, last = false)
            base = "flex items-center justify-center w-9 h-9 text-[var(--pu-text-subtle)] bg-[var(--pu-surface-alt)] border border-[var(--pu-border)] opacity-50 cursor-not-allowed"
            classes = [base]
            classes << "rounded-l-lg" if first
            classes << "rounded-r-lg" if last
            classes << "rounded-lg" if !first && !last
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
