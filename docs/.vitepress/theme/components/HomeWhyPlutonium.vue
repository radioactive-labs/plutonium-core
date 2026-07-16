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
            <li><IconArrowRight class="wp-arr" :size="16" :stroke-width="2.25" aria-hidden="true" /><span>Convention extended to CRUD, policies, and portals</span></li>
            <li><IconArrowRight class="wp-arr" :size="16" :stroke-width="2.25" aria-hidden="true" /><span>Generated code lives in your repo — edit anything</span></li>
          </ul>
        </div>
        <div class="wp-aud wp-aud--right">
          <div class="wp-aud-head">For founders &amp; teams</div>
          <p class="wp-aud-lede">Skip the SaaS template debate. Plutonium turns Rails into a SaaS toolkit.</p>
          <ul class="wp-aud-list">
            <li><IconArrowRight class="wp-arr" :size="16" :stroke-width="2.25" aria-hidden="true" /><span>Admin panel, signup, and invites on day one</span></li>
            <li><IconArrowRight class="wp-arr" :size="16" :stroke-width="2.25" aria-hidden="true" /><span>Multi-tenant scoping when you need it</span></li>
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
    desc: 'Generated code lives in your repo. Edit it, override it, delete it. The "magic" is regular Ruby mixins you can read.' },
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
