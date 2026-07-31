# frozen_string_literal: true

module Plutonium
  module Definition
    # What an `as:` on an input / display declaration MEANS, independent of any
    # view.
    #
    # `as:` is a union: either an alias naming a built-in tag (`:string`,
    # `:uppy`, a String) OR a component Class rendered directly (see
    # {Plutonium::UI::Component::ResolvesTags}). A Class has no `#to_sym`, so
    # every "which alias is this?" question goes through {resolve} rather than
    # coercing `as` itself — the controller, the wizard, the generators and the
    # views all ask here.
    module InputAliases
      # The `as:` values that render through the Uppy file-upload component —
      # the single source of truth, so the form builder's tag aliases and the
      # attachment detection in {Plutonium::Wizard::Attachments.field?} and
      # `Plutonium::Resource::Controller#attachment_input_keys` never drift.
      FILE_INPUT_TYPES = %i[uppy file attachment].freeze

      class << self
        # @param as [Symbol, String, Class, nil] a declared `as:`.
        # @return [Symbol, nil] the Symbol form of a symbol/string `as:`; nil for
        #   anything else, a component Class included, since it names no alias.
        #   The Symbol is NOT validated against the tags that actually exist —
        #   callers compare it against the aliases they care about.
        def resolve(as)
          as.to_sym if as.is_a?(Symbol) || as.is_a?(String)
        end

        # Whether an `as:` renders as an attachment/file input.
        def file_input?(as)
          FILE_INPUT_TYPES.include?(resolve(as))
        end
      end
    end
  end
end
