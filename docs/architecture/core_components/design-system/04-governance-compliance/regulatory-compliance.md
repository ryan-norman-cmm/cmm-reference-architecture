# Regulatory Compliance

## Introduction

Healthcare applications must adhere to strict regulatory requirements to ensure patient safety, data privacy, and system reliability. The CMM Technology Platform Design System incorporates compliance considerations directly into its components and patterns to simplify the development of compliant healthcare applications.

## HIPAA Compliance

The Health Insurance Portability and Accountability Act (HIPAA) establishes standards for protecting sensitive patient data.

### Component Requirements

#### Authentication Components

- **Automatic Session Timeout**: Components must implement automatic session timeout after a configurable period of inactivity (default: 15 minutes)
- **Multi-factor Authentication**: Support for various MFA methods including SMS, email, authenticator apps, and biometrics
- **Role-based Access Control**: Components must respect and enforce role-based permissions

#### Data Display Components

- **PHI Visibility Controls**: Features to mask or limit visibility of Protected Health Information
- **Audit Logging Integration**: All components that display or modify PHI must integrate with audit logging systems
- **Print Management**: Controls for secure printing, watermarking, and print logging

#### User Interface Patterns

- **Privacy Indicators**: Visual indicators when screens may be visible to others
- **Consent Management**: UI patterns for capturing and displaying consent
- **Break-glass Procedures**: Components for emergency access with appropriate logging

### Implementation Examples

```jsx
// Example: PHI Display component with privacy controls
function PHIDisplay({ data, sensitivity = 'medium', children }) {
  const [isVisible, setIsVisible] = useState(false);
  const { hasPermission } = usePermissions();
  const { logAccess } = useAuditLogging();
  
  // Check if user has permission to view this data
  const canView = hasPermission(`view:${sensitivity}`);
  
  // Log access when data is viewed
  useEffect(() => {
    if (isVisible && canView) {
      logAccess({
        dataType: data.type,
        dataId: data.id,
        action: 'view',
        timestamp: new Date().toISOString(),
      });
    }
  }, [isVisible, canView, data, logAccess]);
  
  if (!canView) {
    return (
      <div className="phi-restricted">
        <LockIcon className="h-4 w-4 mr-2" />
        <span>You don't have permission to view this information</span>
      </div>
    );
  }
  
  return (
    <div className="phi-container">
      {sensitivity === 'high' && !isVisible ? (
        <Button 
          variant="outline" 
          size="sm"
          onClick={() => setIsVisible(true)}
          className="phi-reveal-button"
        >
          <EyeIcon className="h-4 w-4 mr-2" />
          Show Sensitive Information
        </Button>
      ) : (
        <div className="phi-content">
          {children}
          {sensitivity === 'high' && (
            <Button 
              variant="ghost" 
              size="sm"
              onClick={() => setIsVisible(false)}
              className="phi-hide-button"
            >
              <EyeOffIcon className="h-4 w-4 mr-2" />
              Hide
            </Button>
          )}
        </div>
      )}
    </div>
  );
}
```

## 21 CFR Part 11

Title 21 CFR Part 11 establishes requirements for electronic records and electronic signatures in FDA-regulated industries.

### Component Requirements

#### Electronic Signature Components

- **Multi-factor Authentication**: Require at least two identification components
- **Signature Meaning**: Clear indication of the meaning of signatures (e.g., review, approval, authorship)
- **Signature Manifestation**: Display of printed name, date/time, and meaning of signature

#### Audit Trail Components

- **Record Change Tracking**: Components for tracking all changes to electronic records
- **Non-repudiation Features**: Mechanisms to ensure signatures cannot be repudiated
- **Audit Log Viewers**: Interfaces for reviewing audit trails

#### Validation Features

- **System Checks**: Components for validating system integrity
- **Error Handling**: Standardized error handling and reporting
- **Data Integrity Indicators**: Visual indicators of data integrity status

### Implementation Examples

```jsx
// Example: Audit log viewer component for 21 CFR Part 11 compliance
function AuditLogViewer({ recordId, recordType }) {
  const { data: auditTrail, isLoading } = useAuditTrail(recordId, recordType);
  const [filters, setFilters] = useState({
    startDate: null,
    endDate: null,
    eventType: 'all',
    user: '',
  });
  
  // Filter audit trail based on current filters
  const filteredAuditTrail = useMemo(() => {
    if (!auditTrail) return [];
    
    return auditTrail.filter(entry => {
      // Apply date filters
      if (filters.startDate && new Date(entry.timestamp) < filters.startDate) return false;
      if (filters.endDate && new Date(entry.timestamp) > filters.endDate) return false;
      
      // Apply event type filter
      if (filters.eventType !== 'all' && entry.eventType !== filters.eventType) return false;
      
      // Apply user filter
      if (filters.user && !entry.username.toLowerCase().includes(filters.user.toLowerCase())) return false;
      
      return true;
    });
  }, [auditTrail, filters]);
  
  // Handle filter changes
  const handleFilterChange = (key, value) => {
    setFilters(prev => ({ ...prev, [key]: value }));
  };
  
  // Handle export of audit trail
  const handleExport = () => {
    // Implementation for exporting audit trail to PDF or CSV
    // with appropriate security controls
  };
  
  if (isLoading) return <LoadingSpinner />;
  
  return (
    <div className="audit-log-viewer">
      <div className="audit-log-filters">
        {/* Filter controls */}
        <div className="filter-group">
          <Label htmlFor="startDate">Start Date</Label>
          <DatePicker
            id="startDate"
            selected={filters.startDate}
            onChange={date => handleFilterChange('startDate', date)}
          />
        </div>
        
        <div className="filter-group">
          <Label htmlFor="endDate">End Date</Label>
          <DatePicker
            id="endDate"
            selected={filters.endDate}
            onChange={date => handleFilterChange('endDate', date)}
          />
        </div>
        
        <div className="filter-group">
          <Label htmlFor="eventType">Event Type</Label>
          <Select
            id="eventType"
            value={filters.eventType}
            onValueChange={value => handleFilterChange('eventType', value)}
          >
            <SelectItem value="all">All Events</SelectItem>
            <SelectItem value="create">Create</SelectItem>
            <SelectItem value="update">Update</SelectItem>
            <SelectItem value="delete">Delete</SelectItem>
            <SelectItem value="view">View</SelectItem>
            <SelectItem value="sign">Electronic Signature</SelectItem>
          </Select>
        </div>
        
        <div className="filter-group">
          <Label htmlFor="user">User</Label>
          <Input
            id="user"
            value={filters.user}
            onChange={e => handleFilterChange('user', e.target.value)}
            placeholder="Filter by username"
          />
        </div>
      </div>
      
      <div className="audit-log-actions">
        <Button onClick={handleExport} variant="outline">
          <DownloadIcon className="h-4 w-4 mr-2" />
          Export Audit Trail
        </Button>
      </div>
      
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Timestamp</TableHead>
            <TableHead>User</TableHead>
            <TableHead>Event Type</TableHead>
            <TableHead>Description</TableHead>
            <TableHead>Details</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {filteredAuditTrail.map(entry => (
            <TableRow key={entry.id}>
              <TableCell>{formatDateTime(entry.timestamp)}</TableCell>
              <TableCell>{entry.username}</TableCell>
              <TableCell>
                <Badge variant={getEventTypeBadgeVariant(entry.eventType)}>
                  {entry.eventType}
                </Badge>
              </TableCell>
              <TableCell>{entry.description}</TableCell>
              <TableCell>
                <Button variant="ghost" size="sm" onClick={() => showAuditDetails(entry)}>
                  View Details
                </Button>
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  );
}
```

## WCAG Accessibility Requirements

Web Content Accessibility Guidelines (WCAG) 2.1 Level AA compliance is required for healthcare applications.

### Component Requirements

#### Core Component Requirements

- **Keyboard Navigation**: All interactive elements must be operable via keyboard
- **Screen Reader Compatibility**: All components must work with screen readers
- **Color Contrast**: Text must have a contrast ratio of at least 4.5:1 (3:1 for large text)
- **Focus Management**: Visible focus indicators and logical focus order

#### Healthcare-Specific Requirements

- **Clinical Terminology**: Support for screen reader pronunciation of medical terms
- **Critical Alerts**: Multiple modes of presentation for critical information
- **Medical Images**: Alternative text and descriptions for medical images
- **Time-Sensitive Interactions**: Adjustable timing for clinical workflows

### Implementation Examples

See the [Accessibility Guidelines](../03-advanced-patterns/accessibility.md) document for detailed implementation examples.

## GDPR and Data Privacy

The General Data Protection Regulation (GDPR) and similar data privacy regulations establish requirements for handling personal data.

### Component Requirements

#### Consent Management

- **Consent Capture**: Components for capturing explicit consent
- **Consent Withdrawal**: Interfaces for withdrawing consent
- **Consent Tracking**: Mechanisms for tracking consent history

#### Data Subject Rights

- **Data Access**: Interfaces for accessing personal data
- **Data Portability**: Components for exporting data in standard formats
- **Data Deletion**: Interfaces for requesting data deletion

#### Privacy by Design

- **Data Minimization**: Components should collect only necessary data
- **Purpose Limitation**: Clear indication of data usage purpose
- **Storage Limitation**: Controls for data retention periods

### Implementation Examples

```jsx
// Example: Consent management component
function ConsentManager({ userId, requiredConsents, onComplete }) {
  const { data: userConsents, isLoading, mutate } = useUserConsents(userId);
  const [updatedConsents, setUpdatedConsents] = useState({});
  
  // Initialize updated consents from existing user consents
  useEffect(() => {
    if (userConsents) {
      const initialUpdatedConsents = {};
      requiredConsents.forEach(consent => {
        const existingConsent = userConsents.find(c => c.type === consent.type);
        initialUpdatedConsents[consent.type] = existingConsent ? existingConsent.granted : false;
      });
      setUpdatedConsents(initialUpdatedConsents);
    }
  }, [userConsents, requiredConsents]);
  
  // Handle consent toggle
  const handleConsentToggle = (consentType, granted) => {
    setUpdatedConsents(prev => ({
      ...prev,
      [consentType]: granted,
    }));
  };
  
  // Save updated consents
  const handleSave = async () => {
    const consentUpdates = Object.entries(updatedConsents).map(([type, granted]) => ({
      type,
      granted,
      timestamp: new Date().toISOString(),
    }));
    
    await updateUserConsents(userId, consentUpdates);
    await mutate(); // Refresh consent data
    onComplete();
  };
  
  if (isLoading) return <LoadingSpinner />;
  
  return (
    <div className="consent-manager">
      <h2 className="text-xl font-bold mb-4">Manage Your Privacy Preferences</h2>
      
      <div className="space-y-4">
        {requiredConsents.map(consent => (
          <div key={consent.type} className="consent-item border rounded p-4">
            <div className="flex items-start">
              <Switch
                id={`consent-${consent.type}`}
                checked={updatedConsents[consent.type] || false}
                onCheckedChange={checked => handleConsentToggle(consent.type, checked)}
              />
              <div className="ml-3">
                <Label 
                  htmlFor={`consent-${consent.type}`}
                  className="font-medium"
                >
                  {consent.title}
                </Label>
                <p className="text-sm text-muted-foreground mt-1">
                  {consent.description}
                </p>
                {consent.required && (
                  <Badge variant="outline" className="mt-2">
                    Required for service
                  </Badge>
                )}
              </div>
            </div>
            
            {userConsents.find(c => c.type === consent.type) && (
              <div className="text-xs text-muted-foreground mt-2">
                Last updated: {formatDateTime(userConsents.find(c => c.type === consent.type).timestamp)}
              </div>
            )}
          </div>
        ))}
      </div>
      
      <div className="flex justify-end mt-6 space-x-2">
        <Button variant="outline" onClick={onComplete}>
          Cancel
        </Button>
        <Button onClick={handleSave}>
          Save Preferences
        </Button>
      </div>
    </div>
  );
}
```

## Compliance Testing and Validation

### Automated Testing

Implement automated testing for compliance requirements:

```jsx
// Example: HIPAA compliance test for session timeout
describe('SessionTimeoutManager', () => {
  beforeEach(() => {
    jest.useFakeTimers();
  });
  
  afterEach(() => {
    jest.useRealTimers();
  });
  
  it('should show warning before session timeout', () => {
    const logoutMock = jest.fn();
    const { getByText, queryByText } = render(
      <AuthContext.Provider value={{ logout: logoutMock }}>
        <SessionTimeoutManager timeoutMinutes={15}>
          <div>Test Content</div>
        </SessionTimeoutManager>
      </AuthContext.Provider>
    );
    
    // Verify content is rendered
    expect(getByText('Test Content')).toBeInTheDocument();
    
    // No warning initially
    expect(queryByText('Session Timeout Warning')).not.toBeInTheDocument();
    
    // Advance time to just before warning (14 minutes)
    jest.advanceTimersByTime(14 * 60 * 1000);
    expect(queryByText('Session Timeout Warning')).not.toBeInTheDocument();
    
    // Advance to warning threshold (14 minutes)
    jest.advanceTimersByTime(60 * 1000);
    expect(getByText('Session Timeout Warning')).toBeInTheDocument();
    
    // Verify logout not called yet
    expect(logoutMock).not.toHaveBeenCalled();
    
    // Advance to timeout (additional 60 seconds)
    jest.advanceTimersByTime(60 * 1000);
    
    // Verify logout was called
    expect(logoutMock).toHaveBeenCalled();
  });
});
```

### Compliance Documentation

Maintain comprehensive compliance documentation for the design system:

1. **Component Compliance Matrix**
   - Map components to specific regulatory requirements
   - Document compliance testing results
   - Track compliance status across versions

2. **Validation Evidence**
   - Test results and validation reports
   - Accessibility audit results
   - Security assessment findings

3. **Compliance Updates**
   - Process for addressing regulatory changes
   - Impact assessment for new regulations
   - Compliance roadmap and priorities

## Conclusion

Compliance with healthcare regulations is a critical aspect of the CMM Technology Platform Design System. By incorporating compliance requirements directly into components and patterns, the design system simplifies the development of compliant healthcare applications.

Designers and developers should use this document as a reference when creating or modifying components to ensure they meet all relevant compliance requirements. Regular compliance reviews and updates to the design system will ensure it remains aligned with evolving healthcare regulations.
