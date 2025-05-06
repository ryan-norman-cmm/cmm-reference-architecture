# Design Tokens

## Introduction

Design tokens are the foundational visual elements that ensure consistency across the CMM Reference Architecture Design System. They represent the smallest visual attributes, such as colors, typography, spacing, and other visual properties that define the look and feel of our healthcare applications.

By centralizing these values as tokens, we enable consistent implementation across different platforms and technologies while facilitating theme customization and brand alignment.

## Token Categories

### Color System

Our color system is designed to meet healthcare-specific needs, including accessible contrast ratios and semantic meaning for clinical contexts.

#### Base Colors

```css
:root {
  /* Primary colors */
  --primary: 196 100% 47%; /* Healthcare blue */
  --primary-foreground: 210 40% 98%;
  
  /* Secondary colors */
  --secondary: 210 40% 96.1%;
  --secondary-foreground: 222.2 47.4% 11.2%;
  
  /* Neutral colors */
  --background: 0 0% 100%;
  --foreground: 222.2 84% 4.9%;
  --muted: 210 40% 96.1%;
  --muted-foreground: 215.4 16.3% 46.9%;
  
  /* UI element colors */
  --card: 0 0% 100%;
  --card-foreground: 222.2 84% 4.9%;
  --popover: 0 0% 100%;
  --popover-foreground: 222.2 84% 4.9%;
  --border: 214.3 31.8% 91.4%;
  --input: 214.3 31.8% 91.4%;
  
  /* Accent colors */
  --accent: 210 40% 96.1%;
  --accent-foreground: 222.2 47.4% 11.2%;
  --ring: 222.2 84% 4.9%;
}
```

#### Semantic Colors

```css
:root {
  /* Feedback colors */
  --destructive: 0 84.2% 60.2%; /* Error red */
  --destructive-foreground: 210 40% 98%;
  --success: 142 76% 36%; /* Success green */
  --success-foreground: 210 40% 98%;
  --warning: 38 92% 50%; /* Warning yellow */
  --warning-foreground: 210 40% 98%;
  --info: 196 100% 47%; /* Info blue */
  --info-foreground: 210 40% 98%;
  
  /* Healthcare-specific colors */
  --clinical: 175 84% 32%; /* Teal for clinical */
  --clinical-foreground: 0 0% 100%;
  --patient: 196 100% 47%; /* Blue for patient-facing */
  --patient-foreground: 0 0% 100%;
  --admin: 265 84% 50%; /* Purple for admin */
  --admin-foreground: 0 0% 100%;
  --pharmacy: 142 76% 36%; /* Green for pharmacy */
  --pharmacy-foreground: 0 0% 100%;
  --lab: 38 92% 50%; /* Yellow for laboratory */
  --lab-foreground: 0 0% 100%;
  --imaging: 326 100% 44%; /* Magenta for imaging */
  --imaging-foreground: 0 0% 100%;
}
```

#### Clinical Alert Colors

```css
:root {
  /* Clinical alert levels */
  --critical: 0 84.2% 60.2%; /* Critical alert red */
  --critical-foreground: 210 40% 98%;
  --high: 24 100% 62%; /* High alert orange */
  --high-foreground: 210 40% 98%;
  --medium: 38 92% 50%; /* Medium alert yellow */
  --medium-foreground: 210 40% 98%;
  --low: 142 76% 36%; /* Low alert green */
  --low-foreground: 210 40% 98%;
}
```

### Typography

Typography tokens define font families, sizes, weights, and line heights to ensure readability and hierarchy across the system.

#### Font Families

```css
:root {
  --font-sans: 'Inter', system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
  --font-mono: 'JetBrains Mono', monospace;
}
```

#### Font Sizes

```css
:root {
  --font-size-xs: 0.75rem; /* 12px */
  --font-size-sm: 0.875rem; /* 14px */
  --font-size-base: 1rem; /* 16px */
  --font-size-lg: 1.125rem; /* 18px */
  --font-size-xl: 1.25rem; /* 20px */
  --font-size-2xl: 1.5rem; /* 24px */
  --font-size-3xl: 1.875rem; /* 30px */
  --font-size-4xl: 2.25rem; /* 36px */
  --font-size-5xl: 3rem; /* 48px */
}
```

#### Font Weights

```css
:root {
  --font-weight-light: 300;
  --font-weight-normal: 400;
  --font-weight-medium: 500;
  --font-weight-semibold: 600;
  --font-weight-bold: 700;
}
```

#### Line Heights

```css
:root {
  --line-height-none: 1;
  --line-height-tight: 1.25;
  --line-height-snug: 1.375;
  --line-height-normal: 1.5;
  --line-height-relaxed: 1.625;
  --line-height-loose: 2;
}
```

### Spacing

Spacing tokens ensure consistent margins, padding, and layout spacing throughout the application.

```css
:root {
  --spacing-0: 0px;
  --spacing-px: 1px;
  --spacing-0-5: 0.125rem; /* 2px */
  --spacing-1: 0.25rem; /* 4px */
  --spacing-1-5: 0.375rem; /* 6px */
  --spacing-2: 0.5rem; /* 8px */
  --spacing-2-5: 0.625rem; /* 10px */
  --spacing-3: 0.75rem; /* 12px */
  --spacing-3-5: 0.875rem; /* 14px */
  --spacing-4: 1rem; /* 16px */
  --spacing-5: 1.25rem; /* 20px */
  --spacing-6: 1.5rem; /* 24px */
  --spacing-7: 1.75rem; /* 28px */
  --spacing-8: 2rem; /* 32px */
  --spacing-9: 2.25rem; /* 36px */
  --spacing-10: 2.5rem; /* 40px */
  --spacing-11: 2.75rem; /* 44px */
  --spacing-12: 3rem; /* 48px */
  --spacing-14: 3.5rem; /* 56px */
  --spacing-16: 4rem; /* 64px */
  --spacing-20: 5rem; /* 80px */
  --spacing-24: 6rem; /* 96px */
  --spacing-28: 7rem; /* 112px */
  --spacing-32: 8rem; /* 128px */
  --spacing-36: 9rem; /* 144px */
  --spacing-40: 10rem; /* 160px */
  --spacing-44: 11rem; /* 176px */
  --spacing-48: 12rem; /* 192px */
  --spacing-52: 13rem; /* 208px */
  --spacing-56: 14rem; /* 224px */
  --spacing-60: 15rem; /* 240px */
  --spacing-64: 16rem; /* 256px */
  --spacing-72: 18rem; /* 288px */
  --spacing-80: 20rem; /* 320px */
  --spacing-96: 24rem; /* 384px */
}
```

### Elevation

Elevation tokens define shadow values for creating depth and hierarchy in the interface.

```css
:root {
  --shadow-sm: 0 1px 2px 0 rgb(0 0 0 / 0.05);
  --shadow: 0 1px 3px 0 rgb(0 0 0 / 0.1), 0 1px 2px -1px rgb(0 0 0 / 0.1);
  --shadow-md: 0 4px 6px -1px rgb(0 0 0 / 0.1), 0 2px 4px -2px rgb(0 0 0 / 0.1);
  --shadow-lg: 0 10px 15px -3px rgb(0 0 0 / 0.1), 0 4px 6px -4px rgb(0 0 0 / 0.1);
  --shadow-xl: 0 20px 25px -5px rgb(0 0 0 / 0.1), 0 8px 10px -6px rgb(0 0 0 / 0.1);
  --shadow-2xl: 0 25px 50px -12px rgb(0 0 0 / 0.25);
  --shadow-inner: inset 0 2px 4px 0 rgb(0 0 0 / 0.05);
}
```

### Border Radius

Border radius tokens ensure consistent rounding of corners throughout the interface.

```css
:root {
  --radius-none: 0px;
  --radius-sm: 0.125rem; /* 2px */
  --radius: 0.5rem; /* 8px */
  --radius-md: calc(var(--radius) - 2px);
  --radius-lg: 0.75rem; /* 12px */
  --radius-xl: 1rem; /* 16px */
  --radius-2xl: 1.5rem; /* 24px */
  --radius-3xl: 2rem; /* 32px */
  --radius-full: 9999px;
}
```

### Animation

Animation tokens define standard timing functions and durations for consistent motion design.

```css
:root {
  /* Durations */
  --duration-75: 75ms;
  --duration-100: 100ms;
  --duration-150: 150ms;
  --duration-200: 200ms;
  --duration-300: 300ms;
  --duration-500: 500ms;
  --duration-700: 700ms;
  --duration-1000: 1000ms;
  
  /* Timing functions */
  --ease-linear: linear;
  --ease-in: cubic-bezier(0.4, 0, 1, 1);
  --ease-out: cubic-bezier(0, 0, 0.2, 1);
  --ease-in-out: cubic-bezier(0.4, 0, 0.2, 1);
}
```

## Implementation

### CSS Variables

Design tokens are implemented as CSS variables in the global stylesheet, making them available throughout the application.

### Tailwind Configuration

For projects using Tailwind CSS, tokens are mapped in the Tailwind configuration file:

```js
// tailwind.config.js
const { fontFamily } = require("tailwindcss/defaultTheme")

/** @type {import('tailwindcss').Config} */
module.exports = {
  darkMode: ["class"],
  content: ["./src/**/*.{js,jsx,ts,tsx}"],
  theme: {
    container: {
      center: true,
      padding: "2rem",
      screens: {
        "2xl": "1400px",
      },
    },
    extend: {
      colors: {
        border: "hsl(var(--border))",
        input: "hsl(var(--input))",
        ring: "hsl(var(--ring))",
        background: "hsl(var(--background))",
        foreground: "hsl(var(--foreground))",
        primary: {
          DEFAULT: "hsl(var(--primary))",
          foreground: "hsl(var(--primary-foreground))",
        },
        // ... other color mappings
      },
      borderRadius: {
        lg: "var(--radius-lg)",
        md: "var(--radius-md)",
        sm: "var(--radius-sm)",
      },
      fontFamily: {
        sans: ["var(--font-sans)", ...fontFamily.sans],
        mono: ["var(--font-mono)", ...fontFamily.mono],
      },
      // ... other token mappings
    },
  },
  plugins: [require("tailwindcss-animate")],
}
```

### Dark Mode

Dark mode is implemented by providing alternative values for tokens in a `.dark` selector:

```css
.dark {
  --background: 222.2 84% 4.9%;
  --foreground: 210 40% 98%;
  --card: 222.2 84% 4.9%;
  --card-foreground: 210 40% 98%;
  /* ... other dark mode token values */
}
```

## Theming and Customization

The design system supports theming through token customization. Organizations can create their own themes by overriding token values to match their brand guidelines while maintaining the underlying component structure.

### Theme Example: Pediatric Healthcare

```css
:root.theme-pediatric {
  /* More vibrant, child-friendly colors */
  --primary: 196 90% 60%;
  --primary-foreground: 210 40% 98%;
  
  /* Rounded corners for a friendlier feel */
  --radius: 0.75rem;
  --radius-md: 0.5rem;
  --radius-sm: 0.25rem;
  
  /* ... other customized token values */
}
```

## Accessibility Considerations

Design tokens are defined with accessibility in mind:

- Color combinations meet WCAG 2.1 AA contrast requirements
- Font sizes support readability and scaling
- Animation durations consider users who prefer reduced motion

## Conclusion

Design tokens form the foundation of our design system, ensuring visual consistency while enabling customization. By centralizing these values, we create a single source of truth that can be implemented across different platforms and technologies, resulting in a cohesive user experience throughout our healthcare applications.
