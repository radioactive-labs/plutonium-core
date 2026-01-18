# Assets Reference

Complete reference for styling, theming, and frontend assets.

## Overview

Plutonium uses:
- **TailwindCSS** for styling
- **Stimulus** for JavaScript interactions
- **Turbo** for navigation and forms

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

  # Custom assets
  config.assets.stylesheet = "application"    # Your CSS file
  config.assets.script = "application"        # Your JS file
  config.assets.logo = "my_logo.png"          # Logo image
  config.assets.favicon = "my_favicon.ico"    # Favicon
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

### CSS Imports

```css
/* app/assets/stylesheets/application.tailwind.css */
@import "gem:plutonium/src/css/plutonium.css";

@import "tailwindcss";
@config '../../../tailwind.config.js';

/* Your custom styles */
```

### What Plutonium CSS Includes

- Core utility classes
- EasyMDE (markdown editor) styles
- Slim Select styles
- International telephone input styles
- Flatpickr (date picker) styles

## Color System

### Customizing Colors

Override Plutonium's color palette in your Tailwind config:

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

### Default Color Palette

Plutonium includes these semantic colors:

| Color | Usage |
|-------|-------|
| `primary` | Primary brand color (turquoise by default) |
| `secondary` | Secondary color (navy by default) |
| `success` | Success states (green) |
| `info` | Informational states (blue) |
| `warning` | Warning states (amber) |
| `danger` | Error/danger states (red) |
| `accent` | Accent highlights (coral pink) |

## Dark Mode

Plutonium uses `selector` strategy for dark mode:

```javascript
darkMode: "selector"
```

Toggle dark mode by adding/removing the `dark` class on `<html>`:

```javascript
document.documentElement.classList.toggle('dark');
```

Plutonium includes a `color-mode` Stimulus controller that handles this automatically.

## Component Themes

Plutonium components use a theme system based on Phlexi. Each component type has a theme class with named style tokens.

### Form Theme

```ruby
class PostDefinition < ResourceDefinition
  class Form < Form
    class Theme < Plutonium::UI::Form::Theme
      def self.theme
        super.merge({
          # Container
          base: "bg-white dark:bg-gray-800 shadow-md rounded-lg p-6",
          fields_wrapper: "grid grid-cols-2 gap-6",
          actions_wrapper: "flex justify-end mt-6 space-x-2",

          # Labels
          label: "block mb-2 text-base font-bold",
          invalid_label: "text-red-700 dark:text-red-500",
          valid_label: "text-green-700 dark:text-green-500",
          neutral_label: "text-gray-500 dark:text-gray-400",

          # Inputs
          input: "w-full p-2 border rounded-md shadow-sm",
          invalid_input: "bg-red-50 border-red-500 text-red-900",
          valid_input: "bg-green-50 border-green-500 text-green-900",
          neutral_input: "border-gray-300 dark:border-gray-600",

          # Hints & Errors
          hint: "mt-2 text-sm text-gray-500",
          error: "mt-2 text-sm text-red-600",

          # Buttons
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

#### Form Theme Keys

| Key | Description |
|-----|-------------|
| `base` | Form container |
| `fields_wrapper` | Grid wrapper for fields |
| `actions_wrapper` | Submit button container |
| `wrapper` | Individual field wrapper |
| `inner_wrapper` | Inner field wrapper |
| `label` | Label base styles |
| `invalid_label` | Label when field invalid |
| `valid_label` | Label when field valid |
| `neutral_label` | Label default state |
| `input` | Input base styles |
| `invalid_input` | Input when invalid |
| `valid_input` | Input when valid |
| `neutral_input` | Input default state |
| `hint` | Hint text |
| `error` | Error message |
| `button` | Submit button |
| `checkbox` | Checkbox input |
| `select` | Select dropdown |

#### Display Theme Keys

| Key | Description |
|-----|-------------|
| `fields_wrapper` | Grid wrapper |
| `label` | Field label |
| `description` | Field description |
| `string` | String values |
| `text` | Text values |
| `link` | URL links |
| `email` | Email links |
| `phone` | Phone links |
| `markdown` | Markdown content |
| `json` | JSON display |

#### Table Theme Keys

| Key | Description |
|-----|-------------|
| `wrapper` | Table container |
| `base` | Table element |
| `header` | Header row |
| `header_cell` | Header cell |
| `body_row` | Body row |
| `body_cell` | Body cell |
| `sort_icon` | Sort indicator |

## Using Tokens in Components

### The `tokens` Helper

Conditionally apply classes:

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
    )) {
      "Content"
    }
  end

  private

  def active? = @active
  def inactive? = !@active
end
```

### The `classes` Helper

Returns a hash suitable for splatting:

```ruby
div(**classes("p-4", "rounded", active?: "ring-2")) { }
# => <div class="p-4 rounded ring-2">
```

### Conditional Tokens with Then/Else

For if/else class logic, pass a hash with `:then` and `:else` keys:

```ruby
class MyComponent < Plutonium::UI::Component::Base
  def initialize(status:)
    @status = status
  end

  def view_template
    div(class: tokens(
      "badge",
      published?: { then: "bg-green-500", else: "bg-gray-500" }
    )) { @status }
  end

  private

  def published? = @status == "published"
end
```

## Stimulus Controllers

Plutonium includes Stimulus controllers. Register them in your application:

```javascript
// app/javascript/controllers/index.js
import { application } from "./application"

import { registerControllers } from "@radioactive-labs/plutonium"
registerControllers(application)

// Your custom controllers...
```

### Built-in Controllers

See the [register_controllers.js source](https://github.com/radioactive-labs/plutonium-core/blob/master/src/js/controllers/register_controllers.js) for the current list of controllers.

Key controllers include:

| Controller | Purpose |
|------------|---------|
| `form` | Form handling (pre-submit, etc.) |
| `nested-resource-form-fields` | Nested form management |
| `slim-select` | Enhanced select boxes |
| `flatpickr` | Date/time pickers |
| `easymde` | Markdown editor |
| `color-mode` | Dark/light mode toggle |
| `sidebar` | Sidebar navigation |
| `remote-modal` | Remote modal dialogs |
| `intl-tel-input` | International phone input |
| `attachment-input` | File attachment handling |

### Custom Controllers

Add your own controllers alongside Plutonium's:

```javascript
// app/javascript/controllers/custom_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    console.log("Custom controller connected")
  }
}
```

Register in your index:

```javascript
import CustomController from "./custom_controller"
application.register("custom", CustomController)
```

## Icons

Plutonium uses Tabler Icons via Phlex:

```ruby
# In views
render Phlex::TablerIcons::Home.new(class: "w-5 h-5")
render Phlex::TablerIcons::User.new(class: "w-5 h-5 text-gray-500")
```

### Icon Sizes

```ruby
Phlex::TablerIcons::Home.new(class: "w-4 h-4")  # Small
Phlex::TablerIcons::Home.new(class: "w-5 h-5")  # Default
Phlex::TablerIcons::Home.new(class: "w-6 h-6")  # Large
```

## Typography

Plutonium uses Lato font by default. The layout loads it from Google Fonts.

Override in your layout:

```ruby
class MyLayout < Plutonium::UI::Layout::ResourceLayout
  def render_fonts
    # Your custom fonts
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

## Custom Styles

### Adding Custom Utilities

```css
@layer utilities {
  .text-gradient {
    background: linear-gradient(to right, var(--tw-gradient-from), var(--tw-gradient-to));
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
  }

  .animate-fade-in {
    animation: fadeIn 0.3s ease-in-out;
  }
}

@keyframes fadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}
```

### Component Classes

```css
@layer components {
  .btn {
    @apply px-4 py-2 rounded font-medium transition-colors;
  }

  .btn-primary {
    @apply bg-primary-600 text-white hover:bg-primary-700;
  }

  .card {
    @apply bg-white rounded-lg shadow p-6;
  }
}
```

## Related

- [Theming Guide](/guides/theming)
- [Views Reference](/reference/views/)
- [Forms Reference](/reference/views/forms)
