# FHIR Interoperability Platform Quick Start

This guide provides a comprehensive, step-by-step process to help you start building with the FHIR Interoperability Platform. You'll go from setup to creating your first FHIR application in about 30 minutes.

## Prerequisites

- **Environment Access**: Valid credentials for the CMM platform (dev/staging/production)
- **FHIR Credentials**: Aidbox username/password or API key (request from your administrator if needed)
- **Network Access**: Connectivity to FHIR Interoperability Platform endpoints
- **Basic Knowledge**: Familiarity with REST APIs and JSON (FHIR-specific knowledge is helpful but not required)

## Step 1: Set Up Your Development Environment

### Option A: Run Aidbox Locally (Recommended for Development)

#### 1. Install Docker
```bash
# Verify installation after
docker --version
```

#### 2. Generate Your Aidbox Developer License
- Sign up at [Aidbox Portal](https://aidbox.app/ui/portal#/signup)
- Navigate to **Licenses** → **New license** → **Dev** → **Self-Hosted** → **Create**
- Save your license key safely - you'll need it in the next step

#### 3. Configure Your Environment

Create a project directory and initialize configuration files:

```bash
mkdir fhir-project && cd fhir-project
```

Create `docker-compose.yml`:

```yaml
version: '3.7'
services:
  aidbox:
    image: healthsamurai/aidboxone:latest
    ports:
      - "8888:8080"
    env_file:
      - .env
    volumes:
      - ./config:/var/config
      - ./additional-profiles:/var/additional-profiles
```

Create `.env` file with your configuration:

```env
# Required settings
AIDBOX_LICENSE=<your-license-key>
AIDBOX_PROJECT_ID=fhir-quickstart
AIDBOX_ADMIN_PASSWORD=<strong-password>

# Optional performance settings
PGPORT=5432
PGHOSTPORT=5437
PGUSER=postgres
PGPASSWORD=postgres
PGDATABASE=aidbox

# Enable FHIR R4 support
AIDBOX_FHIR_VERSION=4.0.1

# Enable US Core profiles (recommended for CoverMyMeds projects)
AIDBOX_USCORE_ENABLED=true
```

#### 4. Start the FHIR Server

Launch the containers and wait for initialization:

```bash
docker-compose up
```

The server will be available at http://localhost:8888. Log in with:
- Username: `admin`
- Password: `<the password you set in .env>`

#### 5. Verify Server Status

Navigate to http://localhost:8888/health to confirm the server is running correctly. You should see a JSON response with `"status": "pass"`.

### Option B: Connect to Existing FHIR Environment

If you're connecting to a pre-deployed FHIR environment, request the following information from your administrator:

- **FHIR Server URL**: The base URL of the FHIR server
- **Authentication Credentials**: API key or username/password
- **API Documentation**: Any CoverMyMeds-specific API documentation
- **Available Resources**: List of available FHIR resources and custom profiles

## Step 2: Install Client Libraries

Choose the appropriate client library for your language:

### TypeScript/JavaScript (recommended)

```bash
# Create a new project if needed
mkdir fhir-client && cd fhir-client
npm init -y

# Install the Aidbox SDK for FHIR R4
npm install @aidbox/sdk-r4 
```

### Python

```bash
pip install fhirclient
```

### Java

Add to your Maven `pom.xml`:

```xml
<dependency>
  <groupId>ca.uhn.hapi.fhir</groupId>
  <artifactId>hapi-fhir-client</artifactId>
  <version>6.2.0</version>
</dependency>
```

## Step 3: Connect and Authenticate

Create a new file called `client.ts` (or appropriate for your language):

```typescript
import { AidboxClient } from '@aidbox/sdk-r4';

// Create a client instance with your configuration 
export const client = new AidboxClient({
  // For local development
  url: 'http://localhost:8888',
  auth: {
    username: 'admin',
    password: 'your-password', // Use the password from your .env file
  },
  
  // OR for production/staging environment
  // url: 'https://fhir-api.covermymeds.com',
  // auth: {
  //   type: 'bearer',
  //   token: 'YOUR_API_KEY',
  // },
});

// Test connection
async function testConnection() {
  try {
    const response = await client.request({
      method: 'GET',
      url: '/health',
    });
    console.log('Connection test:', response);
    return response;
  } catch (error) {
    console.error('Connection failed:', error);
    throw error;
  }
}

// Execute the test if this file is run directly
if (require.main === module) {
  testConnection().catch(console.error);
}
```

Test your connection:

```bash
npx ts-node client.ts
```

## Step 4: Create Your First FHIR Resources

Create a file called `basic-operations.ts`:

```typescript
import { client } from './client';

// Example function to create a patient
async function createPatient() {
  try {
    // Create a patient resource
    const patient = await client.fhirCreate('Patient', {
      resourceType: 'Patient',
      identifier: [
        {
          system: 'http://covermymeds.com/fhir/identifiers/mrn',
          value: 'MRN12345',
        },
      ],
      name: [
        {
          use: 'official',
          family: 'Smith',
          given: ['John', 'Jacob'],
        },
      ],
      gender: 'male',
      birthDate: '1987-02-20',
      address: [
        {
          use: 'home',
          line: ['123 Main St'],
          city: 'Columbus',
          state: 'OH',
          postalCode: '43215',
        },
      ],
      telecom: [
        {
          system: 'phone',
          value: '614-555-1234',
          use: 'home',
        },
        {
          system: 'email',
          value: 'john.smith@example.com',
        },
      ],
    });
    
    console.log('Created patient:', patient);
    console.log('Patient ID:', patient.id);
    
    return patient;
  } catch (error) {
    console.error('Error creating patient:', error);
    throw error;
  }
}

// Function to read a patient by ID
async function readPatient(id: string) {
  try {
    const patient = await client.fhirRead('Patient', id);
    console.log('Retrieved patient:', patient);
    return patient;
  } catch (error) {
    console.error(`Error reading patient ${id}:`, error);
    throw error;
  }
}

// Function to search for patients
async function searchPatients(params: any) {
  try {
    const results = await client.fhirSearch('Patient', params);
    console.log(`Found ${results.total} patients`);
    console.log('Search results:', results);
    return results;
  } catch (error) {
    console.error('Error searching patients:', error);
    throw error;
  }
}

// Function to update a patient
async function updatePatient(id: string, updates: any) {
  try {
    // First, get the current patient
    const currentPatient = await client.fhirRead('Patient', id);
    
    // Merge the updates with the current patient
    const updatedPatient = { ...currentPatient, ...updates };
    
    // Save the updated patient
    const result = await client.fhirUpdate('Patient', id, updatedPatient);
    console.log('Updated patient:', result);
    return result;
  } catch (error) {
    console.error(`Error updating patient ${id}:`, error);
    throw error;
  }
}

// Execute all operations in sequence if this file is run directly
async function runDemo() {
  try {
    // Create a new patient
    const patient = await createPatient();
    
    // Read the patient we just created
    await readPatient(patient.id);
    
    // Search for patients with last name Smith
    await searchPatients({ family: 'Smith' });
    
    // Update the patient with new information
    await updatePatient(patient.id, {
      telecom: [
        ...patient.telecom,
        {
          system: 'phone',
          value: '614-555-5678',
          use: 'work',
        }
      ]
    });
    
    console.log('Demo completed successfully!');
  } catch (error) {
    console.error('Demo failed:', error);
  }
}

if (require.main === module) {
  runDemo().catch(console.error);
}
```

Run the demo:

```bash
npx ts-node basic-operations.ts
```

## Step 5: Explore Healthcare-Specific Workflows

Let's create a more advanced example with a medication prescription workflow in `clinical-workflow.ts`:

```typescript
import { client } from './client';

// Create a medication request (prescription)
async function createMedicationRequest(patientId: string) {
  try {
    const medicationRequest = await client.fhirCreate('MedicationRequest', {
      resourceType: 'MedicationRequest',
      status: 'active',
      intent: 'order',
      medicationCodeableConcept: {
        coding: [
          {
            system: 'http://www.nlm.nih.gov/research/umls/rxnorm',
            code: '1000006',
            display: 'Atorvastatin 20 MG Oral Tablet'
          }
        ],
        text: 'Atorvastatin (Lipitor) 20mg tablets'
      },
      subject: {
        reference: `Patient/${patientId}`
      },
      authoredOn: new Date().toISOString(),
      requester: {
        reference: 'Practitioner/example-prescriber',
        display: 'Dr. Sarah Johnson'
      },
      dosageInstruction: [
        {
          text: 'Take one tablet by mouth once daily',
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
      ],
      dispenseRequest: {
        numberOfRepeatsAllowed: 3,
        quantity: {
          value: 30,
          unit: 'tablet',
          system: 'http://terminology.hl7.org/CodeSystem/v3-orderableDrugForm',
          code: 'TAB'
        },
        expectedSupplyDuration: {
          value: 30,
          unit: 'days',
          system: 'http://unitsofmeasure.org',
          code: 'd'
        }
      }
    });
    
    console.log('Created medication request:', medicationRequest);
    return medicationRequest;
  } catch (error) {
    console.error('Error creating medication request:', error);
    throw error;
  }
}

// Create a patient and a medication request
async function runClinicalWorkflow() {
  try {
    // Create a patient first
    const patient = await client.fhirCreate('Patient', {
      resourceType: 'Patient',
      name: [{ family: 'Johnson', given: ['Robert'] }],
      gender: 'male',
      birthDate: '1975-05-17'
    });
    console.log('Created patient with ID:', patient.id);
    
    // Create a medication request for this patient
    const medicationRequest = await createMedicationRequest(patient.id);
    console.log('Created medication request with ID:', medicationRequest.id);
    
    // Search for all medication requests for this patient
    const results = await client.fhirSearch('MedicationRequest', {
      patient: patient.id
    });
    
    console.log(`Found ${results.total} medication requests for patient ${patient.id}`);
    return { patient, medicationRequest, results };
  } catch (error) {
    console.error('Clinical workflow failed:', error);
    throw error;
  }
}

if (require.main === module) {
  runClinicalWorkflow().catch(console.error);
}
```

Run the clinical workflow:

```bash
npx ts-node clinical-workflow.ts
```

## Step 6: Validate and Troubleshoot Your Setup

### Verify Resource Creation

1. Open the Aidbox Admin UI at http://localhost:8888
2. Log in with your admin credentials
3. Navigate to **Resources** → **Patient**
4. Verify that your patient resources appear in the list
5. Click on a patient to view its details

### Common Issues and Solutions

| Issue | Solution |
|-------|----------|
| Connection refused | Check that Aidbox is running (`docker ps`) and that you're using the correct URL |
| Authentication failed | Verify username/password or API key in your client configuration |
| Resource validation errors | Check the response body for specific validation errors; ensure required fields are provided |
| CORS errors | For browser-based apps, ensure CORS is configured correctly in Aidbox |
| Performance issues | Consider using bulk operations for large data sets and implement proper pagination |

### Debugging Tips

- Enable debug logging in the client:
  ```typescript
  const client = new AidboxClient({
    // ...your config
    debug: true
  });
  ```
- Use the Aidbox UI to examine logs and resource state
- Use the `/$validate` endpoint to test resources before creating them

## Next Steps

### Explore Advanced FHIR Capabilities
- [FHIR Search Parameters and Advanced Queries](../02-core-functionality/core-apis.md)
- [FHIR Profiles and Validation](../02-core-functionality/data-model.md)
- [SMART on FHIR App Development](../03-advanced-patterns/advanced-use-cases.md)

## Integration with Other Core Components

The FHIR Interoperability Platform is designed to work seamlessly with other core components of the CoverMyMeds architecture. Here are detailed integration patterns for each component:

### Event Broker Integration

The FHIR platform can publish and subscribe to healthcare events through the Event Broker:

```typescript
// fhir-event-integration.ts
import { client } from './client';
import { Kafka } from 'kafkajs';

// Configure Kafka client for Event-Driven Architecture
const kafka = new Kafka({
  clientId: 'fhir-service',
  brokers: ['event-architecture:9092'], // Replace with your broker addresses
  // Add authentication if needed
});

const producer = kafka.producer();
const consumer = kafka.consumer({ groupId: 'fhir-service-group' });

// Function to publish FHIR resource changes to Kafka
async function publishResourceChange(resource: any, changeType: 'created' | 'updated' | 'deleted') {
  try {
    await producer.connect();
    
    // Create a standardized event based on the resource type
    const topic = `healthcare.${resource.resourceType.toLowerCase()}.${changeType}`;
    
    // Create an event that follows the standardized structure
    const event = {
      eventId: `evt-${Date.now()}`,
      eventType: `${resource.resourceType}.${changeType}`,
      timestamp: new Date().toISOString(),
      data: resource,
      metadata: {
        source: 'fhir-platform',
        version: '1.0',
        resourceType: resource.resourceType,
        resourceId: resource.id
      }
    };
    
    // Send the event
    await producer.send({
      topic,
      messages: [
        {
          // Use resource ID as the key for consistent partitioning
          key: resource.id,
          value: JSON.stringify(event),
          headers: {
            'event-type': Buffer.from(event.eventType),
            'resource-type': Buffer.from(resource.resourceType),
            'source': Buffer.from('fhir-platform')
          }
        }
      ]
    });
    
    console.log(`Published ${resource.resourceType} change to ${topic}`);
    await producer.disconnect();
  } catch (error) {
    console.error('Error publishing resource change:', error);
    throw error;
  }
}

// Function to consume medication events from Kafka and update FHIR
async function consumeMedicationEvents() {
  try {
    await consumer.connect();
    
    // Subscribe to relevant medication events
    await consumer.subscribe({
      topics: ['healthcare.medication.created', 'healthcare.medication.updated'],
      fromBeginning: false
    });
    
    await consumer.run({
      eachMessage: async ({ topic, partition, message }) => {
        try {
          const eventString = message.value?.toString();
          if (!eventString) return;
          
          const event = JSON.parse(eventString);
          console.log(`Processing ${event.eventType} event`);
          
          // Extract the medication data from the event
          const medicationData = event.data;
          
          // Update or create the corresponding FHIR resource
          if (event.eventType === 'Medication.created') {
            await client.fhirCreate('Medication', medicationData);
            console.log(`Created Medication resource from event: ${medicationData.id}`);
          } else if (event.eventType === 'Medication.updated' && medicationData.id) {
            await client.fhirUpdate('Medication', medicationData.id, medicationData);
            console.log(`Updated Medication resource from event: ${medicationData.id}`);
          }
        } catch (error) {
          console.error('Error processing medication event:', error);
          // Consider a dead-letter queue for failed events
        }
      }
    });
    
    console.log('Medication event consumer is running...');
    // Keep the consumer running until the process is terminated
  } catch (error) {
    console.error('Error in medication event consumer:', error);
    throw error;
  }
}

// Example: Hook into FHIR API operations to publish events
async function createPatientWithEvent() {
  try {
    // Create the patient in FHIR
    const patient = await client.fhirCreate('Patient', {
      resourceType: 'Patient',
      name: [{ family: 'Thompson', given: ['Emma'] }],
      gender: 'female',
      birthDate: '1982-11-30'
    });
    
    // Publish the event to Kafka
    await publishResourceChange(patient, 'created');
    
    return patient;
  } catch (error) {
    console.error('Error in create patient with event:', error);
    throw error;
  }
}

// Export functions
export {
  publishResourceChange,
  consumeMedicationEvents,
  createPatientWithEvent
};

// Run demonstration if executed directly
if (require.main === module) {
  (async () => {
    // Demonstrate publishing a resource change
    const patient = await createPatientWithEvent();
    console.log(`Published creation event for patient: ${patient.id}`);
    
    // Start consuming medication events (will run continuously)
    await consumeMedicationEvents();
  })().catch(console.error);
}
```

Run this integration example:

```bash
npx ts-node fhir-event-integration.ts
```

### Federated Graph API Integration

Expose your FHIR resources through the GraphQL API:

```typescript
// fhir-graphql-integration.ts
import { client } from './client';

// This file demonstrates how FHIR resources can integrate with the Federated Graph API

// 1. Create sample FHIR resources that will be exposed via GraphQL
async function createSampleData() {
  // Create a patient
  const patient = await client.fhirCreate('Patient', {
    resourceType: 'Patient',
    name: [{ family: 'Anderson', given: ['Thomas'] }],
    gender: 'male',
    birthDate: '1970-04-25',
    address: [{
      use: 'home',
      line: ['534 Brookside Way'],
      city: 'Indianapolis',
      state: 'IN',
      postalCode: '46202'
    }]
  });
  
  // Create a practitioner
  const practitioner = await client.fhirCreate('Practitioner', {
    resourceType: 'Practitioner',
    name: [{ family: 'Reynolds', given: ['Sarah'], prefix: ['Dr.'] }],
    gender: 'female',
    qualification: [{
      code: {
        coding: [{
          system: 'http://terminology.hl7.org/CodeSystem/v2-0360',
          code: 'MD',
          display: 'Doctor of Medicine'
        }]
      }
    }]
  });
  
  // Create a medication request linked to both the patient and practitioner
  const medicationRequest = await client.fhirCreate('MedicationRequest', {
    resourceType: 'MedicationRequest',
    status: 'active',
    intent: 'order',
    medicationCodeableConcept: {
      coding: [{
        system: 'http://www.nlm.nih.gov/research/umls/rxnorm',
        code: '1049502',
        display: 'Metformin Hydrochloride 500 MG'
      }],
      text: 'Metformin 500mg tablets'
    },
    subject: {
      reference: `Patient/${patient.id}`,
      display: `${patient.name[0].given[0]} ${patient.name[0].family}`
    },
    requester: {
      reference: `Practitioner/${practitioner.id}`,
      display: `Dr. ${practitioner.name[0].family}`
    },
    authoredOn: new Date().toISOString(),
    dosageInstruction: [{
      text: 'Take one tablet twice daily with meals'
    }]
  });
  
  return { patient, practitioner, medicationRequest };
}

// 2. GraphQL integration - the Federated Graph API can now expose these resources
console.log(`
FHIR resources are now available for GraphQL queries via the Federated Graph API.

Example GraphQL query to access this data:

query {
  patient(id: "PATIENT_ID") {
    id
    name {
      given
      family
    }
    gender
    birthDate
    medicationRequests {
      id
      status
      medicationCodeableConcept {
        text
        coding {
          display
        }
      }
      requester {
        reference
        display
      }
    }
  }
}

To execute this query, use the Apollo Client configuration from the Federated Graph API documentation.
`);

// Run the example
if (require.main === module) {
  createSampleData()
    .then(({ patient, medicationRequest }) => {
      console.log('\nCreated sample FHIR resources for GraphQL integration:');
      console.log(`- Patient ID: ${patient.id}`);
      console.log(`- MedicationRequest ID: ${medicationRequest.id}`);
      console.log('\nThese resources are now available through the Federated Graph API.');
    })
    .catch(console.error);
}
```

Run this GraphQL integration example:

```bash
npx ts-node fhir-graphql-integration.ts
```

### API Marketplace Integration

Register your FHIR APIs in the API Marketplace by creating an API specification:

```typescript
// Generate an OpenAPI specification for your FHIR API
// fhir-openapi-generator.ts
import * as fs from 'fs';
import { client } from './client';

async function generateFhirOpenApiSpec() {
  // Fetch capability statement to understand available resources
  const capabilityStatement = await client.request({
    method: 'GET',
    url: '/fhir/metadata',
  });
  
  // Extract supported resources
  const supportedResources = capabilityStatement.rest[0].resource.map(r => r.type);
  
  // Create a basic OpenAPI structure
  const openApiSpec = {
    openapi: '3.0.0',
    info: {
      title: 'CoverMyMeds FHIR API',
      version: '1.0.0',
      description: 'FHIR R4 API for healthcare data interoperability',
      contact: {
        name: 'API Support',
        email: 'api-support@covermymeds.com',
        url: 'https://developers.covermymeds.com'
      }
    },
    servers: [
      {
        url: 'https://fhir-api.covermymeds.com/fhir',
        description: 'Production API'
      },
      {
        url: 'https://fhir-api-staging.covermymeds.com/fhir',
        description: 'Staging API'
      }
    ],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT'
        }
      },
      schemas: {
        // Add basic schemas for common FHIR resources
        OperationOutcome: {
          type: 'object',
          properties: {
            resourceType: { type: 'string', enum: ['OperationOutcome'] },
            issue: {
              type: 'array',
              items: {
                type: 'object',
                properties: {
                  severity: { type: 'string', enum: ['fatal', 'error', 'warning', 'information'] },
                  code: { type: 'string' },
                  diagnostics: { type: 'string' }
                }
              }
            }
          }
        }
      }
    },
    security: [
      {
        bearerAuth: []
      }
    ],
    paths: {}
  };
  
  // Generate paths for supported resources
  supportedResources.forEach(resource => {
    // Add type-level endpoints (search, create)
    openApiSpec.paths[`/${resource}`] = {
      get: {
        summary: `Search for ${resource} resources`,
        description: `Search for ${resource} resources matching the given criteria`,
        operationId: `search${resource}`,
        parameters: [
          {
            name: '_count',
            in: 'query',
            description: 'Number of results per page',
            schema: { type: 'integer' }
          },
          {
            name: '_sort',
            in: 'query',
            description: 'Sort order',
            schema: { type: 'string' }
          }
          // Additional resource-specific parameters would be added here
        ],
        responses: {
          '200': {
            description: 'Successful search',
            content: {
              'application/fhir+json': {
                schema: {
                  type: 'object',
                  properties: {
                    resourceType: { type: 'string', enum: ['Bundle'] },
                    type: { type: 'string', enum: ['searchset'] },
                    total: { type: 'integer' },
                    link: { type: 'array', items: { type: 'object' } },
                    entry: { type: 'array', items: { type: 'object' } }
                  }
                }
              }
            }
          },
          '400': {
            description: 'Bad request',
            content: {
              'application/fhir+json': {
                schema: { $ref: '#/components/schemas/OperationOutcome' }
              }
            }
          },
          '401': {
            description: 'Unauthorized',
            content: {
              'application/fhir+json': {
                schema: { $ref: '#/components/schemas/OperationOutcome' }
              }
            }
          }
        }
      },
      post: {
        summary: `Create a new ${resource} resource`,
        description: `Create a new ${resource} resource`,
        operationId: `create${resource}`,
        requestBody: {
          required: true,
          content: {
            'application/fhir+json': {
              schema: {
                type: 'object',
                properties: {
                  resourceType: { type: 'string', enum: [resource] }
                  // Resource-specific properties would be detailed here
                }
              }
            }
          }
        },
        responses: {
          '201': {
            description: 'Resource created successfully',
            headers: {
              Location: {
                schema: { type: 'string' },
                description: 'URL of the newly created resource'
              }
            },
            content: {
              'application/fhir+json': {
                schema: {
                  type: 'object',
                  properties: {
                    resourceType: { type: 'string', enum: [resource] },
                    id: { type: 'string' }
                  }
                }
              }
            }
          },
          '400': {
            description: 'Invalid resource',
            content: {
              'application/fhir+json': {
                schema: { $ref: '#/components/schemas/OperationOutcome' }
              }
            }
          }
        }
      }
    };
    
    // Add instance-level endpoints (read, update, delete)
    openApiSpec.paths[`/${resource}/{id}`] = {
      parameters: [
        {
          name: 'id',
          in: 'path',
          required: true,
          description: `The ID of the ${resource}`,
          schema: { type: 'string' }
        }
      ],
      get: {
        summary: `Read a ${resource} by ID`,
        description: `Read a ${resource} resource by its ID`,
        operationId: `read${resource}`,
        responses: {
          '200': {
            description: 'Successful read',
            content: {
              'application/fhir+json': {
                schema: {
                  type: 'object',
                  properties: {
                    resourceType: { type: 'string', enum: [resource] },
                    id: { type: 'string' }
                  }
                }
              }
            }
          },
          '404': {
            description: 'Resource not found',
            content: {
              'application/fhir+json': {
                schema: { $ref: '#/components/schemas/OperationOutcome' }
              }
            }
          }
        }
      },
      put: {
        summary: `Update a ${resource} by ID`,
        description: `Update a ${resource} resource by its ID`,
        operationId: `update${resource}`,
        requestBody: {
          required: true,
          content: {
            'application/fhir+json': {
              schema: {
                type: 'object',
                properties: {
                  resourceType: { type: 'string', enum: [resource] },
                  id: { type: 'string' }
                }
              }
            }
          }
        },
        responses: {
          '200': {
            description: 'Resource updated successfully',
            content: {
              'application/fhir+json': {
                schema: {
                  type: 'object',
                  properties: {
                    resourceType: { type: 'string', enum: [resource] },
                    id: { type: 'string' }
                  }
                }
              }
            }
          },
          '400': {
            description: 'Invalid resource',
            content: {
              'application/fhir+json': {
                schema: { $ref: '#/components/schemas/OperationOutcome' }
              }
            }
          },
          '404': {
            description: 'Resource not found',
            content: {
              'application/fhir+json': {
                schema: { $ref: '#/components/schemas/OperationOutcome' }
              }
            }
          }
        }
      },
      delete: {
        summary: `Delete a ${resource} by ID`,
        description: `Delete a ${resource} resource by its ID`,
        operationId: `delete${resource}`,
        responses: {
          '200': {
            description: 'Resource deleted successfully'
          },
          '404': {
            description: 'Resource not found',
            content: {
              'application/fhir+json': {
                schema: { $ref: '#/components/schemas/OperationOutcome' }
              }
            }
          }
        }
      }
    };
  });
  
  // Write the OpenAPI specification to file
  fs.writeFileSync('fhir-api-spec.json', JSON.stringify(openApiSpec, null, 2));
  console.log('OpenAPI specification generated: fhir-api-spec.json');
  console.log('This file can be used to register your FHIR API in the API Marketplace.');
  
  return openApiSpec;
}

// Run the generator
if (require.main === module) {
  generateFhirOpenApiSpec().catch(console.error);
}
```

Generate the OpenAPI specification:

```bash
npx ts-node fhir-openapi-generator.ts
```

### Using These Integrations

To effectively integrate the FHIR Interoperability Platform with other core components:

1. **Event-Driven Architecture**:
   - Configure FHIR resource hooks to publish events when resources are created, updated, or deleted
   - Implement consumers to process events from other systems and update FHIR resources
   - Use the Event-Driven Architecture for reliable, asynchronous communication between healthcare services
   - Leverage event sourcing patterns for maintaining healthcare data history

2. **GraphQL Federation**:
   - Ensure your FHIR resources follow the expected schema for the Federated Graph API
   - Implement entity resolvers that can fetch FHIR resources by reference
   - Use consistent naming and relationship patterns for optimal federation

3. **API Discovery**:
   - Register your FHIR API endpoints in the API Marketplace
   - Include comprehensive documentation, authentication requirements, and rate limits
   - Update the OpenAPI specification when new resources or capabilities are added

These integration patterns enable you to build cohesive, interoperable healthcare applications that leverage the full capabilities of the CoverMyMeds platform.

### CoverMyMeds-Specific Resources
- [FHIR Implementation Guide for CoverMyMeds](../02-core-functionality/core-apis.md#covermymeds-specific-apis)
- [Custom Resources for Prior Authorization](../02-core-functionality/data-model.md#covermymeds-specific-resources)
- [Healthcare Integration Patterns](../03-advanced-patterns/advanced-use-cases.md)

## Related Resources
- [HL7 FHIR Documentation](https://hl7.org/fhir/)
- [Aidbox Platform Documentation](https://docs.aidbox.app/overview)
- [FHIR Interoperability Platform Overview](./overview.md)
- [FHIR Interoperability Platform Architecture](./architecture.md)
- [FHIR Interoperability Platform Key Concepts](./key-concepts.md)