# Design System Integration Points

## Introduction

This document outlines the integration points between the Design System and other components of the CMM Technology Platform. It describes how the Design System interacts with various systems, frameworks, and applications, providing developers with a comprehensive guide for integrating the Design System into their projects. Understanding these integration points is essential for creating cohesive, consistent user experiences across the healthcare technology ecosystem.

## Core Integration Points

### Application Framework Integration

#### React Integration

The Design System is primarily built for React applications and provides seamless integration:

```jsx
// Import Design System components
import { Button, Card, Input } from '@cmm/design-system';
import { ThemeProvider } from '@cmm/design-system/theme';

// Use components in your application
function MyApplication() {
  return (
    <ThemeProvider theme="clinical">
      <div className="app">
        <Card>
          <h2>Patient Information</h2>
          <Input label="Patient ID" placeholder="Enter patient ID" />
          <Button variant="primary">Search</Button>
        </Card>
      </div>
    </ThemeProvider>
  );
}
```

#### Next.js Integration

For Next.js applications, the Design System provides optimized integration:

```jsx
// pages/_app.js
import { ThemeProvider } from '@cmm/design-system/theme';
import '@cmm/design-system/styles.css';

function MyApp({ Component, pageProps }) {
  return (
    <ThemeProvider>
      <Component {...pageProps} />
    </ThemeProvider>
  );
}

export default MyApp;
```

#### CSS/Styling Integration

The Design System integrates with Tailwind CSS and provides CSS variables for custom styling:

```jsx
// tailwind.config.js
module.exports = {
  content: [
    './pages/**/*.{js,ts,jsx,tsx}',
    './components/**/*.{js,ts,jsx,tsx}',
    // Include Design System components
    './node_modules/@cmm/design-system/**/*.{js,ts,jsx,tsx}',
  ],
  theme: {
    extend: {
      colors: {
        // Use Design System colors
        primary: 'hsl(var(--color-primary))',
        secondary: 'hsl(var(--color-secondary))',
        clinical: 'hsl(var(--color-clinical))',
      },
    },
  },
  plugins: [],
};
```

## Healthcare Component Integrations

### Security and Access Framework Integration

The Design System integrates with the Security and Access Framework for authentication and authorization UI components:

```jsx
// Import components from Design System and Security Framework
import { Card, Button } from '@cmm/design-system';
import { LoginForm, useAuth } from '@cmm/security-framework';

// Combined component
function SecurePatientCard({ patientId }) {
  const { hasPermission } = useAuth();
  const canViewPatient = hasPermission('patient:view');
  
  if (!canViewPatient) {
    return (
      <Card className="access-denied">
        <h2>Access Denied</h2>
        <p>You do not have permission to view this patient.</p>
        <LoginForm />
      </Card>
    );
  }
  
  return (
    <Card>
      <h2>Patient Information</h2>
      <p>Patient ID: {patientId}</p>
      <Button variant="clinical">View Details</Button>
    </Card>
  );
}
```

### Federated GraphQL API Integration

The Design System provides components that integrate with the Federated GraphQL API for data fetching and display:

```jsx
// Import components from Design System and GraphQL client
import { Card, Button, Spinner } from '@cmm/design-system';
import { useQuery, gql } from '@apollo/client';

// GraphQL query
const GET_PATIENT = gql`
  query GetPatient($id: ID!) {
    patient(id: $id) {
      id
      name
      dateOfBirth
      gender
    }
  }
`;

// Component with GraphQL integration
function PatientCard({ patientId }) {
  const { loading, error, data } = useQuery(GET_PATIENT, {
    variables: { id: patientId },
  });
  
  if (loading) return <Spinner size="lg" />;
  if (error) return <Card className="error">Error loading patient data</Card>;
  
  const { patient } = data;
  
  return (
    <Card>
      <h2>{patient.name}</h2>
      <p>Date of Birth: {patient.dateOfBirth}</p>
      <p>Gender: {patient.gender}</p>
      <Button variant="clinical">View Details</Button>
    </Card>
  );
}
```

### API Marketplace Integration

The Design System integrates with the API Marketplace for API documentation and testing interfaces:

```jsx
// Import components from Design System and API Marketplace
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@cmm/design-system';
import { ApiDocumentation, ApiTester } from '@cmm/api-marketplace';

// Combined component
function ApiExplorer({ apiId }) {
  return (
    <Tabs defaultValue="documentation">
      <TabsList>
        <TabsTrigger value="documentation">Documentation</TabsTrigger>
        <TabsTrigger value="testing">Test API</TabsTrigger>
      </TabsList>
      <TabsContent value="documentation">
        <ApiDocumentation apiId={apiId} />
      </TabsContent>
      <TabsContent value="testing">
        <ApiTester apiId={apiId} />
      </TabsContent>
    </Tabs>
  );
}
```

### Event Broker Integration

The Design System provides components for visualizing and interacting with event streams:

```jsx
// Import components from Design System and Event Broker
import { Card, Button, Timeline } from '@cmm/design-system';
import { useEventStream } from '@cmm/event-broker';

// Component with Event Broker integration
function PatientEventTimeline({ patientId }) {
  const { events, subscribe, unsubscribe } = useEventStream();
  
  React.useEffect(() => {
    // Subscribe to patient events
    subscribe(`patient.${patientId}.events`);
    
    return () => {
      // Unsubscribe when component unmounts
      unsubscribe(`patient.${patientId}.events`);
    };
  }, [patientId, subscribe, unsubscribe]);
  
  return (
    <Card>
      <h2>Patient Event Timeline</h2>
      <Timeline>
        {events.map(event => (
          <Timeline.Item key={event.id} timestamp={event.timestamp}>
            <h3>{event.type}</h3>
            <p>{event.description}</p>
          </Timeline.Item>
        ))}
      </Timeline>
      <Button variant="outline">View All Events</Button>
    </Card>
  );
}
```

### FHIR Interoperability Platform Integration

The Design System includes components specifically designed for displaying FHIR resources:

```jsx
// Import components from Design System and FHIR client
import { PatientBanner, VitalSigns } from '@cmm/design-system/clinical';
import { useFhirResource } from '@cmm/fhir-client';

// Component with FHIR integration
function PatientSummary({ patientId }) {
  const { resource: patient } = useFhirResource('Patient', patientId);
  const { resource: observations } = useFhirResource(
    'Observation',
    null,
    { patient: patientId, category: 'vital-signs', _sort: '-date', _count: 5 }
  );
  
  if (!patient) return <Spinner size="lg" />;
  
  // Transform FHIR data to component props
  const patientData = {
    id: patient.id,
    name: `${patient.name[0].given.join(' ')} ${patient.name[0].family}`,
    dateOfBirth: patient.birthDate,
    gender: patient.gender,
    mrn: patient.identifier.find(id => id.system === 'http://hospital.org/mrn').value,
  };
  
  // Transform observations to vital signs format
  const vitals = observations?.map(obs => ({
    name: obs.code.coding[0].display,
    value: obs.valueQuantity.value,
    unit: obs.valueQuantity.unit,
    timestamp: obs.effectiveDateTime,
    normalRange: obs.referenceRange?.[0] ? {
      min: obs.referenceRange[0].low.value,
      max: obs.referenceRange[0].high.value,
    } : undefined,
  })) || [];
  
  return (
    <div>
      <PatientBanner patient={patientData} />
      <VitalSigns vitals={vitals} />
    </div>
  );
}
```

## Development Tool Integrations

### Storybook Integration

The Design System is fully integrated with Storybook for component documentation and development:

```jsx
// Button.stories.tsx
import type { Meta, StoryObj } from '@storybook/react';
import { Button } from './button';

const meta: Meta<typeof Button> = {
  title: 'Components/Button',
  component: Button,
  parameters: {
    layout: 'centered',
  },
  argTypes: {
    variant: {
      control: 'select',
      options: ['default', 'primary', 'secondary', 'destructive', 'outline', 'ghost', 'link', 'clinical'],
    },
    size: {
      control: 'select',
      options: ['default', 'sm', 'lg', 'icon'],
    },
  },
};

export default meta;

type Story = StoryObj<typeof Button>;

export const Default: Story = {
  args: {
    children: 'Button',
  },
};

export const Clinical: Story = {
  args: {
    variant: 'clinical',
    children: 'Clinical Button',
  },
};
```

### Testing Framework Integration

The Design System provides utilities for testing components with React Testing Library:

```jsx
// Button.test.tsx
import { render, screen, fireEvent } from '@testing-library/react';
import { Button } from './button';

describe('Button', () => {
  it('renders correctly', () => {
    render(<Button>Test Button</Button>);
    expect(screen.getByText('Test Button')).toBeInTheDocument();
  });

  it('handles click events', () => {
    const handleClick = jest.fn();
    render(<Button onClick={handleClick}>Click Me</Button>);
    fireEvent.click(screen.getByText('Click Me'));
    expect(handleClick).toHaveBeenCalledTimes(1);
  });

  it('applies variants correctly', () => {
    render(<Button variant="clinical">Clinical</Button>);
    const button = screen.getByText('Clinical');
    expect(button).toHaveClass('bg-clinical');
  });
});
```

### Design Tool Integration

The Design System integrates with Figma for design-to-code workflow:

```typescript
// Design token synchronization with Figma
import { extractTokensFromFigma } from '@cmm/design-system-tools';

async function syncDesignTokens() {
  // Extract tokens from Figma
  const tokens = await extractTokensFromFigma({
    fileKey: 'figma-file-key',
    accessToken: process.env.FIGMA_ACCESS_TOKEN,
  });
  
  // Transform tokens to CSS variables
  const cssVariables = transformTokensToCss(tokens);
  
  // Write to CSS file
  fs.writeFileSync('src/styles/tokens.css', cssVariables);
  
  console.log('Design tokens synchronized successfully');
}
```

## Build and Deployment Integrations

### Package Manager Integration

The Design System is distributed as NPM packages for easy integration:

```json
// package.json
{
  "dependencies": {
    "@cmm/design-system": "^1.0.0",
    "@cmm/design-system-icons": "^1.0.0",
    "@cmm/design-system-clinical": "^1.0.0"
  }
}
```

### CI/CD Pipeline Integration

The Design System integrates with CI/CD pipelines for automated testing and deployment:

```yaml
# .github/workflows/design-system.yml
name: Design System CI/CD

on:
  push:
    branches: [main]
    paths:
      - 'packages/design-system/**'
  pull_request:
    branches: [main]
    paths:
      - 'packages/design-system/**'

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: 18
      - run: npm ci
      - run: npm test

  build:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: 18
      - run: npm ci
      - run: npm run build
      - uses: actions/upload-artifact@v3
        with:
          name: design-system-build
          path: packages/design-system/dist

  publish:
    needs: build
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: 18
          registry-url: https://npm.pkg.github.com/
      - uses: actions/download-artifact@v3
        with:
          name: design-system-build
          path: packages/design-system/dist
      - run: npm publish
        env:
          NODE_AUTH_TOKEN: ${{secrets.GITHUB_TOKEN}}
```

### Artifactory Integration

The Design System is published to Artifactory for internal distribution:

```bash
# .npmrc
@cmm:registry=https://artifactory.cmm.org/api/npm/npm-local/
//artifactory.cmm.org/api/npm/npm-local/:_authToken=${ARTIFACTORY_TOKEN}
```

## Application-Specific Integrations

### Clinical Portal Integration

The Design System provides specialized components for clinical portals:

```jsx
// Import clinical components
import { ClinicalLayout, PatientBanner, VitalSigns, MedicationList } from '@cmm/design-system/clinical';

// Clinical portal component
function ClinicalPortal() {
  const { selectedPatient } = usePatientContext();
  
  return (
    <ClinicalLayout>
      <ClinicalLayout.Header>
        <PatientBanner patient={selectedPatient} />
      </ClinicalLayout.Header>
      <ClinicalLayout.Sidebar>
        <PatientNavigation patientId={selectedPatient.id} />
      </ClinicalLayout.Sidebar>
      <ClinicalLayout.Content>
        <VitalSigns patientId={selectedPatient.id} />
        <MedicationList patientId={selectedPatient.id} />
      </ClinicalLayout.Content>
    </ClinicalLayout>
  );
}
```

### Patient Portal Integration

The Design System includes components optimized for patient-facing applications:

```jsx
// Import patient-facing components
import { PatientLayout, HealthSummary, AppointmentScheduler } from '@cmm/design-system/patient';

// Patient portal component
function PatientPortal() {
  const { user } = useAuth();
  
  return (
    <PatientLayout>
      <PatientLayout.Header>
        <h1>Welcome, {user.firstName}</h1>
      </PatientLayout.Header>
      <PatientLayout.Sidebar>
        <PatientNavigation />
      </PatientLayout.Sidebar>
      <PatientLayout.Content>
        <HealthSummary userId={user.id} />
        <AppointmentScheduler userId={user.id} />
      </PatientLayout.Content>
    </PatientLayout>
  );
}
```

### Administrative Portal Integration

The Design System provides components for administrative interfaces:

```jsx
// Import administrative components
import { AdminLayout, DataTable, FilterPanel } from '@cmm/design-system/admin';

// Administrative portal component
function AdminPortal() {
  const [filters, setFilters] = useState({});
  const { data, loading } = useAdminData(filters);
  
  return (
    <AdminLayout>
      <AdminLayout.Header>
        <h1>User Administration</h1>
      </AdminLayout.Header>
      <AdminLayout.Sidebar>
        <FilterPanel onChange={setFilters} />
      </AdminLayout.Sidebar>
      <AdminLayout.Content>
        <DataTable 
          data={data} 
          loading={loading} 
          columns={[
            { header: 'ID', accessor: 'id' },
            { header: 'Name', accessor: 'name' },
            { header: 'Role', accessor: 'role' },
            { header: 'Status', accessor: 'status' },
          ]} 
        />
      </AdminLayout.Content>
    </AdminLayout>
  );
}
```

## Conclusion

The Design System provides comprehensive integration points with various components of the CMM Technology Platform. These integrations enable developers to create consistent, accessible, and user-friendly healthcare applications while leveraging the full capabilities of the underlying systems. By following the integration patterns outlined in this document, developers can ensure a cohesive experience across all applications in the ecosystem.

## Related Documentation

- [Core APIs](./core-apis.md)
- [Data Model](./data-model.md)
- [Component Patterns](./component-patterns.md)
- [Implementation Resources](./implementation-resources.md)
