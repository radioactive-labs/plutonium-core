<template>
  <section class="pu-section">
    <div class="pu-section-inner">
      <h2 class="pu-section-title">Organized the way you'll use it.</h2>
      <div v-for="cat in cats" :key="cat.name" class="hb-cat">
        <div class="hb-cat-name">{{ cat.name }}</div>
        <div class="hb-row">
          <a v-for="item in cat.items" :key="item.name" :href="item.link" class="hb-item">
            <span class="hb-item-body">
              <b>{{ item.name }}</b>
              <small>{{ item.desc }}</small>
            </span>
            <IconArrowUpRight class="hb-arrow" :size="16" :stroke-width="2" />
          </a>
        </div>
      </div>
    </div>
  </section>
</template>

<script setup>
import { IconArrowUpRight } from "@tabler/icons-vue"

const cats = [
  { name: "Resources", items: [
    { name: "Scaffolds", desc: "Model, definition, policy, routes",
      link: "/plutonium-core/reference/app/generators" },
    { name: "Search & filters", desc: "Declarative on the definition",
      link: "/plutonium-core/guides/search-filtering" },
    { name: "Custom & bulk actions", desc: "Resource-scoped interactions",
      link: "/plutonium-core/guides/custom-actions" },
  ]},
  { name: "App structure", items: [
    { name: "Portals", desc: "Themed, mountable engines",
      link: "/plutonium-core/reference/app/portals" },
    { name: "Packages", desc: "Feature engines under your app",
      link: "/plutonium-core/guides/creating-packages" },
    { name: "Multi-tenancy", desc: "Path or domain scoping",
      link: "/plutonium-core/guides/multi-tenancy" },
  ]},
  { name: "People & access", items: [
    { name: "Auth (Rodauth)", desc: "Login, signup, password reset",
      link: "/plutonium-core/guides/authentication" },
    { name: "Authorization", desc: "ActionPolicy per resource",
      link: "/plutonium-core/guides/authorization" },
    { name: "Invites & memberships", desc: "Token lifecycle, mailers, onboarding",
      link: "/plutonium-core/guides/user-invites" },
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
.hb-item {
  display: flex; align-items: flex-start; justify-content: space-between; gap: 10px;
  padding: 14px 16px; border: 1px solid var(--pu-border-soft); border-radius: 8px;
  background: var(--pu-bg-light); color: inherit; text-decoration: none;
  transition: border-color 0.15s ease, transform 0.15s ease;
}
.hb-item:hover { border-color: var(--pu-accent); }
.hb-item:hover b { color: var(--pu-accent); }
.hb-item:hover .hb-arrow { color: var(--pu-accent); transform: translate(2px, -2px); }
.hb-item-body { display: flex; flex-direction: column; min-width: 0; }
.hb-item b { display: block; color: var(--pu-text); font-weight: 600; margin-bottom: 2px; font-size: 14px; transition: color 0.15s ease; }
.hb-item small { font-size: 12px; color: var(--pu-text-faint); }
.hb-arrow { color: var(--pu-text-faint); flex-shrink: 0; transition: color 0.15s ease, transform 0.15s ease; margin-top: 2px; }
@media (max-width: 768px) { .hb-row { grid-template-columns: 1fr; } }
</style>
