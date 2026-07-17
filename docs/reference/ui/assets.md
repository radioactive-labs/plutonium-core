# Assets

TailwindCSS 4 + Stimulus toolchain. CSS design tokens for theming, `.pu-*` component classes for consistent styling, and a Phlexi theme system for component-level overrides.

## 🚨 Critical

- **Always register Stimulus controllers** — `registerControllers(application)` is required. Without it, Plutonium's controllers (color-mode, form, slim-select, flatpickr, easymde, etc.) are dead.
- **Use `plutoniumTailwindConfig.merge`** when overriding the theme — plain object spread drops Plutonium's defaults.
- **Tokens are CSS variables**, not Tailwind keys — `bg-[var(--pu-surface)]`, NOT `bg-pu-surface`.
- **Dark mode uses `selector`** strategy — toggle `dark` on `<html>`. The bundled `color-mode` controller does this.
- **Prefer `.pu-*` classes and `var(--pu-*)` tokens** over hardcoded `gray-X/dark:gray-Y` pairs — they switch with dark mode automatically.

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

This:

1. Installs npm packages (`@radioactive-labs/plutonium`, TailwindCSS plugins).
2. Creates `tailwind.config.js` extending Plutonium's config.
3. Imports Plutonium CSS into `application.tailwind.css`.
4. Registers Plutonium's Stimulus controllers.
5. Updates Plutonium config to point at your asset files.

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

- `color-mode` — dark/light mode toggle
- `form` — form handling (pre-submit, etc.)
- `nested-resource-form-fields` — nested form management
- `slim-select` — enhanced select boxes
- `flatpickr` — date/time pickers
- `easymde` — markdown editor
- Various internal UI controllers

### Custom Stimulus controller — standard pattern

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
Your stylesheet loads after Plutonium's, and `:root` and `.dark` have equal specificity — so a token you override in `:root` beats Plutonium's `.dark` value even when dark mode is active. Any color token you customize in `:root` without re-asserting in `.dark` ships your light value into dark mode, where it's typically unreadable (e.g. a translucent dark `--pu-text-subtle` becomes invisible on a dark surface).
:::

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

Ready-to-use styled components in `src/css/components.css`. **Prefer these over hardcoded `gray-X/dark:gray-Y` pairs** — they auto-switch with dark mode.

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
Don't replace the theme wholesale. Plutonium's defaults handle invalid states, focus rings, and dark mode — `super.merge` keeps them.
:::

## Gotchas

- **Stimulus controllers register silently fails.** If `registerControllers(application)` isn't called, the entire UI's interactive layer is dead (color-mode toggle, slim-select, flatpickr, easymde, pre-submit). No error — just no behavior.
- **`plutoniumTailwindConfig.merge` is mandatory.** Plain spread drops defaults silently.
- **Tokens are CSS variables, not Tailwind keys.** Use `bg-[var(--pu-surface)]`, not `bg-pu-surface`.
- **Dark mode is `selector`, not `class`.** Toggle via `document.documentElement.classList.toggle('dark')`.
- **`.pu-*` classes auto-switch with dark mode.** Hardcoded `gray-X/dark:gray-Y` pairs don't get auto-updated when tokens change.

## Related

- [Forms › Theming](./forms#theming) — Form theme keys + override pattern
- [Components](./components) — `tokens` and `classes` helpers for conditional class composition
- [Layouts](./layouts) — fonts, dark-mode toggle, body attributes
