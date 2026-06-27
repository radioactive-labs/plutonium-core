# frozen_string_literal: true

module Plutonium
  module Definition
    # Base class for Plutonium definitions
    #
    # @abstract Subclass and override {#customize_fields}, {#customize_inputs},
    #   {#customize_filters}, {#customize_scopes}, and {#customize_sorters}
    #   to implement custom behavior.
    #
    # @example
    #   class MyDefinition < Plutonium::Definition::Base
    #     field :name, as: :string
    #     input :email, as: :email
    #     filter :status, type: :select, collection: %w[active inactive]
    #     scope :active
    #     default_scope :active
    #     sorter :created_at
    #
    #     def customize_fields
    #       field :custom_field, as: :integer
    #     end
    #   end
    #
    # @note This class is not thread-safe. Ensure proper synchronization
    #   if used in a multi-threaded environment.
    class Base
      include DefineableProps
      include ConfigAttr
      include InheritableConfigAttr
      include Actions
      include Wizards
      include Sorting
      include Scoping
      include Search
      include NestedInputs
      include StructuredInputs
      include FormLayout
      include IndexViews
      include Metadata

      class IndexPage < Plutonium::UI::Page::Index; end

      class NewPage < Plutonium::UI::Page::New; end

      class ShowPage < Plutonium::UI::Page::Show; end

      class EditPage < Plutonium::UI::Page::Edit; end

      class InteractiveActionPage < Plutonium::UI::Page::InteractiveAction; end

      class Form < Plutonium::UI::Form::Resource; end

      class Table < Plutonium::UI::Table::Resource; end

      class Grid < Plutonium::UI::Grid::Resource; end

      class Display < Plutonium::UI::Display::Resource; end

      class QueryForm < Plutonium::UI::Form::Query; end

      class TextFilter < Plutonium::Query::Filters::Text; end

      # fields
      defineable_props :field, :input, :display, :column

      # export
      defineable_prop :export

      # queries
      defineable_props :filter, :scope

      # pages
      config_attr \
        :index_page_title, :index_page_description,
        :show_page_title, :show_page_description,
        :new_page_title, :new_page_description,
        :edit_page_title, :edit_page_description

      # breadcrumbs
      inheritable_config_attr :breadcrumbs,
        :index_page_breadcrumbs, :new_page_breadcrumbs,
        :edit_page_breadcrumbs, :show_page_breadcrumbs,
        :interactive_action_page_breadcrumbs
      # global default
      breadcrumbs true

      # forms
      # Controls the "Save and add another" / "Update and continue editing" buttons
      # nil = auto-detect (hidden for singular resources, shown for plural)
      # true = always show
      # false = always hide
      inheritable_config_attr :submit_and_continue

      # modals — drive how :new / :edit and interactive actions render.
      # Actions read these lazily at render time, so override order and
      # subclass inheritance both work naturally.
      VALID_MODAL_MODES = [:centered, :slideover, false].freeze

      inheritable_config_attr :modal_mode, :modal_size
      modal_mode :slideover
      modal_size :md

      # Sets `modal_mode` and `modal_size` together with validation.
      #
      # - :slideover (default) — slide-in panel from the right
      # - :centered — centered dialog
      # - false — no modal; new/edit are full standalone pages
      #
      # `size:` see Plutonium::UI::Modal::Base::VALID_SIZES. `:auto`
      # hugs the form's natural width.
      def self.modal(mode, size: :md)
        unless VALID_MODAL_MODES.include?(mode)
          raise ArgumentError, "modal must be one of #{VALID_MODAL_MODES.inspect}, got #{mode.inspect}"
        end
        unless Plutonium::UI::Modal::Base::VALID_SIZES.include?(size)
          raise ArgumentError,
            "modal size must be one of #{Plutonium::UI::Modal::Base::VALID_SIZES.inspect}, got #{size.inspect}"
        end
        modal_mode mode
        modal_size size
      end

      # show_in — how the :show page opens from a record link (table row,
      # grid card). Unlike :new/:edit (which follow `modal_mode`), the show
      # page is ALWAYS centered when shown in a modal, so this is just a
      # modal/page switch — not a style.
      #
      #   :page  (default) — full-page navigation to the show route
      #   :modal           — open the show page in a centered dialog
      #
      # The kanban board has its own `show_in` that overrides this per-board.
      VALID_SHOW_IN = [:modal, :page].freeze

      inheritable_config_attr :show_in
      show_in :page

      # Validated setter — raises on an unknown mode rather than silently
      # falling back, matching the kanban board's `show_in`.
      def self.show_in(value = :__not_set__)
        return show_in_config if value == :__not_set__
        unless VALID_SHOW_IN.include?(value)
          raise ArgumentError, "show_in must be one of #{VALID_SHOW_IN.inspect}, got #{value.inspect}"
        end
        self.show_in_config = value
      end

      def initialize
        super
      end

      def index_page_class
        self.class::IndexPage
      end

      def new_page_class
        self.class::NewPage
      end

      def show_page_class
        self.class::ShowPage
      end

      def edit_page_class
        self.class::EditPage
      end

      def interactive_action_page_class
        self.class::InteractiveActionPage
      end

      def form_class
        self.class::Form
      end

      def collection_class
        self.class::Table
      end

      def grid_class
        self.class::Grid
      end

      def detail_class
        self.class::Display
      end

      def query_form
        self.class::QueryForm
      end
    end
  end
end
