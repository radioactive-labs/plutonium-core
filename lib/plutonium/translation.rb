# frozen_string_literal: true

module Plutonium
  # Translation lookups for everything Plutonium renders.
  #
  # All of Plutonium's own strings live under the `plutonium.*` namespace in
  # `config/locales`, loaded at the lowest precedence so a package, portal or
  # the host application can override any key. Beyond the fixed strings, this
  # module resolves the *derived* text a definition never declares (field
  # placeholders and hints, action / scope / filter labels, kanban columns,
  # wizard steps) by convention, with a portal-specific layer on top:
  #
  #   plutonium.portals.<portal>.fields.<model>.<attr>.placeholder
  #   plutonium.fields.<model>.<attr>.placeholder
  #
  # `<portal>` is the package namespace (`admin_portal`), `<model>` the
  # `model_name.i18n_key` (`blogging/article`), walked up `lookup_ancestors`
  # the way `human_attribute_name` does. Every lookup is a plain hash probe on
  # the I18n backend and returns nil when nothing is defined, so a missing key
  # costs a few microseconds and renders exactly what it did before.
  #
  # Not named `Plutonium::I18n` on purpose: that constant would shadow `::I18n`
  # inside every `module Plutonium` body.
  module Translation
    extend self

    # Request-local portal, set by the controller so lookups deep in the query
    # layer (filter labels, kanban rejections) see the same portal the view does.
    class Current < ActiveSupport::CurrentAttributes
      attribute :portal, :value_labels
    end

    # Kinds of derived labels resolved by convention. The value is the key
    # segment under `plutonium.` (and under `plutonium.portals.<portal>.`).
    LABEL_KINDS = {
      action: "actions",
      scope: "scopes",
      filter: "filters",
      kanban_column: "kanban_columns",
      wizard_step: "wizard_steps"
    }.freeze

    # Field slots resolved by convention when the definition leaves them blank.
    FIELD_SLOTS = %i[placeholder hint description].freeze

    # Plain translation of a fixed Plutonium string. Full keys only; there is
    # no lazy-lookup prefix, so every call site is greppable.
    def t(key, **options)
      ::I18n.t(key, **options)
    end
    alias_method :translate, :t

    # Translate a Pagy dictionary key with the current I18n locale. Pagy keeps
    # its own (faster) dictionaries and a thread-local locale; sync the locale
    # per call so a host that switches `I18n.locale` per request is honoured.
    def pagy(key, **options)
      ::Pagy::I18n.locale = ::I18n.locale.to_s
      ::Pagy::I18n.translate(key, **options)
    end

    # Resolve an option value that may be a lazy translation (a proc built by
    # {Lazy#t}) or any other zero-arity callable.
    def resolve(value)
      value.is_a?(Proc) ? value.call : value
    end

    # The i18n key segment for a package / portal module, or nil for the main app.
    def portal_key(package)
      return if package.nil?

      (package.respond_to?(:name) ? package.name : package.to_s).underscore
    end

    # Text for a field slot (:placeholder, :hint, :description) resolved by
    # convention. Returns nil when no key is defined.
    #
    #   field_text(Blogging::Article, :title, :placeholder)
    #   # => plutonium.portals.<portal>.fields.blogging/article.title.placeholder
    #   #    plutonium.fields.blogging/article.title.placeholder
    #   #    helpers.placeholder.blogging/article.title   (placeholder only)
    def field_text(klass, attribute, slot, portal: Current.portal)
      raise ArgumentError, "unknown field slot #{slot.inspect}" unless FIELD_SLOTS.include?(slot)

      model_keys_for(klass).each do |model_key|
        [portal_scope(portal, "fields"), "plutonium.fields"].compact.each do |scope|
          value = probe("#{scope}.#{model_key}.#{attribute}.#{slot}")
          return value if value
        end

        next unless slot == :placeholder

        value = probe("helpers.placeholder.#{model_key}.#{attribute}")
        return value if value
      end

      nil
    end

    # Whether the locale defines one/other forms for the model's name
    # (`activerecord.models.<model>: {one:, other:}`), on it or an ancestor.
    def locale_plural?(klass)
      return false unless klass.respond_to?(:i18n_scope)

      model_keys_for(klass).any? { |key| ::I18n.t("#{klass.i18n_scope}.models.#{key}", default: nil).is_a?(Hash) }
    end

    # Fill the convention text into `options` for each slot the definition
    # left blank, e.g. `fill_field_text(opts, Blogging::Post, :title, :placeholder, :hint)`.
    def fill_field_text(options, klass, attribute, *slots)
      slots.each do |slot|
        next if options.key?(slot)

        text = field_text(klass, attribute, slot)
        options = options.merge(slot => text) if text
      end
      options
    end

    # Label for a derived key (an action, scope, filter, kanban column or
    # wizard step) resolved by convention. Returns nil when no key is defined,
    # so callers keep their `humanize` fallback.
    #
    #   label_for(:action, Blogging::Article, :publish)
    #   # => plutonium.portals.<portal>.actions.blogging/article.publish
    #   #    plutonium.actions.blogging/article.publish
    def label_for(kind, klass, key, portal: Current.portal)
      segment = LABEL_KINDS.fetch(kind) { raise ArgumentError, "unknown label kind #{kind.inspect}" }

      model_keys_for(klass).each do |model_key|
        [portal_scope(portal, segment), "plutonium.#{segment}"].compact.each do |scope|
          value = probe("#{scope}.#{model_key}.#{key}")
          return value if value
        end
      end

      nil
    end

    # Label for an enum-like value rendered by a badge or filter, resolved the
    # way Rails resolves enum attribute values:
    #
    #   activerecord.attributes.<model>.<attribute>/<value>   (Rails convention)
    #   plutonium.values.<model>.<attribute>.<value>
    #
    # Badges render once per cell, so the answer is memoised for the request.
    def value_label(klass, attribute, value, portal: Current.portal)
      return if value.nil? || klass.nil?

      cache = (Current.value_labels ||= {})
      cache.fetch([::I18n.locale, portal_key(portal), klass, attribute, value.to_s]) do |cache_key|
        cache[cache_key] = uncached_value_label(klass, attribute, value, portal)
      end
    end

    def uncached_value_label(klass, attribute, value, portal)
      model_keys_for(klass).each do |model_key|
        [portal_scope(portal, "values"), "plutonium.values"].compact.each do |scope|
          found = probe("#{scope}.#{model_key}.#{attribute}.#{value}")
          return found if found
        end

        if klass.respond_to?(:human_attribute_name)
          found = probe("#{klass.i18n_scope}.attributes.#{model_key}.#{attribute}/#{value}")
          return found if found
        end
      end

      nil
    end

    # Class-level `t` for definitions, interactions and wizards. Returns a lazy
    # proc so the lookup runs on every render in the request's locale rather
    # than once, in whatever locale was active when the class loaded.
    #
    #   input :email, placeholder: t("forms.shared.email_placeholder")
    #   action :publish, label: t("plutonium.actions.blogging/article.publish")
    module Lazy
      def t(key, **options)
        -> { ::I18n.t(key, **options) }
      end
    end

    private :uncached_value_label

    private

    def probe(key)
      value = ::I18n.t(key, default: nil)
      value.is_a?(String) ? value : nil
    end

    def portal_scope(portal, segment)
      key = portal_key(portal)
      key && "plutonium.portals.#{key}.#{segment}"
    end

    # `blogging/article`, then each STI / abstract ancestor that has a model
    # name, mirroring ActiveModel::Translation#human_attribute_name.
    def model_keys_for(klass)
      return [] unless klass.respond_to?(:model_name)

      ancestors = klass.respond_to?(:lookup_ancestors) ? klass.lookup_ancestors : [klass]
      ancestors.filter_map { |k| k.model_name.i18n_key if k.respond_to?(:model_name) }
    end
  end
end
