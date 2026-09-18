---
title: "Introducing Plutonium i18n: every string translatable, the Rails way"
titleTemplate: "Plutonium Blog"
date: 2026-09-17
description: The text a framework renders has always been the framework's, not yours. Plutonium now routes every string it draws through a locale file, so translating the UI is a matter of YAML and nothing else.
author: Stefan Froelich
tags: [announcement, i18n, rails]
draft: true
---

# Introducing Plutonium i18n: every string translatable, the Rails way

<BlogMeta />

You have always been able to translate your own app. Rails has shipped `I18n.t`, per-model attribute names and localized dates since long before you needed them. What you could not translate was the framework on top. The button that says "Create", the "Search..." in the filter box, the flash that a record was saved, the empty-state line, the sentence under the paginator: an admin framework ships those in English, baked into views you adopted the framework precisely so you would never open. Translating them meant forking them.

Plutonium now routes every string it renders through a locale file, and resolves every label it derives from a key through the Rails i18n conventions you already know. Translating the UI is a matter of YAML. Nothing in a definition, a policy or a controller changes.

## The strings come from YAML

Plutonium's own text lives under `config/locales/en/*.yml`, in a `plutonium` namespace, loaded at the lowest precedence. Rails' normal load order does the rest: your app's `config/locales` beats a portal's, a portal's beats the gem's. To reword a fixed string, or translate it, copy its key into your own file:

```yaml
# config/locales/en.yml
en:
  plutonium:
    boolean:
      "true": "On"
      "false": "Off"
```

That one move covers renaming "On" to "Active" in English and translating it to another language. There is no second mechanism to learn for the second case.

## The labels you never wrote translate too

The strings above are the easy half. The interesting half is the text a definition never spells out. An action, a scope, a filter, a kanban column, a field's placeholder: each one defaults to a humanized version of its key, and each has a convention key that a locale file can supply.

```yaml
en:
  plutonium:
    actions:
      blogging/post:
        publish: "Publish now"
    scopes:
      blogging/post:
        drafts: "Drafts"
    fields:
      blogging/post:
        title:
          placeholder: "A short, descriptive title"
          hint: "Shown in search results"
```

A field you never annotated is already translatable. You did not declare a placeholder to get one, and you do not declare a key to translate it: Plutonium looks it up by the model's `i18n_key`, the same way `human_attribute_name` walks ancestors, so a key on `blogging/post` also serves its STI subclasses. Model and attribute names flow from the standard Rails `activerecord` keys, which is why column headers, page titles and flashes come along the moment you provide them. Nothing is declared twice, and the exception, an explicit label you do want to spell out, gets a named place: the definition's own `t`, resolved per request in the right locale.

## Switching locale is a Rails around_action

Plutonium reads `I18n.locale` on every render and never sets it, so you switch the way you would in any Rails app. The dummy app's admin portal wires an `EN | ES` toggle into the top bar and remembers the choice per session:

```ruby
included do
  around_action :switch_locale
end

def switch_locale(&)
  session[:locale] = params[:locale] if params[:locale].present?
  locale = session[:locale].to_s.to_sym
  locale = I18n.default_locale unless I18n.available_locales.include?(locale)
  I18n.with_locale(locale, &)
end
```

Pick ES and the portal answers in Spanish: the heading, the search box, the filters and scopes, the column headers, the row and page actions, the status badges, the pager and the CRUD flashes. The heading translates because the definition sets it with the same lazy `t`, `index_page_title t("blog.index.title")`, that inputs and labels use. Two things stay English by design: the record data, because it is yours and not the framework's, and any label a definition hardcodes as a plain string, like the `column :user, label: "Author"` you can see in the shot sitting next to the translated `Autor`.

![The dummy admin portal rendered in Spanish, with the EN | ES switch in the top bar](/images/blog/i18n-es-admin.png)

## Even the parts that aren't Rails views

Two surfaces never touch Rails' server-side `t`, and both come along.

The Stimulus controllers bundled with the gem read their strings from a JSON blob the layout renders once per page in the current locale. Override a key in YAML and the bundled JavaScript's text changes with it, no rebuild. And pagination, which has its own dictionary, is translated by [Pagy](https://ddnexus.github.io/pagy/resources/i18n) in about thirty-five languages out of the box. Plutonium syncs Pagy's locale to `I18n.locale` on every render, so the same `around_action` that switched the chrome switched the pager, in the screenshot above, for free.

## Ship a half-translated locale

You do not have to finish a language before you use it. The dummy demo translates the blog-posts screen and leaves the rest of the app, the dates, and Rodauth's own flashes to fall back to English through `config.i18n.fallbacks`. That matters more than it sounds: the test environment turns on `raise_on_missing_translations`, so a page under a half-done locale would otherwise blow up on the first key you had not reached yet. With fallbacks on, a found-via-fallback string is not missing. Translate the screens your users live on first, ship it, and fill in the rest as you go.

## Adding a language

A full second locale is the usual Rails checklist: a [rails-i18n](https://github.com/svenfuchs/rails-i18n) locale for dates and numbers, a Pagy dictionary, `rodauth-i18n` if you use Rodauth, the `plutonium` namespace translated from the gem's English files, and your own models and attributes. Plutonium itself ships only English, and hands you the door to the rest.

The [internationalization reference](/reference/i18n) has the full key catalogue and the exact resolution order for every slot.
