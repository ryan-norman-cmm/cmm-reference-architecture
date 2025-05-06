# Design System Monitoring

## Introduction

This document outlines the monitoring strategy for the Design System in the CMM Technology Platform. Effective monitoring is essential for ensuring the reliability, performance, and usability of the Design System across all healthcare applications. This guide explains the monitoring approaches, tools, and best practices for tracking the health and usage of the Design System components.

## Monitoring Objectives

The primary objectives of Design System monitoring are:

1. **Performance Tracking**: Monitor the performance impact of Design System components
2. **Usage Analytics**: Track how components are being used across applications
3. **Error Detection**: Identify and diagnose errors in Design System components
4. **Accessibility Compliance**: Ensure ongoing accessibility compliance
5. **Visual Consistency**: Detect visual regressions and inconsistencies
6. **Adoption Metrics**: Measure the adoption rate of the Design System

## Performance Monitoring

### Bundle Size Monitoring

Track the size of Design System bundles to prevent performance degradation:

```javascript
// webpack.config.js with bundle analyzer
const { BundleAnalyzerPlugin } = require('webpack-bundle-analyzer');

module.exports = {
  // ... other webpack configuration
  plugins: [
    // ... other plugins
    new BundleAnalyzerPlugin({
      analyzerMode: process.env.ANALYZE === 'true' ? 'server' : 'disabled',
      generateStatsFile: true,
      statsFilename: 'bundle-stats.json',
    }),
  ],
};
```

Implement automated bundle size checks in CI/CD:

```yaml
# .github/workflows/bundle-size.yml
name: Bundle Size Check

on:
  pull_request:
    paths:
      - 'packages/design-system/**'

jobs:
  bundle-size:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: 18
      - run: npm ci
      - run: npm run build
      - name: Check bundle size
        uses: preactjs/compressed-size-action@v2
        with:
          repo-token: "${{ secrets.GITHUB_TOKEN }}"
          pattern: "./packages/design-system/dist/**/*.{js,css}"
          compression: "gzip"
          strip-hash: "\.(\w{8})\."
```

### Runtime Performance Monitoring

Implement performance monitoring for Design System components:

```javascript
// performance-monitoring.js
import { Profiler } from 'react';

export function withPerformanceTracking(Component, componentName) {
  return function PerformanceTrackedComponent(props) {
    function handleRender(id, phase, actualDuration, baseDuration, startTime, commitTime) {
      // Send performance data to monitoring service
      if (process.env.NODE_ENV === 'production') {
        window.performanceObserver?.observe({
          component: componentName,
          phase,
          actualDuration,
          baseDuration,
          startTime,
          commitTime,
        });
      }
    }
    
    return (
      <Profiler id={componentName} onRender={handleRender}>
        <Component {...props} />
      </Profiler>
    );
  };
}

// Usage
const PerformanceTrackedButton = withPerformanceTracking(Button, 'Button');
```

Integrate with application performance monitoring (APM) tools:

```javascript
// apm-integration.js
import { init as initApm } from '@elastic/apm-rum';

// Initialize APM
const apm = initApm({
  serviceName: 'design-system',
  serverUrl: 'https://apm.example.com',
  environment: process.env.NODE_ENV,
});

// Create custom transaction for component rendering
export function trackComponentPerformance(componentName, callback) {
  const transaction = apm.startTransaction(`render:${componentName}`, 'component-render');
  
  try {
    const result = callback();
    transaction.end();
    return result;
  } catch (error) {
    apm.captureError(error);
    transaction.end();
    throw error;
  }
}
```

## Usage Analytics

### Component Usage Tracking

Implement tracking to understand how components are used:

```javascript
// usage-tracking.js
export function trackComponentUsage(componentName, props) {
  // Only track in production
  if (process.env.NODE_ENV !== 'production') return;
  
  // Extract non-sensitive properties for analytics
  const trackedProps = {};
  
  // Track specific properties based on component
  if (componentName === 'Button') {
    trackedProps.variant = props.variant;
    trackedProps.size = props.size;
    trackedProps.hasIcon = !!props.icon;
  } else if (componentName === 'Card') {
    trackedProps.hasHeader = !!props.header;
    trackedProps.hasFooter = !!props.footer;
  }
  
  // Send usage data to analytics service
  window.analyticsClient?.trackEvent('component_usage', {
    component: componentName,
    properties: trackedProps,
    timestamp: new Date().toISOString(),
  });
}

// Higher-order component for usage tracking
export function withUsageTracking(Component, componentName) {
  return function TrackedComponent(props) {
    useEffect(() => {
      trackComponentUsage(componentName, props);
    }, [props]);
    
    return <Component {...props} />;
  };
}
```

### Usage Dashboard

Implement a dashboard to visualize component usage:

```javascript
// Example dashboard data structure
const usageDashboardData = {
  components: [
    {
      name: 'Button',
      usageCount: 12500,
      topVariants: [
        { name: 'primary', count: 5200 },
        { name: 'secondary', count: 3100 },
        { name: 'outline', count: 2800 },
        { name: 'clinical', count: 1400 },
      ],
      applications: [
        { name: 'Clinical Portal', count: 6200 },
        { name: 'Patient Portal', count: 4100 },
        { name: 'Admin Dashboard', count: 2200 },
      ],
      trend: '+5% in last 30 days',
    },
    // Other components...
  ],
  topApplications: [
    { name: 'Clinical Portal', componentCount: 28 },
    { name: 'Patient Portal', componentCount: 24 },
    { name: 'Admin Dashboard', componentCount: 22 },
  ],
  adoptionRate: '78%',
  trendsOverTime: [
    { date: '2023-01', adoptionRate: 0.65 },
    { date: '2023-02', adoptionRate: 0.68 },
    { date: '2023-03', adoptionRate: 0.72 },
    { date: '2023-04', adoptionRate: 0.75 },
    { date: '2023-05', adoptionRate: 0.78 },
  ],
};
```

## Error Monitoring

### Error Tracking

Implement error tracking for Design System components:

```javascript
// error-tracking.js
export function withErrorBoundary(Component, componentName) {
  return class ErrorBoundary extends React.Component {
    constructor(props) {
      super(props);
      this.state = { hasError: false, error: null };
    }
    
    static getDerivedStateFromError(error) {
      return { hasError: true, error };
    }
    
    componentDidCatch(error, errorInfo) {
      // Log error to monitoring service
      console.error(`Error in ${componentName}:`, error);
      
      // Send to error monitoring service
      if (process.env.NODE_ENV === 'production') {
        window.errorMonitoring?.captureException(error, {
          tags: {
            component: componentName,
          },
          extra: {
            componentProps: this.props,
            errorInfo,
          },
        });
      }
    }
    
    render() {
      if (this.state.hasError) {
        // Render fallback UI
        return (
          <div className="design-system-error">
            <p>Something went wrong in {componentName}.</p>
            {process.env.NODE_ENV !== 'production' && (
              <details>
                <summary>Error details</summary>
                <pre>{this.state.error?.toString()}</pre>
              </details>
            )}
          </div>
        );
      }
      
      return <Component {...this.props} />;
    }
  };
}

// Usage
const ButtonWithErrorBoundary = withErrorBoundary(Button, 'Button');
```

Integrate with error monitoring services:

```javascript
// sentry-integration.js
import * as Sentry from '@sentry/react';

Sentry.init({
  dsn: 'https://examplePublicKey@o0.ingest.sentry.io/0',
  environment: process.env.NODE_ENV,
  release: 'design-system@1.0.0',
});

// Create error boundary with Sentry integration
export const SentryErrorBoundary = Sentry.withErrorBoundary(({ children }) => (
  <>{children}</>
));

// Wrap Design System provider with error boundary
export function DesignSystemProvider({ children }) {
  return (
    <SentryErrorBoundary>
      <ThemeProvider>
        {children}
      </ThemeProvider>
    </SentryErrorBoundary>
  );
}
```

## Accessibility Monitoring

### Automated Accessibility Testing

Implement automated accessibility testing in CI/CD:

```yaml
# .github/workflows/accessibility.yml
name: Accessibility Testing

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  accessibility:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: 18
      - run: npm ci
      - run: npm run build-storybook
      - name: Run accessibility tests
        run: npm run test:a11y
```

Implement accessibility testing with axe-core:

```javascript
// a11y-testing.js
import { axe } from 'jest-axe';
import { render } from '@testing-library/react';

// Test component accessibility
export async function testComponentAccessibility(Component, props = {}) {
  const { container } = render(<Component {...props} />);
  const results = await axe(container);
  
  expect(results).toHaveNoViolations();
  
  return results;
}

// Example test
describe('Button Accessibility', () => {
  it('should have no accessibility violations', async () => {
    await testComponentAccessibility(Button, { children: 'Test Button' });
  });
  
  it('should have no accessibility violations with icon', async () => {
    await testComponentAccessibility(Button, { 
      children: 'Test Button',
      icon: <Icon name="settings" />,
    });
  });
});
```

### Runtime Accessibility Monitoring

Implement runtime accessibility checking:

```javascript
// runtime-a11y.js
import { useEffect } from 'react';
import { axeCore } from 'react-axe';

export function useAccessibilityMonitoring() {
  useEffect(() => {
    // Only run in development or testing
    if (process.env.NODE_ENV !== 'production' || process.env.ENABLE_A11Y_MONITORING) {
      const axe = axeCore(React, ReactDOM, 1000);
      
      // Run accessibility checks
      axe.run(document.body, {}, (err, results) => {
        if (err) throw err;
        
        // Log accessibility issues
        if (results.violations.length > 0) {
          console.group('Accessibility violations');
          results.violations.forEach(violation => {
            console.warn(
              `${violation.impact} impact: ${violation.help}`,
              violation.nodes
            );
          });
          console.groupEnd();
        }
      });
    }
  }, []);
}

// Usage in application
function App() {
  useAccessibilityMonitoring();
  
  return (
    <div className="app">
      {/* Application content */}
    </div>
  );
}
```

## Visual Regression Testing

### Storybook Visual Testing

Implement visual regression testing with Storybook and Chromatic:

```javascript
// .storybook/main.js
module.exports = {
  stories: ['../src/**/*.stories.mdx', '../src/**/*.stories.@(js|jsx|ts|tsx)'],
  addons: [
    '@storybook/addon-links',
    '@storybook/addon-essentials',
    '@storybook/addon-interactions',
    '@storybook/addon-a11y',
  ],
};
```

```yaml
# .github/workflows/visual-testing.yml
name: Visual Regression Testing

on:
  pull_request:
    branches: [main]

jobs:
  visual-testing:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0
      - uses: actions/setup-node@v3
        with:
          node-version: 18
      - run: npm ci
      - name: Publish to Chromatic
        uses: chromaui/action@v1
        with:
          projectToken: ${{ secrets.CHROMATIC_PROJECT_TOKEN }}
          exitZeroOnChanges: true # Optional: allow workflow to pass even if there are changes
```

### Component Screenshot Testing

Implement screenshot testing for components:

```javascript
// screenshot-testing.js
import puppeteer from 'puppeteer';
import { toMatchImageSnapshot } from 'jest-image-snapshot';

expect.extend({ toMatchImageSnapshot });

describe('Button Visual Regression', () => {
  let browser;
  let page;
  
  beforeAll(async () => {
    browser = await puppeteer.launch();
    page = await browser.newPage();
  });
  
  afterAll(async () => {
    await browser.close();
  });
  
  it('should match primary button snapshot', async () => {
    await page.goto('http://localhost:6006/iframe.html?id=components-button--primary');
    await page.waitForSelector('.button');
    
    const screenshot = await page.screenshot();
    expect(screenshot).toMatchImageSnapshot();
  });
  
  it('should match clinical button snapshot', async () => {
    await page.goto('http://localhost:6006/iframe.html?id=components-button--clinical');
    await page.waitForSelector('.button');
    
    const screenshot = await page.screenshot();
    expect(screenshot).toMatchImageSnapshot();
  });
});
```

## Adoption Metrics

### Design System Adoption Tracking

Implement tracking for Design System adoption across applications:

```javascript
// adoption-metrics.js
export async function analyzeDesignSystemAdoption() {
  // Get list of applications
  const applications = await fetchApplications();
  
  // Analyze each application
  const results = await Promise.all(
    applications.map(async (app) => {
      // Get application code
      const codebase = await fetchApplicationCode(app.id);
      
      // Analyze imports
      const designSystemImports = analyzeImports(codebase, '@cmm/design-system');
      
      // Analyze component usage
      const componentUsage = analyzeComponentUsage(codebase, designSystemImports);
      
      // Calculate adoption percentage
      const totalComponents = countTotalComponents(codebase);
      const designSystemComponents = componentUsage.length;
      const adoptionPercentage = (designSystemComponents / totalComponents) * 100;
      
      return {
        applicationId: app.id,
        applicationName: app.name,
        designSystemImports,
        componentUsage,
        adoptionPercentage,
        totalComponents,
        designSystemComponents,
      };
    })
  );
  
  // Calculate overall adoption
  const overallAdoption = results.reduce(
    (sum, result) => sum + result.adoptionPercentage,
    0
  ) / results.length;
  
  return {
    applications: results,
    overallAdoption,
    timestamp: new Date().toISOString(),
  };
}
```

### Adoption Dashboard

Implement a dashboard to visualize Design System adoption:

```javascript
// Example adoption dashboard data structure
const adoptionDashboardData = {
  overallAdoption: 78.5,
  applicationAdoption: [
    { name: 'Clinical Portal', adoption: 92.3 },
    { name: 'Patient Portal', adoption: 85.7 },
    { name: 'Admin Dashboard', adoption: 76.2 },
    { name: 'Scheduling System', adoption: 68.9 },
    { name: 'Billing Portal', adoption: 62.4 },
  ],
  componentAdoption: [
    { name: 'Button', adoption: 98.2 },
    { name: 'Card', adoption: 94.5 },
    { name: 'Input', adoption: 91.3 },
    { name: 'Table', adoption: 87.6 },
    { name: 'Dialog', adoption: 82.1 },
  ],
  trendsOverTime: [
    { date: '2023-01', adoption: 65.2 },
    { date: '2023-02', adoption: 68.7 },
    { date: '2023-03', adoption: 72.3 },
    { date: '2023-04', adoption: 75.8 },
    { date: '2023-05', adoption: 78.5 },
  ],
};
```

## Monitoring Infrastructure

### Monitoring Dashboard

Implement a comprehensive monitoring dashboard for the Design System:

```javascript
// Example dashboard structure
const monitoringDashboard = {
  performance: {
    bundleSize: {
      current: '125KB',
      trend: '-2KB since last release',
      breakdown: [
        { name: 'core', size: '45KB' },
        { name: 'components', size: '65KB' },
        { name: 'utilities', size: '15KB' },
      ],
    },
    renderTimes: {
      average: '12ms',
      p95: '28ms',
      byComponent: [
        { name: 'DataTable', average: '35ms', p95: '62ms' },
        { name: 'Chart', average: '28ms', p95: '45ms' },
        { name: 'Form', average: '18ms', p95: '32ms' },
      ],
    },
  },
  errors: {
    total: 27,
    trend: '-15% since last month',
    topErrors: [
      { component: 'DataTable', count: 12, message: 'Invalid data format' },
      { component: 'Form', count: 8, message: 'Validation failed' },
      { component: 'Dialog', count: 5, message: 'Failed to render' },
    ],
  },
  accessibility: {
    score: 98,
    trend: '+2 since last month',
    issues: [
      { component: 'Tooltip', severity: 'moderate', message: 'Missing aria-describedby' },
      { component: 'Icon', severity: 'minor', message: 'Missing aria-label' },
    ],
  },
  adoption: {
    overall: 78.5,
    trend: '+3.2% since last month',
    byApplication: [
      { name: 'Clinical Portal', adoption: 92.3 },
      { name: 'Patient Portal', adoption: 85.7 },
      { name: 'Admin Dashboard', adoption: 76.2 },
    ],
  },
};
```

### Alerting System

Implement alerts for critical Design System issues:

```javascript
// alerts-config.js
const alertsConfig = {
  performance: [
    {
      name: 'Bundle Size Increase',
      condition: 'bundleSize > previousBundleSize * 1.1', // 10% increase
      severity: 'warning',
      channels: ['teams', 'email'],
    },
    {
      name: 'Render Time Degradation',
      condition: 'averageRenderTime > previousAverageRenderTime * 1.2', // 20% increase
      severity: 'warning',
      channels: ['teams'],
    },
  ],
  errors: [
    {
      name: 'Error Spike',
      condition: 'errorRate > previousErrorRate * 2', // 100% increase
      severity: 'critical',
      channels: ['teams', 'email', 'pager'],
    },
    {
      name: 'Consistent Errors',
      condition: 'errorCount > 10 && errorComponent === sameComponent', // Same component has >10 errors
      severity: 'high',
      channels: ['teams', 'email'],
    },
  ],
  accessibility: [
    {
      name: 'Accessibility Regression',
      condition: 'a11yScore < previousA11yScore', // Any decrease in accessibility score
      severity: 'high',
      channels: ['teams', 'email'],
    },
    {
      name: 'Critical Accessibility Issue',
      condition: 'a11yIssue.severity === "critical"', // Critical accessibility issue
      severity: 'critical',
      channels: ['teams', 'email', 'pager'],
    },
  ],
};
```

## Healthcare-Specific Monitoring

### Clinical Context Monitoring

Implement monitoring for clinical-specific components:

```javascript
// clinical-monitoring.js
export function monitorClinicalComponents() {
  // Track clinical component usage
  const trackClinicalUsage = (componentName, clinicalContext) => {
    window.analyticsClient?.trackEvent('clinical_component_usage', {
      component: componentName,
      clinicalContext,
      department: getCurrentDepartment(),
      userRole: getCurrentUserRole(),
      timestamp: new Date().toISOString(),
    });
  };
  
  // Monitor clinical data display accuracy
  const monitorClinicalDataDisplay = (componentName, displayedData, sourceData) => {
    // Verify that displayed data matches source data
    const isAccurate = validateClinicalDataAccuracy(displayedData, sourceData);
    
    if (!isAccurate) {
      // Log data display discrepancy
      console.error(`Clinical data display discrepancy in ${componentName}`);
      
      // Report to monitoring service
      window.errorMonitoring?.captureMessage('Clinical data display discrepancy', {
        tags: {
          component: componentName,
          clinical: true,
        },
        extra: {
          displayedData,
          sourceData,
          discrepancies: findDataDiscrepancies(displayedData, sourceData),
        },
      });
    }
  };
  
  return {
    trackClinicalUsage,
    monitorClinicalDataDisplay,
  };
}

// Usage in a clinical component
function PatientVitals({ patientId }) {
  const { data: vitals } = usePatientVitals(patientId);
  const { trackClinicalUsage, monitorClinicalDataDisplay } = monitorClinicalComponents();
  
  useEffect(() => {
    trackClinicalUsage('PatientVitals', 'vitals-display');
  }, []);
  
  useEffect(() => {
    if (vitals) {
      // Monitor that displayed vitals match source data
      monitorClinicalDataDisplay('PatientVitals', formatVitalsForDisplay(vitals), vitals);
    }
  }, [vitals]);
  
  return (
    <VitalSigns vitals={formatVitalsForDisplay(vitals)} />
  );
}
```

### Regulatory Compliance Monitoring

Implement monitoring for regulatory compliance:

```javascript
// regulatory-monitoring.js
export function monitorRegulatoryCompliance() {
  // Track user interactions for audit purposes
  const trackAuditableAction = (action, data) => {
    const auditRecord = {
      action,
      data,
      user: getCurrentUser(),
      timestamp: new Date().toISOString(),
      ipAddress: getCurrentIpAddress(),
      sessionId: getCurrentSessionId(),
    };
    
    // Send to audit logging service
    window.auditLogger?.logAction(auditRecord);
    
    return auditRecord;
  };
  
  // Monitor for potential PHI exposure
  const monitorPhiExposure = (componentName, props) => {
    // Check if component might display PHI
    if (mightContainPhi(props)) {
      // Verify appropriate safeguards are in place
      const safeguards = checkPhiSafeguards(componentName, props);
      
      if (!safeguards.adequate) {
        // Log potential PHI exposure risk
        console.error(`Potential PHI exposure risk in ${componentName}`);
        
        // Report to monitoring service
        window.errorMonitoring?.captureMessage('Potential PHI exposure risk', {
          tags: {
            component: componentName,
            regulatory: true,
            phi: true,
          },
          extra: {
            missingSafeguards: safeguards.missing,
            recommendations: safeguards.recommendations,
          },
        });
      }
    }
  };
  
  return {
    trackAuditableAction,
    monitorPhiExposure,
  };
}

// Usage in a component that displays PHI
function PatientHeader({ patient }) {
  const { monitorPhiExposure } = monitorRegulatoryCompliance();
  
  useEffect(() => {
    monitorPhiExposure('PatientHeader', { patient });
  }, [patient]);
  
  return (
    <div className="patient-header">
      <h2>{patient.name}</h2>
      <div>DOB: {patient.dateOfBirth}</div>
      <div>MRN: {patient.mrn}</div>
    </div>
  );
}
```

## Conclusion

Effective monitoring of the Design System is essential for ensuring its reliability, performance, and usability across healthcare applications. By implementing comprehensive monitoring strategies for performance, usage, errors, accessibility, visual consistency, and adoption, teams can identify and address issues proactively, measure the impact of the Design System, and continuously improve its quality.

The monitoring approaches outlined in this document provide a foundation for tracking the health and usage of the Design System components. By adapting these approaches to specific healthcare requirements and integrating with existing monitoring infrastructure, organizations can ensure that the Design System continues to meet the needs of healthcare applications and users.

## Related Documentation

- [CI/CD Pipeline](./ci-cd-pipeline.md)
- [Maintenance](./maintenance.md)
- [Scaling](./scaling.md)
- [Troubleshooting](./troubleshooting.md)
- [Testing Strategy](./testing-strategy.md)
