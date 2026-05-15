<template>
  <section class="pu-section home-stop-writing">
    <div class="pu-section-inner">
      <h2 class="pu-section-title">What you stop writing.</h2>
      <p class="hsw-sub">A blog with posts, comments, an admin panel, and authorization. Same feature, two paths.</p>

      <div class="hsw-grid">
        <div>
          <span class="hsw-label hsw-label--bad">Hand-rolled</span>
          <div class="hsw-filetree">
            app/controllers/posts_controller.rb<br>
            app/views/posts/*.html.erb<br>
            app/policies/post_policy.rb<br>
            <span class="dim">…before search, filters, bulk actions, auth…</span>
          </div>
          <div class="hsw-stats">
            <span>Just <b>CRUD</b></span>
            <span>No <b>auth</b></span>
            <span>No <b>search</b></span>
          </div>
        </div>
        <div>
          <span class="hsw-label hsw-label--good">Plutonium</span>
          <pre class="pu-term pu-term--inline hsw-term"><span class="prompt">$</span> rails g pu:res:scaffold Post title:string body:text
<span class="prompt">$</span> rails g pu:res:conn Post --dest=admin_portal</pre>
          <div class="hsw-stats hsw-stats--win">
            <span><b>Full CRUD</b></span>
            <span><b>+ Auth</b></span>
            <span><b>+ Search</b></span>
            <span><b>+ Filters</b></span>
            <span><b>+ Bulk actions</b></span>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>

<style scoped>
.hsw-sub { color: var(--pu-text-muted); font-size: 15px; margin: -16px 0 32px; }
.hsw-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 24px; align-items: stretch; }
.hsw-grid > div { display: flex; flex-direction: column; }
.hsw-stats { margin-top: auto; }
.hsw-label {
  display: inline-block; font-size: 11px; padding: 3px 8px; border-radius: 4px;
  text-transform: uppercase; letter-spacing: 0.08em; font-weight: 600;
}
.hsw-label--bad { background: #fff0f0; color: var(--pu-accent); }
.hsw-label--good { background: var(--pu-success-bg); color: var(--pu-success-fg); }
.hsw-filetree {
  margin-top: 10px;
  background: var(--pu-bg-band); border: 1px solid var(--pu-border-soft);
  border-radius: 8px; padding: 14px;
  font-family: ui-monospace, monospace; font-size: 12px; line-height: 1.75; color: var(--pu-text-muted);
}
.hsw-filetree .dim { color: var(--pu-text-faint); }
.hsw-term { margin-top: 10px; }
.hsw-stats {
  padding-top: 14px; display: flex; gap: 14px; flex-wrap: wrap;
  font-size: 11.5px; text-transform: uppercase; letter-spacing: 0.08em; color: var(--pu-text-faint);
}
.hsw-stats b { color: var(--pu-text); font-weight: 600; }
.hsw-stats--win b { color: var(--pu-success-fg); }
@media (max-width: 768px) { .hsw-grid { grid-template-columns: 1fr; } }
</style>
