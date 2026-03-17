# frozen_string_literal: true

module SharedTests
  module CatalogProductTests
    extend ActiveSupport::Concern

    included do
      # Index
      test "lists products" do
        create_product!
        get "#{path_prefix}/catalog/products"
        assert_response :success
      end

      # Show
      test "shows a product" do
        product = create_product!
        get "#{path_prefix}/catalog/products/#{product.id}"
        assert_response :success
      end

      # New
      test "renders new product form" do
        create_category!
        get "#{path_prefix}/catalog/products/new"
        assert_response :success
      end

      # Create
      test "creates a product" do
        category = create_category!
        assert_difference -> { Catalog::Product.count }, 1 do
          post "#{path_prefix}/catalog/products", params: {
            catalog_product: {name: "New Product", category_id: category.id, price_cents: 1999}
          }
        end
        assert_response :redirect
      end

      # Edit
      test "renders edit product form" do
        product = create_product!
        get "#{path_prefix}/catalog/products/#{product.id}/edit"
        assert_response :success
      end

      # Update (non-association fields only)
      test "updates a product" do
        product = create_product!
        patch "#{path_prefix}/catalog/products/#{product.id}", params: {
          catalog_product: {name: "Updated Product"}
        }
        assert_response :redirect
        assert_equal "Updated Product", product.reload.name
      end

      # Destroy
      test "destroys a product" do
        product = create_product!
        assert_difference -> { Catalog::Product.count }, -1 do
          delete "#{path_prefix}/catalog/products/#{product.id}"
        end
      end

      # Nested resources
      test "lists variants for a product (has_many)" do
        product = create_product!
        create_variant!(product: product)
        get "#{path_prefix}/catalog/products/#{product.id}/nested_variants"
        assert_response :success
      end

      test "lists reviews for a product (has_many)" do
        product = create_product!
        create_review!(product: product)
        get "#{path_prefix}/catalog/products/#{product.id}/nested_reviews"
        assert_response :success
      end

      test "shows product detail (has_one)" do
        product = create_product!
        create_product_detail!(product: product)
        get "#{path_prefix}/catalog/products/#{product.id}/nested_product_detail"
        assert_response :success
      end

      test "lists comments on a product (polymorphic)" do
        product = create_product!
        create_comment!(commentable: product)
        get "#{path_prefix}/catalog/products/#{product.id}/nested_comments"
        assert_response :success
      end

      # Categories
      test "lists categories" do
        create_category!
        get "#{path_prefix}/catalog/categories"
        assert_response :success
      end

      test "shows a category (self-referential)" do
        parent = create_category!(name: "Parent")
        create_category!(name: "Child", parent: parent)
        # Ensure category is visible in scoped portals by having a product in it
        create_product!(category: parent)
        get "#{path_prefix}/catalog/categories/#{parent.id}"
        assert_response :success
      end

      # Reviews
      test "lists reviews" do
        product = create_product!
        create_review!(product: product)
        get "#{path_prefix}/catalog/reviews"
        assert_response :success
      end
    end
  end
end
