# FHIR Interoperability Platform Core APIs

## Introduction

The FHIR Interoperability Platform provides a comprehensive set of APIs for interacting with healthcare data using the HL7 FHIR standard. This document outlines the core APIs available through the platform, implemented with TypeScript and modern cloud-native technologies.

## RESTful API Overview

The platform implements the standard FHIR RESTful API as defined in the FHIR specification, with additional cloud-native enhancements for scalability and security.

### API Base URL

```
https://fhir-api.cmm-platform.org/fhir/r4
```

### Authentication

All API requests require authentication using OAuth 2.0 Bearer tokens:

```typescript
// Example: Authentication with TypeScript
import axios from 'axios';

const fhirClient = axios.create({
  baseURL: 'https://fhir-api.cmm-platform.org/fhir/r4',
  headers: {
    'Content-Type': 'application/fhir+json',
    'Accept': 'application/fhir+json',
    'Authorization': `Bearer ${accessToken}`
  }
});
```

## Resource APIs

### Create Resource

Create a new FHIR resource.

**Endpoint:** `POST /{resourceType}`

**TypeScript Example:**

```typescript
import { Patient } from 'fhir/r4';

async function createPatient(patient: Patient): Promise<Patient> {
  const response = await fhirClient.post<Patient>('/Patient', patient);
  return response.data;
}

// Usage example
const newPatient: Patient = {
  resourceType: 'Patient',
  identifier: [{
    system: 'http://hospital.example.org/identifiers/mrn',
    value: 'MRN12345'
  }],
  name: [{
    family: 'Smith',
    given: ['John']
  }],
  gender: 'male',
  birthDate: '1970-01-01'
};

const createdPatient = await createPatient(newPatient);
console.log(`Created patient with ID: ${createdPatient.id}`);
```

### Read Resource

Retrieve a specific FHIR resource by ID.

**Endpoint:** `GET /{resourceType}/{id}`

**TypeScript Example:**

```typescript
import { Patient } from 'fhir/r4';

async function getPatient(id: string): Promise<Patient> {
  const response = await fhirClient.get<Patient>(`/Patient/${id}`);
  return response.data;
}

// Usage example
const patient = await getPatient('123');
console.log(`Retrieved patient: ${patient.name?.[0]?.family}, ${patient.name?.[0]?.given?.[0]}`);
```

### Update Resource

Update an existing FHIR resource.

**Endpoint:** `PUT /{resourceType}/{id}`

**TypeScript Example:**

```typescript
import { Patient } from 'fhir/r4';

async function updatePatient(patient: Patient): Promise<Patient> {
  if (!patient.id) {
    throw new Error('Patient ID is required for updates');
  }
  
  const response = await fhirClient.put<Patient>(`/Patient/${patient.id}`, patient);
  return response.data;
}

// Usage example
const patient = await getPatient('123');

// Update patient information
if (patient.name && patient.name.length > 0) {
  patient.name[0].family = 'Smith-Jones';
}

patient.telecom = [{
  system: 'phone',
  value: '555-123-4567',
  use: 'home'
}];

const updatedPatient = await updatePatient(patient);
console.log(`Updated patient: ${updatedPatient.name?.[0]?.family}`);
```

### Delete Resource

Delete a FHIR resource.

**Endpoint:** `DELETE /{resourceType}/{id}`

**TypeScript Example:**

```typescript
async function deletePatient(id: string): Promise<void> {
  await fhirClient.delete(`/Patient/${id}`);
  console.log(`Deleted patient with ID: ${id}`);
}

// Usage example
await deletePatient('123');
```

### Search Resources

Search for FHIR resources based on various criteria.

**Endpoint:** `GET /{resourceType}?{parameters}`

**TypeScript Example:**

```typescript
import { Bundle } from 'fhir/r4';

async function searchPatients(params: Record<string, string>): Promise<Bundle> {
  const response = await fhirClient.get<Bundle>('/Patient', { params });
  return response.data;
}

// Usage example: Search for patients by name
const bundle = await searchPatients({ name: 'Smith' });
console.log(`Found ${bundle.total} patients`);

// Usage example: More complex search
const advancedBundle = await searchPatients({
  family: 'Smith',
  gender: 'male',
  'birthdate': 'gt1970-01-01',
  _count: '10',
  _sort: '-_lastUpdated'
});

// Process search results
advancedBundle.entry?.forEach(entry => {
  const patient = entry.resource as Patient;
  console.log(`Patient: ${patient.name?.[0]?.family}, ${patient.name?.[0]?.given?.[0]}`);
});
```

### History

Retrieve the history of a resource.

**Endpoint:** `GET /{resourceType}/{id}/_history`

**TypeScript Example:**

```typescript
import { Bundle } from 'fhir/r4';

async function getResourceHistory(resourceType: string, id: string): Promise<Bundle> {
  const response = await fhirClient.get<Bundle>(`/${resourceType}/${id}/_history`);
  return response.data;
}

// Usage example
const historyBundle = await getResourceHistory('Patient', '123');
console.log(`Resource has ${historyBundle.total} versions`);
```

## Batch and Transaction Operations

### Batch

Process a batch of operations where each operation is processed independently.

**Endpoint:** `POST /`

**TypeScript Example:**

```typescript
import { Bundle, BundleEntry, Patient, Observation } from 'fhir/r4';

async function executeBatch(entries: BundleEntry[]): Promise<Bundle> {
  const batch: Bundle = {
    resourceType: 'Bundle',
    type: 'batch',
    entry: entries
  };
  
  const response = await fhirClient.post<Bundle>('/', batch);
  return response.data;
}

// Usage example: Create a patient and observations in a batch
const patient: Patient = {
  resourceType: 'Patient',
  identifier: [{
    system: 'http://hospital.example.org/identifiers/mrn',
    value: 'MRN12345'
  }],
  name: [{
    family: 'Smith',
    given: ['John']
  }]
};

const observation: Observation = {
  resourceType: 'Observation',
  status: 'final',
  code: {
    coding: [{
      system: 'http://loinc.org',
      code: '8867-4',
      display: 'Heart rate'
    }]
  },
  valueQuantity: {
    value: 80,
    unit: 'beats/minute',
    system: 'http://unitsofmeasure.org',
    code: '/min'
  }
};

const batchEntries: BundleEntry[] = [
  {
    request: {
      method: 'POST',
      url: 'Patient'
    },
    resource: patient
  },
  {
    request: {
      method: 'POST',
      url: 'Observation'
    },
    resource: observation
  }
];

const batchResult = await executeBatch(batchEntries);
console.log(`Batch completed with ${batchResult.entry?.length} results`);
```

### Transaction

Process a transaction where all operations succeed or fail together.

**Endpoint:** `POST /`

**TypeScript Example:**

```typescript
import { Bundle, BundleEntry } from 'fhir/r4';

async function executeTransaction(entries: BundleEntry[]): Promise<Bundle> {
  const transaction: Bundle = {
    resourceType: 'Bundle',
    type: 'transaction',
    entry: entries
  };
  
  const response = await fhirClient.post<Bundle>('/', transaction);
  return response.data;
}

// Usage example similar to batch but with type: 'transaction'
```

## Search Operations

### Chained Search

Search for resources based on properties of referenced resources.

**TypeScript Example:**

```typescript
// Search for observations for patients with a specific name
async function findObservationsForPatientsWithName(name: string): Promise<Bundle> {
  const response = await fhirClient.get<Bundle>('/Observation', {
    params: {
      'patient.name': name
    }
  });
  return response.data;
}

// Usage example
const observations = await findObservationsForPatientsWithName('Smith');
```

### Include and Reverse Include

Include referenced resources or resources that reference the matched resources.

**TypeScript Example:**

```typescript
// Search for patients and include their conditions
async function findPatientsWithConditions(name: string): Promise<Bundle> {
  const response = await fhirClient.get<Bundle>('/Patient', {
    params: {
      name,
      '_include': 'Patient:condition'
    }
  });
  return response.data;
}

// Search for conditions and include the patients they belong to
async function findConditionsWithPatients(code: string): Promise<Bundle> {
  const response = await fhirClient.get<Bundle>('/Condition', {
    params: {
      code,
      '_revinclude': 'Condition:patient'
    }
  });
  return response.data;
}
```

## Subscription API

Manage subscriptions for real-time notifications.

### Create Subscription

**Endpoint:** `POST /Subscription`

**TypeScript Example:**

```typescript
import { Subscription } from 'fhir/r4';

async function createSubscription(subscription: Subscription): Promise<Subscription> {
  const response = await fhirClient.post<Subscription>('/Subscription', subscription);
  return response.data;
}

// Usage example: Create a REST Hook subscription
const subscription: Subscription = {
  resourceType: 'Subscription',
  status: 'requested',
  reason: 'Monitor new patients',
  criteria: 'Patient?_format=application/fhir+json',
  channel: {
    type: 'rest-hook',
    endpoint: 'https://webhook.example.org/fhir-subscription',
    payload: 'application/fhir+json',
    header: ['Authorization: Bearer secret-token']
  }
};

const createdSubscription = await createSubscription(subscription);
console.log(`Created subscription with ID: ${createdSubscription.id}`);
```

## Bulk Data API

Export and import large volumes of FHIR data.

### Start System Export

**Endpoint:** `GET /$export`

**TypeScript Example:**

```typescript
async function startSystemExport(params: Record<string, string> = {}): Promise<string> {
  const response = await fhirClient.get('/$export', {
    params,
    headers: {
      'Prefer': 'respond-async'
    },
    maxRedirects: 0,
    validateStatus: status => status === 202
  });
  
  const contentLocation = response.headers['content-location'];
  if (!contentLocation) {
    throw new Error('No Content-Location header in response');
  }
  
  return contentLocation;
}

// Usage example
const statusUrl = await startSystemExport({
  '_type': 'Patient,Observation',
  '_since': '2023-01-01T00:00:00Z'
});

console.log(`Export job status URL: ${statusUrl}`);
```

### Check Export Status

**TypeScript Example:**

```typescript
async function checkExportStatus(statusUrl: string): Promise<any> {
  const response = await axios.get(statusUrl, {
    headers: {
      'Accept': 'application/json',
      'Authorization': `Bearer ${accessToken}`
    }
  });
  
  if (response.status === 202) {
    return { status: 'in-progress' };
  } else if (response.status === 200) {
    return { status: 'completed', output: response.data };
  } else {
    throw new Error(`Unexpected status: ${response.status}`);
  }
}
```

## Operations API

Custom operations for specific functionality.

### Validate Resource

**Endpoint:** `POST /{resourceType}/$validate`

**TypeScript Example:**

```typescript
import { OperationOutcome, Patient } from 'fhir/r4';

async function validateResource(resource: any): Promise<OperationOutcome> {
  const response = await fhirClient.post<OperationOutcome>(
    `/${resource.resourceType}/$validate`,
    resource
  );
  return response.data;
}

// Usage example
const patient: Patient = {
  resourceType: 'Patient',
  // Missing required fields for US Core profile
};

try {
  const outcome = await validateResource(patient);
  
  if (outcome.issue?.some(issue => issue.severity === 'error')) {
    console.error('Validation failed:', outcome.issue);
  } else {
    console.log('Validation passed');
  }
} catch (error) {
  console.error('Validation request failed:', error);
}
```

### Convert Data

**Endpoint:** `POST /$convert`

**TypeScript Example:**

```typescript
async function convertData(data: any, sourceFormat: string, targetFormat: string): Promise<any> {
  const parameters = {
    resourceType: 'Parameters',
    parameter: [
      {
        name: 'content',
        resource: data
      },
      {
        name: 'sourceFormat',
        valueString: sourceFormat
      },
      {
        name: 'targetFormat',
        valueString: targetFormat
      }
    ]
  };
  
  const response = await fhirClient.post('/$convert', parameters);
  return response.data;
}

// Usage example: Convert CDA to FHIR
const cdaDocument = '<ClinicalDocument>...</ClinicalDocument>';
const fhirResources = await convertData(
  cdaDocument,
  'application/cda+xml',
  'application/fhir+json'
);
```

## TypeScript Client SDK

The platform provides a TypeScript client SDK for simplified API interaction.

```typescript
import { FhirClient } from '@cmm/fhir-client';
import { Patient, Bundle, OperationOutcome } from 'fhir/r4';

// Initialize the client
const client = new FhirClient({
  baseUrl: 'https://fhir-api.cmm-platform.org/fhir/r4',
  auth: {
    type: 'bearer',
    token: accessToken
  }
});

// Use the client
async function exampleUsage() {
  try {
    // Create a patient
    const patient: Patient = {
      resourceType: 'Patient',
      name: [{ family: 'Smith', given: ['John'] }],
      gender: 'male',
      birthDate: '1970-01-01'
    };
    
    const createdPatient = await client.create<Patient>(patient);
    
    // Search for patients
    const searchResult = await client.search<Patient>('Patient', {
      family: 'Smith',
      gender: 'male'
    });
    
    // Process search results
    searchResult.entry?.forEach(entry => {
      console.log(`Found patient: ${entry.resource.id}`);
    });
    
    // Update a patient
    createdPatient.active = true;
    const updatedPatient = await client.update<Patient>(createdPatient);
    
    // Delete a patient
    await client.delete('Patient', createdPatient.id!);
    
  } catch (error) {
    if (error.response?.data?.resourceType === 'OperationOutcome') {
      const outcome = error.response.data as OperationOutcome;
      console.error('FHIR error:', outcome.issue?.[0]?.diagnostics);
    } else {
      console.error('Error:', error.message);
    }
  }
}
```

## Conclusion

The FHIR Interoperability Platform provides a comprehensive set of APIs for healthcare data interoperability. These TypeScript-based, cloud-native APIs enable developers to build modern healthcare applications with strong typing, improved developer experience, and robust error handling.
