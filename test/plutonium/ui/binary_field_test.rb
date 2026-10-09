# frozen_string_literal: true

require "test_helper"

# A `binary` column used to infer a plain text input, so editing a record
# echoed the raw bytes into the page and the show page printed them.
class Plutonium::UI::BinaryFieldTest < ActiveSupport::TestCase
  BYTES = "\x89PNG\r\n\x1A\n".b

  def sink(fingerprint: BYTES) = KitchenSink.new(fingerprint:)

  test "a binary column infers a file input" do
    html = Plutonium::UI::Form::Base.new(sink).field(:fingerprint).component_for(nil).call

    assert_includes html, 'type="file"'
  end

  test "the input says what is stored and that a blank submit keeps it" do
    record = KitchenSink.create!(name: "Sink", organization: Organization.create!(name: "Org"), fingerprint: BYTES)
    record.fingerprint = "a rejected upload"
    field = Plutonium::UI::Form::Base.new(record).field(:fingerprint)
    field.binary_tag.call

    assert_equal "Stored: 8 Bytes. Choose a file to replace it.", field.hint
  end

  test "a new record gets no hint" do
    field = Plutonium::UI::Form::Base.new(sink).field(:fingerprint)
    field.binary_tag.call

    assert_nil field.hint
  end

  test "an uploaded file is read into bytes" do
    upload = Rack::Test::UploadedFile.new(StringIO.new(BYTES), "application/octet-stream", original_filename: "fp.bin")
    component = Plutonium::UI::Form::Base.new(sink).field(:fingerprint).binary_tag

    assert_equal({fingerprint: BYTES}, component.extract_input({fingerprint: ActionDispatch::Http::UploadedFile.new(tempfile: upload.tempfile)}))
  end

  # nil is dropped by the controller's `.compact`, so the stored bytes stay.
  test "submitting without a file extracts nil" do
    component = Plutonium::UI::Form::Base.new(sink).field(:fingerprint).binary_tag

    assert_equal({fingerprint: nil}, component.extract_input({fingerprint: ""}))
  end

  test "the show page shows the size, never the bytes" do
    html = Plutonium::UI::Display::Base.new(sink).field(:fingerprint).component_for(nil).call

    assert_includes html, "Binary data (8 Bytes)"
    refute_includes html, "PNG"
  end

  test "a table cell shows the size, never the bytes" do
    html = Plutonium::UI::Table::Base::Display.new(sink).field(:fingerprint).component_for(nil).call

    assert_includes html, "Binary data (8 Bytes)"
  end

  test "an empty binary column shows nothing" do
    html = Plutonium::UI::Display::Base.new(sink(fingerprint: nil)).field(:fingerprint).component_for(nil).call

    refute_includes html, "Binary data"
  end
end
