# frozen_string_literal: true

module Plutonium
  module Wizard
    # Bridges a wizard's staged attachment value to the displayable attachment the
    # `Uppy` input and `Display::Components::Attachment` render — **model-free and
    # backend-agnostic**, for a bare `attribute :photo, :string` + `input :photo,
    # as: :uppy, direct_upload: true` field (no `using:` model needed).
    #
    # A wizard stages plain strings, so an attachment field holds its backend's own
    # direct-upload token: ActiveStorage's **signed_id** (an opaque signed string)
    # or active_shrine/Shrine's **cached-file data** (a JSON object). Those are the
    # only two shapes, and they're distinguishable — a Shrine token parses as JSON,
    # an AS signed_id doesn't — so we revive each through its own backend with no
    # model and no per-field configuration.
    #
    # Resolution is **display-only**: staging and `execute` (which assigns the token
    # straight to a model attachment — both AS and active_shrine accept it) never
    # call it. The two backends' native objects answer DIFFERENT method names
    # (`filename`/`content_type` vs `original_filename`/`mime_type`), so a resolved
    # token is wrapped in {Resolved}, a uniform view exposing exactly what the
    # display + preview components call. See the wizard-attachments design spec.
    module Attachments
      module_function

      # Resolve a staged attachment token (or array of them) into uniform
      # {Resolved} view(s).
      #
      # @param value [String, Array, nil] the staged token(s).
      # @return [Array<Resolved>] resolved attachments; blank, tampered, or
      #   unrecognized tokens are dropped (never raised), so a bad token can't 500
      #   the form or the review.
      def resolve(value)
        Array(value).filter_map { |token| resolve_token(token) }
      end

      # Whether a step input renders as an attachment (its `as:` is a file alias),
      # so its staged token should be resolved for display. Keys off the form's
      # canonical file-input alias set, so the two never drift.
      def field?(input_options)
        as = input_options&.dig(:options, :as) || input_options&.dig(:as)
        Plutonium::UI::Form::Base::Builder::FILE_INPUT_TYPES.include?(as&.to_sym)
      end

      # SERVER-SIDE staging: turn a submitted attachment value into a token string
      # to stage in `data`, minting one from an uploaded file when needed.
      #
      # Handles every shape a step POST can carry for an attachment field:
      # - an already-minted token String (direct upload, or the hidden preview field
      #   on re-submit) → kept verbatim;
      # - an uploaded file (IO-like) → uploaded to the backend's cache, returning its
      #   token (an AS signed_id, or Shrine cached-file JSON);
      # - blank / no selection → nil (the caller drops the key so the previously
      #   staged token survives a Back/re-submit);
      # - an Array (multiple) → each element mapped, blanks dropped.
      #
      # @param backend [Symbol, nil] per-field override; nil → the configured default.
      # @param uploader [Class, String, nil] a Shrine uploader to cache through
      #   (`:shrine` backend only) — its cache-stage plugins (mime/dimension
      #   extraction, `generate_location`, validations) run instead of base Shrine's.
      #   The minted token stays uploader-agnostic, so display + `execute` promotion
      #   are unaffected. Ignored shape for ActiveStorage (raises if given).
      def stage_upload(value, backend: nil, uploader: nil)
        if value.is_a?(Array)
          value.filter_map { |v| stage_upload(v, backend:, uploader:) }.presence
        elsif value.is_a?(String)
          value.presence
        elsif value.respond_to?(:read)
          upload_to_cache(value, backend || attachment_backend, uploader:)
        end
      end

      # The default server-side staging backend: the configured one, else
      # auto-detected (active_shrine loaded → Shrine, else ActiveStorage).
      def attachment_backend
        Plutonium.configuration.wizards.attachment_backend ||
          (defined?(ActiveShrine) ? :shrine : :active_storage)
      end

      # Run the EFFECTIVE Shrine uploader's attacher validations against a staged
      # token (or array of them), returning the validation messages — so a file that
      # violates the uploader's `validate_*` rules is rejected at the STEP (stage
      # phase), not deferred to `execute`'s model assignment.
      #
      # The effective uploader is the field's `uploader:` if given, else base
      # `Shrine` — both of which may carry `Attacher.validate` rules. Returns `[]`
      # when the field isn't Shrine-backed (ActiveStorage has no attacher here), when
      # nothing is staged, or when the effective uploader declares no validations.
      #
      # @param value [String, Array, nil] the staged token(s).
      # @param backend [Symbol, nil] per-field override; nil → the configured default.
      # @param uploader [Class, String, nil] the field's `uploader:` option.
      # @return [Array<String>] validation messages (empty ⇒ valid).
      def validation_errors(value, backend: nil, uploader: nil)
        return [] unless (backend || attachment_backend).to_sym == :shrine

        klass = shrine_uploader(uploader)
        # Shrine's `validation` plugin is OPTIONAL — without it (or `validation_helpers`)
        # the Attacher has no `#errors` and nothing to enforce. Detect it up front so a
        # plugin-less app is a clean no-op, not a per-step rescued NoMethodError.
        return [] unless klass::Attacher.method_defined?(:errors)

        Array(value).flat_map { |token| token_validation_errors(klass, token) }
      end

      # Validate one cached token through an uploader's attacher. A broad rescue
      # (like {resolve_token}) — a tampered/expired token shouldn't 500 the step; it
      # surfaces at `execute` instead, where it's caught as a RecordInvalid.
      def token_validation_errors(uploader_class, token)
        return [] if token.blank?

        attacher = uploader_class::Attacher.new
        attacher.assign(token)
        Array(attacher.errors)
      rescue => e
        Rails.logger.warn { "[Plutonium::Wizard] attachment validation skipped: #{e.class}: #{e.message}" }
        []
      end
      private_class_method :token_validation_errors

      # Upload a file to the backend's CACHE and return its re-postable token. The
      # file lives in cache until `execute` assigns the token to a real attachment
      # (which promotes it); an abandoned upload is reaped by the backend's own
      # unattached-cache cleanup.
      def upload_to_cache(file, backend, uploader: nil)
        case backend.to_sym
        when :shrine
          shrine_uploader(uploader).upload(file, :cache).to_json
        when :active_storage
          raise ArgumentError, "input `uploader:` is only supported for the :shrine backend" if uploader
          ActiveStorage::Blob.create_and_upload!(
            io: file, filename: file.original_filename, content_type: file.content_type
          ).signed_id
        else
          raise ArgumentError, "unknown wizard attachment backend: #{backend.inspect}"
        end
      end
      private_class_method :upload_to_cache

      # Resolve an `uploader:` option to the Shrine uploader class to cache through.
      # nil → base `Shrine`; a class is used as-is; a String/Symbol is constantized.
      # Anything that isn't a Shrine subclass is a configuration error (fail loud).
      def shrine_uploader(uploader)
        return Shrine if uploader.nil?

        klass = uploader.is_a?(Class) ? uploader : uploader.to_s.safe_constantize
        unless klass.is_a?(Class) && klass <= Shrine
          raise ArgumentError, "input `uploader:` must be a Shrine uploader class, got #{uploader.inspect}"
        end
        klass
      end
      private_class_method :shrine_uploader

      # Revive one token through whichever backend owns it, wrapped in {Resolved}. A
      # broad rescue is warranted here (unlike elsewhere): the token is arbitrary,
      # user-supplied input reconstituted at a render boundary, and the two backends
      # raise different error classes for a tampered/expired token — none of which
      # should take down the page.
      def resolve_token(token)
        return if token.blank?

        source = shrine_uploaded_file(token) || active_storage_blob(token)
        source && Resolved.new(source, token)
      rescue => e
        Rails.logger.warn { "[Plutonium::Wizard] could not resolve attachment token: #{e.class}: #{e.message}" }
        nil
      end
      private_class_method :resolve_token

      # A Shrine cached-file token is JSON (`{"id":…,"storage":"cache",…}`); an AS
      # signed_id isn't. Parse-success → Shrine materializes it from the globally
      # registered storages (no model, no per-field uploader needed for a `.url`).
      def shrine_uploaded_file(token)
        return unless defined?(Shrine)

        data = begin
          JSON.parse(token)
        rescue JSON::ParserError, TypeError
          nil
        end
        return unless data.is_a?(Hash)

        Shrine.uploaded_file(data)
      end
      private_class_method :shrine_uploaded_file

      def active_storage_blob(token)
        ActiveStorage::Blob.find_signed(token) if defined?(ActiveStorage::Blob)
      end
      private_class_method :active_storage_blob

      # A uniform view over a resolved attachment so the review display + the uppy
      # preview don't care whether the source is an ActiveStorage `Blob`
      # (`filename`/`content_type`/`representable?`) or a Shrine `UploadedFile`
      # (`original_filename`/`mime_type`, none of the AS-only methods). Exposes
      # exactly what those components call.
      class Resolved
        # @param source the backend object (AS Blob or Shrine UploadedFile).
        # @param token  [String] the ORIGINAL staged token — what the hidden preview
        #   field re-posts to preserve the upload across a Back/re-submit, and what
        #   `execute` assigns to the model attachment.
        def initialize(source, token)
          @source = source
          @token = token
        end

        # `url` is lazy (called at render, inside a request, where AS url options
        # exist) — never eager at resolve time.
        def url(*args) = @source.url(*args)

        # The re-postable token, surfaced under the name the uppy input reads.
        def signed_id = @token

        def filename = (@source.try(:filename) || @source.try(:original_filename)).to_s

        def content_type = @source.try(:content_type) || @source.try(:mime_type)

        def representable? = @source.try(:representable?) || content_type.to_s.start_with?("image/")

        def extension = @source.try(:extension).presence || File.extname(filename).delete(".").presence

        def present? = true
      end
    end
  end
end
