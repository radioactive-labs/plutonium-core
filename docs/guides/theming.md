# Theming

This guide covers customizing colors, styles, and branding.

## Overview

Plutonium uses TailwindCSS 4 with a design token system for consistent styling. Customization happens through:

- **Design Tokens** - CSS custom properties for colors, spacing, shadows
- **Component Classes** - Pre-built `.pu-*` classes for buttons, inputs, tables
- **Tailwind Configuration** - Extend colors and design tokens
- **Component Themes** - Override form, table, and display styling

## Design Token System

Plutonium uses CSS custom properties (design tokens) for theming. These tokens automatically adapt to light and dark modes.

### Available Tokens

#### Surface Colors

```css
--pu-body            /* Page background */
--pu-surface         /* Card/panel backgrounds */
--pu-surface-alt     /* Alternate surface (headers, sidebars) */
--pu-surface-raised  /* Elevated surfaces */
--pu-surface-overlay /* Modal/dropdown overlays */
```

#### Border Colors

```css
--pu-border        /* Default borders */
--pu-border-muted  /* Subtle borders */
--pu-border-strong /* Emphasized borders */
```

#### Text Colors

```css
--pu-text        /* Primary text */
--pu-text-muted  /* Secondary text */
--pu-text-subtle /* Tertiary/placeholder text */
```

#### Table Tokens

```css
--pu-table-header-bg    /* Header background */
--pu-table-header-text  /* Header text color */
--pu-table-row-bg       /* Row background */
--pu-table-row-hover    /* Row hover state */
--pu-table-row-selected /* Selected row */
--pu-table-border       /* Row borders */
```

#### Form Tokens

```css
--pu-input-bg          /* Input background */
--pu-input-border      /* Input border */
--pu-input-focus-ring  /* Focus ring color */
--pu-input-placeholder /* Placeholder text */
```

#### Card Tokens

```css
--pu-card-bg     /* Card background */
--pu-card-border /* Card border */
```

#### Shadow System

```css
--pu-shadow-sm  /* Subtle shadow */
--pu-shadow-md  /* Medium shadow */
--pu-shadow-lg  /* Large shadow */
```

#### Spacing Scale

```css
--pu-space-xs  /* 0.25rem */
--pu-space-sm  /* 0.5rem */
--pu-space-md  /* 1rem */
--pu-space-lg  /* 1.5rem */
--pu-space-xl  /* 2rem */
```

#### Border Radius

```css
--pu-radius-sm   /* 0.375rem */
--pu-radius-md   /* 0.5rem */
--pu-radius-lg   /* 0.75rem */
--pu-radius-xl   /* 1rem */
--pu-radius-full /* 9999px */
```

#### Transitions

```css
--pu-transition-fast   /* 150ms */
--pu-transition-normal /* 200ms */
--pu-transition-slow   /* 300ms */
```

### Overriding Tokens

Override tokens in your CSS to customize the theme:

```css
/* app/assets/stylesheets/application.css */
@import "tailwindcss";
@import "gem:plutonium/src/css/plutonium.css";

/* Light mode overrides */
:root {
  --pu-surface: #fafafa;
  --pu-border: #d4d4d4;
  --pu-input-focus-ring: #6366f1;
}

/* Dark mode overrides */
.dark {
  --pu-surface: #18181b;
  --pu-border: #3f3f46;
}
```

## Component Classes

Plutonium provides pre-built component classes for common UI elements.

### Buttons

```html
<!-- Sizes -->
<button class="pu-btn pu-btn-md pu-btn-primary">Medium</button>
<button class="pu-btn pu-btn-sm pu-btn-primary">Small</button>
<button class="pu-btn pu-btn-xs pu-btn-primary">Extra Small</button>

<!-- Solid variants -->
<button class="pu-btn pu-btn-md pu-btn-primary">Primary</button>
<button class="pu-btn pu-btn-md pu-btn-secondary">Secondary</button>
<button class="pu-btn pu-btn-md pu-btn-success">Success</button>
<button class="pu-btn pu-btn-md pu-btn-danger">Danger</button>
<button class="pu-btn pu-btn-md pu-btn-warning">Warning</button>
<button class="pu-btn pu-btn-md pu-btn-info">Info</button>
<button class="pu-btn pu-btn-md pu-btn-accent">Accent</button>

<!-- Soft variants (tinted backgrounds) -->
<button class="pu-btn pu-btn-md pu-btn-soft-primary">Soft Primary</button>
<button class="pu-btn pu-btn-md pu-btn-soft-secondary">Soft Secondary</button>
<button class="pu-btn pu-btn-md pu-btn-soft-success">Soft Success</button>
<button class="pu-btn pu-btn-md pu-btn-soft-danger">Soft Danger</button>
<button class="pu-btn pu-btn-md pu-btn-soft-warning">Soft Warning</button>
<button class="pu-btn pu-btn-md pu-btn-soft-info">Soft Info</button>
<button class="pu-btn pu-btn-md pu-btn-soft-accent">Soft Accent</button>

<!-- Other styles -->
<button class="pu-btn pu-btn-md pu-btn-ghost">Ghost</button>
<button class="pu-btn pu-btn-md pu-btn-outline">Outline</button>
```

### Form Inputs

```html
<label class="pu-label">Email</label>
<input type="email" class="pu-input" placeholder="you@example.com">
<p class="pu-hint">We'll never share your email.</p>

<!-- Validation states -->
<input type="text" class="pu-input pu-input-invalid">
<p class="pu-error">This field is required.</p>

<input type="text" class="pu-input pu-input-valid">
```

### Checkboxes

```html
<input type="checkbox" class="pu-checkbox">
```

### Cards

```html
<div class="pu-card">
  <div class="pu-card-body">
    Card content here
  </div>
</div>
```

### Tables

```html
<div class="pu-table-wrapper">
  <table class="pu-table">
    <thead class="pu-table-header">
      <tr>
        <th class="pu-table-header-cell">Name</th>
      </tr>
    </thead>
    <tbody>
      <tr class="pu-table-body-row">
        <td class="pu-table-body-cell">John</td>
      </tr>
    </tbody>
  </table>
</div>
```

### Empty States

```html
<div class="pu-empty-state">
  <svg class="pu-empty-state-icon">...</svg>
  <h3 class="pu-empty-state-title">No items found</h3>
  <p class="pu-empty-state-description">Get started by creating a new item.</p>
</div>
```

## Setup Custom Assets

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

## Asset Configuration

Configure assets in the initializer:

```ruby
# config/initializers/plutonium.rb
Plutonium.configure do |config|
  config.load_defaults 1.0

  config.assets.stylesheet = "application"  # Your CSS file
  config.assets.script = "application"      # Your JS file
  config.assets.logo = "my_logo.png"        # Logo image
  config.assets.favicon = "my_favicon.ico"  # Favicon
end
```

## TailwindCSS Configuration

### Generated Config

```javascript
// tailwind.config.js
const { execSync } = require('child_process');
const plutoniumGemPath = execSync("bundle show plutonium").toString().trim();
const plutoniumTailwindConfig = require(`${plutoniumGemPath}/tailwind.options.js`)

module.exports = {
  darkMode: plutoniumTailwindConfig.darkMode,
  plugins: [
    // Add your plugins here
  ].concat(plutoniumTailwindConfig.plugins),
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

Override Plutonium's color palette:

```javascript
// tailwind.config.js
theme: plutoniumTailwindConfig.merge(
  plutoniumTailwindConfig.theme,
  {
    extend: {
      colors: {
        primary: {
          50: '#eff6ff',
          100: '#dbeafe',
          200: '#bfdbfe',
          300: '#93c5fd',
          400: '#60a5fa',
          500: '#3b82f6',  // Your brand color
          600: '#2563eb',
          700: '#1d4ed8',
          800: '#1e40af',
          900: '#1e3a8a',
          950: '#172554',
        },
      },
    },
  },
),
```

### Semantic Colors

Plutonium includes these semantic colors:

| Color | Usage |
|-------|-------|
| `primary` | Primary brand color |
| `secondary` | Secondary color |
| `success` | Success states (green) |
| `info` | Informational states (blue) |
| `warning` | Warning states (amber) |
| `danger` | Error/danger states (red) |
| `accent` | Accent highlights |

## CSS Imports

### Application Stylesheet

```css
/* app/assets/stylesheets/application.tailwind.css */
@import "gem:plutonium/src/css/plutonium.css";

@import "tailwindcss";
@config '../../../tailwind.config.js';

/* Your custom styles and token overrides */
```

## Component Themes

Plutonium components use a theme system. Override themes by defining nested Theme classes in your definitions.

### Form Theme

```ruby
class PostDefinition < ResourceDefinition
  class Form < Form
    class Theme < Plutonium::UI::Form::Theme
      def self.theme
        super.merge({
          base: "pu-card my-4 p-8 space-y-8",
          fields_wrapper: "grid grid-cols-2 gap-6",
          actions_wrapper: "flex justify-end mt-6 space-x-2",
          label: "pu-label",
          input: "pu-input",
          hint: "pu-hint",
          error: "pu-error",
          button: "pu-btn pu-btn-md pu-btn-primary",
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
          label: "text-sm font-bold text-[var(--pu-text-muted)] mb-1",
          string: "text-lg text-[var(--pu-text)]",
          link: "text-primary-600 hover:underline",
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
          wrapper: "pu-table-wrapper",
          base: "pu-table",
          header: "pu-table-header",
          header_cell: "pu-table-header-cell",
          body_row: "pu-table-body-row",
          body_cell: "pu-table-body-cell",
        })
      end
    end
  end
end
```

## Branding

### Application Name

```ruby
# config/initializers/plutonium.rb
Plutonium.application_name = "My Application"
```

### Custom Logo

Override the logo in your layout:

```ruby
# packages/admin_portal/app/views/layouts/admin_portal/application.rb
module AdminPortal
  class ApplicationLayout < Plutonium::UI::Layout::Application
    def render_logo
      img(src: helpers.asset_path("logo.svg"), alt: "My App", class: "h-8")
    end
  end
end
```

### Custom Fonts

Override in your layout:

```ruby
class MyLayout < Plutonium::UI::Layout::ResourceLayout
  def render_fonts
    link(rel: "preconnect", href: "https://fonts.googleapis.com")
    link(href: "https://fonts.googleapis.com/css2?family=Inter&display=swap", rel: "stylesheet")
  end
end
```

Update Tailwind config:

```javascript
theme: {
  fontFamily: {
    'body': ['Inter', 'sans-serif'],
    'sans': ['Inter', 'sans-serif'],
  }
}
```

## Dark Mode

Plutonium uses `selector` strategy for dark mode. Toggle by adding/removing the `dark` class on `<html>`:

```javascript
document.documentElement.classList.toggle('dark');
```

Plutonium includes a color mode selector component that handles this automatically.

Design tokens automatically adapt to dark mode - override the `.dark` selector in your CSS to customize dark mode colors.

## Stimulus Controllers

Register Plutonium's Stimulus controllers in your application:

```javascript
// app/javascript/controllers/index.js
import { application } from "./application"

import { registerControllers } from "@radioactive-labs/plutonium"
registerControllers(application)

// Your custom controllers...
```

### Available Controllers

- `color-mode` - Dark/light mode toggle
- `form` - Form handling
- `nested-resource-form-fields` - Nested form management
- `slim-select` - Enhanced select boxes
- `flatpickr` - Date/time pickers
- `easymde` - Markdown editor

### Custom Controllers

```javascript
// app/javascript/controllers/custom_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    console.log("Connected")
  }
}
```

Register in your index:

```javascript
import CustomController from "./custom_controller"
application.register("custom", CustomController)
```

## Related

- [Custom Actions](./custom-actions)
- [Creating Packages](./creating-packages)
