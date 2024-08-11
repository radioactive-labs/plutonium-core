# frozen_string_literal: true

module Plutonium
  module Action
    # RouteOptions class for handling routing options in the Plutonium framework.
    #
    # @attr_reader [Symbol] method The HTTP method for the route.
    # @attr_reader [Array] url_args The positional arguments for URL generation.
    # @attr_reader [Hash] url_options URL options for the route.
    # @attr_reader [Symbol] url_resolver The method to use for resolving URLs.
    class RouteOptions
      attr_reader :method, :url_args, :url_options, :url_resolver

      # Initialize a new RouteOptions instance.
      #
      # @param [Array] url_args The positional arguments for URL generation.
      # @param [Symbol] method The HTTP method for the route (default: :get).
      # @param [Symbol] url_resolver The method to use for resolving URLs (default: :resource_url_for).
      # @param [Hash] url_options URL options for the route.
      def initialize(*url_args, method: :get, url_resolver: :resource_url_for, **url_options)
        @method = method
        @url_resolver = url_resolver
        @url_args = url_args
        @url_options = url_options.freeze
        freeze
      end

      # Convert the RouteOptions to arguments suitable for URL helpers.
      #
      # @return [Array] The arguments for URL generation.
      def to_url_args
        @url_args + [@url_options]
      end

      # Merge this RouteOptions with another RouteOptions instance.
      #
      # @param [RouteOptions] other The other RouteOptions instance to merge with.
      # @return [RouteOptions] A new RouteOptions instance with merged values.
      def merge(other)
        self.class.new(
          *(@url_args | other.url_args),
          method: other.method || @method,
          url_resolver: other.url_resolver || @url_resolver,
          **@url_options.merge(other.url_options)
        )
      end

      def ==(other)
        self.class == other.class &&
          method == other.method &&
          url_resolver == other.url_resolver &&
          url_args == other.url_args &&
          url_options == other.url_options
      end

      def eql?(other)
        self == other
      end

      def hash
        [self.class, method, url_resolver, url_args, url_options].hash
      end
    end
  end
end
