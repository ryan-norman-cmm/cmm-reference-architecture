# Dark Mode Implementation

## Introduction

Dark mode is an essential feature for healthcare applications, particularly for clinical environments with varying lighting conditions and for reducing eye strain during extended use. The CMM Reference Architecture Design System provides a comprehensive dark mode implementation that maintains accessibility, readability, and clinical functionality. This document outlines the patterns and techniques for implementing dark mode in healthcare applications.

## Core Implementation

### CSS Variables Approach

The design system uses CSS variables to implement theme switching:

```css
/* Light mode (default) */
:root {
  /* Background colors */
  --background: 0 0% 100%;
  --foreground: 222.2 84% 4.9%;
  
  /* Card colors */
  --card: 0 0% 100%;
  --card-foreground: 222.2 84% 4.9%;
  
  /* Primary colors */
  --primary: 196 100% 47%;
  --primary-foreground: 210 40% 98%;
  
  /* Secondary colors */
  --secondary: 210 40% 96.1%;
  --secondary-foreground: 222.2 47.4% 11.2%;
  
  /* Accent colors */
  --accent: 210 40% 96.1%;
  --accent-foreground: 222.2 47.4% 11.2%;
  
  /* Muted colors */
  --muted: 210 40% 96.1%;
  --muted-foreground: 215.4 16.3% 46.9%;
  
  /* Destructive colors */
  --destructive: 0 84.2% 60.2%;
  --destructive-foreground: 210 40% 98%;
  
  /* Border and input colors */
  --border: 214.3 31.8% 91.4%;
  --input: 214.3 31.8% 91.4%;
  --ring: 222.2 84% 4.9%;
  
  /* Healthcare-specific colors */
  --clinical: 175 84% 32%;
  --clinical-foreground: 0 0% 100%;
  
  /* Other variables */
  --radius: 0.5rem;
}

/* Dark mode */
.dark {
  /* Background colors */
  --background: 222.2 84% 4.9%;
  --foreground: 210 40% 98%;
  
  /* Card colors */
  --card: 222.2 84% 4.9%;
  --card-foreground: 210 40% 98%;
  
  /* Primary colors - maintain brand recognition */
  --primary: 196 100% 47%;
  --primary-foreground: 222.2 47.4% 11.2%;
  
  /* Secondary colors */
  --secondary: 217.2 32.6% 17.5%;
  --secondary-foreground: 210 40% 98%;
  
  /* Accent colors */
  --accent: 217.2 32.6% 17.5%;
  --accent-foreground: 210 40% 98%;
  
  /* Muted colors */
  --muted: 217.2 32.6% 17.5%;
  --muted-foreground: 215 20.2% 65.1%;
  
  /* Destructive colors - maintain recognition */
  --destructive: 0 62.8% 30.6%;
  --destructive-foreground: 210 40% 98%;
  
  /* Border and input colors */
  --border: 217.2 32.6% 17.5%;
  --input: 217.2 32.6% 17.5%;
  --ring: 212.7 26.8% 83.9%;
  
  /* Healthcare-specific colors - maintain recognition */
  --clinical: 175 84% 32%;
  --clinical-foreground: 0 0% 100%;
}
```

### Theme Provider

Implement a theme provider component to manage dark mode state:

```jsx
'use client';

import { createContext, useContext, useEffect, useState } from 'react';

type Theme = 'dark' | 'light' | 'system';

type ThemeProviderProps = {
  children: React.ReactNode;
  defaultTheme?: Theme;
  storageKey?: string;
};

type ThemeProviderState = {
  theme: Theme;
  setTheme: (theme: Theme) => void;
};

const initialState: ThemeProviderState = {
  theme: 'system',
  setTheme: () => null,
};

const ThemeProviderContext = createContext<ThemeProviderState>(initialState);

export function ThemeProvider({
  children,
  defaultTheme = 'system',
  storageKey = 'ui-theme',
  ...props
}: ThemeProviderProps) {
  const [theme, setTheme] = useState<Theme>(
    () => (localStorage.getItem(storageKey) as Theme) || defaultTheme
  );

  useEffect(() => {
    const root = window.document.documentElement;

    root.classList.remove('light', 'dark');

    if (theme === 'system') {
      const systemTheme = window.matchMedia('(prefers-color-scheme: dark)')
        .matches
        ? 'dark'
        : 'light';

      root.classList.add(systemTheme);
      return;
    }

    root.classList.add(theme);
  }, [theme]);

  const value = {
    theme,
    setTheme: (theme: Theme) => {
      localStorage.setItem(storageKey, theme);
      setTheme(theme);
    },
  };

  return (
    <ThemeProviderContext.Provider {...props} value={value}>
      {children}
    </ThemeProviderContext.Provider>
  );
}

export const useTheme = () => {
  const context = useContext(ThemeProviderContext);

  if (context === undefined)
    throw new Error('useTheme must be used within a ThemeProvider');

  return context;
};
```

### Theme Switcher Component

Create a user interface for switching between themes:

```jsx
'use client';

import { useTheme } from '@/components/theme-provider';
import { Button } from '@/components/ui/button';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { MoonIcon, SunIcon, MonitorIcon } from 'lucide-react';

export function ThemeToggle() {
  const { theme, setTheme } = useTheme();

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="ghost" size="icon">
          <SunIcon className="h-[1.2rem] w-[1.2rem] rotate-0 scale-100 transition-all dark:-rotate-90 dark:scale-0" />
          <MoonIcon className="absolute h-[1.2rem] w-[1.2rem] rotate-90 scale-0 transition-all dark:rotate-0 dark:scale-100" />
          <span className="sr-only">Toggle theme</span>
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end">
        <DropdownMenuItem onClick={() => setTheme('light')}>
          <SunIcon className="mr-2 h-4 w-4" />
          <span>Light</span>
        </DropdownMenuItem>
        <DropdownMenuItem onClick={() => setTheme('dark')}>
          <MoonIcon className="mr-2 h-4 w-4" />
          <span>Dark</span>
        </DropdownMenuItem>
        <DropdownMenuItem onClick={() => setTheme('system')}>
          <MonitorIcon className="mr-2 h-4 w-4" />
          <span>System</span>
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
```

## Healthcare-Specific Considerations

### Clinical Environment Optimizations

Optimize dark mode for clinical environments:

```jsx
import { useTheme } from '@/components/theme-provider';
import { useContext } from 'react';
import { ClinicalContext } from '@/contexts/clinical-context';

function ClinicalModeProvider({ children }) {
  const { theme, setTheme } = useTheme();
  const { clinicalContext } = useContext(ClinicalContext);
  
  // Automatically switch to dark mode for nighttime clinical work
  useEffect(() => {
    if (clinicalContext === 'night-shift') {
      // Use clinical dark mode
      document.documentElement.classList.add('clinical-dark');
      setTheme('dark');
    } else {
      document.documentElement.classList.remove('clinical-dark');
    }
  }, [clinicalContext, setTheme]);
  
  return children;
}

// CSS for clinical dark mode
.clinical-dark {
  /* Ultra-dark background for nighttime use */
  --background: 220 20% 2%;
  --foreground: 220 10% 80%;
  
  /* Reduced brightness for all elements */
  --brightness-adjustment: 0.8;
  
  /* Apply brightness adjustment */
  & * {
    filter: brightness(var(--brightness-adjustment));
  }
  
  /* Preserve critical alert colors */
  .critical-alert {
    filter: none;
  }
}
```

### Preserving Clinical Information

Ensure clinical information remains clear and distinguishable in dark mode:

```css
/* Base color definitions for clinical status indicators */
:root {
  /* Normal range */
  --normal-color: 142 76% 36%;
  --normal-color-dark: 142 76% 46%;
  
  /* Abnormal - low */
  --abnormal-low-color: 221 83% 53%;
  --abnormal-low-color-dark: 221 83% 63%;
  
  /* Abnormal - high */
  --abnormal-high-color: 24 100% 62%;
  --abnormal-high-color-dark: 24 100% 72%;
  
  /* Critical */
  --critical-color: 0 84% 60%;
  --critical-color-dark: 0 84% 70%;
}

/* Apply appropriate colors based on theme */
.normal-indicator {
  color: hsl(var(--normal-color));
}

.abnormal-low-indicator {
  color: hsl(var(--abnormal-low-color));
}

.abnormal-high-indicator {
  color: hsl(var(--abnormal-high-color));
}

.critical-indicator {
  color: hsl(var(--critical-color));
}

/* Dark mode adjustments to maintain visibility */
.dark .normal-indicator {
  color: hsl(var(--normal-color-dark));
}

.dark .abnormal-low-indicator {
  color: hsl(var(--abnormal-low-color-dark));
}

.dark .abnormal-high-indicator {
  color: hsl(var(--abnormal-high-color-dark));
}

.dark .critical-indicator {
  color: hsl(var(--critical-color-dark));
}
```

### Medical Imaging Considerations

Provide specialized handling for medical images in dark mode:

```jsx
import { useTheme } from '@/components/theme-provider';

function MedicalImageViewer({ studyId, images }) {
  const { theme } = useTheme();
  const isDarkMode = theme === 'dark';
  
  // Adjust viewer settings based on theme
  const viewerSettings = {
    // Default settings
    backgroundColor: isDarkMode ? '#000' : '#fff',
    // For medical imaging, often invert the typical approach
    // Dark mode often works better for radiology
    textColor: isDarkMode ? '#fff' : '#000',
    // Don't apply dark mode to the actual images
    applyThemeToImages: false,
  };
  
  return (
    <div 
      className="medical-image-viewer" 
      style={{ backgroundColor: viewerSettings.backgroundColor }}
    >
      <div className="viewer-controls" style={{ color: viewerSettings.textColor }}>
        {/* Viewer controls */}
      </div>
      
      <div className="image-container">
        {/* Images are displayed with their own specialized handling */}
        {images.map(image => (
          <div key={image.id} className="image-wrapper">
            {/* Apply specialized image processing based on modality */}
            <img 
              src={image.url} 
              alt={image.description} 
              className={`medical-image ${image.modality.toLowerCase()}`}
              // Prevent dark mode styles from affecting the image
              style={{ isolation: 'isolate' }}
            />
          </div>
        ))}
      </div>
    </div>
  );
}
```

## Advanced Dark Mode Techniques

### Context-Aware Dark Mode

Implement context-aware dark mode that adapts to specific clinical contexts:

```jsx
function useContextAwareDarkMode() {
  const { theme, setTheme } = useTheme();
  const { user, clinicalContext } = useContext(ClinicalContext);
  
  useEffect(() => {
    // Get current hour
    const currentHour = new Date().getHours();
    
    // Automatic dark mode for night shifts (7pm - 7am)
    if (clinicalContext === 'inpatient' && (currentHour >= 19 || currentHour < 7)) {
      setTheme('dark');
    }
    
    // Automatic dark mode for radiology
    if (clinicalContext === 'radiology') {
      setTheme('dark');
    }
    
    // Respect user preference for other contexts
  }, [clinicalContext, setTheme]);
  
  return { theme, setTheme };
}
```

### Specialized Dark Mode Variants

Create specialized dark mode variants for different clinical contexts:

```jsx
import { useTheme } from '@/components/theme-provider';
import { useContext, useEffect } from 'react';
import { ClinicalContext } from '@/contexts/clinical-context';

function SpecializedThemeProvider({ children }) {
  const { theme } = useTheme();
  const { clinicalContext } = useContext(ClinicalContext);
  
  useEffect(() => {
    const root = document.documentElement;
    
    // Remove all specialized themes
    root.classList.remove(
      'radiology-theme',
      'surgery-theme',
      'icu-theme',
      'patient-theme'
    );
    
    // Apply specialized theme based on context
    if (theme === 'dark') {
      switch (clinicalContext) {
        case 'radiology':
          root.classList.add('radiology-theme');
          break;
        case 'surgery':
          root.classList.add('surgery-theme');
          break;
        case 'icu':
          root.classList.add('icu-theme');
          break;
        case 'patient':
          root.classList.add('patient-theme');
          break;
      }
    }
  }, [theme, clinicalContext]);
  
  return children;
}

// CSS for specialized dark mode variants
/* Radiology theme - optimized for image viewing */
.radiology-theme {
  --background: 220 20% 0%;
  --foreground: 220 10% 90%;
  --muted: 220 20% 10%;
  --muted-foreground: 220 10% 70%;
}

/* Surgery theme - reduced blue light */
.surgery-theme {
  --background: 30 20% 5%;
  --foreground: 30 10% 90%;
  --primary: 30 80% 50%;
  --primary-foreground: 30 10% 10%;
}

/* ICU theme - high contrast for critical information */
.icu-theme {
  --background: 220 20% 5%;
  --foreground: 220 10% 95%;
  --critical: 0 90% 70%;
  --critical-foreground: 0 10% 10%;
}

/* Patient theme - softer, less clinical */
.patient-theme {
  --background: 220 20% 10%;
  --foreground: 220 10% 90%;
  --primary: 210 80% 50%;
  --primary-foreground: 210 10% 10%;
}
```

## Testing and Validation

### Dark Mode Testing

Implement comprehensive testing for dark mode:

```jsx
import { render, screen } from '@testing-library/react';
import { ThemeProvider } from '@/components/theme-provider';

// Test component in both light and dark modes
function testInBothModes(Component, props, testFn) {
  ['light', 'dark'].forEach(mode => {
    describe(`${Component.name} in ${mode} mode`, () => {
      beforeEach(() => {
        // Set up document with appropriate theme
        document.documentElement.classList.remove('light', 'dark');
        document.documentElement.classList.add(mode);
      });
      
      testFn(mode);
    });
  });
}

// Example usage
describe('ClinicalAlert', () => {
  const alert = {
    type: 'critical',
    message: 'Critical lab value',
  };
  
  testInBothModes(ClinicalAlert, { alert }, (mode) => {
    it('displays with appropriate contrast', () => {
      render(
        <ThemeProvider defaultTheme={mode}>
          <ClinicalAlert alert={alert} />
        </ThemeProvider>
      );
      
      const alertElement = screen.getByText('Critical lab value');
      const styles = window.getComputedStyle(alertElement);
      
      // Get colors and check contrast
      const backgroundColor = styles.backgroundColor;
      const textColor = styles.color;
      const contrast = calculateContrastRatio(backgroundColor, textColor);
      
      // WCAG AA requires 4.5:1 for normal text
      expect(contrast).toBeGreaterThanOrEqual(4.5);
    });
  });
});
```

### Contrast Validation

Validate color contrast in both light and dark modes:

```jsx
import { useState, useEffect } from 'react';
import { useTheme } from '@/components/theme-provider';

function ContrastValidator({ children }) {
  const { theme } = useTheme();
  const [contrastIssues, setContrastIssues] = useState([]);
  
  useEffect(() => {
    // Only run in development
    if (process.env.NODE_ENV !== 'development') return;
    
    // Function to check contrast
    const validateContrast = () => {
      const issues = [];
      
      // Get all text elements
      const textElements = document.querySelectorAll('p, h1, h2, h3, h4, h5, h6, span, a, button, label, input, textarea');
      
      textElements.forEach(element => {
        const styles = window.getComputedStyle(element);
        const backgroundColor = styles.backgroundColor;
        const textColor = styles.color;
        const fontSize = parseInt(styles.fontSize);
        const fontWeight = styles.fontWeight;
        
        // Calculate contrast ratio
        const contrast = calculateContrastRatio(backgroundColor, textColor);
        
        // Determine required contrast based on text size
        const isLargeText = fontSize >= 18 || (fontSize >= 14 && fontWeight >= 700);
        const requiredContrast = isLargeText ? 3 : 4.5; // WCAG AA standards
        
        if (contrast < requiredContrast) {
          issues.push({
            element,
            contrast,
            requiredContrast,
            textColor,
            backgroundColor,
          });
        }
      });
      
      setContrastIssues(issues);
    };
    
    // Run validation after theme change
    const timeoutId = setTimeout(validateContrast, 500);
    
    return () => clearTimeout(timeoutId);
  }, [theme]);
  
  // Display contrast issues in development
  if (process.env.NODE_ENV === 'development' && contrastIssues.length > 0) {
    console.warn(`Found ${contrastIssues.length} contrast issues in ${theme} mode:`, contrastIssues);
  }
  
  return children;
}

// Helper function to calculate contrast ratio
function calculateContrastRatio(backgroundColor, textColor) {
  // Convert colors to luminance values
  const bgLuminance = getLuminance(backgroundColor);
  const textLuminance = getLuminance(textColor);
  
  // Calculate contrast ratio
  const ratio = (Math.max(bgLuminance, textLuminance) + 0.05) / 
                (Math.min(bgLuminance, textLuminance) + 0.05);
  
  return ratio;
}

// Helper function to get luminance from color
function getLuminance(color) {
  // Implementation of luminance calculation
  // ...
}
```

## Conclusion

Dark mode is an essential feature for healthcare applications, particularly in clinical environments with varying lighting conditions. The CMM Reference Architecture Design System provides a comprehensive dark mode implementation that maintains accessibility, readability, and clinical functionality.

By following these patterns and techniques, developers can create healthcare applications with effective dark mode support that enhances usability across different clinical contexts and reduces eye strain during extended use.
