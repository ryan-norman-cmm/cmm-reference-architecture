# FHIR Interoperability Platform Integration Points

## Introduction

The FHIR Interoperability Platform is designed to seamlessly integrate with other systems and components within the healthcare ecosystem. This document outlines the key integration points, protocols, patterns, and interfaces that enable interoperability with the platform.

## API Integration Points

### RESTful FHIR API

The primary integration point is the RESTful FHIR API, which follows the HL7 FHIR specification for standardized healthcare data exchange.

**Key Characteristics:**
- Standard HTTP methods (GET, POST, PUT, DELETE)
- JSON and XML content formats
- OAuth 2.0 authentication
- SMART on FHIR authorization

```typescript
// Example: TypeScript client for RESTful FHIR API integration
import axios, { AxiosInstance } from 'axios';
import { Bundle, Patient, Resource } from 'fhir/r4';

export class FhirClient {
  private client: AxiosInstance;

  constructor(baseUrl: string, accessToken: string) {
    this.client = axios.create({
      baseURL: baseUrl,
      headers: {
        'Content-Type': 'application/fhir+json',
        'Accept': 'application/fhir+json',
        'Authorization': `Bearer ${accessToken}`
      }
    });
  }

  async search<T extends Resource>(resourceType: string, params: Record<string, string>): Promise<Bundle> {
    const response = await this.client.get<Bundle>(`/${resourceType}`, { params });
    return response.data;
  }

  async read<T extends Resource>(resourceType: string, id: string): Promise<T> {
    const response = await this.client.get<T>(`/${resourceType}/${id}`);
    return response.data;
  }

  // Additional methods for create, update, delete, etc.
}
```

### GraphQL API

The platform provides a GraphQL API for more efficient and flexible data retrieval, particularly useful for frontend applications and mobile clients.

**Key Characteristics:**
- Single endpoint for all queries
- Precise data retrieval (only requested fields)
- Reduced network overhead
- Strongly typed schema

```typescript
// Example: TypeScript client for GraphQL API integration
import { GraphQLClient } from 'graphql-request';

export class FhirGraphQLClient {
  private client: GraphQLClient;

  constructor(endpoint: string, accessToken: string) {
    this.client = new GraphQLClient(endpoint, {
      headers: {
        authorization: `Bearer ${accessToken}`
      }
    });
  }

  async getPatientWithObservations(patientId: string) {
    const query = `
      query GetPatientWithObservations($id: ID!) {
        Patient(id: $id) {
          id
          name { given family }
          birthDate
          Observation {
            id
            code { coding { display } }
            valueQuantity { value unit }
            effectiveDateTime
          }
        }
      }
    `;

    return await this.client.request(query, { id: patientId });
  }
}
```

## Event-Based Integration

### FHIR Subscription Service

The platform provides a subscription service for real-time notifications when resources are created, updated, or deleted.

**Supported Channels:**
- REST Hooks
- WebSockets
- Message Queue
- Email

```typescript
// Example: Setting up a REST Hook subscription
import { Subscription } from 'fhir/r4';
import { FhirClient } from './fhir-client';

async function createSubscription(fhirClient: FhirClient, criteria: string, endpoint: string) {
  const subscription: Subscription = {
    resourceType: 'Subscription',
    status: 'requested',
    reason: 'Clinical data monitoring',
    criteria,
    channel: {
      type: 'rest-hook',
      endpoint,
      payload: 'application/fhir+json'
    }
  };

  return await fhirClient.create<Subscription>(subscription);
}

// Usage example
const subscription = await createSubscription(
  fhirClient,
  'Observation?code=http://loinc.org|8867-4',
  'https://example.org/fhir-webhook'
);
```

### Event Broker Integration

The platform integrates with the CMM Event Broker for broader event-driven architecture patterns.

**Key Characteristics:**
- Publish-subscribe pattern
- Schema-validated events
- Exactly-once delivery semantics
- Dead letter queues for error handling

```typescript
// Example: Publishing FHIR events to the Event Broker
import { KafkaProducer } from '@cmm/event-broker-client';
import { Resource } from 'fhir/r4';

export class FhirEventPublisher {
  constructor(private producer: KafkaProducer) {}

  async publishResourceCreated(resource: Resource): Promise<void> {
    await this.producer.produce({
      topic: `fhir.${resource.resourceType.toLowerCase()}.created`,
      key: resource.id,
      value: {
        resourceType: resource.resourceType,
        id: resource.id,
        timestamp: new Date().toISOString(),
        resource
      },
      headers: {
        'event-type': 'resource-created',
        'resource-type': resource.resourceType
      }
    });
  }

  // Similar methods for update, delete, etc.
}
```

## Bulk Data Integration

### FHIR Bulk Data API

The platform implements the FHIR Bulk Data API for efficient transfer of large datasets.

**Key Operations:**
- System-level export
- Group-level export
- Patient-level export

```typescript
// Example: Client for Bulk Data API integration
import axios from 'axios';

export class BulkDataClient {
  constructor(private baseUrl: string, private accessToken: string) {}

  async startExport(params: Record<string, string> = {}): Promise<string> {
    const response = await axios.get(`${this.baseUrl}/$export`, {
      params,
      headers: {
        'Accept': 'application/fhir+json',
        'Prefer': 'respond-async',
        'Authorization': `Bearer ${this.accessToken}`
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

  async checkExportStatus(statusUrl: string): Promise<'in-progress' | 'complete' | 'error'> {
    const response = await axios.get(statusUrl, {
      headers: {
        'Authorization': `Bearer ${this.accessToken}`
      }
    });

    if (response.status === 202) return 'in-progress';
    if (response.status === 200) return 'complete';
    return 'error';
  }

  // Additional methods for downloading output files, etc.
}
```

## Integration with CMM Platform Components

### Workflow Orchestration Engine Integration

The FHIR Interoperability Platform integrates with the Workflow Orchestration Engine to enable complex healthcare workflows.

**Integration Patterns:**
- FHIR resources as workflow inputs and outputs
- FHIR Task resources for workflow tracking
- FHIR PlanDefinition resources for workflow definitions

```typescript
// Example: Initiating a workflow from a FHIR resource change
import { WorkflowClient } from '@cmm/workflow-engine-client';
import { Resource } from 'fhir/r4';

export class FhirWorkflowIntegration {
  constructor(private workflowClient: WorkflowClient) {}

  async triggerReferralWorkflow(referral: Resource): Promise<string> {
    // Start a workflow instance with the referral as input
    const workflowInstance = await this.workflowClient.startWorkflow({
      workflowName: 'patient-referral-process',
      workflowVersion: '1.0',
      input: {
        referralResource: referral,
        patientId: this.extractPatientId(referral),
        priority: this.extractPriority(referral)
      },
      correlationId: `referral-${referral.id}`
    });

    return workflowInstance.id;
  }

  private extractPatientId(referral: Resource): string {
    // Implementation details
    return 'patient-id';
  }

  private extractPriority(referral: Resource): string {
    // Implementation details
    return 'routine';
  }
}
```

### Federated Graph API Integration

The platform integrates with the Federated Graph API to provide a unified view of healthcare data across multiple systems.

**Integration Patterns:**
- FHIR resources as graph nodes
- FHIR references as graph edges
- GraphQL resolvers for FHIR resources

```typescript
// Example: FHIR resolver for the Federated Graph API
import { FhirClient } from './fhir-client';

export const fhirResolvers = {
  Query: {
    Patient: async (_: any, { id }: { id: string }, { dataSources }: any) => {
      const fhirClient = dataSources.fhirAPI as FhirClient;
      return await fhirClient.read('Patient', id);
    },
    searchPatients: async (_: any, { name }: { name: string }, { dataSources }: any) => {
      const fhirClient = dataSources.fhirAPI as FhirClient;
      const bundle = await fhirClient.search('Patient', { name });
      return bundle.entry?.map(entry => entry.resource) || [];
    }
  },
  Patient: {
    observations: async (patient: any, _: any, { dataSources }: any) => {
      const fhirClient = dataSources.fhirAPI as FhirClient;
      const bundle = await fhirClient.search('Observation', { 
        patient: `Patient/${patient.id}` 
      });
      return bundle.entry?.map(entry => entry.resource) || [];
    }
  }
};
```

### API Marketplace Integration

The platform exposes FHIR APIs through the API Marketplace for discovery and consumption by authorized applications.

**Integration Patterns:**
- API registration and documentation
- API access management
- Usage monitoring and analytics

```typescript
// Example: Registering FHIR APIs in the API Marketplace
import { ApiRegistrationClient } from '@cmm/api-marketplace-client';

export async function registerFhirApis(client: ApiRegistrationClient) {
  await client.registerApi({
    name: 'FHIR Patient API',
    description: 'API for managing patient demographics and information',
    version: '1.0.0',
    baseUrl: '/fhir/r4/Patient',
    documentation: 'https://docs.example.org/fhir-apis/patient',
    endpoints: [
      {
        path: '/',
        method: 'GET',
        description: 'Search for patients',
        parameters: [
          { name: 'name', type: 'string', description: 'Patient name' },
          { name: 'identifier', type: 'string', description: 'Patient identifier' }
          // Additional parameters
        ]
      },
      {
        path: '/{id}',
        method: 'GET',
        description: 'Get patient by ID',
        parameters: [
          { name: 'id', type: 'string', description: 'Patient ID', required: true }
        ]
      }
      // Additional endpoints
    ],
    tags: ['fhir', 'patient', 'healthcare'],
    category: 'Healthcare'
  });

  // Register additional FHIR resource APIs
}
```

## External System Integration

### EHR System Integration

The platform integrates with external Electronic Health Record (EHR) systems through standard FHIR interfaces.

**Integration Patterns:**
- SMART on FHIR for EHR app integration
- CDS Hooks for clinical decision support
- Bulk Data for population health

```typescript
// Example: SMART on FHIR app launch sequence
import { oauth2 } from 'oauth4webapi';

export async function initiateSmartOnFhirLaunch(ehrLaunchUrl: string, clientId: string, redirectUri: string) {
  // Construct the SMART launch URL
  const launchUrl = new URL(ehrLaunchUrl);
  launchUrl.searchParams.append('response_type', 'code');
  launchUrl.searchParams.append('client_id', clientId);
  launchUrl.searchParams.append('redirect_uri', redirectUri);
  launchUrl.searchParams.append('scope', 'launch patient/*.read');
  launchUrl.searchParams.append('state', generateRandomState());
  launchUrl.searchParams.append('aud', 'https://ehr.example.org/fhir');
  
  // Redirect the user to the EHR authorization server
  window.location.href = launchUrl.toString();
}

function generateRandomState(): string {
  return Math.random().toString(36).substring(2, 15);
}
```

### Health Information Exchange (HIE) Integration

The platform integrates with regional and national Health Information Exchanges for broader data sharing.

**Integration Patterns:**
- IHE profiles (XDS, XCPD, XCA)
- FHIR-based exchange protocols
- Secure Direct messaging

```typescript
// Example: Querying an HIE using IHE XCPD profile over FHIR
import axios from 'axios';
import { Bundle, Parameters } from 'fhir/r4';

export async function queryPatientDemographics(hieEndpoint: string, demographics: any, accessToken: string) {
  // Create FHIR Parameters resource for patient demographics query
  const parameters: Parameters = {
    resourceType: 'Parameters',
    parameter: [
      {
        name: 'familyName',
        valueString: demographics.familyName
      },
      {
        name: 'givenName',
        valueString: demographics.givenName
      },
      {
        name: 'birthDate',
        valueDate: demographics.birthDate
      },
      {
        name: 'gender',
        valueCode: demographics.gender
      }
      // Additional demographics parameters
    ]
  };

  // Send the query to the HIE
  const response = await axios.post<Bundle>(
    `${hieEndpoint}/$ihe-pix`,
    parameters,
    {
      headers: {
        'Content-Type': 'application/fhir+json',
        'Accept': 'application/fhir+json',
        'Authorization': `Bearer ${accessToken}`
      }
    }
  );

  return response.data;
}
```

## Related Resources

- [FHIR Interoperability Platform Overview](../01-getting-started/overview.md)
- [Core APIs](core-apis.md)
- [Data Model](data-model.md)
- [GraphQL Integration](../03-advanced-patterns/graphql-integration.md)
- [Event Processing](../03-advanced-patterns/event-processing.md)
- [Bulk Data Operations](../03-advanced-patterns/bulk-data-operations.md)
