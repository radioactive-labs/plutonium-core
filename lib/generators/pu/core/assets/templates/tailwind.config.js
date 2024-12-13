const { execSync } = require('child_process');
const plutoniumGemPath = execSync("bundle show plutonium").toString().trim();
const plutoniumTailwindConfig = require(`${plutoniumGemPath}/tailwind.options.js`)
const tailwindPlugin = require('tailwindcss/plugin')

module.exports = {
  darkMode: plutoniumTailwindConfig.darkMode,
  plugins: [
    // add plugins here
  ].concat(plutoniumTailwindConfig.plugins.map(function (plugin) {
    switch (typeof plugin) {
      case "function":
        return tailwindPlugin(plugin)
      case "string":
        return require(plugin)
      default:
        throw Error(`unsupported plugin: ${plugin}: ${(typeof plugin)}`)
    }
  })),
  theme: plutoniumTailwindConfig.merge(
    {
    },
    plutoniumTailwindConfig.theme
  ),
  content: [
    `${__dirname}/app/**/*.{erb,haml,html,slim,rb}`,
    `${__dirname}/app/assets/stylesheets/**/*.css`,
    `${__dirname}/app/javascript/**/*.js`,
    `${__dirname}/packages/**/app/**/*.{erb,haml,html,slim,rb}`,
  ].concat(plutoniumTailwindConfig.content),
}
