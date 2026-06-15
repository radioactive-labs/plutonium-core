# Configuration

Plutonium is configured through `Plutonium.configure` in an initializer. A generated app has this at `config/initializers/plutonium.rb`:

```ruby
# config/initializers/plutonium.rb
Plutonium.configure do |config|
  config.load_defaults 1.0

  # config.shell = :modern
  # config.navii_host_url = "https://api.navii.dev"

  config.assets.logo       = "plutonium.png"
  config.assets.favicon    = "plutonium.ico"
  config.assets.stylesheet = "plutonium.css"
  config.assets.script     = "plutonium.min.js"
end
```

Access the live config anywhere via `Plutonium.configuration`.

## Versioned defaults

```ruby
config.load_defaults 1.0
```

Loads the baseline defaults for a given framework version. Call this first; later versions layer their changes on top. Read the resolved version with `config.defaults_version`.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `load_defaults(version)` | — | Apply versioned framework defaults. Call first. |
| `development` | `ENV["PLUTONIUM_DEV"]` | Development mode for the framework itself (local assets, hot reload, verbose errors). Query with `config.development?`. You rarely set this in an app — see [Development mode](#development-mode). |
| `cache_discovery` | `true` outside `development` env | Cache resource/route discovery. Disable to pick up new resources without a reboot. |
| `enable_hotreload` | `true` in `development` env | Hot-reload Plutonium components on change. |
| `shell` | `:modern` | Chrome style: `:modern` (topbar + icon rail), `:plain` (topbar, no icon rail), or `:classic` (legacy header + sidebar, only for upgrades). See [Layouts](./ui/layouts). |
| `navii_host_url` | `"https://api.navii.dev"` | Host of the [Navii](https://navii.dev) avatar service used by [`Avatar`](./ui/components#avatar). The component appends `/avatar/:seed`. Repoint to self-host or proxy. |
| `assets.logo` | `"plutonium.png"` | Brand logo asset. See [Assets](./ui/assets). |
| `assets.favicon` | `"plutonium.ico"` | Favicon asset. |
| `assets.stylesheet` | `"plutonium.css"` | Stylesheet entry. |
| `assets.script` | `"plutonium.min.js"` | JavaScript entry. |

## Development mode

`config.development?` is driven by the `PLUTONIUM_DEV` environment variable, not set in the initializer. It’s primarily for working **on the Plutonium gem** (uses local `src/` assets, enables hot reloading, and shows more detailed errors). Applications generally leave it unset.

```bash
export PLUTONIUM_DEV=1
```

## Assets

Asset entries live under `config.assets` and point the framework at your compiled stylesheet/script and brand imagery. The `pu:core:assets` generator wires these up. See [Assets](./ui/assets) for the full asset/Tailwind/Stimulus setup.

## Related

- [Assets](./ui/assets) — stylesheet, script, Tailwind, and design tokens
- [Layouts](./ui/layouts) — the `shell` option and ejecting chrome
- [Components › Avatar](./ui/components#avatar) — `navii_host_url`
