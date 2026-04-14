# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"

class Plutonium::Testing::ResourceModelTest < ActiveSupport::TestCase
  include IntegrationTestHelper
  include Plutonium::Testing::ResourceModel

  resource_tests_for Blogging::Post, portal: :admin,
    associated_with: :organization,
    sgid_routing: true

  setup do
    @org = create_organization!
    @user = create_user!
  end

  def model_test_record
    create_post!(user: @user, organization: @org)
  end
end

class Plutonium::Testing::ResourceModelHasCentsTest < ActiveSupport::TestCase
  include IntegrationTestHelper
  include Plutonium::Testing::ResourceModel

  resource_tests_for Catalog::Product, portal: :admin,
    has_cents: %i[price]

  setup do
    @org = create_organization!
    @user = create_user!
  end

  def model_test_record
    create_product!(user: @user, organization: @org)
  end
end
