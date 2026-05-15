<template>
  <section class="pu-section">
    <div class="pu-section-inner">
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
