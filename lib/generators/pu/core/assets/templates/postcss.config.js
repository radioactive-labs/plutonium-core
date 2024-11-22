const { execSync } = require('child_process');
const plutoniumGemPath = execSync("bundle show plutonium").toString().trim();

module.exports = {
  plugins: {
    [`${plutoniumGemPath}/postcss-gem-import.js`]: {},
    'postcss-import': {},
    tailwindcss: {},
    autoprefixer: {},
    cssnano: {}
  }
}
