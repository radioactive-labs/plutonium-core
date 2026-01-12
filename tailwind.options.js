export const content = [
  `${__dirname}/src/js/**/*.js`,
  `${__dirname}/app/views/**/*.{rb,erb,js}`,
  `${__dirname}/lib/plutonium/**/*.rb`,
];

export const darkMode = "selector";

export const plugins = [
  // requires users to have the required packages installed in their own project.
  "@tailwindcss/forms",
  "@tailwindcss/typography",
  "flowbite-typography",
  function ({ addVariant }) {
    // This creates a variant that applies when an ancestor has data-dyna="true"
    addVariant('dyna', ':where(.dyna, .dyna *) &')
  }
];

export const theme = {
  extend: {
    typography: ({ theme }) => ({
      primary: {
        css: {
          '--tw-prose-body': theme('colors.gray.900'),
          '--tw-prose-headings': theme('colors.gray.900'),
          '--tw-prose-lead': theme('colors.gray.600'),
          '--tw-prose-links': theme('colors.primary.700'),
          '--tw-prose-bold': theme('colors.gray.900'),
          '--tw-prose-counters': theme('colors.gray.600'),
          '--tw-prose-bullets': theme('colors.gray.600'),
          '--tw-prose-hr': theme('colors.gray.200'),
          '--tw-prose-quotes': theme('colors.gray.900'),
          '--tw-prose-quote-borders': theme('colors.gray.300'),
          '--tw-prose-captions': theme('colors.gray.700'),
          '--tw-prose-code': theme('colors.gray.900'),
          '--tw-prose-code-bg': theme('colors.primary.50'),
          '--tw-prose-pre-code': theme('colors.primary.100'),
          '--tw-prose-pre-bg': theme('colors.gray.900'),
          '--tw-prose-th-borders': theme('colors.gray.300'),
          '--tw-prose-td-borders': theme('colors.gray.200'),
          '--tw-prose-th-bg': theme('colors.gray.100'),

          // Dark mode
          '--tw-prose-invert-body': theme('colors.white'),
          '--tw-prose-invert-headings': theme('colors.secondary.100'),
          '--tw-prose-invert-lead': theme('colors.secondary.400'),
          '--tw-prose-invert-links': theme('colors.primary.500'),
          '--tw-prose-invert-bold': theme('colors.secondary.100'),
          '--tw-prose-invert-counters': theme('colors.gray.400'),
          '--tw-prose-invert-bullets': theme('colors.gray.400'),
          '--tw-prose-invert-hr': theme('colors.primary.800'),
          '--tw-prose-invert-quotes': theme('colors.secondary.100'),
          '--tw-prose-invert-quote-borders': theme('colors.gray.500'),
          '--tw-prose-invert-captions': theme('colors.secondary.300'),
          '--tw-prose-invert-code': theme('colors.secondary.100'),
          '--tw-prose-invert-code-bg': theme('colors.primary.950'),
          '--tw-prose-invert-pre-code': theme('colors.primary.900'),
          '--tw-prose-invert-pre-bg': theme('colors.secondary.100'),
          '--tw-prose-invert-th-borders': theme('colors.gray.600'),
          '--tw-prose-invert-td-borders': theme('colors.gray.700'),
          '--tw-prose-invert-th-bg': theme('colors.gray.800'),
        },
      },
    }),
    // Semantic spacing scale - affects padding, margin, gap, space utilities
    spacing: {
      'xs': '0.5rem',    // 8px - extra small spacing
      'sm': '0.75rem',   // 12px - small spacing (inputs, buttons, small gaps)
      'md': '1rem',      // 16px - medium spacing (cards, tabs, standard gaps)
      'lg': '1.5rem',    // 24px - large spacing (forms, displays, large spacing)
      'xl': '2rem',      // 32px - extra large spacing
      '2xl': '2.5rem',   // 40px - 2x extra large spacing
      '3xl': '3rem',     // 48px - 3x extra large spacing
    },
    colors: {
      // Semantic background colors for theming - minimal, modern palette
      surface: {
        DEFAULT: '#ffffff',           // Light mode surface (cards, forms, tables, panels)
        dark: '#1f2937',              // Dark mode surface - gray-800
      },
      page: {
        DEFAULT: 'rgb(248 248 248)',  // Light mode page - neutral gray
        dark: '#111827',              // Dark mode page - gray-900
      },
      elevated: {
        DEFAULT: 'rgb(244 244 245)',  // Light mode elevated - subtle
        dark: '#374151',              // Dark mode elevated - gray-700
      },
      interactive: {
        DEFAULT: 'rgb(244 244 245)',  // Light mode hover - subtle
        dark: '#374151',              // Dark mode hover - gray-700
      },

      // Brand colors
      primary: {
        50: '#F0FDFD',
        100: '#E0FAFA',
        200: '#BAF3F5',
        300: '#7DE8EC',
        400: '#40D9DE',
        500: '#17B8BE', // Turquoise
        600: '#0E8F94',
        700: '#0B6D71',
        800: '#0A5558',
        900: '#084547',
        950: '#042F30',
      },
      secondary: {
        50: '#F2F5F8',
        100: '#E6ECF1',
        200: '#C7D5E1',
        300: '#9DB3C7',
        400: '#678CAB',
        500: '#1E3D59', // Navy
        600: '#1A3549',
        700: '#152C3D',
        800: '#102231',
        900: '#0C1B26',
        950: '#080F15',
      },
      success: {
        50: '#F0FDF4',
        100: '#DCFCE7',
        200: '#BBF7D0',
        300: '#86EFAC',
        400: '#4ADE80',
        500: '#22C55E', // Base color
        600: '#16A34A',
        700: '#15803D',
        800: '#166534',
        900: '#14532D',
        950: '#052E16',
      },
      info: {
        50: '#F0F9FF',
        100: '#E0F2FE',
        200: '#BAE6FD',
        300: '#7DD3FC',
        400: '#38BDF8',
        500: '#0EA5E9', // Base color
        600: '#0284C7',
        700: '#0369A1',
        800: '#075985',
        900: '#0C4A6E',
        950: '#082F49',
      },
      warning: {
        50: '#FFFBEB',
        100: '#FEF3C7',
        200: '#FDE68A',
        300: '#FCD34D',
        400: '#FBBF24',
        500: '#F59E0B', // Base color
        600: '#D97706',
        700: '#B45309',
        800: '#92400E',
        900: '#78350F',
        950: '#451A03',
      },
      danger: {
        50: '#FEF2F2',
        100: '#FEE2E2',
        200: '#FECACA',
        300: '#FCA5A5',
        400: '#F87171',
        500: '#EF4444', // Base color
        600: '#DC2626',
        700: '#B91C1C',
        800: '#991B1B',
        900: '#7F1D1D',
        950: '#450A0A',
      },
      accent: {
        50: '#FFF1F3',
        100: '#FFE4E7',
        200: '#FFCCD2',
        300: '#FFB1BA',
        400: '#FF9EAA',
        500: '#FF8394', // Coral Pink
        600: '#FF647A',
        700: '#E73D55',
        800: '#D12D44',
        900: '#B02438',
        950: '#8E1525',
      },
    },
    screens: {
      'xs': '475px',
    }
  },
  fontFamily: {
    'body': [
      'Lato',
      'ui-sans-serif',
      'system-ui',
      '-apple-system',
      'system-ui',
      'Segoe UI',
      'Roboto',
      'Helvetica Neue',
      'Arial',
      'Noto Sans',
      'sans-serif',
      'Apple Color Emoji',
      'Segoe UI Emoji',
      'Segoe UI Symbol',
      'Noto Color Emoji'
    ],
    'sans': [
      'Lato',
      'ui-sans-serif',
      'system-ui',
      '-apple-system',
      'system-ui',
      'Segoe UI',
      'Roboto',
      'Helvetica Neue',
      'Arial',
      'Noto Sans',
      'sans-serif',
      'Apple Color Emoji',
      'Segoe UI Emoji',
      'Segoe UI Symbol',
      'Noto Color Emoji'
    ],
    'mono': [
      'ui-monospace',
      'SFMono-Regular',
      'Menlo',
      'Monaco',
      'Consolas',
      'Liberation Mono',
      'Courier New',
      'monospace'
    ]
  },
};

export const safelist = [
  // Col span classes
  {
    pattern: /^col-span-/,
    variants: ['sm', 'md', 'lg', 'xl', '2xl'],
  },
  // Col start classes
  {
    pattern: /^col-start-/,
    variants: ['sm', 'md', 'lg', 'xl', '2xl'],
  },
  // Col end classes
  {
    pattern: /^col-end-/,
    variants: ['sm', 'md', 'lg', 'xl', '2xl'],
  },
  // Row span classes
  {
    pattern: /^row-span-/,
    variants: ['sm', 'md', 'lg', 'xl', '2xl'],
  },
  // Row start classes
  {
    pattern: /^row-start-/,
    variants: ['sm', 'md', 'lg', 'xl', '2xl'],
  },
  // Row end classes
  {
    pattern: /^row-end-/,
    variants: ['sm', 'md', 'lg', 'xl', '2xl'],
  },
]

export const merge = function (...configs) {
  function isObject(item) {
    return item && typeof item === 'object' && !Array.isArray(item);
  }

  function mergeArrays(target, source) {
    // Combine arrays and remove duplicates for simple values
    if (target.every(item => typeof item === 'string')) {
      return [...new Set([...target, ...source])];
    }
    // For arrays of objects or complex types, concatenate
    return [...target, ...source];
  }

  function deepMerge(target, source) {
    if (!isObject(target) || !isObject(source)) {
      return source;
    }

    const output = { ...target };

    Object.keys(source).forEach(key => {
      const targetValue = output[key];
      const sourceValue = source[key];

      if (Array.isArray(targetValue) && Array.isArray(sourceValue)) {
        output[key] = mergeArrays(targetValue, sourceValue);
      } else if (isObject(targetValue) && isObject(sourceValue)) {
        // Handle function properties (like theme functions in Tailwind)
        if (typeof targetValue === 'function' || typeof sourceValue === 'function') {
          output[key] = sourceValue;
        } else {
          output[key] = deepMerge(targetValue, sourceValue);
        }
      } else {
        output[key] = sourceValue;
      }
    });

    return output;
  }

  // Reduce all configs into a single merged config
  return configs.reduce((merged, config) => deepMerge(merged, config), {});
}

// // Object.keys(colors).forEach((color) => {
// //   if (typeof colors[color] === 'object') {
// //     Object.keys(colors[color]).forEach((shade) => {
// //       safelist.push(`bg-${color}-${shade}`);
// //       safelist.push(`text-${color}-${shade}`);
// //       // Add other utilities as needed
// //     });
// //   }
// // });
// export const safelist = _safelist;
