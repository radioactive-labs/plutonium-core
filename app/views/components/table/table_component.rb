module Plutonium
  module Ui
    # TableComponent is a UI component that represents a table with sortable columns and optional row actions.
    class TableComponent < Plutonium::Ui::Base
      option :rows

      attr_reader :columns, :actions_block

      # Initializes the TableComponent with the given options.
      #
      # @param options [Hash] The options for the component.
      def initialize(...)
        super(...)
        @columns = []
      end

      # Defines a column in the table.
      #
      # @param name [Symbol] The name of the column.
      # @param label [String] The label of the column.
      # @param search_object [Object] The search object associated with the column.
      # @param block [Proc] An optional block for additional column customization.
      def column(name:, label:, search_object:, &block)
        @columns ||= []
        @columns << Column.new(name:, label:, search_object:, &block)
      end

      # Returns the base attributes for the table.
      #
      # @return [Hash] The base attributes hash.
      def base_attributes
        {
          classname: "table-auto w-full text-sm text-left rtl:text-right text-gray-500 dark:text-gray-200",
          table_head_classname: "text-xs text-gray-700 uppercase bg-gray-200 dark:bg-gray-700 dark:text-gray-200",
          table_head_cell_classname: "px-6 py-3",
          table_row_classname: "bg-white border-b dark:bg-gray-800 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-600",
          table_row_cell_classname: "px-6 py-4 whitespace-nowrap max-w-[250px] hover:max-w-fit overflow-hidden text-ellipsis",
          table_actions_head_classname: "px-6 py-3 text-end",
          table_actions_row_classname: "flex justify-end px-6 py-4"
        }
      end

      # Defines a block of actions to be included in each row.
      #
      # @param block [Proc] The block defining the actions.
      def with_actions(&block)
        @actions_block = block
      end

      private

      # Ensures that the view component calls the block, and @columns get populated.
      def before_render
        content
      end

      # Retrieves the CSS class for the table head.
      #
      # @return [String] The CSS class for the table head.
      def table_head_classname
        attributes_hash[:table_head_classname]
      end

      # Retrieves the CSS class for a table head cell.
      #
      # @return [String] The CSS class for a table head cell.
      def table_head_cell_classname
        attributes_hash[:table_head_cell_classname]
      end

      # Retrieves the CSS class for a table row.
      #
      # @return [String] The CSS class for a table row.
      def table_row_classname
        attributes_hash[:table_row_classname]
      end

      # Retrieves the CSS class for a table row cell.
      #
      # @return [String] The CSS class for a table row cell.
      def table_row_cell_classname
        attributes_hash[:table_row_cell_classname]
      end

      # Retrieves the CSS class for the table actions head.
      #
      # @return [String] The CSS class for the table actions head.
      def table_actions_head_classname
        attributes_hash[:table_actions_head_classname]
      end

      # Retrieves the CSS class for the table actions row.
      #
      # @return [String] The CSS class for the table actions row.
      def table_actions_row_classname
        attributes_hash[:table_actions_row_classname]
      end

      # Generates the content for a table head cell, including sorting links if applicable.
      #
      # @param column [Column] The column object.
      # @return [String] The HTML content for the table head cell.
      def table_head_cell(column)
        name = column.name
        label = column.label
        search_object = column.search_object

        if (sort_params = search_object.sort_params_for(name))
          tag.div class: "inline-flex" do
            concat begin
              link_to(sort_params[:url], class: "flex", title: sort_params[:direction] || "Sort") do
                concat label
                if sort_params[:direction].present?
                  icon = (sort_params[:direction] == "ASC") ? "up" : "down"
                  concat " "
                  concat render_icon("outline/arrow-#{icon}")
                end
              end
            end

            if sort_params[:position].present?
              concat " "
              concat link_to(
                sort_params[:position] + 1,
                sort_params[:reset_url],
                class: "inline-flex items-center justify-center w-4 h-4 text-xs font-bold text-white bg-yellow-500 border-1 border-white rounded-full dark:border-gray-90",
                title: "Clear sorting"
              )
            end
          end
        else
          label
        end
      end

      # A value object to hold the column definition.
      class Column
        attr_reader :name, :label, :search_object, :td_block

        # Initializes a Column object with the given attributes.
        #
        # @param name [Symbol] The name of the column.
        # @param label [String] The label of the column.
        # @param search_object [Object] The search object associated with the column.
        # @param block [Proc] An optional block for additional column customization.
        def initialize(name:, label:, search_object:, &block)
          @name = name
          @label = label
          @search_object = search_object
          @td_block = block
        end
      end
    end
  end
end

Plutonium::ComponentRegistry.register :table, to: Plutonium::Ui::TableComponent
