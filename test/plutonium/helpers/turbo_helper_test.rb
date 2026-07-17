# frozen_string_literal: true

require "test_helper"

class Plutonium::Helpers::TurboHelperTest < Minitest::Test
  include Plutonium::Helpers::TurboHelper

  attr_reader :request, :params

  def setup
    @params = {}
  end

  def stub_frame(value)
    headers = value.nil? ? {} : {"Turbo-Frame" => value}
    @request = Struct.new(:headers).new(headers)
  end

  def test_current_turbo_frame_reads_request_header
    stub_frame "remote_modal"
    assert_equal "remote_modal", current_turbo_frame
  end

  def test_in_frame_true_for_any_frame
    stub_frame "anything"
    assert_predicate self, :in_frame?
  end

  def test_in_frame_false_when_header_absent
    stub_frame nil
    refute_predicate self, :in_frame?
  end

  def test_in_modal_true_for_primary
    stub_frame Plutonium::REMOTE_MODAL_FRAME
    assert_predicate self, :in_modal?
  end

  def test_in_modal_true_for_secondary
    stub_frame Plutonium::REMOTE_MODAL_SECONDARY_FRAME
    assert_predicate self, :in_modal?
  end

  def test_in_modal_false_for_non_modal_frame
    stub_frame "some_other_frame"
    refute_predicate self, :in_modal?
  end

  def test_in_secondary_modal_only_true_for_secondary
    stub_frame Plutonium::REMOTE_MODAL_SECONDARY_FRAME
    assert_predicate self, :in_secondary_modal?

    stub_frame Plutonium::REMOTE_MODAL_FRAME
    refute_predicate self, :in_secondary_modal?

    stub_frame nil
    refute_predicate self, :in_secondary_modal?
  end

  def test_in_kanban_modal_true_when_modal_frame_and_param_present
    stub_frame Plutonium::REMOTE_MODAL_FRAME
    @params = {Plutonium::KANBAN_MODAL_PARAM => "1"}
    assert_predicate self, :in_kanban_modal?
  end

  def test_in_kanban_modal_false_when_param_absent
    stub_frame Plutonium::REMOTE_MODAL_FRAME
    @params = {}
    refute_predicate self, :in_kanban_modal?
  end

  def test_in_kanban_modal_false_outside_a_modal_even_with_param
    # A full-page show that somehow carries the param must still show metadata.
    stub_frame nil
    @params = {Plutonium::KANBAN_MODAL_PARAM => "1"}
    refute_predicate self, :in_kanban_modal?
  end

  def test_turbo_scoped_dom_id_outside_modal_returns_base
    stub_frame nil
    assert_equal "resource-form", turbo_scoped_dom_id("resource-form")
  end

  def test_turbo_scoped_dom_id_in_primary_modal_appends_primary
    stub_frame Plutonium::REMOTE_MODAL_FRAME
    assert_equal "resource-form-primary", turbo_scoped_dom_id("resource-form")
  end

  def test_turbo_scoped_dom_id_in_secondary_modal_appends_secondary
    stub_frame Plutonium::REMOTE_MODAL_SECONDARY_FRAME
    assert_equal "resource-form-secondary", turbo_scoped_dom_id("resource-form")
  end

  def test_turbo_scoped_dom_id_accepts_symbol_returns_string
    stub_frame Plutonium::REMOTE_MODAL_FRAME
    assert_equal "interaction-form-primary", turbo_scoped_dom_id(:"interaction-form")
  end

  def test_turbo_scoped_dom_id_in_non_modal_frame_returns_base
    # A frame that isn't one of the two modal frames should not get a suffix.
    stub_frame "some_other_frame"
    assert_equal "resource-form", turbo_scoped_dom_id("resource-form")
  end
end
