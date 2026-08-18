# frozen_string_literal: true

require "test_helper"

# StorefrontPortal registers Blogging::Post but not Run — a run dispatched
# elsewhere still targets this resource_class, so it must not break this index.
class StorefrontPortal::InteractionRunBannerTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup { Plutonium::Interaction::Run.delete_all }

  teardown { Plutonium::Interaction::Run.delete_all }

  test "an in-progress run targeting a shared resource does not break an index in a portal without Run registered" do
    post_record = create_post!(status: :published)
    TestPostRun.create!(
      initiator: create_user!,
      scoped_entity: create_organization!,
      target_type: "Blogging::Post",
      target_ids: [post_record.id],
      state: "running",
      progress_total: 1,
      progress_done: 0
    )

    get "/storefront/blogging/posts"

    assert_response :success
    refute_match(/pu-running-banner/, response.body)
  end
end
