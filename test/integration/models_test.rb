# frozen_string_literal: true

require "test_helper"

class ModelsTest < ActiveSupport::TestCase
  include DataHelpers

  teardown do
    Comment.delete_all
    Blogging::PostTag.delete_all
    Blogging::PostDetail.delete_all
    Blogging::Post.delete_all
    Blogging::Tag.delete_all
    Catalog::Review.delete_all
    Catalog::ProductDetail.delete_all
    Catalog::Variant.delete_all
    Catalog::Product.delete_all
    Catalog::Category.delete_all
    OrganizationUser.delete_all
    Organization.delete_all
    User.delete_all
  end

  # STI
  test "STI: Article and Tutorial inherit from Post" do
    org = create_organization!
    user = create_user!
    article = Blogging::Article.create!(title: "Article", body: "Content", user: user, organization: org)
    tutorial = Blogging::Tutorial.create!(title: "Tutorial", body: "Content", user: user, organization: org)

    assert_equal "Blogging::Article", article.type
    assert_equal "Blogging::Tutorial", tutorial.type
    assert_equal 2, Blogging::Post.count
    assert_equal 1, Blogging::Article.count
    assert_equal 1, Blogging::Tutorial.count
  end

  test "STI: base Post query includes all subtypes" do
    org = create_organization!
    user = create_user!
    Blogging::Article.create!(title: "A", body: "B", user: user, organization: org)
    Blogging::Tutorial.create!(title: "C", body: "D", user: user, organization: org)
    Blogging::Post.create!(title: "E", body: "F", user: user, organization: org)

    assert_equal 3, Blogging::Post.count
  end

  # Polymorphic
  test "polymorphic: comments on posts and products" do
    org = create_organization!
    user = create_user!
    post_record = create_post!(user: user, organization: org)
    product = create_product!(user: user, organization: org)

    c1 = create_comment!(commentable: post_record, user: user, body: "Post comment")
    c2 = create_comment!(commentable: product, user: user, body: "Product comment")

    assert_equal "Blogging::Post", c1.commentable_type
    assert_equal "Catalog::Product", c2.commentable_type
    assert_includes post_record.comments, c1
    assert_includes product.comments, c2
  end

  # Self-referential
  test "self-referential: category parent and subcategories" do
    parent = create_category!(name: "Electronics")
    child1 = create_category!(name: "Phones", parent: parent)
    child2 = create_category!(name: "Laptops", parent: parent)

    assert_equal parent, child1.parent
    assert_includes parent.subcategories, child1
    assert_includes parent.subcategories, child2
    assert_equal 2, parent.subcategories.count
  end

  # has_many :through
  test "has_many through: post tags" do
    org = create_organization!
    user = create_user!
    post_record = create_post!(user: user, organization: org)
    tag1 = create_tag!(name: "Ruby")
    tag2 = create_tag!(name: "Rails")
    create_post_tag!(post: post_record, tag: tag1)
    create_post_tag!(post: post_record, tag: tag2)

    assert_equal 2, post_record.tags.count
    assert_includes post_record.tags, tag1
    assert_includes post_record.tags, tag2
  end

  # has_one
  test "has_one: post detail" do
    org = create_organization!
    user = create_user!
    post_record = create_post!(user: user, organization: org)
    detail = create_post_detail!(post: post_record)

    assert_equal detail, post_record.post_detail
    assert_equal post_record, detail.post
  end

  test "has_one: product detail" do
    org = create_organization!
    user = create_user!
    product = create_product!(user: user, organization: org)
    detail = create_product_detail!(product: product)

    assert_equal detail, product.product_detail
  end

  # has_cents
  test "has_cents: product price" do
    org = create_organization!
    user = create_user!
    product = create_product!(user: user, organization: org, price_cents: 4999)

    assert_equal 4999, product.price_cents
    assert_equal BigDecimal("49.99"), product.price
  end

  test "has_cents: variant price" do
    org = create_organization!
    user = create_user!
    product = create_product!(user: user, organization: org)
    variant = create_variant!(product: product, price_cents: 1250)

    assert_equal 1250, variant.price_cents
    assert_equal BigDecimal("12.50"), variant.price
  end

  # Enum
  test "enum: post status" do
    org = create_organization!
    user = create_user!
    post_record = create_post!(user: user, organization: org, status: :draft)

    assert post_record.draft?
    post_record.update!(status: :published)
    assert post_record.published?
    post_record.update!(status: :archived)
    assert post_record.archived?
  end

  test "enum: product status" do
    org = create_organization!
    user = create_user!
    product = create_product!(user: user, organization: org, status: :draft)

    assert product.draft?
    product.update!(status: :active)
    assert product.active?
    product.update!(status: :discontinued)
    assert product.discontinued?
  end

  # Nested attributes
  test "nested attributes: product with variants" do
    org = create_organization!
    user = create_user!
    category = create_category!
    product = Catalog::Product.create!(
      name: "Bundle", category: category, user: user, organization: org,
      variants_attributes: [
        {name: "Small", sku: "SM-1", price_cents: 999, stock_count: 5},
        {name: "Large", sku: "LG-1", price_cents: 1499, stock_count: 3}
      ]
    )

    assert_equal 2, product.variants.count
  end

  test "nested attributes: product with product_detail" do
    org = create_organization!
    user = create_user!
    category = create_category!
    product = Catalog::Product.create!(
      name: "Detailed", category: category, user: user, organization: org,
      product_detail_attributes: {specifications: "Specs here", warranty_info: "2 years"}
    )

    assert_equal "Specs here", product.product_detail.specifications
  end

  # Scopes
  test "scopes: post published/draft/archived" do
    org = create_organization!
    user = create_user!
    create_post!(user: user, organization: org, status: :draft)
    create_post!(user: user, organization: org, status: :published)
    create_post!(user: user, organization: org, status: :archived)

    assert_equal 1, Blogging::Post.published.count
    assert_equal 1, Blogging::Post.drafts.count
    assert_equal 1, Blogging::Post.archived.count
  end

  # Dependent destroy
  test "dependent destroy: deleting post destroys comments" do
    org = create_organization!
    user = create_user!
    post_record = create_post!(user: user, organization: org)
    create_comment!(commentable: post_record, user: user)
    create_comment!(commentable: post_record, user: user)

    assert_equal 2, Comment.count
    post_record.destroy
    assert_equal 0, Comment.count
  end

  # Organization membership
  test "organization: users through organization_users" do
    org = create_organization!
    user1 = create_user!
    user2 = create_user!
    create_membership!(organization: org, user: user1, role: :admin)
    create_membership!(organization: org, user: user2, role: :member)

    assert_equal 2, org.users.count
    assert_includes org.users, user1
    assert_includes org.users, user2
  end
end
