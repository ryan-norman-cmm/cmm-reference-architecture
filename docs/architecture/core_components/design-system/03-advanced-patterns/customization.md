# Design System Customization

## Introduction

This document outlines the customization options available in the Design System for the CMM Technology Platform. While the Design System provides a comprehensive set of components and patterns out of the box, it also offers various mechanisms for customization to meet specific healthcare application requirements. This guide explains how to customize the Design System while maintaining consistency, accessibility, and upgradeability.

## Customization Principles

Before diving into specific customization techniques, it's important to understand the principles that should guide customization efforts:

1. **Maintain Consistency**: Customizations should maintain visual and behavioral consistency with the rest of the Design System.
2. **Preserve Accessibility**: Customizations must not compromise accessibility features.
3. **Follow Extension Points**: Use the provided extension points rather than modifying core components directly.
4. **Document Customizations**: Document all customizations for future reference and maintenance.
5. **Consider Upgradeability**: Design customizations to minimize conflicts with future Design System updates.

## Visual Customization

### Theme Customization

The most straightforward way to customize the Design System is through theming:

```jsx
// Example: Creating a custom theme
import { ThemeProvider } from '@cmm/design-system/theme';

function CustomThemedApp() {
  return (
    <ThemeProvider
      theme={{
        colors: {
          primary: 'hsl(210, 100%, 50%)',
          secondary: 'hsl(280, 100%, 50%)',
          accent: 'hsl(150, 100%, 50%)',
          background: 'hsl(0, 0%, 100%)',
          foreground: 'hsl(0, 0%, 10%)',
        },
        fonts: {
          sans: '"Roboto", system-ui, sans-serif',
          mono: '"JetBrains Mono", monospace',
        },
        radii: {
          sm: '0.125rem',
          md: '0.25rem',
          lg: '0.5rem',
        },
        shadows: {
          sm: '0 1px 2px 0 rgba(0, 0, 0, 0.05)',
          md: '0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06)',
          lg: '0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05)',
        },
      }}
    >
      <div className="app">
        {/* Application content */}
      </div>
    </ThemeProvider>
  );
}
```

### CSS Variable Customization

For more granular control, you can override CSS variables:

```css
/* styles/theme-overrides.css */
:root {
  /* Color overrides */
  --color-primary: 210 100% 50%;
  --color-primary-foreground: 0 0% 100%;
  --color-secondary: 280 100% 50%;
  --color-secondary-foreground: 0 0% 100%;
  --color-accent: 150 100% 50%;
  --color-accent-foreground: 0 0% 100%;
  
  /* Typography overrides */
  --font-sans: 'Roboto', system-ui, sans-serif;
  --font-mono: 'JetBrains Mono', monospace;
  --font-size-base: 1rem;
  --font-weight-normal: 400;
  --font-weight-medium: 500;
  --font-weight-bold: 700;
  
  /* Spacing overrides */
  --spacing-unit: 0.25rem;
  
  /* Border radius overrides */
  --radius-sm: 0.125rem;
  --radius-md: 0.25rem;
  --radius-lg: 0.5rem;
  
  /* Shadow overrides */
  --shadow-sm: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
  --shadow-md: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
  --shadow-lg: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05);
}
```

Import these overrides in your application:

```jsx
// _app.jsx or similar entry point
import '@cmm/design-system/styles.css';
import './styles/theme-overrides.css'; // Import after Design System styles

function MyApp({ Component, pageProps }) {
  return <Component {...pageProps} />;
}

export default MyApp;
```

### Tailwind Configuration Customization

Customize the Tailwind configuration to extend or override Design System styles:

```javascript
// tailwind.config.js
module.exports = {
  // Use the Design System's Tailwind preset
  presets: [require('@cmm/design-system/tailwind')],
  
  // Extend with custom configuration
  theme: {
    extend: {
      // Add custom colors
      colors: {
        'hospital-blue': '#0055FF',
        'hospital-green': '#00CC88',
      },
      
      // Add custom font sizes
      fontSize: {
        'xxs': '0.625rem',
        '2.5xl': '1.75rem',
      },
      
      // Add custom spacing
      spacing: {
        '4.5': '1.125rem',
        '13': '3.25rem',
      },
    },
  },
  
  // Add custom plugins
  plugins: [
    // Custom plugin for medical-specific utilities
    function({ addUtilities }) {
      const newUtilities = {
        '.clinical-card': {
          backgroundColor: 'var(--color-clinical-50)',
          borderLeft: '4px solid var(--color-clinical-500)',
          borderRadius: 'var(--radius-md)',
          padding: 'var(--spacing-4)',
        },
        '.patient-card': {
          backgroundColor: 'var(--color-patient-50)',
          borderLeft: '4px solid var(--color-patient-500)',
          borderRadius: 'var(--radius-md)',
          padding: 'var(--spacing-4)',
        },
      };
      
      addUtilities(newUtilities);
    },
  ],
};
```

## Component Customization

### Component Variants

Many components support variants that can be used for customization:

```jsx
// Example: Using component variants
import { Button } from '@cmm/design-system';

// Default variant
<Button>Default Button</Button>

// Primary variant
<Button variant="primary">Primary Button</Button>

// Secondary variant
<Button variant="secondary">Secondary Button</Button>

// Outline variant
<Button variant="outline">Outline Button</Button>

// Ghost variant
<Button variant="ghost">Ghost Button</Button>

// Link variant
<Button variant="link">Link Button</Button>

// Destructive variant
<Button variant="destructive">Destructive Button</Button>

// Clinical variant (healthcare-specific)
<Button variant="clinical">Clinical Button</Button>
```

### Component Composition

Compose existing components to create custom components:

```jsx
// Example: Creating a custom component through composition
import { Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter, Button } from '@cmm/design-system';

function PatientAlertCard({ patient, alerts, onAcknowledge }) {
  return (
    <Card className="border-l-4 border-l-destructive">
      <CardHeader className="pb-2">
        <CardTitle className="text-destructive flex items-center">
          <AlertCircle className="mr-2 h-5 w-5" />
          Patient Alerts
        </CardTitle>
        <CardDescription>
          {alerts.length} alert{alerts.length !== 1 ? 's' : ''} for {patient.name}
        </CardDescription>
      </CardHeader>
      <CardContent>
        <ul className="space-y-2">
          {alerts.map((alert, index) => (
            <li key={index} className="p-2 rounded bg-destructive/10">
              <div className="font-medium">{alert.title}</div>
              <div className="text-sm">{alert.description}</div>
            </li>
          ))}
        </ul>
      </CardContent>
      <CardFooter>
        <Button onClick={() => onAcknowledge(patient.id, alerts.map(a => a.id))}>
          Acknowledge All
        </Button>
      </CardFooter>
    </Card>
  );
}
```

### Component Wrappers

Create wrapper components that add custom functionality:

```jsx
// Example: Creating a wrapper component
import { Button } from '@cmm/design-system';

function ConfirmButton({ onConfirm, children, ...props }) {
  const [showConfirm, setShowConfirm] = useState(false);
  
  const handleClick = () => {
    if (showConfirm) {
      onConfirm();
      setShowConfirm(false);
    } else {
      setShowConfirm(true);
    }
  };
  
  const handleBlur = () => {
    // Reset after a short delay to allow for clicking the button again
    setTimeout(() => {
      setShowConfirm(false);
    }, 200);
  };
  
  return (
    <Button
      variant={showConfirm ? 'destructive' : props.variant || 'default'}
      onClick={handleClick}
      onBlur={handleBlur}
      {...props}
    >
      {showConfirm ? 'Confirm?' : children}
    </Button>
  );
}

// Usage
function OrderActions() {
  return (
    <div className="space-x-2">
      <Button variant="outline">Cancel</Button>
      <ConfirmButton onConfirm={handleDeleteOrder}>Delete Order</ConfirmButton>
    </div>
  );
}
```

### Higher-Order Components

Use higher-order components (HOCs) for advanced customization:

```jsx
// Example: Creating a higher-order component
import { Card, CardHeader, CardTitle, CardContent, Spinner } from '@cmm/design-system';

// HOC for adding loading state
function withLoading(Component) {
  return function WithLoadingComponent({ isLoading, loadingText = 'Loading...', ...props }) {
    if (isLoading) {
      return (
        <Card>
          <CardContent className="flex flex-col items-center justify-center p-6">
            <Spinner className="mb-2" />
            <p className="text-sm text-muted-foreground">{loadingText}</p>
          </CardContent>
        </Card>
      );
    }
    
    return <Component {...props} />;
  };
}

// Base component
function PatientSummary({ patient }) {
  return (
    <Card>
      <CardHeader>
        <CardTitle>{patient.name}</CardTitle>
      </CardHeader>
      <CardContent>
        <p>MRN: {patient.mrn}</p>
        <p>DOB: {patient.dateOfBirth}</p>
        <p>Gender: {patient.gender}</p>
      </CardContent>
    </Card>
  );
}

// Enhanced component with loading state
const PatientSummaryWithLoading = withLoading(PatientSummary);

// Usage
function PatientView({ patientId }) {
  const { patient, isLoading } = usePatient(patientId);
  
  return (
    <PatientSummaryWithLoading
      isLoading={isLoading}
      loadingText="Loading patient data..."
      patient={patient}
    />
  );
}
```

## Style Customization

### Global Style Overrides

Create global style overrides for Design System components:

```css
/* styles/component-overrides.css */

/* Button overrides */
.button {
  text-transform: uppercase;
}

/* Card overrides */
.card {
  box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
}

/* Input overrides */
.input {
  border-width: 2px;
}

/* Clinical-specific overrides */
.clinical-environment .button {
  border-radius: 0.125rem;
}

.clinical-environment .card {
  border-radius: 0.125rem;
  border-left-width: 4px;
}
```

### Component-Specific Style Overrides

Use the className prop for component-specific style overrides:

```jsx
// Example: Component-specific style overrides
import { Button, Card } from '@cmm/design-system';
import { cn } from '@cmm/design-system/utils';

function CustomStyledComponents() {
  return (
    <div className="space-y-4">
      <Button 
        className="bg-gradient-to-r from-blue-500 to-purple-500 hover:from-blue-600 hover:to-purple-600"
      >
        Gradient Button
      </Button>
      
      <Card 
        className={cn(
          'border-l-4 border-l-blue-500',
          'hover:shadow-lg transition-shadow duration-200'
        )}
      >
        <div className="p-4">
          <h3 className="text-lg font-semibold">Custom Card</h3>
          <p>This card has custom styling applied.</p>
        </div>
      </Card>
    </div>
  );
}
```

### CSS Modules

Use CSS Modules for component-specific styling:

```css
/* CustomButton.module.css */
.customButton {
  background: linear-gradient(to right, var(--color-primary), var(--color-secondary));
  border: none;
  color: white;
  font-weight: 600;
  transition: all 0.2s ease;
}

.customButton:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
}

.customButton:active {
  transform: translateY(0);
}
```

```jsx
// CustomButton.jsx
import { Button } from '@cmm/design-system';
import { cn } from '@cmm/design-system/utils';
import styles from './CustomButton.module.css';

function CustomButton({ className, ...props }) {
  return (
    <Button 
      className={cn(styles.customButton, className)}
      {...props}
    />
  );
}

export default CustomButton;
```

## Behavioral Customization

### Custom Hooks

Create custom hooks to extend component behavior:

```jsx
// Example: Custom hook for form validation
import { useState, useEffect } from 'react';

function useClinicalValidation(value, validationType) {
  const [error, setError] = useState(null);
  const [warning, setWarning] = useState(null);
  
  useEffect(() => {
    // Reset errors and warnings
    setError(null);
    setWarning(null);
    
    // Skip validation if no value
    if (!value) return;
    
    // Validate based on type
    switch (validationType) {
      case 'medication':
        // Validate medication
        if (isMedicationRestricted(value)) {
          setError('This medication is restricted and requires approval.');
        } else if (hasPotentialInteractions(value)) {
          setWarning('This medication may have potential interactions. Please review.');
        }
        break;
        
      case 'dosage':
        // Validate dosage
        const numericValue = parseFloat(value);
        if (isNaN(numericValue)) {
          setError('Please enter a valid numeric dosage.');
        } else if (numericValue > 100) {
          setError('Dosage exceeds maximum allowed value of 100.');
        } else if (numericValue > 50) {
          setWarning('Dosage is high. Please confirm appropriateness.');
        }
        break;
        
      case 'patientId':
        // Validate patient ID format
        if (!/^[A-Z]{2}\d{6}$/.test(value)) {
          setError('Patient ID must be in format XX000000 (2 letters followed by 6 digits).');
        }
        break;
        
      default:
        // No specific validation
        break;
    }
  }, [value, validationType]);
  
  return { error, warning, hasError: !!error, hasWarning: !!warning };
}

// Usage in a component
function MedicationForm() {
  const [medication, setMedication] = useState('');
  const [dosage, setDosage] = useState('');
  
  const medicationValidation = useClinicalValidation(medication, 'medication');
  const dosageValidation = useClinicalValidation(dosage, 'dosage');
  
  return (
    <form>
      <div className="space-y-4">
        <FormField
          label="Medication"
          error={medicationValidation.error}
          warning={medicationValidation.warning}
        >
          <Input 
            value={medication} 
            onChange={(e) => setMedication(e.target.value)} 
            className={cn(
              medicationValidation.hasError && 'border-destructive',
              medicationValidation.hasWarning && 'border-warning'
            )}
          />
        </FormField>
        
        <FormField
          label="Dosage"
          error={dosageValidation.error}
          warning={dosageValidation.warning}
        >
          <Input 
            value={dosage} 
            onChange={(e) => setDosage(e.target.value)} 
            className={cn(
              dosageValidation.hasError && 'border-destructive',
              dosageValidation.hasWarning && 'border-warning'
            )}
          />
        </FormField>
        
        <Button type="submit" disabled={medicationValidation.hasError || dosageValidation.hasError}>
          Submit
        </Button>
      </div>
    </form>
  );
}
```

### Context Providers

Create custom context providers for shared state and behavior:

```jsx
// Example: Custom context provider for clinical alerts
import { createContext, useContext, useState, useEffect } from 'react';
import { Toast, ToastProvider, ToastViewport } from '@cmm/design-system';

// Create context
const ClinicalAlertContext = createContext(null);

// Create provider
export function ClinicalAlertProvider({ children }) {
  const [alerts, setAlerts] = useState([]);
  
  // Add a new alert
  const addAlert = (alert) => {
    const id = Math.random().toString(36).substring(2, 9);
    const newAlert = { id, ...alert, createdAt: new Date() };
    setAlerts((prev) => [...prev, newAlert]);
    
    // Auto-dismiss non-critical alerts
    if (alert.severity !== 'critical') {
      setTimeout(() => {
        dismissAlert(id);
      }, alert.duration || 5000);
    }
    
    return id;
  };
  
  // Dismiss an alert
  const dismissAlert = (id) => {
    setAlerts((prev) => prev.filter((alert) => alert.id !== id));
  };
  
  // Acknowledge an alert (mark as seen but keep visible)
  const acknowledgeAlert = (id) => {
    setAlerts((prev) =>
      prev.map((alert) =>
        alert.id === id ? { ...alert, acknowledged: true } : alert
      )
    );
  };
  
  // Provide context value
  const value = {
    alerts,
    addAlert,
    dismissAlert,
    acknowledgeAlert,
  };
  
  return (
    <ClinicalAlertContext.Provider value={value}>
      <ToastProvider>
        {children}
        
        {/* Render alerts as toasts */}
        {alerts.map((alert) => (
          <Toast
            key={alert.id}
            variant={alert.severity}
            title={alert.title}
            description={alert.message}
            action={alert.severity === 'critical' && (
              <Toast.Action onClick={() => acknowledgeAlert(alert.id)}>
                Acknowledge
              </Toast.Action>
            )}
            onClose={() => dismissAlert(alert.id)}
          />
        ))}
        <ToastViewport />
      </ToastProvider>
    </ClinicalAlertContext.Provider>
  );
}

// Create hook to use the context
export function useClinicalAlerts() {
  const context = useContext(ClinicalAlertContext);
  
  if (!context) {
    throw new Error('useClinicalAlerts must be used within a ClinicalAlertProvider');
  }
  
  return context;
}

// Usage in application
function App() {
  return (
    <ClinicalAlertProvider>
      <ClinicalDashboard />
    </ClinicalAlertProvider>
  );
}

// Usage in a component
function PatientMonitor({ patientId }) {
  const { addAlert } = useClinicalAlerts();
  const { vitals } = usePatientVitals(patientId);
  
  // Check for abnormal vitals
  useEffect(() => {
    if (vitals?.heartRate > 120) {
      addAlert({
        title: 'High Heart Rate',
        message: `Patient's heart rate is ${vitals.heartRate} bpm`,
        severity: 'warning',
      });
    }
    
    if (vitals?.bloodPressureSystolic > 180) {
      addAlert({
        title: 'Hypertensive Crisis',
        message: `Patient's blood pressure is ${vitals.bloodPressureSystolic}/${vitals.bloodPressureDiastolic} mmHg`,
        severity: 'critical',
      });
    }
  }, [vitals, addAlert]);
  
  return (
    <div>
      <h2>Patient Vitals</h2>
      {/* Vitals display */}
    </div>
  );
}
```

## Healthcare-Specific Customization

### Clinical Variants

Create clinical-specific variants of components:

```jsx
// Example: Creating clinical variants
import { Button, Card } from '@cmm/design-system';
import { cn } from '@cmm/design-system/utils';

// Clinical button variants
function ClinicalButton({ variant = 'primary', ...props }) {
  const variantMap = {
    primary: 'bg-clinical-600 hover:bg-clinical-700 text-white',
    secondary: 'bg-clinical-100 hover:bg-clinical-200 text-clinical-800',
    outline: 'border border-clinical-600 text-clinical-600 hover:bg-clinical-50',
    critical: 'bg-destructive hover:bg-destructive/90 text-white',
    caution: 'bg-warning hover:bg-warning/90 text-warning-foreground',
  };
  
  return (
    <Button
      className={cn(variantMap[variant] || variantMap.primary)}
      {...props}
    />
  );
}

// Clinical card variants
function ClinicalCard({ severity, ...props }) {
  const severityMap = {
    normal: 'border-l-4 border-l-clinical-500',
    warning: 'border-l-4 border-l-warning bg-warning/10',
    critical: 'border-l-4 border-l-destructive bg-destructive/10',
    info: 'border-l-4 border-l-info bg-info/10',
  };
  
  return (
    <Card
      className={cn(severityMap[severity] || severityMap.normal)}
      {...props}
    />
  );
}
```

### Department-Specific Customization

Create department-specific customizations:

```jsx
// Example: Department-specific customization
import { ThemeProvider } from '@cmm/design-system/theme';

// Department themes
const departmentThemes = {
  emergency: {
    colors: {
      primary: 'hsl(0, 100%, 50%)', // Red for emergency
      secondary: 'hsl(30, 100%, 50%)', // Orange for emergency
    },
  },
  radiology: {
    colors: {
      primary: 'hsl(240, 100%, 50%)', // Blue for radiology
      secondary: 'hsl(210, 100%, 50%)', // Light blue for radiology
    },
  },
  cardiology: {
    colors: {
      primary: 'hsl(0, 100%, 40%)', // Dark red for cardiology
      secondary: 'hsl(0, 60%, 60%)', // Light red for cardiology
    },
  },
  pediatrics: {
    colors: {
      primary: 'hsl(120, 100%, 35%)', // Green for pediatrics
      secondary: 'hsl(180, 100%, 35%)', // Teal for pediatrics
    },
    radii: {
      md: '0.5rem', // Slightly more rounded for pediatrics
    },
  },
};

// Department-specific provider
function DepartmentProvider({ department, children }) {
  const theme = departmentThemes[department] || {};
  
  return (
    <ThemeProvider theme={theme}>
      <div className={`department-${department}`}>
        {children}
      </div>
    </ThemeProvider>
  );
}

// Usage
function EmergencyDepartmentApp() {
  return (
    <DepartmentProvider department="emergency">
      <EmergencyDashboard />
    </DepartmentProvider>
  );
}
```

## Conclusion

The Design System offers numerous customization options that allow developers to adapt it to specific healthcare application requirements while maintaining consistency, accessibility, and upgradeability. By following the customization principles and using the provided mechanisms, developers can create specialized interfaces that still benefit from the Design System's foundation.

When customizing the Design System, always consider the impact on consistency, accessibility, and future upgrades. Document all customizations and prefer using the provided extension points rather than modifying core components directly. This approach ensures that your applications can continue to benefit from Design System updates while meeting specific requirements.

## Related Documentation

- [Extension Points](./extension-points.md)
- [Advanced Use Cases](./advanced-use-cases.md)
- [Theming](./theming.md)
- [Component Patterns](../02-core-functionality/component-patterns.md)
