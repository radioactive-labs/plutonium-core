# frozen_string_literal: true

require "test_helper"

class Plutonium::Helpers::TurboStreamActionsHelperTest < Minitest::Test
  include Turbo::Streams::ActionHelper
  include Plutonium::Helpers::TurboStreamActionsHelper

  attr_reader :request, :params

  def setup
    @request = Struct.new(:referer).new(nil)
    @params = {}
  end

  def test_emits_redirect_when_target_differs_from_referer
    @request = Struct.new(:referer).new("http://example.com/things/5/edit")
    html = turbo_stream_redirect("http://example.com/things/5")
    assert_includes html, 'action="redirect"'
    assert_includes html, 'url="http://example.com/things/5"'
  end

  def test_emits_refresh_when_target_matches_referer
    @request = Struct.new(:referer).new("http://example.com/things?page=2")
    html = turbo_stream_redirect("http://example.com/things?page=2")
    assert_includes html, 'action="refresh"'
    refute_includes html, 'action="redirect"'
  end

  def test_emits_redirect_when_referer_missing
    @request = Struct.new(:referer).new(nil)
    html = turbo_stream_redirect("http://example.com/things")
    assert_includes html, 'action="redirect"'
  end

  def test_normalizes_trailing_slash
    @request = Struct.new(:referer).new("http://example.com/things/")
    html = turbo_stream_redirect("http://example.com/things")
    assert_includes html, 'action="refresh"'
  end

  def test_ignores_fragment_difference_is_not_required
    # Fragments are stripped by URI parsing; different query strings should NOT match.
    @request = Struct.new(:referer).new("http://example.com/things?page=2")
    html = turbo_stream_redirect("http://example.com/things?page=3")
    assert_includes html, 'action="redirect"'
  end
end
