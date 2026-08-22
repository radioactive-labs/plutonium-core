# Configuration

Plutonium is configured through `Plutonium.configure` in an initializer. `pu:core:install` writes `config/initializers/plutonium.rb`:

```ruby
# Configure plutonium

Plutonium.configure do |config|
  config.load_defaults 1.0

  # Shell variant: :modern (icon rail), :plain (no rail), or :classic (legacy).
  config.shell = :modern
  # Configure plutonium above.
end
```

Everything else is opt-in. Read the live config anywhere via `Plutonium.configuration`, and query development mode with `Plutonium.configuration.development?`.

Other generators edit this file in place. `pu:core:assets` rewrites two lines to point at your own bundles:

```ruby
config.assets.stylesheet = "application"
config.assets.script = "application"
```

## Versioned defaults

```ruby
config.load_defaults 1.0
```

Applies the baseline defaults for a framework version, and every earlier version in order. Call it first, before any option you set yourself, or the defaults overwrite you. `1.0` is currently the only version. Read back what resolved with `config.defaults_version`, which is `nil` until you call this.

Passing a version older than the earliest available raises rather than silently applying nothing.

## Core

| Option | Default | Description |
|--------|---------|-------------|
| `load_defaults(version)` | — | Apply versioned framework defaults. Call first. |
| `development` | `ENV["PLUTONIUM_DEV"]` | Development mode for the framework itself (local assets, hot reload, verbose errors). Query with `config.development?`. Apps rarely set this, see [Development mode](#development-mode). |
| `cache_discovery` | `true` outside the `development` env | Cache resource/route discovery. Disable to pick up new resources without a reboot. |
| `enable_hotreload` | `true` in the `development` env | Hot-reload Plutonium components on change. |

## Appearance

| Option | Default | Description |
|--------|---------|-------------|
| `shell` | `:modern` | Chrome style: `:modern` (topbar + icon rail), `:plain` (topbar, no icon rail), or `:classic` (legacy header + sidebar, only for upgrades). See [Layouts](./ui/layouts). |
| `default_page_width` | `:md` | Width of detail-style pages: the show page and resource forms. One of `:sm` `:md` `:lg` `:xl` `:full` (`:full` opts out of any constraint). Index and table pages are unaffected. Override per-resource with `page_width` / `form_width` / `display_width`, see [Definition › Page width](./resource/definition#page-width). |
| `navii_host_url` | `"https://api.navii.dev"` | Host of the [Navii](https://navii.dev) avatar service used by [`Avatar`](./ui/components#avatar). The component appends `/avatar/:seed`. Repoint to self-host or proxy. |
| `assets.logo` | `"plutonium.png"` | Brand logo asset. See [Assets](./ui/assets). |
| `assets.favicon` | `"plutonium.ico"` | Favicon asset. |
| `assets.stylesheet` | `"plutonium.css"` | Stylesheet entry. `pu:core:assets` sets this to `"application"`. |
| `assets.script` | `"plutonium.min.js"` | JavaScript entry. `pu:core:assets` sets this to `"application"`. |

## Rendering and routing

| Option | Default | Description |
|--------|---------|-------------|
| `auto_eager_load_collections` | `true` | Index pages, kanban boards and CSV exports preload the associations and attachments they render. The field set comes from the policy, so it is known before the collection loads. Set `false` to disable globally, or override `auto_eager_load_collections?` in a controller. See [Performance](/guides/performance). |
| `nested_association_routes` | `:detected` | Where a resource's nested routes come from. `:detected` draws one for every `has_many` / `has_one` whose child is a registered resource. `:declared` draws only what `register_resource ..., associations:` names, so a resource that names none gets none. Any other value raises `ArgumentError` rather than drawing the wrong route table for a typo. See [Nested resources](./tenancy/nested-resources#declaring-which-associations-get-routes). |
| `default_currency_unit` | `nil` | Symbol used when rendering a currency value with no unit set on `has_cents` or the display. `nil` falls back to the i18n `number.currency.format.unit` when the locale defines one, otherwise no symbol. Set a literal like `"£"`, or `false` (or `""`) for no symbol application-wide. See [`has_cents`](./resource/model#has-cents) and [Currency fields](./ui/forms#currency-fields). |
| `default_phone_country` | `nil` | Default country (ISO2, e.g. `"gh"`) for `as: :phone` inputs that set no `initial_country:`. `nil` leaves it to intl-tel-input, with no country preselected. Stored verbatim; `config.normalized_default_phone_country` returns it downcased, so `"GH"` and `"gh"` are interchangeable. See [Phone fields](./ui/forms#phone-fields). |

## Attachments

`attachment_backend` picks which library stages a file that travels as a plain string: `:active_storage` or `:shrine`. It is the shared default, and each subsystem layers its own override on top, so setting it once covers both and setting one of theirs narrows it to that subsystem.

| Option | Default | Description |
|--------|---------|-------------|
| `attachment_backend` | `nil` | Shared default for staged attachments. `nil` auto-detects. |
| `wizards.attachment_backend` | `nil` | Overrides the above for wizard attachment fields. `nil` falls through. |
| `async_interactions.attachment_backend` | `nil` | Overrides the above for run dispatch. `nil` falls through. |

Resolution runs first match wins:

1. The field's own `backend:` option.
2. The subsystem setting, `wizards.attachment_backend` or `async_interactions.attachment_backend`.
3. `config.attachment_backend`.
4. Auto-detection: `:shrine` if `ActiveShrine` is loaded, else `:active_storage`.

Only plain uploads are affected. A direct-upload field already arrives as a token and ignores all of this.

## Wizards

`enabled` gates the subsystem and its migrations. Full detail in [Wizards › Storage & config](./wizard/storage-config).

| Option | Default | Description |
|--------|---------|-------------|
| `wizards.enabled` | `false` | Enable wizards and their migrations. See [Enabling the subsystem](./wizard/storage-config#enabling-the-subsystem). |
| `wizards.width` | `:md` | Width of wizard step pages. **Independent of `default_page_width`**: a wizard is a self-contained flow, so widening resource pages leaves wizards where they are. Same size tokens. Override per wizard with `width`. |
| `wizards.cleanup_after` | `14.days` | How long completed and abandoned sessions are kept before `SweepJob` removes them. See [Cleanup & the SweepJob](./wizard/storage-config#cleanup-the-sweepjob). |
| `wizards.database` | `:primary` | Which database the wizard tables live in. |
| `wizards.encrypt_data` | `false` | Encrypt every wizard's staged `data` at rest. Off by default because it needs ActiveRecord encryption keys configured. A wizard can still opt in with `encrypt_data` or out with `encrypt_data false` regardless. See [Encryption](./wizard/storage-config#encryption). |
| `wizards.attachment_backend` | `nil` | See [Attachments](#attachments). |

## Async interactions

`enabled` gates the runs subsystem and its migrations. Full detail in [Async interactions](./behavior/async-interactions).

| Option | Default | Description |
|--------|---------|-------------|
| `async_interactions.enabled` | `false` | Enable persisted runs and their migrations. See [Enabling](./behavior/async-interactions#enabling). |
| `async_interactions.queue` | `:default` | ActiveJob queue for run jobs. |
| `async_interactions.stall_after` | `1.hour` | How long a run may sit with no progress write before `ReapJob` treats it as stalled. See [Stalled runs and ReapJob](./behavior/async-interactions#stalled-runs-and-reapjob). |
| `async_interactions.attachment_backend` | `nil` | See [Attachments](#attachments). |

## Development mode

`config.development?` is driven by the `PLUTONIUM_DEV` environment variable, not by the initializer. It is for working **on the Plutonium gem**: it uses local `src/` assets, enables hot reloading, and shows more detailed errors. Applications leave it unset.

```bash
export PLUTONIUM_DEV=1
```

## Related

- [Assets](./ui/assets) — stylesheet, script, Tailwind, and design tokens
- [Layouts](./ui/layouts) — the `shell` option and ejecting chrome
- [Components › Avatar](./ui/components#avatar) — `navii_host_url`
- [Wizards › Storage & config](./wizard/storage-config) — the `wizards.*` settings in context
- [Async interactions](./behavior/async-interactions) — the `async_interactions.*` settings in context
