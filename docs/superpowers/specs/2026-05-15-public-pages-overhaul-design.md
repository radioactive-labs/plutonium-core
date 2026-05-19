# Public Pages Overhaul — Design

**Date:** 2026-05-15
**Scope:** `docs/index.md`, `docs/getting-started/index.md`, `docs/guides/index.md`, `docs/reference/index.md`
**Goal:** Overhaul the four public landing pages of the Plutonium docs site. Blend Filament's polish with Rails' editorial voice. Address two audiences (Rails developers, founders/teams) without choosing one. Make AI-readiness an equal pillar, not the headline.

---

## Direction at a glance

- **Voice:** plain & honest, peer-to-peer to Rails devs, accessible to founders. No hyped numerals, no "0% AI-comprehensible" framing.
- **Polish:** Filament-style two-column hero, animated terminal, dark sections punctuated by light section bands.
- **Proof:** real screenshots captured from a fresh scaffolded demo app; asciinema recording captured during the same scaffolding session.
- **Sequence (home):** proof-first arc — show what it does, then why it's built that way, then who it's for.

---

## Home page (`docs/index.md`)

Seven blocks. Hero first, then six numbered sections. Section ordering is fixed.

### 0. Hero — locked

```
┌────────────────────────────────────────────────────────────────┐
│  PLUTONIUM · THE RAILS RAD FRAMEWORK                           │
│                                                                │
│  The Rails framework                  ┌────────────────────┐  │
│  for things you should never          │ $ rails g pu:res:  │  │
│  write again.                         │   scaffold Post …  │  │
│                                       │ $ rails g pu:res:  │  │
│  Convention over configuration,       │   conn Post --dest │  │
│  extended to everything you           │   =admin_portal    │  │
│  keep rebuilding.                     │ $ _                │  │
│                                       └────────────────────┘  │
│  CRUD. Auth. Authorization. Multi-                             │
│  tenancy. Admin portals. Search,                               │
│  filters, bulk actions. All generated.                         │
│  All customizable. All Rails.                                  │
│                                                                │
│  [ Get started → ]  [ 15-min tutorial ]                        │
└────────────────────────────────────────────────────────────────┘
```

- **Layout:** dark background (`#0d1117`), two columns. Left: eyebrow → headline → lede → pillar list → CTAs. Right: animated terminal (asciinema embed once recorded; CSS-animated placeholder until then).
- **Eyebrow:** `PLUTONIUM · THE RAILS RAD FRAMEWORK`
- **Headline:** "The Rails framework for things you should never write again."
- **Lede:** "Convention over configuration, extended to everything you keep rebuilding."
- **Pillar line:** "**CRUD. Auth. Authorization. Multi-tenancy. Admin portals. Search, filters, bulk actions.** All generated. All customizable. All Rails."
- **CTAs:** primary "Get started →" → `/getting-started/`; ghost "15-min tutorial" → `/getting-started/tutorial/`.
- **Terminal content:**
  ```
  $ rails g pu:res:scaffold Post title:string body:text
        create  app/models/post.rb
        create  app/resource_registries/post_definition.rb
        create  db/migrate/...create_posts.rb
  $ rails g pu:res:conn Post --dest=admin_portal
        route   resource :posts
        ✓ Connected Post to AdminPortal
  $ _
  ```

### 1. What you stop writing — capability comparison

Surface-area before/after. Compares **what's included** rather than lines or time. Two columns side-by-side: hand-rolled file tree (with "before search, filters, bulk actions, auth…" trailing) vs Plutonium two-command terminal. Stat row below each side compares capabilities (Just CRUD / No auth / No search vs Full CRUD / + Auth / + Search / + Filters / + Bulk actions).

Section title: "What you stop writing."
Subtitle: "A blog with posts, comments, an admin panel, and authorization. Same feature, two paths."

### 2. Four pillars

Plain & honest naming. Four equal cards in a 4-column grid. Light section band.

- **Convention over configuration** — Extended to resources, policies, portals, and tenancy — not just routes and views.
- **It's just Rails** — Generated code lives in your repo. Edit it, override it, delete it. The "magic" is regular Ruby mixins you can read.
- **Multi-tenant ready** — Path or domain tenancy. Scoped relations. Invites and memberships out of the box.
- **AI-readable** — Predictable file layout and naming. Built-in skills teach AI assistants the patterns.

Section title: "Built on principles, not magic."

### 3. A real example, walked through

Hero portal shot up top (wide), then a 3-column strip below: asciinema terminal · index page screenshot · form page screenshot.

- **Wide shot:** the portal layout with sidebar/nav and the posts index visible.
- **Asciinema:** the scaffold commands captured during the demo-app creation (see Assets section).
- **Index screenshot:** `/admin/posts` table view.
- **Form screenshot:** `/admin/posts/new` auto-generated form.

Section title: "Two commands. A whole portal."

### 4. For Rails devs / For founders

Side-by-side audience split. Two columns of equal weight separated by a thin divider.

**Left — For Rails developers**
> The missing layer between Rails and the apps you keep building.
- Convention extended to CRUD, policies, and portals
- Generated code lives in your repo — edit anything
- Mountable Rails engines for packages and portals
- ActionPolicy authorization, baked in

**Right — For founders & teams**
> Skip the SaaS template debate. Plutonium turns Rails into a SaaS toolkit.
- Admin panel, signup, and invites on day one
- Multi-tenant scoping when you need it
- No template lock-in — it's just your Rails app
- Ship faster with AI tools that understand your code

Section title: "Plutonium fits two kinds of teams."

### 5. What's in the box — categorized

Three category rows. Each row has a small uppercase header (red `#d33`) and a 3-column grid of capabilities. Each capability has a bold name and a one-line description.

- **Resources** — Scaffolds · Search & filters · Custom & bulk actions
- **App structure** — Portals · Packages · Multi-tenancy
- **People & access** — Auth (Rodauth) · Authorization · Invites & memberships

Section title: "Organized the way you'll use it."

### 6. CTA — manifesto close

Centered block with subtle gradient background.

- **Line:** *"Stop writing the parts of every Rails app you've already written. Plutonium is what should have been there all along."*
- **Template toggle pills (centered):**
  - `plutonium` — *core + portals*
  - `pluton8` — *+ SaaS lite stack*
- **Install command (changes with selected pill):**
  - `plutonium`: `rails new my_app -m https://radioactive-labs.github.io/plutonium-core/templates/plutonium.rb`
  - `pluton8`: `rails new my_app -m https://radioactive-labs.github.io/plutonium-core/templates/pluton8.rb`
- **CTAs:** primary "Get started →" → `/getting-started/`; ghost "GitHub" → repo.

The pill toggle is a small Vue component (the docs site is VitePress, not a Plutonium app — so no Stimulus). Swaps the install command line on click.

---

## Section landings (`getting-started/`, `guides/`, `reference/`)

All three use **Pattern B — numbered rail with sidebar**. Eyebrow + h1 + lede above; below, a two-column layout: left rail = numbered/categorized list of the section's content (vertical red bar), right sidebar = shortcuts and help.

### Getting Started (`docs/getting-started/index.md`)

- **Eyebrow:** GETTING STARTED
- **H1:** "Get a working Plutonium app in 15 minutes."
- **Lede:** "Walk the path top to bottom, or skip to the part you need."
- **Left rail (numbered steps from the tutorial):**
  1. Project setup
  2. First resource
  3. Authentication
  4. Authorization
  5. Custom actions
  6. Nested resources
  7. Author portal
  8. Customizing UI
- **Right sidebar:**
  - *Already know your way around?* — Installation · Concepts overview · Generators reference
  - *Need help?* — GitHub Discussions · Open an issue

### Guides (`docs/guides/index.md`)

- **Eyebrow:** GUIDES
- **H1:** "How to do the things Plutonium apps do."
- **Lede:** "Task-oriented walkthroughs for the parts of the framework you reach for most."
- **Left rail (categorized, not numbered — uses category headers between groups):**
  - Setup & Resources — Adding Resources · Creating Packages
  - Auth — Authentication · Authorization
  - Features — Custom Actions · Nested Resources · Multi-tenancy · Search & Filtering · User Invites
  - Customization — Theming
  - Quality — Testing
- **Right sidebar:**
  - *New to Plutonium?* — Start with the tutorial
  - *Looking for APIs?* — Browse the reference
  - *Need help?* — GitHub Discussions

### Reference (`docs/reference/index.md`)

- **Eyebrow:** REFERENCE
- **H1:** "Every API, in one place."
- **Lede:** "The full surface area of Plutonium — controllers, policies, definitions, fields, interactions, generators."
- **Left rail (categorized, not numbered):**
  - App — Overview · Packages · Portals
  - Resource — Definitions · Fields · Policies · Controllers · Interactions
  - UI — Pages · Forms · Tables · Displays
  - Tooling — Generators · Testing helpers
- **Right sidebar:**
  - *Learning?* — Tutorial · Concepts
  - *Solving a problem?* — Guides
  - *Need help?* — GitHub Discussions

---

## Visual system

Reused across all four pages so they feel like one product.

- **Type:** system sans, headlines with `-0.02em` to `-0.025em` letter-spacing for tightness.
- **Color tokens:**
  - Dark surface: `#0d1117`
  - Light surface: `#fff`
  - Subtle band: `#fafafa`
  - Border: `#e0e0e0`
  - Muted text: `#666`
  - Accent (red): `#d33` (matches existing Plutonium brand)
  - Success pill: `#ecf9f1` / `#0a7c3f`
- **Terminal block:** rounded 6–8px, `#161b22` body on dark sections, `#0d1117` on light sections, `#7ee787` for prompts, `#58a6ff` cursor.
- **Animated cursor:** blink every 1s.
- **Buttons:** primary red (`#d33` bg, white text); ghost (transparent, border, current color).
- **Eyebrow style:** 11–12px uppercase, `0.1em` letter-spacing.

These tokens should be added as CSS variables in `docs/.vitepress/theme/custom.css` (or wherever existing landing styles live) so they're shareable across pages.

---

## Assets to produce

1. **Demo Rails app for screenshots + asciinema** — scaffold a fresh Rails app via the `plutonium` template, generate `Post(title:string, body:text, published:boolean)` and `Comment(post:references, body:text)`, connect both to an `AdminPortal`. Capture asciinema during this scaffold + boot session.

2. **Asciinema recording** — saved alongside the page assets (likely `docs/public/asciinema/` or `docs/public/images/`). Trim to ~30s. Loop. Embedded via asciinema-player or a CSS-animated SVG/gif fallback.

3. **Screenshots (3)** —
   - `home-portal.png` — wide shot of the portal layout with sidebar + posts index visible
   - `home-index.png` — close shot of `/admin/posts` table
   - `home-form.png` — close shot of `/admin/posts/new` form

   All captured at consistent viewport size (e.g., 1280×800), light mode, with seeded data (3–5 posts including a draft to show the boolean pill).

---

## Interaction

Only one interactive element across the four pages:

- **Template toggle pills** in the home-page CTA. Swaps between `plutonium.rb` and `pluton8.rb` install commands. Implementation: a Vue component registered in `docs/.vitepress/theme/index.ts` (the standard VitePress theme extension point), used in `docs/index.md` via `<TemplateToggle />`.

Everything else is static.

---

## Structure of work

Each piece below is independently buildable.

1. **CSS theme tokens** — add the variables, button styles, terminal block, eyebrow class to the VitePress custom CSS. Foundation for everything else.
2. **Home hero + section 1** — through the first proof block.
3. **Home sections 2–4** — pillars, walkthrough placeholders (asciinema/screenshots come last), audience split.
4. **Home sections 5–6** — in-the-box grid, manifesto CTA with template-toggle pills + Stimulus controller.
5. **Getting Started landing** — Pattern B page.
6. **Guides landing** — Pattern B page.
7. **Reference landing** — Pattern B page.
8. **Demo app + asciinema + screenshots** — produce the assets. Can run in parallel to 1–7.
9. **Wire assets into home section 3** — replace placeholders.

---

## Out of scope

- Inner pages (tutorial chapters, individual guides, reference subpages) — only the four landing pages are in scope.
- Vitepress theme switch (light/dark toggle) — keep current behavior.
- Logo, favicon, brand mark changes.
- Pricing, blog, changelog — no such pages exist; not adding them here.
- Search UX, sidebar/nav changes — those live in `.vitepress/config.ts` and aren't part of this overhaul.
