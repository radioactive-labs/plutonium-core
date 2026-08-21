# frozen_string_literal: true

require "test_helper"

# A portal that exists only to be drawn at. Redrawing one of the dummy app's own
# portals would mean restoring every engine from its routes file after each test,
# which costs more than the rest of this file put together. Nothing mounts this
# one, and nothing else reads its route set.
module NestedRouteDrawPortal
  class Engine < ::Rails::Engine
    include Plutonium::Portal::Engine
  end
end

module Plutonium
  module Routing
    # `register_resource ..., associations:` names the associations a resource
    # draws nested routes for, and
    # Plutonium.configuration.nested_association_routes decides what naming none
    # means: `:detected` (every routable association, the historical behaviour)
    # or `:declared` (nothing).
    #
    # These redraw a real portal engine rather than asserting against a mapper
    # double, because what is under test is which routes come out the far end of
    # a draw. StorefrontPortal is the smallest portal in the dummy app, and the
    # teardown restores every engine from its own routes file.
    class DeclaredNestedAssociationsTest < Minitest::Test
      def setup
        @original_mode = Plutonium.configuration.nested_association_routes
      end

      def teardown
        Plutonium.configuration.nested_association_routes = @original_mode
      end

      def test_detected_mode_draws_every_routable_association
        draw do
          register_resource ::Blogging::Post
          register_resource ::Comment
          register_resource ::Blogging::PostDetail
        end

        assert_includes nested_keys, "blogging_posts/comments"
        assert_includes nested_keys, "blogging_posts/post_detail"
        # Named nowhere, drawn anyway: that is what :detected means.
        assert_includes nested_keys, "blogging_posts/comment_series"
      end

      def test_declared_associations_are_the_only_ones_drawn
        draw do
          register_resource ::Blogging::Post, associations: %i[comments]
          register_resource ::Comment
          register_resource ::Blogging::PostDetail
        end

        assert_includes nested_keys, "blogging_posts/comments"
        refute_includes nested_keys, "blogging_posts/comment_series"
        refute_includes nested_keys, "blogging_posts/post_detail"
      end

      def test_declared_associations_cover_has_one
        draw do
          register_resource ::Blogging::Post, associations: %i[post_detail]
          register_resource ::Comment
          register_resource ::Blogging::PostDetail
        end

        assert_includes nested_keys, "blogging_posts/post_detail"
        refute_includes nested_keys, "blogging_posts/comments"
      end

      # An empty list is an answer, not an omission.
      def test_empty_declaration_draws_nothing
        draw do
          register_resource ::Blogging::Post, associations: []
          register_resource ::Comment
        end

        assert_empty nested_keys
      end

      def test_declared_mode_draws_nothing_when_none_are_named
        Plutonium.configuration.nested_association_routes = :declared

        draw do
          register_resource ::Blogging::Post
          register_resource ::Comment
          register_resource ::Blogging::PostDetail
        end

        assert_empty nested_keys
      end

      def test_declared_mode_still_draws_what_is_named
        Plutonium.configuration.nested_association_routes = :declared

        draw do
          register_resource ::Blogging::Post, associations: %i[comments]
          register_resource ::Comment
        end

        assert_equal ["blogging_posts/comments"], nested_keys
      end

      # Top-level routes are untouched by either mode.
      def test_declared_mode_leaves_top_level_routes_alone
        Plutonium.configuration.nested_association_routes = :declared

        draw do
          register_resource ::Blogging::Post
          register_resource ::Comment
        end

        assert_includes route_keys, "blogging_posts"
        assert_includes route_keys, "comments"
      end

      def test_unknown_association_fails_the_draw
        error = assert_raises(ArgumentError) do
          draw do
            register_resource ::Blogging::Post, associations: %i[commets]
            register_resource ::Comment
          end
        end

        assert_match(/Blogging::Post is registered with/, error.message)
        assert_match(/:commets is not a routable association/, error.message)
        # Names what it could have meant.
        assert_match(/:comments/, error.message)
      end

      # belongs_to and has_many :through are not nestable, so naming one is the
      # same mistake as naming something that does not exist.
      def test_belongs_to_is_not_a_routable_association
        error = assert_raises(ArgumentError) do
          draw do
            register_resource ::Blogging::Post, associations: %i[user]
            register_resource ::Comment
          end
        end

        assert_match(/:user is not a routable association/, error.message)
      end

      # Silently skipped when detected; an explicit declaration says the author
      # expected a route, so say why there is none.
      def test_declaring_an_unregistered_child_fails_the_draw
        error = assert_raises(ArgumentError) do
          draw do
            register_resource ::Blogging::Post, associations: %i[comments]
          end
        end

        assert_match(/Comment is not registered in this portal/, error.message)
        assert_match(/register_resource Comment/, error.message)
      end

      def test_configuration_rejects_an_unknown_mode
        error = assert_raises(ArgumentError) do
          Plutonium.configuration.nested_association_routes = :declaired
        end

        assert_match(/unknown nested_association_routes :declaired/, error.message)
        assert_match(/:detected, :declared/, error.message)
      end

      def test_configuration_accepts_a_string
        Plutonium.configuration.nested_association_routes = "declared"

        assert_equal :declared, Plutonium.configuration.nested_association_routes
      end

      private

      def draw(&block)
        ::NestedRouteDrawPortal::Engine.routes.clear!
        ::NestedRouteDrawPortal::Engine.routes.draw(&block)
      end

      def route_keys
        ::NestedRouteDrawPortal::Engine.routes.resource_route_config_lookup.keys
      end

      def nested_keys
        route_keys.select { |key| key.include?("/") }
      end
    end
  end
end
