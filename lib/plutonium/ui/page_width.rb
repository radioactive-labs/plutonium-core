# frozen_string_literal: true

module Plutonium
  module UI
    # The width vocabulary for detail-style pages — the show page, resource
    # forms and wizard steps.
    #
    # These pages are read and filled top-to-bottom in a single column. Inputs
    # and values stretch to their container, so at full content width on a wide
    # screen you get ~1200px-long lines and text boxes: past a comfortable
    # measure, and a long eye-travel between a label and the value beside it.
    # Index and table pages are deliberately NOT covered — a table wants every
    # pixel it can get.
    #
    # The tokens deliberately mirror {Plutonium::UI::Modal::Base::VALID_SIZES}
    # so the framework has one width language rather than two.
    module PageWidth
      # Token => the max-width utility it resolves to. `:full` is the opt-out:
      # no constraint at all, the historical behaviour.
      SIZES = {
        sm: "max-w-2xl",
        md: "max-w-4xl",
        lg: "max-w-6xl",
        xl: "max-w-7xl",
        full: nil
      }.freeze

      VALID_SIZES = SIZES.keys.freeze

      # The classes for a token: a max-width plus the centring that makes it
      # read as a column rather than a left-hugging block. `:full` contributes
      # nothing, so an unconstrained page keeps exactly the markup it had
      # before this vocabulary existed.
      #
      # @param size [Symbol]
      # @return [String, nil]
      def self.classes_for(size)
        max_width = SIZES.fetch(size) { raise_unknown(size) }
        return nil if max_width.nil?

        "#{max_width} mx-auto"
      end

      # Raises on an unknown token rather than silently falling back, matching
      # `modal` and `show_in`. A typo'd width is a bug, not a default.
      def self.validate!(size)
        return size if VALID_SIZES.include?(size)
        raise_unknown(size)
      end

      def self.raise_unknown(size)
        raise ArgumentError,
          "page width must be one of #{VALID_SIZES.inspect}, got #{size.inspect}"
      end
      private_class_method :raise_unknown
    end
  end
end
