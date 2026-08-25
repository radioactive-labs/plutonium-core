# frozen_string_literal: true

require "test_helper"
require "tempfile"
require "base64"

# Regression for the active_shrine + resource double-extraction bug.
#
# A plain server-side file input (`input :file, as: :file`, no direct_upload)
# backed by active_shrine posts a single-read Rack upload. Resource param
# extraction builds a throwaway `extraction_record` and assigns to it before
# #create assigns to the real record — and a Shrine attacher CONSUMES the
# tempfile to EOF on assign, so the second read hit "IOError: closed stream".
# Active Storage escaped it (its attachment reflects as an association, which
# extraction skips); Shrine's virtual `file=` accessor does not.
#
# AdminPortal::ShrineDocDefinition declares `input :file, as: :file`.
class AdminPortal::ShrineDocUploadTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    @admin = create_admin!
    login_as_admin(@admin)
  end

  def multipart_png(filename)
    bytes = Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==")
    file = Tempfile.new([filename, ".png"], binmode: true)
    file.write(bytes)
    file.rewind
    Rack::Test::UploadedFile.new(file.path, "image/png", original_filename: "#{filename}.png")
  end

  test "a raw multipart shrine upload survives param extraction and attaches on create" do
    assert_difference -> { ShrineDoc.count }, 1 do
      post "/admin/shrine_docs", params: {shrine_doc: {title: "Report", file: multipart_png("report")}}
    end
    assert_response :redirect

    doc = ShrineDoc.order(:id).last
    assert_equal "Report", doc.title
    assert doc.file.present?, "expected the uploaded file to be attached (not consumed during extraction)"
  end

  # Regression for #113: attachment_input_keys only covered inputs explicitly
  # declared with a file `as:` (:file/:uppy/:attachment). An AUTO-DETECTED
  # attachment (ShrineDoc's :banner — `has_one_attached` with no `input`
  # declaration in the definition) was invisible to the guard, got assigned to
  # the throwaway extraction record, and its single-read upload was consumed —
  # so the real assignment in create/update raised "IOError: closed stream".
  test "an upload for an auto-detected (undeclared) attachment survives param extraction" do
    assert_difference -> { ShrineDoc.count }, 1 do
      post "/admin/shrine_docs", params: {shrine_doc: {title: "Auto", banner: multipart_png("banner")}}
    end
    assert_response :redirect

    doc = ShrineDoc.order(:id).last
    assert_equal "Auto", doc.title
    assert doc.banner.present?, "expected the auto-detected attachment to attach (not consumed during extraction)"
  end

  test "an upload for an auto-detected attachment survives param extraction on update" do
    doc = ShrineDoc.create!(title: "Before")

    patch "/admin/shrine_docs/#{doc.id}", params: {shrine_doc: {title: "After", banner: multipart_png("banner")}}
    assert_response :redirect

    doc.reload
    assert_equal "After", doc.title
    assert doc.banner.present?, "expected the auto-detected attachment to attach (not consumed during extraction)"
  end
end
