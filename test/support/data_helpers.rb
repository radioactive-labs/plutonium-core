# frozen_string_literal: true

module DataHelpers
  def create_user!(email: "user#{SecureRandom.hex(4)}@example.com", password: "password123", status: :verified)
    User.create!(email: email, password: password, status: status)
  end

  def create_admin!(email: "admin#{SecureRandom.hex(4)}@example.com", password: "password123", status: :verified)
    Admin.create!(email: email, password: password, status: status)
  end

  def create_organization!(name: "Org #{SecureRandom.hex(4)}")
    Organization.create!(name: name)
  end

  def create_membership!(organization:, user:, role: :member)
    OrganizationUser.create!(organization: organization, user: user, role: role)
  end

  def create_post!(user: nil, organization: nil, title: "Post #{SecureRandom.hex(4)}", body: "Body content", status: :draft, type: nil)
    user ||= @user || create_user!
    organization ||= @org || create_organization!
    klass = type ? "Blogging::#{type}".constantize : Blogging::Post
    klass.create!(title: title, body: body, user: user, organization: organization, status: status)
  end

  def create_article!(user: nil, organization: nil, **attrs)
    create_post!(type: "Article", user: user, organization: organization, **attrs)
  end

  def create_tutorial!(user: nil, organization: nil, **attrs)
    create_post!(type: "Tutorial", user: user, organization: organization, **attrs)
  end

  def create_tag!(name: "Tag #{SecureRandom.hex(4)}", color: "#3B82F6")
    Blogging::Tag.create!(name: name, color: color)
  end

  def create_post_tag!(post:, tag:)
    Blogging::PostTag.create!(post: post, tag: tag)
  end

  def create_post_detail!(post:, seo_title: "SEO Title", seo_description: "SEO Description", canonical_url: "https://example.com")
    Blogging::PostDetail.create!(post: post, seo_title: seo_title, seo_description: seo_description, canonical_url: canonical_url)
  end

  def create_comment!(commentable:, user: nil, body: "Comment #{SecureRandom.hex(4)}")
    user ||= @user || create_user!
    Comment.create!(body: body, commentable: commentable, user: user)
  end

  def create_category!(name: "Category #{SecureRandom.hex(4)}", description: nil, parent: nil)
    Catalog::Category.create!(name: name, description: description, parent: parent)
  end

  def create_product!(category: nil, user: nil, organization: nil, name: "Product #{SecureRandom.hex(4)}", price_cents: 1999, status: :draft, **attrs)
    category ||= create_category!
    user ||= @user || create_user!
    organization ||= @org || create_organization!
    Catalog::Product.create!(name: name, category: category, user: user, organization: organization, price_cents: price_cents, status: status, **attrs)
  end

  def create_variant!(product:, name: "Variant #{SecureRandom.hex(4)}", sku: "SKU-#{SecureRandom.hex(4)}", price_cents: 999, stock_count: 10)
    Catalog::Variant.create!(name: name, sku: sku, product: product, price_cents: price_cents, stock_count: stock_count)
  end

  def create_product_detail!(product:, specifications: "Specs", warranty_info: "1 year warranty")
    Catalog::ProductDetail.create!(product: product, specifications: specifications, warranty_info: warranty_info)
  end

  def create_review!(product:, user: nil, title: "Review #{SecureRandom.hex(4)}", body: "Review body", rating: 4, verified: false)
    user ||= @user || create_user!
    Catalog::Review.create!(product: product, user: user, title: title, body: body, rating: rating, verified: verified)
  end

end
