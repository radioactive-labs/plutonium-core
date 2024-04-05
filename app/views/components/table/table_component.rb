module Plutonium::Ui
  class TableComponent < Plutonium::Ui::Base
    option :resource_class
    option :resources
    option :record_actions
    option :search_object
    option :fields
    option :pager

    def classname
      "table-auto w-full text-sm text-left rtl:text-right text-gray-500 dark:text-gray-400 #{super}"
    end

    private

    def table_rounding
      search_object.scope_definitions.present? ? :bottom : :all
    end

    def table_head_classes
      "text-xs text-gray-700 uppercase bg-gray-200 dark:bg-gray-700 dark:text-gray-400"
    end

    def table_row_classes
      "bg-white border-b dark:bg-gray-800 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-600"
    end

    def table_row_cell_classes
      "px-6 py-4 whitespace-nowrap max-w-[250px] hover:max-w-fit overflow-hidden text-ellipsis"
    end

    def table_actions_cell_classes
      "flex justify-end px-6 py-4"
    end

    def table_header(name, label, search_object)
      if (sort_params = search_object.sort_params_for(name))
        tag.span do
          concat begin
            link_to(sort_params[:url], class: "text-decoration-none") do
              concat label
              if sort_params[:direction].present?
                icon = (sort_params[:direction] == "ASC") ? "up" : "down"
                concat " "
                concat tag.i(icon, class: "bi bi-sort-#{icon} text-muted", title: sort_params[:direction])
              end
            end
          end
          if sort_params[:position].present?
            concat " "
            concat link_to(sort_params[:position] + 1, sort_params[:reset_url],
              class: "badge rounded-pill text-bg-secondary text-decoration-none", title: "remove sorting",
              style: "font-size: 0.6em;")
          end
        end
      else
        label
      end
    end
  end
end

Plutonium::ComponentRegistry.register :table, to: Plutonium::Ui::TableComponent
