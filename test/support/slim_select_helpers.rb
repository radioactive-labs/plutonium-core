# frozen_string_literal: true

# Drives a slim-select widget from a system test.
#
# Capybara's own `select` cannot: the native element is `display: none` and
# `aria-hidden`, so the driver refuses it ("Unable to find visible select box").
# Reaching past the widget and setting the native value is not what a user does
# either, and with a `typeahead_url` there is nothing to reach — the select
# ships with no usable options, because slim_select_controller replaces the
# client-side filter with a server fetch:
#
#   events.search = (search, currentData) => this.#typeaheadFetch(search, ...)
#
# == Why this retries the whole interaction
#
# The obvious sequence — open, click the option, assert the widget shows it —
# waits for the RESULT but never retries the CAUSE. If the click is lost (the
# option list re-rendered under it, the dropdown moved, the driver clicked a
# node that had just been replaced) then no amount of waiting recovers it: the
# form submits with nothing selected and fails later as "User must exist", or
# the assertion times out against a widget still showing its placeholder.
#
# So each attempt here is open → narrow → click → VERIFY, and a failed verify
# starts another attempt rather than waiting harder on a click that never
# landed. That is the property that makes it reliable, not the timeout.
module SlimSelectHelpers
  # @param option_text [String] the option's visible label, matched exactly
  # @param from [String, Symbol, nil] label or name of the underlying select.
  #   Optional when the page has a single widget.
  # @param search [String, nil] text to type into the widget's search box.
  #   Defaults to +option_text+. Pass it when the searchable value differs from
  #   the rendered label (a typeahead matching on email while the option shows
  #   +to_label+).
  # @param wait [Numeric] total seconds to keep retrying the interaction.
  #   Governs ATTEMPTS, not one wait: each is open -> narrow -> click -> verify.
  def select_association(option_text, from: nil, search: nil, wait: 15)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + wait

    loop do
      wrapper = slim_select_wrapper(from)
      # Also the fast path when the value is already set (a re-render that
      # preserved it, or a caller selecting the same option twice).
      return if slim_select_shows?(wrapper, option_text, wait: 0)

      try_slim_select(wrapper, option_text, search || option_text)
      return if slim_select_shows?(wrapper, option_text, wait: 1)

      next unless Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

      raise Capybara::ExpectationNotMet,
        "slim-select never showed #{option_text.inspect} after #{wait}s of retries. " \
        "The widget reads #{slim_select_text(wrapper).inspect}. " \
        "Options offered: #{slim_select_option_texts(wrapper).inspect}"
    end
  end

  private

  # One attempt. Swallows the two errors that mean "the DOM moved under me",
  # because the caller re-checks and retries — raising here would turn a
  # recoverable miss into a failed test, which is the bug this helper exists to
  # fix.
  def try_slim_select(wrapper, option_text, search)
    wrapper.find(".ss-main").click

    content = slim_select_content(wrapper)
    box = content.all(".ss-search input", wait: 1).first
    # Narrowing first is what makes the click reliable with a long list: the
    # option ends up at the top of a short list rather than somewhere inside a
    # scrolling container. With a typeahead it is also the only way to load the
    # option at all.
    box&.set(search)

    # Short wait on purpose: the list was just narrowed, so the option is there
    # or it never will be, and a long wait here buys fewer attempts from the
    # same budget — attempts are what recover a lost click.
    content.find(".ss-option", text: option_text, exact_text: true, match: :first, wait: 2).click
  rescue Capybara::ElementNotFound, Selenium::WebDriver::Error::StaleElementReferenceError
    nil
  end

  # The dropdown mounts in one of two places: into a `.ss-dropdown-container`
  # next to the select when the widget is inside a modal (so it is clipped and
  # positioned by the dialog), and into the body otherwise.
  def slim_select_content(wrapper)
    wrapper.all(".ss-dropdown-container", wait: 0).first || page
  end

  # The element that contains BOTH the native select and the widget markup
  # slim-select inserts beside it.
  def slim_select_wrapper(from)
    return page if from.nil?

    find_field(from, visible: :all, match: :first).find(:xpath, "..")
  end

  def slim_select_shows?(wrapper, option_text, wait:)
    wrapper.has_css?(".ss-main", text: option_text, wait: wait)
  end

  def slim_select_text(wrapper)
    wrapper.all(".ss-main", wait: 0).first&.text
  end

  def slim_select_option_texts(wrapper)
    slim_select_content(wrapper).all(".ss-option", wait: 0).map(&:text)
  end
end
