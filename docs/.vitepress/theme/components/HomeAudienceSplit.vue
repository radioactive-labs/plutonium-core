<template>
  <section class="pu-section pu-section--band">
    <div class="pu-section-inner">
      <h2 class="pu-section-title">Plutonium fits two kinds of teams.</h2>
      <div class="ha-grid">
        <div class="ha-col">
          <div class="ha-head">For Rails developers</div>
          <p class="ha-lede">The missing layer between Rails and the apps you keep building.</p>
          <ul class="ha-list">
            <li><IconArrowRight class="ha-arr" :size="16" :stroke-width="2.25" /><span>Convention extended to CRUD, policies, and portals</span></li>
            <li><IconArrowRight class="ha-arr" :size="16" :stroke-width="2.25" /><span>Generated code lives in your repo — edit anything</span></li>
            <li><IconArrowRight class="ha-arr" :size="16" :stroke-width="2.25" /><span>Mountable Rails engines for packages and portals</span></li>
            <li><IconArrowRight class="ha-arr" :size="16" :stroke-width="2.25" /><span>ActionPolicy authorization, baked in</span></li>
          </ul>
        </div>
        <div class="ha-col ha-col--right">
          <div class="ha-head">For founders &amp; teams</div>
          <p class="ha-lede">Skip the SaaS template debate. Plutonium turns Rails into a SaaS toolkit.</p>
          <ul class="ha-list">
            <li><IconArrowRight class="ha-arr" :size="16" :stroke-width="2.25" /><span>Admin panel, signup, and invites on day one</span></li>
            <li><IconArrowRight class="ha-arr" :size="16" :stroke-width="2.25" /><span>Multi-tenant scoping when you need it</span></li>
            <li><IconArrowRight class="ha-arr" :size="16" :stroke-width="2.25" /><span>No template lock-in — it's just your Rails app</span></li>
            <li><IconArrowRight class="ha-arr" :size="16" :stroke-width="2.25" /><span>Ship faster with AI tools that understand your code</span></li>
          </ul>
        </div>
      </div>
    </div>
  </section>
</template>

<script setup>
import { IconArrowRight } from "@tabler/icons-vue"
</script>

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
.ha-list { list-style: none; padding: 0; margin: 0; font-size: 14px; line-height: 1.6; color: var(--pu-text-muted); }
.ha-list li { display: flex; gap: 10px; align-items: flex-start; padding: 5px 0; }
.ha-arr { color: var(--pu-accent); flex-shrink: 0; margin-top: 3px; }
@media (max-width: 768px) {
  .ha-grid { grid-template-columns: 1fr; }
  .ha-col--right { border-left: none; padding-left: 0; border-top: 1px solid var(--pu-border); padding-top: 24px; }
}
</style>
