const esbuild = require('esbuild');
const manifestPlugin = require('esbuild-plugin-manifest')

esbuild.context({
  entryPoints: ["app/assets/js/plutonium.js"],
  bundle: true,
  outdir: "public/plutonium-assets/build/",
  plugins: [manifestPlugin({
    filename: `${__dirname}/js.manifest`,
    shortNames: 'input',
  })],
}).then((context) => context.watch().catch((e) => console.error(e.message)))
