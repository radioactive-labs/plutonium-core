# frozen_string_literal: true

# Shrine setup for the dummy so it can exercise the **active_shrine** attachment
# backend alongside ActiveStorage. active_shrine is a thin ActiveRecord layer over
# Shrine; this is the storage/plugin config it needs. We deliberately do NOT include
# `ActiveShrine::Model` globally or strip the ActiveStorage railtie — so both
# backends coexist, each declared per-model (AS `has_one_attached` vs an
# `ActiveShrine::Model`-including model). Backgrounding is omitted (synchronous
# promotion) to keep the test app simple.
require "shrine"
require "shrine/storage/file_system"

# Store under the app's `public/` (ABSOLUTE Rails.root path — a relative "public"
# resolves against the CWD, which is the repo root when the suite runs from there,
# scattering uploads outside the dummy). The `uploads/cache|store` prefixes make the
# files web-servable at `/uploads/…`, so the preview/review <img> actually loads.
Shrine.storages = {
  cache: Shrine::Storage::FileSystem.new(Rails.root.join("public").to_s, prefix: "uploads/cache"),
  store: Shrine::Storage::FileSystem.new(Rails.root.join("public").to_s, prefix: "uploads")
}

Shrine.plugin :activerecord
Shrine.plugin :cached_attachment_data
Shrine.plugin :restore_cached_data
Shrine.plugin :determine_mime_type, analyzer: :marcel
Shrine.plugin :upload_endpoint, url: true
