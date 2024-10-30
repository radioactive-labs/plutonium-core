# Installation

Plutonium ships as a gem but with extension points within your app.

## Installing Plutonium

::: warning Prerequisites
- A new or existing Rails 7.1+ application
- Ruby 3.2.2+
:::

1. Add Plutonium to your Gemfile:

```ruby
gem 'plutonium'
```

2. Install required dependencies:

```bash
bundle install
```

3. Run the installation generator:

```bash
rails generate pu:core:install
```

## Configure Authentication

Plutonium expects a non-nil `user` per request in order to perform authorization checks.

If your `ApplicationController` inherits `ActionController::Base` and implements a `current_user` method,
this will be used by plutonium.

Otherwise, configure the `current_user` method in `app/controllers/resource_controller.rb` to return a non nil value.

```ruby
class ResourceController < PlutoniumController
  include Plutonium::Resource::Controller

  private def current_user
    raise NotImplementedError, "#{self.class}#current_user must return a non nil value" # [!code --]
    "Guest" # allow all users # [!code ++]
  end
end
```

::: tip Note
You only need to perform this step if you intend to register resources in your main app or
wish to set a default authentication scheme.
:::

<!--

VitePress provides Syntax Highlighting powered by [Shiki](https://github.com/shikijs/shiki), with additional features like line-highlighting:

**Input**

````md
```js{4}
export default {
  data () {
    return {
      msg: 'Highlighted!'
    }
  }
}
```
````

**Output**

```js{4}
export default {
  data () {
    return {
      msg: 'Highlighted!'
    }
  }
}
```

## Custom Containers

**Input**

```md
::: info
This is an info box.
:::

::: tip
This is a tip.
:::

::: warning
This is a warning.
:::

::: danger
This is a dangerous warning.
:::

::: details
This is a details block.
:::
```

**Output**

::: info
This is an info box.
:::

::: tip
This is a tip.
:::

::: warning
This is a warning.
:::

::: danger
This is a dangerous warning.
:::

::: details
This is a details block.
:::

## More

Check out the documentation for the [full list of markdown extensions](https://vitepress.dev/guide/markdown).

 -->
