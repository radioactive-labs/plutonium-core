# Wizard relaunch prompt — "resume or start new" on bare launch

## Problem

Tokened (repeatable) wizards — those with **no `concurrency_key`** — mint a fresh
run on every bare launch (`GET /onboarding`). A user with one or more pending
(in-progress) runs has no way to resume from the launch URL; each visit forks a
new run. Keyed wizards (incl. one-time and anchored) already auto-resume their
single keyed run, so this gap is specific to tokened wizards.

## Goal

Let a tokened wizard **opt in** so that a bare launch with ≥1 pending run shows a
chooser page — list the pending runs (resume any) or start a new one — instead of
silently forking. `/onboarding` becomes a chooser in that case.

## Decisions (settled in brainstorming)

- **Opt-in**, not default. A macro turns it on; default behaviour (fresh run) is
  unchanged, so existing wizards and "run repeatedly" flows don't nag.
- **Chooser whenever ≥1 pending** (owner- and tenant-scoped). Even a single
  pending run shows the page, so "Start new" stays reachable.
- **0 pending → fresh run**, exactly as today.
- **No-op unless it matters**: ignored for keyed wizards (already auto-resume) and
  `anonymous`/guest wizards (session-keyed single run, no owner).

## Design

### 1. DSL — `on_relaunch`

```ruby
on_relaunch :prompt   # show the chooser when pending runs exist
# omit → :new (default) → always a fresh run
```

`dsl.rb`: store `@on_relaunch` (default `:new`), inherit it, expose
`relaunch_prompt?` (`@on_relaunch == :prompt`).

### 2. Launch branch — `driving.rb#wizard_launch`

Before building the runner (which mints a token), decide:

```
require auth
if relaunch_prompt? && !anonymous? && !concurrency_key?
   && params[:new].blank? && pending_entries.any?
     → render the chooser page (no token minted)
else
     → (today) build runner → mint token → PRG to first step
```

- `pending_entries` = `Plutonium::Wizard::Resume.entries_for(owner, scope:)`
  filtered to `current_wizard_class` — reuses the existing listing module, which
  already resolves owner/tenant scoping and per-run `resume_url`s.
- `params[:new]` present → skip the chooser (the "Start new" path).

### 3. Chooser page — `Plutonium::UI::Page::WizardChooser`

Same card aesthetic as `WizardCompleted`. Renders the wizard label/description,
then a list of pending runs — each row: current-step label + relative
`updated_at` + a **Resume** link (`entry.resume_url`) — and a primary **Start
new** button (→ bare launch URL with `?new=1`). No per-row discard in v1 (YAGNI;
`cancel` makes it easy to add later).

### 4. "Start new" path

The Start-new button links to the bare launch URL + `?new=1`. Re-enters
`wizard_launch`; the `params[:new]` guard skips the chooser; mints a fresh token
and redirects to the first step — identical to today's launch. GET, like the
existing launch (no DB row until the first step is submitted → no orphans).

## Testing

A tokened dummy wizard with `on_relaunch :prompt`:

- 0 pending → fresh redirect (unchanged).
- ≥1 pending → chooser lists them with resume links + a Start-new control.
- `?new=1` → fresh redirect even with pending.
- opt-out wizard → always fresh (no chooser).
- keyed / anonymous wizard declaring `on_relaunch` → no-op (still auto-resume / fork).

## Out of scope

- Per-row discard/cancel from the chooser (v2).
- Changing keyed/one-time/anchored behaviour (already auto-resume).
- A standalone dashboard widget (the `Resume` module already covers that).
