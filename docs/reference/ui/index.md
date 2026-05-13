# UI Reference

Plutonium uses [Phlex](https://www.phlex.fun/) for all view components and TailwindCSS 4 + Stimulus for the frontend.

## Sub-pages

- [Pages](./pages) — `IndexPage`, `ShowPage`, `NewPage`, `EditPage`, render hooks, custom ERB views, context detection
- [Forms](./forms) — `Form` class, field builder, association inputs (typeahead + inline add), themes
- [Displays](./displays) — `Display` class, custom rendering, `phlexi_tag`
- [Tables](./tables) — `Table` class, custom rendering, search/scopes bar
- [Components](./components) — built-in component kit, custom Phlex components, `DynaFrameContent` pattern, modals & tabs
- [Layouts](./layouts) — shell config, ejecting chrome, custom `ResourceLayout` class
- [Assets](./assets) — Tailwind config, Stimulus controllers, design tokens, `.pu-*` component classes, Phlexi themes

## 🚨 Critical (applies across all sub-pages)

- **Override via nested classes in the definition.** `class ShowPage < ShowPage; end`, `class Form < Form; end`. Don't replace the entire view layer.
- **Use render hooks, not `view_template`.** `render_before_content`, `render_after_content`, `render_before_toolbar`, etc. exist so you don't reimplement the whole page.
- **All pages inherit `DynaFrameContent`** — turbo-frame requests render only the content. Don't fight it; modals and frame nav "just work".
- **Custom components inherit `Plutonium::UI::Component::Base`** — gives you the component kit (`PageHeader`, `Panel`, `Block`), resource helpers, and the `helpers` proxy for Rails helpers.
- **`render_actions` is mandatory in custom `form_template`** — without it, the form has no submit button.
- **Always `registerControllers(application)`** in `app/javascript/controllers/index.js`. Without it, Plutonium's Stimulus controllers (color-mode, form, slim-select, flatpickr, easymde, etc.) are dead.
- **Use `plutoniumTailwindConfig.merge`** when extending Tailwind theme — plain object merge drops Plutonium's defaults.
- **Prefer `.pu-*` classes and `var(--pu-*)` tokens** over hardcoded `gray-X/dark:gray-Y` pairs — they switch with dark mode automatically.
- **Configure inputs in the definition; render them with `render_resource_field` in the form.** Don't reimplement field widgets from scratch.

## Related

- [Resource › Definition](/reference/resource/definition) — field-level rendering (`field :foo, as: :markdown`, `display :status do |f| … end`)
- [Behavior › Controllers](/reference/behavior/controllers) — controller render-context hooks (`present_parent?`, `submit_parent?`)
