import { context as _context, build as _build } from 'esbuild';
import manifestPlugin from 'esbuild-plugin-manifest';


if (process.argv.includes("--dev")) {
  _context({
    outdir: "src/build",
    entryPoints: [
      "src/js/plutonium.js"
    ],
    plugins: [
      manifestPlugin({
        filename: `js.manifest`,
        shortNames: true,
      })
    ],
    bundle: true,
  }).then((context) => context.watch().catch((e) => console.error(e.message)))
}
else {
  function build(minify) {
    const outExtension = minify ? { '.js': '.min.js' } : { '.js': '.js' }
    _build({
      outdir: "src/dist/js",
      entryPoints: [
        "src/js/plutonium.js",
      ],
      minify,
      sourcemap: true,
      bundle: true,
      outExtension
    }).catch(() => process.exit(1));

    _build({
      outdir: "app/assets",
      entryPoints: [
        "src/js/plutonium.js"
      ],
      minify,
      sourcemap: true,
      bundle: true,
      outExtension
    }).catch(() => process.exit(1));
  }

  build(true)
  build(false)
}
