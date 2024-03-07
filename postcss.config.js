module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
    'postcss-hash': {
      algorithm: 'sha256',
      trim: 20,
      manifest: './assets.manifest'
    },
  }
}
