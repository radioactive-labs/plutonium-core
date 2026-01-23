# frozen_string_literal: true

module Plutonium
  module Core
    module Controllers
      # Resolves target classes/instances to association names on a parent model.
      #
      # This module handles the mapping between resource classes and their association
      # names when generating nested resource URLs. It supports:
      # - Explicit association names (symbols)
      # - Class-based resolution with namespace fallback
      # - Instance-based resolution
      #
      # @example Explicit association
      #   resolve_association(:comments, @post) # => :comments
      #
      # @example Class-based resolution
      #   resolve_association(Comment, @post) # => :comments
      #
      # @example Namespaced class resolution
      #   resolve_association(Blogging::Comment, @post) # => :comments (tries :blogging_comments first)
      #
      module AssociationResolver
        class AmbiguousAssociationError < StandardError; end

        # Resolves a target to an association name on the parent
        #
        # @param target [Class, Object, Symbol] The target class, instance, or association name
        # @param parent [Object] The parent instance
        # @return [Symbol] The resolved association name
        # @raise [ArgumentError] If no matching association is found
        # @raise [AmbiguousAssociationError] If multiple associations match
        def resolve_association(target, parent)
          return target if target.is_a?(Symbol)

          target_class = target.is_a?(Class) ? target : target.class
          candidates = association_candidates_for(target_class)

          matching = candidates.filter_map do |assoc_name|
            assoc = parent.class.reflect_on_association(assoc_name)
            assoc_name if assoc && assoc.klass >= target_class
          end

          case matching.size
          when 0
            raise ArgumentError,
              "No association found for #{target_class} on #{parent.class}. " \
              "Tried: #{candidates.join(", ")}"
          when 1
            matching.first
          else
            raise AmbiguousAssociationError,
              "Multiple associations to #{target_class} on #{parent.class}: #{matching.join(", ")}. " \
              "Please specify explicitly using a symbol: resource_url_for(:association_name, parent: ...)"
          end
        end

        private

        # Returns candidate association names for a class
        #
        # For Blogging::Comment, returns [:blogging_comments, :comments]
        # For Comment, returns [:comments]
        #
        # @param klass [Class] The target class
        # @return [Array<Symbol>] Candidate association names in priority order
        def association_candidates_for(klass)
          candidates = []

          # Full namespaced name: Blogging::Comment => :blogging_comments
          full_name = klass.model_name.plural.to_sym
          candidates << full_name

          # Demodulized name: Blogging::Comment => :comments
          demodulized = klass.name.demodulize
          if demodulized != klass.name
            short_name = demodulized.underscore.pluralize.to_sym
            candidates << short_name unless candidates.include?(short_name)
          end

          candidates
        end
      end
    end
  end
end
