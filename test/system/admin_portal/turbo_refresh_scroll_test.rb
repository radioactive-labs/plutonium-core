# frozen_string_literal: true

require "application_system_test_case"

class AdminPortal::TurboRefreshScrollTest < ApplicationSystemTestCase
  setup do
    @admin = create_admin!
    30.times { |i| create_post!(title: "Post %03d" % i, status: :published) }
  end

  test "scroll position is preserved across interactive action refresh" do
    # Visit the guarded page; rodauth redirects to multi-phase login.
    visit "/admin/blogging/posts"
    fill_in "login", with: @admin.email
    click_button "Login"
    fill_in "password", with: "password123"
    click_button "Login"

    assert_current_path "/admin/blogging/posts"
    assert_selector "table tbody tr", minimum: 10

    assert_operator page.evaluate_script("document.documentElement.scrollHeight"), :>, 1200,
      "page must be scrollable for this test to be meaningful"

    page.execute_script("window.scrollTo(0, 800)")
    sleep 0.1
    initial_scroll = page.evaluate_script("window.scrollY").to_i
    assert_operator initial_scroll, :>, 500, "scroll did not actually move (got #{initial_scroll})"

    updated_ats_before = Blogging::Post.pluck(:id, :updated_at).to_h

    # Submit via fetch so Capybara doesn't scroll the clicked button into view.
    # Pass the submit button as FormData's submitter so button_to's
    # `return_to` name/value pair is included — the same-page heuristic in
    # turbo_stream_redirect checks Referer, but return_to is what the
    # interaction controller uses to compute the redirect target.
    result = page.evaluate_async_script(<<~JS, 10)
      const cb = arguments[arguments.length - 1];
      const form = document.querySelector('form[action*="/record_actions/touch"]');
      if (!form) { cb({error: 'no touch form on page'}); return; }
      const submitter = form.querySelector('button[type=submit]');
      const token = document.querySelector('meta[name=csrf-token]')?.content || '';
      fetch(form.action, {
        method: 'POST',
        headers: {
          'Accept': 'text/vnd.turbo-stream.html',
          'X-CSRF-Token': token
        },
        body: new URLSearchParams(new FormData(form, submitter)),
        credentials: 'same-origin'
      }).then(async r => {
        const body = await r.text();
        if (r.ok && window.Turbo) Turbo.renderStreamMessage(body);
        cb({status: r.status, body: body});
      }).catch(e => cb({error: e.message}));
    JS

    assert_equal 200, result["status"], "interactive action failed: #{result.inspect}"
    assert_match %r{<turbo-stream[^>]*action="refresh"}, result["body"],
      "expected refresh stream, got: #{result["body"]}"

    using_wait_time(5) do
      changed = Blogging::Post.all.any? { |p| p.updated_at > updated_ats_before[p.id] }
      assert changed, "Touch interaction did not update any post"
    end

    # Let Turbo process the refresh stream and morph the DOM.
    sleep 0.3

    final_scroll = page.evaluate_script("window.scrollY").to_i
    assert_in_delta initial_scroll, final_scroll, 20,
      "expected scroll ~#{initial_scroll}, got #{final_scroll} (scroll was reset — refresh/preserve broken)"
  end
end
