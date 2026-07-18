<template>
  <section class="pu-section pu-section--dark home-hero">
    <div class="pu-section-inner home-hero-grid">
      <div class="home-hero-text">
        <div class="pu-eyebrow">Plutonium · The Rails RAD framework</div>
        <h1 class="home-hero-headline">
          The Rails framework for things you should never write again.
        </h1>
        <p class="home-hero-lede">
          Convention over configuration, extended to everything you keep rebuilding.
        </p>
        <p class="home-hero-pillars">
          <!-- keep the bolds on one source line: Vue drops whitespace-only nodes containing newlines -->
          <b>CRUD.</b> <b>Auth.</b> <b>Authorization.</b> <b>Multi-tenancy.</b> <b>Wizards.</b> <b>Kanban.</b> <b>Admin portals.</b> <b>Search, filters, bulk actions.</b>
          All generated. All customizable. All Rails.
        </p>
        <div class="home-hero-ctas">
          <a class="pu-btn pu-btn-primary" href="/plutonium-core/getting-started/">Get started →</a>
          <a class="pu-btn pu-btn-ghost on-dark" href="/plutonium-core/getting-started/tutorial/">Tutorial</a>
        </div>
      </div>
      <pre class="pu-term home-hero-term"><span class="prompt">$</span> rails g pu:pkg:portal admin
<span class="dim">      create  packages/admin_portal/...</span>
<span class="prompt">$</span> rails g pu:res:scaffold Post title:string body:text published_at:datetime --dest=main_app
<span class="dim">      create  app/models/post.rb</span>
<span class="dim">      create  app/definitions/post_definition.rb</span>
<span class="prompt">$</span> rails g pu:res:conn Post --dest=admin_portal
<span class="dim">      ✓ Connected Post to AdminPortal</span>
<span class="prompt">$</span> <span class="pu-term-cursor"></span></pre>
    </div>
  </section>
</template>

<style scoped>
.home-hero { padding: 96px 24px; }
.home-hero-grid {
  display: grid;
  grid-template-columns: 1.05fr 1fr;
  gap: 48px;
  align-items: center;
}
.home-hero-headline {
  font-size: 48px;
  line-height: 1.05;
  letter-spacing: -0.025em;
  margin: 0 0 18px;
  font-weight: 700;
}
.home-hero-lede {
  font-size: 18px;
  line-height: 1.5;
  opacity: 0.78;
  margin: 0 0 14px;
  max-width: 540px;
}
.home-hero-pillars {
  font-size: 14.5px;
  line-height: 1.6;
  opacity: 0.65;
  margin: 0 0 28px;
  max-width: 540px;
}
.home-hero-pillars b { color: var(--pu-term-text); font-weight: 600; opacity: 1; }
.home-hero-ctas { display: flex; gap: 12px; flex-wrap: wrap; }
.home-hero-term { margin: 0; white-space: pre; }
@media (max-width: 768px) {
  .home-hero-grid { grid-template-columns: 1fr; gap: 28px; }
  .home-hero-headline { font-size: 36px; }
}
</style>
