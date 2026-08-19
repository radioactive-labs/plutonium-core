<template>
  <section class="pu-section bi-section">
    <div class="pu-section-inner">
      <div class="pu-eyebrow">{{ eyebrow }}</div>
      <h1 class="bi-h1">{{ title }}</h1>
      <p class="bi-lede">{{ lede }}</p>

      <a class="bi-rss" :href="withBase('/blog/feed.rss')">
        <IconRss :size="15" :stroke-width="2" /> Subscribe via RSS
      </a>

      <div class="bi-list">
        <a v-for="post in posts" :key="post.url" :href="withBase(post.url)" class="bi-post">
          <time class="bi-date" :datetime="new Date(post.date.time).toISOString()">
            {{ post.date.string }}
          </time>
          <span class="bi-body">
            <span class="bi-title">{{ post.title }}</span>
            <span v-if="post.description" class="bi-desc">{{ post.description }}</span>
            <span v-if="post.tags.length" class="bi-tags">
              <span v-for="tag in post.tags" :key="tag" class="bi-tag">{{ tag }}</span>
            </span>
          </span>
          <IconArrowRight class="bi-arrow" :size="16" :stroke-width="2" />
        </a>
      </div>

      <p v-if="!posts.length" class="bi-empty">No posts yet.</p>
    </div>
  </section>
</template>

<script setup>
import { withBase } from "vitepress"
import { IconArrowRight, IconRss } from "@tabler/icons-vue"
import { data as posts } from "../blog.data"

defineProps({
  eyebrow: { type: String, default: "Blog" },
  title: { type: String, required: true },
  lede: { type: String, required: true },
})
</script>

<style scoped>
.bi-section { padding: 64px 24px 96px; }
.bi-h1 { font-size: 36px; letter-spacing: -0.025em; margin: 0 0 12px; color: var(--pu-text); }
.bi-lede { font-size: 16px; color: var(--pu-text-muted); max-width: 640px; margin: 0 0 20px; line-height: 1.55; }

.bi-rss {
  display: inline-flex; align-items: center; gap: 6px; margin-bottom: 40px;
  font-size: 13px; font-weight: 500; color: var(--pu-text-muted); text-decoration: none;
}
.bi-rss:hover { color: var(--pu-accent); }

.bi-list { border-left: 2px solid var(--pu-accent); padding-left: 24px; max-width: 760px; }
.bi-post {
  display: flex; gap: 20px; align-items: flex-start;
  padding: 18px 0; border-bottom: 1px solid var(--pu-border-soft);
  color: var(--pu-text); text-decoration: none;
}
.bi-post:last-child { border-bottom: none; }
.bi-post:hover .bi-title { color: var(--pu-accent); }
.bi-post:hover .bi-arrow { transform: translateX(2px); color: var(--pu-accent); }

.bi-date {
  flex-shrink: 0; width: 124px; padding-top: 2px;
  font-size: 12.5px; color: var(--pu-text-faint); font-variant-numeric: tabular-nums;
}
.bi-body { display: flex; flex-direction: column; gap: 4px; flex: 1; }
.bi-title { font-weight: 600; font-size: 16px; letter-spacing: -0.01em; }
.bi-desc { font-size: 13.5px; color: var(--pu-text-muted); line-height: 1.5; }
.bi-tags { display: flex; flex-wrap: wrap; gap: 6px; margin-top: 4px; }
.bi-tag {
  font-size: 11px; text-transform: uppercase; letter-spacing: 0.06em; font-weight: 600;
  color: var(--pu-text-faint); border: 1px solid var(--pu-border-soft);
  border-radius: 3px; padding: 1px 6px;
}
.bi-arrow { color: var(--pu-text-faint); transition: transform 0.15s ease, color 0.15s ease; flex-shrink: 0; margin-top: 4px; }
.bi-empty { color: var(--pu-text-muted); font-size: 14px; }

@media (max-width: 640px) {
  .bi-post { flex-direction: column; gap: 6px; }
  .bi-date { width: auto; padding-top: 0; }
  .bi-arrow { display: none; }
}
</style>
