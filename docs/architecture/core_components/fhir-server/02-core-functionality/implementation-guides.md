# FHIR Implementation Guides

## Introduction

FHIR Implementation Guides (IGs) provide detailed specifications for implementing FHIR in specific healthcare contexts. They define profiles, extensions, value sets, and other constraints that ensure interoperability between systems. This guide explains how to implement common FHIR IGs, including Da Vinci Prior Authorization Support, US Core, and Burden Reduction implementation guides.

### Quick Start

1. Identify the Implementation Guides relevant to your healthcare domain
2. Configure your FHIR server to support the required profiles and extensions
3. Implement validation against the IG specifications
4. Test your implementation against reference implementations
5. Document your conformance to the Implementation Guide

### Related Components

- [FHIR Server Setup Guide](fhir-server-setup-guide.md): Configure your Aidbox FHIR server
- [Extending FHIR Resources](extending-fhir-resources.md): Learn how to customize FHIR resources
- [Implementation Guide Decisions](fhir-ig-decisions.md) (Coming Soon): Understand implementation choices

## Understanding Implementation Guides

FHIR Implementation Guides are formal specifications that define how FHIR should be used in specific contexts. They include:

| Component | Description | Purpose |
|-----------|-------------|----------|
| Profiles | Constraints on FHIR resources | Define how resources should be structured for specific use cases |
| Extensions | Additional data elements | Add domain-specific data not included in base FHIR |
| Value Sets | Sets of coded values | Define specific terminologies for coded elements |
| Operations | Custom API operations | Define additional functionality beyond RESTful API |
| Examples | Sample resources | Demonstrate correct implementation |

## Da Vinci Prior Authorization Support (PAS)

The Da Vinci Prior Authorization Support Implementation Guide defines how to automate the prior authorization process using FHIR.

### Key Components

- **Claim Resource**: Represents the prior authorization request
- **ClaimResponse Resource**: Represents the prior authorization decision
- **Task Resource**: Tracks the prior authorization workflow
- **Questionnaire/QuestionnaireResponse**: Captures additional information needed for the request

### Implementing PAS

```typescript
import { AidboxClient } from '@aidbox/sdk-r4';
import { Claim, ClaimResponse, Task } from '@aidbox/sdk-r4/types';

const client = new AidboxClient({
  baseUrl: 'http://localhost:8888',
  auth: {
    type: 'basic',
    username: 'root',
    password: 'secret'
  }
});

/**
 * Creates a Prior Authorization request following the Da Vinci PAS IG
 * @param patientId The ID of the patient
 * @param providerId The ID of the requesting provider
 * @param items The items being requested (procedures, medications, etc.)
 * @returns The created Claim resource
 */
async function createPriorAuthRequest(
  patientId: string,
  providerId: string,
  items: Array<{
    productOrService: {
      coding: Array<{
        system: string;
        code: string;
        display: string;
      }>;
    };
    quantity?: {
      value: number;
      unit: string;
    };
  }>
): Promise<Claim> {
  // Create the Claim resource following PAS profile
  const claim: Partial<Claim> = {
    resourceType: 'Claim',
    status: 'active',
    type: {
      coding: [{
        system: 'http://terminology.hl7.org/CodeSystem/claim-type',
        code: 'institutional',
        display: 'Institutional'
      }]
    },
    use: 'preauthorization',
    patient: {
      reference: `Patient/${patientId}`
    },
    created: new Date().toISOString(),
    provider: {
      reference: `Practitioner/${providerId}`
    },
    priority: {
      coding: [{
        system: 'http://terminology.hl7.org/CodeSystem/processpriority',
        code: 'normal'
      }]
    },
    insurance: [{
      sequence: 1,
      focal: true,
      coverage: {
        reference: `Coverage/${patientId}` // Simplified for example
      }
    }],
    item: items.map((item, index) => ({
      sequence: index + 1,
      productOrService: item.productOrService,
      quantity: item.quantity
    })),
    // Add PAS profile metadata
    meta: {
      profile: [
        'http://hl7.org/fhir/us/davinci-pas/StructureDefinition/profile-claim'
      ]
    }
  };

  try {
    const result = await client.create<Claim>(claim);
    console.log(`Prior Authorization request created with ID: ${result.id}`);
    return result;
  } catch (error) {
    console.error('Error creating Prior Authorization request:', error);
    throw error;
  }
}

/**
 * Checks the status of a Prior Authorization request
 * @param claimId The ID of the Claim resource
 * @returns The ClaimResponse resource if available
 */
async function checkPriorAuthStatus(claimId: string): Promise<ClaimResponse | null> {
  try {
    // Search for ClaimResponse resources referencing this claim
    const bundle = await client.search<ClaimResponse>({
      resourceType: 'ClaimResponse',
      params: {
        'request': `Claim/${claimId}`
      }
    });
    
    if (bundle.entry && bundle.entry.length > 0) {
      const claimResponse = bundle.entry[0].resource as ClaimResponse;
      console.log(`Prior Authorization status: ${claimResponse.outcome}`);
      return claimResponse;
    }
    
    // If no ClaimResponse found, check for Task resources
    const taskBundle = await client.search<Task>({
      resourceType: 'Task',
      params: {
        'focus': `Claim/${claimId}`
      }
    });
    
    if (taskBundle.entry && taskBundle.entry.length > 0) {
      const task = taskBundle.entry[0].resource as Task;
      console.log(`Prior Authorization task status: ${task.status}`);
      // Task exists but no response yet
      return null;
    }
    
    console.log('No Prior Authorization response or task found');
    return null;
  } catch (error) {
    console.error('Error checking Prior Authorization status:', error);
    throw error;
  }
}
```

## US Core Implementation Guide

The US Core Implementation Guide defines the minimum set of constraints on FHIR resources to create a common foundation for US healthcare data exchange.

### Key Profiles

- **US Core Patient**: Basic demographics for patient identification
- **US Core Condition**: Patient health conditions and problems
- **US Core Medication Request**: Medication prescriptions and orders
- **US Core Observation**: Clinical observations and measurements

### Implementing US Core Patient

```typescript
import { AidboxClient } from '@aidbox/sdk-r4';
import { Patient } from '@aidbox/sdk-r4/types';

/**
 * Creates a patient following the US Core Patient profile
 * @returns The created Patient resource
 */
async function createUSCorePatient(
  familyName: string,
  givenNames: string[],
  birthDate: string,
  gender: 'male' | 'female' | 'other' | 'unknown'
): Promise<Patient> {
  const patient: Partial<Patient> = {
    resourceType: 'Patient',
    meta: {
      profile: ['http://hl7.org/fhir/us/core/StructureDefinition/us-core-patient']
    },
    identifier: [
      {
        system: 'http://hospital.smarthealthit.org',
        value: `MRN-${Math.floor(Math.random() * 10000000)}`
      }
    ],
    name: [
      {
        family: familyName,
        given: givenNames,
        use: 'official'
      }
    ],
    gender: gender,
    birthDate: birthDate,
    // US Core requires at least one of these communication extensions
    extension: [
      {
        url: 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-race',
        extension: [
          {
            url: 'ombCategory',
            valueCoding: {
              system: 'urn:oid:2.16.840.1.113883.6.238',
              code: '2106-3',
              display: 'White'
            }
          }
        ]
      },
      {
        url: 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-ethnicity',
        extension: [
          {
            url: 'ombCategory',
            valueCoding: {
              system: 'urn:oid:2.16.840.1.113883.6.238',
              code: '2186-5',
              display: 'Not Hispanic or Latino'
            }
          }
        ]
      }
    ]
  };

  try {
    const result = await client.create<Patient>(patient);
    console.log(`US Core Patient created with ID: ${result.id}`);
    return result;
  } catch (error) {
    console.error('Error creating US Core Patient:', error);
    throw error;
  }
}
```

### Validating Resources Against US Core

```typescript
/**
 * Validates a resource against US Core profiles
 * @param resource The resource to validate
 * @param profile The US Core profile to validate against
 * @returns Validation results
 */
async function validateAgainstUSCore(
  resource: any,
  profile: string
): Promise<any> {
  try {
    // Add the profile to the resource metadata if not already present
    if (!resource.meta) {
      resource.meta = { profile: [profile] };
    } else if (!resource.meta.profile || !resource.meta.profile.includes(profile)) {
      resource.meta.profile = [...(resource.meta.profile || []), profile];
    }
    
    // Use Aidbox validation endpoint
    const response = await client.request({
      method: 'POST',
      url: '/$validate',
      data: resource
    });
    
    return response;
  } catch (error) {
    console.error('Validation error:', error);
    throw error;
  }
}
```

## Burden Reduction Implementation Guides

Burden Reduction Implementation Guides focus on reducing administrative burden in healthcare through standardized data exchange.

### Da Vinci Coverage Requirements Discovery (CRD)

CRD allows providers to discover payer requirements for coverage at the point of service.

```typescript
/**
 * Performs a Coverage Requirements Discovery query
 * @param patientId The ID of the patient
 * @param serviceType The type of service being requested
 * @returns Coverage requirements information
 */
async function discoverCoverageRequirements(
  patientId: string,
  serviceType: {
    system: string;
    code: string;
    display: string;
  }
): Promise<any> {
  try {
    // Create a CRD request using FHIR operations
    const response = await client.request({
      method: 'POST',
      url: '/ServiceRequest/$coverage-requirements',
      data: {
        resourceType: 'Parameters',
        parameter: [
          {
            name: 'patient',
            resource: {
              resourceType: 'Patient',
              id: patientId
            }
          },
          {
            name: 'service',
            coding: [
              serviceType
            ]
          }
        ]
      }
    });
    
    return response.data;
  } catch (error) {
    console.error('Error discovering coverage requirements:', error);
    throw error;
  }
}
```

## Implementation Strategy and Approach

### Phased Implementation

Implementing FHIR IGs can be complex. A phased approach is recommended:

1. **Assessment Phase**: Identify which IGs are relevant to your use case
2. **Planning Phase**: Determine which profiles and extensions to implement
3. **Development Phase**: Implement the required profiles and extensions
4. **Testing Phase**: Validate against the IG specifications
5. **Deployment Phase**: Roll out the implementation

### Testing and Validation

Validation is critical for ensuring compliance with Implementation Guides:

```typescript
/**
 * Comprehensive validation of resources against Implementation Guides
 * @param resources The resources to validate
 * @param implementationGuide The Implementation Guide to validate against
 * @returns Validation results with issues grouped by severity
 */
async function validateAgainstImplementationGuide(
  resources: any[],
  implementationGuide: string
): Promise<{
  valid: boolean;
  issues: {
    error: any[];
    warning: any[];
    information: any[];
  };
}> {
  const issues = {
    error: [],
    warning: [],
    information: []
  };
  
  try {
    // For each resource, perform validation
    for (const resource of resources) {
      try {
        // Use the $validate operation
        const response = await client.request({
          method: 'POST',
          url: '/$validate',
          data: {
            resourceType: 'Parameters',
            parameter: [
              {
                name: 'resource',
                resource: resource
              },
              {
                name: 'profile',
                valueUri: implementationGuide
              }
            ]
          }
        });
        
        // Process validation results
        const outcome = response.data;
        if (outcome.issue) {
          for (const issue of outcome.issue) {
            switch (issue.severity) {
              case 'error':
                issues.error.push({
                  resource: resource.resourceType + '/' + resource.id,
                  issue
                });
                break;
              case 'warning':
                issues.warning.push({
                  resource: resource.resourceType + '/' + resource.id,
                  issue
                });
                break;
              default:
                issues.information.push({
                  resource: resource.resourceType + '/' + resource.id,
                  issue
                });
            }
          }
        }
      } catch (error) {
        issues.error.push({
          resource: resource.resourceType + '/' + resource.id,
          issue: {
            severity: 'error',
            code: 'exception',
            diagnostics: error.message
          }
        });
      }
    }
    
    return {
      valid: issues.error.length === 0,
      issues
    };
  } catch (error) {
    console.error('Error during validation:', error);
    throw error;
  }
}
```

### Handling Multiple Implementation Guides

Many healthcare applications need to support multiple IGs simultaneously:

```typescript
/**
 * Configures the FHIR server to support multiple Implementation Guides
 * @param implementationGuides Array of Implementation Guide URLs to support
 */
async function configureImplementationGuides(
  implementationGuides: string[]
): Promise<void> {
  try {
    // Configure Aidbox to load the Implementation Guides
    await client.request({
      method: 'POST',
      url: '/admin/configuration',
      data: {
        resourceType: 'Parameters',
        parameter: [
          {
            name: 'implementation-guides',
            valueString: implementationGuides.join(',')
          }
        ]
      }
    });
    
    console.log('Implementation Guides configured successfully');
  } catch (error) {
    console.error('Error configuring Implementation Guides:', error);
    throw error;
  }
}
```

## Conclusion

FHIR Implementation Guides provide the detailed specifications needed to ensure interoperability in healthcare data exchange. By implementing these guides, you can ensure your healthcare applications conform to industry standards and can seamlessly exchange data with other systems.

Key takeaways:

1. Identify the Implementation Guides relevant to your healthcare domain
2. Implement the required profiles and extensions
3. Validate your resources against the IG specifications
4. Use a phased approach for complex Implementation Guides
5. Consider supporting multiple IGs for comprehensive interoperability

By following these guidelines, you can successfully implement FHIR Implementation Guides in your healthcare applications, ensuring standards compliance and interoperability.
