import { execSync } from 'child_process';

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

export default plugin;
