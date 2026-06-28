# frozen_string_literal: true

require "test_helper"

# The model-free attachment bridge, exercised against BOTH real backends the dummy
# enables — ActiveStorage and Shrine (the layer active_shrine wraps). A wizard
# stages an attachment field as its backend's direct-upload token (an AS signed_id,
# or a Shrine cached-file JSON); {Plutonium::Wizard::Attachments.resolve} revives it
# by token SHAPE (JSON ⇒ Shrine, else ⇒ ActiveStorage) into a uniform {Resolved}
# view, so the review + preview render either backend identically.
class Plutonium::Wizard::AttachmentsTest < ActiveSupport::TestCase
  def upload_blob(name: "logo.png", type: "image/png")
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new("as-bytes"), filename: name, content_type: type)
  end

  def upload_shrine(name: "photo.jpg", type: "image/jpeg")
    io = StringIO.new("shrine-bytes")
    io.define_singleton_method(:original_filename) { name }
    io.define_singleton_method(:content_type) { type }
    Shrine.upload(io, :cache)
  end

  test "an ActiveStorage signed_id resolves to a uniform view over the blob" do
    blob = upload_blob
    resolved = Plutonium::Wizard::Attachments.resolve(blob.signed_id)
    assert_equal 1, resolved.size
    r = resolved.first
    assert_equal blob.filename.to_s, r.filename
    assert_equal blob.content_type, r.content_type
    assert_equal blob.signed_id, r.signed_id, "re-postable token is the original staged token"
    assert r.representable?
    assert_equal "png", r.extension
  end

  test "a Shrine cached-file token resolves to a uniform view over the uploaded file" do
    cached = upload_shrine
    token = cached.to_json
    r = Plutonium::Wizard::Attachments.resolve(token).first
    # Shrine names them differently (original_filename / mime_type) — the adapter
    # normalizes to filename / content_type.
    assert_equal cached.original_filename, r.filename
    assert_equal cached.mime_type, r.content_type
    assert_equal token, r.signed_id, "re-post the same cached JSON"
  end

  test "routes by token shape: an AS signed_id isn't JSON, a Shrine token is" do
    blob = upload_blob(name: "a.png")
    cached = upload_shrine(name: "b.jpg")
    resolved = Plutonium::Wizard::Attachments.resolve([blob.signed_id, cached.to_json])
    assert_equal "a.png", resolved[0].filename
    assert_equal "b.jpg", resolved[1].filename
  end

  test "drops blank, nil, and tampered tokens without raising" do
    blob = upload_blob
    resolved = Plutonium::Wizard::Attachments.resolve([blob.signed_id, "", nil, "not-a-real-token"])
    assert_equal 1, resolved.size
    assert_equal blob.filename.to_s, resolved.first.filename
  end

  test "nil / empty resolves to empty" do
    assert_empty Plutonium::Wizard::Attachments.resolve(nil)
    assert_empty Plutonium::Wizard::Attachments.resolve([])
  end

  test "field? detects file-alias inputs (nested or flat options)" do
    assert Plutonium::Wizard::Attachments.field?({options: {as: :uppy}})
    assert Plutonium::Wizard::Attachments.field?({options: {as: :file}})
    assert Plutonium::Wizard::Attachments.field?({as: :attachment})
    refute Plutonium::Wizard::Attachments.field?({options: {as: :string}})
    refute Plutonium::Wizard::Attachments.field?(nil)
  end
end
