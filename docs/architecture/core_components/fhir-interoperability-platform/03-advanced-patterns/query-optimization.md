# FHIR Server Query Optimization

## Introduction

As healthcare applications scale to handle larger volumes of data and more concurrent users, query performance becomes a critical factor in maintaining responsive user experiences. This guide provides advanced techniques for optimizing FHIR queries to improve performance, reduce latency, and enhance scalability. Efficient querying is essential for healthcare applications that need to process large volumes of patient data while maintaining responsiveness.

### Quick Start

1. Use direct ID-based access for single resources: `client.read<ResourceType>({ resourceType, id })`
2. Limit returned fields with `_elements` parameter to reduce payload size
3. Implement pagination for large result sets using `_count` and handling `next` links
4. Use batch requests to reduce round trips to the server
5. Consider caching frequently accessed, relatively static resources
6. Monitor query performance to identify optimization opportunities

### Related Components

- [Accessing FHIR Resources](accessing-fhir-resources.md): Learn basic query patterns
- [GraphQL Integration](graphql-integration.md): Alternative approach for efficient data retrieval
- [Performance Architecture Decisions](fhir-performance-decisions.md) (Coming Soon): Understand performance optimization choices

## Basic Query Optimization Techniques

### Retrieving Single Resources Efficiently

When retrieving a single resource, use direct ID-based access whenever possible:

```typescript
import { AidboxClient } from '@aidbox/sdk-r4';
import { Patient } from '@aidbox/sdk-r4/types';

const client = new AidboxClient({
  baseUrl: 'http://localhost:8888',
  auth: {
    type: 'basic',
    username: 'root',
    password: 'secret'
  }
});

// Efficient: Direct ID-based access
async function getPatientEfficient(id: string): Promise<Patient> {
  return await client.read<Patient>({
    resourceType: 'Patient',
    id
  });
}

// Less efficient: Using search with ID
async function getPatientLessEfficient(id: string): Promise<Patient | null> {
  const bundle = await client.search<Patient>({
    resourceType: 'Patient',
    params: {
      _id: id
    }
  });
  
  return bundle.entry?.[0]?.resource as Patient || null;
}
```

### Limiting Returned Fields

Use the `_elements` parameter to limit the fields returned by the server:

```typescript
// Only retrieve specific fields
async function getPatientBasicInfo(id: string): Promise<Patient> {
  return await client.read<Patient>({
    resourceType: 'Patient',
    id,
    params: {
      _elements: 'id,name,birthDate,gender'
    }
  });
}
```

### Using Summary Views

FHIR supports summary views to retrieve only essential information:

```typescript
// Get a summary view of patients
async function getPatientsSummary(): Promise<Patient[]> {
  const bundle = await client.search<Patient>({
    resourceType: 'Patient',
    params: {
      _summary: 'true'
    }
  });
  
  return bundle.entry?.map(entry => entry.resource as Patient) || [];
}
```

## Advanced Query Patterns

### Querying Multiple Resources for a Single Patient

When you need data from multiple resource types for a single patient, you have several options:

#### Option 1: Multiple Parallel Requests

```typescript
import { AidboxClient } from '@aidbox/sdk-r4';
import { Patient, Observation, MedicationRequest, Bundle } from '@aidbox/sdk-r4/types';

async function getPatientData(patientId: string): Promise<{
  patient: Patient;
  observations: Observation[];
  medications: MedicationRequest[];
}> {
  const client = new AidboxClient({
    baseUrl: 'http://localhost:8888',
    auth: {
      type: 'basic',
      username: 'root',
      password: 'secret'
    }
  });

  // Execute requests in parallel
  const [patientResult, observationsResult, medicationsResult] = await Promise.all([
    client.read<Patient>({
      resourceType: 'Patient',
      id: patientId
    }),
    client.search<Observation>({
      resourceType: 'Observation',
      params: {
        subject: `Patient/${patientId}`,
        _sort: '-date',
        _count: '50'
      }
    }),
    client.search<MedicationRequest>({
      resourceType: 'MedicationRequest',
      params: {
        subject: `Patient/${patientId}`,
        _sort: '-authored',
        _count: '50'
      }
    })
  ]);

  return {
    patient: patientResult,
    observations: observationsResult.entry?.map(entry => entry.resource as Observation) || [],
    medications: medicationsResult.entry?.map(entry => entry.resource as MedicationRequest) || []
  };
}
```

#### Option 2: Using _include and _revinclude

```typescript
async function getPatientWithRelatedData(patientId: string): Promise<{
  patient: Patient;
  relatedResources: any[];
}> {
  const bundle = await client.search<Patient>({
    resourceType: 'Patient',
    params: {
      _id: patientId,
      _include: [
        'Patient:organization', // Include the patient's organization
        'Patient:general-practitioner' // Include the patient's practitioners
      ],
      _revinclude: [
        'Observation:subject', // Include observations for this patient
        'MedicationRequest:subject' // Include medication requests for this patient
      ]
    }
  });
  
  const patient = bundle.entry?.find(entry => 
    entry.resource?.resourceType === 'Patient' && entry.resource?.id === patientId
  )?.resource as Patient;
  
  const relatedResources = bundle.entry
    ?.filter(entry => entry.resource?.id !== patientId)
    .map(entry => entry.resource) || [];
  
  return { patient, relatedResources };
}
```

#### Option 3: Using Batch or Transaction Requests

```typescript
async function getPatientDataBatch(patientId: string): Promise<Bundle> {
  const batchBundle: Bundle = {
    resourceType: 'Bundle',
    type: 'batch',
    entry: [
      {
        request: {
          method: 'GET',
          url: `Patient/${patientId}`
        }
      },
      {
        request: {
          method: 'GET',
          url: `Observation?subject=Patient/${patientId}&_sort=-date&_count=50`
        }
      },
      {
        request: {
          method: 'GET',
          url: `MedicationRequest?subject=Patient/${patientId}&_sort=-authored&_count=50`
        }
      }
    ]
  };
  
  return await client.request<Bundle>({
    method: 'POST',
    url: '/',
    data: batchBundle
  });
}
```

### Cross-Patient Queries and Filtering

When querying across multiple patients, use appropriate filtering to limit the result set:

```typescript
// Find all patients with a specific condition
async function getPatientsWithCondition(conditionCode: string): Promise<Patient[]> {
  // First, find the condition references
  const conditionBundle = await client.search<Bundle>({
    resourceType: 'Condition',
    params: {
      'code': conditionCode,
      '_elements': 'subject' // Only retrieve the patient reference
    }
  });
  
  // Extract patient references
  const patientReferences = conditionBundle.entry
    ?.map(entry => (entry.resource as any)?.subject?.reference)
    .filter(Boolean) || [];
  
  if (patientReferences.length === 0) {
    return [];
  }
  
  // Get unique patient IDs
  const uniquePatientIds = [...new Set(patientReferences.map(ref => ref.replace('Patient/', '')))];
  
  // Retrieve patients in batches to avoid URL length limitations
  const batchSize = 40;
  const patients: Patient[] = [];
  
  for (let i = 0; i < uniquePatientIds.length; i += batchSize) {
    const batchIds = uniquePatientIds.slice(i, i + batchSize);
    const patientBundle = await client.search<Patient>({
      resourceType: 'Patient',
      params: {
        '_id': batchIds.join(',')
      }
    });
    
    patients.push(...(patientBundle.entry?.map(entry => entry.resource as Patient) || []));
  }
  
  return patients;
}
```

## Performance Best Practices

### Pagination Strategies

Implement proper pagination to handle large result sets:

```typescript
import { AidboxClient } from '@aidbox/sdk-r4';
import { Bundle, Patient } from '@aidbox/sdk-r4/types';

// Paginated retrieval with automatic handling
async function getAllPatientsPaginated(): Promise<Patient[]> {
  const client = new AidboxClient({
    baseUrl: 'http://localhost:8888',
    auth: {
      type: 'basic',
      username: 'root',
      password: 'secret'
    }
  });

  const allPatients: Patient[] = [];
  let url: string | undefined = 'Patient?_count=100';
  
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
    url = nextLink?.url;
  }
  
  return allPatients;
}
```

### Using Cursor-Based Pagination

For very large datasets, cursor-based pagination is more efficient:

```typescript
async function getPatientsByCursor(count: number = 100): Promise<{
  patients: Patient[];
  nextCursor: string | null;
}> {
  const bundle = await client.search<Patient>({
    resourceType: 'Patient',
    params: {
      '_count': count.toString(),
      '_sort': 'id',
      '_page_token': currentCursor || undefined
    }
  });
  
  const patients = bundle.entry?.map(entry => entry.resource as Patient) || [];
  
  // Extract cursor from the next link
  const nextLink = bundle.link?.find(link => link.relation === 'next');
  const nextCursor = nextLink ? extractCursorFromLink(nextLink.url) : null;
  
  return { patients, nextCursor };
}

function extractCursorFromLink(url: string): string | null {
  const match = url.match(/_page_token=([^&]+)/);
  return match ? match[1] : null;
}
```

### Caching Strategies

Implement client-side caching to reduce server load:

```typescript
class CachedFhirClient {
  private client: AidboxClient;
  private cache: Map<string, { data: any; timestamp: number }> = new Map();
  private cacheTTL: number = 5 * 60 * 1000; // 5 minutes in milliseconds
  
  constructor(baseUrl: string, auth: any) {
    this.client = new AidboxClient({
      baseUrl,
      auth
    });
  }
  
  async read<T>(resourceType: string, id: string): Promise<T> {
    const cacheKey = `${resourceType}/${id}`;
    const cachedItem = this.cache.get(cacheKey);
    
    if (cachedItem && Date.now() - cachedItem.timestamp < this.cacheTTL) {
      return cachedItem.data as T;
    }
    
    const result = await this.client.read<T>({
      resourceType,
      id
    });
    
    this.cache.set(cacheKey, {
      data: result,
      timestamp: Date.now()
    });
    
    return result;
  }
  
  // Invalidate cache for a specific resource
  invalidateCache(resourceType: string, id: string): void {
    this.cache.delete(`${resourceType}/${id}`);
  }
  
  // Clear entire cache
  clearCache(): void {
    this.cache.clear();
  }
}

// Usage
const cachedClient = new CachedFhirClient('http://localhost:8888', {
  type: 'basic',
  username: 'root',
  password: 'secret'
});

async function getPatientWithCaching(id: string): Promise<Patient> {
  return await cachedClient.read<Patient>('Patient', id);
}
```

## Query Optimization for Specific Use Cases

### Patient Dashboard Optimization

When building a patient dashboard that displays multiple types of data:

```typescript
async function loadPatientDashboard(patientId: string): Promise<{
  demographics: Patient;
  recentObservations: Observation[];
  activeMedications: MedicationRequest[];
  recentEncounters: any[];
}> {
  // Use a batch request to get all data in one round-trip
  const batchBundle: Bundle = {
    resourceType: 'Bundle',
    type: 'batch',
    entry: [
      {
        request: {
          method: 'GET',
          url: `Patient/${patientId}`
        }
      },
      {
        request: {
          method: 'GET',
          url: `Observation?subject=Patient/${patientId}&_sort=-date&_count=10&_elements=id,code,valueQuantity,valueString,valueCodeableConcept,effectiveDateTime`
        }
      },
      {
        request: {
          method: 'GET',
          url: `MedicationRequest?subject=Patient/${patientId}&status=active&_sort=-authored&_count=10&_elements=id,medicationCodeableConcept,dosageInstruction,status`
        }
      },
      {
        request: {
          method: 'GET',
          url: `Encounter?subject=Patient/${patientId}&_sort=-date&_count=5&_elements=id,type,period,status,class`
        }
      }
    ]
  };
  
  const response = await client.request<Bundle>({
    method: 'POST',
    url: '/',
    data: batchBundle
  });
  
  // Extract results from the batch response
  const results = response.entry?.map(entry => entry.resource) || [];
  
  return {
    demographics: results[0] as Patient,
    recentObservations: ((results[1] as Bundle).entry || []).map(e => e.resource) as Observation[],
    activeMedications: ((results[2] as Bundle).entry || []).map(e => e.resource) as MedicationRequest[],
    recentEncounters: ((results[3] as Bundle).entry || []).map(e => e.resource) as any[]
  };
}
```

### Population Health Queries

For population health analytics that require aggregating data across many patients:

```typescript
// Find patients with high blood pressure in the last 30 days
async function findPatientsWithHighBP(): Promise<string[]> {
  const thirtyDaysAgo = new Date();
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
  const dateString = thirtyDaysAgo.toISOString().split('T')[0];
  
  const bundle = await client.search<Observation>({
    resourceType: 'Observation',
    params: {
      'code': 'http://loinc.org|8480-6', // Systolic BP
      'value-quantity': 'gt140',
      'date': `ge${dateString}`,
      '_elements': 'subject' // Only retrieve the patient reference
    }
  });
  
  // Extract unique patient IDs
  const patientIds = new Set<string>();
  bundle.entry?.forEach(entry => {
    const resource = entry.resource as Observation;
    if (resource.subject?.reference) {
      const patientId = resource.subject.reference.replace('Patient/', '');
      patientIds.add(patientId);
    }
  });
  
  return Array.from(patientIds);
}
```

## Monitoring and Optimizing Query Performance

### Tracking Query Performance

Implement query timing to identify slow queries:

```typescript
class MonitoredFhirClient {
  private client: AidboxClient;
  
  constructor(baseUrl: string, auth: any) {
    this.client = new AidboxClient({
      baseUrl,
      auth
    });
  }
  
  async search<T>(options: any): Promise<Bundle<T>> {
    const startTime = performance.now();
    
    try {
      const result = await this.client.search<T>(options);
      
      const endTime = performance.now();
      const duration = endTime - startTime;
      
      // Log or report query performance
      console.log(`Query ${options.resourceType} took ${duration.toFixed(2)}ms`, {
        resourceType: options.resourceType,
        params: options.params,
        resultCount: result.entry?.length || 0,
        duration
      });
      
      return result;
    } catch (error) {
      const endTime = performance.now();
      const duration = endTime - startTime;
      
      // Log failed query
      console.error(`Query ${options.resourceType} failed after ${duration.toFixed(2)}ms`, {
        resourceType: options.resourceType,
        params: options.params,
        error,
        duration
      });
      
      throw error;
    }
  }
}

// Usage
const monitoredClient = new MonitoredFhirClient('http://localhost:8888', {
  type: 'basic',
  username: 'root',
  password: 'secret'
});

async function searchWithMonitoring(): Promise<void> {
  await monitoredClient.search({
    resourceType: 'Patient',
    params: {
      'name': 'Smith'
    }
  });
}
```

### Server-Side Query Analysis

Aidbox provides tools to analyze query performance on the server side:

```sql
-- Example SQL query to find slow FHIR queries in Aidbox
SELECT 
  request_method,
  request_url,
  AVG(duration) as avg_duration,
  MAX(duration) as max_duration,
  COUNT(*) as count
FROM request_log
WHERE duration > 1000 -- queries taking more than 1 second
GROUP BY request_method, request_url
ORDER BY avg_duration DESC
LIMIT 10;
```

## Conclusion

Optimizing FHIR queries is essential for building high-performance healthcare applications. By implementing the techniques described in this guide, you can significantly improve the responsiveness and scalability of your FHIR-based systems.

Key takeaways:

1. Use direct ID-based access when retrieving single resources
2. Limit returned fields using `_elements` and summary views
3. Use batch requests to reduce round trips to the server
4. Implement proper pagination for large result sets
5. Consider caching frequently accessed resources
6. Monitor query performance to identify optimization opportunities

By following these best practices, you can ensure your FHIR applications deliver the performance required for modern healthcare systems.
