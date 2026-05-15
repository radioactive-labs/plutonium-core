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
                class="sl-step sl-step--link sl-step--cat"
              >
                <span class="sl-step-body">
                  <span class="sl-step-name">{{ item.name }}</span>
                  <span v-if="item.desc" class="sl-step-desc">{{ item.desc }}</span>
                </span>
                <IconArrowRight class="sl-step-arrow" :size="16" :stroke-width="2" />
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
import { IconArrowRight } from "@tabler/icons-vue"

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
.sl-step--cat { justify-content: space-between; align-items: center; }
.sl-step--link:hover .sl-step-name { color: var(--pu-accent); }
.sl-step--link:hover .sl-step-arrow { transform: translateX(2px); color: var(--pu-accent); }
.sl-num {
  flex-shrink: 0; width: 24px; height: 24px; line-height: 24px; text-align: center;
  background: var(--pu-accent); color: #fff; border-radius: 50%;
  font-size: 11px; font-weight: 600;
}
.sl-step-body { display: flex; flex-direction: column; gap: 2px; flex: 1; }
.sl-step-name { font-weight: 600; font-size: 14px; }
.sl-step-desc { font-size: 12.5px; color: var(--pu-text-muted); }
.sl-step-arrow { color: var(--pu-text-faint); transition: transform 0.15s ease, color 0.15s ease; flex-shrink: 0; }

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
