# PLUTONIUM_DEV asset overrides — respect consumer customization

**Status:** approved
**Date:** 2026-05-09
**Branch base:** `feature/ui-layout-overhaul`

## Problem

When a consumer app sets `PLUTONIUM_DEV=1` (typically because they have a local `plutonium-core` checkout and want framework Ruby auto-reload), the rendered application loses all of its design customizations:

- Custom Tailwind config and theme tokens disappear
- App-level CSS overrides are not applied
- Registered Stimulus controllers and other consumer JS are missing

The consumer cannot meaningfully "develop and see changes actively" against their own app while PLUTONIUM_DEV is set, because the framework forces its raw, unbundled assets in place of the consumer's bundled `application.css` / `application.js`.

## Root cause

`PLUTONIUM_DEV=1` flips two switches via `Plutonium.configuration.development = true`:

1. **`lib/plutonium/railtie.rb:42-44, 75-87`** — mounts `Rack::Static` at `/build` to serve the gem's `src/` directory. Benign on its own.
2. **`lib/plutonium/helpers/assets_helper.rb:73-79`** — `resource_asset_url_for` *unconditionally* rewrites the stylesheet and script URLs to `/build/<hashed-plutonium>.{css,js}` from the gem's manifest. This bypasses whatever the consumer configured via `Plutonium.configuration.assets.stylesheet` / `.script`.

The `pu:res:assets` (`pu:core:assets`) generator sets `config.assets.stylesheet = "application"` and `config.assets.script = "application"` and adds `@import "gem:plutonium/src/css/plutonium.css"` to the consumer's `application.tailwind.css`. With this setup the consumer's own build pipeline already rebuilds when the gem's CSS source changes — the URL rewrite isn't needed for hot-reload to work, it just clobbers the consumer's bundle.

`Plutonium::Reloader` (Ruby auto-reload of framework code) is unrelated — it's gated by `Plutonium.configuration.development?` independently and is the legitimate value PLUTONIUM_DEV provides for gem-checkout workflows. That behavior must be preserved.

## Goals

1. With `PLUTONIUM_DEV=1` and a customized asset config, the consumer's bundled `application.css` / `application.js` ship to the browser, with all their tokens, theme, and JS controllers intact.
2. With `PLUTONIUM_DEV=1` and *no* asset customization (the dummy app, or unconfigured apps), the dev `/build/*` hot-served URLs continue to be used.
3. Ruby auto-reload of framework code via `Plutonium::Reloader` remains gated by `PLUTONIUM_DEV` and continues to work.
4. No new environment variable.

## Non-goals

- Removing the `/build` Rack mount or the dev asset server entirely.
- Changing what `PLUTONIUM_DEV` means semantically beyond this asset URL behavior.
- Rewriting the `pu:core:assets` generator or its templates.
- Touching the dummy app's configuration.

## Design

Track asset customization explicitly on `Plutonium::Configuration::AssetConfiguration`. The dev-mode asset URL override only applies when the asset attribute has *not* been customized.

### `AssetConfiguration` changes

Replace the current ad-hoc `attr_accessor` declarations with a defaults map and generated accessors that record customization:

```ruby
class AssetConfiguration
  DEFAULTS = {
    logo: "plutonium.png",
    favicon: "plutonium.ico",
    stylesheet: "plutonium.css",
    script: "plutonium.min.js"
  }.freeze

  def initialize
    @customized = {}
    DEFAULTS.each { |key, value| instance_variable_set(:"@#{key}", value) }
  end

  DEFAULTS.each_key do |attr|
    attr_reader attr

    define_method(:"#{attr}=") do |value|
      @customized[attr] = true
      instance_variable_set(:"@#{attr}", value)
    end
  end

  def customized?(attr)
    @customized.fetch(attr, false)
  end
end
```

Setting any asset — even back to its default value — flags it as customized. This matches user intent: "I touched this on purpose, don't override me."

### `AssetsHelper#resource_asset_url_for` changes

Skip the dev override when the relevant asset attribute is customized:

```ruby
def resource_asset_url_for(type, fallback)
  attr = (type == :css) ? :stylesheet : :script
  if Plutonium.configuration.development? &&
     !Plutonium.configuration.assets.customized?(attr)
    resource_development_asset_url(type)
  else
    fallback
  end
end
```

Everything else in the helper module is unchanged.

### Scope of the override

The dev-mode URL swap currently only applies to **stylesheet and script** (the two assets that flow through `resource_asset_url_for`). `resource_logo_asset` and `resource_favicon_asset` already return `Plutonium.configuration.assets.logo` / `.favicon` directly with no dev-mode branch, so customization tracking on `:logo` and `:favicon` is harmless symmetry — it costs nothing and keeps `AssetConfiguration` uniform if a future change ever needs it.

### What stays unchanged

- `lib/plutonium/railtie.rb` — `setup_development_asset_server` keeps mounting `Rack::Static` at `/build`. Customized apps simply never resolve URLs to that mount.
- `lib/plutonium/reloader.rb` — `development?` gating of gem `lib/` watch paths is untouched; framework Ruby auto-reload continues to work under PLUTONIUM_DEV.
- `Plutonium::Configuration` itself outside the nested `AssetConfiguration`.
- All existing default values for assets.

## Behavior matrix

| `PLUTONIUM_DEV` | `config.assets.stylesheet` set by user | URL emitted for stylesheet                  |
| --------------- | -------------------------------------- | ------------------------------------------- |
| unset           | no                                     | `"plutonium.css"` (Rails asset pipeline)    |
| unset           | yes (`"application"`)                  | `"application"` (consumer bundle)           |
| set             | no                                     | `/build/plutonium-<hash>.css` (dev mount)   |
| set             | yes (`"application"`)                  | `"application"` (consumer bundle)           |

Same matrix for script.

## Test plan

### Unit tests — `test/plutonium/configuration_test.rb`

- `AssetConfiguration#customized?(:stylesheet)` returns `false` on a freshly initialized configuration.
- After `assets.stylesheet = "application"`, `customized?(:stylesheet)` returns `true`.
- After `assets.stylesheet = AssetConfiguration::DEFAULTS[:stylesheet]` (assigning the same value as the default), `customized?(:stylesheet)` still returns `true` — explicit assignment counts as customization.
- `customized?` for the other three attrs (`:script`, `:logo`, `:favicon`) behaves identically.
- Unrelated attrs are independent: setting `stylesheet` does not flip `customized?(:script)`.

### Helper tests — `test/plutonium/helpers/assets_helper_test.rb`

(Create the file if it doesn't exist; otherwise add cases.)

- Dev mode + default stylesheet → `resource_asset_url_for(:css, fallback)` returns the `/build/...` URL parsed from `src/build/css.manifest`.
- Dev mode + customized stylesheet → returns the fallback (`"application"`).
- Dev mode + default script → returns `/build/...` URL from `js.manifest`.
- Dev mode + customized script → returns the fallback.
- Non-dev mode → returns the fallback regardless of customization (regression check on the existing path).

Stub `Plutonium.configuration.development?` and the manifest reads as needed.

### Manual verification

1. In a consumer app with `pu:core:assets` already run, set `PLUTONIUM_DEV=1`, run the consumer's `yarn dev` and Rails server, and confirm the page renders with the consumer's theme/tokens and Stimulus controllers active.
2. In `test/dummy` of plutonium-core, set `PLUTONIUM_DEV=1`, run `yarn dev` in plutonium-core, and confirm the dummy app still picks up changes from `src/css/plutonium.css` via `/build/...`.

## Documentation updates

- `docs/guides/theming.md` and `docs/reference/assets/index.md`: short note that any custom `config.assets.stylesheet` / `config.assets.script` opts out of the PLUTONIUM_DEV asset URL override; the consumer's build pipeline is then responsible for picking up gem CSS/JS source changes (which it already does via the `@import "gem:plutonium/..."` line installed by `pu:core:assets`).
- `CLAUDE.md` (project root): in the `PLUTONIUM_DEV=1` description, clarify that the "uses local assets instead of packaged ones" behavior applies only to assets not customized by the consumer.
- `.claude/skills/plutonium-assets/SKILL.md` if it mentions PLUTONIUM_DEV. (Skill changes ship with the gem release; no urgency.)

## Risk and mitigation

- **Edge case:** A consumer who explicitly sets `config.assets.stylesheet = "plutonium"` (no extension, matches the gem's bundled asset pipeline name) opts out of the dev override even though they're effectively asking for the gem's defaults. Acceptable: the explicit assignment is treated as deliberate intent. Documented.
- **Backward compatibility:** No public API removed. `AssetConfiguration` keeps the same readable accessors and the same default values. New `customized?` predicate is additive. Anyone relying on the old override behavior in a consumer app was already getting broken design — by definition, no working setup depends on the current behavior outside of the dummy app, which uses defaults and is unaffected.
- **Setter generation:** Replacing `attr_accessor` with hand-defined setters that record state is the only structural change to `AssetConfiguration`. Read paths are identical.

## Out of scope (deferred)

- Considering removal of the `/build` Rack mount entirely (Approach B in brainstorming): valuable cleanup but adds friction to the gem's own dev workflow against the dummy app. Not pursued now.
- Splitting PLUTONIUM_DEV into separate flags for reloader vs. asset server: rejected as flag proliferation for a problem that this design solves directly.
