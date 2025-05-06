# Component Composition Patterns

## Introduction

Component composition is a powerful pattern for building complex, flexible, and maintainable user interfaces. The CMM Reference Architecture Design System leverages advanced composition patterns to create a cohesive system that can address the diverse needs of healthcare applications. This document explores these patterns and provides guidance on effectively composing components.

## Core Composition Patterns

### Compound Components

Compound components are a pattern where multiple components work together to create a cohesive experience while maintaining flexibility. Each component in the group shares state and behavior through React context.

#### Example: Form Controls

```jsx
// Compound component pattern for form controls
const FormControlContext = React.createContext({});

function FormControl({ children, id, required, disabled, invalid }) {
  // Generate a unique ID if none is provided
  const generatedId = useId();
  const fieldId = id || generatedId;
  
  // Create shared context value
  const context = {
    id: fieldId,
    required,
    disabled,
    invalid,
    describedBy: {}
  };
  
  return (
    <FormControlContext.Provider value={context}>
      <div className="form-control">
        {children}
      </div>
    </FormControlContext.Provider>
  );
}

// Sub-components that consume the shared context
FormControl.Label = function FormControlLabel({ children, htmlFor, ...props }) {
  const { id, required } = useContext(FormControlContext);
  
  return (
    <label htmlFor={htmlFor || id} {...props}>
      {children}
      {required && <span aria-hidden="true" className="required-indicator"> *</span>}
    </label>
  );
};

FormControl.Input = function FormControlInput({ id, ...props }) {
  const context = useContext(FormControlContext);
  
  return (
    <input
      id={id || context.id}
      aria-required={context.required}
      aria-invalid={context.invalid}
      disabled={context.disabled}
      {...props}
    />
  );
};

FormControl.Error = function FormControlError({ children }) {
  const { id, invalid } = useContext(FormControlContext);
  const errorId = `${id}-error`;
  
  // Register this error message with the context
  useEffect(() => {
    context.describedBy.error = errorId;
  }, []);
  
  if (!invalid) return null;
  
  return (
    <div id={errorId} className="error-message" role="alert">
      {children}
    </div>
  );
};

FormControl.Helper = function FormControlHelper({ children }) {
  const { id } = useContext(FormControlContext);
  const helperId = `${id}-helper`;
  
  // Register this helper text with the context
  useEffect(() => {
    context.describedBy.helper = helperId;
  }, []);
  
  return (
    <div id={helperId} className="helper-text">
      {children}
    </div>
  );
};

// Usage example
function PatientForm() {
  return (
    <form>
      <FormControl required>
        <FormControl.Label>Patient Name</FormControl.Label>
        <FormControl.Input placeholder="Enter patient name" />
        <FormControl.Helper>Enter the patient's full legal name</FormControl.Helper>
      </FormControl>
      
      <FormControl invalid>
        <FormControl.Label>Date of Birth</FormControl.Label>
        <FormControl.Input type="date" />
        <FormControl.Error>Please enter a valid date of birth</FormControl.Error>
      </FormControl>
    </form>
  );
}
```

### Composition Slots

Slots allow components to receive and render content in specific locations, providing flexibility while maintaining structure.

#### Example: Card Component with Slots

```jsx
function Card({ children, className, ...props }) {
  return (
    <div className={cn("card", className)} {...props}>
      {children}
    </div>
  );
}

Card.Header = function CardHeader({ children, className, ...props }) {
  return (
    <div className={cn("card-header", className)} {...props}>
      {children}
    </div>
  );
};

Card.Title = function CardTitle({ children, className, ...props }) {
  return (
    <h3 className={cn("card-title", className)} {...props}>
      {children}
    </h3>
  );
};

Card.Description = function CardDescription({ children, className, ...props }) {
  return (
    <p className={cn("card-description", className)} {...props}>
      {children}
    </p>
  );
};

Card.Content = function CardContent({ children, className, ...props }) {
  return (
    <div className={cn("card-content", className)} {...props}>
      {children}
    </div>
  );
};

Card.Footer = function CardFooter({ children, className, ...props }) {
  return (
    <div className={cn("card-footer", className)} {...props}>
      {children}
    </div>
  );
};

// Usage example
function PatientSummary({ patient }) {
  return (
    <Card>
      <Card.Header>
        <Card.Title>{patient.name}</Card.Title>
        <Card.Description>DOB: {formatDate(patient.dateOfBirth)}</Card.Description>
      </Card.Header>
      <Card.Content>
        <VitalSigns vitals={patient.vitals} />
      </Card.Content>
      <Card.Footer>
        <Button variant="outline">View Details</Button>
        <Button>Edit Patient</Button>
      </Card.Footer>
    </Card>
  );
}
```

### Render Props

Render props provide a way to share code between components using a prop whose value is a function.

#### Example: Collapsible Component

```jsx
function Collapsible({
  children,
  defaultOpen = false,
  onChange,
}) {
  const [open, setOpen] = useState(defaultOpen);
  
  const toggle = useCallback(() => {
    const newState = !open;
    setOpen(newState);
    onChange?.(newState);
  }, [open, onChange]);
  
  // Provide state and handlers to children
  return children({
    open,
    toggle,
  });
}

// Usage example
function ExpandableSection({ title, children }) {
  return (
    <Collapsible>
      {({ open, toggle }) => (
        <div className="expandable-section">
          <button 
            className="expandable-trigger" 
            onClick={toggle}
            aria-expanded={open}
          >
            {title}
            <ChevronIcon direction={open ? 'up' : 'down'} />
          </button>
          
          {open && (
            <div className="expandable-content">
              {children}
            </div>
          )}
        </div>
      )}
    </Collapsible>
  );
}
```

### Higher-Order Components (HOCs)

Higher-order components wrap components to add additional functionality.

#### Example: With Authentication

```jsx
function withAuthentication(Component) {
  return function WithAuthentication(props) {
    const { user, loading } = useAuth();
    
    if (loading) {
      return <LoadingSpinner />;
    }
    
    if (!user) {
      return <LoginRedirect />;
    }
    
    return <Component user={user} {...props} />;
  };
}

// Usage example
const ProtectedPatientChart = withAuthentication(PatientChart);

function App() {
  return (
    <Router>
      <Route path="/patients/:id" component={ProtectedPatientChart} />
    </Router>
  );
}
```

## Healthcare-Specific Composition Patterns

### Clinical Data Display

Composition patterns for displaying clinical data with appropriate context and actions.

#### Example: Lab Result Component

```jsx
function LabResult({ result, onAcknowledge, onOrder, children }) {
  const isAbnormal = result.value < result.range.min || result.value > result.range.max;
  const isCritical = result.value < result.criticalRange.min || result.value > result.criticalRange.max;
  
  return (
    <Card className={cn(
      "lab-result",
      isAbnormal && "lab-result-abnormal",
      isCritical && "lab-result-critical"
    )}>
      <Card.Header>
        <Card.Title>{result.name}</Card.Title>
        <Card.Description>
          Collected: {formatDateTime(result.collectedAt)}
        </Card.Description>
      </Card.Header>
      
      <Card.Content>
        <div className="lab-result-value">
          <span className="value">{result.value}</span>
          <span className="unit">{result.unit}</span>
        </div>
        
        <div className="lab-result-range">
          Reference Range: {result.range.min} - {result.range.max} {result.unit}
        </div>
        
        {isAbnormal && (
          <Alert variant={isCritical ? "critical" : "warning"}>
            {isCritical ? "Critical Value" : "Abnormal Value"}
          </Alert>
        )}
        
        {/* Render any additional content */}
        {children}
      </Card.Content>
      
      <Card.Footer>
        {onAcknowledge && (
          <Button onClick={onAcknowledge}>
            Acknowledge
          </Button>
        )}
        
        {onOrder && (
          <Button variant="outline" onClick={onOrder}>
            Order Repeat
          </Button>
        )}
      </Card.Footer>
    </Card>
  );
}

// Usage with composition
function PatientLabResults({ patientId }) {
  const { data: results } = usePatientLabResults(patientId);
  
  return (
    <div className="patient-lab-results">
      {results.map(result => (
        <LabResult 
          key={result.id} 
          result={result}
          onAcknowledge={() => acknowledgeResult(result.id)}
          onOrder={() => orderRepeatTest(result.id)}
        >
          {result.comments && (
            <div className="lab-comments">
              <h4>Comments</h4>
              <p>{result.comments}</p>
            </div>
          )}
          
          {result.history && (
            <LabTrend data={result.history} />
          )}
        </LabResult>
      ))}
    </div>
  );
}
```

### Clinical Workflows

Composition patterns for complex clinical workflows that maintain context across multiple steps.

#### Example: Medication Order Workflow

```jsx
const OrderContext = createContext({});

function MedicationOrderWorkflow({ patient, onComplete, onCancel }) {
  const [currentStep, setCurrentStep] = useState('search');
  const [orderData, setOrderData] = useState({});
  
  const updateOrderData = useCallback((data) => {
    setOrderData(prev => ({ ...prev, ...data }));
  }, []);
  
  const goToStep = useCallback((step) => {
    setCurrentStep(step);
  }, []);
  
  const handleComplete = useCallback(() => {
    onComplete(orderData);
  }, [orderData, onComplete]);
  
  // Create shared context
  const contextValue = {
    patient,
    orderData,
    updateOrderData,
    goToStep,
    handleComplete,
    onCancel
  };
  
  return (
    <OrderContext.Provider value={contextValue}>
      <Card className="medication-order-workflow">
        <Card.Header>
          <Card.Title>Medication Order</Card.Title>
          <Card.Description>
            Patient: {patient.name} (DOB: {formatDate(patient.dateOfBirth)})
          </Card.Description>
        </Card.Header>
        
        <Card.Content>
          {currentStep === 'search' && <MedicationSearch />}
          {currentStep === 'details' && <MedicationDetails />}
          {currentStep === 'review' && <MedicationReview />}
        </Card.Content>
      </Card>
    </OrderContext.Provider>
  );
}

// Step components that use the shared context
function MedicationSearch() {
  const { updateOrderData, goToStep } = useContext(OrderContext);
  const [searchTerm, setSearchTerm] = useState('');
  const { data: searchResults } = useMedicationSearch(searchTerm);
  
  const handleSelectMedication = (medication) => {
    updateOrderData({ medication });
    goToStep('details');
  };
  
  return (
    <div className="medication-search">
      <h3>Search for Medication</h3>
      <Input 
        value={searchTerm} 
        onChange={(e) => setSearchTerm(e.target.value)} 
        placeholder="Enter medication name"
      />
      
      <ul className="search-results">
        {searchResults.map(med => (
          <li key={med.id}>
            <Button variant="ghost" onClick={() => handleSelectMedication(med)}>
              {med.name} {med.strength} {med.form}
            </Button>
          </li>
        ))}
      </ul>
    </div>
  );
}

function MedicationDetails() {
  const { orderData, updateOrderData, goToStep, onCancel } = useContext(OrderContext);
  
  const handleSubmit = (e) => {
    e.preventDefault();
    goToStep('review');
  };
  
  return (
    <div className="medication-details">
      <h3>Order Details</h3>
      <p>Medication: {orderData.medication.name} {orderData.medication.strength}</p>
      
      <form onSubmit={handleSubmit}>
        {/* Order details form fields */}
        <FormControl>
          <FormControl.Label>Dose</FormControl.Label>
          <FormControl.Input 
            value={orderData.dose || ''}
            onChange={(e) => updateOrderData({ dose: e.target.value })}
            required
          />
        </FormControl>
        
        {/* More form fields */}
        
        <div className="button-group">
          <Button type="button" variant="outline" onClick={() => goToStep('search')}>
            Back
          </Button>
          <Button type="button" variant="outline" onClick={onCancel}>
            Cancel
          </Button>
          <Button type="submit">Continue</Button>
        </div>
      </form>
    </div>
  );
}

function MedicationReview() {
  const { patient, orderData, handleComplete, goToStep } = useContext(OrderContext);
  
  return (
    <div className="medication-review">
      <h3>Review Order</h3>
      
      <div className="review-section">
        <h4>Patient</h4>
        <p>{patient.name} (DOB: {formatDate(patient.dateOfBirth)})</p>
      </div>
      
      <div className="review-section">
        <h4>Medication</h4>
        <p>{orderData.medication.name} {orderData.medication.strength}</p>
      </div>
      
      {/* More review sections */}
      
      <div className="button-group">
        <Button variant="outline" onClick={() => goToStep('details')}>
          Back
        </Button>
        <Button onClick={handleComplete}>
          Submit Order
        </Button>
      </div>
    </div>
  );
}
```

## Advanced Composition Techniques

### Polymorphic Components

Polymorphic components can render as different HTML elements or components based on props.

#### Example: Text Component

```jsx
import { Slot } from '@radix-ui/react-slot';

function Text({
  children,
  className,
  asChild = false,
  as: Component = 'p',
  variant = 'body',
  ...props
}) {
  const Comp = asChild ? Slot : Component;
  
  return (
    <Comp
      className={cn(
        'text',
        {
          'text-3xl font-bold': variant === 'h1',
          'text-2xl font-bold': variant === 'h2',
          'text-xl font-bold': variant === 'h3',
          'text-lg font-medium': variant === 'h4',
          'text-base': variant === 'body',
          'text-sm': variant === 'small',
          'text-xs': variant === 'caption',
        },
        className
      )}
      {...props}
    >
      {children}
    </Comp>
  );
}

// Usage examples
function Example() {
  return (
    <div>
      <Text as="h1" variant="h1">This is a heading</Text>
      <Text>This is a paragraph</Text>
      <Text as="label" htmlFor="input" variant="small">This is a label</Text>
      
      {/* Using asChild to wrap existing elements */}
      <Text asChild variant="h2">
        <a href="/patients">Patient List</a>
      </Text>
    </div>
  );
}
```

### Component Factories

Component factories create specialized components based on configuration.

#### Example: Alert Component Factory

```jsx
function createAlertComponent(config) {
  return function Alert({ children, title, variant = 'info', action, ...props }) {
    const variantConfig = config.variants[variant] || config.variants.info;
    
    return (
      <div
        role="alert"
        className={cn(
          'alert',
          variantConfig.className,
          props.className
        )}
        {...props}
      >
        <div className="alert-icon">
          {variantConfig.icon}
        </div>
        
        <div className="alert-content">
          {title && <div className="alert-title">{title}</div>}
          <div className="alert-description">{children}</div>
        </div>
        
        {action && (
          <div className="alert-action">
            {action}
          </div>
        )}
      </div>
    );
  };
}

// Create specialized alert components
const clinicalAlertConfig = {
  variants: {
    critical: {
      className: 'bg-critical/15 text-critical border-l-4 border-critical',
      icon: <AlertTriangleIcon className="h-5 w-5" />
    },
    warning: {
      className: 'bg-warning/15 text-warning-foreground border-l-4 border-warning',
      icon: <AlertCircleIcon className="h-5 w-5" />
    },
    info: {
      className: 'bg-info/15 text-info-foreground border-l-4 border-info',
      icon: <InfoIcon className="h-5 w-5" />
    },
    success: {
      className: 'bg-success/15 text-success-foreground border-l-4 border-success',
      icon: <CheckCircleIcon className="h-5 w-5" />
    }
  }
};

const ClinicalAlert = createAlertComponent(clinicalAlertConfig);

// Usage example
function LabResultAlert({ result }) {
  const isCritical = result.value < result.criticalRange.min || result.value > result.criticalRange.max;
  const isAbnormal = result.value < result.range.min || result.value > result.range.max;
  
  if (!isAbnormal) return null;
  
  const variant = isCritical ? 'critical' : 'warning';
  const title = isCritical ? 'Critical Value' : 'Abnormal Value';
  
  return (
    <ClinicalAlert 
      variant={variant} 
      title={title}
      action={<Button size="sm">Acknowledge</Button>}
    >
      {result.name}: {result.value} {result.unit} is outside the reference range 
      ({result.range.min} - {result.range.max} {result.unit}).
    </ClinicalAlert>
  );
}
```

### Composition with Hooks

Custom hooks can provide shared behavior for component composition.

#### Example: Form Field with Validation Hook

```jsx
function useField({
  name,
  initialValue = '',
  validate,
  required = false
}) {
  const [value, setValue] = useState(initialValue);
  const [touched, setTouched] = useState(false);
  const [error, setError] = useState(null);
  
  const handleChange = useCallback((e) => {
    const newValue = e.target.value;
    setValue(newValue);
    
    if (touched) {
      validateValue(newValue);
    }
  }, [touched]);
  
  const handleBlur = useCallback(() => {
    setTouched(true);
    validateValue(value);
  }, [value]);
  
  const validateValue = useCallback((valueToValidate) => {
    if (required && !valueToValidate) {
      setError('This field is required');
      return false;
    }
    
    if (validate && valueToValidate) {
      try {
        validate(valueToValidate);
        setError(null);
        return true;
      } catch (err) {
        setError(err.message);
        return false;
      }
    }
    
    setError(null);
    return true;
  }, [required, validate]);
  
  return {
    value,
    setValue,
    error,
    touched,
    handleChange,
    handleBlur,
    isValid: !error
  };
}

// Usage with composition
function PatientForm() {
  const nameField = useField({
    name: 'patientName',
    required: true
  });
  
  const dobField = useField({
    name: 'dateOfBirth',
    required: true,
    validate: (value) => {
      const date = new Date(value);
      if (isNaN(date.getTime())) {
        throw new Error('Invalid date format');
      }
      if (date > new Date()) {
        throw new Error('Date of birth cannot be in the future');
      }
    }
  });
  
  const handleSubmit = (e) => {
    e.preventDefault();
    // Process form if all fields are valid
  };
  
  return (
    <form onSubmit={handleSubmit}>
      <FormControl invalid={nameField.touched && !!nameField.error}>
        <FormControl.Label>Patient Name</FormControl.Label>
        <FormControl.Input
          value={nameField.value}
          onChange={nameField.handleChange}
          onBlur={nameField.handleBlur}
          required
        />
        {nameField.error && (
          <FormControl.Error>{nameField.error}</FormControl.Error>
        )}
      </FormControl>
      
      <FormControl invalid={dobField.touched && !!dobField.error}>
        <FormControl.Label>Date of Birth</FormControl.Label>
        <FormControl.Input
          type="date"
          value={dobField.value}
          onChange={dobField.handleChange}
          onBlur={dobField.handleBlur}
          required
        />
        {dobField.error && (
          <FormControl.Error>{dobField.error}</FormControl.Error>
        )}
      </FormControl>
      
      <Button type="submit" disabled={!nameField.isValid || !dobField.isValid}>
        Submit
      </Button>
    </form>
  );
}
```

## Best Practices

### Composition Guidelines

1. **Prefer Composition Over Inheritance**: Build complex components by composing smaller ones rather than using inheritance hierarchies.

2. **Single Responsibility Principle**: Each component should have a single responsibility, making it easier to compose and maintain.

3. **Consistent Props API**: Maintain consistent prop names and patterns across components to make composition intuitive.

4. **Forward Refs and Props**: Always forward refs and spread remaining props to enable proper composition.

5. **Document Composition Patterns**: Clearly document how components can be composed together.

### Performance Considerations

1. **Memoization**: Use React.memo, useMemo, and useCallback to prevent unnecessary re-renders in composed components.

2. **Context Optimization**: Split contexts to minimize re-renders when state changes.

3. **Lazy Loading**: Use React.lazy for code-splitting complex component compositions.

4. **Virtualization**: Implement virtualization for long lists of composed components.

### Accessibility in Composition

1. **Maintain ARIA Relationships**: Ensure proper ARIA relationships are preserved when composing components.

2. **Keyboard Navigation**: Preserve logical keyboard navigation flow in composed interfaces.

3. **Focus Management**: Implement proper focus management, especially in complex workflows.

4. **Screen Reader Announcements**: Ensure dynamic content changes are properly announced to screen readers.

## Conclusion

Advanced component composition patterns enable the creation of flexible, maintainable, and accessible healthcare interfaces. By leveraging these patterns, developers can build complex applications while maintaining consistency with the design system. The CMM Reference Architecture Design System provides a robust foundation of composable components that can be combined to address the unique requirements of healthcare applications.
