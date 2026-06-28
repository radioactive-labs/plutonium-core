# frozen_string_literal: true

require "test_helper"

# The model-free attachment bridge, exercised against BOTH real backends the dummy
# enables — ActiveStorage and Shrine (the layer active_shrine wraps). A wizard
# stages an attachment field as its backend's direct-upload token (an AS signed_id,
# or a Shrine cached-file JSON); {Plutonium::Wizard::Attachments.resolve} revives it
# by token SHAPE (JSON ⇒ Shrine, else ⇒ ActiveStorage) into a uniform {Resolved}
# view, so the review + preview render either backend identically.
class Plutonium::Wizard::AttachmentsTest < ActiveSupport::TestCase
  # A Shrine uploader subclass that records which storage it cached into, so a test
  # can prove staging routed the upload through the field's `uploader:` (not base
  # `Shrine`). It inherits the globally registered storages.
  class RecordingUploader < Shrine
    class << self
      attr_accessor :last_storage
      def upload(io, storage, **)
        self.last_storage = storage
        super
      end
    end
  end

  def upload_blob(name: "logo.png", type: "image/png")
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new("as-bytes"), filename: name, content_type: type)
  end

  def shrine_io(name: "photo.jpg", type: "image/jpeg", bytes: "shrine-bytes")
    io = StringIO.new(bytes)
    io.define_singleton_method(:original_filename) { name }
    io.define_singleton_method(:content_type) { type }
    io
  end

  def upload_shrine(name: "photo.jpg", type: "image/jpeg")
    Shrine.upload(shrine_io(name:, type:), :cache)
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

  test "uploader: routes Shrine staging through the given uploader" do
    RecordingUploader.last_storage = nil
    io = shrine_io
    token = Plutonium::Wizard::Attachments.stage_upload(io, backend: :shrine, uploader: RecordingUploader)

    assert_equal :cache, RecordingUploader.last_storage, "the file was cached via the given uploader"
    assert_equal "cache", JSON.parse(token)["storage"], "still a standard cached-file token"
    # the token is uploader-agnostic, so it still resolves for display unchanged
    assert_equal io.original_filename, Plutonium::Wizard::Attachments.resolve(token).first.filename
  end

  test "uploader: accepts a class name string" do
    RecordingUploader.last_storage = nil
    Plutonium::Wizard::Attachments.stage_upload(shrine_io, backend: :shrine, uploader: RecordingUploader.name)
    assert_equal :cache, RecordingUploader.last_storage
  end

  test "uploader: is rejected for the active_storage backend" do
    err = assert_raises(ArgumentError) do
      Plutonium::Wizard::Attachments.stage_upload(shrine_io, backend: :active_storage, uploader: RecordingUploader)
    end
    assert_match(/uploader:/, err.message)
  end

  test "uploader: must be a Shrine uploader class" do
    err = assert_raises(ArgumentError) do
      Plutonium::Wizard::Attachments.stage_upload(shrine_io, backend: :shrine, uploader: String)
    end
    assert_match(/Shrine uploader/, err.message)
  end

  # An uploader carrying an Attacher validation, to exercise stage-phase validation.
  class ValidatingUploader < Shrine
    plugin :validation_helpers
    Attacher.validate { validate_max_size 4 } # 4 bytes; the default test file is larger
  end

  test "validation_errors flags a file that violates the effective uploader's rules" do
    token = Plutonium::Wizard::Attachments.stage_upload(shrine_io, backend: :shrine, uploader: ValidatingUploader)
    # staging itself only caches — the over-size file IS cached (Uploader.upload runs no validations)…
    assert token.present?
    # …but stage-phase validation (run on the step via the effective uploader) catches it.
    errors = Plutonium::Wizard::Attachments.validation_errors(token, backend: :shrine, uploader: ValidatingUploader)
    assert errors.any?, "the over-size file fails the uploader's validation"
  end

  test "validation_errors is empty for a valid file" do
    token = Plutonium::Wizard::Attachments.stage_upload(shrine_io(bytes: "ok"), backend: :shrine, uploader: ValidatingUploader)
    assert_empty Plutonium::Wizard::Attachments.validation_errors(token, backend: :shrine, uploader: ValidatingUploader)
  end

  test "validation_errors is a no-op for base Shrine with no rules and for ActiveStorage" do
    shrine_token = upload_shrine.to_json
    assert_empty Plutonium::Wizard::Attachments.validation_errors(shrine_token, backend: :shrine),
      "base Shrine has no Attacher.validate here → nothing to enforce"
    assert_empty Plutonium::Wizard::Attachments.validation_errors(upload_blob.signed_id, backend: :active_storage),
      "ActiveStorage has no attacher validations at this layer"
  end

  test "validation_errors tolerates a tampered token without raising" do
    assert_empty Plutonium::Wizard::Attachments.validation_errors("not-a-real-token", backend: :shrine, uploader: ValidatingUploader)
  end

  test "field? detects file-alias inputs (nested or flat options)" do
    assert Plutonium::Wizard::Attachments.field?({options: {as: :uppy}})
    assert Plutonium::Wizard::Attachments.field?({options: {as: :file}})
    assert Plutonium::Wizard::Attachments.field?({as: :attachment})
    refute Plutonium::Wizard::Attachments.field?({options: {as: :string}})
    refute Plutonium::Wizard::Attachments.field?(nil)
  end
end
