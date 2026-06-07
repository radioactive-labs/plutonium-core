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

      <div class="hc-term-wrap">
        <pre class="pu-term hc-term"><span class="prompt">$</span> {{ activeCommand }}<span class="pu-term-cursor"></span></pre>
        <button class="hc-copy" :class="{ 'hc-copy--ok': copied }" @click="copy" :title="copied ? 'Copied' : 'Copy command'" :aria-label="copied ? 'Copied' : 'Copy command'">
          <component :is="copied ? IconCheck : IconCopy" :size="16" :stroke-width="2" />
        </button>
      </div>

      <div class="hc-ctas">
        <a class="pu-btn pu-btn-primary" href="/plutonium-core/getting-started/">Get started <IconArrowRight :size="16" :stroke-width="2.25" /></a>
        <a class="pu-btn pu-btn-ghost" href="https://github.com/radioactive-labs/plutonium-core" target="_blank" rel="noopener">
          <IconBrandGithub :size="16" :stroke-width="2" /> GitHub
        </a>
      </div>
    </div>
  </section>
</template>

<script setup>
import { ref, computed } from "vue"
import { IconArrowRight, IconBrandGithub, IconCopy, IconCheck } from "@tabler/icons-vue"

const options = [
  { id: "plutonium", name: "plutonium", sub: "core + portals",
    url: "https://radioactive-labs.github.io/plutonium-core/templates/plutonium.rb" },
  { id: "pluton8", name: "pluton8", sub: "+ SaaS lite stack",
    url: "https://radioactive-labs.github.io/plutonium-core/templates/pluton8.rb" },
]
const selected = ref("plutonium")
const activeUrl = computed(() => options.find(o => o.id === selected.value).url)
const activeCommand = computed(() => `rails new my_app -a propshaft -j esbuild -c tailwind -m ${activeUrl.value}`)
const copied = ref(false)

async function copy() {
  try {
    await navigator.clipboard.writeText(activeCommand.value)
    copied.value = true
    setTimeout(() => { copied.value = false }, 1600)
  } catch (e) {
    // clipboard API unavailable; do nothing
  }
}
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
  font-family: inherit;
}
.hc-pill-sub { font-size: 9.5px; text-transform: uppercase; letter-spacing: 0.08em; color: var(--pu-text-faint); margin-top: 2px; }
.hc-pill--active {
  background: var(--pu-bg-light); color: var(--pu-text); font-weight: 600;
  box-shadow: 0 1px 3px rgba(0,0,0,0.1);
}
.hc-term-wrap { position: relative; max-width: 640px; margin: 0 auto 24px; }
.hc-term { margin: 0; text-align: left; white-space: pre-wrap; word-break: break-all; padding-right: 48px; }
.hc-copy {
  position: absolute; top: 8px; right: 8px;
  background: rgba(255,255,255,0.08); border: 1px solid rgba(255,255,255,0.12);
  color: var(--pu-term-text); border-radius: 6px;
  width: 32px; height: 32px; display: inline-flex; align-items: center; justify-content: center;
  cursor: pointer; transition: background 0.15s ease, color 0.15s ease;
  padding: 0;
}
.hc-copy:hover { background: rgba(255,255,255,0.16); }
.hc-copy--ok { background: var(--pu-success-bg); color: var(--pu-success-fg); border-color: transparent; }
.hc-ctas { display: flex; gap: 10px; justify-content: center; flex-wrap: wrap; }
.hc-ctas .pu-btn { display: inline-flex; align-items: center; gap: 6px; }
@media (max-width: 600px) { .hc-quote { font-size: 22px; } }
</style>
