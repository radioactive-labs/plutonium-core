<template>
  <section class="pu-section">
    <div class="pu-section-inner">
      <h2 class="pu-section-title">Two commands. A whole portal.</h2>

      <div class="hw-hero-shot">
        <div class="hw-browser-bar"><span></span><span></span><span></span><code>localhost:3000/admin</code></div>
        <div class="hw-placeholder hw-placeholder--portal">
          [ Wide portal screenshot — <code>home-portal.png</code> pending ]
        </div>
      </div>

      <div class="hw-strip">
        <div>
          <div class="hw-label">1 — You run</div>
          <div class="hw-placeholder hw-placeholder--term">
            [ Asciinema — <code>home-scaffold.cast</code> pending ]
          </div>
        </div>
        <div>
          <div class="hw-label">2 — Plutonium serves</div>
          <div class="hw-browser hw-browser--small">
            <div class="hw-browser-bar"><span></span><span></span><code>/admin/posts</code></div>
            <div class="hw-placeholder">[ <code>home-index.png</code> pending ]</div>
          </div>
        </div>
        <div>
          <div class="hw-label">3 — Forms, free</div>
          <div class="hw-browser hw-browser--small">
            <div class="hw-browser-bar"><span></span><span></span><code>/admin/posts/new</code></div>
            <div class="hw-placeholder">[ <code>home-form.png</code> pending ]</div>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>

<style scoped>
.hw-hero-shot {
  border: 1px solid var(--pu-border); border-radius: 10px; overflow: hidden;
  background: var(--pu-bg-light); margin-bottom: 18px;
}
.hw-browser-bar {
  background: var(--pu-bg-band); padding: 8px 12px; display: flex; align-items: center; gap: 5px;
  border-bottom: 1px solid var(--pu-border-soft);
}
.hw-browser-bar span {
  width: 10px; height: 10px; border-radius: 50%; background: var(--pu-border);
}
.hw-browser-bar code {
  margin-left: 12px; background: var(--pu-bg-light); padding: 3px 8px; border-radius: 4px;
  font-size: 11px; color: var(--pu-text-faint);
}
.hw-placeholder {
  aspect-ratio: 16/9;
  display: flex; align-items: center; justify-content: center;
  background: linear-gradient(135deg, var(--pu-bg-band), #f0f0f0);
  color: var(--pu-text-faint); font-size: 13px; font-family: ui-monospace, monospace;
}
.hw-placeholder--portal { aspect-ratio: 21/8; }
.hw-placeholder--term { aspect-ratio: 4/3; background: linear-gradient(135deg, #1a1f29, #0d1117); color: #6e7681; }
.hw-strip { display: grid; grid-template-columns: 1.1fr 1fr 1fr; gap: 16px; align-items: stretch; }
.hw-label { font-size: 11px; text-transform: uppercase; letter-spacing: 0.08em; color: var(--pu-text-faint); margin-bottom: 8px; }
.hw-browser--small { border: 1px solid var(--pu-border-soft); border-radius: 8px; overflow: hidden; }
.hw-browser--small .hw-browser-bar { padding: 5px 8px; }
.hw-browser--small .hw-browser-bar span { width: 8px; height: 8px; }
.hw-browser--small .hw-browser-bar code { margin-left: 6px; font-size: 10px; }
@media (max-width: 768px) { .hw-strip { grid-template-columns: 1fr; } }
</style>
