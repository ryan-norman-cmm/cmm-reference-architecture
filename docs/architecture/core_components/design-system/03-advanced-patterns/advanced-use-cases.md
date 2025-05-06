# Design System Advanced Use Cases

## Introduction

This document outlines advanced use cases for the Design System in the CMM Technology Platform. While the core components and patterns cover most common scenarios, these advanced use cases demonstrate how to leverage the Design System for complex, specialized healthcare applications. Understanding these advanced patterns will help developers create sophisticated interfaces while maintaining consistency and accessibility.

## Clinical Workflow Use Cases

### Patient Timeline Visualization

Create comprehensive patient timelines that display clinical events, medications, and encounters:

```jsx
function PatientTimeline({ patientId }) {
  const { data } = usePatientTimeline(patientId);
  
  return (
    <Card className="p-6">
      <CardHeader>
        <CardTitle>Patient Timeline</CardTitle>
        <CardDescription>Clinical history and events</CardDescription>
      </CardHeader>
      <CardContent>
        <Timeline>
          {data.events.map(event => (
            <Timeline.Item 
              key={event.id}
              date={event.date}
              category={event.category}
              icon={getCategoryIcon(event.category)}
              severity={event.severity}
            >
              <h3 className="font-medium">{event.title}</h3>
              <p className="text-sm text-muted-foreground">{event.description}</p>
              {event.details && (
                <Collapsible>
                  <CollapsibleTrigger asChild>
                    <Button variant="link" size="sm">View Details</Button>
                  </CollapsibleTrigger>
                  <CollapsibleContent>
                    <div className="mt-2 text-sm">
                      {event.details}
                    </div>
                  </CollapsibleContent>
                </Collapsible>
              )}
            </Timeline.Item>
          ))}
        </Timeline>
      </CardContent>
    </Card>
  );
}
```

### Clinical Decision Support

Implement clinical decision support interfaces that present recommendations while maintaining context:

```jsx
function ClinicalDecisionSupport({ patientId, context }) {
  const { recommendations, loading } = useClinicalRecommendations(patientId, context);
  
  if (loading) return <Spinner />;
  
  return (
    <Card className="border-l-4 border-l-clinical">
      <CardHeader className="pb-2">
        <CardTitle className="flex items-center">
          <AlertCircle className="mr-2 h-5 w-5 text-clinical" />
          Clinical Recommendations
        </CardTitle>
      </CardHeader>
      <CardContent>
        <ul className="space-y-2">
          {recommendations.map(rec => (
            <li key={rec.id} className="p-2 rounded bg-muted/50">
              <div className="flex items-start">
                <div className="mr-4">
                  <Badge variant={rec.urgency}>{rec.urgency}</Badge>
                </div>
                <div>
                  <h4 className="font-medium">{rec.title}</h4>
                  <p className="text-sm text-muted-foreground">{rec.description}</p>
                  <div className="mt-2 flex space-x-2">
                    <Button size="sm" variant="outline" onClick={() => rec.onAccept()}>Accept</Button>
                    <Button size="sm" variant="ghost" onClick={() => rec.onDismiss()}>Dismiss</Button>
                    <Button size="sm" variant="link" onClick={() => rec.onViewEvidence()}>View Evidence</Button>
                  </div>
                </div>
              </div>
            </li>
          ))}
        </ul>
      </CardContent>
    </Card>
  );
}
```

### Medication Reconciliation

Create interfaces for complex medication reconciliation workflows:

```jsx
function MedicationReconciliation({ patientId, encounterId }) {
  const { medications, sources, actions, loading } = useMedicationReconciliation(patientId, encounterId);
  
  if (loading) return <Spinner />;
  
  return (
    <div className="space-y-6">
      <Card>
        <CardHeader>
          <CardTitle>Medication Reconciliation</CardTitle>
          <CardDescription>Compare and reconcile medications from different sources</CardDescription>
        </CardHeader>
        <CardContent>
          <Tabs defaultValue="compare">
            <TabsList>
              <TabsTrigger value="compare">Compare</TabsTrigger>
              <TabsTrigger value="reconcile">Reconcile</TabsTrigger>
              <TabsTrigger value="document">Document</TabsTrigger>
            </TabsList>
            <TabsContent value="compare">
              <MedicationComparisonTable 
                medications={medications} 
                sources={sources} 
              />
            </TabsContent>
            <TabsContent value="reconcile">
              <MedicationReconciliationForm 
                medications={medications} 
                onAction={actions.reconcile} 
              />
            </TabsContent>
            <TabsContent value="document">
              <MedicationDocumentationForm 
                onComplete={actions.complete} 
                onSaveDraft={actions.saveDraft} 
              />
            </TabsContent>
          </Tabs>
        </CardContent>
      </Card>
    </div>
  );
}
```

## Data Visualization Use Cases

### Clinical Dashboard

Create comprehensive clinical dashboards with multiple visualization types:

```jsx
function ClinicalDashboard({ departmentId }) {
  const { metrics, loading } = useDepartmentMetrics(departmentId);
  
  if (loading) return <Spinner />;
  
  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
      <MetricCard 
        title="Average Length of Stay" 
        value={metrics.averageLOS} 
        unit="days"
        trend={metrics.losTrend}
        trendLabel={metrics.losTrend > 0 ? 'Increased' : 'Decreased'}
        trendDirection={metrics.losTrend > 0 ? 'up' : 'down'}
        chart={<SparklineChart data={metrics.losHistory} />}
      />
      
      <MetricCard 
        title="Bed Occupancy" 
        value={metrics.bedOccupancy} 
        unit="%"
        trend={metrics.occupancyTrend}
        trendLabel={metrics.occupancyTrend > 0 ? 'Increased' : 'Decreased'}
        trendDirection={metrics.occupancyTrend > 0 ? 'up' : 'down'}
        chart={<GaugeChart value={metrics.bedOccupancy} max={100} />}
      />
      
      <MetricCard 
        title="Readmission Rate" 
        value={metrics.readmissionRate} 
        unit="%"
        trend={metrics.readmissionTrend}
        trendLabel={metrics.readmissionTrend > 0 ? 'Increased' : 'Decreased'}
        trendDirection={metrics.readmissionTrend > 0 ? 'up' : 'down'}
        chart={<SparklineChart data={metrics.readmissionHistory} />}
      />
      
      <Card className="col-span-1 md:col-span-2">
        <CardHeader>
          <CardTitle>Patient Flow</CardTitle>
        </CardHeader>
        <CardContent>
          <BarChart 
            data={metrics.patientFlow} 
            xAxis="hour" 
            yAxis="count" 
            categories={['Admissions', 'Discharges']} 
          />
        </CardContent>
      </Card>
      
      <Card>
        <CardHeader>
          <CardTitle>Top Diagnoses</CardTitle>
        </CardHeader>
        <CardContent>
          <PieChart 
            data={metrics.topDiagnoses} 
            nameKey="diagnosis" 
            valueKey="count" 
          />
        </CardContent>
      </Card>
    </div>
  );
}
```

### Population Health Analytics

Create interfaces for analyzing population health data:

```jsx
function PopulationHealthDashboard({ populationId }) {
  const { data, filters, setFilters, loading } = usePopulationHealth(populationId);
  
  if (loading) return <Spinner />;
  
  return (
    <div className="space-y-6">
      <Card>
        <CardHeader>
          <CardTitle>Population Filters</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <Select 
              label="Age Group" 
              value={filters.ageGroup} 
              onChange={value => setFilters({ ...filters, ageGroup: value })}
              options={[
                { label: 'All Ages', value: 'all' },
                { label: '0-17', value: 'pediatric' },
                { label: '18-64', value: 'adult' },
                { label: '65+', value: 'geriatric' },
              ]}
            />
            
            <Select 
              label="Gender" 
              value={filters.gender} 
              onChange={value => setFilters({ ...filters, gender: value })}
              options={[
                { label: 'All Genders', value: 'all' },
                { label: 'Male', value: 'male' },
                { label: 'Female', value: 'female' },
                { label: 'Other', value: 'other' },
              ]}
            />
            
            <Select 
              label="Risk Level" 
              value={filters.riskLevel} 
              onChange={value => setFilters({ ...filters, riskLevel: value })}
              options={[
                { label: 'All Risk Levels', value: 'all' },
                { label: 'High', value: 'high' },
                { label: 'Medium', value: 'medium' },
                { label: 'Low', value: 'low' },
              ]}
            />
          </div>
        </CardContent>
      </Card>
      
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <Card>
          <CardHeader>
            <CardTitle>Risk Stratification</CardTitle>
          </CardHeader>
          <CardContent>
            <PieChart 
              data={data.riskDistribution} 
              nameKey="risk" 
              valueKey="count" 
              colors={{
                'High': 'var(--color-destructive)',
                'Medium': 'var(--color-warning)',
                'Low': 'var(--color-success)',
              }}
            />
          </CardContent>
        </Card>
        
        <Card>
          <CardHeader>
            <CardTitle>Chronic Conditions</CardTitle>
          </CardHeader>
          <CardContent>
            <BarChart 
              data={data.chronicConditions} 
              xAxis="condition" 
              yAxis="prevalence" 
              layout="vertical"
              unit="%"
            />
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
```

## Responsive Design Use Cases

### Adaptive Clinical Workflows

Create workflows that adapt to different screen sizes and devices:

```jsx
function AdaptiveOrderEntry({ patientId }) {
  const isMobile = useMediaQuery('(max-width: 768px)');
  const { orderTypes, selectedType, setSelectedType } = useOrderContext();
  
  return (
    <div className="space-y-4">
      {isMobile ? (
        // Mobile layout - vertical flow
        <div className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle>Order Type</CardTitle>
            </CardHeader>
            <CardContent>
              <Select 
                value={selectedType} 
                onChange={setSelectedType}
                options={orderTypes.map(type => ({
                  label: type.name,
                  value: type.id,
                }))}
              />
            </CardContent>
          </Card>
          
          {selectedType && (
            <Card>
              <CardHeader>
                <CardTitle>Order Details</CardTitle>
              </CardHeader>
              <CardContent>
                <OrderForm 
                  patientId={patientId} 
                  orderType={selectedType} 
                  compact={true}
                />
              </CardContent>
            </Card>
          )}
        </div>
      ) : (
        // Desktop layout - side-by-side
        <div className="grid grid-cols-4 gap-6">
          <Card className="col-span-1">
            <CardHeader>
              <CardTitle>Order Types</CardTitle>
            </CardHeader>
            <CardContent>
              <nav className="space-y-1">
                {orderTypes.map(type => (
                  <Button 
                    key={type.id}
                    variant={selectedType === type.id ? 'default' : 'ghost'}
                    className="w-full justify-start"
                    onClick={() => setSelectedType(type.id)}
                  >
                    {type.icon && <type.icon className="mr-2 h-4 w-4" />}
                    {type.name}
                  </Button>
                ))}
              </nav>
            </CardContent>
          </Card>
          
          <Card className="col-span-3">
            <CardHeader>
              <CardTitle>Order Details</CardTitle>
            </CardHeader>
            <CardContent>
              {selectedType ? (
                <OrderForm 
                  patientId={patientId} 
                  orderType={selectedType} 
                  compact={false}
                />
              ) : (
                <div className="text-center p-6 text-muted-foreground">
                  <p>Select an order type to continue</p>
                </div>
              )}
            </CardContent>
          </Card>
        </div>
      )}
    </div>
  );
}
```

### Context-Aware Interfaces

Create interfaces that adapt based on user context and permissions:

```jsx
function ContextAwarePatientView({ patientId }) {
  const { user, permissions } = useAuth();
  const { patientData } = usePatient(patientId);
  
  // Determine user context
  const isPhysician = permissions.includes('physician');
  const isNurse = permissions.includes('nurse');
  const isAdmin = permissions.includes('admin');
  
  return (
    <div className="space-y-6">
      <PatientBanner patient={patientData} />
      
      <Tabs defaultValue={getDefaultTab()}>
        <TabsList>
          <TabsTrigger value="summary">Summary</TabsTrigger>
          {isPhysician && <TabsTrigger value="orders">Orders</TabsTrigger>}
          {(isPhysician || isNurse) && <TabsTrigger value="documentation">Documentation</TabsTrigger>}
          {(isPhysician || isNurse) && <TabsTrigger value="results">Results</TabsTrigger>}
          {isAdmin && <TabsTrigger value="billing">Billing</TabsTrigger>}
        </TabsList>
        
        <TabsContent value="summary">
          <PatientSummary patientId={patientId} userRole={user.role} />
        </TabsContent>
        
        {isPhysician && (
          <TabsContent value="orders">
            <OrderManagement patientId={patientId} />
          </TabsContent>
        )}
        
        {(isPhysician || isNurse) && (
          <TabsContent value="documentation">
            <ClinicalDocumentation patientId={patientId} userRole={user.role} />
          </TabsContent>
        )}
        
        {(isPhysician || isNurse) && (
          <TabsContent value="results">
            <ResultsViewer patientId={patientId} userRole={user.role} />
          </TabsContent>
        )}
        
        {isAdmin && (
          <TabsContent value="billing">
            <BillingManagement patientId={patientId} />
          </TabsContent>
        )}
      </Tabs>
    </div>
  );
  
  function getDefaultTab() {
    if (isPhysician) return 'orders';
    if (isNurse) return 'documentation';
    if (isAdmin) return 'billing';
    return 'summary';
  }
}
```

## Accessibility Use Cases

### Screen Reader Optimized Interfaces

Create interfaces specifically optimized for screen readers:

```jsx
function ScreenReaderOptimizedResults({ patientId }) {
  const { results, loading } = usePatientResults(patientId);
  
  if (loading) return <Spinner aria-label="Loading patient results" />;
  
  return (
    <div>
      <h2 id="results-heading">Patient Results</h2>
      <p id="results-description">Showing {results.length} recent results</p>
      
      <div 
        role="table" 
        aria-labelledby="results-heading"
        aria-describedby="results-description"
      >
        <div role="rowgroup">
          <div role="row">
            <div role="columnheader">Date</div>
            <div role="columnheader">Test</div>
            <div role="columnheader">Result</div>
            <div role="columnheader">Status</div>
          </div>
        </div>
        
        <div role="rowgroup">
          {results.map(result => (
            <div key={result.id} role="row">
              <div role="cell">{formatDate(result.date)}</div>
              <div role="cell">{result.test}</div>
              <div role="cell">
                <span aria-label={`Result: ${result.value} ${result.unit}`}>
                  {result.value} {result.unit}
                </span>
                {result.abnormal && (
                  <span 
                    className="sr-only"
                    aria-label={`This result is ${result.abnormalType}`}
                  >
                    Abnormal result
                  </span>
                )}
              </div>
              <div role="cell">
                <Badge 
                  variant={getStatusVariant(result.status)}
                  aria-label={`Status: ${result.status}`}
                >
                  {result.status}
                </Badge>
              </div>
            </div>
          ))}
        </div>
      </div>
      
      <div className="sr-only" aria-live="polite">
        {results.length} results loaded successfully
      </div>
    </div>
  );
}
```

### Keyboard Navigation Optimized Interfaces

Create interfaces with enhanced keyboard navigation:

```jsx
function KeyboardOptimizedWorkflow() {
  const [currentStep, setCurrentStep] = useState(0);
  const steps = ['Patient Selection', 'Order Entry', 'Review', 'Sign'];
  
  // Handle keyboard navigation
  useEffect(() => {
    function handleKeyDown(e) {
      // Navigate between steps with arrow keys
      if (e.key === 'ArrowRight' && currentStep < steps.length - 1) {
        setCurrentStep(currentStep + 1);
      } else if (e.key === 'ArrowLeft' && currentStep > 0) {
        setCurrentStep(currentStep - 1);
      }
    }
    
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [currentStep, steps.length]);
  
  return (
    <div>
      <div className="mb-6">
        <Steps>
          {steps.map((step, index) => (
            <Step 
              key={step} 
              title={step} 
              completed={index < currentStep}
              current={index === currentStep}
              onClick={() => setCurrentStep(index)}
              tabIndex={0}
              aria-current={index === currentStep ? 'step' : undefined}
            />
          ))}
        </Steps>
      </div>
      
      <Card>
        <CardHeader>
          <CardTitle>{steps[currentStep]}</CardTitle>
          <CardDescription>
            Step {currentStep + 1} of {steps.length}
            <span className="sr-only">
              Use arrow keys to navigate between steps
            </span>
          </CardDescription>
        </CardHeader>
        <CardContent>
          {/* Step content */}
          {currentStep === 0 && <PatientSelectionStep />}
          {currentStep === 1 && <OrderEntryStep />}
          {currentStep === 2 && <ReviewStep />}
          {currentStep === 3 && <SignStep />}
        </CardContent>
        <CardFooter className="justify-between">
          <Button
            variant="outline"
            onClick={() => setCurrentStep(Math.max(0, currentStep - 1))}
            disabled={currentStep === 0}
            aria-label="Previous step"
          >
            Previous
          </Button>
          <Button
            onClick={() => setCurrentStep(Math.min(steps.length - 1, currentStep + 1))}
            disabled={currentStep === steps.length - 1}
            aria-label="Next step"
          >
            Next
          </Button>
        </CardFooter>
      </Card>
    </div>
  );
}
```

## Theming Use Cases

### Multi-Brand Support

Create interfaces that support multiple healthcare brands:

```jsx
function MultiBrandApplication() {
  const { currentBrand, brands, setBrand } = useBranding();
  
  return (
    <ThemeProvider theme={currentBrand.theme}>
      <div className="space-y-6">
        <header className="border-b">
          <div className="container py-4 flex items-center justify-between">
            <div className="flex items-center">
              <img 
                src={currentBrand.logo} 
                alt={`${currentBrand.name} logo`} 
                className="h-8 w-auto" 
              />
              <h1 className="ml-4 text-xl font-semibold">
                {currentBrand.name} Healthcare Portal
              </h1>
            </div>
            
            <Select
              value={currentBrand.id}
              onChange={brandId => setBrand(brandId)}
              options={brands.map(brand => ({
                label: brand.name,
                value: brand.id,
              }))}
              aria-label="Select healthcare brand"
            />
          </div>
        </header>
        
        <main className="container py-6">
          <Card>
            <CardHeader>
              <CardTitle>Welcome to {currentBrand.name} Healthcare</CardTitle>
              <CardDescription>
                Access your healthcare information and services
              </CardDescription>
            </CardHeader>
            <CardContent>
              <p>This interface automatically adapts to the selected healthcare brand:</p>
              <ul className="list-disc pl-6 mt-2">
                <li>Colors and typography follow brand guidelines</li>
                <li>Component styling reflects brand personality</li>
                <li>Terminology adapts to brand preferences</li>
              </ul>
            </CardContent>
          </Card>
        </main>
      </div>
    </ThemeProvider>
  );
}
```

### Department-Specific Theming

Create interfaces with department-specific themes:

```jsx
function DepartmentSpecificInterface() {
  const { department } = useDepartmentContext();
  const departmentThemes = {
    emergency: 'emergency',
    radiology: 'radiology',
    cardiology: 'cardiology',
    pediatrics: 'pediatrics',
    default: 'clinical',
  };
  
  const theme = departmentThemes[department] || departmentThemes.default;
  
  return (
    <ThemeProvider theme={theme}>
      <div className="space-y-6">
        <header className="border-b bg-departmentHeader text-departmentHeaderForeground">
          <div className="container py-4">
            <h1 className="text-xl font-semibold flex items-center">
              {getDepartmentIcon(department)}
              <span className="ml-2">{getDepartmentName(department)} Department</span>
            </h1>
          </div>
        </header>
        
        <main className="container py-6">
          <Card>
            <CardHeader>
              <CardTitle>Department Dashboard</CardTitle>
            </CardHeader>
            <CardContent>
              <p>This interface automatically adapts to the department context:</p>
              <ul className="list-disc pl-6 mt-2">
                <li>Color scheme optimized for {getDepartmentName(department)} workflows</li>
                <li>Department-specific terminology and icons</li>
                <li>Specialized components for {getDepartmentName(department)} use cases</li>
              </ul>
            </CardContent>
          </Card>
        </main>
      </div>
    </ThemeProvider>
  );
  
  function getDepartmentIcon(dept) {
    const icons = {
      emergency: <Ambulance className="h-5 w-5" />,
      radiology: <XRay className="h-5 w-5" />,
      cardiology: <Heart className="h-5 w-5" />,
      pediatrics: <Baby className="h-5 w-5" />,
    };
    
    return icons[dept] || <Hospital className="h-5 w-5" />;
  }
  
  function getDepartmentName(dept) {
    const names = {
      emergency: 'Emergency',
      radiology: 'Radiology',
      cardiology: 'Cardiology',
      pediatrics: 'Pediatrics',
    };
    
    return names[dept] || 'Clinical';
  }
}
```

## Conclusion

These advanced use cases demonstrate the flexibility and power of the Design System in addressing complex healthcare scenarios. By leveraging the Design System's components, patterns, and utilities, developers can create sophisticated interfaces that maintain consistency, accessibility, and usability across the healthcare ecosystem. These examples provide a starting point for implementing advanced features while adhering to the Design System's principles and guidelines.

## Related Documentation

- [Extension Points](./extension-points.md)
- [Customization](./customization.md)
- [Accessibility](./accessibility.md)
- [Responsive Design](./responsive-design.md)
- [Theming](./theming.md)
