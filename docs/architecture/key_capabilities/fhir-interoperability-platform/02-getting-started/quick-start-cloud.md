# FHIR Interoperability Platform Quick Start Guide (Cloud)

## Introduction

This guide will help you quickly get started with the **FHIR Interoperability Platform** capability in the CMM Azure development environment. This approach uses the fully-managed version of the FHIR server based on Health Samurai's Aidbox rather than a local development setup, allowing you to experiment with the platform capabilities immediately without complex configuration.

## Prerequisites

Before you begin, ensure you have:

- [ ] An active Azure AD account with access to the CMM development subscription
- [ ] Azure CLI installed and authenticated with your CMM account 
- [ ] Required role assignments (details below)
- [ ] Postman or similar API testing tool for FHIR API exploration

## Accessing the Managed Service

### Azure Authentication

1. Authenticate with Azure:

   ```bash
   az login
   ```

2. Set your subscription to the CMM development environment:

   ```bash
   az account set --subscription "CMM-Development"
   ```

3. Verify you have the required roles:

   ```bash
   az role assignment list --assignee [your-email@covermymeds.com]
   ```

   You should see at least these roles:
   - Reader
   - FHIR Data Contributor

### Service Endpoints

The **FHIR Interoperability Platform** is available at the following endpoints in the development environment:

| Service | Endpoint | Purpose |
|---------|----------|---------|
| Admin Portal | `https://fhir-admin.dev.cmm.azure.com` | Aidbox administration dashboard |
| FHIR API | `https://fhir-api.dev.cmm.azure.com` | RESTful FHIR API access |
| GraphQL API | `https://fhir-graphql.dev.cmm.azure.com` | GraphQL API access |
| Metrics Dashboard | `https://fhir-metrics.dev.cmm.azure.com` | Observability and monitoring |

## Basic Usage Examples

### Example 1: Retrieving a Patient Resource

```typescript
// TypeScript Example for retrieving a patient
import axios from 'axios';
import { MsalAuthProvider } from '@cmm/azure-auth';

async function getPatient(patientId: string): Promise<any> {
  try {
    // Initialize authentication provider with Azure credentials
    const authProvider = new MsalAuthProvider({
      clientId: process.env.AZURE_CLIENT_ID,
      tenantId: process.env.AZURE_TENANT_ID,
      scope: 'https://fhir-api.dev.cmm.azure.com/.default'
    });
    
    // Get access token
    const token = await authProvider.getToken();
    
    // Make authenticated request to FHIR API
    const response = await axios.get(
      `https://fhir-api.dev.cmm.azure.com/Patient/${patientId}`,
      {
        headers: {
          'Authorization': `Bearer ${token}`,
          'Accept': 'application/fhir+json'
        }
      }
    );
    
    return response.data;
  } catch (error) {
    if (axios.isAxiosError(error)) {
      console.error('FHIR API Error:', error.response?.status, error.response?.data);
    } else {
      console.error('Error retrieving patient:', error);
    }
    throw error;
  }
}

// Usage
getPatient('example-patient-id')
  .then(patient => console.log('Patient retrieved:', patient))
  .catch(error => console.error('Failed to retrieve patient'));
```

### Example 2: Creating a FHIR Observation

```typescript
// TypeScript Example for creating an observation
import axios from 'axios';
import { MsalAuthProvider } from '@cmm/azure-auth';

interface FhirObservation {
  resourceType: string;
  status: string;
  code: {
    coding: Array<{
      system: string;
      code: string;
      display: string;
    }>;
  };
  subject: {
    reference: string;
  };
  effectiveDateTime: string;
  valueQuantity?: {
    value: number;
    unit: string;
    system: string;
    code: string;
  };
}

async function createObservation(patientId: string, observationData: Partial<FhirObservation>): Promise<any> {
  try {
    // Initialize authentication provider
    const authProvider = new MsalAuthProvider({
      clientId: process.env.AZURE_CLIENT_ID,
      tenantId: process.env.AZURE_TENANT_ID,
      scope: 'https://fhir-api.dev.cmm.azure.com/.default'
    });
    
    // Get access token
    const token = await authProvider.getToken();
    
    // Default observation with required fields
    const observation: FhirObservation = {
      resourceType: 'Observation',
      status: 'final',
      code: {
        coding: [
          {
            system: 'http://loinc.org',
            code: '8867-4',
            display: 'Heart rate'
          }
        ]
      },
      subject: {
        reference: `Patient/${patientId}`
      },
      effectiveDateTime: new Date().toISOString(),
      ...observationData
    };
    
    // Make authenticated request to create observation
    const response = await axios.post(
      'https://fhir-api.dev.cmm.azure.com/Observation',
      observation,
      {
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/fhir+json'
        }
      }
    );
    
    return response.data;
  } catch (error) {
    if (axios.isAxiosError(error)) {
      console.error('FHIR API Error:', error.response?.status, error.response?.data);
    } else {
      console.error('Error creating observation:', error);
    }
    throw error;
  }
}

// Usage
const heartRateObservation = {
  valueQuantity: {
    value: 80,
    unit: 'beats/minute',
    system: 'http://unitsofmeasure.org',
    code: '/min'
  }
};

createObservation('example-patient-id', heartRateObservation)
  .then(result => console.log('Observation created:', result.id))
  .catch(error => console.error('Failed to create observation'));
```

## Resource Limitations

The development environment has the following limitations:

| Resource | Limit | Notes |
|----------|-------|-------|
| API Rate | 100 requests/minute | Higher rates will trigger throttling |
| Storage | 5GB per tenant | For testing purposes only |
| Concurrent requests | 10 | For fair resource sharing |
| FHIR Version | R4 (4.0.1) | US Core 3.1.1 profiles supported |
| Resource history | 5 versions | Older versions automatically pruned |

## Environment Cleanup

**Important:** The development environment is shared. After completing your testing:

1. Delete any test resources you created:
   ```typescript
   // Example: Delete a resource you created
   async function deleteResource(resourceType: string, id: string): Promise<void> {
     const token = await authProvider.getToken();
     await axios.delete(
       `https://fhir-api.dev.cmm.azure.com/${resourceType}/${id}`,
       {
         headers: {
           'Authorization': `Bearer ${token}`
         }
       }
     );
   }
   ```

2. Clean up any temporary data sets
3. Log out when finished:
   ```bash
   az logout
   ```

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| Authentication failure | Ensure your Azure AD account has appropriate access and MFA is completed |
| 404 Not Found | Verify resource ID and URL path are correct |
| 422 Unprocessable Entity | Check your resource structure against FHIR specifications |
| Rate limiting (429) | Reduce request frequency or implement exponential backoff |
| CORS issues | When testing from browser-based applications, ensure your application origin is registered |

### Getting Support

If you encounter issues accessing the development environment:

1. Check the status dashboard at `https://cmm-status.dev.cmm.azure.com`
2. Contact the platform team in the Microsoft Teams channel: `#fhir-platform-support`
3. Submit a request with the IT service desk for access issues

## Next Steps

After completing this quick start guide:

- Explore the full [API documentation](../03-core-functionality/core-apis.md)
- Learn about [advanced capabilities](../04-advanced-patterns/advanced-use-cases.md)
- Understand [security considerations](../05-governance-compliance/access-controls.md)
- Set up a [local development environment](local-setup.md) for deeper customization

## Related Resources

- [Aidbox Documentation](https://docs.aidbox.app/) — Official Aidbox FHIR server documentation
- [HL7 FHIR R4 Specification](https://hl7.org/fhir/R4/) — Official FHIR R4 specification
- [US Core Implementation Guide](https://www.hl7.org/fhir/us/core/) — US Core profiles used in the platform
- [SMART on FHIR Documentation](https://docs.smarthealthit.org/) — Healthcare app authorization framework
- [CMM Internal Azure Guidelines](link-to-internal-docs)
- [FHIR Interoperability Platform Architecture](../01-overview/architecture.md)