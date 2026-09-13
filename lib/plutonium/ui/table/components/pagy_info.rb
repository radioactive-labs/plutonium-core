# frozen_string_literal: true

module Plutonium
  module UI
    module Table
      module Components
        # "Displaying articles 11-20 of 100 in total" plus a per-page selector.
        #
        # The sentences come from Pagy's own dictionaries (`pagy.info_tag.*`,
        # `pagy.limit_tag_js`), translated in the current I18n locale, so a host
        # that ships a Pagy locale file gets this component for free. Pagy
        # leaves any placeholder it isn't handed untouched, which is what lets
        # the counts render in bold and the per-page select sit inside its
        # sentence: the template is translated with those placeholders still in
        # place, then split around them.
        class PagyInfo < Plutonium::UI::Component::Base
          PLACEHOLDER = /(%\{(?:from|to|count|limit_input)\})/

          # @param item_name [String, nil] the noun for the paginated records
          #   ("articles"); defaults to Pagy's generic "items".
          def initialize(pagy, per_page_options: [5, 10, 20, 50, 100], item_name: nil)
            @pagy = pagy
            @per_page_options = (per_page_options + [@pagy.limit]).uniq.sort
            @item_name = item_name
          end

          def view_template
            div(class: "flex flex-col md:flex-row justify-between items-center text-sm text-[var(--pu-text-muted)]") do
              results_info
              per_page_selector
            end
          end

          private

          def results_info
            key = if @pagy.count.zero?
              "pagy.info_tag.no_items"
            elsif @pagy.in == @pagy.count
              "pagy.info_tag.single_page"
            else
              "pagy.info_tag.multiple_pages"
            end

            div do
              render_template(pagy_template(key, @pagy.count)) do |placeholder|
                b { @pagy.public_send(placeholder).to_s }
              end
            end
          end

          def per_page_selector
            id = "perPage#{SecureRandom.hex}"

            div(
              class: "flex items-center space-x-2 mt-2 md:mt-0",
              data_controller: "select-navigator"
            ) do
              label(for: id, class: "flex items-center gap-2") do
                render_template(pagy_template("pagy.limit_tag_js", @pagy.limit)) do
                  select(
                    id: id, name: "items", class: select_classes,
                    data_action: "change->select-navigator#navigate",
                    data_select_navigator_target: "select"
                  ) do
                    @per_page_options.each do |option|
                      option(value: page_url(option), selected: option == @pagy.limit) { option.to_s }
                    end
                  end
                end
              end
            end
          end

          # Translate `key` with the item name filled in and every other
          # placeholder left literal, for {#render_template} to split on.
          def pagy_template(key, count)
            Plutonium::Translation.pagy(key, item_name: item_name(count))
          end

          def item_name(count)
            @item_name || Plutonium::Translation.pagy("pagy.item_name", count:)
          end

          # Emit `template` as text, yielding each remaining placeholder's name
          # (:from, :to, :count, :limit_input) for the caller to render inline.
          def render_template(template)
            template.split(PLACEHOLDER).each do |part|
              if (match = part.match(/\A%\{(\w+)\}\z/))
                yield match[1].to_sym
              else
                plain part
              end
            end
          end

          def select_classes
            "bg-[var(--pu-surface)] border border-[var(--pu-border)] text-[var(--pu-text)] text-sm rounded-[var(--pu-radius-md)] focus:ring-2 focus:ring-primary-500 focus:border-primary-500 block p-2.5 min-w-[5em]"
          end

          def page_url(limit)
            @pagy.page_url(@pagy.page, limit: limit, max_limit: limit)
          end
        end
      end
    end
  end
end
