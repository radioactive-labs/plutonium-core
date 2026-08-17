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

# Regression: the helper used to build policies as `new(record: record, ...)`, and
# ActionPolicy swallows that keyword into a splat, leaving `record` nil. Every
# record-dependent predicate was therefore asserted against nil.
#
# Blogging::PostPolicy#publish? is `record.draft?` and #archive? is `record.published?`.
# The matrix below only holds if the record genuinely arrives *and* carries its state;
# against a nil record the helper raises NoMethodError instead.
class Plutonium::Testing::ResourcePolicyRecordArgTest < ActiveSupport::TestCase
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
    create_post!(user: @user, organization: @org, status: :draft)
  end

  def policy_matrix
    {
      publish: %i[admin member],
      archive: []
    }
  end
end
