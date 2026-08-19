<template>
  <div class="bm">
    <div class="bm-line">
      <time v-if="dateString" :datetime="isoDate">{{ dateString }}</time>
      <span v-if="frontmatter.author" class="bm-sep">·</span>
      <span v-if="frontmatter.author">{{ frontmatter.author }}</span>
    </div>
    <a class="bm-back" :href="withBase('/blog/')">
      <IconArrowLeft :size="14" :stroke-width="2" /> All posts
    </a>
  </div>
</template>

<script setup>
import { computed } from "vue"
import { useData, withBase } from "vitepress"
import { IconArrowLeft } from "@tabler/icons-vue"

const { frontmatter } = useData()

// Frontmatter dates arrive as a Date (YAML-parsed) or a string, depending on quoting.
const parsed = computed(() => (frontmatter.value.date ? new Date(frontmatter.value.date) : null))
const isoDate = computed(() => parsed.value?.toISOString())
const dateString = computed(() =>
  parsed.value?.toLocaleDateString("en-US", {
    year: "numeric", month: "long", day: "numeric", timeZone: "UTC",
  })
)
</script>

<style scoped>
.bm {
  margin: 0 0 40px;
  padding-bottom: 20px;
  border-bottom: 1px solid var(--pu-border-soft);
}
.bm-line {
  font-size: 14px; color: var(--pu-text-muted);
  display: flex; align-items: center; gap: 7px;
}
.bm-sep { color: var(--pu-text-faint); }
.bm-back {
  display: inline-flex; align-items: center; gap: 5px; margin-top: 14px;
  font-size: 13px; font-weight: 500; color: var(--pu-accent); text-decoration: none;
}
.bm-back:hover { text-decoration: underline; }
</style>
