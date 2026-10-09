# frozen_string_literal: true

require "test_helper"

class AdminPortal::BinaryUploadTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    login_as_admin(create_admin!)
    @sink = KitchenSink.create!(name: "Sink", organization: Organization.create!(name: "Org #{SecureRandom.hex(4)}"))
  end

  def upload(bytes)
    Rack::Test::UploadedFile.new(StringIO.new(bytes), "application/octet-stream", original_filename: "fp.bin")
  end

  test "the edit form is multipart" do
    get "/admin/kitchen_sinks/#{@sink.id}/edit"

    assert_response :success
    assert_includes response.body, 'enctype="multipart/form-data"'
  end

  test "uploading a file stores its bytes" do
    patch "/admin/kitchen_sinks/#{@sink.id}", params: {kitchen_sink: {name: "Sink", fingerprint: upload("\x00\x01\xFF".b)}}

    assert_equal "\x00\x01\xFF".b, @sink.reload.fingerprint
  end

  test "saving without choosing a file keeps the stored bytes" do
    @sink.update!(fingerprint: "\x00\x01\xFF".b)

    patch "/admin/kitchen_sinks/#{@sink.id}", params: {kitchen_sink: {name: "Renamed", fingerprint: ""}}

    assert_equal "Renamed", @sink.reload.name
    assert_equal "\x00\x01\xFF".b, @sink.fingerprint
  end
end
