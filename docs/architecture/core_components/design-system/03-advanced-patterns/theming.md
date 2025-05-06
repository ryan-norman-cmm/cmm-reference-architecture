# Theming and Customization

## Introduction

The CMM Technology Platform Design System supports comprehensive theming and customization to meet the diverse needs of healthcare organizations. This document outlines the advanced patterns and techniques for customizing the design system while maintaining consistency, accessibility, and performance.

## Theming Architecture

Our theming architecture is built on a foundation of design tokens implemented as CSS variables, with support for multiple themes, dark mode, and organization-specific customizations.

### Design Token Structure

Design tokens are organized in a hierarchical structure:

1. **Global Tokens**: Base values that define the fundamental design elements
2. **Semantic Tokens**: Purpose-based tokens that reference global tokens
3. **Component Tokens**: Component-specific tokens that reference semantic tokens

This structure allows for targeted customization at different levels without breaking the overall design system.

```css
/* Example of token hierarchy */
:root {
  /* Global tokens */
  --blue-50: 240 100% 98%;
  --blue-100: 240 100% 95%;
  /* ... */
  --blue-900: 240 100% 20%;
  
  /* Semantic tokens */
  --primary: var(--blue-600);
  --primary-foreground: var(--white);
  
  /* Component tokens */
  --button-background: var(--primary);
  --button-foreground: var(--primary-foreground);
}
```

### Theme Configuration

Themes are defined as sets of token overrides applied to specific contexts. The design system supports:

1. **Base Theme**: Default appearance for all applications
2. **Organization Themes**: Custom themes for specific healthcare organizations
3. **Product Themes**: Variations for different product lines (clinical, administrative, patient-facing)
4. **Dark Mode**: Optimized for low-light environments
5. **High Contrast Mode**: Enhanced contrast for accessibility

## Implementation Techniques

### CSS Variable Approach

The primary theming mechanism uses CSS variables for runtime theme switching:

```css
/* Base theme */
:root {
  --primary: 196 100% 47%;
  --primary-foreground: 210 40% 98%;
  /* Other token values */
}

/* Dark theme */
.dark-theme {
  --primary: 196 100% 47%;
  --primary-foreground: 222.2 47.4% 11.2%;
  /* Other dark theme token values */
}

/* Pediatric theme */
.pediatric-theme {
  --primary: 152 76% 50%;
  --primary-foreground: 210 40% 98%;
  /* Other pediatric theme token values */
}
```

### Theme Switching

Themes can be switched dynamically using JavaScript:

```jsx
function ThemeProvider({ children, theme = 'default' }) {
  useEffect(() => {
    // Remove any existing theme classes
    document.documentElement.classList.remove(
      'dark-theme',
      'pediatric-theme',
      'high-contrast-theme'
    );
    
    // Add the selected theme class
    if (theme !== 'default') {
      document.documentElement.classList.add(`${theme}-theme`);
    }
  }, [theme]);
  
  return children;
}
```

### User Preference Detection

The design system automatically detects and respects user preferences:

```css
/* Detect user preference for dark mode */
@media (prefers-color-scheme: dark) {
  :root:not(.light-theme) {
    --background: 222.2 84% 4.9%;
    --foreground: 210 40% 98%;
    /* Other dark mode values */
  }
}

/* Detect user preference for reduced motion */
@media (prefers-reduced-motion: reduce) {
  :root {
    --animation-duration-fast: 0.001ms;
    --animation-duration-medium: 0.001ms;
    --animation-duration-slow: 0.001ms;
  }
}
```

## Advanced Customization Patterns

### Multi-Brand Support

For healthcare systems with multiple brands or facilities, the design system supports multi-brand configurations:

```jsx
const brandConfig = {
  'main-hospital': {
    primary: '196 100% 47%',
    logo: '/assets/main-hospital-logo.svg',
    // Other brand values
  },
  'childrens-hospital': {
    primary: '152 76% 50%',
    logo: '/assets/childrens-hospital-logo.svg',
    // Other brand values
  },
  'behavioral-health': {
    primary: '265 84% 50%',
    logo: '/assets/behavioral-health-logo.svg',
    // Other brand values
  }
};

function BrandProvider({ children, brand = 'main-hospital' }) {
  const brandValues = brandConfig[brand] || brandConfig['main-hospital'];
  
  useEffect(() => {
    // Apply brand-specific CSS variables
    Object.entries(brandValues).forEach(([key, value]) => {
      if (typeof value === 'string' && !key.includes('logo')) {
        document.documentElement.style.setProperty(`--${key}`, value);
      }
    });
  }, [brand, brandValues]);
  
  return (
    <BrandContext.Provider value={brandValues}>
      {children}
    </BrandContext.Provider>
  );
}
```

### Component Variant Customization

Components can be customized through variant configurations:

```jsx
// Default button variants
const buttonVariants = cva(
  'inline-flex items-center justify-center rounded-md text-sm font-medium ring-offset-background transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50',
  {
    variants: {
      variant: {
        default: 'bg-primary text-primary-foreground hover:bg-primary/90',
        destructive: 'bg-destructive text-destructive-foreground hover:bg-destructive/90',
        outline: 'border border-input bg-background hover:bg-accent hover:text-accent-foreground',
        secondary: 'bg-secondary text-secondary-foreground hover:bg-secondary/80',
        ghost: 'hover:bg-accent hover:text-accent-foreground',
        link: 'text-primary underline-offset-4 hover:underline',
      },
      size: {
        default: 'h-10 px-4 py-2',
        sm: 'h-9 rounded-md px-3',
        lg: 'h-11 rounded-md px-8',
        icon: 'h-10 w-10',
      },
    },
    defaultVariants: {
      variant: 'default',
      size: 'default',
    },
  }
);

// Organization-specific button variant customization
const customButtonVariants = {
  variants: {
    variant: {
      // Add organization-specific variants
      urgent: 'bg-critical text-white font-bold hover:bg-critical/90',
      success: 'bg-success text-white hover:bg-success/90',
    },
    // Add organization-specific sizes
    size: {
      xl: 'h-14 rounded-md px-10 text-lg',
    },
  },
};

// Merge default and custom variants
const mergedButtonVariants = mergeVariantConfig(buttonVariants, customButtonVariants);
```

### Runtime Theme Generation

For advanced use cases, themes can be generated dynamically based on a primary color:

```jsx
function generateThemeFromColor(primaryColor) {
  // Convert hex to HSL
  const hsl = hexToHSL(primaryColor);
  
  // Generate a color palette based on the primary color
  const palette = generateColorPalette(hsl);
  
  // Create theme object
  return {
    primary: `${palette.primary.hue} ${palette.primary.saturation}% ${palette.primary.lightness}%`,
    secondary: `${palette.secondary.hue} ${palette.secondary.saturation}% ${palette.secondary.lightness}%`,
    // Generate other colors
  };
}

function DynamicThemeProvider({ children, primaryColor = '#0284c7' }) {
  const theme = useMemo(() => generateThemeFromColor(primaryColor), [primaryColor]);
  
  useEffect(() => {
    // Apply generated theme
    Object.entries(theme).forEach(([key, value]) => {
      document.documentElement.style.setProperty(`--${key}`, value);
    });
  }, [theme]);
  
  return children;
}
```

## Healthcare-Specific Theming Considerations

### Clinical Environment Optimization

Themes optimized for clinical environments address specific needs:

- **Reduced Eye Strain**: Color palettes designed for long-term use
- **Night Mode**: Ultra-dark themes for nighttime clinical work
- **High Visibility**: Enhanced contrast for critical information
- **Distraction Reduction**: Minimal animations and visual noise

```css
/* Night mode for clinical environments */
.clinical-night-theme {
  --background: 220 20% 2%;
  --foreground: 220 10% 80%;
  
  /* Muted colors to reduce eye strain */
  --primary: 220 70% 40%;
  --red: 0 70% 40%;
  --yellow: 40 70% 40%;
  
  /* Reduced brightness for all elements */
  --brightness-adjustment: 0.8;
  
  /* Apply brightness adjustment */
  & * {
    filter: brightness(var(--brightness-adjustment));
  }
}
```

### Regulatory Compliance

Theming must maintain compliance with healthcare regulations:

- **Consistent Alert Colors**: Standardized colors for clinical alerts
- **Information Hierarchy**: Clear visual hierarchy for critical information
- **Readability Standards**: Minimum text sizes and contrast ratios
- **Status Indicators**: Consistent visual language for system status

```css
/* Standardized clinical alert colors */
:root {
  /* These values should not be overridden by custom themes */
  --clinical-critical: 0 84.2% 60.2%;
  --clinical-high: 24 100% 62%;
  --clinical-medium: 38 92% 50%;
  --clinical-low: 142 76% 36%;
  --clinical-normal: 220 10% 45%;
}
```

### Accessibility Maintenance

Custom themes must maintain accessibility standards:

```jsx
function validateThemeAccessibility(theme) {
  const validationResults = [];
  
  // Check contrast ratios
  const backgroundHSL = parseHSL(theme.background);
  const foregroundHSL = parseHSL(theme.foreground);
  const contrastRatio = calculateContrastRatio(backgroundHSL, foregroundHSL);
  
  if (contrastRatio < 4.5) {
    validationResults.push({
      type: 'error',
      message: `Text contrast ratio (${contrastRatio.toFixed(2)}) is below WCAG AA standard (4.5)`
    });
  }
  
  // Check other accessibility requirements
  // ...
  
  return validationResults;
}

function ThemeCustomizer({ onChange }) {
  const [theme, setTheme] = useState(defaultTheme);
  const validationResults = validateThemeAccessibility(theme);
  
  // Render theme customization UI with validation feedback
  // ...
}
```

## Theme Documentation and Governance

### Theme Documentation

All themes should be documented with:

- **Color Palette**: Complete color specifications
- **Typography Scale**: Font families, sizes, and weights
- **Component Variants**: Available component variants
- **Usage Guidelines**: When and how to use the theme
- **Accessibility Compliance**: Validation results and considerations

### Theme Governance

Implement governance processes for theme creation and modification:

1. **Theme Proposal**: Documentation of business need and design approach
2. **Design Review**: Evaluation by design team for brand alignment
3. **Accessibility Review**: Validation of accessibility compliance
4. **Technical Review**: Implementation approach and performance impact
5. **Approval Process**: Final sign-off from stakeholders
6. **Version Control**: Theme versioning and change management

## Integration Examples

### Application Configuration

```jsx
// App entry point with theme configuration
import { ThemeProvider } from '@/components/theme-provider';
import { BrandProvider } from '@/components/brand-provider';

function App({ organization = 'main-hospital' }) {
  return (
    <BrandProvider brand={organization}>
      <ThemeProvider>
        <Router>
          {/* Application routes */}
        </Router>
      </ThemeProvider>
    </BrandProvider>
  );
}
```

### User Preference Management

```jsx
// User theme preference management
function ThemeSettings() {
  const { theme, setTheme } = useTheme();
  const { colorMode, setColorMode } = useColorMode();
  
  return (
    <div className="theme-settings">
      <h2>Display Settings</h2>
      
      <div className="setting-group">
        <h3>Theme</h3>
        <RadioGroup value={theme} onValueChange={setTheme}>
          <RadioItem value="default">Default</RadioItem>
          <RadioItem value="high-contrast">High Contrast</RadioItem>
          {/* Other theme options */}
        </RadioGroup>
      </div>
      
      <div className="setting-group">
        <h3>Color Mode</h3>
        <RadioGroup value={colorMode} onValueChange={setColorMode}>
          <RadioItem value="light">Light</RadioItem>
          <RadioItem value="dark">Dark</RadioItem>
          <RadioItem value="system">System Preference</RadioItem>
        </RadioGroup>
      </div>
      
      {/* Other display settings */}
    </div>
  );
}
```

## Conclusion

The theming and customization capabilities of the CMM Technology Platform Design System provide flexibility while maintaining consistency and accessibility. By following these advanced patterns, organizations can create distinctive visual identities that align with their brand while benefiting from the robust foundation of the design system.
