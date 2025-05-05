# Accessing FHIR Resources

## Introduction

Efficient and secure retrieval of healthcare data is essential for building responsive and compliant healthcare applications. This guide explains how to access FHIR resources from the Aidbox FHIR server, covering authentication, authorization, and various query patterns. It provides practical examples using the TypeScript SDK to help you efficiently retrieve healthcare data while following security best practices.

### Quick Start

1. Configure authentication for your client:
   - Basic authentication for development
   - OAuth 2.0 for production environments
   - SMART on FHIR for healthcare applications
2. Retrieve single resources with `client.read<ResourceType>()`
3. Search for resources with `client.search<ResourceType>()`
4. Implement pagination for large result sets
5. Handle errors appropriately using try/catch blocks

### Related Components

- [FHIR Client Authentication](fhir-client-authentication.md): Configure secure access to your FHIR server
- [FHIR Query Optimization](fhir-query-optimization.md): Learn advanced query techniques
- [GraphQL Integration](graphql-integration.md): Alternative approach to data retrieval
- [Query Pattern Decisions](fhir-query-decisions.md) (Coming Soon): Understand query pattern choices

## Authentication and Authorization

Aidbox provides several authentication methods to secure access to FHIR resources.

### Basic Authentication

Basic authentication is suitable for development environments and backend services:

```typescript
import { AidboxClient } from '@aidbox/sdk-r4';

const client = new AidboxClient({
  baseUrl: 'http://localhost:8888',
  auth: {
    type: 'basic',
    username: 'root',
    password: 'secret'
  }
});
```

### OAuth 2.0 Authentication

For production environments, OAuth 2.0 provides more secure authentication:

```typescript
import { AidboxClient } from '@aidbox/sdk-r4';

// Client credentials flow
const client = new AidboxClient({
  baseUrl: 'https://fhir-server.example.org',
  auth: {
    type: 'client_credentials',
    client_id: 'your-client-id',
    client_secret: 'your-client-secret',
    tokenUrl: 'https://fhir-server.example.org/auth/token'
  }
});
```

### SMART on FHIR Authentication

SMART on FHIR is a profile of OAuth 2.0 designed specifically for healthcare applications. It allows apps to request granular access to FHIR resources.

```typescript
import { AidboxClient } from '@aidbox/sdk-r4';

// Authorization code flow with SMART scopes
const client = new AidboxClient({
  baseUrl: 'https://fhir-server.example.org',
  auth: {
    type: 'authorization_code',
    client_id: 'your-client-id',
    redirect_uri: 'https://your-app.example.org/callback',
    scope: 'launch/patient patient/*.read',
    authorizeUrl: 'https://fhir-server.example.org/auth/authorize',
    tokenUrl: 'https://fhir-server.example.org/auth/token'
  }
});
```

#### SMART App Launch

For SMART on FHIR applications, the launch sequence typically involves:

1. Redirecting to the authorization server
2. User authentication
3. Consent for requested scopes
4. Redirect back to your application with an authorization code
5. Exchange of the code for an access token

```typescript
// Step 1: Redirect to authorization server
function initiateSmartLogin() {
  const authUrl = new URL('https://fhir-server.example.org/auth/authorize');
  authUrl.searchParams.append('response_type', 'code');
  authUrl.searchParams.append('client_id', 'your-client-id');
  authUrl.searchParams.append('redirect_uri', 'https://your-app.example.org/callback');
  authUrl.searchParams.append('scope', 'launch/patient patient/*.read');
  authUrl.searchParams.append('state', generateRandomState());
  authUrl.searchParams.append('aud', 'https://fhir-server.example.org');
  
  window.location.href = authUrl.toString();
}

// Step 5: Exchange code for token
async function handleCallback(code: string) {
  const tokenResponse = await fetch('https://fhir-server.example.org/auth/token', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded'
    },
    body: new URLSearchParams({
      grant_type: 'authorization_code',
      code,
      client_id: 'your-client-id',
      redirect_uri: 'https://your-app.example.org/callback'
    })
  });
  
  const tokenData = await tokenResponse.json();
  
  // Initialize client with the access token
  const client = new AidboxClient({
    baseUrl: 'https://fhir-server.example.org',
    auth: {
      type: 'bearer',
      token: tokenData.access_token
    }
  });
  
  // Use the client to access resources
}
```

## Basic Query Patterns

### Reading a Single Resource

To retrieve a specific resource by its ID:

```typescript
import { AidboxClient } from '@aidbox/sdk-r4';
import { Patient } from '@aidbox/sdk-r4/types';

async function getPatient(id: string): Promise<Patient> {
  const client = new AidboxClient({
    baseUrl: 'http://localhost:8888',
    auth: {
      type: 'basic',
      username: 'root',
      password: 'secret'
    }
  });

  try {
    return await client.read<Patient>({
      resourceType: 'Patient',
      id
    });
  } catch (error) {
    console.error('Error fetching patient:', error);
    throw error;
  }
}
```

### Searching for Resources

To search for resources based on criteria:

```typescript
import { AidboxClient } from '@aidbox/sdk-r4';
import { Bundle, Patient } from '@aidbox/sdk-r4/types';

async function searchPatients(name: string): Promise<Patient[]> {
  const client = new AidboxClient({
    baseUrl: 'http://localhost:8888',
    auth: {
      type: 'basic',
      username: 'root',
      password: 'secret'
    }
  });

  try {
    const bundle = await client.search<Patient>({
      resourceType: 'Patient',
      params: {
        name: name
      }
    });

    // Extract patients from bundle
    return bundle.entry?.map(entry => entry.resource as Patient) || [];
  } catch (error) {
    console.error('Error searching patients:', error);
    throw error;
  }
}
```

### Complex Search Parameters

FHIR supports a wide range of search parameters and modifiers:

```typescript
async function advancedPatientSearch(): Promise<Patient[]> {
  const client = new AidboxClient({
    baseUrl: 'http://localhost:8888',
    auth: {
      type: 'basic',
      username: 'root',
      password: 'secret'
    }
  });

  try {
    const bundle = await client.search<Patient>({
      resourceType: 'Patient',
      params: {
        // Multiple parameters
        'name': 'Smith',
        'birthdate': 'gt2000-01-01',
        'gender': 'male',
        
        // Modifiers
        'name:exact': 'John Smith',
        'address:contains': 'New York',
        
        // Special parameters
        '_sort': 'birthdate',
        '_count': '50',
        '_include': 'Patient:organization'
      }
    });

    return bundle.entry?.map(entry => entry.resource as Patient) || [];
  } catch (error) {
    console.error('Error performing advanced search:', error);
    throw error;
  }
}
```

### Chained Parameters

FHIR allows chaining parameters to search through referenced resources:

```typescript
async function searchPatientsWithChaining(): Promise<Patient[]> {
  const client = new AidboxClient({
    baseUrl: 'http://localhost:8888',
    auth: {
      type: 'basic',
      username: 'root',
      password: 'secret'
    }
  });

  try {
    // Find patients who have prescriptions for a specific medication
    const bundle = await client.search<Patient>({
      resourceType: 'Patient',
      params: {
        '_has:MedicationRequest:patient:medication.code': '123456'
      }
    });

    return bundle.entry?.map(entry => entry.resource as Patient) || [];
  } catch (error) {
    console.error('Error searching with chained parameters:', error);
    throw error;
  }
}
```

## Resource Versioning

FHIR resources are versioned, allowing you to track changes and retrieve specific versions.

### Reading a Specific Version

```typescript
import { AidboxClient } from '@aidbox/sdk-r4';
import { Patient } from '@aidbox/sdk-r4/types';

async function getPatientVersion(id: string, versionId: string): Promise<Patient> {
  const client = new AidboxClient({
    baseUrl: 'http://localhost:8888',
    auth: {
      type: 'basic',
      username: 'root',
      password: 'secret'
    }
  });

  try {
    return await client.vread<Patient>({
      resourceType: 'Patient',
      id,
      versionId
    });
  } catch (error) {
    console.error('Error fetching patient version:', error);
    throw error;
  }
}
```

### Getting Resource History

```typescript
import { AidboxClient } from '@aidbox/sdk-r4';
import { Bundle, Patient } from '@aidbox/sdk-r4/types';

async function getPatientHistory(id: string): Promise<Patient[]> {
  const client = new AidboxClient({
    baseUrl: 'http://localhost:8888',
    auth: {
      type: 'basic',
      username: 'root',
      password: 'secret'
    }
  });

  try {
    const bundle = await client.history<Patient>({
      resourceType: 'Patient',
      id
    });

    return bundle.entry?.map(entry => entry.resource as Patient) || [];
  } catch (error) {
    console.error('Error fetching patient history:', error);
    throw error;
  }
}
```

## Bulk Data Access

For retrieving large datasets, FHIR provides bulk data access capabilities.

### Exporting Data

```typescript
import { AidboxClient } from '@aidbox/sdk-r4';

async function initiateExport() {
  const client = new AidboxClient({
    baseUrl: 'http://localhost:8888',
    auth: {
      type: 'basic',
      username: 'root',
      password: 'secret'
    }
  });

  try {
    // Start an export operation
    const response = await fetch(`${client.baseUrl}/$export?_type=Patient,MedicationRequest`, {
      method: 'GET',
      headers: {
        'Authorization': 'Basic ' + btoa('root:secret'),
        'Accept': 'application/fhir+json',
        'Prefer': 'respond-async'
      }
    });

    // Get the content location for polling
    const contentLocation = response.headers.get('Content-Location');
    return contentLocation;
  } catch (error) {
    console.error('Error initiating export:', error);
    throw error;
  }
}

async function checkExportStatus(contentLocation: string) {
  try {
    const response = await fetch(contentLocation, {
      method: 'GET',
      headers: {
        'Authorization': 'Basic ' + btoa('root:secret'),
        'Accept': 'application/json'
      }
    });

    if (response.status === 202) {
      // Still processing
      return { status: 'processing' };
    } else {
      // Completed
      const result = await response.json();
      return { status: 'completed', result };
    }
  } catch (error) {
    console.error('Error checking export status:', error);
    throw error;
  }
}
```

## Error Handling

When accessing FHIR resources, it's important to handle errors properly.

```typescript
import { AidboxClient } from '@aidbox/sdk-r4';
import { OperationOutcome, Patient } from '@aidbox/sdk-r4/types';

async function getPatientWithErrorHandling(id: string): Promise<Patient | null> {
  const client = new AidboxClient({
    baseUrl: 'http://localhost:8888',
    auth: {
      type: 'basic',
      username: 'root',
      password: 'secret'
    }
  });

  try {
    return await client.read<Patient>({
      resourceType: 'Patient',
      id
    });
  } catch (error: any) {
    // Check if it's a FHIR OperationOutcome
    if (error.resourceType === 'OperationOutcome') {
      const outcome = error as OperationOutcome;
      
      // Handle different error types
      if (outcome.issue?.[0]?.code === 'not-found') {
        console.log(`Patient ${id} not found`);
        return null;
      } else {
        console.error('FHIR error:', outcome.issue?.[0]?.details?.text);
        throw new Error(outcome.issue?.[0]?.details?.text || 'Unknown FHIR error');
      }
    } else {
      // Handle network or other errors
      console.error('Error accessing FHIR server:', error.message);
      throw error;
    }
  }
}
```

## Best Practices

### Efficient Querying

1. **Be Specific**: Only request the data you need. Use `_elements` to limit returned fields.

   ```typescript
   const bundle = await client.search<Patient>({
     resourceType: 'Patient',
     params: {
       'name': 'Smith',
       '_elements': 'id,name,birthDate'
     }
   });
   ```

2. **Use Pagination**: For large result sets, use pagination to improve performance.

   ```typescript
   async function getAllPatients(): Promise<Patient[]> {
     const client = new AidboxClient({
       baseUrl: 'http://localhost:8888',
       auth: {
         type: 'basic',
         username: 'root',
         password: 'secret'
       }
     });

     let url = 'Patient?_count=100';
     const allPatients: Patient[] = [];

     while (url) {
       const bundle = await client.request<Bundle<Patient>>({
         method: 'GET',
         url
       });

       // Add patients from this page
       if (bundle.entry) {
         allPatients.push(...bundle.entry.map(entry => entry.resource as Patient));
       }

       // Get next page URL if it exists
       const nextLink = bundle.link?.find(link => link.relation === 'next');
       url = nextLink?.url || '';
     }

     return allPatients;
   }
   ```

3. **Use Includes Wisely**: Include referenced resources only when needed.

   ```typescript
   const bundle = await client.search<MedicationRequest>({
     resourceType: 'MedicationRequest',
     params: {
       'patient': patientId,
       '_include': 'MedicationRequest:medication'
     }
   });
   ```

### Security Considerations

1. **Token Management**: Securely store and refresh OAuth tokens.

2. **Scope Limitation**: Request only the scopes your application needs.

3. **Error Logging**: Log authentication errors without exposing sensitive information.

4. **HTTPS**: Always use HTTPS for production environments.

## Conclusion

Effectively accessing FHIR resources requires understanding authentication mechanisms, query patterns, and best practices. By following the guidelines in this document, you can build secure, efficient applications that interact with FHIR servers.
