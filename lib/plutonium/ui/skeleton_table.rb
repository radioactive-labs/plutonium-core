module Plutonium
  module UI
    class SkeletonTable < Plutonium::UI::Component::Base
      def view_template
        div(
          role: "status",
          class: "pu-card p-6 space-y-4 divide-y divide-[var(--pu-border-muted)] motion-safe:animate-pulse"
        ) do
          div(class: "flex items-center justify-between") do
            div do
              div(class: "h-3 bg-[var(--pu-border-strong)] rounded-full w-24 mb-3")
              div(class: "w-32 h-2 bg-[var(--pu-border)] rounded-full")
            end
            div(class: "h-3 bg-[var(--pu-border)] rounded-full w-12")
          end
          div(class: "flex items-center justify-between pt-4") do
            div do
              div(class: "h-3 bg-[var(--pu-border-strong)] rounded-full w-24 mb-3")
              div(class: "w-32 h-2 bg-[var(--pu-border)] rounded-full")
            end
            div(class: "h-3 bg-[var(--pu-border)] rounded-full w-12")
          end
          span(class: "sr-only") { "Loading..." }
        end
      end
    end
  end
end
