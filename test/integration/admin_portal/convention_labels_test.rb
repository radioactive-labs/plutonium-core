# frozen_string_literal: true

require "test_helper"

# Labels a definition never declares (placeholders, hints, descriptions,
# scope / filter / action names, enum values, kanban columns) resolve from
# locale keys by convention, with a portal-specific layer on top.
class AdminPortal::ConventionLabelsTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    @admin = create_admin!
    login_as_admin(@admin)
    @post = create_post!
  end

  teardown do
    I18n.backend.reload!
    Plutonium::Translation::Current.reset
  end

  test "form placeholder and hint come from plutonium.fields" do
    store(plutonium: {fields: {"blogging/post": {title: {
      placeholder: "A short, descriptive title", hint: "Shown in search results"
    }}}})

    get "/admin/blogging/posts/new"

    assert_response :success
    assert_includes response.body, 'placeholder="A short, descriptive title"'
    assert_includes response.body, "Shown in search results"
  end

  test "an explicit lazy translation on the input wins over the convention" do
    store(
      forms: {shared: {title_placeholder: "From the explicit key"}},
      plutonium: {fields: {"blogging/post": {title: {placeholder: "From the convention"}}}}
    )
    definition = Blogging::PostDefinition
    definition.input :title, placeholder: definition.t("forms.shared.title_placeholder")

    get "/admin/blogging/posts/new"

    assert_includes response.body, 'placeholder="From the explicit key"'
    refute_includes response.body, "From the convention"
  ensure
    Blogging::PostDefinition.defined_inputs.delete(:title)
  end

  test "display description comes from plutonium.fields" do
    store(plutonium: {fields: {"blogging/post": {body: {description: "Rendered as Markdown"}}}})

    get "/admin/blogging/posts/#{@post.id}"

    assert_response :success
    assert_includes response.body, "Rendered as Markdown"
  end

  test "scope, filter and action labels come from plutonium.* keys" do
    store(plutonium: {
      scopes: {"blogging/post": {drafts: "Unpublished drafts"}},
      filters: {"blogging/post": {title: "Working title"}},
      actions: {"blogging/post": {touch: "Bump this post"}}
    })

    without_explicit_label(Blogging::TouchPost) { get "/admin/blogging/posts" }

    assert_response :success
    assert_includes response.body, "Unpublished drafts"
    assert_includes response.body, "Working title contains..."
    assert_includes response.body, "Bump this post"
  end

  test "an interaction's explicit presents label wins over the convention" do
    store(plutonium: {actions: {"blogging/post": {touch: "Bump this post"}}})

    get "/admin/blogging/posts"

    assert_includes response.body, ">Touch<"
    refute_includes response.body, "Bump this post"
  end

  test "the portal layer wins over the global key" do
    store(plutonium: {
      actions: {"blogging/post": {touch: "Bump this post"}},
      portals: {admin_portal: {actions: {"blogging/post": {touch: "Bump on the admin site"}}}}
    })

    without_explicit_label(Blogging::TouchPost) { get "/admin/blogging/posts" }

    assert_includes response.body, "Bump on the admin site"
    refute_includes response.body, "Bump this post"
  end

  test "enum values resolve through the Rails enum convention" do
    store(activerecord: {attributes: {"blogging/post": {"status/draft": "Unpublished"}}})

    get "/admin/blogging/posts/#{@post.id}"

    assert_includes response.body, "Unpublished"
  end

  test "a lazy label on a field resolves on displays and tables" do
    store(labels: {post_title: "Headline"})
    Blogging::PostDefinition.field :title, label: Blogging::PostDefinition.t("labels.post_title")

    get "/admin/blogging/posts"
    assert_includes response.body, "Headline"

    get "/admin/blogging/posts/#{@post.id}"
    assert_includes response.body, "Headline"
  ensure
    Blogging::PostDefinition.defined_fields.delete(:title)
  end

  test "kanban column labels come from plutonium.kanban_columns" do
    store(plutonium: {kanban_columns: {task: {todo: "To do next"}}})
    Task.create!(title: "Todo Alpha", status: "todo")

    get "/admin/tasks?view=kanban"

    assert_response :success
    assert_includes response.body, "To do next"
  ensure
    Task.delete_all
  end

  private

  # Drop the interaction's `presents label:` for the block so the convention
  # key gets its turn; the action reads the label lazily, so no rebuild needed.
  def without_explicit_label(interaction)
    original = interaction.presentation_metadata
    interaction.presentation_metadata = original.except(:label)
    yield
  ensure
    interaction.presentation_metadata = original
  end

  def store(translations)
    I18n.backend.store_translations(:en, translations)
  end
end
