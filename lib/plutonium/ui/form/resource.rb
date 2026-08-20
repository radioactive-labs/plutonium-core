# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      class Resource < Base
        include Plutonium::UI::Form::Concerns::RendersRepeaterRowControls
        include Plutonium::UI::Form::Concerns::RendersNestedResourceFields
        include Plutonium::UI::Form::Concerns::RendersStructuredInputs

        attr_reader :resource_fields, :resource_definition, :singular_resource

        alias_method :record, :object

        def initialize(*, resource_fields:, resource_definition:, singular_resource: false, **, &)
          super(*, **, &)
          @resource_fields = resource_fields
          @resource_definition = resource_definition
          @singular_resource = singular_resource
        end

        def form_template
          if in_modal?
            # In modal: form is the flex container that fills the modal
            # body. Fields region scrolls; action strip sits flush at the
            # bottom edge of the modal.
            div(class: "flex-1 min-h-0 overflow-y-auto px-6 py-5") do
              render_fields
            end
          else
            render_fields
          end
          render_actions
        end

        # Mirrors Phlexi::Form::Base#view_template (phlexi-form ~> 0.14)
        # — keep these in sync if upgrading. We override so the guard
        # dialog renders inside the <form> tag (where the JS controller
        # looks for it via `dirty-form-guard-target`) even when a
        # subclass overrides `form_template`. Without this, the
        # controller silently falls back to `window.confirm`.
        def view_template(&block)
          captured_body = capture { form_template(&block) }
          captured_guard = capture { render_dirty_form_guard_dialog if in_modal? }
          form_tag do
            form_errors
            raw(safe(captured_body))
            raw(safe(captured_guard))
          end
        end

        # The form is normally a card (theme :base). When a form_layout is
        # declared each section becomes a card of its own, so the form must
        # stop being one — otherwise every section is a card nested inside a
        # card, doubling borders and padding. The sections' own container
        # supplies the spacing that :base's padding used to.
        #
        # Width comes from configuration rather than the theme (`page_width` /
        # `form_width` on the definition), so it is appended here. A modal form
        # gets none of this: the dialog already sets its own width.
        def form_class
          return "flex-1 flex flex-col min-h-0" if in_modal?

          base = resource_definition.defined_form_layout ? themed(:sectioned_base, nil) : super
          tokens(base, resource_definition.form_width_classes)
        end

        private

        # Nested inside the form so showModal() stacks it in the browser's
        # top layer above the surrounding slideover/centered modal — no
        # z-index juggling required.
        def render_dirty_form_guard_dialog
          dialog(
            class:
              "pu-dialog " \
              "top-1/2 -translate-y-1/2 left-1/2 -translate-x-1/2 " \
              "w-full max-w-md p-0 " \
              "open:flex flex-col " \
              "opacity-0 scale-95 data-[open]:opacity-100 data-[open]:scale-100 " \
              "transition-[opacity,scale] duration-200 ease-out",
            data: {"dirty-form-guard-target": "confirmDialog"},
            # Modern Chrome refuses user-agent close requests (Esc, backdrop);
            # older browsers fall back to the JS controller's interception.
            closedby: "none",
            "aria-labelledby": "pu-dirty-guard-title",
            "aria-describedby": "pu-dirty-guard-desc"
          ) do
            div(class: "px-6 pt-5 pb-4 border-b border-[var(--pu-border)]") do
              h2(id: "pu-dirty-guard-title", class: "text-lg font-semibold text-[var(--pu-text)]") do
                "Discard changes?"
              end
              p(id: "pu-dirty-guard-desc", class: "mt-1 text-sm text-[var(--pu-text-muted)]") do
                "You have unsaved changes. Closing this form now will lose them."
              end
            end
            div(class: "flex items-center justify-end gap-2 px-6 py-4") do
              button(
                type: "button",
                class: "pu-btn pu-btn-md pu-btn-outline",
                data: {action: "dirty-form-guard#keepEditing"}
              ) { "Keep editing" }
              button(
                type: "button",
                class: "pu-btn pu-btn-md pu-btn-danger",
                data: {action: "dirty-form-guard#discard"}
              ) { "Discard changes" }
            end
          end
        end

        def render_fields
          sections = resolve_form_layout
          if sections.nil?
            fields_wrapper {
              resource_fields.each { |name| render_resource_field name }
            }
          else
            # Sections live in their own stacking container rather than being
            # emitted straight into the form body. They are cards in their own
            # right, and the container is what spaces them; without it they
            # would also share a parent with the errors block, so any
            # `:first-child` styling in the section chrome would silently
            # target the wrong element.
            div(class: themed(:sections_wrapper, nil)) do
              sections.each { |rs| render_form_section(rs) }
            end
          end
        end

        # Resolve the whole form layout for THIS render, in one pass: drop
        # condition-hidden sections and evaluate any proc-valued options, all in
        # the form instance context (where `object`, `current_user`, `params` and
        # helpers live — same context as input/section `condition:`). Returns nil
        # when no form_layout is declared (caller falls back to a single grid).
        def resolve_form_layout
          sections = resource_definition.resolve_form_sections(resource_fields)
          return nil if sections.nil?

          sections.filter_map do |resolved|
            section = resolved.section
            condition = section.condition
            next if condition && !instance_exec(&condition)

            # Drop sections left with no fields — e.g. every declared field was
            # filtered out by the permitted set (policy, per-action, scoping,
            # nesting). Rendering the chrome (heading + empty grid) for these
            # litters the form with empty headings (notably on `+ New`, where
            # fewer attributes are permitted than declared). Field-level
            # `condition:` is evaluated later, at render — a section whose fields
            # are all condition-hidden is the author's call to gate via the
            # section's own `condition:`.
            next if resolved.fields.empty?

            # `columns` stays a validated literal (the Builder rejects a non-Integer
            # at declaration); `label`/`description`/`collapsible`/`collapsed` may be
            # procs, resolved by the SAME arity rule as a field/input option so
            # `-> { … }` means one thing across the whole form DSL.
            options = resolve_option_procs(section.options)
            Plutonium::Definition::FormLayout::ResolvedSection.new(
              section: Plutonium::Definition::FormLayout::Section.new(
                key: section.key, fields: section.fields, options: options.freeze
              ),
              fields: resolved.fields
            )
          end
        end

        # Pure presentation — the section is already resolved (visible, options
        # evaluated) by resolve_form_layout.
        def render_form_section(resolved)
          section = resolved.section
          render Plutonium::UI::Form::Components::Section.new(
            resolved, grid_class: section_grid_class(section.columns)
          ) do
            # Inside a multi-column section, let fields flow into the grid cells
            # instead of forcing each to span the full row (see col-span default
            # in render_simple_resource_field).
            previous = @section_columns
            @section_columns = section.columns
            begin
              resolved.fields.each { |name| render_resource_field name }
            ensure
              @section_columns = previous
            end
          end
        end

        # True while rendering fields inside a section that declared an explicit
        # column count > 1. Such fields default to a single grid cell rather than
        # `col-span-full`, so the section's grid actually lays out in columns.
        def in_multi_column_section?
          @section_columns.to_i > 1
        end

        # nil → the form's default responsive grid; an Integer overrides columns.
        def section_grid_class(columns)
          return themed(:fields_wrapper, nil) if columns.nil?

          base = "grid gap-6 grid-flow-row-dense grid-cols-1"
          case columns.to_i
          when 1 then base
          when 2 then "#{base} md:grid-cols-2"
          when 3 then "#{base} md:grid-cols-2 lg:grid-cols-3"
          else "#{base} md:grid-cols-2 2xl:grid-cols-#{columns.to_i}"
          end
        end

        def render_actions
          # Only carry an *explicit* return_to. We deliberately do NOT fall
          # back to request.original_url: for interactive-action forms that URL
          # is the action's own (modal-only) path, and submitting it back would
          # "return" to a bare standalone form — a blank page. When absent, the
          # controller computes the right destination (redirect_url_after_submit
          # / redirect_url_after_action_on, both → resource_url_for).
          #
          # capture-url grafts the live URL fragment (#tab-id) onto this value
          # on connect (the server never sees fragments), but only when a base
          # value is present.
          input name: "return_to",
            value: request.params[:return_to],
            type: :hidden,
            hidden: true,
            data: {controller: "capture-url"}

          # Kanban quick-add: carry the column key through to the create POST so
          # the controller can apply that column's on_enter + positioning to the
          # new record post-create (the "+ Add" link opens this form with
          # ?kanban_column=<key>). Only emitted when present, so it never appears
          # on ordinary new/edit forms.
          if request.params[:kanban_column].present?
            input name: "kanban_column",
              value: request.params[:kanban_column],
              type: :hidden,
              hidden: true
          end

          if in_modal?
            div(class: "shrink-0 px-6 py-3 " \
                       "bg-[var(--pu-surface)] border-t border-[var(--pu-border)] " \
                       "flex items-center justify-end gap-2") do
              render_submit_and_continue_button if show_submit_and_continue?
              render submit_button
            end
          else
            render Plutonium::UI::Form::Components::StickyFooter.new do
              render_submit_and_continue_button if show_submit_and_continue?
              render submit_button
            end
          end
        end

        def show_submit_and_continue?
          return false unless object.respond_to?(:new_record?)

          # Continue / add-another lands on the form's standalone URL —
          # which breaks the experience when the form is inside a frame
          # (modal or association tab) since the redirect can't keep the
          # user in that frame context.
          return false if current_turbo_frame.present?

          # Check explicit configuration first
          configured = resource_definition.submit_and_continue
          return configured unless configured.nil?

          # Auto-detect: hide for singular resources
          !singular_resource
        end

        def render_submit_and_continue_button
          label = object.new_record? ? "Create and add another" : "Update and continue editing"

          button(
            type: :submit,
            name: "return_to",
            value: request.url,
            class: "pu-btn pu-btn-md pu-btn-outline"
          ) { label }
        end

        def form_action
          return @form_action unless object.present? && @form_action != false && view_context.present?

          @form_action ||= resource_url_for(object, action: object.new_record? ? :create : :update)
        end

        def render_resource_field(name)
          when_permitted(name) do
            if resource_definition.respond_to?(:defined_structured_inputs) && resource_definition.defined_structured_inputs[name]
              render_structured_input(name)
            elsif resource_definition.respond_to?(:defined_nested_inputs) && resource_definition.defined_nested_inputs[name]
              render_nested_resource_field(name)
            else
              render_simple_resource_field(name, resource_definition, self)
            end
          end
        end

        def render_simple_resource_field(name, definition, form)
          # field :name, as: :string
          # input :name, as: :string
          # input :description, wrapper: {class: "col-span-full"}
          # input :age, class: "max-h-fit"
          # input :dob do |f|
          #   f.date_tag
          # end

          field_options = definition.defined_fields[name] ? definition.defined_fields[name][:options] : {}

          input_definition = definition.defined_inputs[name] || {}
          input_options = input_definition[:options] || {}

          field_options = resolve_option_procs(field_options)
          input_options = resolve_option_procs(input_options)

          tag = input_options[:as] || field_options[:as]

          # Extract field-level options from input_options and merge into field_options
          # These are Phlexi field options that should be passed to form.field(), not to the tag builder
          # Note: forms use :hint, displays use :description
          field_level_keys = [:hint, :label, :placeholder]
          field_level_options = input_options.slice(*field_level_keys)
          field_options = field_options.merge(field_level_options)

          # Staging options are stripped here as well as in Wizard::StepAdapter,
          # because an interaction's inputs reach this method directly. A
          # Class-valued `uploader:` is not an HTML attribute and Phlex refuses
          # it, so leaving it in raises rather than rendering.
          tag_attributes = input_options.except(
            :wrapper, :as, :pre_submit, :condition, *field_level_keys,
            *Plutonium::Attachments::STAGING_ONLY_INPUT_OPTIONS
          )
          if input_options[:pre_submit]
            tag_attributes["data-action"] = "change->form#preSubmit"
          end
          tag_block = input_definition[:block] || ->(f) { f.component_for(tag, **tag_attributes) }

          # Keep `:as` so the Builder can detect hidden fields via `options[:as]`.
          # `as:` may be declared on either `field` or `input`, and the tag
          # lookup above already honours both. Carry the resolved value back
          # into field_options so the Builder sees it too: without this,
          # `input :x, as: :hidden` renders a hidden input inside a fully
          # chromed wrapper, label and all, while `field :x, as: :hidden`
          # renders correctly. The Builder consumes `:as` before Phlexi sees
          # the options, so this cannot leak into a Phlexi field option.
          field_options = field_options.merge(as: tag) if tag
          field_options = field_options.except(:condition)

          condition = input_options[:condition] || field_options[:condition]
          conditionally_hidden = condition && !instance_exec(&condition)
          if conditionally_hidden
            # Do not render the field, but still create field
            # Phlexi form will record it without rendering it, allowing us to extract its value
            form.field(name, **field_options) do |f|
              vanish { render instance_exec(f, &tag_block) }
            end
          else
            wrapper_options = input_options[:wrapper] || {}
            # Only supply a default column span when the field hasn't declared its
            # own (via `wrapper: {class: "col-span-..."}`). A field-level col-span
            # ALWAYS wins — including inside a section with `columns:` — so authors
            # can opt a single field back to full width in a multi-column section,
            # or vice versa.
            # TODO: remove the string check once theming supports class merges.
            if !wrapper_options[:class] || !wrapper_options[:class].include?("col-span")
              # In a multi-column section the field flows into a single grid cell
              # (no col-span), so the declared `columns:` actually takes effect.
              # Everywhere else fields span the full row.
              default_span = in_multi_column_section? ? nil : "col-span-full"
              wrapper_options[:class] = tokens(default_span, wrapper_options[:class])
            end

            render form.field(name, **field_options).wrapped(
              **wrapper_options
            ) do |f|
              render instance_exec(f, &tag_block)
            end
          end
        end

        # Resolve proc-valued options for THIS render, so any option can vary per
        # request rather than being frozen when the class loads. One rule for the
        # whole form DSL: `field`/`input`, `section`/`ungrouped`, `structured_input`
        # and nested inputs all route through here.
        #
        # Arity says whether you want the form, NOT which `self` you get:
        #
        #   -> { … }       a plain call — means what it reads like where it was
        #                  written, closure and all
        #   ->(form) { … } handed this form, for `object`/`params`/helpers
        #
        # This is `choices:`'s rule, adopted rather than replaced. Phlexi has
        # always resolved a `choices:` proc with a plain `.call`, so it is both
        # the oldest of these semantics and the only one that predates Plutonium's
        # own option layer — and it is the unsurprising one: nothing silently
        # rebinds `self` out from under a lambda. `section :x, collapsed: -> { … }`
        # (v0.60) followed the other convention and was migrated to `->(form)` to
        # meet it here.
        #
        # Form::Wizard overrides the zero-arity case, because a step block is
        # instance_exec'd against a throwaway recorder — the closure there holds
        # nothing, so the wizard takes its place.
        #
        # `condition:` is excluded because it is a different kind of thing, not
        # because it is an awkward leftover. An option asks "what value should
        # this have?" and may not care about the render; `condition:` asks
        # "should this render here, now?", which is a question about the render
        # context by definition. So it is evaluated separately, always AGAINST
        # its context — and that context is not always a form (a `column`'s is the
        # table, a step's is the wizard, an action's is a ConditionContext), which
        # is why it cannot take a `form` argument the way an option does.
        # Resolving it here would also collapse it to a boolean before the render
        # site that owns it gets to ask.
        def resolve_option_procs(options)
          return options if options.blank?

          options.to_h do |key, value|
            [key, resolvable_proc?(key, value) ? call_option_proc(value) : value]
          end
        end

        def resolvable_proc?(key, value) = key != :condition && value.is_a?(Proc)

        def call_option_proc(value) = value.arity.zero? ? value.call : value.call(self)

        def when_permitted(name, &)
          return unless resource_fields.include? name

          yield
        end
      end
    end
  end
end
