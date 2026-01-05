// data-dev:styles-tailwind-config
/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{ts,tsx,js,jsx}'],
  theme: {
    extend: {
      colors: {
        jade: {
          50: '#e6faf2',
          100: '#c0f0db',
          200: '#96e5c3',
          300: '#69d8aa',
          400: '#3fcb93',
          500: '#19bd7f',
          600: '#00A36C',
          700: '#07885a',
          800: '#0b6d4a',
          900: '#0c5a3e',
          DEFAULT: '#00A86B',
          light: '#33B98D',
        },
        crystal: {
          50: '#f0f9ff',
          100: '#e0f2fe',
          200: '#bae6fd',
          300: '#7dd3fc',
          400: '#38bdf8',
          500: '#0ea5e9',
          600: '#0284c7',
          700: '#0369a1',
          800: '#075985',
          900: '#0c4a6e',
          DEFAULT: '#0ea5e9',
        },
        gold: {
          50: '#fffbeb',
          100: '#fef3c7',
          200: '#fde68a',
          300: '#fcd34d',
          400: '#fbbf24',
          500: '#f59e0b',
          600: '#d97706',
          700: '#b45309',
          800: '#92400e',
          900: '#78350f',
          DEFAULT: '#f59e0b',
        },
        ink: '#0A0A0A',
        snow: '#FAFAFA',
        'text-primary': '#FFFFFF',
        'text-secondary': '#8b949e',
        'text-muted': '#6e7681',
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
      },
      backgroundImage: {
        'ink-gradient':
          'radial-gradient(600px 300px at 10% 10%, rgba(0,168,107,0.12), transparent 60%)',
      },
      backdropBlur: {
        xs: '2px',
      },
    },
  },
  plugins: [],
};
