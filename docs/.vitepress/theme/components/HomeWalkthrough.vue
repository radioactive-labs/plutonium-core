<template>
  <section class="pu-section">
    <div class="pu-section-inner">
      <h2 class="pu-section-title">Scaffold a portal in minutes.</h2>

      <div class="hw-cast">
        <div class="hw-browser-bar hw-browser-bar--term">
          <span></span><span></span><span></span>
          <code>asciinema · scaffold a blog</code>
        </div>
        <div ref="castEl" class="hw-cast-player"></div>
      </div>

      <div class="hw-strip">
        <figure v-for="shot in shots" :key="shot.label">
          <div class="hw-label">{{ shot.label }}</div>
          <button type="button" class="hw-browser" @click="open(shot)" :aria-label="`Expand ${shot.label} screenshot`">
            <div class="hw-browser-bar"><span></span><span></span><code>{{ shot.url }}</code></div>
            <img :src="shot.src" :alt="shot.alt" class="hw-shot" />
            <span class="hw-zoom-hint">
              <IconArrowsMaximize :size="14" :stroke-width="2" />
            </span>
          </button>
        </figure>
      </div>
    </div>

    <Teleport to="body">
      <div v-if="expanded" class="hw-lightbox" role="dialog" aria-modal="true" @click="close">
        <button type="button" class="hw-lightbox-close" @click="close" aria-label="Close">
          <IconX :size="20" :stroke-width="2" />
        </button>
        <img :src="expanded.src" :alt="expanded.alt" class="hw-lightbox-img" @click.stop />
      </div>
    </Teleport>
  </section>
</template>

<script setup>
import { ref, onMounted, onBeforeUnmount } from "vue"
import { withBase } from "vitepress"
import { IconArrowsMaximize, IconX } from "@tabler/icons-vue"

const shots = [
  { label: "Index", url: "/admin/posts",     src: withBase("/images/home-index.png"), alt: "Posts index" },
  { label: "New",   url: "/admin/posts/new", src: withBase("/images/home-new.png"),   alt: "New post form" },
  { label: "Show",  url: "/admin/posts/1",   src: withBase("/images/home-show.png"),  alt: "Post show page" },
]
const castUrl = withBase("/asciinema/home-scaffold.cast")

const castEl = ref(null)
let player = null

const expanded = ref(null)
function open(shot) { expanded.value = shot }
function close() { expanded.value = null }
function onKey(e) { if (e.key === "Escape") close() }

onMounted(async () => {
  if (typeof window === "undefined" || !castEl.value) return

  const [{ create }] = await Promise.all([
    import("asciinema-player"),
    import("asciinema-player/dist/bundle/asciinema-player.css"),
  ])

  player = create(castUrl, castEl.value, {
    autoPlay: true,
    loop: true,
    controls: true,
    fit: "width",
    rows: 14,
    terminalFontSize: "small",
    idleTimeLimit: 1.5,
  })
})

onMounted(() => {
  if (typeof window !== "undefined") window.addEventListener("keydown", onKey)
})

onBeforeUnmount(() => {
  player?.dispose?.()
  if (typeof window !== "undefined") window.removeEventListener("keydown", onKey)
})
</script>

<style scoped>
.hw-cast {
  border: 1px solid var(--pu-border); border-radius: 10px; overflow: hidden;
  background: var(--pu-bg-dark); margin-bottom: 18px;
}
.hw-cast-player { padding: 8px; background: var(--pu-bg-dark); }
.hw-cast-player :deep(.ap-player) { background: var(--pu-bg-dark); }

.hw-browser-bar {
  background: var(--pu-bg-band); padding: 8px 12px; display: flex; align-items: center; gap: 5px;
  border-bottom: 1px solid var(--pu-border-soft);
}
.hw-browser-bar--term { background: #161b22; border-bottom-color: #30363d; }
.hw-browser-bar span {
  width: 10px; height: 10px; border-radius: 50%; background: var(--pu-border);
}
.hw-browser-bar--term span { background: #30363d; }
.hw-browser-bar code {
  margin-left: 12px; background: var(--pu-bg-light); padding: 3px 8px; border-radius: 4px;
  font-size: 11px; color: var(--pu-text-faint);
}
.hw-browser-bar--term code { background: #21262d; color: #8b949e; }

.hw-strip {
  display: grid; grid-template-columns: repeat(3, 1fr); gap: 16px; align-items: stretch;
}
.hw-strip figure { margin: 0; display: flex; flex-direction: column; }
.hw-label {
  font-size: 11px; text-transform: uppercase; letter-spacing: 0.08em;
  color: var(--pu-text-faint); margin-bottom: 8px;
}
.hw-browser {
  position: relative;
  display: block; width: 100%; padding: 0;
  border: 1px solid var(--pu-border-soft); border-radius: 8px; overflow: hidden;
  background: var(--pu-bg-light); cursor: zoom-in; font: inherit; text-align: left;
  transition: border-color 0.15s ease, transform 0.15s ease;
}
.hw-browser:hover { border-color: var(--pu-accent); }
.hw-browser:hover .hw-zoom-hint { opacity: 1; }
.hw-browser:focus-visible {
  outline: 2px solid var(--pu-accent); outline-offset: 2px;
}
.hw-browser .hw-browser-bar { padding: 5px 8px; }
.hw-browser .hw-browser-bar span { width: 8px; height: 8px; }
.hw-browser .hw-browser-bar code { margin-left: 6px; font-size: 10px; }
.hw-shot { display: block; width: 100%; height: auto; }
.hw-zoom-hint {
  position: absolute; top: 10px; right: 10px;
  background: rgba(0,0,0,0.55); color: #fff;
  width: 28px; height: 28px; border-radius: 50%;
  display: inline-flex; align-items: center; justify-content: center;
  opacity: 0; transition: opacity 0.15s ease;
  pointer-events: none;
}

.hw-lightbox {
  position: fixed; inset: 0; z-index: 1000;
  background: rgba(0,0,0,0.82);
  display: flex; align-items: center; justify-content: center;
  padding: 5vh 5vw;
  animation: hw-fade 0.15s ease;
}
@keyframes hw-fade { from { opacity: 0; } to { opacity: 1; } }
.hw-lightbox-img {
  max-width: 100%; max-height: 100%;
  object-fit: contain;
  border-radius: 8px;
  box-shadow: 0 20px 60px rgba(0,0,0,0.4);
  cursor: default;
}
.hw-lightbox-close {
  position: absolute; top: 16px; right: 16px;
  background: rgba(255,255,255,0.1); border: 1px solid rgba(255,255,255,0.18);
  color: #fff; border-radius: 50%;
  width: 36px; height: 36px;
  display: inline-flex; align-items: center; justify-content: center;
  cursor: pointer; padding: 0;
  transition: background 0.15s ease;
}
.hw-lightbox-close:hover { background: rgba(255,255,255,0.22); }

@media (max-width: 768px) {
  .hw-strip { grid-template-columns: 1fr; }
}
</style>
