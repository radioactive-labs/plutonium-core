---
title: "Plutonium and Rails i18n: every string translatable"
titleTemplate: "Plutonium Blog"
date: 2026-09-17
description: Admin frameworks hardcode their own chrome, so translating one means forking its views. Plutonium routes every string it renders through a locale file and resolves every derived label by convention, so nothing in a definition changes.
author: Stefan Froelich
tags: [i18n, rails]
draft: true
---

# Plutonium and Rails i18n: every string translatable

<BlogMeta />

The text an admin framework renders is not yours. The button that says "Create", the "Search..." in the filter box, the flash that says a record was saved, the empty-state line, the pagination sentence: the framework ships them in English, baked into its views. Translating the app you built on top means reaching into those views, which is exactly the code you adopted a framework to avoid touching.

Plutonium renders every one of those strings through a locale file, and resolves every label it derives from a key through the Rails i18n conventions you already know. Nothing in a definition, a policy or a controller changes to translate the UI.

## The strings come from YAML

Plutonium ships its own text under `config/locales/en/*.yml`, all under a `plutonium` namespace, loaded at the lowest precedence. Rails' normal load order does the rest: your app's `config/locales` beats a portal's, a portal's beats the gem's. To reword a fixed string, copy its key into your own file:

```yaml
# config/locales/en.yml
en:
  plutonium:
    boolean:
      "true": "On"
      "false": "Off"
```

That is the same move whether you are translating to another language or just renaming "On" to "Active" in English.

## Labels resolve by convention

The interesting part is the text a definition never spells out. An action, a scope, a filter, a kanban column, a wizard step, a field's placeholder or hint: each defaults to a humanized version of its key, and each has a convention key that takes precedence over that default.

```yaml
en:
  plutonium:
    actions:
      blogging/post:
        publish: "Publish now"
    scopes:
      blogging/post:
        drafts: "Drafts"
    filters:
      blogging/post:
        author: "Written by"
    fields:
      blogging/post:
        title:
          placeholder: "A short, descriptive title"
          hint: "Shown in search results"
```

The model segment is the resource's `model_name.i18n_key`, so a key on `blogging/post` also serves an STI subclass, the same way `human_attribute_name` walks ancestors. Model and attribute names themselves already flow from the Rails `activerecord.models` and `activerecord.attributes` keys, which is why column headers, page titles and flashes translate the moment you provide them. And every convention key has a portal-scoped variant under `plutonium.portals.<portal>`, so the admin site and the customer site can word the same field differently.

One rule earns its own line, because getting it wrong is subtle: never call `I18n.t` in a class body. It runs once, at load time, in whatever locale happened to be active. When you want a translated value as an explicit option, use the definition's class-level `t`, which returns a lazy value resolved on every render in the request's locale:

```ruby
class PostDefinition < Plutonium::Resource::Definition
  input :email, placeholder: t("forms.shared.email_placeholder")
end
```

## Switching locale is a Rails around_action

Plutonium reads `I18n.locale` on every render and never sets it. You set it the way any Rails app does. The dummy app's admin portal wires an `EN | ES` switch into the top bar and remembers the choice per session:

```ruby
module AdminPortal
  module Concerns
    module Controller
      extend ActiveSupport::Concern

      included do
        around_action :switch_locale
      end

      def switch_locale(&)
        session[:locale] = params[:locale] if params[:locale].present?
        locale = session[:locale].to_s.to_sym
        locale = I18n.default_locale unless I18n.available_locales.include?(locale)
        I18n.with_locale(locale, &)
      end
    end
  end
end
```

Pick ES and the whole portal answers in Spanish: the search box, the table controls, the page titles, the CRUD flashes, the user menu.

![The dummy admin portal rendered in Spanish, with the EN | ES switch in the top bar](/images/blog/i18n-es-admin.png)

That demo translates only a visible slice of the strings on purpose. Everything it does not translate falls back to English through `config.i18n.fallbacks`, which matters more than it looks: the test environment turns on `config.i18n.raise_on_missing_translations`, so a page rendered under a half-translated locale would blow up on the first missing key. With fallbacks on, a found-via-fallback string is not missing, and a partially translated locale is a valid state to ship. You translate the strings your users see and let the rest read in English until you get to them.

## The parts that aren't Rails views

Two surfaces don't go through Rails' `t` on the server, and both are covered.

The Stimulus controllers bundled with the gem read their strings from a JSON blob the layout renders once per page, in the current locale. Override a key in YAML and the bundled JavaScript's text changes without a rebuild. Host code can read the same blob through `window.Plutonium.t(...)`.

Pagination has its own dictionary. The info sentence, the per-page sentence and the nav labels come from [Pagy](https://ddnexus.github.io/pagy/resources/i18n), which ships locales for about thirty-five languages. Plutonium syncs the Pagy locale to `I18n.locale` on each render, so the same `around_action` that switched the UI switches the pager too.

## Adding a language

A second locale is the usual Rails checklist: a [rails-i18n](https://github.com/svenfuchs/rails-i18n) locale for dates and numbers, a Pagy dictionary, `rodauth-i18n` if you use Rodauth, the `plutonium` namespace translated from the gem's English files, and your own models and attributes. Plutonium itself ships only `en`.

The [internationalization reference](/reference/i18n) has the full key catalogue and the exact resolution order for every slot.
