# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Form::Components::PasswordTest < ActiveSupport::TestCase
  Component = Plutonium::UI::Form::Components::Password
  SENTINEL = Component::SENTINEL

  # --- masked_value: the sentinel reflects the *stored* secret -------------
  #
  # The sentinel must mean "a secret is already stored — leave blank to keep
  # it". It is sourced from the persisted database value (attribute_in_database),
  # never from field.value, because on a failed re-render field.value holds the
  # user's submitted input.

  def test_new_record_renders_empty_even_with_a_typed_value
    # The failed-create re-render case: nothing is stored yet, so no phantom
    # "leave to keep" dots — the user must (re-)enter the secret.
    record = User.new(email: "typed@example.com")
    assert_nil masked_value_for(record, :email)
  end

  def test_persisted_record_with_a_stored_value_renders_the_sentinel
    record = create_user
    assert_equal SENTINEL, masked_value_for(record, :email)
  end

  def test_persisted_record_blanks_a_pending_edit_so_the_user_re_enters
    # Failed-edit re-render: the user's typed value has been assigned to the
    # record (dirty) but not saved. We render blank rather than a sentinel so
    # the user knows their entry was dropped and must re-type it — we never
    # reflect the submitted secret back into the DOM.
    record = create_user
    record.email = "pending@example.com"
    assert_nil masked_value_for(record, :email)
  end

  def test_persisted_record_with_an_unset_secret_renders_empty
    # password_hash is a real nullable column inferred as a password field.
    record = create_user(password_hash: nil)
    assert_nil masked_value_for(record, :password_hash)
  end

  # --- render side: the stored secret must never reach the DOM -------------

  def test_build_input_attributes_substitutes_sentinel_and_forces_password_type
    secret_email = "secret-#{SecureRandom.hex(4)}@val.ue"
    record = create_user(email: secret_email)
    form = build_form(record, [:email])
    component = Component.new(form.field(:email), type: :password)
    attrs = component.send(:attributes)

    assert_equal :password, attrs[:type]
    assert_equal SENTINEL, attrs[:value]
    assert_equal "new-password", attrs[:autocomplete]
    refute(
      attrs.values.map(&:to_s).any? { |v| v.include?(secret_email) },
      "the real value must never reach the DOM"
    )
  end

  def test_sentinel_field_wires_the_clear_on_edit_controller
    record = create_user(email: "secret-#{SecureRandom.hex(4)}@val.ue")
    component = Component.new(build_form(record, [:email]).field(:email), type: :password)
    attrs = component.send(:attributes)

    assert_equal SENTINEL, attrs[:value]
    assert_includes attrs[:data_controller].to_s, "password-sentinel"
    assert_includes attrs[:data_action].to_s, "beforeinput->password-sentinel#beforeinput"
    assert_equal SENTINEL, attrs[:data_password_sentinel_sentinel_value]
  end

  def test_blank_field_does_not_wire_the_clear_on_edit_controller
    # New record: nothing stored, no sentinel, so nothing to guard.
    component = Component.new(build_form(User.new, [:password_hash]).field(:password_hash), type: :password)
    attrs = component.send(:attributes)

    assert_nil attrs[:value]
    refute_includes attrs[:data_controller].to_s, "password-sentinel"
  end

  def test_sentinel_field_gets_a_keep_hint
    field = build_form(create_user, [:email]).field(:email)
    Component.new(field, type: :password).send(:attributes)
    assert_equal "Leave blank to keep the current value.", field.hint
  end

  def test_reentry_field_gets_a_reenter_hint
    record = create_user(password_hash: "stored-digest")
    record.password_hash = "pending-digest"
    field = build_form(record, [:password_hash]).field(:password_hash)
    Component.new(field, type: :password).send(:attributes)
    assert_equal "Re-enter the new value to save it.", field.hint
  end

  def test_new_record_gets_no_auto_hint
    field = build_form(User.new, [:password_hash]).field(:password_hash)
    Component.new(field, type: :password).send(:attributes)
    assert_nil field.hint
  end

  def test_author_hint_is_not_overridden
    field = build_form(create_user, [:email]).field(:email)
    field.hint("Your master key")
    Component.new(field, type: :password).send(:attributes)
    assert_equal "Your master key", field.hint
  end

  def test_cleared_stored_secret_is_not_forced_required
    # The user blanked an existing secret on a failed submit — they may have
    # intended to clear it (clear-by-blank). Don't force re-entry; let the
    # blank stand rather than trapping them with `required`.
    record = create_user(password_hash: "stored-digest")
    record.password_hash = ""
    component = Component.new(build_form(record, [:password_hash]).field(:password_hash), type: :password)
    attrs = component.send(:attributes)

    assert_nil attrs[:value]
    refute attrs[:required], "a cleared secret must not be force-required — the clear may be intentional"
  end

  def test_untouched_stored_secret_is_not_forced_required
    # password_hash is a nullable, non-presence-validated column, so any
    # `required` here would come from the re-entry guard, not the model.
    record = create_user(password_hash: "stored-digest")
    component = Component.new(build_form(record, [:password_hash]).field(:password_hash), type: :password)
    attrs = component.send(:attributes)

    assert_equal SENTINEL, attrs[:value]
    refute attrs[:required], "an untouched stored secret renders the sentinel; re-entry is not forced"
  end

  def test_edited_stored_secret_renders_blank_and_required_for_reentry
    # Failed-edit re-render: the dirty secret comes back blank (never echoed),
    # and `required` forces the user to re-type it so an untouched resubmit
    # can't silently clear the stored secret via clear-by-blank.
    record = create_user(password_hash: "stored-digest")
    record.password_hash = "pending-digest"
    component = Component.new(build_form(record, [:password_hash]).field(:password_hash), type: :password)
    attrs = component.send(:attributes)

    assert_nil attrs[:value], "an edited secret must come back blank"
    assert_equal true, attrs[:required], "blank re-entry must be forced even on a non-model-required column"
  end

  # --- extract side: blank vs nil semantics -------------------------------

  def test_normalize_maps_sentinel_back_to_nil_so_value_is_kept
    # nil → Plutonium's submitted_resource_params `.compact` drops it → the
    # existing value is preserved (the untouched-field case).
    assert_nil normalize(SENTINEL)
  end

  def test_normalize_preserves_blank_as_explicit_clear
    # "" passes through (not compacted) → an explicit clear, distinct from the
    # sentinel's "keep". This is clear-by-blank; the rendered field guards
    # against an *accidental* blank submit with `required` (see below).
    assert_equal "", normalize("")
  end

  def test_normalize_passes_a_real_new_value_through
    assert_equal "newsecret", normalize("newsecret")
  end

  def test_normalize_passes_nil_through
    assert_nil normalize(nil)
  end

  # --- routing: inferred password/secret fields reach this component ------

  def test_inferred_password_fields_route_to_the_password_component
    form = build_form(User.new(email: "x@y.z"), [:password, :api_token, :reset_password_token])

    %i[password api_token reset_password_token].each do |name|
      assert_equal :password, form.field(name).send(:infer_field_component),
        "expected #{name} to infer the :password component"
    end
  end

  def test_widened_secret_names_route_to_the_password_component
    # Names Phlexi's own heuristic misses, masked by our secret_field_name?.
    names = %i[api_key client_secret webhook_secret salt encryption_key token]
    form = build_form(User.new(email: "x@y.z"), names)

    names.each do |name|
      assert_equal :password, form.field(name).send(:infer_field_component),
        "expected #{name} to infer the :password component"
    end
  end

  def test_non_secret_fields_do_not_route_to_the_password_component
    # `key` (exact) and ordinary words must not be swept up by the widened
    # heuristic — only `*_key`, `*_secret`, `salt`, `token`, etc.
    form = build_form(User.new(email: "x@y.z"), [:email, :key, :monkey])

    %i[email key monkey].each do |name|
      refute_equal :password, form.field(name).send(:infer_field_component),
        "#{name} must not route to the password component"
    end
  end

  private

  def create_user(**attrs)
    defaults = {status: :unverified, email: "pw-#{SecureRandom.hex(6)}@example.com"}
    User.create!(defaults.merge(attrs))
  end

  def build_form(record, fields)
    Plutonium::UI::Form::Resource.new(
      record,
      resource_fields: fields,
      resource_definition: Plutonium::Definition::Base.new,
      singular_resource: false
    )
  end

  def masked_value_for(record, attr)
    Component.new(build_form(record, [attr]).field(attr)).send(:masked_value)
  end

  def normalize(input)
    Component.allocate.send(:normalize_input, input)
  end
end
