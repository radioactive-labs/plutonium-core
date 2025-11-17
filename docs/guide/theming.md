# Theming Guide

Plutonium uses a semantic design token system built on Tailwind CSS, making it easy to customize the appearance of your application while maintaining design consistency.

## Design Philosophy

Plutonium's theming system is built on these principles:

- **Semantic tokens** - Colors and spacing have meaningful names (e.g., `surface`, `elevated`) rather than generic values
- **Cross-property consistency** - The same size name means the same value across all utilities (`p-md` = `gap-md` = `my-md`)
- **Minimal, modern aesthetic** - Subtle corners, clean lines, and restrained use of shadows
- **Easy customization** - Override tokens in your Tailwind config to theme the entire application

## Semantic Design Tokens

### Spacing Scale

Plutonium extends Tailwind's spacing scale with semantic values:

```javascript
spacing: {
  'xs': '0.5rem',    // 8px - extra small spacing
  'sm': '0.75rem',   // 12px - small spacing (inputs, buttons, small gaps)
  'md': '1rem',      // 16px - medium spacing (cards, tabs, standard gaps)
  'lg': '1.5rem',    // 24px - large spacing (forms, displays, large spacing)
  'xl': '2rem',      // 32px - extra large spacing
  '2xl': '2.5rem',   // 40px - 2x extra large spacing
  '3xl': '3rem',     // 48px - 3x extra large spacing
}
```

These work across **all** spacing utilities:
- Padding: `p-md`, `px-sm`, `py-lg`
- Margin: `m-md`, `mx-sm`, `my-lg`
- Gap: `gap-md`, `gap-x-sm`, `gap-y-lg`
- Space: `space-x-md`, `space-y-sm`

### Background Colors

Semantic background colors provide consistent theming across light and dark modes:

```javascript
colors: {
  // Semantic background colors
  surface: {
    DEFAULT: '#ffffff',   // Light mode: cards, forms, tables, panels
    dark: '#1f2937',      // Dark mode: gray-800
  },
  page: {
    DEFAULT: 'rgb(248 248 248)',  // Light mode: page background
    dark: '#111827',              // Dark mode: gray-900
  },
  elevated: {
    DEFAULT: 'rgb(244 244 245)',  // Light mode: subtle elevation
    dark: '#374151',              // Dark mode: gray-700
  },
  interactive: {
    DEFAULT: 'rgb(244 244 245)',  // Light mode: hover states
    dark: '#374151',              // Dark mode: gray-700
  },
}
```

**Where each color is used:**
- `surface` - Cards, forms, tables, panels, modals
- `page` - Main page background
- `elevated` - Slightly elevated elements like dropdowns, selected items
- `interactive` - Hover and focus states

### Border Radius

Plutonium uses subtle border radius values for a modern, minimal look:

- `rounded-sm` (2px) - Most UI elements (buttons, inputs, cards)
- `rounded` (4px) - Slightly larger elements
- `rounded-lg` (8px) - Special cases needing more rounding

## Getting Started

By default, Plutonium is completely self-contained and uses its own bundled assets - you don't need to do anything to get started. The gem includes pre-compiled CSS and JavaScript that work out of the box.

### When to Integrate Assets

You only need to integrate Plutonium's assets into your application if you want to:
- Customize the theme (colors, spacing, fonts)
- Override component styles
- Extend Tailwind with your own utilities

To integrate Plutonium's assets with your Rails application, run:

```bash
rails generate pu:core:assets
```

This generator will:
- Install required npm packages (`@radioactive-labs/plutonium`, Tailwind CSS, PostCSS)
- Create a `tailwind.config.js` that loads Plutonium's theme configuration
- Configure your application to import Plutonium's CSS and register its Stimulus controllers
- Set up the build pipeline to compile everything together

After running the generator, you can customize the theme as described below.

## Customizing Your Theme

To customize Plutonium's theme, you need to extend the Tailwind configuration in your application (created by `rails generate pu:core:assets`):

```javascript
// tailwind.config.js
const { execSync } = require('child_process');
const plutoniumGemPath = execSync("bundle show plutonium").toString().trim();
const plutoniumTailwindConfig = require(`${plutoniumGemPath}/tailwind.options.js`)
const tailwindPlugin = require('tailwindcss/plugin')

module.exports = {
  darkMode: 'class',
  plugins: [
    // Add your custom plugins here
  ].concat(plutoniumTailwindConfig.plugins.map(function (plugin) {
    switch (typeof plugin) {
      case "function":
        return tailwindPlugin(plugin)
      case "string":
        return require(plugin)
      default:
        throw Error(`unsupported plugin: ${plugin}: ${(typeof plugin)}`)
    }
  })),
  theme: plutoniumTailwindConfig.merge(
    plutoniumTailwindConfig.theme,
    {
      extend: {
        colors: {
          // Override brand colors - example using blue
          primary: {
            50: '#eff6ff',
            100: '#dbeafe',
            200: '#bfdbfe',
            300: '#93c5fd',
            400: '#60a5fa',
            500: '#3b82f6',
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
  content: [
    `${__dirname}/app/**/*.{erb,haml,html,slim,rb}`,
    `${__dirname}/app/javascript/**/*.js`,
  ].concat(plutoniumTailwindConfig.content),
}
```

### Dark Mode Customization

Customize just the dark mode colors:

```javascript
theme: plutoniumTailwindConfig.merge(
  plutoniumTailwindConfig.theme,
  {
    extend: {
      colors: {
        surface: {
          dark: '#1e293b',  // slate-800 for a cooler dark mode
        },
        page: {
          dark: '#0f172a',  // slate-900
        },
        elevated: {
          dark: '#334155',  // slate-700
        },
        interactive: {
          dark: '#475569',  // slate-600 for more contrast on hover
        },
      },
    },
  }
)
```

### Brand Color Customization

Replace Plutonium's turquoise/navy palette with your brand colors:

```javascript
theme: plutoniumTailwindConfig.merge(
  plutoniumTailwindConfig.theme,
  {
    extend: {
      colors: {
        primary: {
          // Your primary brand color scale
          50: '#fef2f2',
          100: '#fee2e2',
          500: '#ef4444',  // Your primary color
          900: '#7f1d1d',
        },
        secondary: {
          // Your secondary brand color scale
          50: '#f0fdf4',
          100: '#dcfce7',
          500: '#22c55e',  // Your secondary color
          900: '#14532d',
        },
      },
    },
  }
)
```

### Component-Level Theming

Every Plutonium component supports CSS class customization through the theme system. Component classes follow the pattern:

```
pu-{component}[-{variant}][-{element}]
```

#### Available Component Classes

**Forms:**
- `pu-form` - Form container
- `pu-form-input` - Text input fields
- `pu-form-label` - Input labels
- `pu-form-hint` - Help text below inputs
- `pu-form-error` - Validation error messages
- `pu-form-button` - Primary form button
- `pu-form-button_secondary` - Secondary form button
- `pu-form-fieldset` - Field grouping container
- `pu-form-fields` - Fields wrapper

**Tables:**
- `pu-table` - Table container
- `pu-table-wrapper` - Scrollable wrapper
- `pu-table-header` - Table header row
- `pu-table-header-cell` - Header cell
- `pu-table-body` - Table body
- `pu-table-row` - Table row
- `pu-table-cell` - Table cell
- `pu-table-footer` - Footer with pagination

**Display (Detail Views):**
- `pu-display` - Display container
- `pu-display-fields` - Fields grid wrapper
- `pu-display-field` - Individual field wrapper
- `pu-display-label` - Field label
- `pu-display-value` - Field value

**Layout:**
- `pu-layout-body` - Main layout body
- `pu-layout-main` - Main content area
- `pu-layout-header` - Page header
- `pu-layout-sidebar` - Sidebar navigation

**Navigation:**
- `pu-breadcrumbs` - Breadcrumb navigation
- `pu-nav-menu` - Navigation menu
- `pu-nav-user` - User menu dropdown
- `pu-sidebar-menu` - Sidebar menu items

**Panels:**
- `pu-panel` - Generic panel container
- `pu-panel-header` - Panel header
- `pu-panel-body` - Panel content

#### Customization Examples

```css
/* Custom form styling */
.pu-form {
  @apply shadow-xl border-2;
}

.pu-form-input {
  @apply text-lg rounded-lg;
}

.pu-form-error {
  @apply text-sm font-semibold;
}

/* Custom table styling */
.pu-table-row:hover {
  @apply bg-primary-50 dark:bg-primary-950;
}

.pu-table-header-cell {
  @apply font-bold uppercase tracking-wider;
}

/* Custom display styling */
.pu-display-field {
  @apply border-l-4 border-primary-500 pl-4;
}

.pu-display-label {
  @apply text-xs uppercase tracking-wide text-gray-500;
}
```

You can also use Ruby to customize theme classes programmatically:

```ruby
# In your resource controller or view
class Admin::UsersController < Plutonium::ResourceController
  def self.form_theme
    {
      input: "pu-form-input w-full rounded-lg border-2 border-primary-300"
    }
  end
end
```

## Common Theming Scenarios

### Warmer Color Palette

```javascript
theme: plutoniumTailwindConfig.merge(
  plutoniumTailwindConfig.theme,
  {
    extend: {
      colors: {
        surface: {
          DEFAULT: '#fefefe',
          dark: '#1c1917',  // stone-900
        },
        page: {
          DEFAULT: '#fafaf9',  // stone-50
          dark: '#0c0a09',     // stone-950
        },
        elevated: {
          DEFAULT: '#f5f5f4',  // stone-100
          dark: '#292524',     // stone-800
        },
      },
    },
  }
)
```

### High Contrast Mode

```javascript
theme: plutoniumTailwindConfig.merge(
  plutoniumTailwindConfig.theme,
  {
    extend: {
      colors: {
        surface: {
          DEFAULT: '#ffffff',
          dark: '#000000',  // Pure black
        },
        page: {
          DEFAULT: '#fafafa',
          dark: '#0a0a0a',  // Almost black
        },
        elevated: {
          DEFAULT: '#f0f0f0',
          dark: '#1a1a1a',
        },
        interactive: {
          DEFAULT: '#e5e5e5',
          dark: '#2a2a2a',
        },
      },
    },
  }
)
```

### Monochrome Theme

```javascript
theme: plutoniumTailwindConfig.merge(
  plutoniumTailwindConfig.theme,
  {
    extend: {
      colors: {
        primary: {
          50: '#fafafa',
          100: '#f5f5f5',
          500: '#737373',
          900: '#171717',
        },
        secondary: {
          50: '#f5f5f5',
          100: '#e5e5e5',
          500: '#525252',
          900: '#0a0a0a',
        },
      },
    },
  }
)
```

## Tips and Best Practices

1. **Use semantic tokens** - Prefer `bg-surface` over `bg-white` so dark mode works automatically
2. **Test both modes** - Always verify your changes in both light and dark mode
3. **Maintain contrast** - Ensure text remains readable against your background colors
4. **Extend, don't replace** - Use the `merge` helper to extend rather than replace the theme
5. **Stay consistent** - Use the same spacing scale throughout your application

## Migration from Hardcoded Values

If you have existing components using hardcoded Tailwind values, migrate them to semantic tokens:

**Before:**
```ruby
div(class: "bg-white dark:bg-gray-800 p-4 rounded-lg")
```

**After:**
```ruby
div(class: "bg-surface dark:bg-surface-dark p-md rounded-sm")
```

This ensures your components automatically adapt to theme changes.

## Further Resources

- [Tailwind CSS Customization](https://tailwindcss.com/docs/configuration)
- [Dark Mode Guide](https://tailwindcss.com/docs/dark-mode)
- [Color Palette Generator](https://uicolors.app/create)
