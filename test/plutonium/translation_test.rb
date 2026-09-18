# frozen_string_literal: true

require "test_helper"

class Plutonium::TranslationTest < ActiveSupport::TestCase
  include I18nTestHelper

  def teardown
    Plutonium::Translation::Current.reset
    I18n.backend.reload!
  end

  test "gem locales are on the load path, below the app's own" do
    gem_paths = I18n.load_path.grep(%r{plutonium-core/config/locales/})
    app_path = I18n.load_path.index(Rails.root.join("config/locales/en.yml").to_s)

    assert gem_paths.any?, "expected config/locales/**/*.yml to be loaded"
    gem_paths.each { |p| assert_operator I18n.load_path.index(p), :<, app_path }
    assert_equal "Yes", I18n.t("plutonium.boolean.true")
  end

  test "t translates a full key" do
    assert_equal "No", Plutonium::Translation.t("plutonium.boolean.false")
  end

  test "Lazy#t returns a proc that looks the key up on call" do
    lazy = Class.new { extend Plutonium::Translation::Lazy }.t("plutonium.boolean.true")

    assert_kind_of Proc, lazy
    assert_equal "Yes", lazy.call
    assert_equal "Yes", Plutonium::Translation.resolve(lazy)
    assert_equal "plain", Plutonium::Translation.resolve("plain")
  end

  test "field_text returns nil when nothing is defined" do
    assert_nil Plutonium::Translation.field_text(Blogging::Article, :title, :placeholder)
  end

  test "field_text resolves the convention key, walking STI ancestors" do
    store(plutonium: {fields: {"blogging/post": {title: {placeholder: "Post title"}}}})

    assert_equal "Post title", Plutonium::Translation.field_text(Blogging::Article, :title, :placeholder)
    assert_nil Plutonium::Translation.field_text(Blogging::Article, :title, :hint)
  end

  test "field_text prefers the portal layer over the global one" do
    store(plutonium: {
      fields: {"blogging/article": {title: {hint: "Global"}}},
      portals: {admin_portal: {fields: {"blogging/article": {title: {hint: "Admin"}}}}}
    })

    assert_equal "Global", Plutonium::Translation.field_text(Blogging::Article, :title, :hint)
    assert_equal "Admin", Plutonium::Translation.field_text(Blogging::Article, :title, :hint, portal: AdminPortal)

    Plutonium::Translation::Current.portal = AdminPortal
    assert_equal "Admin", Plutonium::Translation.field_text(Blogging::Article, :title, :hint)
  end

  test "field_text falls back to the Rails helpers.placeholder key for placeholders only" do
    store(helpers: {placeholder: {"blogging/article": {title: "Rails placeholder"}}})

    assert_equal "Rails placeholder", Plutonium::Translation.field_text(Blogging::Article, :title, :placeholder)
    assert_nil Plutonium::Translation.field_text(Blogging::Article, :title, :hint)
  end

  test "field_text rejects unknown slots" do
    assert_raises(ArgumentError) { Plutonium::Translation.field_text(Blogging::Article, :title, :label) }
  end

  test "label_for resolves actions, scopes, filters, kanban columns and wizard steps" do
    store(plutonium: {
      actions: {"blogging/article": {publish: "Publish now"}},
      scopes: {"blogging/article": {drafts: "Drafts only"}},
      filters: {"blogging/article": {author: "Written by"}},
      kanban_columns: {"blogging/article": {in_review: "In review"}},
      portals: {admin_portal: {actions: {"blogging/article": {publish: "Publish to site"}}}}
    })

    assert_equal "Publish now", Plutonium::Translation.label_for(:action, Blogging::Article, :publish)
    assert_equal "Publish to site", Plutonium::Translation.label_for(:action, Blogging::Article, :publish, portal: AdminPortal)
    assert_equal "Drafts only", Plutonium::Translation.label_for(:scope, Blogging::Article, :drafts)
    assert_equal "Written by", Plutonium::Translation.label_for(:filter, Blogging::Article, :author)
    assert_equal "In review", Plutonium::Translation.label_for(:kanban_column, Blogging::Article, :in_review)
    assert_nil Plutonium::Translation.label_for(:action, Blogging::Article, :archive)
    assert_raises(ArgumentError) { Plutonium::Translation.label_for(:menu, Blogging::Article, :x) }
  end

  test "value_label resolves the Rails enum convention and the plutonium.values key" do
    store(activerecord: {attributes: {"blogging/article": {"status/draft": "Draft (rails)"}}})
    assert_equal "Draft (rails)", Plutonium::Translation.value_label(Blogging::Article, :status, :draft)

    store(plutonium: {values: {"blogging/article": {status: {draft: "Draft (plutonium)"}}}})
    Plutonium::Translation::Current.reset
    assert_equal "Draft (plutonium)", Plutonium::Translation.value_label(Blogging::Article, :status, "draft")

    assert_nil Plutonium::Translation.value_label(Blogging::Article, :status, :nope)
    assert_nil Plutonium::Translation.value_label(nil, :status, :draft)
  end

  test "portal_key derives the key segment from the package module" do
    assert_equal "admin_portal", Plutonium::Translation.portal_key(AdminPortal)
    assert_equal "admin_portal", Plutonium::Translation.portal_key("AdminPortal")
    assert_nil Plutonium::Translation.portal_key(nil)
  end

  test "pagy translates through Pagy's dictionary in the current locale" do
    assert_equal "Show %{limit_input} items per page",
      Plutonium::Translation.pagy("pagy.limit_tag_js", count: 10, item_name: "items")
  end

  test "wizard steps and kanban columns resolve their labels by convention" do
    wizard = Class.new(Plutonium::Wizard::Base) do
      def self.name = "OnboardingWizard"
      step :billing do
        attribute :plan, :string
        input :plan
      end
    end
    assert_equal "Billing", wizard.steps.first.label

    store(plutonium: {wizard_steps: {onboarding_wizard: {billing: "Billing details"}}})
    assert_equal "Billing details", wizard.steps.first.label

    column = Plutonium::Kanban::Column.new(:in_review, resource_class: Blogging::Article)
    assert_equal "In Review", column.label
    store(plutonium: {kanban_columns: {"blogging/post": {in_review: "Under review"}}})
    assert_equal "Under review", column.label
    assert_equal "Fixed", Plutonium::Kanban::Column.new(:in_review, label: "Fixed", resource_class: Blogging::Article).label
  end

  test "actions bound to a definition's model resolve their labels by convention" do
    action = Plutonium::Action::Simple.new(:publish)
    assert_equal "Publish", action.label

    bound = action.for_resource(Blogging::Article)
    store(plutonium: {actions: {"blogging/article": {publish: "Publish now"}}})
    assert_equal "Publish now", bound.label
    assert_equal "Publish", action.label
    assert_same bound, bound.for_resource(Blogging::Post)
  end

  test "locale_plural? reports whether the model name has one/other forms" do
    refute Plutonium::Translation.locale_plural?(Blogging::Article)

    store(activerecord: {models: {"blogging/post": {one: "Sheep", other: "Sheep"}}})
    assert Plutonium::Translation.locale_plural?(Blogging::Article)
    refute Plutonium::Translation.locale_plural?(Class.new)
  end

  test "an action keeps its model binding through with()" do
    store(plutonium: {actions: {"blogging/article": {publish: "Publish now"}}})
    bound = Plutonium::Action::Simple.new(:publish).for_resource(Blogging::Article)

    assert_equal "Publish now", bound.with(color: :primary).label
  end

  test "the standard destroy action's confirmation comes from the locale" do
    store(plutonium: {actions: {confirm_destroy: "Really delete?"}})
    assert_equal "Really delete?", Blogging::PostDefinition.new.defined_actions[:destroy].confirmation
  end

  test "a review step resolves a lazy label" do
    step = Plutonium::Wizard::ReviewStep.new(label: -> { "Lazy review" })
    assert_equal "Lazy review", step.label
  end

  test "select filter pills resolve values through the value convention" do
    filter = Plutonium::Query::Filters::Select.new(key: :status, resource_class: Blogging::Article, choices: %w[draft published])
    assert_equal "draft", filter.humanize_value("draft")

    store(activerecord: {attributes: {"blogging/post": {"status/draft": "Unpublished"}}})
    Plutonium::Translation::Current.reset
    assert_equal "Unpublished", filter.humanize_value("draft")
    assert_equal "Unpublished, published", filter.humanize_value(["draft", "published", ""])
  end

  test "value_label memoises per request" do
    store(plutonium: {values: {"blogging/article": {status: {draft: "Draft"}}}})
    assert_equal "Draft", Plutonium::Translation.value_label(Blogging::Article, :status, :draft)

    store(plutonium: {values: {"blogging/article": {status: {draft: "Changed"}}}})
    assert_equal "Draft", Plutonium::Translation.value_label(Blogging::Article, :status, :draft)

    Plutonium::Translation::Current.reset
    assert_equal "Changed", Plutonium::Translation.value_label(Blogging::Article, :status, :draft)
  end

  private

  def store(translations)
    store_translations(translations)
  end
end
