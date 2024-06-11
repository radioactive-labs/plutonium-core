const { execSync } = require('child_process');
const plutoniumGemPath = execSync("bundle show plutonium").toString().trim();
const plutoniumTailwindConfig = require(`${plutoniumGemPath}/tailwind.config.js`)

module.exports = {
  darkMode: plutoniumTailwindConfig.darkMode,
  plugins: [
    // add plugins here
  ].concat(plutoniumTailwindConfig.plugins),
  theme: plutoniumTailwindConfig.theme,
  content: [
    `${__dirname}/app/views/**/*.html.erb`,
    `${__dirname}/app/helpers/**/*.rb`,
    `${__dirname}/app/assets/stylesheets/**/*.css`,
    `${__dirname}/app/javascript/**/*.js`,
    `${__dirname}/app/plutonium/**/*.rb`,
    `${__dirname}/packages/**/app/plutonium/**/*.rb`,
    `${__dirname}/packages/**/app/views/**/*.html.erb`,
  ].concat(plutoniumTailwindConfig.content),
}
