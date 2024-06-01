require "pagy"

module Plutonium::Ui
  class PaginationComponent < Plutonium::Ui::Base
    include Pagy::Frontend

    option :pager
    option :pagy_id, optional: true
    option :nav_aria_label, optional: true
    option :nav_i18n_key, optional: true

    def pagy_nav(pagy, **vars)
      p_id = %( id="#{pagy_id}") if pagy_id
      link = pagy_link_proc(pagy, link_extra: "class=\"#{default_link_classes} #{page_link_classes}\"")

      html = +%(<nav#{p_id} class="pagy pagy-nav pagination" #{nav_aria_label_attr(pagy, nav_aria_label, nav_i18n_key)}>)
      html = +%(<ul class="inline-flex -space-x-px text-sm">)
      html << prev_html(pagy)
      pagy.series(**vars).each do |item| # series example: [1, :gap, 7, 8, "9", 10, 11, :gap, 36]
        html << case item
        when Integer
          %(<li class="page" >#{link.call(item)}</li>)
        when String
          %(<li class="page active">) +
            %(<a role="link" aria-disabled="true" aria-current="page" class="#{default_link_classes} #{active_link_classes}">#{pagy.label_for(item)}</a></li>)
        when :gap
          %(<li class="page gap #{default_link_classes} border-y-0">#{pagy_t("pagy.gap")}</li>)
        else
          raise InternalError, "expected item types in series to be Integer, String or :gap; got #{item.inspect}"
        end
      end
      html << %(#{next_html(pagy)}</ul></nav>)
    end

    def pagy_info(pagy, pagy_id: nil, item_name: nil, item_i18n_key: nil)
      p_id = %( id="#{pagy_id}") if pagy_id
      p_count = pagy.count
      key = if p_count.zero? then "pagy.info.no_items"
      elsif pagy.pages == 1 then "pagy.info.single_page"
      else "pagy.info.multiple_pages" # rubocop:disable Lint/ElseLayout
      end

      %(<span#{p_id} class="text-sm text-gray-700 dark:text-gray-200 pagy-info">#{
          pagy_t key, item_name: item_name || pagy_t(item_i18n_key || pagy.vars[:item_i18n_key], count: p_count),
            count: p_count, from: pagy.from, to: pagy.to
        }</span>)
    end

    private

    def base_attributes
      {
        classname: "flex flex-col items-center space-y-2 p-6",
        controller: "pagination"
      }
    end

    def prev_html(pagy, text: pagy_t("pagy.prev"))
      link = pagy_link_proc(pagy, link_extra: "class=\"#{default_link_classes} #{page_link_classes} rounded-s-lg\"")

      if (p_prev = pagy.prev)
        %(<li class="page prev">#{link.call(p_prev, text, prev_aria_label_attr)}</li>)
      else
        %(<li class="page prev disabled"><span role="link" aria-disabled="true" class="#{default_link_classes} #{active_link_classes} border-e-0 rounded-s-lg" #{
          prev_aria_label_attr}>#{text}</span></li>)
      end
    end

    def next_html(pagy, text: pagy_t("pagy.next"))
      link = pagy_link_proc(pagy, link_extra: "class=\"#{default_link_classes} #{page_link_classes} rounded-e-lg\"")

      if (p_next = pagy.next)
        %(<li class="page next">#{link.call(p_next, text, next_aria_label_attr)}</li>)
      else
        %(<li class="page next disabled"><span role="link" aria-disabled="true" class="#{default_link_classes} #{active_link_classes} rounded-e-lg" #{
          next_aria_label_attr}>#{text}</span></li>)
      end
    end

    def default_link_classes
      "flex items-center justify-center px-3 h-8 leading-tight text-gray-500 border border-gray-300 bg-white dark:bg-gray-800 dark:border-gray-700 dark:text-gray-200"
    end

    def page_link_classes
      "hover:bg-gray-100 hover:text-gray-700 dark:hover:bg-gray-700 dark:hover:text-white"
    end

    def active_link_classes
      "text-primary-600 hover:text-primary-600 dark:bg-gray-700 dark:text-white dark:hover:text-white cursor-default select-none"
    end
  end
end

Plutonium::ComponentRegistry.register :pagination, to: Plutonium::Ui::PaginationComponent
