# Performance Optimization

## Introduction

Performance is a critical aspect of healthcare applications, where efficiency can directly impact clinical workflows and patient care. The CMM Reference Architecture Design System incorporates advanced performance optimization patterns to ensure that applications remain responsive and efficient, even with complex interfaces and large datasets. This document outlines these patterns and provides guidance for implementing them in healthcare applications.

## Core Performance Principles

### Rendering Optimization

#### Component Memoization

Use React's memoization features to prevent unnecessary re-renders:

```jsx
// Memoize components that don't need frequent updates
import { memo, useMemo, useCallback } from 'react';

// Memoize a component
const PatientCard = memo(function PatientCard({ patient, onSelect }) {
  return (
    <Card onClick={() => onSelect(patient.id)}>
      <CardContent>
        <h3>{patient.name}</h3>
        <p>DOB: {formatDate(patient.dateOfBirth)}</p>
        <p>MRN: {patient.medicalRecordNumber}</p>
      </CardContent>
    </Card>
  );
});

// Usage with memoized callback
function PatientList({ patients }) {
  // Memoize the callback to prevent unnecessary re-renders
  const handleSelect = useCallback((patientId) => {
    navigateToPatient(patientId);
  }, []);
  
  // Memoize derived data
  const sortedPatients = useMemo(() => {
    return [...patients].sort((a, b) => a.name.localeCompare(b.name));
  }, [patients]);
  
  return (
    <div className="patient-list">
      {sortedPatients.map(patient => (
        <PatientCard 
          key={patient.id} 
          patient={patient} 
          onSelect={handleSelect}
        />
      ))}
    </div>
  );
}
```

#### Render Batching

Group multiple state updates to minimize render cycles:

```jsx
// Instead of multiple state updates
function inefficientUpdate() {
  setLoading(true);       // Causes a render
  setPatients(newData);   // Causes another render
  setError(null);         // Causes a third render
  setLoading(false);      // Causes a fourth render
}

// Use batched updates
function efficientUpdate() {
  // React 18+ automatically batches these updates into a single render
  setLoading(true);
  setPatients(newData);
  setError(null);
  setLoading(false);
  
  // For older versions or complex state logic, use a reducer
  dispatch({
    type: 'FETCH_SUCCESS',
    payload: newData
  });
}
```

### Code Splitting

Reduce initial bundle size by splitting code into smaller chunks that load on demand:

```jsx
import { lazy, Suspense } from 'react';

// Lazy load components that aren't needed immediately
const PatientChart = lazy(() => import('./PatientChart'));
const OrderEntry = lazy(() => import('./OrderEntry'));
const MedicationAdmin = lazy(() => import('./MedicationAdmin'));

function ClinicalWorkspace() {
  const [activeTab, setActiveTab] = useState('chart');
  
  return (
    <div className="clinical-workspace">
      <Tabs value={activeTab} onValueChange={setActiveTab}>
        <TabsList>
          <TabsTrigger value="chart">Patient Chart</TabsTrigger>
          <TabsTrigger value="orders">Order Entry</TabsTrigger>
          <TabsTrigger value="meds">Medications</TabsTrigger>
        </TabsList>
      </Tabs>
      
      <Suspense fallback={<LoadingSpinner />}>
        {activeTab === 'chart' && <PatientChart />}
        {activeTab === 'orders' && <OrderEntry />}
        {activeTab === 'meds' && <MedicationAdmin />}
      </Suspense>
    </div>
  );
}
```

### Data Virtualization

Render only the visible portion of large datasets to improve performance:

```jsx
import { useVirtualizer } from '@tanstack/react-virtual';

function PatientList({ patients }) {
  const parentRef = useRef(null);
  
  const rowVirtualizer = useVirtualizer({
    count: patients.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 80, // estimated row height
    overscan: 5, // number of items to render outside of the visible area
  });
  
  return (
    <div 
      ref={parentRef} 
      className="patient-list" 
      style={{ height: '600px', overflow: 'auto' }}
    >
      <div
        style={{
          height: `${rowVirtualizer.getTotalSize()}px`,
          width: '100%',
          position: 'relative',
        }}
      >
        {rowVirtualizer.getVirtualItems().map(virtualRow => {
          const patient = patients[virtualRow.index];
          
          return (
            <div
              key={patient.id}
              className="patient-item"
              style={{
                position: 'absolute',
                top: 0,
                left: 0,
                width: '100%',
                height: `${virtualRow.size}px`,
                transform: `translateY(${virtualRow.start}px)`,
              }}
            >
              <PatientCard patient={patient} />
            </div>
          );
        })}
      </div>
    </div>
  );
}
```

## Healthcare-Specific Optimizations

### Clinical Data Caching

Implement efficient caching strategies for clinical data:

```jsx
import { useQuery, useQueryClient } from '@tanstack/react-query';

// Set up cache configuration for clinical data
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      // Clinical data typically needs to be fresh
      staleTime: 5 * 60 * 1000, // 5 minutes
      cacheTime: 30 * 60 * 1000, // 30 minutes
      refetchOnWindowFocus: true,
      retry: 2,
    },
  },
});

// Custom hook for patient data with optimized caching
function usePatientData(patientId) {
  const queryClient = useQueryClient();
  
  // Main patient data query
  const patientQuery = useQuery(
    ['patient', patientId],
    () => fetchPatientData(patientId),
    {
      // Critical patient data should be fresh
      staleTime: 2 * 60 * 1000, // 2 minutes
      onSuccess: (data) => {
        // Pre-populate related queries
        queryClient.setQueryData(
          ['patient', patientId, 'demographics'],
          data.demographics
        );
      },
    }
  );
  
  // Lab results query with different caching strategy
  const labsQuery = useQuery(
    ['patient', patientId, 'labs'],
    () => fetchPatientLabs(patientId),
    {
      // Lab results change less frequently
      staleTime: 10 * 60 * 1000, // 10 minutes
      // Enable prefetching of lab details when hovering
      onSuccess: (labResults) => {
        // Prefetch details for critical labs
        labResults
          .filter(lab => lab.isCritical)
          .forEach(lab => {
            queryClient.prefetchQuery(
              ['lab', lab.id],
              () => fetchLabDetails(lab.id)
            );
          });
      },
    }
  );
  
  return {
    patient: patientQuery.data,
    labs: labsQuery.data,
    isLoading: patientQuery.isLoading || labsQuery.isLoading,
    isError: patientQuery.isError || labsQuery.isError,
  };
}
```

### Critical Path Optimization

Optimize the critical rendering path for clinical workflows:

```jsx
function ClinicalDashboard() {
  // Split data fetching into critical and non-critical paths
  const { data: criticalData, isLoading: criticalLoading } = useQuery(
    ['critical-patient-data'],
    fetchCriticalData,
    { priority: 'high' } // React Query v4 feature
  );
  
  const { data: nonCriticalData, isLoading: nonCriticalLoading } = useQuery(
    ['non-critical-data'],
    fetchNonCriticalData,
    { priority: 'low' } // Lower priority, won't block critical data
  );
  
  return (
    <div className="clinical-dashboard">
      {/* Critical path - render as soon as data is available */}
      <Suspense fallback={<CriticalDataSkeleton />}>
        <CriticalDataDisplay data={criticalData} />
      </Suspense>
      
      {/* Non-critical path - can load after critical content */}
      <Suspense fallback={<NonCriticalSkeleton />}>
        <NonCriticalDataDisplay data={nonCriticalData} />
      </Suspense>
    </div>
  );
}
```

### Progressive Loading for Medical Images

Implement progressive loading for medical images and studies:

```jsx
import { useState, useEffect } from 'react';

function MedicalImageViewer({ studyId }) {
  const [imageQuality, setImageQuality] = useState('low');
  const [seriesIndex, setSeriesIndex] = useState(0);
  const [loadedSeries, setLoadedSeries] = useState([]);
  
  // Fetch study metadata first
  const { data: studyMetadata } = useQuery(
    ['study-metadata', studyId],
    () => fetchStudyMetadata(studyId)
  );
  
  // Then load the first series in low quality
  useEffect(() => {
    if (studyMetadata && studyMetadata.series.length > 0) {
      fetchImageSeries(studyId, studyMetadata.series[0].id, 'low')
        .then(seriesData => {
          setLoadedSeries([{
            id: studyMetadata.series[0].id,
            quality: 'low',
            data: seriesData
          }]);
          
          // Then upgrade to high quality
          return fetchImageSeries(studyId, studyMetadata.series[0].id, 'high');
        })
        .then(highQualityData => {
          setLoadedSeries(prev => [
            {
              id: studyMetadata.series[0].id,
              quality: 'high',
              data: highQualityData
            }
          ]);
          setImageQuality('high');
        });
    }
  }, [studyId, studyMetadata]);
  
  // Prefetch adjacent series when user navigates
  const handleSeriesChange = (newIndex) => {
    setSeriesIndex(newIndex);
    
    // Prefetch next and previous series if they exist
    if (studyMetadata) {
      const seriesToPrefetch = [];
      
      if (newIndex < studyMetadata.series.length - 1) {
        seriesToPrefetch.push(studyMetadata.series[newIndex + 1].id);
      }
      
      if (newIndex > 0) {
        seriesToPrefetch.push(studyMetadata.series[newIndex - 1].id);
      }
      
      // Prefetch in low quality first
      seriesToPrefetch.forEach(seriesId => {
        if (!loadedSeries.some(s => s.id === seriesId)) {
          fetchImageSeries(studyId, seriesId, 'low');
        }
      });
    }
  };
  
  return (
    <div className="medical-image-viewer">
      {studyMetadata ? (
        <>
          <div className="viewer-controls">
            <SeriesSelector 
              series={studyMetadata.series}
              currentIndex={seriesIndex}
              onChange={handleSeriesChange}
            />
          </div>
          
          <div className="image-display">
            {loadedSeries.length > 0 && (
              <ImageRenderer 
                seriesData={loadedSeries.find(s => 
                  s.id === studyMetadata.series[seriesIndex].id
                )?.data}
                quality={imageQuality}
              />
            )}
          </div>
        </>
      ) : (
        <LoadingSpinner />
      )}
    </div>
  );
}
```

## Advanced Optimization Techniques

### Web Workers for Intensive Computations

Offload intensive computations to web workers to keep the main thread responsive:

```jsx
import { useState } from 'react';
import { useWorker } from '@koale/useworker';

// Complex calculation function to run in a worker
function calculateRiskScore(patientData, labResults, medications) {
  // Complex algorithm that would block the main thread
  // ...
  return riskScore;
}

function PatientRiskAssessment({ patient }) {
  const [riskScore, setRiskScore] = useState(null);
  const [calculating, setCalculating] = useState(false);
  
  // Create a worker for the calculation
  const [workerFn, { status, kill }] = useWorker(calculateRiskScore);
  
  const handleCalculateRisk = async () => {
    setCalculating(true);
    try {
      // Run calculation in web worker
      const score = await workerFn(
        patient.data,
        patient.labResults,
        patient.medications
      );
      setRiskScore(score);
    } catch (error) {
      console.error('Risk calculation failed:', error);
    } finally {
      setCalculating(false);
    }
  };
  
  return (
    <Card>
      <CardHeader>
        <CardTitle>Risk Assessment</CardTitle>
      </CardHeader>
      <CardContent>
        {riskScore !== null ? (
          <div className="risk-score">
            <h3>Risk Score: {riskScore.toFixed(2)}</h3>
            <RiskIndicator score={riskScore} />
          </div>
        ) : (
          <p>Calculate risk score based on patient data</p>
        )}
      </CardContent>
      <CardFooter>
        <Button 
          onClick={handleCalculateRisk} 
          disabled={calculating}
        >
          {calculating ? 'Calculating...' : 'Calculate Risk'}
        </Button>
      </CardFooter>
    </Card>
  );
}
```

### Resource Prioritization

Prioritize loading of critical resources for healthcare applications:

```jsx
// In your application entry point
import { unstable_IdlePriority as IdlePriority, unstable_scheduleCallback as scheduleCallback } from 'scheduler';

// Initialize critical resources immediately
function initApp() {
  // Load critical patient data first
  loadCriticalPatientData();
  
  // Schedule non-critical initialization for idle time
  scheduleCallback(IdlePriority, () => {
    // Initialize analytics
    initAnalytics();
  });
  
  scheduleCallback(IdlePriority, () => {
    // Prefetch likely-to-be-needed resources
    prefetchCommonResources();
  });
  
  scheduleCallback(IdlePriority, () => {
    // Register service worker for offline support
    registerServiceWorker();
  });
}

// Resource hints for critical resources
function addResourceHints() {
  // Preconnect to critical APIs
  const preconnect = document.createElement('link');
  preconnect.rel = 'preconnect';
  preconnect.href = 'https://api.healthcare-system.org';
  document.head.appendChild(preconnect);
  
  // Prefetch critical resources
  const prefetch = document.createElement('link');
  prefetch.rel = 'prefetch';
  prefetch.href = '/assets/critical-patient-data-worker.js';
  document.head.appendChild(prefetch);
}

// Call during initialization
addResourceHints();
initApp();
```

### Memory Management

Implement careful memory management for long-running healthcare applications:

```jsx
import { useEffect, useRef } from 'react';

// Custom hook to prevent memory leaks in long-running applications
function useMemoryManagement(cleanupInterval = 60000) {
  const cleanupTimerRef = useRef(null);
  const memoryStats = useRef({
    leaks: [],
    disposedResources: 0
  });
  
  // Setup periodic cleanup
  useEffect(() => {
    // Function to clean up resources
    const performCleanup = () => {
      // Check for detached DOM nodes with event listeners
      detectDetachedNodes();
      
      // Clean up image caches older than threshold
      cleanImageCache(30 * 60 * 1000); // 30 minutes
      
      // Dispose of unused large objects
      disposeUnusedObjects();
      
      // Log memory usage if available
      if (window.performance && window.performance.memory) {
        console.log('Memory usage:', window.performance.memory);
      }
    };
    
    // Set up periodic cleanup
    cleanupTimerRef.current = setInterval(performCleanup, cleanupInterval);
    
    return () => {
      if (cleanupTimerRef.current) {
        clearInterval(cleanupTimerRef.current);
      }
    };
  }, [cleanupInterval]);
  
  // Helper functions for memory management
  const detectDetachedNodes = () => {
    // Implementation would depend on application structure
    // This is a simplified example
    const suspiciousNodes = [];
    // Logic to find detached nodes with event listeners
    // ...
    
    if (suspiciousNodes.length > 0) {
      memoryStats.current.leaks.push({
        timestamp: Date.now(),
        count: suspiciousNodes.length
      });
    }
  };
  
  const cleanImageCache = (maxAge) => {
    // Implementation for cleaning image cache
    // ...
  };
  
  const disposeUnusedObjects = () => {
    // Implementation for disposing unused objects
    // ...
  };
  
  return memoryStats.current;
}

// Usage in a long-running application component
function ClinicalWorkstation() {
  const memoryStats = useMemoryManagement();
  
  // Rest of component implementation
  // ...
  
  return (
    <div className="clinical-workstation">
      {/* Application UI */}
      
      {/* Optional: Debug panel for memory stats in development */}
      {process.env.NODE_ENV === 'development' && (
        <MemoryStatsPanel stats={memoryStats} />
      )}
    </div>
  );
}
```

## Performance Monitoring

### Real User Monitoring

Implement real user monitoring to track performance metrics:

```jsx
import { useEffect } from 'react';

// Custom hook for performance monitoring
function usePerformanceMonitoring() {
  useEffect(() => {
    // Track page load performance
    if (window.performance) {
      // Wait for the page to fully load
      window.addEventListener('load', () => {
        // Capture navigation timing metrics
        const pageNavigation = performance.getEntriesByType('navigation')[0];
        const paintMetrics = performance.getEntriesByType('paint');
        
        // Calculate key metrics
        const timeToFirstByte = pageNavigation.responseStart - pageNavigation.requestStart;
        const domContentLoaded = pageNavigation.domContentLoadedEventEnd - pageNavigation.startTime;
        const fullPageLoad = pageNavigation.loadEventEnd - pageNavigation.startTime;
        
        // Find paint metrics
        const firstPaint = paintMetrics.find(metric => metric.name === 'first-paint');
        const firstContentfulPaint = paintMetrics.find(metric => metric.name === 'first-contentful-paint');
        
        // Send metrics to analytics
        sendPerformanceMetrics({
          timeToFirstByte,
          domContentLoaded,
          fullPageLoad,
          firstPaint: firstPaint ? firstPaint.startTime : null,
          firstContentfulPaint: firstContentfulPaint ? firstContentfulPaint.startTime : null,
        });
      });
      
      // Track long tasks that might cause jank
      const observer = new PerformanceObserver((list) => {
        list.getEntries().forEach((entry) => {
          // Log tasks that take more than 100ms (potential UI jank)
          if (entry.duration > 100) {
            console.warn('Long task detected:', entry);
            sendLongTaskMetric({
              duration: entry.duration,
              startTime: entry.startTime,
              name: entry.name
            });
          }
        });
      });
      
      observer.observe({ entryTypes: ['longtask'] });
      
      return () => {
        observer.disconnect();
      };
    }
  }, []);
}

// Component-level performance tracking
function withPerformanceTracking(Component, componentName) {
  return function WrappedComponent(props) {
    const startTime = performance.now();
    
    useEffect(() => {
      const renderTime = performance.now() - startTime;
      sendComponentRenderMetric(componentName, renderTime);
      
      // Track when component becomes visible in viewport
      const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
          if (entry.isIntersecting) {
            const timeToVisible = performance.now() - startTime;
            sendComponentVisibilityMetric(componentName, timeToVisible);
            observer.disconnect();
          }
        });
      });
      
      // Start observing the component
      observer.observe(document.querySelector(`[data-component="${componentName}"]`));
      
      return () => {
        observer.disconnect();
      };
    }, []);
    
    return <Component {...props} data-component={componentName} />;
  };
}

// Usage
const PatientDashboard = withPerformanceTracking(
  function PatientDashboard(props) {
    usePerformanceMonitoring();
    
    // Component implementation
    // ...
    
    return <div>{/* Dashboard content */}</div>;
  },
  'PatientDashboard'
);
```

### Performance Budgets

Establish and monitor performance budgets for healthcare applications:

```js
// webpack.config.js
module.exports = {
  // ... other webpack configuration
  performance: {
    // Set size hints for healthcare applications
    maxAssetSize: 250000, // 250 KB per asset
    maxEntrypointSize: 500000, // 500 KB per entrypoint
    hints: 'warning', // or 'error' in CI/CD pipeline
    // Custom asset filter
    assetFilter: function(assetFilename) {
      // Exclude maps and large medical image assets from performance checks
      return !assetFilename.endsWith('.map') && 
             !assetFilename.includes('medical-images');
    },
  },
};

// Monitor runtime performance budgets
const PERFORMANCE_BUDGETS = {
  // Time budgets (milliseconds)
  timeToInteractive: 3000,
  firstContentfulPaint: 1500,
  firstInputDelay: 100,
  // Size budgets (bytes)
  totalJavaScript: 500000,
  totalCSS: 100000,
  // Custom healthcare metrics
  patientSearchResponse: 500,
  medicationOrderCompletion: 2000,
};

function checkPerformanceBudgets(metrics) {
  const violations = [];
  
  Object.entries(metrics).forEach(([key, value]) => {
    if (PERFORMANCE_BUDGETS[key] && value > PERFORMANCE_BUDGETS[key]) {
      violations.push({
        metric: key,
        budget: PERFORMANCE_BUDGETS[key],
        actual: value,
        overage: value - PERFORMANCE_BUDGETS[key]
      });
    }
  });
  
  if (violations.length > 0) {
    // Log violations and send to monitoring system
    console.warn('Performance budget violations:', violations);
    sendPerformanceBudgetViolations(violations);
  }
  
  return violations;
}
```

## Conclusion

Performance optimization is essential for healthcare applications, where responsiveness and efficiency directly impact clinical workflows and patient care. By implementing these advanced patterns, developers can create high-performance applications that provide a smooth user experience even with complex interfaces and large datasets.

The CMM Reference Architecture Design System incorporates these performance optimization patterns to ensure that healthcare applications remain responsive and efficient. By following these guidelines, developers can create applications that meet the demanding performance requirements of healthcare environments.
