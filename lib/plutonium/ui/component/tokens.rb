# frozen_string_literal: true

module Plutonium
  module UI
    module Component
      module Tokens
        def classes(*tokens, **conditional_tokens)
          tokens = self.tokens(*tokens, **conditional_tokens)

          if tokens.empty?
            {}
          else
            {class: tokens}
          end
        end

        def tokens(*tokens, **conditional_tokens)
          conditional_tokens.each do |condition, token|
            truthy = case condition
            when Symbol then send(condition)
            when Proc then condition.call
            else raise ArgumentError, "The class condition must be a Symbol or a Proc."
            end

            if truthy
              case token
              when Hash then __append_token__(tokens, token[:then])
              else __append_token__(tokens, token)
              end
            else
              case token
              when Hash then __append_token__(tokens, token[:else])
              end
            end
          end

          tokens = tokens.select(&:itself).join(" ")
          tokens.strip!
          tokens.gsub!(/\s+/, " ")
          tokens
        end

        private

        def __append_token__(tokens, token)
          case token
          when nil then nil
          when String then tokens << token
          when Symbol then tokens << token.name
          when Array then tokens.concat(token)
          else raise ArgumentError,
            "Conditional classes must be Symbols, Strings, or Arrays of Symbols or Strings."
          end
        end
      end
    end
  end
end
