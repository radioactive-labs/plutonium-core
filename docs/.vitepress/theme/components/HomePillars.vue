<template>
  <section class="pu-section pu-section--band">
    <div class="pu-section-inner">
      <div class="pu-eyebrow pu-eyebrow--muted">Four pillars</div>
      <h2 class="pu-section-title">Built on Rails. Wired for shipping.</h2>
      <div class="hp-grid">
        <div class="hp-card" v-for="p in pillars" :key="p.name">
          <component :is="p.icon" class="hp-icon" :size="22" :stroke-width="1.75" />
          <div class="hp-name">{{ p.name }}</div>
          <div class="hp-desc">{{ p.desc }}</div>
        </div>
      </div>
    </div>
  </section>
</template>

<script setup>
import { IconRoute, IconCode, IconBuildingSkyscraper, IconRobot } from "@tabler/icons-vue"

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
.hp-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 16px; }
.hp-card {
  padding: 18px; border: 1px solid var(--pu-border-soft); border-radius: 8px;
  background: var(--pu-bg-light);
}
.hp-icon { color: var(--pu-accent); margin-bottom: 10px; display: block; }
.hp-name { font-weight: 600; font-size: 15px; color: var(--pu-text); margin-bottom: 6px; line-height: 1.25; }
.hp-desc { font-size: 13px; color: var(--pu-text-muted); line-height: 1.5; }
@media (max-width: 900px) { .hp-grid { grid-template-columns: repeat(2, 1fr); } }
@media (max-width: 480px) { .hp-grid { grid-template-columns: 1fr; } }
</style>
