const { execSync } = require('child_process');
const plutoniumGemPath = execSync("bundle show plutonium").toString().trim();
const plutoniumTailwindConfig = require(`${plutoniumGemPath}/tailwind.options.js`)

module.exports = {
  darkMode: plutoniumTailwindConfig.darkMode,
  plugins: [
    // add plugins here
  ].concat(plutoniumTailwindConfig.plugins.map((plugin) => require(plugin))),
  theme: plutoniumTailwindConfig.theme,
  content: [
    `${__dirname}/app/**/*.rb`,
    `${__dirname}/app/views/**/*.html.erb`,
    `${__dirname}/app/helpers/**/*.rb`,
    `${__dirname}/app/assets/stylesheets/**/*.css`,
    `${__dirname}/app/javascript/**/*.js`,
    `${__dirname}/packages/**/app/**/*.rb`,
    `${__dirname}/packages/**/app/views/**/*.html.erb`,
  ].concat(plutoniumTailwindConfig.content),
}
