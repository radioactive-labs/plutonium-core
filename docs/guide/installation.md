# Installation

## Requirements

Plutonium requires the following to run:

- Ruby 3.2.2+
- Rails 7.1+

## Installing Plutonium

1. Add plutonium to your bundle

```bash
bundle add plutonium
```

2. Run the install generator to setup the integration

```bash
rails g pu:core:install
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
