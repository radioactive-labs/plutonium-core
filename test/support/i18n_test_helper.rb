# frozen_string_literal: true

# Store translations for one test without them being clobbered.
#
# The Simple backend loads its locale files lazily on the first lookup after
# a `reload!`, deep-merging the files OVER anything stored before that point.
# Initialise first so a stored override wins; `I18n.backend.reload!` in
# teardown then drops it again.
module I18nTestHelper
  def store_translations(data = nil, locale: :en, **inline)
    I18n.backend.send(:init_translations) unless I18n.backend.initialized?
    # The Simple backend silently discards a store for a locale outside the
    # memoised available set while enforcement is on; a foreign locale has to
    # be stored with enforcement off and the set cleared.
    enforcing = I18n.enforce_available_locales
    I18n.enforce_available_locales = false
    I18n.backend.store_translations(locale, data || inline)
    I18n.config.clear_available_locales_set
  ensure
    I18n.enforce_available_locales = enforcing
  end

  # Run the block with `locale` accepted as available (the dummy app only
  # declares :en) and active.
  def with_extra_locale(locale, &)
    original = I18n.enforce_available_locales
    I18n.enforce_available_locales = false
    I18n.with_locale(locale, &)
  ensure
    I18n.enforce_available_locales = original
  end
end
