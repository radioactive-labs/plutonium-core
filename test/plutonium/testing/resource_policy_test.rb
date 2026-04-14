# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"

class Plutonium::Testing::ResourcePolicyTest < ActiveSupport::TestCase
  include IntegrationTestHelper
  include Plutonium::Testing::ResourcePolicy

  resource_tests_for Blogging::Post, portal: :admin

  setup do
    @admin = create_admin!
    @org = create_organization!
    @user = create_user!
  end

  def policy_roles
    {admin: -> { @admin }, member: -> { @user }}
  end

  def policy_record
    create_post!(user: @user, organization: @org)
  end

  def policy_matrix
    {
      index: %i[admin member],
      show: %i[admin member],
      create: %i[admin member],
      update: %i[admin member],
      destroy: %i[admin member]
    }
  end
end
