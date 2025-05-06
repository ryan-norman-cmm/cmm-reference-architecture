# Responsive Design Patterns

## Introduction

Healthcare applications must function effectively across a wide range of devices and contexts, from large clinical workstations to mobile devices used at the point of care. The CMM Technology Platform Design System incorporates advanced responsive design patterns to ensure consistent functionality and usability across all devices. This document outlines these patterns and provides guidance for implementing responsive healthcare interfaces.

## Core Responsive Principles

### Fluid Layouts

Implement fluid layouts that adapt to different screen sizes:

```jsx
// Example of a fluid layout component
function ClinicalDashboard() {
  return (
    <div className="clinical-dashboard">
      {/* Fluid grid system */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
        <PatientSummaryCard />
        <VitalSignsCard />
        <LabResultsCard />
        <MedicationsCard />
      </div>
      
      {/* Responsive table */}
      <div className="mt-6 overflow-hidden">
        <div className="responsive-table-container">
          <table className="w-full">
            {/* Table content */}
          </table>
        </div>
      </div>
    </div>
  );
}

// CSS for responsive tables
.responsive-table-container {
  width: 100%;
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
}

@media (max-width: 768px) {
  .responsive-table-container {
    margin-left: -1rem;
    margin-right: -1rem;
    padding-left: 1rem;
    padding-right: 1rem;
    width: calc(100% + 2rem);
  }
}
```

### Responsive Typography

Implement a responsive typography system that scales appropriately across devices:

```css
/* Base typography settings */
:root {
  --font-size-base: 16px;
  --line-height-base: 1.5;
  --font-scale-ratio: 1.25; /* Major third scale */
}

/* Fluid typography using clamp */
html {
  font-size: var(--font-size-base);
}

h1 {
  font-size: clamp(1.75rem, 4vw, 2.5rem);
  line-height: 1.2;
}

h2 {
  font-size: clamp(1.5rem, 3vw, 2rem);
  line-height: 1.25;
}

h3 {
  font-size: clamp(1.25rem, 2.5vw, 1.75rem);
  line-height: 1.3;
}

p, li, td, th {
  font-size: clamp(0.875rem, 1vw, 1rem);
}

/* Clinical data that must remain readable */
.clinical-value {
  font-size: clamp(1rem, 1.5vw, 1.25rem);
  font-weight: 600;
}

/* Small text with minimum size for legibility */
.small-text {
  font-size: clamp(0.75rem, 0.875vw, 0.875rem);
}
```

### Responsive Component Variants

Create components with responsive variants that adapt to different screen sizes:

```jsx
import { cva } from 'class-variance-authority';

// Define responsive variants for a component
const cardVariants = cva(
  'card rounded-lg shadow-md overflow-hidden',
  {
    variants: {
      layout: {
        default: 'grid grid-cols-1 gap-4 p-4',
        compact: 'flex flex-col p-2',
        expanded: 'grid grid-cols-1 gap-6 p-6',
      },
      density: {
        default: 'space-y-4',
        high: 'space-y-2',
        low: 'space-y-6',
      },
    },
    defaultVariants: {
      layout: 'default',
      density: 'default',
    },
  }
);

// Component with responsive props
function ResponsiveCard({ children, className, layout, density, ...props }) {
  return (
    <div className={cardVariants({ layout, density, className })} {...props}>
      {children}
    </div>
  );
}

// Usage with responsive variants
function PatientSummary() {
  return (
    <ResponsiveCard 
      layout={{ base: 'compact', md: 'default', lg: 'expanded' }}
      density={{ base: 'high', md: 'default' }}
    >
      {/* Card content */}
    </ResponsiveCard>
  );
}
```

## Healthcare-Specific Responsive Patterns

### Clinical Workstation to Mobile Adaptations

Implement patterns for adapting clinical interfaces from workstations to mobile devices:

```jsx
import { useMediaQuery } from '@/hooks/use-media-query';

function ClinicalInterface({ patient }) {
  // Detect viewport size
  const isMobile = useMediaQuery('(max-width: 768px)');
  const isTablet = useMediaQuery('(min-width: 769px) and (max-width: 1024px)');
  const isWorkstation = useMediaQuery('(min-width: 1025px)');
  
  return (
    <div className="clinical-interface">
      {/* Patient banner - always visible but adapts layout */}
      <PatientBanner 
        patient={patient}
        compact={isMobile}
      />
      
      {/* Workstation: Side-by-side layout */}
      {isWorkstation && (
        <div className="grid grid-cols-3 gap-4">
          <div className="col-span-1">
            <ClinicalNavigation orientation="vertical" />
            <PatientSummary patient={patient} />
          </div>
          <div className="col-span-2">
            <ClinicalContent patient={patient} />
          </div>
        </div>
      )}
      
      {/* Tablet: Modified layout */}
      {isTablet && (
        <div className="flex flex-col space-y-4">
          <ClinicalNavigation orientation="horizontal" />
          <div className="grid grid-cols-2 gap-4">
            <PatientSummary patient={patient} compact />
            <ClinicalContent patient={patient} compact />
          </div>
        </div>
      )}
      
      {/* Mobile: Stacked layout with tabs */}
      {isMobile && (
        <div className="flex flex-col space-y-2">
          <ClinicalNavigation orientation="tabs" />
          <PatientSummary patient={patient} compact />
          <ClinicalContent patient={patient} compact />
        </div>
      )}
    </div>
  );
}
```

### Context-Aware Data Density

Adjust data density based on device context and clinical needs:

```jsx
import { useContext } from 'react';
import { ClinicalContext } from '@/contexts/clinical-context';

function LabResultsTable({ results }) {
  const { clinicalContext } = useContext(ClinicalContext);
  const isMobile = useMediaQuery('(max-width: 768px)');
  
  // Determine which columns to show based on context and device
  const getVisibleColumns = () => {
    // Critical care context shows more data even on mobile
    if (clinicalContext === 'critical-care') {
      return isMobile 
        ? ['name', 'value', 'status', 'trend']
        : ['name', 'value', 'unit', 'reference', 'status', 'trend', 'time', 'notes'];
    }
    
    // Standard clinical context
    if (clinicalContext === 'standard-care') {
      return isMobile
        ? ['name', 'value', 'status']
        : ['name', 'value', 'unit', 'reference', 'status', 'time'];
    }
    
    // Patient-facing context shows simplified data
    if (clinicalContext === 'patient-facing') {
      return isMobile
        ? ['name', 'value', 'interpretation']
        : ['name', 'value', 'interpretation', 'time', 'explanation'];
    }
    
    // Default fallback
    return isMobile
      ? ['name', 'value']
      : ['name', 'value', 'unit', 'time'];
  };
  
  const visibleColumns = getVisibleColumns();
  
  return (
    <div className="lab-results-container">
      <table className="w-full">
        <thead>
          <tr>
            {visibleColumns.includes('name') && <th>Test</th>}
            {visibleColumns.includes('value') && <th>Value</th>}
            {visibleColumns.includes('unit') && <th>Unit</th>}
            {visibleColumns.includes('reference') && <th>Reference Range</th>}
            {visibleColumns.includes('status') && <th>Status</th>}
            {visibleColumns.includes('trend') && <th>Trend</th>}
            {visibleColumns.includes('time') && <th>Time</th>}
            {visibleColumns.includes('notes') && <th>Notes</th>}
            {visibleColumns.includes('interpretation') && <th>Meaning</th>}
            {visibleColumns.includes('explanation') && <th>Explanation</th>}
          </tr>
        </thead>
        <tbody>
          {results.map(result => (
            <tr key={result.id}>
              {visibleColumns.includes('name') && <td>{result.name}</td>}
              {visibleColumns.includes('value') && (
                <td className="font-medium">{result.value}</td>
              )}
              {visibleColumns.includes('unit') && <td>{result.unit}</td>}
              {visibleColumns.includes('reference') && (
                <td>{result.rangeMin}-{result.rangeMax}</td>
              )}
              {visibleColumns.includes('status') && (
                <td>
                  <ResultStatus status={result.status} />
                </td>
              )}
              {visibleColumns.includes('trend') && (
                <td>
                  <TrendIndicator trend={result.trend} />
                </td>
              )}
              {visibleColumns.includes('time') && (
                <td>{formatDateTime(result.timestamp)}</td>
              )}
              {visibleColumns.includes('notes') && <td>{result.notes}</td>}
              {visibleColumns.includes('interpretation') && (
                <td>{result.patientFriendlyInterpretation}</td>
              )}
              {visibleColumns.includes('explanation') && (
                <td>{result.patientFriendlyExplanation}</td>
              )}
            </tr>
          ))}
        </tbody>
      </table>
      
      {/* Mobile alternative view when table is too complex */}
      {isMobile && visibleColumns.length > 3 && (
        <div className="mt-4 md:hidden">
          <p className="text-sm text-muted-foreground">Swipe horizontally to see all data or view as cards below</p>
          <button 
            className="text-sm text-primary mt-1"
            onClick={() => setViewMode('cards')}
          >
            Switch to card view
          </button>
        </div>
      )}
    </div>
  );
}
```

### Point-of-Care Optimizations

Optimize interfaces for point-of-care usage on mobile devices:

```jsx
function PointOfCareInterface() {
  const [mode, setMode] = useState('scanning'); // scanning, review, documentation
  
  return (
    <div className="point-of-care-interface">
      {/* Large touch targets for gloved hands */}
      <div className="flex justify-around p-4 touch-interface">
        <Button 
          size="xl" 
          variant={mode === 'scanning' ? 'default' : 'outline'}
          onClick={() => setMode('scanning')}
          className="touch-target"
        >
          <QrCodeIcon className="h-6 w-6 mr-2" />
          Scan
        </Button>
        
        <Button 
          size="xl" 
          variant={mode === 'review' ? 'default' : 'outline'}
          onClick={() => setMode('review')}
          className="touch-target"
        >
          <ClipboardIcon className="h-6 w-6 mr-2" />
          Review
        </Button>
        
        <Button 
          size="xl" 
          variant={mode === 'documentation' ? 'default' : 'outline'}
          onClick={() => setMode('documentation')}
          className="touch-target"
        >
          <PencilIcon className="h-6 w-6 mr-2" />
          Document
        </Button>
      </div>
      
      {/* Mode-specific content */}
      {mode === 'scanning' && <BarcodeScanner />}
      {mode === 'review' && <MedicationReview />}
      {mode === 'documentation' && <QuickDocumentation />}
      
      {/* Emergency access - always visible */}
      <div className="fixed bottom-4 right-4">
        <Button size="lg" variant="destructive" className="touch-target">
          <AlertIcon className="h-6 w-6 mr-2" />
          Emergency
        </Button>
      </div>
    </div>
  );
}

// CSS for touch interfaces
.touch-interface {
  /* Larger touch targets for gloved hands */
  --touch-target-size: 3rem;
}

.touch-target {
  min-height: var(--touch-target-size);
  min-width: var(--touch-target-size);
  padding: 0.75rem 1.25rem;
  touch-action: manipulation;
}

/* Increase spacing between interactive elements */
.touch-interface .touch-target + .touch-target {
  margin-left: 1rem;
}

/* Optimize for one-handed operation on mobile */
@media (max-width: 768px) {
  .touch-interface {
    position: fixed;
    bottom: 0;
    left: 0;
    right: 0;
    background-color: var(--background);
    box-shadow: 0 -2px 10px rgba(0, 0, 0, 0.1);
    z-index: 10;
  }
}
```

## Advanced Responsive Techniques

### Container Queries

Use container queries for component-level responsiveness:

```jsx
function PatientCard({ patient }) {
  return (
    <div className="@container">
      <div className="flex flex-col @md:flex-row @lg:items-center p-4 gap-4">
        <div className="@md:w-1/4">
          <Avatar 
            patient={patient}
            className="w-16 h-16 @md:w-20 @md:h-20 @lg:w-24 @lg:h-24"
          />
        </div>
        
        <div className="@md:w-3/4">
          <h3 className="text-lg @md:text-xl font-bold">{patient.name}</h3>
          
          <div className="grid grid-cols-1 @sm:grid-cols-2 @lg:grid-cols-3 gap-2 mt-2">
            <div className="patient-info-item">
              <span className="text-muted-foreground text-sm">DOB</span>
              <span>{formatDate(patient.dateOfBirth)}</span>
            </div>
            
            <div className="patient-info-item">
              <span className="text-muted-foreground text-sm">MRN</span>
              <span>{patient.medicalRecordNumber}</span>
            </div>
            
            <div className="patient-info-item @sm:col-span-2 @lg:col-span-1">
              <span className="text-muted-foreground text-sm">Primary Provider</span>
              <span>{patient.primaryProvider}</span>
            </div>
          </div>
        </div>
        
        <div className="flex flex-row @md:flex-col @lg:flex-row gap-2 mt-2 @md:mt-0">
          <Button size="sm" variant="outline">
            <FileIcon className="h-4 w-4 mr-2" />
            Chart
          </Button>
          
          <Button size="sm" variant="outline">
            <CalendarIcon className="h-4 w-4 mr-2" />
            Schedule
          </Button>
        </div>
      </div>
    </div>
  );
}

// Tailwind configuration for container queries
// tailwind.config.js
module.exports = {
  theme: {
    extend: {
      // ... other extensions
    },
  },
  plugins: [
    require('@tailwindcss/container-queries'),
  ],
};
```

### Responsive Behavior

Implement components with behavior that adapts to different devices:

```jsx
import { useState, useEffect } from 'react';

function ClinicalNavigation({ orientation = 'horizontal' }) {
  const [activeItem, setActiveItem] = useState('summary');
  const isMobile = useMediaQuery('(max-width: 768px)');
  
  // Adjust behavior based on device and orientation
  const handleItemClick = (item) => {
    setActiveItem(item);
    
    // On mobile, navigate to the item directly
    if (isMobile) {
      navigateToSection(item);
    } 
    // On desktop, scroll to the section if using horizontal nav
    else if (orientation === 'horizontal') {
      scrollToSection(item);
    }
    // On desktop with vertical nav, update the main content area
    else {
      updateMainContent(item);
    }
  };
  
  // Render appropriate navigation type based on orientation
  if (orientation === 'tabs') {
    return (
      <Tabs value={activeItem} onValueChange={handleItemClick}>
        <TabsList className="w-full">
          <TabsTrigger value="summary">Summary</TabsTrigger>
          <TabsTrigger value="results">Results</TabsTrigger>
          <TabsTrigger value="orders">Orders</TabsTrigger>
          <TabsTrigger value="notes">Notes</TabsTrigger>
        </TabsList>
      </Tabs>
    );
  }
  
  if (orientation === 'horizontal') {
    return (
      <nav className="clinical-nav-horizontal">
        <ul className="flex space-x-4 border-b">
          <li>
            <button 
              className={`px-4 py-2 ${activeItem === 'summary' ? 'border-b-2 border-primary font-medium' : ''}`}
              onClick={() => handleItemClick('summary')}
            >
              Summary
            </button>
          </li>
          {/* Other navigation items */}
        </ul>
      </nav>
    );
  }
  
  return (
    <nav className="clinical-nav-vertical">
      <ul className="space-y-1">
        <li>
          <button 
            className={`w-full text-left px-4 py-2 rounded-md ${activeItem === 'summary' ? 'bg-primary/10 text-primary font-medium' : ''}`}
            onClick={() => handleItemClick('summary')}
          >
            Summary
          </button>
        </li>
        {/* Other navigation items */}
      </ul>
    </nav>
  );
}
```

### Responsive Data Visualization

Implement charts and visualizations that adapt to different screen sizes:

```jsx
import { useState, useEffect, useRef } from 'react';
import { LineChart, BarChart } from '@/components/charts';

function ResponsiveVisualization({ data, type = 'line' }) {
  const containerRef = useRef(null);
  const [dimensions, setDimensions] = useState({ width: 0, height: 0 });
  const [visibleDataPoints, setVisibleDataPoints] = useState(0);
  
  // Update dimensions on resize
  useEffect(() => {
    const updateDimensions = () => {
      if (containerRef.current) {
        const { width, height } = containerRef.current.getBoundingClientRect();
        setDimensions({ width, height });
        
        // Adjust visible data points based on width
        // For smaller screens, show fewer data points
        if (width < 400) {
          setVisibleDataPoints(7); // e.g., show weekly data on mobile
        } else if (width < 768) {
          setVisibleDataPoints(14); // e.g., show bi-weekly data on tablets
        } else {
          setVisibleDataPoints(30); // e.g., show monthly data on desktop
        }
      }
    };
    
    // Initial update
    updateDimensions();
    
    // Add resize listener
    const resizeObserver = new ResizeObserver(updateDimensions);
    if (containerRef.current) {
      resizeObserver.observe(containerRef.current);
    }
    
    return () => {
      if (containerRef.current) {
        resizeObserver.unobserve(containerRef.current);
      }
    };
  }, []);
  
  // Prepare data based on visible data points
  const visibleData = data.slice(-visibleDataPoints);
  
  // Adjust chart configuration based on dimensions
  const getChartConfig = () => {
    const baseConfig = {
      data: visibleData,
      width: dimensions.width,
      height: dimensions.height,
    };
    
    if (dimensions.width < 400) {
      // Mobile optimizations
      return {
        ...baseConfig,
        margin: { top: 10, right: 10, bottom: 30, left: 30 },
        hideGrid: true,
        hideLegend: true,
        xAxisTickFormat: (date) => format(new Date(date), 'MM/dd'),
        tooltipFormat: (value) => value.toFixed(1),
      };
    }
    
    if (dimensions.width < 768) {
      // Tablet optimizations
      return {
        ...baseConfig,
        margin: { top: 20, right: 20, bottom: 40, left: 40 },
        hideGrid: false,
        hideLegend: false,
        xAxisTickFormat: (date) => format(new Date(date), 'MMM dd'),
        tooltipFormat: (value) => value.toFixed(2),
      };
    }
    
    // Desktop full configuration
    return {
      ...baseConfig,
      margin: { top: 20, right: 30, bottom: 50, left: 50 },
      hideGrid: false,
      hideLegend: false,
      xAxisTickFormat: (date) => format(new Date(date), 'MMM dd, yyyy'),
      tooltipFormat: (value) => value.toFixed(2),
    };
  };
  
  return (
    <div 
      ref={containerRef} 
      className="w-full h-[300px] md:h-[400px]"
    >
      {dimensions.width > 0 && (
        type === 'line' ? (
          <LineChart {...getChartConfig()} />
        ) : (
          <BarChart {...getChartConfig()} />
        )
      )}
      
      {/* Data range selector */}
      <div className="mt-2 flex justify-end">
        <Select 
          value={visibleDataPoints.toString()}
          onValueChange={(value) => setVisibleDataPoints(parseInt(value))}
        >
          <SelectItem value="7">7 Days</SelectItem>
          <SelectItem value="14">14 Days</SelectItem>
          <SelectItem value="30">30 Days</SelectItem>
          <SelectItem value="90">90 Days</SelectItem>
        </Select>
      </div>
    </div>
  );
}
```

## Testing and Validation

### Responsive Testing Framework

Implement a comprehensive testing framework for responsive interfaces:

```jsx
import { render, screen } from '@testing-library/react';
import { setWindowSize } from '@/test-utils/responsive';

// Define standard viewport sizes
const VIEWPORT_SIZES = {
  mobile: { width: 375, height: 667 },
  tablet: { width: 768, height: 1024 },
  desktop: { width: 1280, height: 800 },
  largeDesktop: { width: 1920, height: 1080 },
};

// Test component across multiple viewport sizes
function testResponsive(Component, props, testFn) {
  Object.entries(VIEWPORT_SIZES).forEach(([size, dimensions]) => {
    describe(`${Component.name} at ${size} viewport`, () => {
      beforeEach(() => {
        setWindowSize(dimensions.width, dimensions.height);
      });
      
      testFn(size, dimensions);
    });
  });
}

// Example usage
describe('PatientBanner', () => {
  const patient = {
    id: '123',
    name: 'John Doe',
    dateOfBirth: '1980-01-01',
    mrn: 'MRN12345',
    gender: 'Male',
    alerts: ['Allergy: Penicillin', 'Fall Risk'],
  };
  
  testResponsive(PatientBanner, { patient }, (size, dimensions) => {
    it('displays patient name', () => {
      render(<PatientBanner patient={patient} />);
      expect(screen.getByText('John Doe')).toBeInTheDocument();
    });
    
    it('displays appropriate information for viewport size', () => {
      render(<PatientBanner patient={patient} />);
      
      // Always visible information
      expect(screen.getByText('John Doe')).toBeInTheDocument();
      
      // Information that might be conditionally displayed
      if (size === 'mobile') {
        // On mobile, expect compact display
        expect(screen.queryByText('Medical Record Number:')).not.toBeInTheDocument();
        expect(screen.getByText('MRN12345')).toBeInTheDocument();
      } else {
        // On larger screens, expect more detailed display
        expect(screen.getByText('Medical Record Number:')).toBeInTheDocument();
        expect(screen.getByText('MRN12345')).toBeInTheDocument();
      }
      
      // Critical alerts should always be visible
      expect(screen.getByText('Allergy: Penicillin')).toBeInTheDocument();
    });
    
    it('has appropriate layout', () => {
      render(<PatientBanner patient={patient} />);
      const banner = screen.getByTestId('patient-banner');
      
      if (size === 'mobile') {
        expect(banner).toHaveClass('flex-col');
      } else {
        expect(banner).toHaveClass('flex-row');
      }
    });
  });
});
```

### Accessibility Across Devices

Ensure accessibility is maintained across all device sizes:

```jsx
import { axe, toHaveNoViolations } from 'jest-axe';
import { render } from '@testing-library/react';

// Extend Jest matchers
expect.extend(toHaveNoViolations);

// Test accessibility across viewport sizes
async function testAccessibility(Component, props) {
  Object.entries(VIEWPORT_SIZES).forEach(([size, dimensions]) => {
    describe(`${Component.name} accessibility at ${size} viewport`, () => {
      beforeEach(() => {
        setWindowSize(dimensions.width, dimensions.height);
      });
      
      it('has no accessibility violations', async () => {
        const { container } = render(<Component {...props} />);
        const results = await axe(container);
        expect(results).toHaveNoViolations();
      });
    });
  });
}

// Example usage
describe('ClinicalDashboard Accessibility', () => {
  const mockProps = {
    patientId: '123',
    data: mockData,
  };
  
  testAccessibility(ClinicalDashboard, mockProps);
});
```

## Conclusion

Responsive design is essential for healthcare applications that must function across a wide range of devices and contexts. By implementing these advanced responsive patterns, developers can create interfaces that provide a consistent and effective user experience from large clinical workstations to mobile devices used at the point of care.

The CMM Technology Platform Design System incorporates these responsive design patterns to ensure that healthcare applications remain usable and effective across all devices. By following these guidelines, developers can create applications that adapt to the diverse needs of healthcare environments.
