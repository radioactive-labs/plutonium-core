const config = {
  plugins: {
    'postcss-import': {},
    '@tailwindcss/postcss': {}
  }
}

if (process.argv.includes("--dev")) {
  config.plugins['postcss-hash'] = {
    algorithm: 'sha256',
    trim: 20,
    manifest: './src/build/css.manifest'
  }
}
else {
  config.plugins['cssnano'] = {
    preset: 'default',
  }
}

export default config
