# Assets

TailwindCSS 4 + Stimulus toolchain. CSS design tokens for theming, `.pu-*` component classes for consistent styling, and a Phlexi theme system for component-level overrides.

## 🚨 Critical

- **Custom CSS, brand colors, or your own Stimulus controllers need `pu:core:assets` first.** Out of the box the app serves the gem's prebuilt `plutonium.css` / `plutonium.min.js`; the generator switches it to your own bundles. Don't hand-write the Tailwind/PostCSS pipeline.
- **Once the app owns its JS bundle, `registerControllers(application)`** must be in `app/javascript/controllers/index.js` (`pu:core:assets` adds it). Your bundle replaces the gem's, so without it Plutonium's controllers (color-mode, form, slim-select, flatpickr, easymde, etc.) are dead.
- **Use `plutoniumTailwindConfig.merge`** when overriding the theme, plain object spread drops Plutonium's defaults.
- **Tokens are CSS variables**, not Tailwind keys, `bg-[var(--pu-surface)]`, NOT `bg-pu-surface`.
- **Dark mode uses `selector`** strategy, toggle `dark` on `<html>`. The bundled `color-mode` controller does this.
- **Style with `.pu-*` classes first, `var(--pu-*)` tokens second, raw palette pairs last.** Banners, badges, cards and buttons all have a `.pu-*` class that carries its own `.dark` rule. See [Component classes](#component-classes-pu).

## Asset configuration

```ruby
# config/initializers/plutonium.rb
Plutonium.configure do |config|
  config.load_defaults 1.0

  config.assets.stylesheet = "application"     # your CSS file
  config.assets.script     = "application"     # your JS file
  config.assets.logo       = "my_logo.png"
  config.assets.favicon    = "my_favicon.ico"
end
```

## Generator

```bash
rails generate pu:core:assets
```

Until this runs, the app serves the gem's prebuilt assets (`config.assets.stylesheet` defaults to `plutonium.css`, `script` to `plutonium.min.js`). Those are compiled from the gem's own sources, so app-side Tailwind classes, a new `primary` palette, token overrides and custom Stimulus controllers have nowhere to go. The generator:

1. Installs `@radioactive-labs/plutonium` (pinned to the gem version), Tailwind 4 and the PostCSS plugins.
2. Writes `tailwind.config.js` (through `plutoniumTailwindConfig.merge`) and `postcss.config.js`.
3. Prepends `@import "gem:plutonium/src/css/plutonium.css";` to `application.tailwind.css` and adds `@config` after `@import "tailwindcss";`.
4. Appends `registerControllers(application)` to `app/javascript/controllers/index.js`.
5. Sets `config.assets.stylesheet = "application"` and `config.assets.script = "application"`, and writes the `build` / `build:css` scripts in `package.json`.

Step 5 is why `registerControllers` is not optional: the gem's `plutonium.min.js` calls it itself, and your `application.js` replaces that bundle.

### Prerequisites

The generator aborts unless `app/assets/stylesheets/application.tailwind.css` and `app/javascript/controllers/index.js` exist, i.e. an app created with `-j esbuild -c tailwind` plus Stimulus. For an app without them, install the bundlers first (`bin/rails javascript:install:esbuild`, `css:install:tailwind`, `stimulus:install` from jsbundling-rails, cssbundling-rails and stimulus-rails), then run the generator. Don't hand-write `tailwind.config.js` / `postcss.config.js` instead: the generated ones resolve the gem path (`bundle show plutonium`) and load its `postcss-gem-import.cjs` so the `gem:` import works.

### Package managers

The generator installs with the package manager `rails javascript:build` will use. The lockfile decides: `bun.lock` or `bun.lockb` means bun, `pnpm-lock.yaml` pnpm, `package-lock.json` npm, `yarn.lock` yarn. With no lockfile, `bun.config.js` means bun, and otherwise the first of bun, yarn, pnpm or npm found on PATH wins (yarn if none is). That is why `rails new -j esbuild` on a machine with bun installed produces a bun app. When the app's jsbundling-rails provides `Jsbundling::PackageManager` (its `main` branch, not yet in a release as of 1.3.1), the generator defers to it instead; that detector ignores `yarn.lock` and picks by PATH. Every package goes through one `add` with versions inline (`tailwindcss@latest`, `@radioactive-labs/plutonium@^<gem version>`), which yarn 1, yarn 2+, bun, npm and pnpm all understand.

Yarn 2+ apps get `nodeLinker: node-modules` written to `.yarnrc.yml` if no linker is set. Tailwind's PostCSS plugin does not load under Plug'n'Play.

`pu:core:update` and `pu:docker:install` use the same detection, so the Dockerfile installs bun, yarn 1, or yarn 2+ via corepack to match the app.

## Tailwind config

Generated `tailwind.config.js`:

```javascript
const { execSync } = require('child_process');
const plutoniumGemPath = execSync("bundle show plutonium").toString().trim();
const plutoniumTailwindConfig = require(`${plutoniumGemPath}/tailwind.options.js`);

module.exports = {
  darkMode: plutoniumTailwindConfig.darkMode,                       // 'selector'
  plugins:  [].concat(plutoniumTailwindConfig.plugins),
  theme:    plutoniumTailwindConfig.merge(
              plutoniumTailwindConfig.theme,
              { /* your overrides */ },
            ),
  content: [
    `${__dirname}/app/**/*.{erb,haml,html,slim,rb}`,
    `${__dirname}/app/javascript/**/*.js`,
    `${__dirname}/packages/**/app/**/*.{erb,haml,html,slim,rb}`,
  ].concat(plutoniumTailwindConfig.content),
};
```

::: danger Use `plutoniumTailwindConfig.merge`
A plain spread (`...plutoniumTailwindConfig.theme`) drops the merge logic and you lose Plutonium's defaults. Always use `merge(...)`.
:::

### Customizing colors

```javascript
theme: plutoniumTailwindConfig.merge(plutoniumTailwindConfig.theme, {
  extend: {
    colors: {
      primary: { 50: '#eff6ff', 500: '#3b82f6', 900: '#1e3a8a' },
    },
  },
})
```

These are Tailwind palette colors, compiled into the CSS at build time (`.pu-btn-primary` is `@apply bg-primary-600 ...`; `--pu-input-focus-ring` is `theme(colors.primary.500)`). Recoloring `primary` therefore means the `merge` above plus a rebuild, not a `--pu-*` override.

### Default color palette

| Color | Usage |
|---|---|
| `primary` | Brand primary (turquoise default) |
| `secondary` | Brand secondary (navy default) |
| `success` | Success states (green) |
| `info` | Informational (blue) |
| `warning` | Warning (amber) |
| `danger` | Error (red) |
| `accent` | Highlight (coral pink) |

## CSS imports

```css
/* app/assets/stylesheets/application.tailwind.css */
@import "gem:plutonium/src/css/plutonium.css";

@import "tailwindcss";
@config '../../../tailwind.config.js';

/* your styles */
```

Plutonium CSS includes core utility classes, EasyMDE (markdown editor), Slim Select, intl-tel-input, Flatpickr (date picker).

## Stimulus

```javascript
// app/javascript/controllers/index.js
import { application } from "./application"
import { registerControllers } from "@radioactive-labs/plutonium"

registerControllers(application)

// Your custom controllers...
import CustomController from "./custom_controller"
application.register("custom", CustomController)
```

### Bundled controllers

- `color-mode`: dark/light mode toggle
- `form`: form handling (pre-submit, etc.)
- `nested-resource-form-fields`: nested form management
- `slim-select`: enhanced select boxes
- `flatpickr`: date/time pickers
- `easymde`: markdown editor
- Various internal UI controllers

### Custom Stimulus controller: standard pattern

```javascript
// app/javascript/controllers/custom_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    console.log("Custom controller connected")
  }
}
```

```javascript
// Register
application.register("custom", CustomController)
```

## Design tokens

Plutonium uses a comprehensive CSS custom-property system for consistent, themeable UI components. Tokens auto-switch with dark mode. Source: `src/css/tokens.css`.

### Surface & backgrounds

```css
/* Light */
--pu-body:             #f8fafc;
--pu-surface:          #ffffff;
--pu-surface-alt:      #f1f5f9;
--pu-surface-raised:   #ffffff;
--pu-surface-overlay:  rgba(255, 255, 255, 0.95);

/* Dark (.dark class) */
--pu-body:             #0f172a;
--pu-surface:          #1e293b;
--pu-surface-alt:      #0f172a;
--pu-surface-raised:   #334155;
--pu-surface-overlay:  rgba(30, 41, 59, 0.95);
```

### Text

```css
/* Light */
--pu-text:         #0f172a;
--pu-text-muted:   #64748b;
--pu-text-subtle:  #94a3b8;

/* Dark */
--pu-text:         #f8fafc;
--pu-text-muted:   #94a3b8;
--pu-text-subtle:  #64748b;
```

### Borders, forms, cards

```css
--pu-border:         #e2e8f0;
--pu-border-muted:   #f1f5f9;
--pu-border-strong:  #cbd5e1;

--pu-input-bg:           #ffffff;
--pu-input-border:       #e2e8f0;
--pu-input-focus-ring:   theme(colors.primary.500);
--pu-input-placeholder:  #94a3b8;

--pu-card-bg:      #ffffff;
--pu-card-border:  #e2e8f0;
```

### Shadows, radii, spacing, transitions

```css
--pu-shadow-sm:  0 1px 2px 0 rgb(0 0 0 / 0.03), 0 1px 3px 0 rgb(0 0 0 / 0.05);
--pu-shadow-md:  0 2px 4px -1px rgb(0 0 0 / 0.04), 0 4px 6px -1px rgb(0 0 0 / 0.06);
--pu-shadow-lg:  0 4px 6px -2px rgb(0 0 0 / 0.03), 0 10px 15px -3px rgb(0 0 0 / 0.08);

--pu-radius-sm:    0.375rem;
--pu-radius-md:    0.5rem;
--pu-radius-lg:    0.75rem;
--pu-radius-xl:    1rem;
--pu-radius-full:  9999px;

--pu-space-xs:  0.25rem;
--pu-space-sm:  0.5rem;
--pu-space-md:  1rem;
--pu-space-lg:  1.5rem;
--pu-space-xl:  2rem;

--pu-transition-fast:    150ms cubic-bezier(0.4, 0, 0.2, 1);
--pu-transition-normal:  200ms cubic-bezier(0.4, 0, 0.2, 1);
--pu-transition-slow:    300ms cubic-bezier(0.4, 0, 0.2, 1);
```

### Customizing tokens

```css
/* app/assets/stylesheets/application.tailwind.css */
@import "gem:plutonium/src/css/plutonium.css";
@import "tailwindcss";

:root {
  --pu-surface: #fafafa;
  --pu-border:  #d1d5db;
}

.dark {
  --pu-surface: #111827;
  --pu-border:  #374151;
}
```

::: warning Mirror every `:root` override in `.dark`
Your stylesheet loads after Plutonium's, and `:root` and `.dark` have equal specificity, so a token you override in `:root` beats Plutonium's `.dark` value even when dark mode is active. Any color token you customize in `:root` without re-asserting in `.dark` ships your light value into dark mode, where it's typically unreadable (e.g. a translucent dark `--pu-text-subtle` becomes invisible on a dark surface).

That includes the shadows: `src/css/tokens.css` redefines `--pu-shadow-sm/md/lg` (and every surface, text, border, table, input, card and chart token) under `.dark`, so a tinted light shadow left out of your `.dark` block replaces the dark one.
:::

Put dark values in a `.dark { ... }` block, not `@media (prefers-color-scheme: dark)`. Dark mode is the `dark` class on `<html>` (set by the `color-mode` controller), so a media query ignores the user's toggle. Overrides need the app's own stylesheet after the Plutonium import (`pu:core:assets`); never edit the gem's `tokens.css` / `components.css`.

### Using tokens in templates

```erb
<h1 class="text-[var(--pu-text)]">Title</h1>
<p class="text-[var(--pu-text-muted)]">Description</p>

<div class="bg-[var(--pu-surface)] border border-[var(--pu-border)] rounded-[var(--pu-radius-lg)]">
  Content
</div>
```

```ruby
class MyComponent < Plutonium::UI::Component::Base
  def view_template
    div(
      class: "bg-[var(--pu-surface)] border border-[var(--pu-border)] rounded-[var(--pu-radius-lg)]",
      style: "box-shadow: var(--pu-shadow-md)"
    ) do
      h2(class: "text-lg font-semibold text-[var(--pu-text)]") { "Title" }
      p(class: "text-[var(--pu-text-muted)]") { "Description" }
    end
  end
end
```

## Component classes (`.pu-*`)

Ready-to-use styled components in `src/css/components.css`. **Prefer these over hardcoded `gray-X/dark:gray-Y` (or `warning-50 dark:warning-950`) pairs.** In order of preference:

1. **A `.pu-*` class** (`pu-alert-warning`, `pu-badge-warning`, `pu-card`, `pu-btn-soft-danger`). Each ships with its own `.dark` rule and is always in the CSS, because `components.css` is part of `plutonium.css` whether the app uses the prebuilt file or imports it.
2. **A `var(--pu-*)` token** (`text-[var(--pu-text-muted)]`, `border-[var(--pu-border)]`) for layout around them. The token switches value under `.dark` and follows any theme override.
3. **Raw palette utilities** only for what neither covers. On the prebuilt `plutonium.css` they exist only if the gem's own sources happen to use them (its Tailwind `content` scans the gem, not your app); with your own build they compile, but each needs a hand-picked `dark:` twin that won't follow a rebrand.

### Buttons

```
.pu-btn                            (base)
.pu-btn-md / -sm / -xs             (size)
.pu-btn-primary / -secondary / -danger / -success / -warning / -info / -accent
.pu-btn-ghost / -outline
.pu-btn-soft-primary / -soft-danger / ...
```

```erb
<%= form.submit "Save", class: "pu-btn pu-btn-md pu-btn-primary" %>
```

### Inputs, labels, hints, errors

```
.pu-input / -invalid / -valid
.pu-label / -required
.pu-hint / .pu-error
.pu-checkbox
.pu-toggle                         (switch-styled checkbox)
```

### Badges (status pills)

```
.pu-badge                          (base)
.pu-badge-neutral / -primary / -secondary / -success / -danger / -warning / -info / -accent
```

```erb
<span class="pu-badge pu-badge-success">Active</span>
```

Rendered automatically by the `:badge` display (enums) and `:boolean` display (Yes/No pills). See [Displays](./displays#built-in-display-components).

### Alerts (inline banners)

```
.pu-alert / -success / -warning / -danger / -info
.pu-alert-message / .pu-alert-close
```

```ruby
div(class: "pu-alert pu-alert-warning", role: "alert") do
  div(class: "pu-alert-message") { t("blog.posts.flagged_comments", count: flagged) }
end
```

The same banner the flash messages use (`app/views/plutonium/_flash_alerts.html.erb`), so it already has its dark-mode colors.

### Cards, panels, tables, toolbars, empty states

```
.pu-card / .pu-card-body
.pu-panel-header / -title / -description
.pu-table-wrapper / .pu-table / -header / -header-cell / -body-row / -body-row-selected / -body-cell / .pu-selection-cell
.pu-toolbar / -text / -actions
.pu-empty-state / -icon / -title / -description
```

### Ruby constants

`Plutonium::UI::ComponentClasses` (in `lib/plutonium/ui/component_classes.rb`):

```ruby
ComponentClasses::Button.classes(variant: :primary, size: :default, soft: false)
# => "pu-btn pu-btn-md pu-btn-primary"

ComponentClasses::Form::INPUT       # "pu-input"
ComponentClasses::Form::LABEL       # "pu-label"
ComponentClasses::Table::WRAPPER    # "pu-table-wrapper"
ComponentClasses::Card::BASE        # "pu-card"
```

## Migration from hardcoded classes

| Old | New |
|---|---|
| `text-gray-900 dark:text-white` | `text-[var(--pu-text)]` |
| `text-gray-500 dark:text-gray-400` | `text-[var(--pu-text-muted)]` |
| `bg-gray-50 dark:bg-gray-700` | `bg-[var(--pu-surface)]` |
| `border-gray-300 dark:border-gray-600` | `border-[var(--pu-border)]` |
| Long input class chain | `pu-input` |
| `block mb-2 text-sm font-semibold ...` | `pu-label` |
| `text-red-600 dark:text-red-400` | `pu-error` |
| Long button class chain | `pu-btn pu-btn-md pu-btn-primary` |

## Phlexi component themes

Plutonium components use a Phlexi-based theme system for customizing Form, Display, and Table components. Each has a theme class with named style tokens.

### Form theme

See [Forms › Theming](./forms#theming) for the full Form theme surface.

### Display theme

```ruby
class PostDefinition < ResourceDefinition
  class Display < Display
    class Theme < Plutonium::UI::Display::Theme
      def self.theme
        super.merge(
          fields_wrapper: "grid grid-cols-3 gap-8",
          label:          "text-sm font-bold text-[var(--pu-text-muted)] mb-1",
          string:         "text-lg text-[var(--pu-text)]",
          markdown:       "prose dark:prose-invert max-w-none"
        )
      end
    end
  end
end
```

**Theme keys:** `fields_wrapper`, `label`, `description`, `string`, `text`, `link`, `email`, `phone`, `markdown`, `json`.

### Table theme

```ruby
class PostDefinition < ResourceDefinition
  class Table < Table
    class Theme < Plutonium::UI::Table::Theme
      def self.theme
        super.merge(
          wrapper:      "pu-table-wrapper",
          base:         "pu-table",
          header:       "pu-table-header",
          header_cell:  "pu-table-header-cell",
          body_row:     "pu-table-body-row",
          body_cell:    "pu-table-body-cell"
        )
      end
    end
  end
end
```

**Theme keys:** `wrapper`, `base`, `header`, `header_cell`, `body_row`, `body_cell`, `sort_icon`.

::: warning Always `super.merge(...)`
Don't replace the theme wholesale. Plutonium's defaults handle invalid states, focus rings, and dark mode, `super.merge` keeps them.
:::

## Gotchas

- **Stimulus controllers register silently fails.** Once `config.assets.script` points at the app's JS, if `registerControllers(application)` isn't called the entire UI's interactive layer is dead (color-mode toggle, slim-select, flatpickr, easymde, pre-submit). No error: just no behavior.
- **`plutoniumTailwindConfig.merge` is mandatory.** Plain spread drops defaults silently.
- **Tokens are CSS variables, not Tailwind keys.** Use `bg-[var(--pu-surface)]`, not `bg-pu-surface`.
- **Dark mode is `selector`, not `class`.** Toggle via `document.documentElement.classList.toggle('dark')`.
- **`.pu-*` classes auto-switch with dark mode.** Hardcoded `gray-X/dark:gray-Y` pairs don't get auto-updated when tokens change.

## Related

- [Forms › Theming](./forms#theming): Form theme keys + override pattern
- [Components](./components): `tokens` and `classes` helpers for conditional class composition
- [Layouts](./layouts): fonts, dark-mode toggle, body attributes
