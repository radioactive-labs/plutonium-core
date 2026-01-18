# Theming

This guide covers customizing colors, styles, and branding.

## Overview

Plutonium uses TailwindCSS 4 for styling. Customization happens through:

- **Tailwind Configuration** - Extend colors and design tokens
- **Component Themes** - Override form, table, and display styling
- **Asset Configuration** - Custom CSS, JS, logo, and favicon

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

/* Your custom styles */
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
          base: "bg-white dark:bg-gray-800 shadow-md rounded-lg p-6",
          fields_wrapper: "grid grid-cols-2 gap-6",
          actions_wrapper: "flex justify-end mt-6 space-x-2",
          label: "block mb-2 text-base font-bold",
          input: "w-full p-2 border rounded-md shadow-sm",
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

## Portal-Specific Themes

Different portals can have different themes by overriding definitions per-portal:

```ruby
# packages/admin_portal/app/definitions/admin_portal/post_definition.rb
class AdminPortal::PostDefinition < ::PostDefinition
  class Form < Form
    class Theme < Plutonium::UI::Form::Theme
      def self.theme
        super.merge({
          base: "bg-blue-50 p-8",  # Admin-specific styling
        })
      end
    end
  end
end
```

## Related

- [Custom Actions](./custom-actions)
- [Creating Packages](./creating-packages)
