# FHIR Interoperability Platform Core APIs

## Introduction
The FHIR Interoperability Platform provides a comprehensive set of FHIR-compliant APIs for healthcare data exchange, built on Health Samurai's Aidbox. These APIs enable secure, standardized access to clinical data across the CoverMyMeds ecosystem and with external healthcare partners. This document outlines the primary APIs provided by the platform and how to interact with them.

## API Endpoints

| API Type | Base URL | Purpose | Documentation |
|----------|----------|---------|--------------|
| **FHIR REST API** | `https://fhir-api.covermymeds.com/fhir/r4/` | Standard FHIR RESTful operations | [HL7 FHIR REST API](https://hl7.org/fhir/R4/http.html) |
| **FHIR GraphQL API** | `https://fhir-api.covermymeds.com/graphql` | GraphQL queries for flexible data retrieval | [FHIR GraphQL](https://hl7.org/fhir/R4/graphql.html) |
| **FHIR Bulk Data API** | `https://fhir-api.covermymeds.com/fhir/r4/$export` | Population-level data export | [FHIR Bulk Data Access](https://hl7.org/fhir/uv/bulkdata/) |
| **FHIR Operations** | `https://fhir-api.covermymeds.com/fhir/r4/[resource]/$[operation]` | Named operations beyond basic CRUD | [FHIR Operations](https://hl7.org/fhir/R4/operations.html) |
| **Terminology Services** | `https://fhir-api.covermymeds.com/fhir/r4/ValueSet/$expand` | Code system and value set operations | [FHIR Terminology](https://hl7.org/fhir/R4/terminology-service.html) |
| **SMART App Launch** | `https://fhir-api.covermymeds.com/oauth2/authorize` | OAuth 2.0 endpoints for SMART apps | [SMART App Launch](http://hl7.org/fhir/smart-app-launch/) |

## Authentication & Authorization

The FHIR Interoperability Platform supports multiple authentication mechanisms:

### OAuth 2.0 / SMART on FHIR

The preferred method for client applications (including SMART apps) is OAuth 2.0 following the SMART on FHIR specification:

```typescript
// Example OAuth 2.0 authorization code flow
const authorizationUrl = new URL('https://fhir-api.covermymeds.com/oauth2/authorize');
authorizationUrl.searchParams.append('response_type', 'code');
authorizationUrl.searchParams.append('client_id', 'YOUR_CLIENT_ID');
authorizationUrl.searchParams.append('redirect_uri', 'YOUR_REDIRECT_URI');
authorizationUrl.searchParams.append('scope', 'patient/*.read user/*.* launch');
authorizationUrl.searchParams.append('state', 'random-state-value');
authorizationUrl.searchParams.append('aud', 'https://fhir-api.covermymeds.com/fhir/r4');

// After authorization code is received, exchange for token
async function getToken(authorizationCode) {
  const tokenResponse = await fetch('https://fhir-api.covermymeds.com/oauth2/token', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded'
    },
    body: new URLSearchParams({
      grant_type: 'authorization_code',
      code: authorizationCode,
      redirect_uri: 'YOUR_REDIRECT_URI',
      client_id: 'YOUR_CLIENT_ID',
      client_secret: 'YOUR_CLIENT_SECRET'
    })
  });
  
  return await tokenResponse.json();
}
```

### JWT Authentication

For server-to-server communication, JSON Web Token (JWT) authentication is supported:

```typescript
// Create and sign a JWT for server-to-server authentication
import * as jwt from 'jsonwebtoken';

function createClientAssertion() {
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: 'YOUR_CLIENT_ID',
    sub: 'YOUR_CLIENT_ID',
    aud: 'https://fhir-api.covermymeds.com/oauth2/token',
    jti: generateRandomString(32),
    exp: now + 300, // 5 minutes
    iat: now
  };
  
  return jwt.sign(payload, 'YOUR_PRIVATE_KEY', { algorithm: 'RS256' });
}

async function getTokenWithClientCredentials() {
  const tokenResponse = await fetch('https://fhir-api.covermymeds.com/oauth2/token', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded'
    },
    body: new URLSearchParams({
      grant_type: 'client_credentials',
      client_assertion_type: 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer',
      client_assertion: createClientAssertion(),
      scope: 'system/*.read'
    })
  });
  
  return await tokenResponse.json();
}
```

### API Key Authentication

For internal services and development environments, API key authentication is available:

```typescript
// Using API key authentication
const fhirClient = new AidboxClient({
  url: 'https://fhir-api.covermymeds.com',
  auth: {
    type: 'api-key',
    apiKey: 'YOUR_API_KEY'
  }
});
```

## Example Requests & Responses

### REST API Examples

#### Reading a Patient Resource

```typescript
import { AidboxClient } from '@aidbox/sdk-r4';

const client = new AidboxClient({
  url: 'https://fhir-api.covermymeds.com',
  auth: {
    type: 'bearer',
    token: 'YOUR_ACCESS_TOKEN'
  }
});

// Read a patient by ID
async function getPatient(patientId) {
  try {
    const patient = await client.fhirRead('Patient', patientId);
    console.log('Patient retrieved:', patient);
    return patient;
  } catch (error) {
    console.error('Error retrieving patient:', error);
    throw error;
  }
}

// Search for patients
async function searchPatients(params) {
  try {
    const searchResults = await client.fhirSearch('Patient', params);
    console.log('Search results:', searchResults);
    return searchResults;
  } catch (error) {
    console.error('Error searching patients:', error);
    throw error;
  }
}

// Example usage
getPatient('patient-123');
searchPatients({ name: 'Smith', birthdate: '1970-01-01' });
```

#### Creating a Medication Request

```typescript
// Create a new MedicationRequest
async function createMedicationRequest(patientId, medicationId, practitionerId) {
  try {
    const medicationRequest = await client.fhirCreate('MedicationRequest', {
      resourceType: 'MedicationRequest',
      status: 'active',
      intent: 'order',
      medicationReference: {
        reference: `Medication/${medicationId}`
      },
      subject: {
        reference: `Patient/${patientId}`
      },
      requester: {
        reference: `Practitioner/${practitionerId}`
      },
      authoredOn: new Date().toISOString(),
      dosageInstruction: [
        {
          text: 'Take one tablet daily',
          timing: {
            repeat: {
              frequency: 1,
              period: 1,
              periodUnit: 'd'
            }
          },
          doseAndRate: [
            {
              doseQuantity: {
                value: 1,
                unit: 'tablet',
                system: 'http://terminology.hl7.org/CodeSystem/v3-orderableDrugForm',
                code: 'TAB'
              }
            }
          ]
        }
      ]
    });
    
    console.log('MedicationRequest created:', medicationRequest);
    return medicationRequest;
  } catch (error) {
    console.error('Error creating medication request:', error);
    throw error;
  }
}
```

### GraphQL API Examples

```typescript
import { AidboxClient } from '@aidbox/sdk-r4';

const client = new AidboxClient({
  url: 'https://fhir-api.covermymeds.com',
  auth: {
    type: 'bearer',
    token: 'YOUR_ACCESS_TOKEN'
  }
});

// Query for patient and related medication requests using GraphQL
async function getPatientWithMedications(patientId) {
  const query = `
    query ($patientId: ID!) {
      Patient(id: $patientId) {
        id
        name {
          given
          family
        }
        birthDate
        MedicationRequest(subject: { reference: $patientId }) {
          id
          status
          medicationReference {
            resource {
              ... on Medication {
                id
                code {
                  coding {
                    system
                    code
                    display
                  }
                }
              }
            }
          }
          authoredOn
          dosageInstruction {
            text
          }
        }
      }
    }
  `;
  
  try {
    const result = await client.graphql(query, { patientId });
    console.log('GraphQL result:', result);
    return result;
  } catch (error) {
    console.error('GraphQL error:', error);
    throw error;
  }
}

// Example usage
getPatientWithMedications('patient-123');
```

### Bulk Data API Example

```typescript
// Initiate a system-level export
async function initiateSystemExport() {
  try {
    const response = await fetch('https://fhir-api.covermymeds.com/fhir/r4/$export', {
      method: 'GET',
      headers: {
        'Authorization': 'Bearer YOUR_ACCESS_TOKEN',
        'Accept': 'application/fhir+json',
        'Prefer': 'respond-async'
      }
    });
    
    // Check for 202 Accepted response with Content-Location header
    if (response.status === 202) {
      const contentLocation = response.headers.get('Content-Location');
      console.log('Export initiated, status endpoint:', contentLocation);
      return contentLocation;
    } else {
      throw new Error(`Unexpected response: ${response.status}`);
    }
  } catch (error) {
    console.error('Error initiating export:', error);
    throw error;
  }
}

// Check the status of a bulk export
async function checkExportStatus(statusUrl) {
  try {
    const response = await fetch(statusUrl, {
      method: 'GET',
      headers: {
        'Authorization': 'Bearer YOUR_ACCESS_TOKEN'
      }
    });
    
    if (response.status === 202) {
      console.log('Export still in progress');
      return { completed: false };
    } else if (response.status === 200) {
      const result = await response.json();
      console.log('Export completed:', result);
      return { completed: true, result };
    } else {
      throw new Error(`Unexpected response: ${response.status}`);
    }
  } catch (error) {
    console.error('Error checking export status:', error);
    throw error;
  }
}
```

### FHIR Operations Example

```typescript
// Using a custom operation to validate a resource
async function validateResource(resource) {
  try {
    const result = await client.request({
      method: 'POST',
      url: '/fhir/r4/Patient/$validate',
      body: resource
    });
    
    console.log('Validation result:', result);
    return result;
  } catch (error) {
    console.error('Validation error:', error);
    throw error;
  }
}

// Using a custom operation to convert data
async function convertData(source, targetFormat) {
  try {
    const result = await client.request({
      method: 'POST',
      url: '/fhir/r4/$convert',
      body: {
        source: source,
        targetFormat: targetFormat
      }
    });
    
    console.log('Conversion result:', result);
    return result;
  } catch (error) {
    console.error('Conversion error:', error);
    throw error;
  }
}
```

## Error Handling

The FHIR Interoperability Platform follows the FHIR specification for error reporting, using the OperationOutcome resource to provide detailed error information.

### Common HTTP Status Codes

| Status Code | Description | Common Causes |
|-------------|-------------|---------------|
| 200 OK | Request succeeded | Successful GET, PUT, or POST that does not create a new resource |
| 201 Created | Resource created | Successful POST that creates a new resource |
| 400 Bad Request | Invalid request | Malformed request, invalid resource content |
| 401 Unauthorized | Authentication failed | Missing or invalid credentials |
| 403 Forbidden | Insufficient permissions | User lacks necessary access rights |
| 404 Not Found | Resource not found | Requested resource does not exist |
| 409 Conflict | Resource conflict | Version conflict, duplicate resource |
| 422 Unprocessable Entity | Validation error | Resource fails validation rules |
| 429 Too Many Requests | Rate limit exceeded | Client has sent too many requests |
| 500 Server Error | Server error | Internal server error, unexpected condition |

### Error Response Example

```json
{
  "resourceType": "OperationOutcome",
  "issue": [
    {
      "severity": "error",
      "code": "structure",
      "details": {
        "text": "The start date must be before the end date"
      },
      "location": ["MedicationRequest.dispenseRequest.validityPeriod"]
    },
    {
      "severity": "error",
      "code": "required",
      "details": {
        "text": "A medication reference or code must be provided"
      },
      "location": ["MedicationRequest.medication[x]"]
    }
  ]
}
```

### Client-Side Error Handling

```typescript
async function handleFhirOperation(operation) {
  try {
    const result = await operation();
    return result;
  } catch (error) {
    if (error.status === 401) {
      console.error('Authentication error. Please re-authenticate.');
      // Handle authentication refresh
    } else if (error.status === 403) {
      console.error('Permission denied. Your account lacks the necessary permissions.');
    } else if (error.status === 404) {
      console.error('Resource not found. Please check the resource ID.');
    } else if (error.status === 422) {
      // Process validation errors from OperationOutcome
      const operationOutcome = error.data;
      if (operationOutcome && operationOutcome.resourceType === 'OperationOutcome') {
        for (const issue of operationOutcome.issue) {
          console.error(`Validation error: ${issue.details.text}`);
          // Handle specific validation issues
        }
      }
    } else if (error.status === 429) {
      console.error('Rate limit exceeded. Please wait before making more requests.');
      // Implement retry with exponential backoff
      await new Promise(resolve => setTimeout(resolve, 2000));
      return handleFhirOperation(operation);
    } else {
      console.error('Unexpected error:', error);
    }
    throw error;
  }
}
```

## Related Resources
- [FHIR Interoperability Platform Key Concepts](../01-getting-started/key-concepts.md)
- [FHIR Interoperability Platform Data Model](./data-model.md)
- [FHIR Interoperability Platform Advanced Use Cases](../03-advanced-patterns/advanced-use-cases.md)
- [FHIR Interoperability Platform Access Controls](../04-governance-compliance/access-controls.md)
- [HL7 FHIR Documentation](https://hl7.org/fhir/R4/index.html)
- [Aidbox REST API Documentation](https://docs.aidbox.app/api-1/api)