# UI Reference

Plutonium uses [Phlex](https://www.phlex.fun/) for all view components and TailwindCSS 4 + Stimulus for the frontend.

## Sub-pages

- [Pages](./pages): `IndexPage`, `ShowPage`, `NewPage`, `EditPage`, render hooks, custom ERB views, context detection
- [Forms](./forms): `Form` class, field builder, association inputs (typeahead + inline add), themes
- [Displays](./displays): `Display` class, custom rendering, block-form displays
- [Tables](./tables): `Table` class, custom rendering, search/scopes bar
- [Components](./components): built-in component kit, custom Phlex components, `DynaFrameContent` pattern, modals & tabs
- [Layouts](./layouts): shell config, ejecting chrome, custom `ResourceLayout` class
- [Assets](./assets): Tailwind config, Stimulus controllers, design tokens, `.pu-*` component classes, Phlexi themes

## 🚨 Critical (applies across all sub-pages)

- **Override via nested classes in the definition.** `class ShowPage < ShowPage; end`, `class Form < Form; end`. Don't replace the entire view layer.
- **Use render hooks, not `view_template`.** `render_before_content`, `render_after_content`, `render_before_toolbar`, etc. exist so you don't reimplement the whole page.
- **All pages inherit `DynaFrameContent`**: turbo-frame requests render only the content. Don't fight it; modals and frame nav "just work".
- **Custom components inherit `Plutonium::UI::Component::Base`**: gives you the component kit (`PageHeader`, `Panel`, `Block`), resource helpers, and the `helpers` proxy for Rails helpers.
- **`render_actions` is mandatory in custom `form_template`**: without it, the form has no submit button.
- **Custom CSS, brand colors, or your own Stimulus controllers need `pu:core:assets` first.** Out of the box the app serves the gem's prebuilt `plutonium.css` / `plutonium.min.js`; the generator switches it to your own bundles. Don't hand-write the Tailwind/PostCSS pipeline.
- **Once the app owns its JS bundle, `registerControllers(application)`** must be in `app/javascript/controllers/index.js` (`pu:core:assets` adds it). Your bundle replaces the gem's, so without it Plutonium's Stimulus controllers (color-mode, form, slim-select, flatpickr, easymde, etc.) are dead.
- **Use `plutoniumTailwindConfig.merge`** when extending Tailwind theme, plain object merge drops Plutonium's defaults.
- **Style with `.pu-*` classes first, `var(--pu-*)` tokens second, raw palette pairs last.** Banners, badges, cards and buttons all have a `.pu-*` class that carries its own `.dark` rule. A hand-written `bg-warning-50 dark:bg-warning-950/30` pair duplicates that, drifts from the theme, and may not even exist in the prebuilt CSS.
- **User-facing copy goes through `t(...)` with a locale key**, in components, pages, displays and definitions alike. See [i18n](/reference/i18n).
- **Configure inputs in the definition; render them with `render_resource_field` in the form.** Don't reimplement field widgets from scratch.

## Related

- [Resource › Definition](/reference/resource/definition): field-level rendering (`field :foo, as: :markdown`, `display :status do |f| … end`)
- [Behavior › Controllers](/reference/behavior/controllers): controller render-context hooks (`present_parent?`, `submit_parent?`)
