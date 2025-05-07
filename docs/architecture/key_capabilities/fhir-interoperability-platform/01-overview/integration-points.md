# FHIR Interoperability Platform Integration Points

## Introduction
This document outlines the integration points between the FHIR Interoperability Platform and other components of the CoverMyMeds Technology Platform, as well as external systems. The FHIR Platform serves as the central data repository for standardized healthcare information, enabling seamless data exchange across the healthcare ecosystem. Understanding these integration points is essential for architects, developers, and operators working with the platform.

## Core Component Integrations

### Event-Driven Architecture Integration

The FHIR Interoperability Platform integrates with the Event-Driven Architecture to support event-driven healthcare data exchange:

#### Key Integration Points:
- **FHIR Resource Change Notifications**: Publishing events when FHIR resources are created, updated, or deleted
- **FHIR Subscription Implementation**: Enabling real-time notifications through the FHIR Subscription resource
- **Asynchronous Operations**: Supporting long-running FHIR operations through events
- **Data Consistency**: Maintaining data consistency across services using event sourcing patterns

#### Integration Pattern:
```typescript
// FHIR Resource Change Event Publisher
import { AidboxClient } from '@aidbox/sdk-r4';
import { Kafka } from 'kafkajs';
import { SchemaRegistry } from '@kafkajs/confluent-schema-registry';

// Initialize FHIR client
const fhirClient = new AidboxClient({
  url: 'https://fhir-api.cmm.internal',
  auth: {
    type: 'basic',
    username: process.env.FHIR_USERNAME,
    password: process.env.FHIR_PASSWORD,
  },
});

// Initialize Kafka producer
const kafka = new Kafka({
  clientId: 'fhir-event-publisher',
  brokers: ['event-broker.cmm.internal:9092'],
  // Auth and SSL configuration
});

const producer = kafka.producer();

// Initialize Schema Registry client
const registry = new SchemaRegistry({
  host: 'https://schema-registry.cmm.internal',
  // Auth configuration
});

// Configure FHIR resource hook for Patient resources
async function configureFhirHooks() {
  await fhirClient.request({
    method: 'POST',
    url: '/$configure-hooks',
    data: {
      resourceType: 'Parameters',
      parameter: [
        {
          name: 'hook',
          resource: {
            resourceType: 'HookDefinition',
            id: 'patient-resource-hook',
            name: 'patient-resource-hook',
            description: 'Hook to publish events for Patient resource changes',
            on: [
              {
                resourceType: 'Patient',
                event: ['create', 'update', 'delete']
              }
            ],
            handler: {
              resourceType: 'FhirPathHandler',
              expression: "%trigger.resourceType = 'Patient'"
            }
          }
        }
      ]
    }
  });
}

// FHIR hook handler function - deployed as a serverless function in production
export async function handleFhirResourceChange(req, res) {
  try {
    const triggerEvent = req.body.trigger;
    const resource = req.body.resource;
    const operation = triggerEvent.event;
    const resourceType = resource.resourceType;
    
    // Connect to Kafka if not already connected
    if (!producer.isConnected) {
      await producer.connect();
    }
    
    // Create standardized event format
    const event = {
      metadata: {
        eventId: uuidv4(),
        eventType: `fhir.${resourceType.toLowerCase()}.${operation}`,
        eventSource: 'fhir-platform',
        timestamp: new Date().toISOString(),
        version: '1.0'
      },
      data: resource
    };
    
    // Get schema ID for the resource type
    const schemaId = await registry.getLatestSchemaId(`fhir-${resourceType.toLowerCase()}-value`);
    
    // Encode event using schema
    const encodedValue = await registry.encode(schemaId, event);
    
    // Send event to Kafka
    await producer.send({
      topic: `healthcare.${resourceType.toLowerCase()}.${operation}`,
      messages: [
        {
          // Use resource ID as the key for partitioning
          key: resource.id,
          value: encodedValue,
          headers: {
            'resource-type': resourceType,
            'operation': operation,
            'source': 'fhir-platform'
          }
        }
      ]
    });
    
    // Return success response
    res.status(200).json({ success: true });
  } catch (error) {
    console.error('Error publishing FHIR resource change event:', error);
    res.status(500).json({ error: error.message });
  }
}

// Example: Subscribe to FHIR resource change events
export async function consumeFhirEvents() {
  const consumer = kafka.consumer({ 
    groupId: 'fhir-event-consumer'
  });
  
  await consumer.connect();
  
  // Subscribe to FHIR resource topics
  await consumer.subscribe({
    topics: [
      'healthcare.patient.create',
      'healthcare.patient.update',
      'healthcare.medicationrequest.create',
      'healthcare.medicationrequest.update'
    ],
    fromBeginning: false
  });
  
  await consumer.run({
    eachMessage: async ({ topic, partition, message }) => {
      try {
        // Decode event
        const decodedEvent = await registry.decode(message.value);
        
        console.log(`Received ${decodedEvent.metadata.eventType} event for ${decodedEvent.data.resourceType}/${decodedEvent.data.id}`);
        
        // Process the event (e.g., update cache, trigger workflows)
        await processEvent(decodedEvent);
      } catch (error) {
        console.error('Error processing FHIR event:', error);
      }
    }
  });
}
```

### Federated Graph API Integration

The FHIR Interoperability Platform integrates with the Federated Graph API to provide a GraphQL interface for healthcare data:

#### Key Integration Points:
- **FHIR-to-GraphQL Mapping**: Exposing FHIR resources as GraphQL types
- **GraphQL Federation**: Contributing to the federated GraphQL schema
- **Cross-Resource Resolvers**: Supporting complex queries across resource types
- **Nested Query Optimization**: Optimizing nested GraphQL queries to FHIR

#### Integration Pattern:
```typescript
// FHIR GraphQL Subgraph Service
import { ApolloServer } from '@apollo/server';
import { buildSubgraphSchema } from '@apollo/subgraph';
import { gql } from 'graphql-tag';
import { AidboxClient } from '@aidbox/sdk-r4';

// Initialize FHIR client
const fhirClient = new AidboxClient({
  url: 'https://fhir-api.cmm.internal',
  auth: {
    type: 'basic',
    username: process.env.FHIR_USERNAME,
    password: process.env.FHIR_PASSWORD,
  },
});

// Define GraphQL schema with Federation directives
const typeDefs = gql`
  extend schema @link(url: "https://specs.apollo.dev/federation/v2.0", import: ["@key", "@external", "@requires", "@provides"])

  type Query {
    patient(id: ID!): Patient
    patients(filter: PatientFilter): [Patient]
    medicationRequest(id: ID!): MedicationRequest
    medicationRequests(filter: MedicationRequestFilter): [MedicationRequest]
  }

  type Patient @key(fields: "id") {
    id: ID!
    identifier: [Identifier]
    name: [HumanName]
    gender: String
    birthDate: String
    address: [Address]
    telecom: [ContactPoint]
    active: Boolean
    generalPractitioner: [Reference]
    managingOrganization: Reference
    medicationRequests: [MedicationRequest]
  }

  type MedicationRequest @key(fields: "id") {
    id: ID!
    status: String
    intent: String
    medicationCodeableConcept: CodeableConcept
    subject: Reference
    requester: Reference
    authoredOn: String
    dosageInstruction: [Dosage]
  }

  # Additional type definitions for FHIR structures
  type Identifier {
    system: String
    value: String
  }

  # ... Additional type definitions
  
  input PatientFilter {
    name: String
    identifier: IdentifierFilter
    birthDate: String
    gender: String
  }
  
  input IdentifierFilter {
    system: String
    value: String
  }
  
  input MedicationRequestFilter {
    status: String
    patientId: ID
    medicationCode: String
  }
`;

// Define resolvers
const resolvers = {
  Query: {
    // Resolver for individual patient
    patient: async (_, { id }) => {
      try {
        const patient = await fhirClient.fhirRead('Patient', id);
        return patient;
      } catch (error) {
        console.error(`Error fetching patient ${id}:`, error);
        throw error;
      }
    },
    
    // Resolver for patient search
    patients: async (_, { filter }) => {
      try {
        // Convert GraphQL filter to FHIR search parameters
        const searchParams = convertPatientFilterToFhirParams(filter);
        
        const results = await fhirClient.fhirSearch('Patient', searchParams);
        
        // Map FHIR Bundle to array of Patient resources
        return results.entry ? results.entry.map(entry => entry.resource) : [];
      } catch (error) {
        console.error('Error searching patients:', error);
        throw error;
      }
    },
    
    // Resolver for individual medication request
    medicationRequest: async (_, { id }) => {
      try {
        const medicationRequest = await fhirClient.fhirRead('MedicationRequest', id);
        return medicationRequest;
      } catch (error) {
        console.error(`Error fetching medication request ${id}:`, error);
        throw error;
      }
    },
    
    // Resolver for medication request search
    medicationRequests: async (_, { filter }) => {
      try {
        // Convert GraphQL filter to FHIR search parameters
        const searchParams = convertMedicationRequestFilterToFhirParams(filter);
        
        const results = await fhirClient.fhirSearch('MedicationRequest', searchParams);
        
        // Map FHIR Bundle to array of MedicationRequest resources
        return results.entry ? results.entry.map(entry => entry.resource) : [];
      } catch (error) {
        console.error('Error searching medication requests:', error);
        throw error;
      }
    }
  },
  
  Patient: {
    // Resolver for patient's medication requests (nested query)
    medicationRequests: async (patient) => {
      try {
        // Search for medication requests with patient reference
        const results = await fhirClient.fhirSearch('MedicationRequest', {
          patient: patient.id
        });
        
        // Map FHIR Bundle to array of MedicationRequest resources
        return results.entry ? results.entry.map(entry => entry.resource) : [];
      } catch (error) {
        console.error(`Error fetching medication requests for patient ${patient.id}:`, error);
        return [];
      }
    },
    
    // Reference resolvers
    generalPractitioner: async (patient) => {
      // Resolve practitioner references if needed
      return patient.generalPractitioner || [];
    },
    
    // Entity resolver for Federation
    __resolveReference: async (reference) => {
      try {
        // Resolve Patient reference for Federation
        return await fhirClient.fhirRead('Patient', reference.id);
      } catch (error) {
        console.error(`Error resolving Patient reference ${reference.id}:`, error);
        return null;
      }
    }
  },
  
  MedicationRequest: {
    // Entity resolver for Federation
    __resolveReference: async (reference) => {
      try {
        // Resolve MedicationRequest reference for Federation
        return await fhirClient.fhirRead('MedicationRequest', reference.id);
      } catch (error) {
        console.error(`Error resolving MedicationRequest reference ${reference.id}:`, error);
        return null;
      }
    }
  }
};

// Helper functions
function convertPatientFilterToFhirParams(filter) {
  if (!filter) return {};
  
  const params = {};
  
  if (filter.name) {
    params.name = filter.name;
  }
  
  if (filter.identifier) {
    if (filter.identifier.system) {
      params['identifier-system'] = filter.identifier.system;
    }
    if (filter.identifier.value) {
      params['identifier-value'] = filter.identifier.value;
    }
  }
  
  if (filter.birthDate) {
    params.birthdate = filter.birthDate;
  }
  
  if (filter.gender) {
    params.gender = filter.gender;
  }
  
  return params;
}

function convertMedicationRequestFilterToFhirParams(filter) {
  if (!filter) return {};
  
  const params = {};
  
  if (filter.status) {
    params.status = filter.status;
  }
  
  if (filter.patientId) {
    params.patient = filter.patientId;
  }
  
  if (filter.medicationCode) {
    params['medication.code'] = filter.medicationCode;
  }
  
  return params;
}

// Create Apollo Server
const server = new ApolloServer({
  schema: buildSubgraphSchema({ typeDefs, resolvers }),
});

// Start the server (implementation varies by environment)
startApolloServer(server);
```

### API Marketplace Integration

The FHIR Interoperability Platform integrates with the API Marketplace to publish and manage FHIR APIs:

#### Key Integration Points:
- **FHIR API Registration**: Publishing FHIR API specifications to the marketplace
- **Access Control Management**: Managing access to FHIR resources
- **Usage Analytics**: Tracking usage of FHIR APIs
- **Developer Documentation**: Providing resources for FHIR API consumers

#### Integration Pattern:
```typescript
// FHIR API Marketplace Registration
import axios from 'axios';
import { AidboxClient } from '@aidbox/sdk-r4';

// Initialize FHIR client
const fhirClient = new AidboxClient({
  url: 'https://fhir-api.cmm.internal',
  auth: {
    type: 'basic',
    username: process.env.FHIR_USERNAME,
    password: process.env.FHIR_PASSWORD,
  },
});

// API Marketplace client
const marketplaceClient = axios.create({
  baseURL: 'https://api-marketplace.cmm.internal/api/v1',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${process.env.MARKETPLACE_API_KEY}`
  }
});

// Generate OpenAPI specification from FHIR CapabilityStatement
async function generateFhirOpenApiSpec() {
  try {
    // Fetch FHIR CapabilityStatement
    const capabilityStatement = await fhirClient.request({
      method: 'GET',
      url: '/metadata?_format=json',
    });
    
    // Extract supported resources and operations
    const supportedResources = capabilityStatement.rest[0].resource || [];
    
    // Create OpenAPI specification
    const openApiSpec = {
      openapi: '3.0.0',
      info: {
        title: 'CoverMyMeds FHIR API',
        version: capabilityStatement.version || '1.0.0',
        description: 'FHIR R4 API for healthcare data interoperability',
        contact: {
          name: 'CoverMyMeds API Support',
          email: 'api-support@covermymeds.com',
          url: 'https://developers.covermymeds.com'
        }
      },
      servers: [
        {
          url: 'https://fhir-api.cmm.internal/fhir',
          description: 'Production FHIR API'
        },
        {
          url: 'https://fhir-api-staging.cmm.internal/fhir',
          description: 'Staging FHIR API'
        }
      ],
      paths: {},
      components: {
        securitySchemes: {
          bearerAuth: {
            type: 'http',
            scheme: 'bearer'
          }
        },
        schemas: {
          OperationOutcome: {
            type: 'object',
            properties: {
              resourceType: { type: 'string', enum: ['OperationOutcome'] },
              issue: {
                type: 'array',
                items: {
                  type: 'object',
                  properties: {
                    severity: { type: 'string' },
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
      ]
    };
    
    // Add paths for each supported resource
    supportedResources.forEach(resource => {
      const resourceType = resource.type;
      
      // Type-level endpoints (search, create)
      openApiSpec.paths[`/${resourceType}`] = {
        get: {
          summary: `Search for ${resourceType} resources`,
          description: `Search for ${resourceType} resources matching the given criteria`,
          parameters: generateSearchParameters(resource),
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
              description: 'Invalid search parameters',
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
          summary: `Create a new ${resourceType} resource`,
          description: `Create a new ${resourceType} resource`,
          requestBody: {
            required: true,
            content: {
              'application/fhir+json': {
                schema: {
                  type: 'object',
                  properties: {
                    resourceType: { type: 'string', enum: [resourceType] }
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
                      resourceType: { type: 'string', enum: [resourceType] },
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
      
      // Instance-level endpoints (read, update, delete)
      openApiSpec.paths[`/${resourceType}/{id}`] = {
        parameters: [
          {
            name: 'id',
            in: 'path',
            required: true,
            description: `The ID of the ${resourceType} resource`,
            schema: { type: 'string' }
          }
        ],
        get: {
          summary: `Read a ${resourceType} resource by ID`,
          description: `Read a ${resourceType} resource by its ID`,
          responses: {
            '200': {
              description: 'Successful read',
              content: {
                'application/fhir+json': {
                  schema: {
                    type: 'object',
                    properties: {
                      resourceType: { type: 'string', enum: [resourceType] },
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
          summary: `Update a ${resourceType} resource by ID`,
          description: `Update a ${resourceType} resource by its ID`,
          requestBody: {
            required: true,
            content: {
              'application/fhir+json': {
                schema: {
                  type: 'object',
                  properties: {
                    resourceType: { type: 'string', enum: [resourceType] },
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
                      resourceType: { type: 'string', enum: [resourceType] },
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
          summary: `Delete a ${resourceType} resource by ID`,
          description: `Delete a ${resourceType} resource by its ID`,
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
    
    return openApiSpec;
  } catch (error) {
    console.error('Error generating OpenAPI specification:', error);
    throw error;
  }
}

// Helper function to generate search parameters
function generateSearchParameters(resource) {
  const parameters = [
    {
      name: '_count',
      in: 'query',
      description: 'Number of resources to return',
      schema: { type: 'integer' }
    },
    {
      name: '_sort',
      in: 'query',
      description: 'Sort order for results',
      schema: { type: 'string' }
    }
  ];
  
  // Add resource-specific search parameters
  if (resource.searchParam) {
    resource.searchParam.forEach(param => {
      parameters.push({
        name: param.name,
        in: 'query',
        description: param.documentation || `Search by ${param.name}`,
        schema: { type: 'string' }
      });
    });
  }
  
  return parameters;
}

// Register FHIR API with API Marketplace
async function registerFhirApi() {
  try {
    // Generate OpenAPI specification
    const openApiSpec = await generateFhirOpenApiSpec();
    
    // Register API with marketplace
    const response = await marketplaceClient.post('/apis', {
      name: 'FHIR R4 API',
      description: 'Healthcare data interoperability API based on HL7 FHIR R4 standard',
      category: 'healthcare',
      visibility: 'internal', // or 'external' if publicly available
      openApiSpec: openApiSpec
    });
    
    console.log('FHIR API registered successfully:', response.data);
    return response.data;
  } catch (error) {
    console.error('Error registering FHIR API with marketplace:', error);
    throw error;
  }
}
```

### Design System Integration

The FHIR Interoperability Platform integrates with the Design System to provide consistent UI components for healthcare data:

#### Key Integration Points:
- **FHIR Data Rendering Components**: UI components optimized for displaying FHIR resources
- **FHIR Form Components**: Components for editing and creating FHIR resources
- **Clinical Data Visualization**: Components for visualizing clinical data
- **Terminology Services Integration**: Components for terminology selection and display

#### Integration Pattern:
```typescript
// React component for rendering FHIR Patient data
import React, { useState, useEffect } from 'react';
import { FhirClient } from '@cmm/fhir-client';
import {
  PatientCard,
  DemographicsPanel,
  AddressDisplay,
  ContactPointList,
  LoadingSpinner,
  ErrorPanel
} from '@cmm/design-system';

const fhirClient = new FhirClient({
  baseUrl: 'https://fhir-api.cmm.internal',
  auth: {
    type: 'token',
    token: getAuthToken()
  }
});

// PatientProfile component
function PatientProfile({ patientId }) {
  const [patient, setPatient] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    async function fetchPatient() {
      try {
        setLoading(true);
        
        // Fetch patient data
        const patientData = await fhirClient.read('Patient', patientId);
        setPatient(patientData);
        setLoading(false);
      } catch (err) {
        setError(err.message);
        setLoading(false);
      }
    }

    fetchPatient();
  }, [patientId]);

  if (loading) {
    return <LoadingSpinner size="large" />;
  }

  if (error) {
    return <ErrorPanel message={`Error loading patient: ${error}`} />;
  }

  if (!patient) {
    return <ErrorPanel message="Patient not found" />;
  }

  return (
    <PatientCard patient={patient}>
      <DemographicsPanel patient={patient} />
      
      {patient.address && patient.address.length > 0 && (
        <section>
          <h3>Addresses</h3>
          {patient.address.map((address, index) => (
            <AddressDisplay key={index} address={address} />
          ))}
        </section>
      )}
      
      {patient.telecom && patient.telecom.length > 0 && (
        <section>
          <h3>Contact Information</h3>
          <ContactPointList contactPoints={patient.telecom} />
        </section>
      )}
    </PatientCard>
  );
}

// Form component for editing a FHIR Patient resource
function PatientForm({ patientId, onSave }) {
  const [patient, setPatient] = useState(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    async function fetchPatient() {
      try {
        setLoading(true);
        
        // Fetch patient data if editing an existing patient
        if (patientId) {
          const patientData = await fhirClient.read('Patient', patientId);
          setPatient(patientData);
        } else {
          // Initialize new patient
          setPatient({
            resourceType: 'Patient',
            active: true,
            name: [{ family: '', given: [''] }],
            telecom: [],
            address: []
          });
        }
        
        setLoading(false);
      } catch (err) {
        setError(err.message);
        setLoading(false);
      }
    }

    fetchPatient();
  }, [patientId]);

  const handleSubmit = async (event) => {
    event.preventDefault();
    
    try {
      setSaving(true);
      
      // Save patient resource
      let savedPatient;
      
      if (patientId) {
        // Update existing patient
        savedPatient = await fhirClient.update('Patient', patientId, patient);
      } else {
        // Create new patient
        savedPatient = await fhirClient.create('Patient', patient);
      }
      
      setSaving(false);
      
      // Call onSave callback with saved patient
      if (onSave) {
        onSave(savedPatient);
      }
    } catch (err) {
      setError(`Error saving patient: ${err.message}`);
      setSaving(false);
    }
  };

  // Update patient state with form changes
  const handleChange = (updatedPatient) => {
    setPatient(updatedPatient);
  };

  if (loading) {
    return <LoadingSpinner size="large" />;
  }

  if (error) {
    return <ErrorPanel message={error} />;
  }

  return (
    <form onSubmit={handleSubmit}>
      <PatientFormFields
        patient={patient}
        onChange={handleChange}
        disabled={saving}
      />
      
      <div className="form-buttons">
        <button type="submit" disabled={saving}>
          {saving ? 'Saving...' : 'Save Patient'}
        </button>
      </div>
    </form>
  );
}
```

## External System Integrations

### Electronic Health Record (EHR) Integration

The FHIR Interoperability Platform integrates with external EHR systems:

#### Key Integration Points:
- **Patient Data Synchronization**: Bidirectional exchange of patient demographics and clinical data
- **Document Exchange**: Sharing clinical documents and images
- **Order Management**: Handling medication orders and lab/diagnostic orders
- **Query/Response**: Supporting directed queries for patient information

#### Integration Pattern:
```typescript
// EHR Integration Service
import { AidboxClient } from '@aidbox/sdk-r4';
import { EhrClient } from './ehr-client';

// Initialize FHIR client
const fhirClient = new AidboxClient({
  url: 'https://fhir-api.cmm.internal',
  auth: {
    type: 'basic',
    username: process.env.FHIR_USERNAME,
    password: process.env.FHIR_PASSWORD,
  },
});

// Initialize EHR client (example implementation)
const ehrClient = new EhrClient({
  baseUrl: process.env.EHR_API_URL,
  clientId: process.env.EHR_CLIENT_ID,
  clientSecret: process.env.EHR_CLIENT_SECRET
});

// Sync patient from EHR to FHIR
async function syncPatientFromEhr(ehrPatientId) {
  try {
    // Fetch patient from EHR
    const ehrPatient = await ehrClient.getPatient(ehrPatientId);
    
    // Convert EHR patient to FHIR format
    const fhirPatient = convertEhrPatientToFhir(ehrPatient);
    
    // Check if patient already exists in FHIR
    const existingPatients = await fhirClient.fhirSearch('Patient', {
      identifier: `${fhirPatient.identifier[0].system}|${fhirPatient.identifier[0].value}`
    });
    
    let savedPatient;
    
    if (existingPatients.total > 0) {
      // Update existing patient
      const existingId = existingPatients.entry[0].resource.id;
      fhirPatient.id = existingId;
      savedPatient = await fhirClient.fhirUpdate('Patient', existingId, fhirPatient);
    } else {
      // Create new patient
      savedPatient = await fhirClient.fhirCreate('Patient', fhirPatient);
    }
    
    return savedPatient;
  } catch (error) {
    console.error(`Error syncing patient ${ehrPatientId} from EHR:`, error);
    throw error;
  }
}

// Push medication requests from FHIR to EHR
async function pushMedicationRequestsToEhr(patientId) {
  try {
    // Fetch medication requests for patient
    const medicationRequests = await fhirClient.fhirSearch('MedicationRequest', {
      patient: patientId,
      status: 'active'
    });
    
    const results = [];
    
    // Process each medication request
    for (const entry of medicationRequests.entry || []) {
      const medicationRequest = entry.resource;
      
      // Convert FHIR medication request to EHR format
      const ehrMedicationOrder = convertFhirMedicationRequestToEhr(medicationRequest);
      
      // Send to EHR
      const result = await ehrClient.createMedicationOrder(ehrMedicationOrder);
      
      // Update FHIR resource with EHR reference
      await fhirClient.fhirUpdate('MedicationRequest', medicationRequest.id, {
        ...medicationRequest,
        identifier: [
          ...(medicationRequest.identifier || []),
          {
            system: 'http://example.org/ehr/medication-orders',
            value: result.orderId
          }
        ]
      });
      
      results.push({
        fhirId: medicationRequest.id,
        ehrId: result.orderId,
        status: 'success'
      });
    }
    
    return results;
  } catch (error) {
    console.error(`Error pushing medication requests for patient ${patientId} to EHR:`, error);
    throw error;
  }
}

// Convert EHR patient to FHIR format
function convertEhrPatientToFhir(ehrPatient) {
  return {
    resourceType: 'Patient',
    identifier: [
      {
        system: 'http://example.org/ehr/patients',
        value: ehrPatient.patientId
      }
    ],
    active: ehrPatient.status === 'ACTIVE',
    name: [
      {
        family: ehrPatient.lastName,
        given: [ehrPatient.firstName, ehrPatient.middleName].filter(Boolean),
        prefix: ehrPatient.prefix ? [ehrPatient.prefix] : undefined
      }
    ],
    gender: mapEhrGenderToFhir(ehrPatient.gender),
    birthDate: ehrPatient.dateOfBirth,
    address: ehrPatient.addresses ? ehrPatient.addresses.map(mapEhrAddressToFhir) : undefined,
    telecom: mapEhrContactsToFhirTelecom(ehrPatient)
  };
}

// Convert FHIR medication request to EHR format
function convertFhirMedicationRequestToEhr(medicationRequest) {
  return {
    patientId: extractPatientIdFromReference(medicationRequest.subject.reference),
    providerId: extractProviderIdFromReference(medicationRequest.requester.reference),
    medicationDetails: {
      name: medicationRequest.medicationCodeableConcept?.text,
      code: medicationRequest.medicationCodeableConcept?.coding?.[0]?.code,
      codeSystem: medicationRequest.medicationCodeableConcept?.coding?.[0]?.system
    },
    dosageInstructions: medicationRequest.dosageInstruction?.[0]?.text,
    quantity: medicationRequest.dispenseRequest?.quantity?.value,
    quantityUnits: medicationRequest.dispenseRequest?.quantity?.unit,
    daysSupply: medicationRequest.dispenseRequest?.expectedSupplyDuration?.value,
    refills: medicationRequest.dispenseRequest?.numberOfRepeatsAllowed,
    startDate: medicationRequest.authoredOn,
    status: mapFhirStatusToEhr(medicationRequest.status)
  };
}

// Helper functions for mapping between FHIR and EHR formats
function mapEhrGenderToFhir(ehrGender) {
  const genderMap = {
    'M': 'male',
    'F': 'female',
    'U': 'unknown',
    'O': 'other'
  };
  return genderMap[ehrGender] || 'unknown';
}

function mapFhirStatusToEhr(fhirStatus) {
  const statusMap = {
    'active': 'ACTIVE',
    'completed': 'COMPLETED',
    'cancelled': 'CANCELLED',
    'stopped': 'DISCONTINUED'
  };
  return statusMap[fhirStatus] || 'PENDING';
}

function mapEhrAddressToFhir(ehrAddress) {
  return {
    use: ehrAddress.type.toLowerCase(),
    line: [ehrAddress.line1, ehrAddress.line2].filter(Boolean),
    city: ehrAddress.city,
    state: ehrAddress.state,
    postalCode: ehrAddress.zipCode,
    country: ehrAddress.country
  };
}

function mapEhrContactsToFhirTelecom(ehrPatient) {
  const telecom = [];
  
  if (ehrPatient.phoneNumbers) {
    ehrPatient.phoneNumbers.forEach(phone => {
      telecom.push({
        system: 'phone',
        value: phone.number,
        use: phone.type.toLowerCase()
      });
    });
  }
  
  if (ehrPatient.emails) {
    ehrPatient.emails.forEach(email => {
      telecom.push({
        system: 'email',
        value: email.address,
        use: email.type.toLowerCase()
      });
    });
  }
  
  return telecom;
}

function extractPatientIdFromReference(reference) {
  return reference.split('/')[1];
}

function extractProviderIdFromReference(reference) {
  return reference.split('/')[1];
}
```

### Pharmacy System Integration

The FHIR Interoperability Platform integrates with pharmacy systems for medication workflows:

#### Key Integration Points:
- **Prescription Exchange**: Converting FHIR MedicationRequest resources to pharmacy prescriptions
- **Fulfillment Tracking**: Monitoring prescription fill status
- **Medication Inventory**: Accessing pharmacy inventory data
- **Patient Medication History**: Retrieving consolidated medication history

#### Integration Pattern:
```typescript
// Pharmacy System Integration
import { AidboxClient } from '@aidbox/sdk-r4';
import { PharmacyClient } from './pharmacy-client';

// Initialize FHIR client
const fhirClient = new AidboxClient({
  url: 'https://fhir-api.cmm.internal',
  auth: {
    type: 'basic',
    username: process.env.FHIR_USERNAME,
    password: process.env.FHIR_PASSWORD,
  },
});

// Initialize Pharmacy client (example implementation)
const pharmacyClient = new PharmacyClient({
  baseUrl: process.env.PHARMACY_API_URL,
  apiKey: process.env.PHARMACY_API_KEY
});

// Send prescription to pharmacy
async function sendPrescriptionToPharmacy(medicationRequestId) {
  try {
    // Fetch medication request
    const medicationRequest = await fhirClient.fhirRead('MedicationRequest', medicationRequestId);
    
    // Validate medication request status
    if (medicationRequest.status !== 'active') {
      throw new Error(`Cannot send prescription with status: ${medicationRequest.status}`);
    }
    
    // Fetch patient information
    const patientId = medicationRequest.subject.reference.split('/')[1];
    const patient = await fhirClient.fhirRead('Patient', patientId);
    
    // Fetch prescriber information
    const prescriberId = medicationRequest.requester.reference.split('/')[1];
    const prescriber = await fhirClient.fhirRead('Practitioner', prescriberId);
    
    // Convert to pharmacy prescription format
    const prescription = {
      externalId: medicationRequestId,
      patient: {
        id: patient.identifier.find(id => id.system === 'http://covermymeds.com/fhir/identifiers/mrn')?.value,
        name: {
          first: patient.name[0].given[0],
          last: patient.name[0].family
        },
        dateOfBirth: patient.birthDate,
        gender: patient.gender.charAt(0).toUpperCase(),
        address: patient.address?.[0] ? {
          line1: patient.address[0].line[0],
          line2: patient.address[0].line.length > 1 ? patient.address[0].line[1] : undefined,
          city: patient.address[0].city,
          state: patient.address[0].state,
          zipCode: patient.address[0].postalCode
        } : undefined,
        phone: patient.telecom?.find(t => t.system === 'phone')?.value
      },
      prescriber: {
        npi: prescriber.identifier.find(id => id.system === 'http://hl7.org/fhir/sid/us-npi')?.value,
        name: {
          first: prescriber.name[0].given[0],
          last: prescriber.name[0].family
        }
      },
      medication: {
        ndc: extractNdcFromMedicationRequest(medicationRequest),
        name: medicationRequest.medicationCodeableConcept?.text,
        instructions: medicationRequest.dosageInstruction?.[0]?.text,
        daysSupply: medicationRequest.dispenseRequest?.expectedSupplyDuration?.value,
        quantity: medicationRequest.dispenseRequest?.quantity?.value,
        refills: medicationRequest.dispenseRequest?.numberOfRepeatsAllowed || 0
      },
      status: 'NEW'
    };
    
    // Send to pharmacy
    const pharmacyResponse = await pharmacyClient.createPrescription(prescription);
    
    // Update FHIR resource with pharmacy reference
    await fhirClient.fhirUpdate('MedicationRequest', medicationRequestId, {
      ...medicationRequest,
      identifier: [
        ...(medicationRequest.identifier || []),
        {
          system: 'http://covermymeds.com/fhir/pharmacy/prescriptions',
          value: pharmacyResponse.prescriptionId
        }
      ]
    });
    
    return {
      fhirId: medicationRequestId,
      pharmacyId: pharmacyResponse.prescriptionId,
      status: 'SENT_TO_PHARMACY'
    };
  } catch (error) {
    console.error(`Error sending prescription ${medicationRequestId} to pharmacy:`, error);
    throw error;
  }
}

// Check prescription status from pharmacy
async function checkPrescriptionStatus(medicationRequestId) {
  try {
    // Fetch medication request
    const medicationRequest = await fhirClient.fhirRead('MedicationRequest', medicationRequestId);
    
    // Find pharmacy prescription ID
    const pharmacyPrescriptionId = medicationRequest.identifier?.find(
      id => id.system === 'http://covermymeds.com/fhir/pharmacy/prescriptions'
    )?.value;
    
    if (!pharmacyPrescriptionId) {
      throw new Error('No pharmacy prescription ID found for this medication request');
    }
    
    // Check status from pharmacy
    const prescriptionStatus = await pharmacyClient.getPrescriptionStatus(pharmacyPrescriptionId);
    
    // Map pharmacy status to FHIR status
    const fhirStatus = mapPharmacyStatusToFhir(prescriptionStatus.status);
    
    // Update FHIR resource if status has changed
    if (medicationRequest.status !== fhirStatus) {
      await fhirClient.fhirUpdate('MedicationRequest', medicationRequestId, {
        ...medicationRequest,
        status: fhirStatus
      });
    }
    
    return {
      fhirId: medicationRequestId,
      pharmacyId: pharmacyPrescriptionId,
      status: prescriptionStatus.status,
      fhirStatus: fhirStatus,
      fillDetails: prescriptionStatus.fills,
      updatedAt: prescriptionStatus.updatedAt
    };
  } catch (error) {
    console.error(`Error checking prescription status for ${medicationRequestId}:`, error);
    throw error;
  }
}

// Helper functions
function extractNdcFromMedicationRequest(medicationRequest) {
  // Look for NDC code in coding
  const ndcCoding = medicationRequest.medicationCodeableConcept?.coding?.find(
    coding => coding.system === 'http://hl7.org/fhir/sid/ndc'
  );
  
  return ndcCoding?.code;
}

function mapPharmacyStatusToFhir(pharmacyStatus) {
  const statusMap = {
    'NEW': 'active',
    'IN_PROGRESS': 'active',
    'FILLED': 'completed',
    'PARTIALLY_FILLED': 'active',
    'ON_HOLD': 'on-hold',
    'CANCELLED': 'cancelled',
    'DENIED': 'stopped',
    'EXPIRED': 'entered-in-error'
  };
  
  return statusMap[pharmacyStatus] || 'unknown';
}
```

### Payer System Integration

The FHIR Interoperability Platform integrates with payer systems for claims and benefits:

#### Key Integration Points:
- **Prior Authorization**: Managing prior authorization requests and decisions
- **Coverage Eligibility**: Verifying patient insurance coverage
- **Claims Management**: Submitting and tracking healthcare claims
- **Benefits Information**: Retrieving patient benefit information

#### Integration Pattern:
```typescript
// Payer System Integration
import { AidboxClient } from '@aidbox/sdk-r4';
import { PayerClient } from './payer-client';

// Initialize FHIR client
const fhirClient = new AidboxClient({
  url: 'https://fhir-api.cmm.internal',
  auth: {
    type: 'basic',
    username: process.env.FHIR_USERNAME,
    password: process.env.FHIR_PASSWORD,
  },
});

// Initialize Payer client (example implementation)
const payerClient = new PayerClient({
  baseUrl: process.env.PAYER_API_URL,
  clientId: process.env.PAYER_CLIENT_ID,
  clientSecret: process.env.PAYER_CLIENT_SECRET
});

// Check coverage eligibility
async function checkCoverageEligibility(patientId, payerId, serviceType) {
  try {
    // Fetch patient information
    const patient = await fhirClient.fhirRead('Patient', patientId);
    
    // Find patient's insurance ID for this payer
    const coverage = await fhirClient.fhirSearch('Coverage', {
      patient: patientId,
      payor: `Organization/${payerId}`
    });
    
    if (!coverage.entry || coverage.entry.length === 0) {
      throw new Error(`No coverage found for patient ${patientId} with payer ${payerId}`);
    }
    
    const patientInsuranceId = coverage.entry[0].resource.identifier[0].value;
    
    // Create eligibility request
    const eligibilityRequest = {
      memberId: patientInsuranceId,
      memberInfo: {
        firstName: patient.name[0].given[0],
        lastName: patient.name[0].family,
        dateOfBirth: patient.birthDate,
        gender: patient.gender
      },
      serviceType: serviceType,
      serviceDate: new Date().toISOString().split('T')[0]
    };
    
    // Send to payer
    const eligibilityResponse = await payerClient.checkEligibility(eligibilityRequest);
    
    // Create FHIR CoverageEligibilityResponse
    const fhirEligibilityResponse = {
      resourceType: 'CoverageEligibilityResponse',
      status: 'active',
      purpose: ['benefits'],
      patient: {
        reference: `Patient/${patientId}`
      },
      created: new Date().toISOString(),
      request: {
        reference: `CoverageEligibilityRequest/${uuidv4()}`
      },
      insurer: {
        reference: `Organization/${payerId}`
      },
      insurance: [
        {
          coverage: {
            reference: `Coverage/${coverage.entry[0].resource.id}`
          },
          inforce: eligibilityResponse.coverageActive,
          item: mapBenefitsToFhirItems(eligibilityResponse.benefits, serviceType)
        }
      ],
      outcome: eligibilityResponse.coverageActive ? 'complete' : 'error'
    };
    
    // Save eligibility response
    const savedResponse = await fhirClient.fhirCreate('CoverageEligibilityResponse', fhirEligibilityResponse);
    
    return {
      eligibilityResponseId: savedResponse.id,
      coverageActive: eligibilityResponse.coverageActive,
      benefits: eligibilityResponse.benefits
    };
  } catch (error) {
    console.error(`Error checking eligibility for patient ${patientId}:`, error);
    throw error;
  }
}

// Submit prior authorization
async function submitPriorAuthorization(medicationRequestId) {
  try {
    // Fetch medication request
    const medicationRequest = await fhirClient.fhirRead('MedicationRequest', medicationRequestId);
    
    // Fetch patient
    const patientId = medicationRequest.subject.reference.split('/')[1];
    const patient = await fhirClient.fhirRead('Patient', patientId);
    
    // Fetch prescriber
    const prescriberId = medicationRequest.requester.reference.split('/')[1];
    const prescriber = await fhirClient.fhirRead('Practitioner', prescriberId);
    
    // Fetch coverage
    const coverage = await fhirClient.fhirSearch('Coverage', {
      patient: patientId,
      status: 'active'
    });
    
    if (!coverage.entry || coverage.entry.length === 0) {
      throw new Error(`No active coverage found for patient ${patientId}`);
    }
    
    const patientCoverage = coverage.entry[0].resource;
    const payerId = patientCoverage.payor[0].reference.split('/')[1];
    
    // Create prior authorization request
    const priorAuthRequest = {
      type: 'MEDICATION',
      urgent: false,
      patientInfo: {
        memberId: patientCoverage.identifier[0].value,
        firstName: patient.name[0].given[0],
        lastName: patient.name[0].family,
        dateOfBirth: patient.birthDate,
        gender: patient.gender
      },
      prescriberInfo: {
        npi: prescriber.identifier.find(id => id.system === 'http://hl7.org/fhir/sid/us-npi')?.value,
        firstName: prescriber.name[0].given[0],
        lastName: prescriber.name[0].family
      },
      medication: {
        name: medicationRequest.medicationCodeableConcept?.text,
        ndc: extractNdcFromMedicationRequest(medicationRequest),
        dosage: medicationRequest.dosageInstruction?.[0]?.text,
        quantity: medicationRequest.dispenseRequest?.quantity?.value,
        daysSupply: medicationRequest.dispenseRequest?.expectedSupplyDuration?.value,
        refills: medicationRequest.dispenseRequest?.numberOfRepeatsAllowed || 0
      },
      diagnosis: extractDiagnosisFromMedicationRequest(medicationRequest)
    };
    
    // Send to payer
    const authResponse = await payerClient.submitPriorAuthorization(priorAuthRequest);
    
    // Create FHIR Claim resource for tracking
    const fhirClaim = {
      resourceType: 'Claim',
      status: 'active',
      type: {
        coding: [
          {
            system: 'http://terminology.hl7.org/CodeSystem/claim-type',
            code: 'pharmacy',
            display: 'Pharmacy'
          }
        ]
      },
      use: 'preauthorization',
      patient: {
        reference: `Patient/${patientId}`
      },
      created: new Date().toISOString(),
      provider: {
        reference: `Practitioner/${prescriberId}`
      },
      priority: {
        coding: [
          {
            system: 'http://terminology.hl7.org/CodeSystem/processpriority',
            code: 'normal',
            display: 'Normal'
          }
        ]
      },
      insurance: [
        {
          sequence: 1,
          focal: true,
          coverage: {
            reference: `Coverage/${patientCoverage.id}`
          }
        }
      ],
      item: [
        {
          sequence: 1,
          productOrService: {
            coding: medicationRequest.medicationCodeableConcept?.coding || [],
            text: medicationRequest.medicationCodeableConcept?.text
          },
          quantity: {
            value: medicationRequest.dispenseRequest?.quantity?.value,
            unit: medicationRequest.dispenseRequest?.quantity?.unit
          }
        }
      ],
      identifier: [
        {
          system: 'http://covermymeds.com/fhir/payer/prior-auth',
          value: authResponse.authorizationId
        }
      ]
    };
    
    // Save claim
    const savedClaim = await fhirClient.fhirCreate('Claim', fhirClaim);
    
    // Link PA to medication request
    await fhirClient.fhirUpdate('MedicationRequest', medicationRequestId, {
      ...medicationRequest,
      insurance: [
        {
          reference: `Coverage/${patientCoverage.id}`
        }
      ],
      extension: [
        ...(medicationRequest.extension || []),
        {
          url: 'http://covermymeds.com/fhir/StructureDefinition/prior-authorization',
          valueReference: {
            reference: `Claim/${savedClaim.id}`
          }
        }
      ]
    });
    
    return {
      claimId: savedClaim.id,
      authorizationId: authResponse.authorizationId,
      status: authResponse.status,
      statusReason: authResponse.statusReason,
      decisionDate: authResponse.decisionDate
    };
  } catch (error) {
    console.error(`Error submitting prior authorization for medication request ${medicationRequestId}:`, error);
    throw error;
  }
}

// Helper functions
function mapBenefitsToFhirItems(benefits, serviceType) {
  return benefits.map((benefit, index) => ({
    category: {
      coding: [
        {
          system: 'http://terminology.hl7.org/CodeSystem/ex-benefitcategory',
          code: 'medical',
          display: 'Medical Care'
        }
      ]
    },
    name: {
      text: benefit.name
    },
    description: {
      text: benefit.description
    },
    network: {
      coding: [
        {
          system: 'http://terminology.hl7.org/CodeSystem/benefit-network',
          code: benefit.inNetwork ? 'in' : 'out',
          display: benefit.inNetwork ? 'In Network' : 'Out of Network'
        }
      ]
    },
    unit: {
      coding: [
        {
          system: 'http://terminology.hl7.org/CodeSystem/benefit-unit',
          code: benefit.type === 'percentage' ? 'percentage' : 'currency',
          display: benefit.type === 'percentage' ? 'Percentage' : 'Currency'
        }
      ]
    },
    term: {
      coding: [
        {
          system: 'http://terminology.hl7.org/CodeSystem/benefit-term',
          code: benefit.period || 'annual',
          display: (benefit.period || 'annual').charAt(0).toUpperCase() + (benefit.period || 'annual').slice(1)
        }
      ]
    },
    benefit: benefit.type === 'percentage' ? 
      { used: { value: benefit.value } } : 
      { money: { value: benefit.value, currency: 'USD' } }
  }));
}

function extractDiagnosisFromMedicationRequest(medicationRequest) {
  // Find diagnosis references in reasonReference
  if (medicationRequest.reasonReference) {
    return medicationRequest.reasonReference.map(ref => ({
      code: ref.display || ref.reference,
      codeSystem: 'reference'
    }));
  }
  
  // Or use reasonCode
  if (medicationRequest.reasonCode) {
    return medicationRequest.reasonCode.map(coding => ({
      code: coding.coding[0]?.code,
      codeSystem: coding.coding[0]?.system,
      description: coding.text
    }));
  }
  
  return [];
}
```

## Related Resources
- [FHIR Interoperability Platform Overview](./overview.md)
- [FHIR Core APIs](../02-core-functionality/core-apis.md)
- [FHIR Data Model](../02-core-functionality/data-model.md)
- [Event-Driven Architecture Integration Points](../../event-driven-architecture/01-overview/integration-points.md)
- [Federated Graph API Integration Guide](../../federated-graph-api/02-core-functionality/integration-patterns.md)
- [API Marketplace Registration Process](../../api-marketplace/02-core-functionality/api-registration.md)