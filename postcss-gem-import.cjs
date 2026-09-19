// CommonJS on purpose: host apps load this by absolute path from their
// postcss.config.js. This directory's package.json declares "type": "module",
// so a .js file here is ESM, which the require()-based loader in
// postcss-load-config 4 (postcss-cli 10) passes to PostCSS as a module
// namespace instead of a plugin. A .cjs file loads under require() and
// import() alike.
const { execSync } = require('child_process');

const plugin = (opts = {}) => {
  return {
    postcssPlugin: 'postcss-gem-import',
    Once(root) {
      root.walkAtRules('import', (rule) => {
        const importPath = rule.params.replace(/['"]/g, '');

        if (importPath.startsWith('gem:')) {
          const gemName = importPath.split('gem:')[1].split('/')[0];

          try {
            const gemPath = execSync(`bundle show ${gemName}`, { encoding: 'utf8' }).trim();
            const newPath = importPath.replace(`gem:${gemName}`, gemPath);
            rule.params = `"${newPath}"`;
          } catch (error) {
            throw rule.error(`Failed to resolve gem path for ${gemName}: ${error.message}`);
          }
        }
      });
    }
  };
};

plugin.postcss = true;

module.exports = plugin;
