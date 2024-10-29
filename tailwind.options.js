export const content = [
  `${__dirname}/src/**/*.{css,js}`,
  `${__dirname}/app/views/**/*.{rb,erb,js}`,
  `${__dirname}/config/initializers/simple_form.rb`,
  `${__dirname}/lib/plutonium/**/*.rb`,

  // node modules are not packaged as part of the gem.
  // requires users to have flowbite installed in their own project.
  './node_modules/flowbite/**/*.js',
];
export const darkMode = "selector";
export const plugins = [
  // requires users to have the required packages installed in their own project.
  "@tailwindcss/forms",
  "flowbite/plugin"
];
export const theme = {
  extend: {
    colors: {
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
    },
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
  }
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
