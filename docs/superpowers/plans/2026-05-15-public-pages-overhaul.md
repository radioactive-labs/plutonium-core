# Public Pages Overhaul — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:subagent-driven-development (recommended) or superpowers-extended-cc:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Overhaul the four public landing pages of the Plutonium docs site (home + Getting Started + Guides + Reference) per the locked design, and produce the supporting demo-app screenshots and asciinema asset.

**Architecture:** VitePress site with custom Vue components and shared CSS tokens. Markdown landing pages composed of small, focused Vue components (one per home section, one shared section-landing component) registered through `docs/.vitepress/theme/index.ts`. CSS variables live in `docs/.vitepress/theme/custom.css`. Visual assets (screenshots + asciinema) captured from a fresh scaffolded Rails demo app and stored under `docs/public/`.

**Tech Stack:** VitePress 1.x · Vue 3 (SFCs) · TailwindCSS-style design tokens via plain CSS variables · asciinema-player (CDN) · Plutonium gem (for demo-app scaffolding) · macOS native screenshot tools.

**User Verification:** YES — the user must visually approve the rendered home page and each section landing in a local `yarn docs:dev` browser session before the work is considered complete. A dedicated verification task at the end of the plan captures this.

---

## Spec Reference

`docs/superpowers/specs/2026-05-15-public-pages-overhaul-design.md` — re-read it before starting any task.

## File Structure

Each home section becomes one Vue SFC. Each component is small (~40–120 lines) so it's easy to read, edit, and visually iterate. Shared visual primitives (button, terminal frame, eyebrow) live in CSS — not Vue — so they're reusable in markdown without import overhead.

```
docs/
├── .vitepress/
│   └── theme/
│       ├── index.ts                    # MODIFY — register new components
│       ├── custom.css                  # MODIFY — append shared design tokens & primitives
│       └── components/                 # CREATE this dir
│           ├── HomeHero.vue
│           ├── HomeStopWriting.vue
│           ├── HomePillars.vue
│           ├── HomeWalkthrough.vue
│           ├── HomeAudienceSplit.vue
│           ├── HomeInTheBox.vue
│           ├── HomeCta.vue             # owns the template-toggle pill state
│           └── SectionLanding.vue      # shared rail+sidebar layout for the 3 section landings
├── index.md                            # REWRITE
├── getting-started/index.md            # REWRITE
├── guides/index.md                     # REWRITE
├── reference/index.md                  # REWRITE
└── public/
    ├── images/
    │   ├── home-portal.png             # asset
    │   ├── home-index.png              # asset
    │   └── home-form.png               # asset
    └── asciinema/
        └── home-scaffold.cast          # asset
```

The Vue components are imported and registered globally in `theme/index.ts` so markdown files can drop `<HomeHero />` etc. without per-file `<script setup>` blocks.

---

## Task 0: Shared CSS tokens and primitives

**Goal:** Add the design-system tokens and small CSS primitives that every component reuses, so later tasks can compose with confidence.

**Files:**
- Modify: `docs/.vitepress/theme/custom.css` (append)

**Acceptance Criteria:**
- [ ] CSS variables defined for the spec's color palette under `:root` and dark-mode variants under `.dark`.
- [ ] `.pu-eyebrow`, `.pu-btn`, `.pu-btn-primary`, `.pu-btn-ghost`, `.pu-term`, `.pu-term-cursor`, `.pu-section`, `.pu-section--dark`, `.pu-section--band` classes exist and render per the design.
- [ ] Cursor blink animation is defined and not jittery.
- [ ] No regressions on existing pages — `yarn docs:dev` still loads, default VitePress theme still works.

**Verify:** `yarn docs:dev` → open `http://localhost:5173/plutonium-core/` → existing landing still renders without console errors.

**Steps:**

- [ ] **Step 1: Read the existing custom.css** so we know what tokens/classes already exist and don't collide.

  ```bash
  cat docs/.vitepress/theme/custom.css | head -200
  ```

- [ ] **Step 2: Append the shared token block.** Add at the bottom of `docs/.vitepress/theme/custom.css`:

  ```css
  /* ===== Public-pages design tokens (2026-05) ===== */
  :root {
    --pu-bg-dark: #0d1117;
    --pu-bg-dark-2: #161b22;
    --pu-bg-light: #ffffff;
    --pu-bg-band: #fafafa;
    --pu-border: #e0e0e0;
    --pu-border-soft: #ececec;
    --pu-text: #1a1a1a;
    --pu-text-muted: #666666;
    --pu-text-faint: #888888;
    --pu-accent: #d33;
    --pu-accent-soft: #fff7f7;
    --pu-success-bg: #ecf9f1;
    --pu-success-fg: #0a7c3f;
    --pu-warn-bg: #fdf3e6;
    --pu-warn-fg: #a86b00;
    --pu-term-prompt: #7ee787;
    --pu-term-cursor: #58a6ff;
    --pu-term-text: #e6edf3;
  }

  .dark {
    --pu-bg-light: #0d1117;
    --pu-bg-band: #161b22;
    --pu-text: #e6edf3;
    --pu-text-muted: #9da7b1;
    --pu-text-faint: #6e7681;
    --pu-border: #30363d;
    --pu-border-soft: #21262d;
  }

  /* Eyebrow */
  .pu-eyebrow {
    font-size: 11px;
    text-transform: uppercase;
    letter-spacing: 0.1em;
    color: var(--pu-accent);
    font-weight: 600;
    margin-bottom: 8px;
  }
  .pu-eyebrow--muted { color: var(--pu-text-faint); }

  /* Buttons */
  .pu-btn {
    display: inline-block;
    padding: 10px 18px;
    border-radius: 6px;
    font-size: 14px;
    font-weight: 500;
    text-decoration: none;
    transition: opacity 0.15s ease;
  }
  .pu-btn:hover { opacity: 0.85; }
  .pu-btn-primary { background: var(--pu-accent); color: #ffffff; }
  .pu-btn-ghost {
    border: 1px solid currentColor;
    color: var(--pu-text);
    opacity: 0.85;
  }
  .pu-btn-ghost.on-dark { color: #e6edf3; border-color: rgba(255,255,255,0.25); }

  /* Terminal block */
  .pu-term {
    background: var(--pu-bg-dark);
    color: var(--pu-term-text);
    border-radius: 8px;
    padding: 16px 18px;
    font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
    font-size: 13px;
    line-height: 1.7;
    overflow-x: auto;
  }
  .pu-term--inline { padding: 12px 14px; font-size: 12.5px; }
  .pu-term .prompt { color: var(--pu-term-prompt); }
  .pu-term .dim { opacity: 0.55; }
  .pu-term-cursor {
    background: var(--pu-term-cursor);
    display: inline-block;
    width: 7px;
    height: 13px;
    vertical-align: text-bottom;
    animation: pu-blink 1s steps(2) infinite;
  }
  @keyframes pu-blink { 50% { opacity: 0; } }

  /* Section frames */
  .pu-section {
    padding: 64px 24px;
  }
  .pu-section--dark {
    background: var(--pu-bg-dark);
    color: var(--pu-term-text);
  }
  .pu-section--band {
    background: var(--pu-bg-band);
  }
  .pu-section .pu-section-inner {
    max-width: 1100px;
    margin: 0 auto;
  }
  .pu-section-title {
    font-size: 28px;
    letter-spacing: -0.02em;
    margin: 0 0 24px;
    color: var(--pu-text);
  }
  .pu-section--dark .pu-section-title { color: var(--pu-term-text); }
  ```

- [ ] **Step 3: Boot the dev server and confirm no regressions.**

  ```bash
  yarn docs:dev
  ```
  Open `http://localhost:5173/plutonium-core/` in a browser. The current landing should still render — we haven't touched it yet. No console errors.

- [ ] **Step 4: Commit.**

  ```bash
  git add docs/.vitepress/theme/custom.css
  git commit -m "feat(docs): add public-pages design tokens and primitives"
  ```

---

## Task 1: HomeHero component

**Goal:** Render the hero exactly as locked in the spec — dark, two-column, eyebrow + headline + lede + pillar list + CTAs on the left, animated terminal on the right.

**Files:**
- Create: `docs/.vitepress/theme/components/HomeHero.vue`
- Modify: `docs/.vitepress/theme/index.ts` (register component)
- Modify: `docs/index.md` (replace VitePress home layout with our composed page — see Step 4)

**Acceptance Criteria:**
- [ ] `<HomeHero />` renders the spec's hero on the home page.
- [ ] Animated terminal cursor blinks; terminal text matches the spec verbatim.
- [ ] CTAs link to `/getting-started/` (primary) and `/getting-started/tutorial/` (ghost).
- [ ] Layout collapses to a single column at narrow widths (< 768px) with terminal below text.
- [ ] No layout shift when fonts load.

**Verify:** `yarn docs:dev` → home page → hero is visually correct, cursor blinks, CTAs are clickable.

**Steps:**

- [ ] **Step 1: Create `docs/.vitepress/theme/components/HomeHero.vue`.**

  ```vue
  <template>
    <section class="pu-section pu-section--dark home-hero">
      <div class="pu-section-inner home-hero-grid">
        <div class="home-hero-text">
          <div class="pu-eyebrow">Plutonium · The Rails RAD framework</div>
          <h1 class="home-hero-headline">
            The Rails framework for things you should never write again.
          </h1>
          <p class="home-hero-lede">
            Convention over configuration, extended to everything you keep rebuilding.
          </p>
          <p class="home-hero-pillars">
            <b>CRUD.</b> <b>Auth.</b> <b>Authorization.</b> <b>Multi-tenancy.</b>
            <b>Admin portals.</b> <b>Search, filters, bulk actions.</b>
            All generated. All customizable. All Rails.
          </p>
          <div class="home-hero-ctas">
            <a class="pu-btn pu-btn-primary" href="/plutonium-core/getting-started/">Get started →</a>
            <a class="pu-btn pu-btn-ghost on-dark" href="/plutonium-core/getting-started/tutorial/">15-min tutorial</a>
          </div>
        </div>
        <pre class="pu-term home-hero-term"><span class="prompt">$</span> rails g pu:res:scaffold Post title:string body:text
  <span class="dim">      create  app/models/post.rb</span>
  <span class="dim">      create  app/resource_registries/post_definition.rb</span>
  <span class="dim">      create  db/migrate/...create_posts.rb</span>
  <span class="prompt">$</span> rails g pu:res:conn Post --dest=admin_portal
  <span class="dim">      route   resource :posts</span>
  <span class="dim">      ✓ Connected Post to AdminPortal</span>
  <span class="prompt">$</span> <span class="pu-term-cursor"></span></pre>
      </div>
    </section>
  </template>

  <style scoped>
  .home-hero { padding: 96px 24px; }
  .home-hero-grid {
    display: grid;
    grid-template-columns: 1.05fr 1fr;
    gap: 48px;
    align-items: center;
  }
  .home-hero-headline {
    font-size: 48px;
    line-height: 1.05;
    letter-spacing: -0.025em;
    margin: 0 0 18px;
    font-weight: 700;
  }
  .home-hero-lede {
    font-size: 18px;
    line-height: 1.5;
    opacity: 0.78;
    margin: 0 0 14px;
    max-width: 540px;
  }
  .home-hero-pillars {
    font-size: 14.5px;
    line-height: 1.6;
    opacity: 0.65;
    margin: 0 0 28px;
    max-width: 540px;
  }
  .home-hero-pillars b { color: var(--pu-term-text); font-weight: 600; opacity: 1; }
  .home-hero-ctas { display: flex; gap: 12px; flex-wrap: wrap; }
  .home-hero-term { margin: 0; white-space: pre; }
  @media (max-width: 768px) {
    .home-hero-grid { grid-template-columns: 1fr; gap: 28px; }
    .home-hero-headline { font-size: 36px; }
  }
  </style>
  ```

- [ ] **Step 2: Register the component globally in `docs/.vitepress/theme/index.ts`.**

  Replace the file with:

  ```ts
  import DefaultTheme from "vitepress/theme"
  import "./custom.css"

  import HomeHero from "./components/HomeHero.vue"

  export default {
    extends: DefaultTheme,
    enhanceApp({ app }) {
      app.component("HomeHero", HomeHero)
    }
  }
  ```

- [ ] **Step 3: Strip the existing landing content** from `docs/index.md` and replace it with a single `<HomeHero />` for now. Keep the file's existing frontmatter `layout: home` removed — we're using a custom composition, so set `layout: page` and clear the body.

  ```markdown
  ---
  layout: page
  sidebar: false
  aside: false
  ---

  <HomeHero />
  ```

  (Subsequent home tasks will add the next sections below `<HomeHero />`.)

- [ ] **Step 4: Visually verify.**

  ```bash
  yarn docs:dev
  ```
  Open `http://localhost:5173/plutonium-core/`. Confirm hero matches spec mockup, cursor blinks, CTAs work, layout collapses on narrow viewport.

- [ ] **Step 5: Commit.**

  ```bash
  git add docs/.vitepress/theme/components/HomeHero.vue docs/.vitepress/theme/index.ts docs/index.md
  git commit -m "feat(docs): hero for public-pages overhaul"
  ```

---

## Task 2: HomeStopWriting component (Section 1)

**Goal:** Render Section 1 — surface-area before/after — exactly per the locked spec (stat-set 2: capability comparison, no LOC numbers).

**Files:**
- Create: `docs/.vitepress/theme/components/HomeStopWriting.vue`
- Modify: `docs/.vitepress/theme/index.ts` (register)
- Modify: `docs/index.md` (add `<HomeStopWriting />` below hero)

**Acceptance Criteria:**
- [ ] Two-column section with light background and section title "What you stop writing." per spec.
- [ ] Left column: file-tree placeholder with `Hand-rolled` red-pill label and capability stat row "Just CRUD · No auth · No search".
- [ ] Right column: terminal block with two `pu:*` commands and stat row "Full CRUD · + Auth · + Search · + Filters · + Bulk actions".
- [ ] Section subtitle: "A blog with posts, comments, an admin panel, and authorization. Same feature, two paths."

**Verify:** `yarn docs:dev` → home page → section renders below hero, both columns aligned, pills correct colors.

**Steps:**

- [ ] **Step 1: Create the component.**

  Create `docs/.vitepress/theme/components/HomeStopWriting.vue`:

  ```vue
  <template>
    <section class="pu-section home-stop-writing">
      <div class="pu-section-inner">
        <h2 class="pu-section-title">What you stop writing.</h2>
        <p class="hsw-sub">A blog with posts, comments, an admin panel, and authorization. Same feature, two paths.</p>

        <div class="hsw-grid">
          <div>
            <span class="hsw-label hsw-label--bad">Hand-rolled</span>
            <div class="hsw-filetree">
              app/controllers/posts_controller.rb<br>
              app/views/posts/*.html.erb<br>
              app/policies/post_policy.rb<br>
              <span class="dim">…before search, filters, bulk actions, auth…</span>
            </div>
            <div class="hsw-stats">
              <span>Just <b>CRUD</b></span>
              <span>No <b>auth</b></span>
              <span>No <b>search</b></span>
            </div>
          </div>
          <div>
            <span class="hsw-label hsw-label--good">Plutonium</span>
            <pre class="pu-term pu-term--inline hsw-term"><span class="prompt">$</span> rails g pu:res:scaffold Post title:string body:text
  <span class="prompt">$</span> rails g pu:res:conn Post --dest=admin_portal</pre>
            <div class="hsw-stats hsw-stats--win">
              <span><b>Full CRUD</b></span>
              <span><b>+ Auth</b></span>
              <span><b>+ Search</b></span>
              <span><b>+ Filters</b></span>
              <span><b>+ Bulk actions</b></span>
            </div>
          </div>
        </div>
      </div>
    </section>
  </template>

  <style scoped>
  .hsw-sub { color: var(--pu-text-muted); font-size: 15px; margin: -16px 0 32px; }
  .hsw-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 24px; }
  .hsw-label {
    display: inline-block; font-size: 11px; padding: 3px 8px; border-radius: 4px;
    text-transform: uppercase; letter-spacing: 0.08em; font-weight: 600;
  }
  .hsw-label--bad { background: #fff0f0; color: var(--pu-accent); }
  .hsw-label--good { background: var(--pu-success-bg); color: var(--pu-success-fg); }
  .hsw-filetree {
    margin-top: 10px;
    background: var(--pu-bg-band); border: 1px solid var(--pu-border-soft);
    border-radius: 8px; padding: 14px;
    font-family: ui-monospace, monospace; font-size: 12px; line-height: 1.75; color: var(--pu-text-muted);
  }
  .hsw-filetree .dim { color: var(--pu-text-faint); }
  .hsw-term { margin-top: 10px; }
  .hsw-stats {
    margin-top: 14px; display: flex; gap: 14px; flex-wrap: wrap;
    font-size: 11.5px; text-transform: uppercase; letter-spacing: 0.08em; color: var(--pu-text-faint);
  }
  .hsw-stats b { color: var(--pu-text); font-weight: 600; }
  .hsw-stats--win b { color: var(--pu-success-fg); }
  @media (max-width: 768px) { .hsw-grid { grid-template-columns: 1fr; } }
  </style>
  ```

- [ ] **Step 2: Register in `docs/.vitepress/theme/index.ts`.** Add the import and `app.component` line:

  ```ts
  import HomeStopWriting from "./components/HomeStopWriting.vue"
  // ... in enhanceApp:
  app.component("HomeStopWriting", HomeStopWriting)
  ```

- [ ] **Step 3: Add to `docs/index.md`** below `<HomeHero />`:

  ```markdown
  <HomeHero />

  <HomeStopWriting />
  ```

- [ ] **Step 4: Visually verify.** `yarn docs:dev` → confirm section renders correctly below hero.

- [ ] **Step 5: Commit.**

  ```bash
  git add docs/.vitepress/theme/components/HomeStopWriting.vue docs/.vitepress/theme/index.ts docs/index.md
  git commit -m "feat(docs): home section 1 — what you stop writing"
  ```

---

## Task 3: HomePillars component (Section 2)

**Goal:** Render Section 2 — four equal pillars in a 4-column grid on a light band.

**Files:**
- Create: `docs/.vitepress/theme/components/HomePillars.vue`
- Modify: `docs/.vitepress/theme/index.ts` (register)
- Modify: `docs/index.md`

**Acceptance Criteria:**
- [ ] Section title: "Built on principles, not magic."
- [ ] Four cards with names "Convention over configuration", "It's just Rails", "Multi-tenant ready", "AI-readable".
- [ ] Card descriptions match the spec verbatim, including the corrected "It's just Rails" copy mentioning regular Ruby mixins.
- [ ] On a light band background.

**Verify:** `yarn docs:dev` → home page → pillars render as a 4-column grid, copy matches spec.

**Steps:**

- [ ] **Step 1: Create the component.**

  ```vue
  <template>
    <section class="pu-section pu-section--band">
      <div class="pu-section-inner">
        <div class="pu-eyebrow pu-eyebrow--muted">Four pillars</div>
        <h2 class="pu-section-title">Built on principles, not magic.</h2>
        <div class="hp-grid">
          <div class="hp-card" v-for="p in pillars" :key="p.name">
            <div class="hp-icon">{{ p.icon }}</div>
            <div class="hp-name">{{ p.name }}</div>
            <div class="hp-desc">{{ p.desc }}</div>
          </div>
        </div>
      </div>
    </section>
  </template>

  <script setup>
  const pillars = [
    { icon: "⚙", name: "Convention over configuration",
      desc: "Extended to resources, policies, portals, and tenancy — not just routes and views." },
    { icon: "💎", name: "It's just Rails",
      desc: "Generated code lives in your repo. Edit it, override it, delete it. The “magic” is regular Ruby mixins you can read." },
    { icon: "🏢", name: "Multi-tenant ready",
      desc: "Path or domain tenancy. Scoped relations. Invites and memberships out of the box." },
    { icon: "🤖", name: "AI-readable",
      desc: "Predictable file layout and naming. Built-in skills teach AI assistants the patterns." },
  ]
  </script>

  <style scoped>
  .hp-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 16px; }
  .hp-card {
    padding: 18px; border: 1px solid var(--pu-border-soft); border-radius: 8px;
    background: var(--pu-bg-light);
  }
  .hp-icon { font-size: 20px; margin-bottom: 8px; opacity: 0.75; }
  .hp-name { font-weight: 600; font-size: 15px; color: var(--pu-text); margin-bottom: 6px; line-height: 1.25; }
  .hp-desc { font-size: 13px; color: var(--pu-text-muted); line-height: 1.5; }
  @media (max-width: 900px) { .hp-grid { grid-template-columns: repeat(2, 1fr); } }
  @media (max-width: 480px) { .hp-grid { grid-template-columns: 1fr; } }
  </style>
  ```

- [ ] **Step 2: Register and add to `docs/index.md`.**

  In `theme/index.ts`:
  ```ts
  import HomePillars from "./components/HomePillars.vue"
  app.component("HomePillars", HomePillars)
  ```

  In `docs/index.md`, append below `<HomeStopWriting />`:
  ```markdown
  <HomePillars />
  ```

- [ ] **Step 3: Visually verify** with `yarn docs:dev`.

- [ ] **Step 4: Commit.**

  ```bash
  git add docs/.vitepress/theme/components/HomePillars.vue docs/.vitepress/theme/index.ts docs/index.md
  git commit -m "feat(docs): home section 2 — four pillars"
  ```

---

## Task 4: HomeWalkthrough component (Section 3) — placeholders

**Goal:** Build the layout for the walkthrough section: wide hero shot up top, then a 3-column strip of asciinema + index + form. Use placeholder boxes — actual assets get wired in by Task 10.

**Files:**
- Create: `docs/.vitepress/theme/components/HomeWalkthrough.vue`
- Modify: `docs/.vitepress/theme/index.ts` (register)
- Modify: `docs/index.md`

**Acceptance Criteria:**
- [ ] Section title: "Two commands. A whole portal."
- [ ] Wide placeholder ribbon at top labeled "[ Wide portal screenshot — `home-portal.png` pending ]".
- [ ] Below: three equal columns — asciinema placeholder, index placeholder, form placeholder — each labeled with the eventual asset filename.
- [ ] Each placeholder has fixed aspect ratio so layout doesn't shift when assets land.

**Verify:** `yarn docs:dev` → section renders with all four placeholder slots labeled with their asset filenames.

**Steps:**

- [ ] **Step 1: Create the component.**

  ```vue
  <template>
    <section class="pu-section">
      <div class="pu-section-inner">
        <div class="pu-eyebrow">A real example</div>
        <h2 class="pu-section-title">Two commands. A whole portal.</h2>

        <div class="hw-hero-shot">
          <div class="hw-browser-bar"><span></span><span></span><span></span><code>localhost:3000/admin</code></div>
          <div class="hw-placeholder hw-placeholder--portal">
            [ Wide portal screenshot — <code>home-portal.png</code> pending ]
          </div>
        </div>

        <div class="hw-strip">
          <div>
            <div class="hw-label">1 — You run</div>
            <div class="hw-placeholder hw-placeholder--term">
              [ Asciinema — <code>home-scaffold.cast</code> pending ]
            </div>
          </div>
          <div>
            <div class="hw-label">2 — Plutonium serves</div>
            <div class="hw-browser hw-browser--small">
              <div class="hw-browser-bar"><span></span><span></span><code>/admin/posts</code></div>
              <div class="hw-placeholder">[ <code>home-index.png</code> pending ]</div>
            </div>
          </div>
          <div>
            <div class="hw-label">3 — Forms, free</div>
            <div class="hw-browser hw-browser--small">
              <div class="hw-browser-bar"><span></span><span></span><code>/admin/posts/new</code></div>
              <div class="hw-placeholder">[ <code>home-form.png</code> pending ]</div>
            </div>
          </div>
        </div>
      </div>
    </section>
  </template>

  <style scoped>
  .hw-hero-shot {
    border: 1px solid var(--pu-border); border-radius: 10px; overflow: hidden;
    background: var(--pu-bg-light); margin-bottom: 18px;
  }
  .hw-browser-bar {
    background: var(--pu-bg-band); padding: 8px 12px; display: flex; align-items: center; gap: 5px;
    border-bottom: 1px solid var(--pu-border-soft);
  }
  .hw-browser-bar span {
    width: 10px; height: 10px; border-radius: 50%; background: var(--pu-border);
  }
  .hw-browser-bar code {
    margin-left: 12px; background: var(--pu-bg-light); padding: 3px 8px; border-radius: 4px;
    font-size: 11px; color: var(--pu-text-faint);
  }
  .hw-placeholder {
    aspect-ratio: 16/9;
    display: flex; align-items: center; justify-content: center;
    background: linear-gradient(135deg, var(--pu-bg-band), #f0f0f0);
    color: var(--pu-text-faint); font-size: 13px; font-family: ui-monospace, monospace;
  }
  .hw-placeholder--portal { aspect-ratio: 21/8; }
  .hw-placeholder--term { aspect-ratio: 4/3; background: linear-gradient(135deg, #1a1f29, #0d1117); color: #6e7681; }
  .hw-strip { display: grid; grid-template-columns: 1.1fr 1fr 1fr; gap: 16px; align-items: stretch; }
  .hw-label { font-size: 11px; text-transform: uppercase; letter-spacing: 0.08em; color: var(--pu-text-faint); margin-bottom: 8px; }
  .hw-browser--small { border: 1px solid var(--pu-border-soft); border-radius: 8px; overflow: hidden; }
  .hw-browser--small .hw-browser-bar { padding: 5px 8px; }
  .hw-browser--small .hw-browser-bar span { width: 8px; height: 8px; }
  .hw-browser--small .hw-browser-bar code { margin-left: 6px; font-size: 10px; }
  @media (max-width: 768px) { .hw-strip { grid-template-columns: 1fr; } }
  </style>
  ```

- [ ] **Step 2: Register and add to `docs/index.md`.**

  ```ts
  // theme/index.ts
  import HomeWalkthrough from "./components/HomeWalkthrough.vue"
  app.component("HomeWalkthrough", HomeWalkthrough)
  ```

  ```markdown
  <!-- docs/index.md, below HomePillars -->
  <HomeWalkthrough />
  ```

- [ ] **Step 3: Visually verify** layout reserves space for assets without shifting.

- [ ] **Step 4: Commit.**

  ```bash
  git add docs/.vitepress/theme/components/HomeWalkthrough.vue docs/.vitepress/theme/index.ts docs/index.md
  git commit -m "feat(docs): home section 3 — walkthrough layout (asset placeholders)"
  ```

---

## Task 5: HomeAudienceSplit component (Section 4)

**Goal:** Render the side-by-side audience split with the locked headlines.

**Files:**
- Create: `docs/.vitepress/theme/components/HomeAudienceSplit.vue`
- Modify: `docs/.vitepress/theme/index.ts` (register)
- Modify: `docs/index.md`

**Acceptance Criteria:**
- [ ] Section title: "Plutonium fits two kinds of teams."
- [ ] Two equal columns separated by a thin divider.
- [ ] Left lede verbatim: "The missing layer between Rails and the apps you keep building."
- [ ] Right lede verbatim: "Skip the SaaS template debate. Plutonium turns Rails into a SaaS toolkit."
- [ ] Each column has 4 bullet items per spec, with the red `→` glyph.

**Verify:** `yarn docs:dev` → home page → section renders with two columns, divider visible, copy matches spec verbatim.

**Steps:**

- [ ] **Step 1: Create the component.**

  ```vue
  <template>
    <section class="pu-section pu-section--band">
      <div class="pu-section-inner">
        <div class="pu-eyebrow pu-eyebrow--muted">For two audiences</div>
        <h2 class="pu-section-title">Plutonium fits two kinds of teams.</h2>
        <div class="ha-grid">
          <div class="ha-col">
            <div class="ha-head">For Rails developers</div>
            <p class="ha-lede">The missing layer between Rails and the apps you keep building.</p>
            <ul class="ha-list">
              <li><span class="ha-arr">→</span> Convention extended to CRUD, policies, and portals</li>
              <li><span class="ha-arr">→</span> Generated code lives in your repo — edit anything</li>
              <li><span class="ha-arr">→</span> Mountable Rails engines for packages and portals</li>
              <li><span class="ha-arr">→</span> ActionPolicy authorization, baked in</li>
            </ul>
          </div>
          <div class="ha-col ha-col--right">
            <div class="ha-head">For founders &amp; teams</div>
            <p class="ha-lede">Skip the SaaS template debate. Plutonium turns Rails into a SaaS toolkit.</p>
            <ul class="ha-list">
              <li><span class="ha-arr">→</span> Admin panel, signup, and invites on day one</li>
              <li><span class="ha-arr">→</span> Multi-tenant scoping when you need it</li>
              <li><span class="ha-arr">→</span> No template lock-in — it's just your Rails app</li>
              <li><span class="ha-arr">→</span> Ship faster with AI tools that understand your code</li>
            </ul>
          </div>
        </div>
      </div>
    </section>
  </template>

  <style scoped>
  .ha-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 32px; }
  .ha-col--right { border-left: 1px solid var(--pu-border); padding-left: 32px; }
  .ha-head {
    font-size: 11px; text-transform: uppercase; letter-spacing: 0.1em;
    color: var(--pu-accent); font-weight: 600; margin-bottom: 8px;
  }
  .ha-lede {
    font-size: 17px; line-height: 1.35; font-weight: 500; color: var(--pu-text);
    margin: 0 0 14px; letter-spacing: -0.01em;
  }
  .ha-list { list-style: none; padding: 0; margin: 0; font-size: 14px; line-height: 1.85; color: var(--pu-text-muted); }
  .ha-list li { display: flex; gap: 8px; align-items: flex-start; }
  .ha-arr { color: var(--pu-accent); font-weight: 700; flex-shrink: 0; }
  @media (max-width: 768px) {
    .ha-grid { grid-template-columns: 1fr; }
    .ha-col--right { border-left: none; padding-left: 0; border-top: 1px solid var(--pu-border); padding-top: 24px; }
  }
  </style>
  ```

- [ ] **Step 2: Register and add to `docs/index.md`.**

  ```ts
  import HomeAudienceSplit from "./components/HomeAudienceSplit.vue"
  app.component("HomeAudienceSplit", HomeAudienceSplit)
  ```

  ```markdown
  <HomeAudienceSplit />
  ```

- [ ] **Step 3: Visually verify.**

- [ ] **Step 4: Commit.**

  ```bash
  git add docs/.vitepress/theme/components/HomeAudienceSplit.vue docs/.vitepress/theme/index.ts docs/index.md
  git commit -m "feat(docs): home section 4 — audience split"
  ```

---

## Task 6: HomeInTheBox component (Section 5)

**Goal:** Render Section 5 — categorized "in the box" — three category rows, each with a 3-column grid of capabilities.

**Files:**
- Create: `docs/.vitepress/theme/components/HomeInTheBox.vue`
- Modify: `docs/.vitepress/theme/index.ts` (register)
- Modify: `docs/index.md`

**Acceptance Criteria:**
- [ ] Section title: "Organized the way you'll use it."
- [ ] Three category headers in red uppercase: Resources / App structure / People & access.
- [ ] Each row has 3 cells with bold name + one-line description, per spec.

**Verify:** `yarn docs:dev` → section renders 3 rows × 3 cells, category headers in red.

**Steps:**

- [ ] **Step 1: Create the component.**

  ```vue
  <template>
    <section class="pu-section">
      <div class="pu-section-inner">
        <div class="pu-eyebrow pu-eyebrow--muted">What's in the box</div>
        <h2 class="pu-section-title">Organized the way you'll use it.</h2>
        <div v-for="cat in cats" :key="cat.name" class="hb-cat">
          <div class="hb-cat-name">{{ cat.name }}</div>
          <div class="hb-row">
            <div v-for="item in cat.items" :key="item.name" class="hb-item">
              <b>{{ item.name }}</b>
              <small>{{ item.desc }}</small>
            </div>
          </div>
        </div>
      </div>
    </section>
  </template>

  <script setup>
  const cats = [
    { name: "Resources", items: [
      { name: "Scaffolds", desc: "Model, definition, policy, routes" },
      { name: "Search & filters", desc: "Declarative on the definition" },
      { name: "Custom & bulk actions", desc: "Resource-scoped interactions" },
    ]},
    { name: "App structure", items: [
      { name: "Portals", desc: "Themed, mountable engines" },
      { name: "Packages", desc: "Feature engines under your app" },
      { name: "Multi-tenancy", desc: "Path or domain scoping" },
    ]},
    { name: "People & access", items: [
      { name: "Auth (Rodauth)", desc: "Login, signup, password reset" },
      { name: "Authorization", desc: "ActionPolicy per resource" },
      { name: "Invites & memberships", desc: "Token lifecycle, mailers, onboarding" },
    ]},
  ]
  </script>

  <style scoped>
  .hb-cat { margin-bottom: 28px; }
  .hb-cat:last-child { margin-bottom: 0; }
  .hb-cat-name {
    font-size: 11px; text-transform: uppercase; letter-spacing: 0.1em;
    color: var(--pu-accent); font-weight: 600; margin-bottom: 12px;
  }
  .hb-row { display: grid; grid-template-columns: repeat(3, 1fr); gap: 14px; }
  .hb-item { font-size: 13px; color: var(--pu-text-muted); }
  .hb-item b { display: block; color: var(--pu-text); font-weight: 600; margin-bottom: 2px; font-size: 14px; }
  .hb-item small { font-size: 12px; color: var(--pu-text-faint); }
  @media (max-width: 768px) { .hb-row { grid-template-columns: 1fr; } }
  </style>
  ```

- [ ] **Step 2: Register and add to `docs/index.md`.**

  ```ts
  import HomeInTheBox from "./components/HomeInTheBox.vue"
  app.component("HomeInTheBox", HomeInTheBox)
  ```

  ```markdown
  <HomeInTheBox />
  ```

- [ ] **Step 3: Visually verify.**

- [ ] **Step 4: Commit.**

  ```bash
  git add docs/.vitepress/theme/components/HomeInTheBox.vue docs/.vitepress/theme/index.ts docs/index.md
  git commit -m "feat(docs): home section 5 — what's in the box"
  ```

---

## Task 7: HomeCta component (Section 6) with template-toggle pills

**Goal:** Render the manifesto CTA with reactive Vue toggle pills swapping between `plutonium.rb` and `pluton8.rb` install commands.

**Files:**
- Create: `docs/.vitepress/theme/components/HomeCta.vue`
- Modify: `docs/.vitepress/theme/index.ts` (register)
- Modify: `docs/index.md`

**Acceptance Criteria:**
- [ ] Centered manifesto block on a subtle gradient.
- [ ] Manifesto line: *"Stop writing the parts of every Rails app you've already written. Plutonium is what should have been there all along."*
- [ ] Pill toggle with two options: `plutonium` (core + portals) and `pluton8` (+ SaaS lite stack). `plutonium` selected by default.
- [ ] Install command line updates reactively when the user clicks a pill.
- [ ] Both URLs are correct:
  - `https://radioactive-labs.github.io/plutonium-core/templates/plutonium.rb`
  - `https://radioactive-labs.github.io/plutonium-core/templates/pluton8.rb`
- [ ] Primary CTA "Get started →" → `/getting-started/`; ghost "GitHub" → `https://github.com/radioactive-labs/plutonium-core`.

**Verify:** `yarn docs:dev` → home page → click each pill → command updates without page reload.

**Steps:**

- [ ] **Step 1: Create the component with reactive state.**

  ```vue
  <template>
    <section class="pu-section pu-section--band hc-section">
      <div class="hc-inner">
        <p class="hc-quote">
          “Stop writing the parts of every Rails app you've already written.
          Plutonium is what should have been there all along.”
        </p>

        <div class="hc-pills" role="tablist">
          <button
            v-for="opt in options"
            :key="opt.id"
            :class="['hc-pill', { 'hc-pill--active': selected === opt.id }]"
            role="tab"
            :aria-selected="selected === opt.id"
            @click="selected = opt.id"
          >
            <span class="hc-pill-name">{{ opt.name }}</span>
            <small class="hc-pill-sub">{{ opt.sub }}</small>
          </button>
        </div>

        <pre class="pu-term hc-term"><span class="prompt">$</span> rails new my_app -m {{ activeUrl }}<span class="pu-term-cursor"></span></pre>

        <div class="hc-ctas">
          <a class="pu-btn pu-btn-primary" href="/plutonium-core/getting-started/">Get started →</a>
          <a class="pu-btn pu-btn-ghost" href="https://github.com/radioactive-labs/plutonium-core" target="_blank" rel="noopener">GitHub</a>
        </div>
      </div>
    </section>
  </template>

  <script setup>
  import { ref, computed } from "vue"

  const options = [
    { id: "plutonium", name: "plutonium", sub: "core + portals",
      url: "https://radioactive-labs.github.io/plutonium-core/templates/plutonium.rb" },
    { id: "pluton8", name: "pluton8", sub: "+ SaaS lite stack",
      url: "https://radioactive-labs.github.io/plutonium-core/templates/pluton8.rb" },
  ]
  const selected = ref("plutonium")
  const activeUrl = computed(() => options.find(o => o.id === selected.value).url)
  </script>

  <style scoped>
  .hc-section { padding: 96px 24px; }
  .hc-inner {
    max-width: 760px; margin: 0 auto; text-align: center;
    background: linear-gradient(180deg, var(--pu-bg-band), var(--pu-bg-light));
    border: 1px solid var(--pu-border); border-radius: 12px; padding: 56px 32px;
  }
  .hc-quote {
    font-size: 28px; letter-spacing: -0.02em; line-height: 1.25;
    color: var(--pu-text); font-weight: 500;
    margin: 0 auto 28px; max-width: 600px;
  }
  .hc-pills {
    display: inline-flex; background: rgba(0,0,0,0.05); border-radius: 999px;
    padding: 4px; gap: 2px; margin-bottom: 14px;
  }
  .hc-pill {
    background: transparent; border: 0; padding: 8px 16px; border-radius: 999px;
    font-size: 12.5px; color: var(--pu-text-muted); cursor: pointer;
    display: flex; flex-direction: column; align-items: center; line-height: 1.1;
  }
  .hc-pill-sub { font-size: 9.5px; text-transform: uppercase; letter-spacing: 0.08em; color: var(--pu-text-faint); margin-top: 2px; }
  .hc-pill--active {
    background: var(--pu-bg-light); color: var(--pu-text); font-weight: 600;
    box-shadow: 0 1px 3px rgba(0,0,0,0.1);
  }
  .hc-term { max-width: 640px; margin: 0 auto 24px; text-align: left; white-space: pre-wrap; word-break: break-all; }
  .hc-ctas { display: flex; gap: 10px; justify-content: center; flex-wrap: wrap; }
  @media (max-width: 600px) { .hc-quote { font-size: 22px; } }
  </style>
  ```

- [ ] **Step 2: Register and add to `docs/index.md` as the final block.**

  ```ts
  import HomeCta from "./components/HomeCta.vue"
  app.component("HomeCta", HomeCta)
  ```

  ```markdown
  <HomeCta />
  ```

- [ ] **Step 3: Visually verify both pill states.** Click `pluton8` → command should change to the pluton8 URL. Click back → reverts.

- [ ] **Step 4: Commit.**

  ```bash
  git add docs/.vitepress/theme/components/HomeCta.vue docs/.vitepress/theme/index.ts docs/index.md
  git commit -m "feat(docs): home section 6 — manifesto CTA with template pills"
  ```

---

## Task 8: SectionLanding shared component

**Goal:** Build a shared Vue component that renders the spec's Pattern B layout (eyebrow + h1 + lede + numbered/categorized rail + sidebar). The three section landings will use this component with different props.

**Files:**
- Create: `docs/.vitepress/theme/components/SectionLanding.vue`
- Modify: `docs/.vitepress/theme/index.ts` (register)

**Acceptance Criteria:**
- [ ] Component accepts props: `eyebrow` (string), `title` (string), `lede` (string), `rail` (array of either step objects `{name, desc}` for numbered mode OR group objects `{group, items: [{name, desc, link}]}` for categorized mode), `mode` ("numbered" | "categorized"), `sidebar` (array of `{heading, items: [{label, href, note?}]}`).
- [ ] Renders left rail with red vertical bar; numbered mode shows red circle badges with step numbers; categorized mode shows category headers between groups.
- [ ] Right sidebar renders heading groups with anchor links.
- [ ] Each rail item with a `link` prop is clickable.
- [ ] Collapses to single column < 768px (sidebar moves below rail).

**Verify:** Smoke-test by temporarily mounting it in a scratch markdown file with sample props; confirm both `numbered` and `categorized` modes render correctly.

**Steps:**

- [ ] **Step 1: Create the component.**

  ```vue
  <template>
    <section class="pu-section sl-section">
      <div class="pu-section-inner">
        <div class="pu-eyebrow">{{ eyebrow }}</div>
        <h1 class="sl-h1">{{ title }}</h1>
        <p class="sl-lede">{{ lede }}</p>

        <div class="sl-grid">
          <div class="sl-rail">
            <template v-if="mode === 'numbered'">
              <a
                v-for="(step, i) in rail"
                :key="i"
                :href="step.link"
                :class="['sl-step', { 'sl-step--link': step.link }]"
              >
                <span class="sl-num">{{ i + 1 }}</span>
                <span class="sl-step-body">
                  <span class="sl-step-name">{{ step.name }}</span>
                  <span v-if="step.desc" class="sl-step-desc">{{ step.desc }}</span>
                </span>
              </a>
            </template>
            <template v-else>
              <div v-for="grp in rail" :key="grp.group" class="sl-group">
                <div class="sl-group-name">{{ grp.group }}</div>
                <a
                  v-for="item in grp.items"
                  :key="item.name"
                  :href="item.link"
                  class="sl-step sl-step--link"
                >
                  <span class="sl-step-body">
                    <span class="sl-step-name">{{ item.name }}</span>
                    <span v-if="item.desc" class="sl-step-desc">{{ item.desc }}</span>
                  </span>
                </a>
              </div>
            </template>
          </div>

          <aside class="sl-aside">
            <div v-for="block in sidebar" :key="block.heading" class="sl-aside-block">
              <h4 class="sl-aside-heading">{{ block.heading }}</h4>
              <ul>
                <li v-for="item in block.items" :key="item.label">
                  <a :href="item.href">{{ item.label }}</a>
                  <span v-if="item.note" class="sl-aside-note"> — {{ item.note }}</span>
                </li>
              </ul>
            </div>
          </aside>
        </div>
      </div>
    </section>
  </template>

  <script setup>
  defineProps({
    eyebrow: { type: String, required: true },
    title: { type: String, required: true },
    lede: { type: String, required: true },
    rail: { type: Array, required: true },
    mode: { type: String, default: "numbered", validator: v => ["numbered", "categorized"].includes(v) },
    sidebar: { type: Array, default: () => [] },
  })
  </script>

  <style scoped>
  .sl-section { padding: 64px 24px 96px; }
  .sl-h1 { font-size: 36px; letter-spacing: -0.025em; margin: 0 0 12px; color: var(--pu-text); }
  .sl-lede { font-size: 16px; color: var(--pu-text-muted); max-width: 640px; margin: 0 0 40px; line-height: 1.55; }
  .sl-grid { display: grid; grid-template-columns: 1.4fr 1fr; gap: 48px; }
  .sl-rail { border-left: 2px solid var(--pu-accent); padding-left: 24px; }
  .sl-group + .sl-group { margin-top: 22px; }
  .sl-group-name {
    font-size: 11px; text-transform: uppercase; letter-spacing: 0.1em;
    color: var(--pu-accent); font-weight: 600; margin-bottom: 8px;
  }
  .sl-step {
    display: flex; gap: 12px; align-items: flex-start;
    padding: 12px 0; border-bottom: 1px solid var(--pu-border-soft);
    color: var(--pu-text); text-decoration: none;
  }
  .sl-step:last-child { border-bottom: none; }
  .sl-step--link:hover .sl-step-name { color: var(--pu-accent); }
  .sl-num {
    flex-shrink: 0; width: 24px; height: 24px; line-height: 24px; text-align: center;
    background: var(--pu-accent); color: #fff; border-radius: 50%;
    font-size: 11px; font-weight: 600;
  }
  .sl-step-body { display: flex; flex-direction: column; gap: 2px; }
  .sl-step-name { font-weight: 600; font-size: 14px; }
  .sl-step-desc { font-size: 12.5px; color: var(--pu-text-muted); }

  .sl-aside-block + .sl-aside-block { margin-top: 28px; }
  .sl-aside-heading {
    font-size: 11px; text-transform: uppercase; letter-spacing: 0.1em;
    color: var(--pu-text-faint); margin: 0 0 10px; font-weight: 600;
  }
  .sl-aside ul { list-style: none; padding: 0; margin: 0; font-size: 14px; line-height: 1.85; }
  .sl-aside a { color: var(--pu-accent); text-decoration: none; font-weight: 500; }
  .sl-aside a:hover { text-decoration: underline; }
  .sl-aside-note { color: var(--pu-text-muted); font-weight: 400; }

  @media (max-width: 900px) {
    .sl-grid { grid-template-columns: 1fr; gap: 32px; }
  }
  </style>
  ```

- [ ] **Step 2: Register globally** in `docs/.vitepress/theme/index.ts`:

  ```ts
  import SectionLanding from "./components/SectionLanding.vue"
  app.component("SectionLanding", SectionLanding)
  ```

- [ ] **Step 3: Smoke-test.** Temporarily add a `<SectionLanding>` to a scratch file (or directly try in `docs/index.md` at the bottom) with both `mode="numbered"` and `mode="categorized"` to confirm both branches render. Remove the scratch usage after confirming.

- [ ] **Step 4: Commit.**

  ```bash
  git add docs/.vitepress/theme/components/SectionLanding.vue docs/.vitepress/theme/index.ts
  git commit -m "feat(docs): SectionLanding shared component"
  ```

---

## Task 9: Getting Started landing page

**Goal:** Rewrite `docs/getting-started/index.md` using `<SectionLanding>` in numbered mode for the 8 tutorial chapters.

**Files:**
- Modify (rewrite): `docs/getting-started/index.md`

**Acceptance Criteria:**
- [ ] Page uses `<SectionLanding>` with `mode="numbered"`.
- [ ] Eyebrow: "GETTING STARTED". H1: "Get a working Plutonium app in 15 minutes."
- [ ] Lede: "Walk the path top to bottom, or skip to the part you need."
- [ ] 8 numbered steps mirror the existing tutorial sidebar (Project Setup → Customizing UI), each linking to its tutorial page.
- [ ] Sidebar has two blocks: "Already know your way around?" (Installation, Concepts, Generators reference) and "Need help?" (Discussions, Issues).
- [ ] Existing prerequisites/installation/template content is NOT lost — preserve it elsewhere if not surfaced here. Move "Prerequisites" section from the old page to the bottom of `docs/getting-started/installation.md` if it isn't already there, or to a `Prerequisites` section above the rail in this page.

**Verify:** `yarn docs:dev` → `/getting-started/` → page renders, all 8 step links work, sidebar links work.

**Steps:**

- [ ] **Step 1: Read the current page** to capture all content (already done in plan-prep), and check `docs/getting-started/installation.md` to see if Prerequisites already lives there.

  ```bash
  cat docs/getting-started/installation.md | head -40
  ```

  If Prerequisites is missing from installation.md, append it.

- [ ] **Step 2: Rewrite `docs/getting-started/index.md`.**

  ```markdown
  ---
  layout: page
  sidebar: false
  aside: false
  ---

  <SectionLanding
    eyebrow="Getting Started"
    title="Get a working Plutonium app in 15 minutes."
    lede="Walk the path top to bottom, or skip to the part you need."
    mode="numbered"
    :rail="[
      { name: 'Project setup', desc: 'Bootstrap a Rails app with the Plutonium template.', link: '/plutonium-core/getting-started/tutorial/01-setup' },
      { name: 'First resource', desc: 'Model, definition, scaffold, connect to a portal.', link: '/plutonium-core/getting-started/tutorial/02-first-resource' },
      { name: 'Authentication', desc: 'Add Rodauth with login + signup.', link: '/plutonium-core/getting-started/tutorial/03-authentication' },
      { name: 'Authorization', desc: 'ActionPolicy-scoped resource access.', link: '/plutonium-core/getting-started/tutorial/04-authorization' },
      { name: 'Custom actions', desc: 'Add a domain-specific action to a resource.', link: '/plutonium-core/getting-started/tutorial/05-custom-actions' },
      { name: 'Nested resources', desc: 'Posts → Comments, scoped through routing.', link: '/plutonium-core/getting-started/tutorial/06-nested-resources' },
      { name: 'Author portal', desc: 'A second portal with its own auth and pages.', link: '/plutonium-core/getting-started/tutorial/07-author-portal' },
      { name: 'Customizing UI', desc: 'Theme tokens, custom Phlex components, layouts.', link: '/plutonium-core/getting-started/tutorial/08-customizing-ui' },
    ]"
    :sidebar="[
      { heading: 'Already know your way around?', items: [
        { label: 'Installation', href: '/plutonium-core/getting-started/installation', note: 'bootstrap a new app' },
        { label: 'Concepts overview', href: '/plutonium-core/reference/' },
        { label: 'Generators reference', href: '/plutonium-core/reference/app/generators' },
      ]},
      { heading: 'Need help?', items: [
        { label: 'GitHub Discussions', href: 'https://github.com/radioactive-labs/plutonium-core/discussions' },
        { label: 'Open an issue', href: 'https://github.com/radioactive-labs/plutonium-core/issues' },
      ]},
    ]"
  />
  ```

- [ ] **Step 3: Visually verify.** Click each step link; confirm it routes to the tutorial pages.

- [ ] **Step 4: Commit.**

  ```bash
  git add docs/getting-started/index.md docs/getting-started/installation.md
  git commit -m "feat(docs): getting started landing — Pattern B"
  ```

---

## Task 10: Guides landing page

**Goal:** Rewrite `docs/guides/index.md` using `<SectionLanding>` in categorized mode.

**Files:**
- Modify (rewrite): `docs/guides/index.md`

**Acceptance Criteria:**
- [ ] Page uses `<SectionLanding>` with `mode="categorized"`.
- [ ] Eyebrow: "GUIDES". H1: "How to do the things Plutonium apps do."
- [ ] Lede: "Task-oriented walkthroughs for the parts of the framework you reach for most."
- [ ] Categories: Setup & Resources, Auth, Features, Customization, Quality. Each category lists existing guide links from current `docs/guides/index.md`.
- [ ] Sidebar: "New to Plutonium?" (tutorial link), "Looking for APIs?" (reference link), "Need help?" (Discussions).
- [ ] Existing "I want to..." quick-task table is preserved — move it below the `<SectionLanding>` block, or drop it (the rail itself fulfils the same orientation purpose). Preserve it for now to avoid losing scannability.

**Verify:** `yarn docs:dev` → `/guides/` → categorized list renders, all guide links work.

**Steps:**

- [ ] **Step 1: Rewrite `docs/guides/index.md`.**

  ```markdown
  ---
  layout: page
  sidebar: false
  aside: false
  ---

  <SectionLanding
    eyebrow="Guides"
    title="How to do the things Plutonium apps do."
    lede="Task-oriented walkthroughs for the parts of the framework you reach for most."
    mode="categorized"
    :rail="[
      { group: 'Setup & Resources', items: [
        { name: 'Adding resources', link: '/plutonium-core/guides/adding-resources' },
        { name: 'Creating packages', link: '/plutonium-core/guides/creating-packages' },
      ]},
      { group: 'Auth', items: [
        { name: 'Authentication', link: '/plutonium-core/guides/authentication' },
        { name: 'Authorization', link: '/plutonium-core/guides/authorization' },
      ]},
      { group: 'Features', items: [
        { name: 'Custom actions', link: '/plutonium-core/guides/custom-actions' },
        { name: 'Nested resources', link: '/plutonium-core/guides/nested-resources' },
        { name: 'Multi-tenancy', link: '/plutonium-core/guides/multi-tenancy' },
        { name: 'Search & filtering', link: '/plutonium-core/guides/search-filtering' },
        { name: 'User invites', link: '/plutonium-core/guides/user-invites' },
      ]},
      { group: 'Customization', items: [
        { name: 'Theming', link: '/plutonium-core/guides/theming' },
      ]},
      { group: 'Quality', items: [
        { name: 'Testing', link: '/plutonium-core/guides/testing' },
      ]},
    ]"
    :sidebar="[
      { heading: 'New to Plutonium?', items: [
        { label: 'Start with the tutorial', href: '/plutonium-core/getting-started/tutorial/' },
      ]},
      { heading: 'Looking for APIs?', items: [
        { label: 'Browse the reference', href: '/plutonium-core/reference/' },
      ]},
      { heading: 'Need help?', items: [
        { label: 'GitHub Discussions', href: 'https://github.com/radioactive-labs/plutonium-core/discussions' },
      ]},
    ]"
  />
  ```

- [ ] **Step 2: Visually verify.** Click each guide link.

- [ ] **Step 3: Commit.**

  ```bash
  git add docs/guides/index.md
  git commit -m "feat(docs): guides landing — Pattern B"
  ```

---

## Task 11: Reference landing page

**Goal:** Rewrite `docs/reference/index.md` using `<SectionLanding>` in categorized mode.

**Files:**
- Modify (rewrite): `docs/reference/index.md`

**Acceptance Criteria:**
- [ ] Page uses `<SectionLanding>` with `mode="categorized"`.
- [ ] Eyebrow: "REFERENCE". H1: "Every API, in one place." Lede per spec.
- [ ] Categories per spec: App / Resource / UI / Tooling — but using the actual reference structure already in the codebase. Verify against `docs/.vitepress/config.ts` reference sidebar.
- [ ] Sidebar: "Learning?" (Tutorial, Concepts), "Solving a problem?" (Guides), "Need help?" (Discussions).

**Verify:** `yarn docs:dev` → `/reference/` → categorized list renders, all links resolve.

**Steps:**

- [ ] **Step 1: Inspect the reference sidebar config** to use the actual categories that exist:

  ```bash
  grep -A 200 "'/reference/'" docs/.vitepress/config.ts | head -250
  ```

  Match the categories in the new landing to the actual sidebar structure (App, Resource, Behavior, UI, Auth, Tenancy, Testing — note the spec mentions four but the existing sidebar has seven; use the seven actual ones since they're the real navigational structure).

- [ ] **Step 2: Rewrite `docs/reference/index.md`.**

  ```markdown
  ---
  layout: page
  sidebar: false
  aside: false
  ---

  <SectionLanding
    eyebrow="Reference"
    title="Every API, in one place."
    lede="The full surface area of Plutonium — controllers, policies, definitions, fields, interactions, generators."
    mode="categorized"
    :rail="[
      { group: 'App', items: [
        { name: 'Overview', link: '/plutonium-core/reference/app/' },
        { name: 'Packages', link: '/plutonium-core/reference/app/packages' },
        { name: 'Portals', link: '/plutonium-core/reference/app/portals' },
        { name: 'Generators', link: '/plutonium-core/reference/app/generators' },
      ]},
      { group: 'Resource', items: [
        { name: 'Definition', link: '/plutonium-core/reference/resource/definition' },
        { name: 'Query', link: '/plutonium-core/reference/resource/query' },
        { name: 'Actions', link: '/plutonium-core/reference/resource/actions' },
      ]},
      { group: 'Behavior', items: [
        { name: 'Controllers', link: '/plutonium-core/reference/behavior/controllers' },
        { name: 'Policies', link: '/plutonium-core/reference/behavior/policies' },
        { name: 'Interactions', link: '/plutonium-core/reference/behavior/interactions' },
      ]},
      { group: 'UI', items: [
        { name: 'Pages', link: '/plutonium-core/reference/ui/pages' },
        { name: 'Forms', link: '/plutonium-core/reference/ui/forms' },
        { name: 'Tables & displays', link: '/plutonium-core/reference/ui/tables' },
        { name: 'Assets & theming', link: '/plutonium-core/reference/ui/assets' },
      ]},
      { group: 'Auth', items: [
        { name: 'Accounts', link: '/plutonium-core/reference/auth/accounts' },
        { name: 'Profile', link: '/plutonium-core/reference/auth/profile' },
      ]},
      { group: 'Tenancy', items: [
        { name: 'Entity scoping', link: '/plutonium-core/reference/tenancy/entity-scoping' },
        { name: 'Invites', link: '/plutonium-core/reference/tenancy/invites' },
      ]},
      { group: 'Testing', items: [
        { name: 'Testing helpers', link: '/plutonium-core/reference/testing/' },
      ]},
    ]"
    :sidebar="[
      { heading: 'Learning?', items: [
        { label: 'Tutorial', href: '/plutonium-core/getting-started/tutorial/' },
      ]},
      { heading: 'Solving a problem?', items: [
        { label: 'Guides', href: '/plutonium-core/guides/' },
      ]},
      { heading: 'Need help?', items: [
        { label: 'GitHub Discussions', href: 'https://github.com/radioactive-labs/plutonium-core/discussions' },
      ]},
    ]"
  />
  ```

  **IMPORTANT:** verify each `link:` resolves against the actual `docs/.vitepress/config.ts` reference sidebar. If a link in the example above (e.g., `tables-displays`) doesn't match the real path, fix it before committing. Don't link to nonexistent pages.

- [ ] **Step 3: Visually verify.** Click each link, confirm no 404s.

- [ ] **Step 4: Commit.**

  ```bash
  git add docs/reference/index.md
  git commit -m "feat(docs): reference landing — Pattern B"
  ```

---

## Task 12: Demo app, asciinema recording, screenshots

**Goal:** Produce the three screenshots and one asciinema recording referenced by `HomeWalkthrough`.

**Files:**
- Create: `docs/public/images/home-portal.png`
- Create: `docs/public/images/home-index.png`
- Create: `docs/public/images/home-form.png`
- Create: `docs/public/asciinema/home-scaffold.cast`

**Acceptance Criteria:**
- [ ] All four asset files exist at the paths above.
- [ ] Screenshots are PNG, captured at 1280×800, light mode, with seeded data: at least 3 posts including a draft.
- [ ] Asciinema cast covers the scaffold sequence: `rails new` (skipped or trimmed) → `pu:res:scaffold Post` → `pu:res:scaffold Comment` → `pu:res:conn` → `rails s`.
- [ ] Cast trims to roughly 30 seconds of useful output (use `asciinema rec` then post-trim, or re-record with paced typing).

**Verify:** `ls -la docs/public/images/home-*.png docs/public/asciinema/home-scaffold.cast` → all four files present, non-empty.

**Steps:**

- [ ] **Step 1: Create a fresh demo app outside the project tree.**

  ```bash
  mkdir -p /tmp/plutonium-demo && cd /tmp/plutonium-demo
  asciinema rec /tmp/home-scaffold-raw.cast
  ```

  Inside the recording session, run:
  ```bash
  rails new blog -a propshaft -j esbuild -c tailwind \
    -m https://radioactive-labs.github.io/plutonium-core/templates/plutonium.rb
  cd blog
  rails g pu:res:scaffold Post title:string body:text published:boolean
  rails g pu:res:scaffold Comment 'post:references' body:text
  rails g pu:res:conn Post Comment --dest=admin_portal
  rails db:migrate
  ```
  Then exit the recording.

  *(Note: `rails new` is verbose. Either record only the `pu:*` commands by starting asciinema after `rails new`, or use `asciinema-trim` / a re-recorded clean version for the final asset.)*

- [ ] **Step 2: Trim the cast** to a focused ~30s sequence showing only the `pu:*` commands and `rails s`. Save to `docs/public/asciinema/home-scaffold.cast`.

  ```bash
  mkdir -p docs/public/asciinema
  cp /tmp/home-scaffold-trimmed.cast docs/public/asciinema/home-scaffold.cast
  ```

- [ ] **Step 3: Boot the demo app and seed data.**

  ```bash
  cd /tmp/plutonium-demo/blog
  rails runner '
    3.times { |i| Post.create!(title: "Hello world #{i+1}", body: "Lorem ipsum…", published: true) }
    Post.create!(title: "Draft post", body: "Consectetur…", published: false)
  '
  rails s
  ```

- [ ] **Step 4: Capture screenshots** with the macOS screenshot tool (`Cmd+Shift+4` then space → click window) at 1280×800 viewport.

  - `home-portal.png` — wide shot of the admin portal with sidebar, nav, and posts table visible.
  - `home-index.png` — focused shot of `/admin/posts` table with the 4 seeded posts.
  - `home-form.png` — focused shot of `/admin/posts/new` form.

  Save all three to `docs/public/images/`.

  ```bash
  mkdir -p docs/public/images
  # move screenshots into place
  mv ~/Desktop/home-portal.png docs/public/images/
  mv ~/Desktop/home-index.png docs/public/images/
  mv ~/Desktop/home-form.png docs/public/images/
  ```

- [ ] **Step 5: Confirm assets exist and are non-empty.**

  ```bash
  ls -la docs/public/images/home-*.png docs/public/asciinema/home-scaffold.cast
  ```

- [ ] **Step 6: Commit.**

  ```bash
  git add docs/public/images/home-portal.png docs/public/images/home-index.png docs/public/images/home-form.png docs/public/asciinema/home-scaffold.cast
  git commit -m "feat(docs): walkthrough assets — screenshots and asciinema"
  ```

---

## Task 13: Wire assets into HomeWalkthrough

**Goal:** Replace the placeholder slots in `HomeWalkthrough.vue` with the real screenshots and asciinema embed.

**Files:**
- Modify: `docs/.vitepress/theme/components/HomeWalkthrough.vue`
- Modify: `docs/.vitepress/theme/index.ts` (add asciinema-player CSS+JS injection if needed)

**Acceptance Criteria:**
- [ ] Wide portal screenshot renders in the hero ribbon.
- [ ] Index and form screenshots render in the strip.
- [ ] Asciinema cast plays in the strip via `asciinema-player`. Auto-loops, no controls overlay distracting in the small frame.
- [ ] No console errors. No layout shift compared to placeholder version.

**Verify:** `yarn docs:dev` → home page → walkthrough section shows three real screenshots and a playing asciinema clip.

**Steps:**

- [ ] **Step 1: Add asciinema-player to the page.** In `docs/.vitepress/theme/index.ts`, inject the CDN-hosted player CSS and JS once on app mount:

  ```ts
  import DefaultTheme from "vitepress/theme"
  import "./custom.css"

  // ... existing component imports ...

  export default {
    extends: DefaultTheme,
    enhanceApp({ app }) {
      // ... existing app.component(...) calls ...

      if (typeof window !== "undefined") {
        const css = document.createElement("link")
        css.rel = "stylesheet"
        css.href = "https://cdn.jsdelivr.net/npm/asciinema-player@3.7.1/dist/bundle/asciinema-player.css"
        document.head.appendChild(css)
      }
    }
  }
  ```

  The player itself will be loaded lazily inside the component (Step 2) so SSR doesn't crash.

- [ ] **Step 2: Update `HomeWalkthrough.vue`** to use real assets and lazy-load the asciinema player:

  Replace the three placeholder slots:
  - Wide portal: `<img src="/plutonium-core/images/home-portal.png" alt="Plutonium admin portal" />`
  - Index: `<img src="/plutonium-core/images/home-index.png" alt="Posts index" />`
  - Form: `<img src="/plutonium-core/images/home-form.png" alt="New post form" />`

  Replace the asciinema placeholder with a `<div ref="castEl" />` and add a `<script setup>`:

  ```vue
  <script setup>
  import { ref, onMounted } from "vue"

  const castEl = ref(null)

  onMounted(async () => {
    if (!castEl.value) return
    const mod = await import("https://cdn.jsdelivr.net/npm/asciinema-player@3.7.1/dist/bundle/asciinema-player.min.js")
    mod.create("/plutonium-core/asciinema/home-scaffold.cast", castEl.value, {
      autoPlay: true,
      loop: true,
      controls: false,
      fit: "width",
      terminalFontSize: "small",
    })
  })
  </script>
  ```

  The image slots replace `.hw-placeholder` with `<img>` styled to fit the same aspect ratios:

  ```css
  .hw-shot { width: 100%; aspect-ratio: 21/8; object-fit: cover; display: block; }
  .hw-shot--small { width: 100%; aspect-ratio: 4/3; object-fit: cover; display: block; }
  .hw-cast { aspect-ratio: 4/3; }
  ```

- [ ] **Step 3: Visually verify.** Hard-refresh; cast should auto-play and loop; screenshots should render sharply.

- [ ] **Step 4: Commit.**

  ```bash
  git add docs/.vitepress/theme/components/HomeWalkthrough.vue docs/.vitepress/theme/index.ts
  git commit -m "feat(docs): wire walkthrough assets — screenshots + asciinema"
  ```

---

## Task 14: Visual sweep + user verification

**Goal:** Catch any cross-cutting issues (broken links, dark-mode bugs, mobile layout issues) and get the user's visual sign-off on all four pages.

**Files:** None (review only).

**Acceptance Criteria:**
- [ ] All four pages render in light and dark modes.
- [ ] All internal links resolve (no 404s when clicking through).
- [ ] No console errors on any page.
- [ ] User has visually approved all four pages via AskUserQuestion.

**Verify:** `yarn docs:dev` running; manual click-through; AskUserQuestion answered.

**User Verification Required:**
Before marking this task complete, you MUST call AskUserQuestion:
```yaml
AskUserQuestion:
  question: "All four public pages are live in `yarn docs:dev`. Have you reviewed Home, Getting Started, Guides, and Reference and are they ready to ship?"
  header: "Verification"
  options:
    - label: "Approved"
      description: "Pages look right — ready to merge"
    - label: "Needs rework"
      description: "Something's off — I'll describe what to fix"
```

**If the user selects "Needs rework":** Apply the fixes they describe, then re-verify with AskUserQuestion before marking complete.

**Steps:**

- [ ] **Step 1: Run the visual sweep.**

  ```bash
  yarn docs:dev
  ```

  Click through each page, toggle dark mode, narrow the viewport to ~400px and confirm responsive breakpoints. Open DevTools and watch for console errors.

- [ ] **Step 2: Fix any issues found** in the sweep with targeted edits. Commit each fix with a focused message.

- [ ] **Step 3: Build the production bundle** to catch build-time errors that don't surface in dev:

  ```bash
  yarn docs:build
  ```

  Should complete without errors. If it errors, fix and re-run before proceeding.

- [ ] **Step 4: Call AskUserQuestion (the one in the User Verification block above).** Wait for the answer.

- [ ] **Step 5: Handle the response.**
  - If "Approved": mark this task complete.
  - If "Needs rework": apply fixes, then call AskUserQuestion again. Do not mark complete until "Approved".

```json:metadata
{"files": [], "verifyCommand": "yarn docs:build", "acceptanceCriteria": ["all 4 pages render in both modes", "no console errors", "user approved"], "requiresUserVerification": true, "userVerificationPrompt": "All four public pages are live in `yarn docs:dev`. Have you reviewed Home, Getting Started, Guides, and Reference and are they ready to ship?"}
```

---

## Self-Review Notes (inline)

- **Spec coverage:** Every section in the spec maps to a task. Hero → T1. Sec 1 → T2. Sec 2 → T3. Sec 3 → T4 (layout) + T13 (assets). Sec 4 → T5. Sec 5 → T6. Sec 6 → T7. Section landings (3) → T8 (shared) + T9, T10, T11. Assets → T12. Visual system → T0. Out-of-scope items confirmed not added.
- **Placeholders:** None — all code blocks contain actual content. Asset captures in T12 are concrete commands, not "TBD".
- **Type consistency:** `SectionLanding` props (`rail`, `mode`, `sidebar`) are used identically in T9/T10/T11. Component names (`HomeHero` etc.) match between create/register/use steps.
- **Verification scan:** YES → T14 includes a `requiresUserVerification: true` task with the standard verification block.
