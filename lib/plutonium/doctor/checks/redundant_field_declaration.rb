# frozen_string_literal: true

module Plutonium
  module Doctor
    module Checks
      # A field declaration that says nothing the framework had not already
      # worked out.
      #
      # Plutonium reads the model and renders every permitted attribute
      # already — type, label, widget, formatter, column. `field :title` with no
      # options and no block adds nothing: the surfaces only ever look
      # declarations UP by name (`defined_fields[name]`) while iterating a list
      # that comes from the policy, so an entry carrying no options is read and
      # discarded. It is dead on the day it is written, and it goes stale the
      # day the column changes type.
      #
      # `input` is deliberately not checked. Its keys are a source list, not
      # just a lookup: nested resource fields, structured inputs and wizard
      # steps all take their field set from `defined_inputs.keys`, so a bare
      # `input :title` is load-bearing in those contexts and only sometimes
      # redundant. Warning on it would train people to ignore the doctor.
      class RedundantFieldDeclaration < Check
        def self.severity = :warning

        # The declaration kinds whose entries are pure lookups, so that a
        # bare declaration cannot be doing anything.
        KINDS = %i[field display column].freeze

        def call
          KINDS.flat_map { |kind| findings_for(kind) }
        end

        private

        def findings_for(kind)
          declarations = target.definition.public_send(:"defined_#{kind.to_s.pluralize}")

          declarations.filter_map do |name, data|
            next unless bare?(data)

            finding(
              subject: "#{target.definition_class}##{kind}:#{name}",
              message: "`#{kind} :#{name}` in #{target.definition_class} declares nothing and can be deleted",
              details: <<~TEXT
                Plutonium already renders :#{name} from the model — this line only repeats
                what was inferred, and stops matching the moment the column changes.

                Declare a #{kind} when you are overriding something: a different type
                (`as: :markdown`), an option (`hint:`, `placeholder:`, `wrapper:`), a
                `condition:`, or a block. Otherwise delete the line.

                To make :#{name} appear or disappear, change `permitted_attributes_for_*`
                on the policy — a declaration here has no say in that.
              TEXT
            )
          end
        end

        # A declaration is bare when it carries neither options nor a block.
        # The merged hash is built with `.compact`, so an option-less, block-less
        # declaration arrives as `{options: {}}`.
        def bare?(data)
          data[:block].nil? && data[:options].blank?
        end
      end
    end
  end
end
