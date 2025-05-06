# FHIR Interoperability Platform Customization

## Introduction

The FHIR Interoperability Platform supports extensive customization to meet organization-specific requirements without modifying the core codebase. This document outlines the customization options available, including configuration, theming, branding, and behavior modifications.

## Configuration Framework

### Environment-Based Configuration

The platform uses a hierarchical configuration system that allows for environment-specific settings.

**Key Capabilities:**
- Override default configurations based on environment
- Define organization-specific settings
- Configure feature flags and toggles

```typescript
// Example: Configuration system implementation
import * as fs from 'fs';
import * as path from 'path';
import { merge } from 'lodash';

interface FhirServerConfig {
  baseUrl: string;
  version: string;
  supportedResources: string[];
  pageSize: number;
  maxPageSize: number;
  defaultFormat: 'json' | 'xml';
  security: {
    enabled: boolean;
    authServer: string;
    audience: string;
    requireHttps: boolean;
  };
  logging: {
    level: 'debug' | 'info' | 'warn' | 'error';
    destination: 'console' | 'file';
    filePath?: string;
  };
  features: {
    bulkData: boolean;
    subscriptions: boolean;
    graphql: boolean;
    terminology: boolean;
  };
  storage: {
    type: 'mongodb' | 'cosmosdb' | 'postgresql';
    connection: string;
    options: Record<string, any>;
  };
  search: {
    engine: 'elasticsearch' | 'native';
    connection?: string;
    indexPrefix?: string;
  };
  extensions: {
    [key: string]: any;
  };
}

class ConfigurationService {
  private config: FhirServerConfig;
  
  constructor(environment: string = 'development') {
    // Load base configuration
    const baseConfig = this.loadConfigFile('base');
    
    // Load environment-specific configuration
    const envConfig = this.loadConfigFile(environment);
    
    // Load organization-specific configuration if exists
    const orgConfig = this.loadConfigFile('organization');
    
    // Merge configurations with environment and organization overrides
    this.config = merge({}, baseConfig, envConfig, orgConfig);
  }
  
  private loadConfigFile(name: string): Partial<FhirServerConfig> {
    const configPath = path.join(process.cwd(), 'config', `${name}.json`);
    
    if (fs.existsSync(configPath)) {
      try {
        return JSON.parse(fs.readFileSync(configPath, 'utf8'));
      } catch (error) {
        console.error(`Error loading config file ${name}.json:`, error);
        return {};
      }
    }
    
    return {};
  }
  
  public get<T>(key: string, defaultValue?: T): T {
    const parts = key.split('.');
    let current: any = this.config;
    
    for (const part of parts) {
      if (current[part] === undefined) {
        return defaultValue as T;
      }
      current = current[part];
    }
    
    return current as T;
  }
  
  public getAll(): FhirServerConfig {
    return { ...this.config };
  }
}

// Usage example
const config = new ConfigurationService(process.env.NODE_ENV);
const pageSize = config.get<number>('pageSize', 20);
const isBulkDataEnabled = config.get<boolean>('features.bulkData', false);
```

### Feature Flags

The platform includes a feature flag system to enable or disable functionality without code changes.

**Key Capabilities:**
- Toggle features on/off per environment
- Implement progressive feature rollout
- A/B testing of new functionality

```typescript
// Example: Feature flag implementation
import { ConfigurationService } from './configuration.service';

class FeatureFlagService {
  constructor(private configService: ConfigurationService) {}
  
  isEnabled(featureName: string, context: Record<string, any> = {}): boolean {
    // Check if feature exists in configuration
    const featureConfig = this.configService.get<any>(`featureFlags.${featureName}`);
    
    if (!featureConfig) {
      return false; // Feature not defined, default to disabled
    }
    
    // Simple boolean flag
    if (typeof featureConfig === 'boolean') {
      return featureConfig;
    }
    
    // Complex feature flag with conditions
    if (featureConfig.enabled === false) {
      return false; // Explicitly disabled
    }
    
    // Check percentage rollout
    if (featureConfig.percentage !== undefined) {
      const percentage = featureConfig.percentage;
      if (percentage <= 0) return false;
      if (percentage >= 100) return true;
      
      // Use a consistent hash for the same user/context
      const hash = this.getContextHash(featureName, context);
      return (hash % 100) < percentage;
    }
    
    // Check organization allowlist
    if (featureConfig.organizations && context.organizationId) {
      return featureConfig.organizations.includes(context.organizationId);
    }
    
    // Check user allowlist
    if (featureConfig.users && context.userId) {
      return featureConfig.users.includes(context.userId);
    }
    
    // Default to enabled if it has a config but no explicit disabled flag
    return true;
  }
  
  private getContextHash(featureName: string, context: Record<string, any>): number {
    // Simple hash function for consistent percentage rollout
    const key = `${featureName}:${context.userId || context.organizationId || 'anonymous'}`;
    let hash = 0;
    for (let i = 0; i < key.length; i++) {
      hash = ((hash << 5) - hash) + key.charCodeAt(i);
      hash = hash & hash; // Convert to 32bit integer
    }
    return Math.abs(hash);
  }
}

// Usage example
const featureFlags = new FeatureFlagService(config);

if (featureFlags.isEnabled('advanced-search', { userId: 'user123' })) {
  // Enable advanced search features
  app.use('/fhir/$advanced-search', advancedSearchRouter);
}

if (featureFlags.isEnabled('bulk-data')) {
  // Enable bulk data endpoints
  app.use('/fhir/$export', bulkDataExportRouter);
}
```

## UI Customization

### Theming and Branding

The platform's user interfaces can be customized with organization-specific theming and branding.

**Key Capabilities:**
- Custom color schemes and typography
- Organization logos and branding elements
- Custom CSS and component styling

```typescript
// Example: Theme configuration in TypeScript
import { createTheme, ThemeOptions } from '@mui/material/styles';

// Define the base theme structure
interface FhirPlatformTheme extends ThemeOptions {
  branding: {
    logo: string;
    favicon: string;
    appName: string;
    organizationName: string;
  };
  customColors: {
    success: string;
    warning: string;
    error: string;
    info: string;
    highlight: string;
  };
}

// Load organization theme from configuration
function loadOrganizationTheme(): FhirPlatformTheme {
  // This could be loaded from a database, API, or configuration file
  return {
    branding: {
      logo: '/assets/organization-logo.svg',
      favicon: '/assets/favicon.ico',
      appName: 'Healthcare Connect',
      organizationName: 'Example Healthcare Organization'
    },
    palette: {
      primary: {
        main: '#0066cc',
        light: '#4d94ff',
        dark: '#003d7a',
        contrastText: '#ffffff'
      },
      secondary: {
        main: '#2c3e50',
        light: '#546e7a',
        dark: '#1a252f',
        contrastText: '#ffffff'
      }
    },
    typography: {
      fontFamily: '"Roboto", "Helvetica", "Arial", sans-serif',
      h1: {
        fontSize: '2.5rem',
        fontWeight: 500
      },
      h2: {
        fontSize: '2rem',
        fontWeight: 500
      }
    },
    customColors: {
      success: '#4caf50',
      warning: '#ff9800',
      error: '#f44336',
      info: '#2196f3',
      highlight: '#ffeb3b'
    }
  };
}

// Create the Material-UI theme with organization customizations
function createOrganizationTheme(): any {
  const organizationTheme = loadOrganizationTheme();
  return createTheme(organizationTheme);
}

export const theme = createOrganizationTheme();
```

### Custom UI Components

The platform allows for customizing and extending UI components to meet specific requirements.

**Key Capabilities:**
- Override default UI components
- Add organization-specific UI elements
- Customize layouts and workflows

```typescript
// Example: Component override system in React
import React from 'react';
import { ComponentRegistry } from '../services/component-registry';

// Define the custom patient header component
const CustomPatientHeader: React.FC<{ patient: any }> = ({ patient }) => {
  const patientName = patient.name?.[0] || {};
  const fullName = `${patientName.given?.join(' ') || ''} ${patientName.family || ''}`;
  
  return (
    <div className="custom-patient-header">
      <div className="patient-avatar">
        {patient.gender === 'male' ? '👨' : patient.gender === 'female' ? '👩' : '🧑'}
      </div>
      <div className="patient-info">
        <h2>{fullName}</h2>
        <div className="patient-details">
          <span>DOB: {patient.birthDate || 'Unknown'}</span>
          <span>MRN: {patient.identifier?.[0]?.value || 'Unknown'}</span>
          <span>Gender: {patient.gender || 'Unknown'}</span>
        </div>
        <div className="patient-alerts">
          {patient.extension?.some((ext: any) => 
            ext.url === 'http://example.org/fhir/StructureDefinition/patient-allergies'
          ) && (
            <span className="alert allergy-alert">⚠️ Allergies</span>
          )}
          
          {/* Organization-specific alerts */}
          {patient.extension?.some((ext: any) => 
            ext.url === 'http://example.org/fhir/StructureDefinition/care-management-program'
          ) && (
            <span className="alert care-program">👥 Care Management</span>
          )}
        </div>
      </div>
      <div className="patient-actions">
        <button className="action-button">📝 Notes</button>
        <button className="action-button">📊 Timeline</button>
        <button className="action-button">📋 Care Plan</button>
      </div>
    </div>
  );
};

// Register the custom component to override the default
ComponentRegistry.register('PatientHeader', CustomPatientHeader);

// Component resolver that checks for overrides
export function resolveComponent(componentName: string) {
  return ComponentRegistry.get(componentName) || DefaultComponents[componentName];
}

// Usage in the application
function PatientView({ patientId }: { patientId: string }) {
  const [patient, setPatient] = React.useState<any>(null);
  const [loading, setLoading] = React.useState<boolean>(true);
  
  React.useEffect(() => {
    // Fetch patient data
    fetchPatient(patientId).then(data => {
      setPatient(data);
      setLoading(false);
    });
  }, [patientId]);
  
  if (loading) return <div>Loading...</div>;
  if (!patient) return <div>Patient not found</div>;
  
  // Dynamically resolve the component, using custom one if registered
  const PatientHeader = resolveComponent('PatientHeader');
  
  return (
    <div className="patient-view">
      <PatientHeader patient={patient} />
      {/* Rest of the patient view */}
    </div>
  );
}
```

## Workflow Customization

### Custom Workflow Steps

The platform allows for defining custom workflow steps for organization-specific processes.

**Key Capabilities:**
- Define custom workflow steps
- Implement organization-specific business logic
- Integrate with external systems

```typescript
// Example: Custom workflow step implementation
import { WorkflowStep, WorkflowContext, StepResult } from '../models/workflow';

// Define a custom workflow step for insurance verification
class InsuranceVerificationStep implements WorkflowStep {
  async execute(context: WorkflowContext): Promise<StepResult> {
    try {
      // Extract patient and encounter from context
      const patientId = context.get('patientId');
      const encounterId = context.get('encounterId');
      
      if (!patientId) {
        return {
          success: false,
          error: 'Patient ID is required for insurance verification'
        };
      }
      
      // Get patient insurance information
      const insuranceInfo = await this.getPatientInsurance(patientId);
      
      if (!insuranceInfo) {
        return {
          success: false,
          error: 'No insurance information found for patient',
          nextStep: 'CollectInsuranceInformation'
        };
      }
      
      // Verify insurance coverage
      const verificationResult = await this.verifyInsuranceCoverage(insuranceInfo, encounterId);
      
      // Update context with verification results
      context.set('insuranceVerified', verificationResult.verified);
      context.set('coverageDetails', verificationResult.coverageDetails);
      context.set('authorizationRequired', verificationResult.authorizationRequired);
      
      if (verificationResult.authorizationRequired) {
        return {
          success: true,
          nextStep: 'RequestAuthorization'
        };
      }
      
      return {
        success: true,
        nextStep: 'ScheduleAppointment'
      };
    } catch (error) {
      console.error('Error in insurance verification step:', error);
      return {
        success: false,
        error: `Insurance verification failed: ${error.message}`,
        retry: true
      };
    }
  }
  
  private async getPatientInsurance(patientId: string): Promise<any> {
    // Implementation details - fetch Coverage resources for the patient
    return null;
  }
  
  private async verifyInsuranceCoverage(insuranceInfo: any, encounterId?: string): Promise<any> {
    // Implementation details - verify coverage with insurance provider
    return {
      verified: true,
      coverageDetails: {},
      authorizationRequired: false
    };
  }
}

// Register the custom workflow step
workflowEngine.registerStep('InsuranceVerification', new InsuranceVerificationStep());

// Define a workflow that uses the custom step
const appointmentWorkflow = {
  name: 'PatientAppointmentScheduling',
  version: '1.0',
  steps: [
    {
      id: 'PatientCheck',
      type: 'PatientLookup',
      next: 'InsuranceVerification'
    },
    {
      id: 'InsuranceVerification',
      type: 'InsuranceVerification',
      next: {
        conditions: [
          {
            condition: 'context.authorizationRequired === true',
            next: 'RequestAuthorization'
          }
        ],
        default: 'ScheduleAppointment'
      }
    },
    {
      id: 'RequestAuthorization',
      type: 'AuthorizationRequest',
      next: 'ScheduleAppointment'
    },
    {
      id: 'ScheduleAppointment',
      type: 'AppointmentScheduling',
      next: 'SendNotification'
    },
    {
      id: 'SendNotification',
      type: 'PatientNotification',
      next: null
    }
  ]
};

// Register the workflow
workflowEngine.registerWorkflow(appointmentWorkflow);
```

## Integration Customization

### Custom Integration Adapters

The platform supports custom integration adapters for connecting with organization-specific systems.

**Key Capabilities:**
- Implement adapters for legacy systems
- Create connectors for specialized healthcare systems
- Build custom data transformation pipelines

```typescript
// Example: Custom integration adapter for a legacy EHR system
import axios from 'axios';
import { IntegrationAdapter, ResourceMapping } from '../models/integration';

class LegacyEhrAdapter implements IntegrationAdapter {
  constructor(
    private baseUrl: string,
    private apiKey: string,
    private mappings: Record<string, ResourceMapping>
  ) {}
  
  async fetchPatient(patientId: string): Promise<any> {
    try {
      // Call the legacy EHR API
      const response = await axios.get(
        `${this.baseUrl}/patients/${patientId}`,
        {
          headers: {
            'X-API-Key': this.apiKey,
            'Accept': 'application/json'
          }
        }
      );
      
      // Transform the legacy data to FHIR format
      return this.transformToFhir('Patient', response.data);
    } catch (error) {
      console.error('Error fetching patient from legacy EHR:', error);
      throw new Error(`Failed to fetch patient: ${error.message}`);
    }
  }
  
  async searchPatients(criteria: Record<string, string>): Promise<any[]> {
    try {
      // Convert FHIR search parameters to legacy format
      const legacyParams = this.convertSearchParams(criteria);
      
      // Call the legacy EHR API
      const response = await axios.get(
        `${this.baseUrl}/patients/search`,
        {
          params: legacyParams,
          headers: {
            'X-API-Key': this.apiKey,
            'Accept': 'application/json'
          }
        }
      );
      
      // Transform each result to FHIR format
      return response.data.results.map((patient: any) => 
        this.transformToFhir('Patient', patient)
      );
    } catch (error) {
      console.error('Error searching patients in legacy EHR:', error);
      throw new Error(`Failed to search patients: ${error.message}`);
    }
  }
  
  private convertSearchParams(fhirParams: Record<string, string>): Record<string, string> {
    const result: Record<string, string> = {};
    
    // Map FHIR search parameters to legacy parameters
    if (fhirParams.name) {
      result.patient_name = fhirParams.name;
    }
    
    if (fhirParams.identifier) {
      const [system, value] = fhirParams.identifier.split('|');
      if (system.includes('mrn')) {
        result.medical_record_number = value;
      } else if (system.includes('ssn')) {
        result.ssn = value;
      }
    }
    
    if (fhirParams.birthdate) {
      result.date_of_birth = fhirParams.birthdate.replace('eq', '');
    }
    
    return result;
  }
  
  private transformToFhir(resourceType: string, legacyData: any): any {
    // Get the mapping for this resource type
    const mapping = this.mappings[resourceType];
    if (!mapping) {
      throw new Error(`No mapping defined for resource type: ${resourceType}`);
    }
    
    // Create the FHIR resource
    const fhirResource: any = {
      resourceType
    };
    
    // Apply each field mapping
    for (const [fhirPath, legacyPath] of Object.entries(mapping.fields)) {
      const value = this.getValueByPath(legacyData, legacyPath);
      if (value !== undefined) {
        this.setValueByPath(fhirResource, fhirPath, value);
      }
    }
    
    // Apply any custom transformations
    if (mapping.customTransformations) {
      for (const transform of mapping.customTransformations) {
        transform(legacyData, fhirResource);
      }
    }
    
    return fhirResource;
  }
  
  private getValueByPath(obj: any, path: string): any {
    return path.split('.').reduce((o, p) => (o ? o[p] : undefined), obj);
  }
  
  private setValueByPath(obj: any, path: string, value: any): void {
    const parts = path.split('.');
    const last = parts.pop()!;
    const parent = parts.reduce((o, p) => {
      o[p] = o[p] || {};
      return o[p];
    }, obj);
    parent[last] = value;
  }
}

// Usage example
const legacyEhrMappings = {
  'Patient': {
    fields: {
      'id': 'patient_id',
      'identifier[0].system': '"http://hospital.example.org/identifiers/mrn"',
      'identifier[0].value': 'medical_record_number',
      'name[0].family': 'last_name',
      'name[0].given[0]': 'first_name',
      'gender': 'sex',
      'birthDate': 'date_of_birth',
      'address[0].line[0]': 'address.street',
      'address[0].city': 'address.city',
      'address[0].state': 'address.state',
      'address[0].postalCode': 'address.zip'
    },
    customTransformations: [
      // Convert legacy sex codes to FHIR gender values
      (legacy: any, fhir: any) => {
        if (legacy.sex === 'M') fhir.gender = 'male';
        else if (legacy.sex === 'F') fhir.gender = 'female';
        else fhir.gender = 'unknown';
      },
      // Format phone numbers
      (legacy: any, fhir: any) => {
        if (legacy.phone) {
          fhir.telecom = fhir.telecom || [];
          fhir.telecom.push({
            system: 'phone',
            value: legacy.phone,
            use: 'home'
          });
        }
      }
    ]
  }
};

const legacyAdapter = new LegacyEhrAdapter(
  'https://legacy-ehr.example.org/api',
  process.env.LEGACY_EHR_API_KEY!,
  legacyEhrMappings
);

// Register the adapter with the integration service
integrationService.registerAdapter('legacy-ehr', legacyAdapter);
```

## Related Resources

- [FHIR Interoperability Platform Overview](../01-getting-started/overview.md)
- [Core APIs](../02-core-functionality/core-apis.md)
- [Integration Points](../02-core-functionality/integration-points.md)
- [Extension Points](extension-points.md)
- [Advanced Use Cases](advanced-use-cases.md)
