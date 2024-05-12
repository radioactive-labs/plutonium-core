const esbuild = require('esbuild');
const manifestPlugin = require('esbuild-plugin-manifest')


if (process.argv.includes("--prod")) {
  esbuild.build({
    outdir: "public/plutonium-assets",
    entryPoints: [
      "app/assets/javascripts/plutonium-app.js"
    ],
    plugins: [
      manifestPlugin({
        filename: `${__dirname}/js.manifest`,
        shortNames: true,
      })
    ],
    minify: true,
    sourcemap: true,
    bundle: true,
  })

  esbuild.build({
    outdir: "app/assets/build",
    entryPoints: [
      "app/assets/javascripts/plutonium.js"
    ],
    bundle: true,
  })
}
else {
  esbuild.context({
    outdir: "public/plutonium-assets/build",
    entryPoints: [
      "app/assets/javascripts/plutonium-app.js"
    ],
    plugins: [
      manifestPlugin({
        filename: `${__dirname}/js.dev.manifest`,
        shortNames: true,
      })
    ],
    bundle: true,
  }).then((context) => context.watch().catch((e) => console.error(e.message)))
}
