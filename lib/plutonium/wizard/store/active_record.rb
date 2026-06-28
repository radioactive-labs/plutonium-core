# frozen_string_literal: true

module Plutonium
  module Wizard
    module Store
      # Shipped store, backed by the +plutonium_wizard_sessions+ table via {Session}.
      class ActiveRecord < Base
        # A +data+ blob encrypted at rest (§8.1, the wizard's +encrypt_data+ opt-in)
        # is stored as a SELF-DESCRIBING envelope INSIDE the jsonb column:
        # +{ "_enc" => "<ciphertext>" }+. The row therefore decrypts based on its own
        # shape, independent of the wizard's CURRENT +encrypt_data?+ (which may have
        # been toggled after the row was written). Only +data+ (the step field values)
        # is encrypted; +tracked_records+ holds record GIDs and stays in clear.
        ENCRYPTED_ENVELOPE_KEY = "_enc"

        def read(instance_key)
          row = Session.find_by(instance_key: instance_key)
          row && to_state(row)
        end

        # Upsert the run's state. Concurrency-safe (§6.2): two requests can write the
        # same run (double-submit, two tabs, the first-step create race). A blind
        # overwrite would let the later writer clobber the earlier one's staged data
        # (last-writer-wins). Instead:
        #
        # - **Create** (no row yet): insert. If a concurrent create won the unique
        #   +instance_key+ index (RecordNotUnique), fall through to the merge path.
        # - **Update** (row exists): take a row lock, then compare the version the
        #   caller's +state+ was read at against the row's CURRENT version. Equal →
        #   no concurrent writer, write +state+ verbatim (honors this request's
        #   prunes/deletions). Differs (or the caller never read a version — it lost
        #   a create race) → a concurrent advance committed; call the +merge+ block
        #   with the latest committed {State} so the two sides are combined, and
        #   write the result. The lock serializes writers; the version check keeps
        #   the merge off the normal single-writer path.
        #
        # +merge+ is optional — a blockless caller keeps last-writer-wins (the
        # store-contract callers that don't model concurrency). The runner always
        # passes one.
        def write(instance_key, state, cleanup_after:, &merge)
          row = Session.find_or_initialize_by(instance_key: instance_key)

          if row.new_record?
            assign_row(row, state, cleanup_after)
            begin
              row.save!
              return to_state(row)
            rescue ::ActiveRecord::RecordNotUnique
              # Lost the create race — the row now exists. Re-fetch and merge.
              row = Session.find_by!(instance_key: instance_key)
            end
          end

          write_locked(row, state, cleanup_after, merge)
        end

        def complete(instance_key)
          row = Session.find_by!(instance_key: instance_key)
          row.update!(status: "completed", completed_at: Time.current, data: {}, tracked_records: {}, visited: [])
        end

        def clear(instance_key)
          Session.where(instance_key: instance_key).delete_all
        end

        def completed?(instance_key:)
          Session.status_completed.where(instance_key: instance_key).exists?
        end

        private

        # Update an existing row under a row lock, merging when a concurrent writer
        # moved it past the version the caller read. Returns the written {State}
        # (carrying the bumped +lock_version+ so the caller's next write is current).
        def write_locked(row, state, cleanup_after, merge)
          row.with_lock do
            final = (merge && stale_for_merge?(row, state)) ? merge.call(to_state(row)) : state
            assign_row(row, final, cleanup_after)
            row.save!
          end
          to_state(row)
        end

        # Whether the row has moved since the caller read it (so a verbatim write
        # would clobber a concurrent advance): the caller never read a version (nil
        # — it thought it was creating, i.e. lost a create race), or its version is
        # behind the row's current one.
        def stale_for_merge?(row, state)
          state.lock_version.nil? || state.lock_version != row.lock_version
        end

        # Copy a {State} onto the row's columns. Never touches +lock_version+ —
        # ActiveRecord manages it (the WHERE-clause check + increment on save).
        def assign_row(row, state, cleanup_after)
          row.wizard = state.wizard
          row.current_step = state.current_step
          row.status ||= "in_progress"
          row.data = encode_data(state.data, state.wizard)
          row.tracked_records = state.persisted
          row.visited = state.visited
          row.owner = state.owner
          row.anchor = state.anchor
          row.scope = state.scope
          row.token = state.token
          row.engine = state.engine
          row.expires_at = cleanup_after ? Time.current + cleanup_after : nil
        end

        def to_state(row)
          State.new(
            wizard: row.wizard,
            instance_key: row.instance_key,
            current_step: row.current_step,
            status: row.status,
            data: decode_data(row.data, row.wizard),
            persisted: row.tracked_records,
            visited: row.visited,
            owner: row.owner,
            anchor: row.anchor,
            scope: row.scope,
            token: row.token,
            engine: row.engine,
            lock_version: row.lock_version
          )
        end

        # Encrypt the run's field data at rest when the wizard opts in via
        # `encrypt_data`; a non-encrypting wizard stores the plain hash. Wrapped in
        # a self-describing {ENCRYPTED_ENVELOPE_KEY} envelope (see the class note).
        def encode_data(data, wizard_name)
          return data unless encrypting?(wizard_name)

          cipher = with_encryption_context(wizard_name) do
            ::ActiveRecord::Encryption.encryptor.encrypt(JSON.generate(data))
          end
          {ENCRYPTED_ENVELOPE_KEY => cipher}
        end

        # Reverse of {#encode_data}: an envelope is decrypted from the row's SHAPE
        # (not the wizard's current flag); any other value is a plain, never-
        # encrypted blob and is returned as-is.
        def decode_data(stored, wizard_name)
          return stored unless stored.is_a?(Hash) && stored.key?(ENCRYPTED_ENVELOPE_KEY)

          clear = with_encryption_context(wizard_name) do
            ::ActiveRecord::Encryption.encryptor.decrypt(stored[ENCRYPTED_ENVELOPE_KEY])
          end
          JSON.parse(clear)
        end

        # Whether the wizard opted into at-rest encryption. A name that doesn't
        # resolve to a loaded class (e.g. a renamed/removed wizard, or a synthetic
        # store-test name) can carry no `encrypt_data` declaration to honour, so it
        # is treated as clear — existing rows decode by SHAPE regardless.
        def encrypting?(wizard_name)
          wizard_name.to_s.safe_constantize&.encrypt_data? || false
        end

        # Run an encrypt/decrypt, translating ActiveRecord's lazy, context-free
        # configuration error into one that names the wizard and points at the fix —
        # `encrypt_data` is opt-in, so a missing key set is an author error, not a
        # runtime surprise to swallow.
        def with_encryption_context(wizard_name)
          yield
        rescue ::ActiveRecord::Encryption::Errors::Configuration => e
          raise ::ActiveRecord::Encryption::Errors::Configuration,
            "#{wizard_name} declares `encrypt_data` but ActiveRecord encryption is not " \
            "configured (set active_record.encryption.{primary_key,deterministic_key," \
            "key_derivation_salt}). Original error: #{e.message}"
        end
      end
    end
  end
end
