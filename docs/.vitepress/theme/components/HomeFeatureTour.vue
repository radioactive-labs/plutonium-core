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
            :aria-controls="selected === f.id ? `ft-panel-${f.id}` : undefined"
            @click="selected = f.id"
          >
            <span class="ft-head-text">
              <b>{{ f.name }}</b>
              <small>{{ f.hook }}</small>
            </span>
            <IconChevronDown class="ft-chev" :size="16" :stroke-width="2" aria-hidden="true" />
          </button>

          <div v-if="selected === f.id" :id="`ft-panel-${f.id}`" class="ft-body">
            <div class="ft-caption">{{ f.file }}</div>
            <pre class="ft-code" v-html="f.code"></pre>
            <img :src="withBase(f.shot)" :alt="f.alt" class="ft-shot pu-zoomable" />
            <div class="ft-foot">
              <span class="ft-policy">
                <IconShieldCheck :size="14" :stroke-width="2" aria-hidden="true" /> {{ f.policy }}
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
  <span class="m">column</span> <span class="s">:todo</span>,  scope: -&gt; { where(status: <span class="s">"todo"</span>) }, on_enter: -&gt;(r) { r.update!(status: <span class="s">"todo"</span>) }, role: <span class="s">:backlog</span>
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
  /* rows = one per feature; last row (1fr) absorbs the panel's extra height */
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
