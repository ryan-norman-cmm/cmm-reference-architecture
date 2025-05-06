# Design System Extension Points

## Introduction

This document outlines the extension points available in the Design System for the CMM Technology Platform. Extension points are deliberate openings in the system that allow developers to customize and extend functionality without modifying the core components. Understanding these extension points is essential for adapting the Design System to specific healthcare applications while maintaining consistency and upgradeability.

## Component Extension Points

### Component Composition

Components can be extended through composition, allowing developers to create new components from existing ones:

```jsx
// Example: Extending a Card component to create a PatientCard
import { Card, CardHeader, CardTitle, CardContent, CardFooter, Button } from '@cmm/design-system';

function PatientCard({ patient, onViewDetails, ...props }) {
  return (
    <Card {...props}>
      <CardHeader>
        <CardTitle>{patient.name}</CardTitle>
        <div className="text-sm text-muted-foreground">
          MRN: {patient.mrn} | DOB: {patient.dateOfBirth}
        </div>
      </CardHeader>
      <CardContent>
        <div className="space-y-2">
          <div className="grid grid-cols-2 gap-2">
            <div>
              <div className="text-sm font-medium">Gender</div>
              <div>{patient.gender}</div>
            </div>
            <div>
              <div className="text-sm font-medium">Age</div>
              <div>{patient.age} years</div>
            </div>
          </div>
          {patient.alerts && patient.alerts.length > 0 && (
            <div className="mt-4">
              <div className="text-sm font-medium">Alerts</div>
              <ul className="mt-2 space-y-1">
                {patient.alerts.map((alert, index) => (
                  <li key={index} className="text-sm text-destructive">
                    {alert}
                  </li>
                ))}
              </ul>
            </div>
          )}
        </div>
      </CardContent>
      <CardFooter>
        <Button onClick={() => onViewDetails(patient.id)}>View Details</Button>
      </CardFooter>
    </Card>
  );
}

export default PatientCard;
```

### Component Props

Components provide extension points through props that allow customization:

```jsx
// Example: Using component props to extend functionality
import { Button } from '@cmm/design-system';

// Standard usage
<Button>Click Me</Button>

// Extended with variant
<Button variant="clinical">Clinical Action</Button>

// Extended with size
<Button size="lg">Large Button</Button>

// Extended with custom className
<Button className="my-custom-button">Custom Styled Button</Button>

// Extended with custom attributes
<Button data-testid="submit-button" onClick={handleSubmit}>Submit</Button>

// Extended with asChild to use a different element
<Button asChild>
  <a href="/patients">View Patients</a>
</Button>
```

### Render Props Pattern

Some components use the render props pattern to allow custom rendering of content:

```jsx
// Example: Using render props to customize rendering
import { DataTable } from '@cmm/design-system';

function PatientList({ patients }) {
  return (
    <DataTable
      data={patients}
      columns={[
        {
          header: 'Name',
          accessor: 'name',
          // Custom cell rendering
          cell: ({ value, row }) => (
            <div className="flex items-center">
              <Avatar
                src={row.original.avatar}
                fallback={row.original.initials}
                className="mr-2 h-6 w-6"
              />
              <span>{value}</span>
              {row.original.vip && (
                <Badge className="ml-2" variant="outline">
                  VIP
                </Badge>
              )}
            </div>
          ),
        },
        {
          header: 'Status',
          accessor: 'status',
          // Custom cell rendering based on value
          cell: ({ value }) => {
            const statusMap = {
              active: { label: 'Active', variant: 'success' },
              inactive: { label: 'Inactive', variant: 'muted' },
              critical: { label: 'Critical', variant: 'destructive' },
            };
            
            const status = statusMap[value] || { label: value, variant: 'default' };
            
            return (
              <Badge variant={status.variant}>
                {status.label}
              </Badge>
            );
          },
        },
        {
          header: 'Actions',
          // Custom cell that doesn't use row data directly
          cell: ({ row }) => (
            <div className="flex space-x-2">
              <Button 
                variant="ghost" 
                size="sm" 
                onClick={() => handleView(row.original.id)}
              >
                View
              </Button>
              <Button 
                variant="ghost" 
                size="sm" 
                onClick={() => handleEdit(row.original.id)}
              >
                Edit
              </Button>
            </div>
          ),
        },
      ]}
    />
  );
}
```

## Styling Extension Points

### CSS Variables

The Design System exposes CSS variables that can be overridden for custom styling:

```css
/* Example: Overriding CSS variables for custom styling */
:root {
  /* Override primary color */
  --color-primary: 210 100% 50%;
  --color-primary-foreground: 0 0% 100%;
  
  /* Override font family */
  --font-sans: 'Roboto', system-ui, sans-serif;
  
  /* Override spacing */
  --spacing-unit: 0.25rem;
}

/* Department-specific overrides */
.radiology-department {
  --color-primary: 280 100% 50%;
  --color-secondary: 250 100% 50%;
}

.emergency-department {
  --color-primary: 0 100% 50%;
  --color-secondary: 30 100% 50%;
}
```

### Tailwind Extensions

The Design System can be extended through Tailwind CSS configuration:

```javascript
// tailwind.config.js
module.exports = {
  // Extend the Design System's Tailwind configuration
  presets: [require('@cmm/design-system/tailwind')],
  
  // Add custom extensions
  theme: {
    extend: {
      // Add custom colors
      colors: {
        'brand-blue': '#0055FF',
        'brand-green': '#00CC88',
      },
      
      // Add custom font family
      fontFamily: {
        'brand': ['BrandFont', 'sans-serif'],
      },
      
      // Add custom spacing
      spacing: {
        '4.5': '1.125rem',
      },
      
      // Add custom animation
      animation: {
        'pulse-slow': 'pulse 3s cubic-bezier(0.4, 0, 0.6, 1) infinite',
      },
    },
  },
  
  // Add custom plugins
  plugins: [
    // Custom plugin for medical-specific utilities
    function({ addUtilities }) {
      const newUtilities = {
        '.clinical-border': {
          border: '2px solid var(--color-clinical)',
          borderRadius: 'var(--radius-md)',
        },
        '.patient-border': {
          border: '2px solid var(--color-patient)',
          borderRadius: 'var(--radius-md)',
        },
      };
      
      addUtilities(newUtilities);
    },
  ],
};
```

### Component Class Name Props

Components accept className props that can be used to customize styling:

```jsx
// Example: Using className props for custom styling
import { Card, Button } from '@cmm/design-system';
import { cn } from '@cmm/design-system/utils';

function CustomCard({ variant, className, ...props }) {
  // Combine classes based on variant and passed className
  const cardClass = cn(
    'rounded-lg shadow',
    variant === 'clinical' && 'border-l-4 border-l-clinical',
    variant === 'patient' && 'border-l-4 border-l-patient',
    variant === 'admin' && 'border-l-4 border-l-primary',
    className
  );
  
  return <Card className={cardClass} {...props} />;
}

function CustomButton({ isProcessing, className, children, ...props }) {
  return (
    <Button 
      className={cn(
        isProcessing && 'opacity-70 pointer-events-none',
        className
      )} 
      {...props}
    >
      {isProcessing ? (
        <>
          <Spinner className="mr-2 h-4 w-4" />
          Processing...
        </>
      ) : (
        children
      )}
    </Button>
  );
}
```

## Theming Extension Points

### Theme Provider

The ThemeProvider component allows for theme customization:

```jsx
// Example: Extending the theme system
import { ThemeProvider, createTheme } from '@cmm/design-system/theme';

// Create a custom theme
const cardiology = createTheme({
  name: 'cardiology',
  colors: {
    primary: 'hsl(0 100% 50%)', // Red for cardiology
    secondary: 'hsl(30 100% 50%)',
    background: 'hsl(0 0% 100%)',
    foreground: 'hsl(0 0% 10%)',
  },
  fonts: {
    sans: '"Roboto", system-ui, sans-serif',
  },
  radii: {
    md: '0.375rem',
  },
});

// Use the custom theme
function CardiologyApp() {
  return (
    <ThemeProvider theme={cardiology}>
      <div className="app">
        {/* Application content */}
      </div>
    </ThemeProvider>
  );
}
```

### Dynamic Theming

Implement dynamic theming based on user preferences or context:

```jsx
// Example: Dynamic theming based on user preferences
import { ThemeProvider } from '@cmm/design-system/theme';
import { useUserPreferences } from '@/hooks/useUserPreferences';

function ThemedApplication() {
  const { preferences, updatePreferences } = useUserPreferences();
  
  // Handle theme change
  const handleThemeChange = (theme) => {
    updatePreferences({ theme });
  };
  
  return (
    <ThemeProvider theme={preferences.theme}>
      <div className="app">
        <header>
          <ThemeSelector 
            value={preferences.theme} 
            onChange={handleThemeChange} 
          />
        </header>
        <main>
          {/* Application content */}
        </main>
      </div>
    </ThemeProvider>
  );
}

function ThemeSelector({ value, onChange }) {
  return (
    <Select
      value={value}
      onChange={onChange}
      options={[
        { label: 'Light', value: 'light' },
        { label: 'Dark', value: 'dark' },
        { label: 'Clinical', value: 'clinical' },
        { label: 'High Contrast', value: 'high-contrast' },
      ]}
    />
  );
}
```

## Hook Extension Points

### Custom Hooks

The Design System provides hooks that can be extended or composed:

```jsx
// Example: Extending and composing hooks
import { useMediaQuery, useTheme } from '@cmm/design-system/hooks';

// Create a custom hook that combines existing hooks
function useResponsiveLayout() {
  const isMobile = useMediaQuery('(max-width: 768px)');
  const isTablet = useMediaQuery('(min-width: 769px) and (max-width: 1024px)');
  const isDesktop = useMediaQuery('(min-width: 1025px)');
  
  return {
    isMobile,
    isTablet,
    isDesktop,
    layout: isMobile ? 'mobile' : isTablet ? 'tablet' : 'desktop',
  };
}

// Create a custom hook for clinical context
function useClinicalTheme() {
  const { theme, setTheme } = useTheme();
  const { department } = useDepartmentContext();
  
  // Map departments to themes
  const departmentThemes = {
    cardiology: 'cardiology',
    radiology: 'radiology',
    emergency: 'emergency',
    pediatrics: 'pediatrics',
  };
  
  // Set theme based on department
  useEffect(() => {
    const departmentTheme = departmentThemes[department];
    if (departmentTheme && theme !== departmentTheme) {
      setTheme(departmentTheme);
    }
  }, [department, theme, setTheme]);
  
  return {
    theme,
    setTheme,
    isDepartmentTheme: departmentThemes[department] === theme,
  };
}
```

### Context Providers

Extend the Design System with custom context providers:

```jsx
// Example: Creating a custom context provider
import { createContext, useContext, useState } from 'react';

// Create a clinical context
const ClinicalContext = createContext(null);

// Create a provider component
export function ClinicalProvider({ children }) {
  const [patient, setPatient] = useState(null);
  const [encounter, setEncounter] = useState(null);
  const [department, setDepartment] = useState(null);
  
  // Provide clinical context values
  const value = {
    patient,
    setPatient,
    encounter,
    setEncounter,
    department,
    setDepartment,
    // Derived values
    isInpatient: encounter?.type === 'inpatient',
    isEmergency: encounter?.type === 'emergency',
    hasActiveOrders: patient?.orders?.some(order => order.status === 'active'),
  };
  
  return (
    <ClinicalContext.Provider value={value}>
      {children}
    </ClinicalContext.Provider>
  );
}

// Create a hook to use the context
export function useClinical() {
  const context = useContext(ClinicalContext);
  
  if (!context) {
    throw new Error('useClinical must be used within a ClinicalProvider');
  }
  
  return context;
}

// Use the custom provider with the Design System
import { ThemeProvider } from '@cmm/design-system/theme';

function ClinicalApplication() {
  return (
    <ThemeProvider theme="clinical">
      <ClinicalProvider>
        <div className="app">
          {/* Application content */}
        </div>
      </ClinicalProvider>
    </ThemeProvider>
  );
}
```

## Plugin Extension Points

### Component Plugins

Some components support plugins for extended functionality:

```jsx
// Example: Creating a plugin for the DataTable component
import { DataTable } from '@cmm/design-system';

// Create a plugin for clinical data highlighting
const clinicalHighlightPlugin = {
  name: 'clinicalHighlight',
  
  // Hook into cell rendering
  cell: (props) => {
    const { value, column, row } = props;
    
    // Check if the column has clinical metadata
    if (column.meta?.clinical) {
      // Handle different clinical data types
      if (column.meta.clinical === 'lab') {
        // Highlight abnormal lab values
        const normalRange = column.meta.normalRange;
        const isAbnormal = normalRange && (value < normalRange.min || value > normalRange.max);
        
        return {
          ...props,
          className: isAbnormal ? 'text-destructive font-medium' : undefined,
          title: isAbnormal ? `Abnormal value (normal range: ${normalRange.min}-${normalRange.max})` : undefined,
        };
      }
      
      if (column.meta.clinical === 'status') {
        // Style status values
        const statusStyles = {
          critical: 'text-destructive font-bold',
          abnormal: 'text-warning font-medium',
          normal: 'text-success',
        };
        
        return {
          ...props,
          className: statusStyles[value.toLowerCase()] || undefined,
        };
      }
    }
    
    // Return unmodified props if no highlighting needed
    return props;
  },
};

// Use the plugin with DataTable
function LabResultsTable({ results }) {
  return (
    <DataTable
      data={results}
      columns={[
        {
          header: 'Test',
          accessor: 'name',
        },
        {
          header: 'Result',
          accessor: 'value',
          meta: {
            clinical: 'lab',
            normalRange: { min: 0, max: 10 },
          },
        },
        {
          header: 'Status',
          accessor: 'status',
          meta: {
            clinical: 'status',
          },
        },
      ]}
      plugins={[clinicalHighlightPlugin]}
    />
  );
}
```

### Form Plugins

Extend form functionality with plugins:

```jsx
// Example: Creating a plugin for the Form component
import { Form } from '@cmm/design-system';

// Create a plugin for clinical data validation
const clinicalValidationPlugin = {
  name: 'clinicalValidation',
  
  // Hook into field validation
  validate: (field, value, formValues) => {
    // Check if the field has clinical metadata
    if (field.meta?.clinical) {
      // Handle different clinical data types
      if (field.meta.clinical === 'medication') {
        // Check for drug interactions
        const otherMeds = formValues.medications || [];
        const interactions = checkDrugInteractions(value, otherMeds);
        
        if (interactions.length > 0) {
          return {
            valid: false,
            error: `Potential drug interaction with ${interactions.join(', ')}`,
            warning: true, // Mark as warning (can still submit)
          };
        }
      }
      
      if (field.meta.clinical === 'dosage') {
        // Check if dosage is within safe range
        const patient = formValues.patient || {};
        const medication = formValues.medication;
        const safeRange = calculateSafeDosage(medication, patient.weight, patient.age);
        
        if (value < safeRange.min) {
          return {
            valid: false,
            error: `Dosage is below minimum safe dose (${safeRange.min} ${safeRange.unit})`,
          };
        }
        
        if (value > safeRange.max) {
          return {
            valid: false,
            error: `Dosage exceeds maximum safe dose (${safeRange.max} ${safeRange.unit})`,
          };
        }
      }
    }
    
    // Return null if validation passes
    return null;
  },
};

// Use the plugin with Form
function MedicationOrderForm() {
  return (
    <Form
      defaultValues={{
        medication: '',
        dosage: '',
        frequency: '',
        route: '',
      }}
      plugins={[clinicalValidationPlugin]}
      onSubmit={handleSubmit}
    >
      {({ register, formState }) => (
        <>
          <FormField
            label="Medication"
            error={formState.errors.medication?.message}
            {...register('medication', {
              required: 'Medication is required',
              meta: { clinical: 'medication' },
            })}
          />
          
          <FormField
            label="Dosage"
            error={formState.errors.dosage?.message}
            {...register('dosage', {
              required: 'Dosage is required',
              meta: { clinical: 'dosage' },
            })}
          />
          
          <FormField
            label="Frequency"
            error={formState.errors.frequency?.message}
            {...register('frequency', {
              required: 'Frequency is required',
            })}
          />
          
          <FormField
            label="Route"
            error={formState.errors.route?.message}
            {...register('route', {
              required: 'Route is required',
            })}
          />
          
          <Button type="submit">Submit Order</Button>
        </>
      )}
    </Form>
  );
}
```

## Integration Extension Points

### Data Fetching Integration

Extend components with data fetching capabilities:

```jsx
// Example: Creating a data fetching wrapper for components
import { Spinner, Card, CardHeader, CardTitle, CardContent } from '@cmm/design-system';

// Create a higher-order component for data fetching
function withDataFetching(Component, fetchFunction) {
  return function DataFetchingComponent({ id, ...props }) {
    const [data, setData] = useState(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);
    
    useEffect(() => {
      let isMounted = true;
      
      async function fetchData() {
        try {
          setLoading(true);
          const result = await fetchFunction(id);
          
          if (isMounted) {
            setData(result);
            setError(null);
          }
        } catch (err) {
          if (isMounted) {
            setError(err.message);
          }
        } finally {
          if (isMounted) {
            setLoading(false);
          }
        }
      }
      
      fetchData();
      
      return () => {
        isMounted = false;
      };
    }, [id]);
    
    if (loading) {
      return (
        <Card>
          <CardContent className="flex justify-center items-center p-6">
            <Spinner size="lg" />
          </CardContent>
        </Card>
      );
    }
    
    if (error) {
      return (
        <Card className="border-destructive">
          <CardHeader>
            <CardTitle className="text-destructive">Error</CardTitle>
          </CardHeader>
          <CardContent>
            <p>{error}</p>
          </CardContent>
        </Card>
      );
    }
    
    return <Component data={data} {...props} />;
  };
}

// Create a component that displays patient information
function PatientDetails({ data }) {
  return (
    <Card>
      <CardHeader>
        <CardTitle>{data.name}</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="space-y-2">
          <div>
            <div className="text-sm font-medium">Date of Birth</div>
            <div>{data.dateOfBirth}</div>
          </div>
          <div>
            <div className="text-sm font-medium">Gender</div>
            <div>{data.gender}</div>
          </div>
          <div>
            <div className="text-sm font-medium">MRN</div>
            <div>{data.mrn}</div>
          </div>
        </div>
      </CardContent>
    </Card>
  );
}

// Function to fetch patient data
async function fetchPatient(id) {
  const response = await fetch(`/api/patients/${id}`);
  
  if (!response.ok) {
    throw new Error('Failed to fetch patient data');
  }
  
  return response.json();
}

// Create a data-fetching version of PatientDetails
const PatientDetailsWithData = withDataFetching(PatientDetails, fetchPatient);

// Use the component
function PatientView({ patientId }) {
  return <PatientDetailsWithData id={patientId} />;
}
```

### Authentication Integration

Extend components with authentication capabilities:

```jsx
// Example: Creating authentication-aware components
import { useAuth } from '@cmm/security-framework';

// Create a higher-order component for authentication
function withAuthentication(Component, requiredPermissions = []) {
  return function AuthenticatedComponent(props) {
    const { user, hasPermission, isAuthenticated, login } = useAuth();
    
    // Check if user is authenticated
    if (!isAuthenticated) {
      return (
        <Card>
          <CardHeader>
            <CardTitle>Authentication Required</CardTitle>
          </CardHeader>
          <CardContent>
            <p>Please log in to access this content.</p>
            <Button onClick={login} className="mt-4">Log In</Button>
          </CardContent>
        </Card>
      );
    }
    
    // Check if user has required permissions
    const missingPermissions = requiredPermissions.filter(permission => !hasPermission(permission));
    
    if (missingPermissions.length > 0) {
      return (
        <Card className="border-destructive">
          <CardHeader>
            <CardTitle className="text-destructive">Access Denied</CardTitle>
          </CardHeader>
          <CardContent>
            <p>You do not have the required permissions to access this content.</p>
            <p className="text-sm text-muted-foreground mt-2">
              Missing permissions: {missingPermissions.join(', ')}
            </p>
          </CardContent>
        </Card>
      );
    }
    
    // User is authenticated and has required permissions
    return <Component user={user} {...props} />;
  };
}

// Create a component that requires authentication
function PatientList({ user, ...props }) {
  return (
    <div>
      <h2>Welcome, {user.name}</h2>
      <p>You have access to the patient list.</p>
      {/* Patient list content */}
    </div>
  );
}

// Create an authenticated version of PatientList
const AuthenticatedPatientList = withAuthentication(PatientList, ['patient:list']);

// Use the component
function PatientDirectory() {
  return <AuthenticatedPatientList />;
}
```

## Conclusion

The Design System provides numerous extension points that allow developers to customize and extend its functionality without modifying the core components. By leveraging these extension points, developers can create specialized healthcare applications while maintaining consistency and upgradeability. Understanding these extension mechanisms is essential for effectively adapting the Design System to specific requirements while preserving its benefits.

## Related Documentation

- [Advanced Use Cases](./advanced-use-cases.md)
- [Customization](./customization.md)
- [Component Patterns](../02-core-functionality/component-patterns.md)
- [Integration Points](../02-core-functionality/integration-points.md)
