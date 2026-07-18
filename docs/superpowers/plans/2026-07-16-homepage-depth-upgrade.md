# Homepage Depth & Proof Upgrade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:subagent-driven-development (recommended) or superpowers-extended-cc:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the VitePress homepage sell Plutonium's depth — a new interactive feature tour (Kanban / Wizards / Actions / Multi-tenancy) with real code + screenshots, a merged "Why Plutonium" band, and copy weaves across existing sections.

**Architecture:** Two new Vue components (`HomeFeatureTour.vue`, `HomeWhyPlutonium.vue`) in the VitePress theme, registered in `index.ts`, composed in `docs/index.md`. `HomePillars.vue` and `HomeAudienceSplit.vue` are deleted (merged into `HomeWhyPlutonium`). Three existing components get copy-only edits. Screenshots are reused from `docs/public/images/guides/` — no new assets.

**Tech Stack:** VitePress + Vue 3 SFCs (`<script setup>`), `@tabler/icons-vue`, existing `pu-*` design tokens in `custom.css`. No new dependencies.

**User Verification:** YES — the user visually signs off the finished homepage (desktop + mobile) before the work is called done (Task 4).

**Spec:** `docs/superpowers/specs/2026-07-16-homepage-depth-upgrade-design.md`

---

## Context for the implementer

- Site source lives in `docs/`. Homepage is `docs/index.md`, which just stacks globally-registered components. Components live in `docs/.vitepress/theme/components/`, registered in `docs/.vitepress/theme/index.ts`.
- Design tokens (`--pu-accent: #d33`, `--pu-bg-dark`, `--pu-section*` classes, `.pu-term`) are in `docs/.vitepress/theme/custom.css` (~line 420+). Dark mode works by `.dark` overriding the `--pu-*` vars — always use the vars, never hardcode light-mode colors (hardcoding the dark terminal palette `#161b22`/`#30363d` is fine; it's constant in both modes, see `hw-browser-bar--term` in `HomeWalkthrough.vue`).
- Images are referenced with `withBase("/images/...")` (see `HomeWalkthrough.vue`). Class `pu-zoomable` opts an image into medium-zoom.
- Internal links in components are written with the site base included: `/plutonium-core/guides/kanban` (see `HomeInTheBox.vue`).
- Build/verify commands run from the repo root: `yarn docs:build` (includes dead-link check), `yarn docs:dev` (localhost:5173).
- There is no JS test infrastructure for the docs site. Verification = successful build + visual pass. TDD does not apply to these tasks.

---

### Task 1: Create `HomeFeatureTour.vue` and mount it

**Goal:** New interactive tour section — desktop feature rail / mobile accordion — showing DSL code + real screenshot for Kanban, Wizards, Actions, Multi-tenancy.

**Files:**
- Create: `docs/.vitepress/theme/components/HomeFeatureTour.vue`
- Modify: `docs/.vitepress/theme/index.ts` (import + register)
- Modify: `docs/index.md` (insert `<HomeFeatureTour />` after `<HomeWalkthrough />`)

**Acceptance Criteria:**
- [ ] Desktop (>768px): vertical rail on the left listing 4 features with one-line hooks; clicking swaps the right panel; active item has accent left border
- [ ] Mobile (≤768px): same DOM reflows to an accordion — all 4 heads visible, one open at a time
- [ ] Each panel: file caption bar → syntax-highlighted DSL snippet → guide screenshot (zoomable) → policy callout + "Read the guide →" link
- [ ] SSR/no-JS renders the first feature (Kanban) expanded
- [ ] Heads are `<button>`s with `aria-expanded`/`aria-controls`
- [ ] `yarn docs:build` passes

**Verify:** `yarn docs:build` → exits 0, no dead links. Then visual check in `yarn docs:dev`.

**Steps:**

- [ ] **Step 1: Write the component**

Create `docs/.vitepress/theme/components/HomeFeatureTour.vue`:

```vue
<template>
  <section class="pu-section">
    <div class="pu-section-inner">
      <h2 class="pu-section-title">More than CRUD.</h2>
      <p class="ft-sub">
        Four features other frameworks make you build yourself.
        All declarative. All policy-aware.
      </p>

      <div class="ft-grid">
        <template v-for="f in features" :key="f.id">
          <button
            class="ft-head"
            :class="{ 'ft-head--on': selected === f.id }"
            :aria-expanded="selected === f.id"
            :aria-controls="`ft-panel-${f.id}`"
            @click="selected = f.id"
          >
            <span class="ft-head-text">
              <b>{{ f.name }}</b>
              <small>{{ f.hook }}</small>
            </span>
            <IconChevronDown class="ft-chev" :size="16" :stroke-width="2" />
          </button>

          <div v-if="selected === f.id" :id="`ft-panel-${f.id}`" class="ft-body">
            <div class="ft-caption">{{ f.file }}</div>
            <pre class="ft-code" v-html="f.code"></pre>
            <img :src="withBase(f.shot)" :alt="f.alt" class="ft-shot pu-zoomable" />
            <div class="ft-foot">
              <span class="ft-policy">
                <IconShieldCheck :size="14" :stroke-width="2" /> {{ f.policy }}
              </span>
              <a class="ft-link" :href="f.link">Read the guide →</a>
            </div>
          </div>
        </template>
      </div>
    </div>
  </section>
</template>

<script setup>
import { ref } from "vue"
import { withBase } from "vitepress"
import { IconChevronDown, IconShieldCheck } from "@tabler/icons-vue"

const features = [
  {
    id: "kanban",
    name: "Kanban boards",
    hook: "Drag-drop boards from one block",
    file: "app/definitions/task_definition.rb",
    code: `<span class="m">kanban</span> <span class="k">do</span>
  <span class="m">column</span> <span class="s">:todo</span>,  scope: -&gt; { where(status: <span class="s">"todo"</span>) }, role: <span class="s">:backlog</span>
  <span class="m">column</span> <span class="s">:doing</span>, on_enter: -&gt;(r) { r.update!(status: <span class="s">"doing"</span>) }, wip: <span class="n">3</span>
  <span class="m">column</span> <span class="s">:done</span>,  on_enter: <span class="s">:mark_done!</span>, role: <span class="s">:done</span>
<span class="k">end</span>`,
    shot: "/images/guides/kanban-board.png",
    alt: "Kanban board with drag-and-drop columns, WIP limits, and quick-add",
    policy: "Columns lock and drags are rejected server-side when kanban_move? says no.",
    link: "/plutonium-core/guides/kanban",
  },
  {
    id: "wizards",
    name: "Wizards",
    hook: "Multi-step flows with branching & resume",
    file: "app/wizards/company_onboarding_wizard.rb",
    code: `<span class="k">class</span> CompanyOnboardingWizard <span class="k">&lt;</span> Plutonium::Wizard::Base
  <span class="m">step</span> <span class="s">:company</span>, label: <span class="s">"Company details"</span> <span class="k">do</span>
    <span class="m">attribute</span> <span class="s">:name</span>, <span class="s">:string</span>
    <span class="m">input</span> <span class="s">:name</span>
    <span class="m">validates</span> <span class="s">:name</span>, presence: <span class="k">true</span>
  <span class="k">end</span>

  <span class="m">step</span> <span class="s">:plan</span>, label: <span class="s">"Plan"</span> <span class="k">do</span>
    <span class="m">attribute</span> <span class="s">:plan</span>, <span class="s">:string</span>
    <span class="m">input</span> <span class="s">:plan</span>, as: <span class="s">:radio_buttons</span>, choices: <span class="s">%w[free pro]</span>
  <span class="k">end</span>

  <span class="m">review</span> label: <span class="s">"Review &amp; submit"</span>

  <span class="k">def</span> <span class="f">execute</span>
    company = Company.create!(name: data.company.name, plan: data.plan.plan)
    succeed(company).with_message(<span class="s">"You're all set!"</span>)
  <span class="k">end</span>
<span class="k">end</span>`,
    shot: "/images/guides/wizards-step.png",
    alt: "Wizard step form with progress indicator",
    policy: "Steps validate per-screen; the built-in review step gates the finish.",
    link: "/plutonium-core/guides/wizards",
  },
  {
    id: "actions",
    name: "Actions & interactions",
    hook: "Business logic with auto-generated UI",
    file: "app/definitions/post_definition.rb",
    code: `<span class="k">class</span> PostDefinition <span class="k">&lt;</span> ResourceDefinition
  <span class="m">action</span> <span class="s">:publish</span>, interaction: PublishPostInteraction
<span class="k">end</span>

<span class="c"># app/policies/post_policy.rb</span>
<span class="k">class</span> PostPolicy <span class="k">&lt;</span> ResourcePolicy
  <span class="k">def</span> <span class="f">publish?</span> = update? &amp;&amp; record.draft?
<span class="k">end</span>`,
    shot: "/images/guides/custom-actions-bulk.png",
    alt: "Bulk action running against selected table rows",
    policy: "No publish? policy method, no button — it disappears, it doesn't disable.",
    link: "/plutonium-core/guides/custom-actions",
  },
  {
    id: "tenancy",
    name: "Multi-tenancy & nesting",
    hook: "Scoping, invites, nested resources",
    file: "packages/customer_portal/lib/engine.rb",
    code: `<span class="k">class</span> CustomerPortal::Engine <span class="k">&lt;</span> Rails::Engine
  <span class="k">include</span> Plutonium::Portal::Engine

  config.after_initialize <span class="k">do</span>
    <span class="m">scope_to_entity</span> Organization, strategy: <span class="s">:path</span>
  <span class="k">end</span>
<span class="k">end</span>

<span class="c"># → /customer/42/posts — every query scoped to org 42</span>`,
    shot: "/images/guides/multi-tenancy-dashboard.png",
    alt: "Tenant-scoped portal dashboard",
    policy: "Every query flows through the entity scope — no default_scope hacks.",
    link: "/plutonium-core/guides/multi-tenancy",
  },
]

const selected = ref(features[0].id)
</script>

<style scoped>
.ft-sub { color: var(--pu-text-muted); font-size: 15px; margin: -16px 0 28px; }

.ft-grid {
  display: grid;
  grid-template-columns: 260px 1fr;
  grid-template-rows: repeat(3, auto) 1fr;
  column-gap: 28px;
  align-items: start;
}
.ft-head {
  grid-column: 1;
  display: flex; align-items: center; justify-content: space-between; gap: 8px;
  width: 100%; text-align: left; cursor: pointer;
  background: transparent; font-family: inherit;
  border: 0; border-left: 3px solid transparent;
  border-bottom: 1px solid var(--pu-border-soft);
  padding: 14px 16px;
  transition: border-color 0.15s ease, background 0.15s ease;
}
.ft-head:hover { background: var(--pu-bg-band); }
.ft-head--on { border-left-color: var(--pu-accent); background: var(--pu-bg-band); }
.ft-head-text { display: flex; flex-direction: column; gap: 2px; min-width: 0; }
.ft-head b { font-size: 14.5px; font-weight: 600; color: var(--pu-text); }
.ft-head--on b { color: var(--pu-accent); }
.ft-head small { font-size: 12px; color: var(--pu-text-faint); }
.ft-chev { color: var(--pu-text-faint); flex-shrink: 0; display: none; }

.ft-body { grid-column: 2; grid-row: 1 / -1; min-width: 0; }
.ft-caption {
  font-size: 11px; letter-spacing: 0.05em;
  font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
  color: #8b949e; background: #161b22;
  border: 1px solid #30363d; border-bottom: 0;
  border-radius: 8px 8px 0 0; padding: 8px 14px;
}
.ft-code {
  background: var(--pu-bg-dark); color: var(--pu-term-text);
  border-radius: 0 0 8px 8px; margin: 0; padding: 14px 16px;
  font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
  font-size: 12.5px; line-height: 1.6; overflow-x: auto; white-space: pre;
}
.ft-code :deep(.k) { color: #ff7b72; }
.ft-code :deep(.s) { color: #a5d6ff; }
.ft-code :deep(.m) { color: #d2a8ff; }
.ft-code :deep(.f) { color: #d2a8ff; }
.ft-code :deep(.n) { color: #79c0ff; }
.ft-code :deep(.c) { color: #8b949e; }

.ft-shot {
  display: block; width: 100%; height: auto; margin-top: 14px;
  border: 1px solid var(--pu-border-soft); border-radius: 8px;
}
.ft-foot {
  display: flex; align-items: center; justify-content: space-between;
  gap: 12px; flex-wrap: wrap; margin-top: 12px;
}
.ft-policy {
  display: inline-flex; align-items: center; gap: 6px;
  font-size: 12.5px; color: var(--pu-text-muted);
}
.ft-policy svg { color: var(--pu-success-fg); flex-shrink: 0; }
.ft-link {
  font-size: 13px; font-weight: 500; color: var(--pu-accent);
  text-decoration: none; white-space: nowrap;
}
.ft-link:hover { text-decoration: underline; }

@media (max-width: 768px) {
  .ft-grid { display: block; }
  .ft-head { border: 1px solid var(--pu-border-soft); border-left-width: 3px; border-radius: 6px; margin-bottom: 8px; }
  .ft-chev { display: block; transition: transform 0.15s ease; }
  .ft-head--on .ft-chev { transform: rotate(180deg); }
  .ft-body { margin: 4px 0 16px; }
}
</style>
```

- [ ] **Step 2: Register the component**

In `docs/.vitepress/theme/index.ts`, add the import after the `HomeWalkthrough` import and the registration after the `HomeWalkthrough` registration:

```ts
import HomeFeatureTour from "./components/HomeFeatureTour.vue"
```

```ts
    app.component("HomeFeatureTour", HomeFeatureTour)
```

- [ ] **Step 3: Mount on the homepage**

In `docs/index.md`, insert after `<HomeWalkthrough />`:

```md
<HomeFeatureTour />
```

(Section order after this task: Hero, StopWriting, Pillars, Walkthrough, **FeatureTour**, AudienceSplit, InTheBox, Cta. Task 2 finishes the reordering.)

- [ ] **Step 4: Build**

Run: `yarn docs:build`
Expected: build succeeds, no dead-link errors.

- [ ] **Step 5: Visual smoke check**

Run `yarn docs:dev`, open `http://localhost:5173/plutonium-core/`. Check: rail renders with Kanban expanded; clicking Wizards/Actions/Tenancy swaps the panel; at ≤768px width the section becomes an accordion; all four screenshots load; guide links navigate.

- [ ] **Step 6: Commit**

```bash
git add docs/.vitepress/theme/components/HomeFeatureTour.vue docs/.vitepress/theme/index.ts docs/index.md
git commit -m "feat(docs): add homepage feature tour section"
```

---

### Task 2: Create `HomeWhyPlutonium.vue`, delete `HomePillars` + `HomeAudienceSplit`

**Goal:** One compact band replaces two sections: four pillar cards on top, two-audience footer row below.

**Files:**
- Create: `docs/.vitepress/theme/components/HomeWhyPlutonium.vue`
- Delete: `docs/.vitepress/theme/components/HomePillars.vue`
- Delete: `docs/.vitepress/theme/components/HomeAudienceSplit.vue`
- Modify: `docs/.vitepress/theme/index.ts`
- Modify: `docs/index.md`

**Acceptance Criteria:**
- [ ] Single `pu-section--band` section titled "Built on Rails. Wired for shipping."
- [ ] Four compact pillar cards (Convention / It's just Rails / Multi-tenant ready / AI-readable) with the same icons and copy as the old `HomePillars`
- [ ] Footer row: "For Rails developers" and "For founders & teams", each with its existing lede + exactly 2 bullets (per spec)
- [ ] `HomePillars.vue` and `HomeAudienceSplit.vue` deleted; no references remain (`grep` clean)
- [ ] Homepage section order is: Hero, StopWriting, Walkthrough, FeatureTour, WhyPlutonium, InTheBox, Cta
- [ ] `yarn docs:build` passes

**Verify:** `yarn docs:build` → exits 0. `grep -rn "HomePillars\|HomeAudienceSplit" docs --include="*.ts" --include="*.md" --include="*.vue" -l` (excluding `docs/.vitepress/dist` and `docs/superpowers`) → no matches.

**Steps:**

- [ ] **Step 1: Write the component**

Create `docs/.vitepress/theme/components/HomeWhyPlutonium.vue`:

```vue
<template>
  <section class="pu-section pu-section--band">
    <div class="pu-section-inner">
      <h2 class="pu-section-title">Built on Rails. Wired for shipping.</h2>

      <div class="wp-grid">
        <div class="wp-card" v-for="p in pillars" :key="p.name">
          <component :is="p.icon" class="wp-icon" :size="20" :stroke-width="1.75" />
          <div class="wp-name">{{ p.name }}</div>
          <div class="wp-desc">{{ p.desc }}</div>
        </div>
      </div>

      <div class="wp-audiences">
        <div class="wp-aud">
          <div class="wp-aud-head">For Rails developers</div>
          <p class="wp-aud-lede">The missing layer between Rails and the apps you keep building.</p>
          <ul class="wp-aud-list">
            <li><IconArrowRight class="wp-arr" :size="16" :stroke-width="2.25" /><span>Convention extended to CRUD, policies, and portals</span></li>
            <li><IconArrowRight class="wp-arr" :size="16" :stroke-width="2.25" /><span>Generated code lives in your repo — edit anything</span></li>
          </ul>
        </div>
        <div class="wp-aud wp-aud--right">
          <div class="wp-aud-head">For founders &amp; teams</div>
          <p class="wp-aud-lede">Skip the SaaS template debate. Plutonium turns Rails into a SaaS toolkit.</p>
          <ul class="wp-aud-list">
            <li><IconArrowRight class="wp-arr" :size="16" :stroke-width="2.25" /><span>Admin panel, signup, and invites on day one</span></li>
            <li><IconArrowRight class="wp-arr" :size="16" :stroke-width="2.25" /><span>Multi-tenant scoping when you need it</span></li>
          </ul>
        </div>
      </div>
    </div>
  </section>
</template>

<script setup>
import { IconRoute, IconCode, IconBuildingSkyscraper, IconRobot, IconArrowRight } from "@tabler/icons-vue"

const pillars = [
  { icon: IconRoute, name: "Convention over configuration",
    desc: "Extended to resources, policies, portals, and tenancy — not just routes and views." },
  { icon: IconCode, name: "It's just Rails",
    desc: 'Generated code lives in your repo. Edit it, override it, delete it. The “magic” is regular Ruby mixins you can read.' },
  { icon: IconBuildingSkyscraper, name: "Multi-tenant ready",
    desc: "Path or domain tenancy. Scoped relations. Invites and memberships out of the box." },
  { icon: IconRobot, name: "AI-readable",
    desc: "Predictable file layout and naming. Built-in skills teach AI assistants the patterns." },
]
</script>

<style scoped>
.wp-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 14px; }
.wp-card {
  padding: 14px 16px; border: 1px solid var(--pu-border-soft); border-radius: 8px;
  background: var(--pu-bg-light);
}
.wp-icon { color: var(--pu-accent); margin-bottom: 8px; display: block; }
.wp-name { font-weight: 600; font-size: 14px; color: var(--pu-text); margin-bottom: 4px; line-height: 1.25; }
.wp-desc { font-size: 12.5px; color: var(--pu-text-muted); line-height: 1.5; }

.wp-audiences {
  display: grid; grid-template-columns: 1fr 1fr; gap: 28px;
  margin-top: 28px; padding-top: 24px; border-top: 1px solid var(--pu-border);
}
.wp-aud--right { border-left: 1px solid var(--pu-border); padding-left: 28px; }
.wp-aud-head {
  font-size: 11px; text-transform: uppercase; letter-spacing: 0.1em;
  color: var(--pu-accent); font-weight: 600; margin-bottom: 6px;
}
.wp-aud-lede {
  font-size: 16px; line-height: 1.35; font-weight: 500; color: var(--pu-text);
  margin: 0 0 10px; letter-spacing: -0.01em;
}
.wp-aud-list { list-style: none; padding: 0; margin: 0; font-size: 14px; line-height: 1.6; color: var(--pu-text-muted); }
.wp-aud-list li { display: flex; gap: 10px; align-items: flex-start; padding: 4px 0; }
.wp-arr { color: var(--pu-accent); flex-shrink: 0; margin-top: 3px; }

@media (max-width: 900px) { .wp-grid { grid-template-columns: repeat(2, 1fr); } }
@media (max-width: 768px) {
  .wp-audiences { grid-template-columns: 1fr; }
  .wp-aud--right { border-left: none; padding-left: 0; border-top: 1px solid var(--pu-border); padding-top: 20px; }
}
@media (max-width: 480px) { .wp-grid { grid-template-columns: 1fr; } }
</style>
```

- [ ] **Step 2: Swap registrations**

In `docs/.vitepress/theme/index.ts`:
- Remove the `HomePillars` and `HomeAudienceSplit` import lines and their `app.component(...)` lines.
- Add:

```ts
import HomeWhyPlutonium from "./components/HomeWhyPlutonium.vue"
```

```ts
    app.component("HomeWhyPlutonium", HomeWhyPlutonium)
```

- [ ] **Step 3: Update the homepage and delete old components**

`docs/index.md` component stack becomes exactly:

```md
<HomeHero />

<HomeStopWriting />

<HomeWalkthrough />

<HomeFeatureTour />

<HomeWhyPlutonium />

<HomeInTheBox />

<HomeCta />
```

Then:

```bash
git rm docs/.vitepress/theme/components/HomePillars.vue docs/.vitepress/theme/components/HomeAudienceSplit.vue
```

- [ ] **Step 4: Build + reference check**

Run: `yarn docs:build`
Expected: exits 0.

Run: `grep -rn "HomePillars\|HomeAudienceSplit" docs/.vitepress/theme docs/index.md`
Expected: no output.

- [ ] **Step 5: Commit**

```bash
git add docs/.vitepress/theme/components/HomeWhyPlutonium.vue docs/.vitepress/theme/index.ts docs/index.md
git commit -m "feat(docs): merge pillars and audience split into Why Plutonium band"
```

---

### Task 3: Copy weaves — hero, stop-writing, in-the-box

**Goal:** Make the four tour features discoverable in the hero, the scaffold comparison, and the categorized links.

**Files:**
- Modify: `docs/.vitepress/theme/components/HomeHero.vue` (pillars line)
- Modify: `docs/.vitepress/theme/components/HomeStopWriting.vue` (win stats)
- Modify: `docs/.vitepress/theme/components/HomeInTheBox.vue` (Workflows category)

**Acceptance Criteria:**
- [ ] Hero pillars line includes **Wizards.** and **Kanban.**
- [ ] Stop-writing Plutonium column shows `+ Actions` after `+ Bulk actions`
- [ ] In-the-box has a "Workflows" category (second position) with Wizards / Kanban boards / Interactions linking to their guides
- [ ] `yarn docs:build` passes

**Verify:** `yarn docs:build` → exits 0; visual check of the three sections.

**Steps:**

- [ ] **Step 1: Hero pillars line**

In `docs/.vitepress/theme/components/HomeHero.vue`, replace:

```html
        <p class="home-hero-pillars">
          <b>CRUD.</b> <b>Auth.</b> <b>Authorization.</b> <b>Multi-tenancy.</b>
          <b>Admin portals.</b> <b>Search, filters, bulk actions.</b>
          All generated. All customizable. All Rails.
        </p>
```

with:

```html
        <p class="home-hero-pillars">
          <b>CRUD.</b> <b>Auth.</b> <b>Authorization.</b> <b>Multi-tenancy.</b>
          <b>Wizards.</b> <b>Kanban.</b> <b>Admin portals.</b>
          <b>Search, filters, bulk actions.</b>
          All generated. All customizable. All Rails.
        </p>
```

- [ ] **Step 2: Stop-writing stats**

In `docs/.vitepress/theme/components/HomeStopWriting.vue`, replace:

```html
          <div class="hsw-stats hsw-stats--win">
            <span><b>Full CRUD</b></span>
            <span><b>+ Search</b></span>
            <span><b>+ Filters</b></span>
            <span><b>+ Bulk actions</b></span>
          </div>
```

with:

```html
          <div class="hsw-stats hsw-stats--win">
            <span><b>Full CRUD</b></span>
            <span><b>+ Search</b></span>
            <span><b>+ Filters</b></span>
            <span><b>+ Bulk actions</b></span>
            <span><b>+ Actions</b></span>
          </div>
```

- [ ] **Step 3: In-the-box Workflows category**

In `docs/.vitepress/theme/components/HomeInTheBox.vue`, insert into the `cats` array **between** the "Resources" and "App structure" entries:

```js
  { name: "Workflows", items: [
    { name: "Wizards", desc: "Multi-step flows with branching & resume",
      link: "/plutonium-core/guides/wizards" },
    { name: "Kanban boards", desc: "Drag-drop boards from one block",
      link: "/plutonium-core/guides/kanban" },
    { name: "Interactions", desc: "Business logic with auto-generated UI",
      link: "/plutonium-core/guides/custom-actions" },
  ]},
```

- [ ] **Step 4: Build**

Run: `yarn docs:build`
Expected: exits 0, no dead links.

- [ ] **Step 5: Commit**

```bash
git add docs/.vitepress/theme/components/HomeHero.vue docs/.vitepress/theme/components/HomeStopWriting.vue docs/.vitepress/theme/components/HomeInTheBox.vue
git commit -m "feat(docs): weave wizards, kanban, and actions into homepage copy"
```

---

### Task 4: Full visual pass + user sign-off

**Goal:** Verify the finished homepage at desktop and mobile widths and get the user's approval.

**Files:** none (verification only)

**Acceptance Criteria:**
- [ ] `yarn docs:build` passes on the final state
- [ ] Desktop pass: section order Hero → StopWriting → Walkthrough → FeatureTour → WhyPlutonium → InTheBox → CTA; tour rail interaction works; dark mode looks right (toggle the theme)
- [ ] Mobile pass (≤768px): tour is an accordion, all sections reflow, no horizontal scroll
- [ ] All four tour screenshots load and zoom; all guide links resolve
- [ ] User confirms the page sells the depth

**Verify:** `yarn docs:build` → exits 0; then manual pass in `yarn docs:dev`.

**Steps:**

- [ ] **Step 1: Build final state**

Run: `yarn docs:build`
Expected: exits 0.

- [ ] **Step 2: Manual pass**

Run `yarn docs:dev`; check every acceptance criterion above at 1280px and 375px widths, in light and dark mode.

- [ ] **Step 3: User verification**

**User Verification Required:**
Before marking this task complete, you MUST call AskUserQuestion:

```yaml
AskUserQuestion:
  question: "The homepage upgrade is done — feature tour, merged Why Plutonium band, copy weaves. Does it sell the depth the way you wanted?"
  header: "Verification"
  options:
    - label: "Approved"
      description: "Page sells the product — work is complete"
    - label: "Needs changes"
      description: "Something's off — describe what, and it gets reworked"
```

**If the user selects "Needs changes":** the task is NOT complete. Rework, then re-verify with AskUserQuestion again.

---

## Self-Review

- **Spec coverage:** Tour section (Task 1), merged band + deletions (Task 2), three copy weaves (Task 3), visual/mobile/build verification (Tasks 1–4). Out-of-scope items untouched. ✓
- **Placeholders:** none — every code step contains full code. ✓
- **Type consistency:** component names `HomeFeatureTour`/`HomeWhyPlutonium` consistent across create/register/mount steps; CSS class prefixes `ft-`/`wp-` self-contained. ✓
- **Verification requirement:** YES → Task 4 carries `requiresUserVerification: true` with the standard block. ✓
