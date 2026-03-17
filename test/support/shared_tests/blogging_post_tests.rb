# frozen_string_literal: true

module SharedTests
  module BloggingPostTests
    extend ActiveSupport::Concern

    included do
      # Index
      test "lists posts" do
        create_post!
        get "#{path_prefix}/blogging/posts"
        assert_response :success
      end

      # Show
      test "shows a post" do
        post_record = create_post!
        get "#{path_prefix}/blogging/posts/#{post_record.id}"
        assert_response :success
      end

      # New
      test "renders new post form" do
        get "#{path_prefix}/blogging/posts/new"
        assert_response :success
      end

      # Create
      test "creates a post" do
        create_organization! unless @org
        assert_difference -> { Blogging::Post.count }, 1 do
          post "#{path_prefix}/blogging/posts", params: {
            blogging_post: {title: "New Post", body: "New body", status: :draft}
          }
        end
        assert_response :redirect
      end

      # Edit
      test "renders edit post form" do
        post_record = create_post!
        get "#{path_prefix}/blogging/posts/#{post_record.id}/edit"
        assert_response :success
      end

      # Update (non-association fields only)
      test "updates a post" do
        post_record = create_post!
        patch "#{path_prefix}/blogging/posts/#{post_record.id}", params: {
          blogging_post: {title: "Updated Title"}
        }
        assert_response :redirect
        assert_equal "Updated Title", post_record.reload.title
      end

      # Destroy
      test "destroys a post" do
        post_record = create_post!
        assert_difference -> { Blogging::Post.count }, -1 do
          delete "#{path_prefix}/blogging/posts/#{post_record.id}"
        end
      end

      # STI
      test "lists articles (STI subtype)" do
        create_article!
        get "#{path_prefix}/blogging/articles"
        assert_response :success
      end

      test "shows an article (STI subtype)" do
        article = create_article!
        get "#{path_prefix}/blogging/articles/#{article.id}"
        assert_response :success
      end

      test "lists tutorials (STI subtype)" do
        create_tutorial!
        get "#{path_prefix}/blogging/tutorials"
        assert_response :success
      end

      test "shows a tutorial (STI subtype)" do
        tutorial = create_tutorial!
        get "#{path_prefix}/blogging/tutorials/#{tutorial.id}"
        assert_response :success
      end

      # Nested resources
      test "lists comments on a post (polymorphic)" do
        post_record = create_post!
        create_comment!(commentable: post_record)
        get "#{path_prefix}/blogging/posts/#{post_record.id}/nested_comments"
        assert_response :success
      end

      test "shows post detail (has_one)" do
        post_record = create_post!
        create_post_detail!(post: post_record)
        get "#{path_prefix}/blogging/posts/#{post_record.id}/nested_post_detail"
        assert_response :success
      end

      test "lists post tags (has_many through)" do
        post_record = create_post!
        tag = create_tag!
        create_post_tag!(post: post_record, tag: tag)
        get "#{path_prefix}/blogging/posts/#{post_record.id}/nested_post_tags"
        assert_response :success
      end

      # Tags
      test "lists tags" do
        create_tag!
        get "#{path_prefix}/blogging/tags"
        assert_response :success
      end
    end
  end
end
