---
name: plutonium-assets
description: Use BEFORE configuring Tailwind, registering a Stimulus controller, or editing design tokens / theming in a Plutonium app. Also when running pu:core:assets or editing tailwind.config.js. Covers the full frontend toolchain.
---

# Plutonium Assets, Stimulus & Theming

## 🚨 Critical (read first)
- **Use the generator.** `pu:core:assets` wires Tailwind, imports Plutonium CSS, registers Stimulus controllers, and updates the Plutonium config. Never hand-roll this.
- **Always register Stimulus controllers.** `registerControllers(application)` is required — Plutonium's controllers (color-mode, form, slim-select, flatpickr, easymde, etc.) are dead without it. Custom controllers must also be explicitly registered.
- **Use `plutoniumTailwindConfig.merge`** when overriding theme keys. Plain object merge drops Plutonium's defaults.
- **Prefer `.pu-*` classes and CSS tokens** over hardcoded `gray-*/dark:gray-*` pairs — they switch with dark mode automatically.
- **Related skills:** `plutonium-views` (layout customization), `plutonium-forms` (form theming), `plutonium-installation` (initial setup).

Plutonium uses TailwindCSS 4 for styling with a customizable theme system for components, and ships its own Stimulus controllers and CSS design token system.

## Contents
- [Asset configuration](#asset-configuration)
- [TailwindCSS configuration](#tailwindcss-configuration)
- [CSS imports](#css-imports)
- [Phlexi component themes](#phlexi-component-themes)
- [Stimulus controllers](#stimulus-controllers)
- [Design tokens and theming](#design-tokens-and-theming)
- [Component classes (`.pu-*`)](#component-classes)
- [Gotchas](#gotchas)

## Asset configuration

```ruby
# config/initializers/plutonium.rb
Plutonium.configure do |config|
  config.load_defaults 1.0

  config.assets.stylesheet = "application"    # Your CSS file
  config.assets.script = "application"        # Your JS file
  config.assets.logo = "my_logo.png"
  config.assets.favicon = "my_favicon.ico"
end
```

Run the assets generator to set up your own TailwindCSS build:

```bash
rails generate pu:core:assets
```

This:
1. Installs required npm packages (`@radioactive-labs/plutonium`, TailwindCSS plugins)
2. Creates `tailwind.config.js` that extends Plutonium's config
3. Imports Plutonium CSS into your `application.tailwind.css`
4. Registers Plutonium's Stimulus controllers
5. Updates Plutonium config to use your assets

## TailwindCSS configuration

### Generated Config

```javascript
// tailwind.config.js
const { execSync } = require('child_process');
const plutoniumGemPath = execSync("bundle show plutonium").toString().trim();
const plutoniumTailwindConfig = require(`${plutoniumGemPath}/tailwind.options.js`)

module.exports = {
  darkMode: plutoniumTailwindConfig.darkMode,
  plugins: [].concat(plutoniumTailwindConfig.plugins),
  theme: plutoniumTailwindConfig.merge(
    plutoniumTailwindConfig.theme,
    {
      // Your custom theme overrides
    },
  ),
  content: [
    `${__dirname}/app/**/*.{erb,haml,html,slim,rb}`,
    `${__dirname}/app/javascript/**/*.js`,
    `${__dirname}/packages/**/app/**/*.{erb,haml,html,slim,rb}`,
  ].concat(plutoniumTailwindConfig.content),
}
```

### Customizing Colors

```javascript
theme: plutoniumTailwindConfig.merge(
  plutoniumTailwindConfig.theme,
  {
    extend: {
      colors: {
        primary: {
          50: '#eff6ff', 500: '#3b82f6', 900: '#1e3a8a',
          // ...
        },
      },
    },
  },
),
```

### Default Color Palette

| Color | Usage |
|-------|-------|
| `primary` | Primary brand color (turquoise by default) |
| `secondary` | Secondary color (navy by default) |
| `success` | Success states (green) |
| `info` | Informational states (blue) |
| `warning` | Warning states (amber) |
| `danger` | Error/danger states (red) |
| `accent` | Accent highlights (coral pink) |

### Dark Mode

Plutonium uses `selector` strategy for dark mode. Toggle by adding/removing `dark` class on `<html>`. Plutonium includes a color mode selector component that handles this automatically.

## CSS imports

```css
/* app/assets/stylesheets/application.tailwind.css */
@import "gem:plutonium/src/css/plutonium.css";

@import "tailwindcss";
@config '../../../tailwind.config.js';

/* Your custom styles */
```

Plutonium CSS includes: core utility classes, EasyMDE (markdown editor) styles, Slim Select styles, International telephone input styles, Flatpickr (date picker) styles.

## Phlexi component themes

Plutonium components use a theme system based on Phlexi for customizing Form, Display, and Table components. Each component type has a theme class with named style tokens.

### Form Theme

```ruby
class PostDefinition < ResourceDefinition
  class Form < Form
    class Theme < Plutonium::UI::Form::Theme
      def self.theme
        super.merge({
          base: "bg-white dark:bg-gray-800 shadow-md rounded-lg p-6",
          fields_wrapper: "grid grid-cols-2 gap-6",
          actions_wrapper: "flex justify-end mt-6 space-x-2",
          label: "block mb-2 text-base font-bold",
          invalid_label: "text-red-700 dark:text-red-500",
          input: "w-full p-2 border rounded-md shadow-sm",
          invalid_input: "bg-red-50 border-red-500 text-red-900",
          hint: "mt-2 text-sm text-gray-500",
          error: "mt-2 text-sm text-red-600",
          button: "px-4 py-2 bg-primary-600 text-white rounded-md hover:bg-primary-700",
        })
      end
    end
  end
end
```

### Display Theme

```ruby
class PostDefinition < ResourceDefinition
  class Display < Display
    class Theme < Plutonium::UI::Display::Theme
      def self.theme
        super.merge({
          fields_wrapper: "grid grid-cols-3 gap-8",
          label: "text-sm font-bold text-gray-500 mb-1",
          string: "text-lg text-gray-900 dark:text-white",
          link: "text-primary-600 hover:underline",
          markdown: "prose dark:prose-invert max-w-none",
        })
      end
    end
  end
end
```

### Table Theme

```ruby
class PostDefinition < ResourceDefinition
  class Table < Table
    class Theme < Plutonium::UI::Table::Theme
      def self.theme
        super.merge({
          wrapper: "overflow-x-auto shadow-md rounded-lg",
          base: "w-full text-sm text-gray-500",
          header: "text-xs uppercase bg-gray-100 dark:bg-gray-700",
          header_cell: "px-6 py-3",
          body_row: "bg-white border-b dark:bg-gray-800",
          body_cell: "px-6 py-4",
        })
      end
    end
  end
end
```

### Theme Keys Reference

**Form theme keys:** `base`, `fields_wrapper`, `actions_wrapper`, `wrapper`, `inner_wrapper`, `label`, `invalid_label`, `valid_label`, `neutral_label`, `input`, `invalid_input`, `valid_input`, `neutral_input`, `hint`, `error`, `button`, `checkbox`, `select`.

**Display theme keys:** `fields_wrapper`, `label`, `description`, `string`, `text`, `link`, `email`, `phone`, `markdown`, `json`.

**Table theme keys:** `wrapper`, `base`, `header`, `header_cell`, `body_row`, `body_cell`, `sort_icon`.

### Using `tokens` and `classes` helpers

```ruby
class MyComponent < Plutonium::UI::Component::Base
  def initialize(active:)
    @active = active
  end

  def view_template
    div(class: tokens(
      "base-class",
      active?: "bg-primary-500 text-white",
      inactive?: "bg-gray-200 text-gray-700"
    )) { "Content" }
  end

  private

  def active? = @active
  def inactive? = !@active
end
```

```ruby
div(**classes("p-4", "rounded", active?: "ring-2")) { }
# => <div class="p-4 rounded ring-2">

tokens(
  "base",
  condition?: { then: "if-true", else: "if-false" }
)
```

## Stimulus controllers

Register Plutonium's Stimulus controllers in your application:

```javascript
// app/javascript/controllers/index.js
import { application } from "./application"

import { registerControllers } from "@radioactive-labs/plutonium"
registerControllers(application)

// Your custom controllers...
```

### Available controllers

- `color-mode` - Dark/light mode toggle
- `form` - Form handling (pre-submit, etc.)
- `nested-resource-form-fields` - Nested form management
- `slim-select` - Enhanced select boxes
- `flatpickr` - Date/time pickers
- `easymde` - Markdown editor
- Various UI controllers

### Custom Stimulus controllers

```javascript
// app/javascript/controllers/custom_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    console.log("Custom controller connected")
  }
}
```

Register:

```javascript
import CustomController from "./custom_controller"
application.register("custom", CustomController)
```

### Typography

Plutonium uses Lato by default. Override:

```ruby
class MyLayout < Plutonium::UI::Layout::ResourceLayout
  def render_fonts
    link(rel: "preconnect", href: "https://fonts.googleapis.com")
    link(href: "https://fonts.googleapis.com/css2?family=Inter&display=swap", rel: "stylesheet")
  end
end
```

```javascript
theme: {
  fontFamily: {
    'body': ['Inter', 'sans-serif'],
    'sans': ['Inter', 'sans-serif'],
  }
}
```

## Design tokens and theming

Plutonium uses a comprehensive CSS design token system for consistent, themeable UI components — CSS custom properties and reusable component classes that automatically support light and dark modes. Tokens are defined in `src/css/tokens.css`.

### Surface & background colors

```css
/* Light */
--pu-body: #f8fafc;
--pu-surface: #ffffff;
--pu-surface-alt: #f1f5f9;
--pu-surface-raised: #ffffff;
--pu-surface-overlay: rgba(255, 255, 255, 0.95);

/* Dark (.dark class) */
--pu-body: #0f172a;
--pu-surface: #1e293b;
--pu-surface-alt: #0f172a;
--pu-surface-raised: #334155;
--pu-surface-overlay: rgba(30, 41, 59, 0.95);
```

### Text colors

```css
/* Light */
--pu-text: #0f172a;
--pu-text-muted: #64748b;
--pu-text-subtle: #94a3b8;

/* Dark */
--pu-text: #f8fafc;
--pu-text-muted: #94a3b8;
--pu-text-subtle: #64748b;
```

### Border colors

```css
--pu-border: #e2e8f0;
--pu-border-muted: #f1f5f9;
--pu-border-strong: #cbd5e1;
```

### Form tokens

```css
--pu-input-bg: #ffffff;
--pu-input-border: #e2e8f0;
--pu-input-focus-ring: theme(colors.primary.500);
--pu-input-placeholder: #94a3b8;
```

### Card tokens

```css
--pu-card-bg: #ffffff;
--pu-card-border: #e2e8f0;
```

### Shadows

```css
--pu-shadow-sm: 0 1px 2px 0 rgb(0 0 0 / 0.03), 0 1px 3px 0 rgb(0 0 0 / 0.05);
--pu-shadow-md: 0 2px 4px -1px rgb(0 0 0 / 0.04), 0 4px 6px -1px rgb(0 0 0 / 0.06);
--pu-shadow-lg: 0 4px 6px -2px rgb(0 0 0 / 0.03), 0 10px 15px -3px rgb(0 0 0 / 0.08);
```

### Radius, spacing, transitions

```css
--pu-radius-sm: 0.375rem;
--pu-radius-md: 0.5rem;
--pu-radius-lg: 0.75rem;
--pu-radius-xl: 1rem;
--pu-radius-full: 9999px;

--pu-space-xs: 0.25rem;
--pu-space-sm: 0.5rem;
--pu-space-md: 1rem;
--pu-space-lg: 1.5rem;
--pu-space-xl: 2rem;

--pu-transition-fast: 150ms cubic-bezier(0.4, 0, 0.2, 1);
--pu-transition-normal: 200ms cubic-bezier(0.4, 0, 0.2, 1);
--pu-transition-slow: 300ms cubic-bezier(0.4, 0, 0.2, 1);
```

### Customizing tokens

```css
/* app/assets/stylesheets/application.tailwind.css */
@import "gem:plutonium/src/css/plutonium.css";
@import "tailwindcss";

:root {
  --pu-surface: #fafafa;
  --pu-border: #d1d5db;
}

.dark {
  --pu-surface: #111827;
  --pu-border: #374151;
}
```

## Component classes

Component classes are defined in `src/css/components.css` for ready-to-use styled components.

### Buttons

```
.pu-btn                /* Base */
.pu-btn-md / .pu-btn-sm / .pu-btn-xs
.pu-btn-primary / -secondary / -danger / -success / -warning / -info / -accent
.pu-btn-ghost / -outline
.pu-btn-soft-primary / -soft-danger / ...
```

```erb
<%= form.submit "Save", class: "pu-btn pu-btn-md pu-btn-primary" %>
```

### Inputs & labels

```
.pu-input / .pu-input-invalid / .pu-input-valid
.pu-label / .pu-label-required
.pu-hint / .pu-error
.pu-checkbox
```

### Cards, panels, tables, toolbar, empty state

```
.pu-card / .pu-card-body
.pu-panel-header / .pu-panel-title / .pu-panel-description
.pu-table-wrapper / .pu-table / .pu-table-header / .pu-table-header-cell /
.pu-table-body-row / .pu-table-body-row-selected / .pu-table-body-cell / .pu-selection-cell
.pu-toolbar / .pu-toolbar-text / .pu-toolbar-actions
.pu-empty-state / .pu-empty-state-icon / .pu-empty-state-title / .pu-empty-state-description
```

### Ruby component class constants

The `Plutonium::UI::ComponentClasses` module (in `lib/plutonium/ui/component_classes.rb`) provides Ruby constants for consistent class usage:

```ruby
ComponentClasses::Button.classes(variant: :primary, size: :default, soft: false)
# => "pu-btn pu-btn-md pu-btn-primary"

ComponentClasses::Form::INPUT         # "pu-input"
ComponentClasses::Form::LABEL         # "pu-label"
ComponentClasses::Table::WRAPPER      # "pu-table-wrapper"
ComponentClasses::Card::BASE          # "pu-card"
```

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
    div(class: "bg-[var(--pu-surface)] border border-[var(--pu-border)] rounded-[var(--pu-radius-lg)]",
        style: "box-shadow: var(--pu-shadow-md)") {
      h2(class: "text-lg font-semibold text-[var(--pu-text)]") { "Title" }
      p(class: "text-[var(--pu-text-muted)]") { "Description" }
    }
  end
end
```

### Migration from hardcoded classes

| Old | New |
|-----|-----|
| `text-gray-900 dark:text-white` | `text-[var(--pu-text)]` |
| `text-gray-500 dark:text-gray-400` | `text-[var(--pu-text-muted)]` |
| `bg-gray-50 dark:bg-gray-700` | `bg-[var(--pu-surface)]` |
| `border-gray-300 dark:border-gray-600` | `border-[var(--pu-border)]` |
| long input class | `pu-input` |
| `block mb-2 text-sm font-semibold ...` | `pu-label` |
| `text-red-600 dark:text-red-400` | `pu-error` |
| long button class | `pu-btn pu-btn-md pu-btn-primary` |

## Gotchas

- **Always register Stimulus controllers** — Plutonium controllers won't work without `registerControllers(application)`. Custom controllers must also be registered.
- **Use `plutoniumTailwindConfig.merge`** when overriding theme — plain object merge drops Plutonium's defaults.
- **Dark mode uses `selector`**, not `class`. Toggle via `document.documentElement.classList.toggle('dark')`.
- **Tokens are CSS variables**, not Tailwind keys — use `bg-[var(--pu-surface)]`, not `bg-pu-surface`.
- **Prefer `.pu-*` component classes and tokens** over hardcoded `gray-*/dark:gray-*` pairs — they switch automatically with dark mode.

## Related skills

- `plutonium-views` - Layout customization
- `plutonium-forms` - Form theming and custom inputs
- `plutonium-installation` - Initial setup
