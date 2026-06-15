# Wizard Reference

The wizard subsystem builds **multi-step flows** — onboarding, checkout, multi-model create, branching questionnaires — as a single declarative class (`< Plutonium::Wizard::Base`). It orchestrates Plutonium's existing field DSL, form rendering, actions, and policies rather than inventing a parallel stack.

For a task-oriented walkthrough, start with the [Wizards guide](/guides/wizards).

## In this section

- **[DSL](./dsl)** — every author-facing macro and accessor: `step`, `review`, `using:`, `condition:`, per-step `on_submit`/`persist`/`on_rollback`, `execute`, `data`/`anchor`/`persisted`.
- **[Anchoring & resume](./anchoring-resume)** — running against an existing record (`anchored` / `anchor`), instance identity, and how a user resumes where they left off.
- **[Storage & config](./storage-config)** — enabling the subsystem, the `plutonium_wizard_sessions` table, `config.wizards.*`, encryption, and the cleanup `SweepJob`.
- **[Registration & launch](./registration-launch)** — reaching a user: the `wizard` definition macro and portal-level `register_wizard`.
- **[One-time wizards](./one-time)** — durable completion markers (`one_time`) and the `ensure_wizard_completed` gate.

## At a glance

| Concept | Macro / accessor |
|---|---|
| Launch chrome | `presents label:, icon:` |
| A screen | `step :key, label:, condition:, using: do ... end` |
| Branching | `condition: -> { data.<field> ... }` (subtractive, nil-safe) |
| Field reuse | `using: Model, fields:/only:/except:` (model only) |
| Terminal recap | `review label:` |
| Per-step write | `on_submit { persist record; fail!(...) }` + `on_rollback` |
| Commit | `def execute` → `succeed(...)` / `failed(...)` (use bang methods) |
| Existing record | `anchored with: Model` → `anchor` |
| Run once | `one_time once_per: :user \| :anchor` + `ensure_wizard_completed` |
| Cleanup TTL | `cleanup_after <ttl> \| :never` (+ `SweepJob`) |

## Prerequisite

Wizards are opt-in. Set `config.wizards.enabled = true` and run `rails db:migrate`. See [Storage & config](./storage-config).
