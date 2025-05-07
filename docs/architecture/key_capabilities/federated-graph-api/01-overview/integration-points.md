# Federated Graph API Integration Points

## Introduction
This document outlines the integration points between the Federated Graph API and other components of the CoverMyMeds Technology Platform, as well as external systems. The Federated Graph API serves as the unified data access layer for healthcare applications, enabling consistent and performant data retrieval across multiple domains. Understanding these integration points is essential for architects, developers, and operators working with the platform.

## Core Component Integrations

### FHIR Interoperability Platform Integration

The Federated Graph API integrates with the FHIR Interoperability Platform to provide GraphQL access to healthcare data:

#### Key Integration Points:
- **FHIR-to-GraphQL Mapping**: Converting FHIR resources to GraphQL types and resolvers
- **Resource Federation**: Including FHIR resources in the federated schema
- **Complex Query Resolution**: Supporting complex queries across FHIR and non-FHIR data
- **Performance Optimization**: Implementing efficient data loading patterns for FHIR resources

#### Integration Pattern:
```typescript
// FHIR Subgraph Service for Federated GraphQL
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
    patientById(id: ID!): Patient
    patientByIdentifier(system: String!, value: String!): Patient
    searchPatients(name: String, birthDate: String): [Patient]
  }

  type Patient @key(fields: "id") {
    id: ID!
    identifier: [Identifier]
    name: [HumanName]
    gender: String
    birthDate: String
    address: [Address]
    telecom: [ContactPoint]
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
  }

  # FHIR type definitions
  type Identifier {
    system: String
    value: String
  }

  type HumanName {
    family: String
    given: [String]
    prefix: [String]
    use: String
  }

  type Address {
    line: [String]
    city: String
    state: String
    postalCode: String
    country: String
    use: String
  }

  type ContactPoint {
    system: String
    value: String
    use: String
  }

  type CodeableConcept {
    coding: [Coding]
    text: String
  }

  type Coding {
    system: String
    code: String
    display: String
  }

  type Reference {
    reference: String
    display: String
  }
`;

// Define resolvers for the schema
const resolvers = {
  Query: {
    patientById: async (_, { id }) => {
      try {
        const patient = await fhirClient.request({
          method: 'GET',
          url: `/Patient/${id}`
        });
        return patient;
      } catch (error) {
        console.error(`Error fetching patient ${id}:`, error);
        throw error;
      }
    },
    
    patientByIdentifier: async (_, { system, value }) => {
      try {
        const searchResults = await fhirClient.request({
          method: 'GET',
          url: '/Patient',
          params: {
            identifier: `${system}|${value}`
          }
        });
        
        if (searchResults.entry && searchResults.entry.length > 0) {
          return searchResults.entry[0].resource;
        }
        return null;
      } catch (error) {
        console.error(`Error fetching patient by identifier:`, error);
        throw error;
      }
    },
    
    searchPatients: async (_, { name, birthDate }) => {
      try {
        const params = {};
        if (name) params.name = name;
        if (birthDate) params.birthdate = birthDate;
        
        const searchResults = await fhirClient.request({
          method: 'GET',
          url: '/Patient',
          params
        });
        
        if (searchResults.entry && searchResults.entry.length > 0) {
          return searchResults.entry.map(entry => entry.resource);
        }
        return [];
      } catch (error) {
        console.error('Error searching patients:', error);
        throw error;
      }
    }
  },
  
  Patient: {
    medicationRequests: async (patient) => {
      try {
        const searchResults = await fhirClient.request({
          method: 'GET',
          url: '/MedicationRequest',
          params: {
            subject: `Patient/${patient.id}`
          }
        });
        
        if (searchResults.entry && searchResults.entry.length > 0) {
          return searchResults.entry.map(entry => entry.resource);
        }
        return [];
      } catch (error) {
        console.error(`Error fetching medication requests for patient ${patient.id}:`, error);
        return [];
      }
    },
    
    // Entity resolver for Federation
    __resolveReference: async (reference) => {
      try {
        const patient = await fhirClient.request({
          method: 'GET',
          url: `/Patient/${reference.id}`
        });
        return patient;
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
        const medicationRequest = await fhirClient.request({
          method: 'GET',
          url: `/MedicationRequest/${reference.id}`
        });
        return medicationRequest;
      } catch (error) {
        console.error(`Error resolving MedicationRequest reference ${reference.id}:`, error);
        return null;
      }
    }
  }
};

// Create Apollo Server with Federation schema
const server = new ApolloServer({
  schema: buildSubgraphSchema({ typeDefs, resolvers }),
});
```

### Event-Driven Architecture Integration

The Federated Graph API integrates with the Event-Driven Architecture to enable real-time data capabilities:

#### Key Integration Points:
- **GraphQL Subscriptions**: Implementing real-time GraphQL subscriptions using event streams
- **Cache Invalidation**: Managing GraphQL cache invalidation based on event notifications
- **Event-Driven Resolvers**: Supporting resolvers that consume events from the Event-Driven Architecture
- **Event Sourcing**: Leveraging event sourcing patterns for data consistency
- **Operational Events**: Publishing GraphQL operational events for monitoring and analytics

#### Integration Pattern:
```typescript
// GraphQL Subscription Service using Event Broker
import { Kafka } from 'kafkajs';
import { PubSub } from 'graphql-subscriptions';
import { SchemaRegistry } from '@kafkajs/confluent-schema-registry';

// Initialize PubSub for GraphQL subscriptions
const pubsub = new PubSub();

// Initialize Kafka client for Event-Driven Architecture
const kafka = new Kafka({
  clientId: 'graphql-subscription-service',
  brokers: ['event-architecture.cmm.internal:9092'],
  // Auth and SSL configuration
});

const consumer = kafka.consumer({ groupId: 'graphql-subscription-service' });
const registry = new SchemaRegistry({ 
  host: 'https://schema-registry.cmm.internal' 
});

// Initialize subscription handler
async function initSubscriptionHandler() {
  await consumer.connect();
  
  // Subscribe to relevant topics
  await consumer.subscribe({ 
    topics: [
      'fhir.patient',
      'fhir.medicationrequest',
      'fhir.observation',
      'healthcare.priorauth.status'
    ],
    fromBeginning: false 
  });
  
  await consumer.run({
    eachMessage: async ({ topic, partition, message }) => {
      try {
        // Decode event with schema registry
        const decodedEvent = await registry.decode(message.value);
        const payload = decodedEvent.payload;
        
        // Extract event metadata
        const resourceType = message.headers['resource-type']?.toString();
        const operation = message.headers['operation']?.toString();
        
        // Map to GraphQL subscription event
        const subscriptionKey = `${resourceType}_${operation}`.toUpperCase();
        
        // Publish to GraphQL subscription system
        pubsub.publish(subscriptionKey, {
          [subscriptionKey]: {
            id: decodedEvent.metadata.resourceId || message.key.toString(),
            data: payload,
            operation: operation,
            timestamp: decodedEvent.metadata.timestamp
          }
        });
        
        // Handle cache invalidation
        invalidateCache(resourceType, payload.id);
      } catch (error) {
        console.error('Error processing event for GraphQL subscription:', error);
      }
    }
  });
}

// Configure GraphQL schema with subscription support
const typeDefs = gql`
  type Subscription {
    patientUpdated: PatientSubscriptionPayload
    medicationRequestCreated: MedicationRequestSubscriptionPayload
    priorAuthStatusChanged: PriorAuthStatusPayload
  }
  
  type PatientSubscriptionPayload {
    id: ID!
    data: Patient
    operation: String
    timestamp: String
  }
  
  type MedicationRequestSubscriptionPayload {
    id: ID!
    data: MedicationRequest
    operation: String
    timestamp: String
  }
  
  type PriorAuthStatusPayload {
    id: ID!
    data: PriorAuth
    operation: String
    timestamp: String
  }
`;

// Configure subscription resolvers
const resolvers = {
  Subscription: {
    patientUpdated: {
      subscribe: () => pubsub.asyncIterator(['PATIENT_UPDATE', 'PATIENT_CREATE'])
    },
    medicationRequestCreated: {
      subscribe: () => pubsub.asyncIterator(['MEDICATIONREQUEST_CREATE'])
    },
    priorAuthStatusChanged: {
      subscribe: () => pubsub.asyncIterator(['PRIORAUTH_STATUS_CHANGED'])
    }
  }
};

// Cache invalidation function
function invalidateCache(resourceType, resourceId) {
  // Implementation depends on caching strategy
  console.log(`Invalidating cache for ${resourceType}/${resourceId}`);
}
```

### API Marketplace Integration

The Federated Graph API integrates with the API Marketplace to provide GraphQL API management:

#### Key Integration Points:
- **GraphQL Schema Registry**: Publishing and versioning GraphQL schemas
- **API Documentation**: Generating documentation for GraphQL APIs
- **Access Control**: Managing access to GraphQL endpoints
- **Usage Analytics**: Tracking GraphQL API usage and performance

#### Integration Pattern:
```typescript
// GraphQL API Marketplace Registration
import axios from 'axios';
import { printSchema, buildClientSchema, getIntrospectionQuery } from 'graphql';
import { buildSubgraphSchema } from '@apollo/subgraph';

// API Marketplace client
const marketplaceClient = axios.create({
  baseURL: 'https://api-marketplace.cmm.internal/api/v1',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${process.env.MARKETPLACE_API_KEY}`
  }
});

// Function to register a GraphQL schema with the API Marketplace
async function registerGraphQLSchema(serviceName, endpoint, schema) {
  try {
    // Generate schema SDL
    const schemaSdl = typeof schema === 'string' 
      ? schema 
      : printSchema(schema);
    
    // Prepare API documentation
    const apiDoc = {
      name: `${serviceName} GraphQL API`,
      description: `GraphQL API for ${serviceName} service`,
      graphqlEndpoint: endpoint,
      schema: schemaSdl,
      version: '1.0.0',
      category: 'healthcare',
      visibility: 'internal',
      tags: ['graphql', 'federation', serviceName.toLowerCase()],
      samples: [
        {
          name: 'Basic Query',
          query: generateSampleQuery(schema),
          variables: {}
        }
      ]
    };
    
    // Register with API Marketplace
    const response = await marketplaceClient.post('/graphql-apis', apiDoc);
    
    console.log(`Successfully registered ${serviceName} GraphQL API:`, response.data);
    return response.data;
  } catch (error) {
    console.error(`Error registering ${serviceName} GraphQL API:`, error);
    throw error;
  }
}

// Helper function to generate a sample query based on schema
function generateSampleQuery(schema) {
  // Implementation would analyze schema to generate a sensible sample query
  return `query SampleQuery {
  # Replace with an appropriate sample query for your schema
  patientById(id: "example-id") {
    id
    name {
      family
      given
    }
  }
}`;
}

// Example usage for a subgraph
const patientSubgraphSchema = buildSubgraphSchema({
  typeDefs: gql`...`, // Patient subgraph schema
  resolvers: {...}    // Patient subgraph resolvers
});

registerGraphQLSchema(
  'Patient Service',
  'https://graphql-gateway.cmm.internal/subgraphs/patient',
  patientSubgraphSchema
);
```

### Design System Integration

The Federated Graph API provides data interfaces for Design System components:

#### Key Integration Points:
- **GraphQL Client Hooks**: React hooks for GraphQL data fetching and manipulation
- **Real-Time UI Components**: Components for displaying real-time data updates
- **Form Integration**: GraphQL-aware form components for data submission
- **Error Handling Patterns**: Standardized error handling for GraphQL operations

#### Integration Pattern:
```typescript
// React hooks for GraphQL data fetching
import React, { useState, useEffect } from 'react';
import { 
  ApolloClient, 
  InMemoryCache, 
  ApolloProvider,
  gql,
  useQuery,
  useMutation,
  useSubscription
} from '@apollo/client';
import { WebSocketLink } from '@apollo/client/link/ws';
import { 
  Table, 
  PatientCard, 
  LoadingSpinner, 
  ErrorDisplay 
} from '@cmm/design-system';

// Initialize Apollo Client
const client = new ApolloClient({
  uri: 'https://graphql-gateway.cmm.internal/graphql',
  cache: new InMemoryCache(),
  defaultOptions: {
    watchQuery: {
      fetchPolicy: 'cache-and-network',
    },
  },
});

// WebSocket link for subscriptions
const wsLink = new WebSocketLink({
  uri: 'wss://graphql-gateway.cmm.internal/graphql',
  options: {
    reconnect: true,
    connectionParams: {
      authToken: localStorage.getItem('auth_token'),
    },
  },
});

// GraphQL queries
const GET_PATIENT = gql`
  query GetPatient($id: ID!) {
    patientById(id: $id) {
      id
      name {
        family
        given
      }
      gender
      birthDate
      address {
        line
        city
        state
        postalCode
      }
      medicationRequests {
        id
        status
        medicationCodeableConcept {
          text
        }
        authoredOn
      }
    }
  }
`;

const PATIENT_UPDATED_SUBSCRIPTION = gql`
  subscription PatientUpdated {
    patientUpdated {
      id
      operation
      data {
        id
        name {
          family
          given
        }
      }
      timestamp
    }
  }
`;

// Patient Details component with real-time updates
function PatientDetails({ patientId }) {
  const { loading, error, data } = useQuery(GET_PATIENT, {
    variables: { id: patientId },
    notifyOnNetworkStatusChange: true,
  });
  
  const { data: subscriptionData } = useSubscription(PATIENT_UPDATED_SUBSCRIPTION);
  
  // Handle real-time updates
  useEffect(() => {
    if (subscriptionData && subscriptionData.patientUpdated) {
      const updatedPatient = subscriptionData.patientUpdated;
      if (updatedPatient.id === patientId) {
        // Show notification or update UI
        showNotification(`Patient ${patientId} was updated`);
      }
    }
  }, [subscriptionData, patientId]);
  
  if (loading) return <LoadingSpinner size="large" />;
  if (error) return <ErrorDisplay message={error.message} />;
  if (!data || !data.patientById) return <p>Patient not found</p>;
  
  const patient = data.patientById;
  
  return (
    <PatientCard
      patient={patient}
      showMedications
      renderMedications={(medications) => (
        <Table
          data={patient.medicationRequests}
          columns={[
            { header: 'Medication', accessor: 'medicationCodeableConcept.text' },
            { header: 'Status', accessor: 'status' },
            { header: 'Date', accessor: 'authoredOn', format: 'date' }
          ]}
        />
      )}
    />
  );
}

// Wrap application with Apollo Provider
function App() {
  return (
    <ApolloProvider client={client}>
      <div className="app-container">
        <PatientDetails patientId="example-patient-id" />
      </div>
    </ApolloProvider>
  );
}
```

## External System Integrations

### EHR System Integration

The Federated Graph API facilitates integration with external Electronic Health Record (EHR) systems:

#### Key Integration Points:
- **Data Federation**: Combining EHR data with internal data through GraphQL federation
- **SMART on FHIR Integration**: Supporting SMART on FHIR application data access
- **EHR-Specific Resolvers**: Implementing resolvers for EHR-specific data models
- **Clinical Decision Support**: Enabling access to clinical decision support systems

#### Integration Pattern:
```typescript
// EHR Integration Subgraph
import { ApolloServer } from '@apollo/server';
import { buildSubgraphSchema } from '@apollo/subgraph';
import { gql } from 'graphql-tag';
import { EhrClient } from './ehr-client';

// Initialize EHR client
const ehrClient = new EhrClient({
  baseUrl: process.env.EHR_API_URL,
  clientId: process.env.EHR_CLIENT_ID,
  clientSecret: process.env.EHR_CLIENT_SECRET
});

// Define GraphQL schema with Federation directives
const typeDefs = gql`
  extend schema @link(url: "https://specs.apollo.dev/federation/v2.0", import: ["@key", "@external", "@requires", "@provides"])

  type Query {
    ehrPatient(ehrId: ID!): EhrPatient
    clinicalEncounters(patientId: ID!): [ClinicalEncounter]
    labResults(patientId: ID!, timeframe: TimeframeInput): [LabResult]
  }

  input TimeframeInput {
    startDate: String
    endDate: String
  }

  type EhrPatient @key(fields: "id") {
    id: ID!
    ehrId: ID!
    mrn: String
    encounters: [ClinicalEncounter]
    labResults: [LabResult]
    allergies: [Allergy]
    problems: [Problem]
  }

  type ClinicalEncounter {
    id: ID!
    date: String
    type: String
    provider: Provider
    location: Location
    reasonForVisit: String
    diagnoses: [Diagnosis]
    procedures: [Procedure]
  }

  type Provider {
    id: ID!
    name: String
    speciality: String
    npi: String
  }

  type Location {
    id: ID!
    name: String
    address: String
  }

  type Diagnosis {
    code: String
    system: String
    display: String
  }

  type Procedure {
    code: String
    system: String
    display: String
    date: String
  }

  type LabResult {
    id: ID!
    code: String
    display: String
    value: String
    unit: String
    referenceRange: String
    interpretation: String
    date: String
  }

  type Allergy {
    id: ID!
    substance: String
    reaction: String
    severity: String
    onset: String
  }

  type Problem {
    id: ID!
    code: String
    display: String
    status: String
    onsetDate: String
    category: String
  }

  # Define extension for Patient type from FHIR subgraph
  extend type Patient @key(fields: "id") {
    id: ID! @external
    ehrRecords: EhrPatient
  }
`;

// Define resolvers for the schema
const resolvers = {
  Query: {
    ehrPatient: async (_, { ehrId }) => {
      try {
        const patient = await ehrClient.getPatient(ehrId);
        return {
          id: patient.cmm_id, // Internal ID that maps to FHIR patient
          ehrId: patient.id,
          mrn: patient.mrn
        };
      } catch (error) {
        console.error(`Error fetching EHR patient ${ehrId}:`, error);
        throw error;
      }
    },
    
    clinicalEncounters: async (_, { patientId }) => {
      try {
        const ehrId = await getEhrIdFromInternalId(patientId);
        return await ehrClient.getEncounters(ehrId);
      } catch (error) {
        console.error(`Error fetching clinical encounters for patient ${patientId}:`, error);
        throw error;
      }
    },
    
    labResults: async (_, { patientId, timeframe }) => {
      try {
        const ehrId = await getEhrIdFromInternalId(patientId);
        return await ehrClient.getLabResults(ehrId, timeframe);
      } catch (error) {
        console.error(`Error fetching lab results for patient ${patientId}:`, error);
        throw error;
      }
    }
  },
  
  EhrPatient: {
    encounters: async (ehrPatient) => {
      try {
        return await ehrClient.getEncounters(ehrPatient.ehrId);
      } catch (error) {
        console.error(`Error fetching encounters for EHR patient ${ehrPatient.ehrId}:`, error);
        return [];
      }
    },
    
    labResults: async (ehrPatient) => {
      try {
        return await ehrClient.getLabResults(ehrPatient.ehrId);
      } catch (error) {
        console.error(`Error fetching lab results for EHR patient ${ehrPatient.ehrId}:`, error);
        return [];
      }
    },
    
    allergies: async (ehrPatient) => {
      try {
        return await ehrClient.getAllergies(ehrPatient.ehrId);
      } catch (error) {
        console.error(`Error fetching allergies for EHR patient ${ehrPatient.ehrId}:`, error);
        return [];
      }
    },
    
    problems: async (ehrPatient) => {
      try {
        return await ehrClient.getProblems(ehrPatient.ehrId);
      } catch (error) {
        console.error(`Error fetching problems for EHR patient ${ehrPatient.ehrId}:`, error);
        return [];
      }
    }
  },
  
  Patient: {
    ehrRecords: async (patient) => {
      try {
        // Get EHR ID from mapping service
        const ehrMapping = await getEhrMapping(patient.id);
        if (!ehrMapping) return null;
        
        // Return minimal EHR patient object to be expanded by resolvers
        return {
          id: patient.id,
          ehrId: ehrMapping.ehrId,
          mrn: ehrMapping.mrn
        };
      } catch (error) {
        console.error(`Error resolving EHR records for patient ${patient.id}:`, error);
        return null;
      }
    }
  }
};

// Helper function to get EHR ID from internal patient ID
async function getEhrIdFromInternalId(internalId) {
  // Implementation would use a mapping service or database
  const mapping = await getEhrMapping(internalId);
  return mapping?.ehrId;
}

async function getEhrMapping(internalId) {
  // Implementation would use a mapping service or database
  // This is a placeholder
  return { ehrId: `ehr-${internalId}`, mrn: `MRN${internalId}` };
}

// Create Apollo Server with Federation schema
const server = new ApolloServer({
  schema: buildSubgraphSchema({ typeDefs, resolvers }),
});
```

### Pharmacy System Integration

The Federated Graph API enables integration with pharmacy management systems:

#### Key Integration Points:
- **Medication Fulfillment Data**: Accessing prescription fill status and history
- **Pharmacy Finder**: Locating pharmacies and checking inventory
- **Prescription Transfer**: Facilitating prescription transfers between pharmacies
- **Refill Management**: Managing prescription refill requests

#### Integration Pattern:
```typescript
// Pharmacy System Integration Subgraph
import { ApolloServer } from '@apollo/server';
import { buildSubgraphSchema } from '@apollo/subgraph';
import { gql } from 'graphql-tag';
import { PharmacyClient } from './pharmacy-client';

// Initialize Pharmacy client
const pharmacyClient = new PharmacyClient({
  baseUrl: process.env.PHARMACY_API_URL,
  apiKey: process.env.PHARMACY_API_KEY
});

// Define GraphQL schema with Federation directives
const typeDefs = gql`
  extend schema @link(url: "https://specs.apollo.dev/federation/v2.0", import: ["@key", "@external", "@requires", "@provides"])

  type Query {
    pharmacyById(id: ID!): Pharmacy
    searchPharmacies(location: LocationInput!, radius: Int): [Pharmacy]
    prescriptionById(id: ID!): Prescription
    patientPrescriptions(patientId: ID!): [Prescription]
  }

  input LocationInput {
    latitude: Float!
    longitude: Float!
    zipCode: String
  }

  type Pharmacy {
    id: ID!
    name: String
    address: Address
    phone: String
    fax: String
    hours: [OperatingHours]
    services: [String]
    hasDelivery: Boolean
    hasDriveThru: Boolean
  }

  type Address {
    street1: String
    street2: String
    city: String
    state: String
    zipCode: String
    latitude: Float
    longitude: Float
  }

  type OperatingHours {
    day: String
    open: String
    close: String
    isClosed: Boolean
  }

  type Prescription @key(fields: "id") {
    id: ID!
    externalId: String
    patient: PatientReference
    pharmacy: Pharmacy
    drug: Drug
    prescriber: Prescriber
    writtenDate: String
    lastFilledDate: String
    expirationDate: String
    status: String
    fills: [Fill]
    refillsRemaining: Int
    refillsTotal: Int
    instructions: String
    quantity: Float
    daysSupply: Int
    pricePerFill: Float
  }

  type PatientReference {
    id: ID!
    name: String
  }

  type Prescriber {
    id: ID!
    name: String
    npi: String
  }

  type Drug {
    ndc: String
    name: String
    genericName: String
    strength: String
    form: String
    manufacturer: String
  }

  type Fill {
    id: ID!
    fillDate: String
    filledQuantity: Float
    daysSupply: Int
    pharmacy: Pharmacy
    status: String
    price: Float
    copay: Float
  }

  # Define extension for MedicationRequest type from FHIR subgraph
  extend type MedicationRequest @key(fields: "id") {
    id: ID! @external
    prescription: Prescription
  }

  # Mutations
  type Mutation {
    requestRefill(prescriptionId: ID!): RefillResponse
    transferPrescription(prescriptionId: ID!, toPharmacyId: ID!): TransferResponse
  }

  type RefillResponse {
    success: Boolean!
    message: String
    requestId: ID
    estimatedReadyTime: String
  }

  type TransferResponse {
    success: Boolean!
    message: String
    transferId: ID
    status: String
  }
`;

// Define resolvers for the schema
const resolvers = {
  Query: {
    pharmacyById: async (_, { id }) => {
      try {
        return await pharmacyClient.getPharmacy(id);
      } catch (error) {
        console.error(`Error fetching pharmacy ${id}:`, error);
        throw error;
      }
    },
    
    searchPharmacies: async (_, { location, radius = 10 }) => {
      try {
        return await pharmacyClient.searchPharmacies(location, radius);
      } catch (error) {
        console.error('Error searching pharmacies:', error);
        throw error;
      }
    },
    
    prescriptionById: async (_, { id }) => {
      try {
        return await pharmacyClient.getPrescription(id);
      } catch (error) {
        console.error(`Error fetching prescription ${id}:`, error);
        throw error;
      }
    },
    
    patientPrescriptions: async (_, { patientId }) => {
      try {
        return await pharmacyClient.getPatientPrescriptions(patientId);
      } catch (error) {
        console.error(`Error fetching prescriptions for patient ${patientId}:`, error);
        throw error;
      }
    }
  },
  
  Prescription: {
    pharmacy: async (prescription) => {
      try {
        return await pharmacyClient.getPharmacy(prescription.pharmacyId);
      } catch (error) {
        console.error(`Error fetching pharmacy for prescription ${prescription.id}:`, error);
        return null;
      }
    },
    
    fills: async (prescription) => {
      try {
        return await pharmacyClient.getPrescriptionFills(prescription.id);
      } catch (error) {
        console.error(`Error fetching fills for prescription ${prescription.id}:`, error);
        return [];
      }
    },
    
    __resolveReference: async (reference) => {
      try {
        return await pharmacyClient.getPrescription(reference.id);
      } catch (error) {
        console.error(`Error resolving prescription reference ${reference.id}:`, error);
        return null;
      }
    }
  },
  
  MedicationRequest: {
    prescription: async (medicationRequest) => {
      try {
        // Find prescription by MedicationRequest ID or external reference
        const prescription = await pharmacyClient.getPrescriptionByExternalId(medicationRequest.id);
        return prescription;
      } catch (error) {
        console.error(`Error resolving prescription for medication request ${medicationRequest.id}:`, error);
        return null;
      }
    }
  },
  
  Mutation: {
    requestRefill: async (_, { prescriptionId }) => {
      try {
        return await pharmacyClient.requestRefill(prescriptionId);
      } catch (error) {
        console.error(`Error requesting refill for prescription ${prescriptionId}:`, error);
        throw error;
      }
    },
    
    transferPrescription: async (_, { prescriptionId, toPharmacyId }) => {
      try {
        return await pharmacyClient.transferPrescription(prescriptionId, toPharmacyId);
      } catch (error) {
        console.error(`Error transferring prescription ${prescriptionId} to pharmacy ${toPharmacyId}:`, error);
        throw error;
      }
    }
  }
};
```

### Payer System Integration

The Federated Graph API facilitates integration with healthcare payer systems:

#### Key Integration Points:
- **Eligibility Verification**: Checking patient insurance coverage
- **Benefits Information**: Retrieving benefit details
- **Prior Authorization Status**: Tracking prior authorization requests
- **Claims Processing**: Managing healthcare claims submission and status

#### Integration Pattern:
```typescript
// Payer System Integration Subgraph
import { ApolloServer } from '@apollo/server';
import { buildSubgraphSchema } from '@apollo/subgraph';
import { gql } from 'graphql-tag';
import { PayerClient } from './payer-client';

// Initialize Payer client
const payerClient = new PayerClient({
  baseUrl: process.env.PAYER_API_URL,
  clientId: process.env.PAYER_CLIENT_ID,
  clientSecret: process.env.PAYER_CLIENT_SECRET
});

// Define GraphQL schema with Federation directives
const typeDefs = gql`
  extend schema @link(url: "https://specs.apollo.dev/federation/v2.0", import: ["@key", "@external", "@requires", "@provides"])

  type Query {
    eligibilityCheck(patientId: ID!, serviceType: String!): EligibilityResponse
    memberBenefits(patientId: ID!): BenefitSummary
    priorAuth(id: ID!): PriorAuth
    priorAuthHistory(patientId: ID!): [PriorAuth]
    claim(id: ID!): Claim
    claimHistory(patientId: ID!): [Claim]
  }

  type EligibilityResponse {
    id: ID!
    patient: PatientReference
    payer: PayerReference
    planName: String
    coverageActive: Boolean
    coverageStartDate: String
    coverageEndDate: String
    verificationDate: String
    inNetwork: Boolean
    copay: Float
    deductible: DeductibleInfo
    benefitSummary: BenefitSummary
  }

  type PatientReference {
    id: ID!
    memberId: String
    name: String
  }

  type PayerReference {
    id: ID!
    name: String
    code: String
  }

  type DeductibleInfo {
    individual: Float
    family: Float
    remaining: Float
    met: Boolean
  }

  type BenefitSummary {
    planType: String
    networkName: String
    effectiveDate: String
    pharmacyBenefits: PharmacyBenefits
    medicalBenefits: MedicalBenefits
    additionalBenefits: [AdditionalBenefit]
  }

  type PharmacyBenefits {
    retail: TieredBenefit
    mailOrder: TieredBenefit
    specialty: SpecialtyBenefit
  }

  type TieredBenefit {
    tier1: CostShare
    tier2: CostShare
    tier3: CostShare
    tier4: CostShare
  }

  type SpecialtyBenefit {
    costShare: CostShare
    priorAuthRequired: Boolean
  }

  type CostShare {
    copay: Float
    coinsurance: Float
  }

  type MedicalBenefits {
    preventive: CostShare
    primaryCare: CostShare
    specialistCare: CostShare
    emergency: CostShare
    inpatient: CostShare
    outpatient: CostShare
  }

  type AdditionalBenefit {
    name: String
    description: String
    costShare: CostShare
  }

  type PriorAuth @key(fields: "id") {
    id: ID!
    status: String
    type: String
    createdDate: String
    updatedDate: String
    expirationDate: String
    patient: PatientReference
    provider: ProviderReference
    medication: MedicationReference
    diagnosis: [String]
    clinicalInfo: String
    decision: AuthDecision
    history: [AuthHistoryEntry]
  }

  type ProviderReference {
    id: ID!
    npi: String
    name: String
  }

  type MedicationReference {
    id: ID
    name: String
    ndc: String
    quantity: Float
    daysSupply: Int
  }

  type AuthDecision {
    status: String
    reason: String
    effectiveDate: String
    expirationDate: String
    approvedQuantity: Float
    approvedDays: Int
    alternativeMedication: MedicationReference
  }

  type AuthHistoryEntry {
    date: String
    status: String
    actor: String
    notes: String
  }

  type Claim {
    id: ID!
    type: String
    status: String
    patient: PatientReference
    provider: ProviderReference
    serviceDate: String
    submissionDate: String
    adjudicationDate: String
    totalAmount: Float
    allowedAmount: Float
    paidAmount: Float
    patientResponsibility: Float
    services: [ClaimService]
  }

  type ClaimService {
    id: ID!
    code: String
    description: String
    quantity: Float
    billedAmount: Float
    allowedAmount: Float
    paidAmount: Float
    adjustmentReason: String
  }

  # Extend MedicationRequest to link to prior authorizations
  extend type MedicationRequest @key(fields: "id") {
    id: ID! @external
    priorAuth: PriorAuth
  }

  # Mutations
  type Mutation {
    createPriorAuth(input: PriorAuthInput!): PriorAuthResponse
    updatePriorAuth(id: ID!, input: PriorAuthUpdateInput!): PriorAuthResponse
    checkClaimStatus(claimId: ID!): ClaimStatusResponse
  }

  input PriorAuthInput {
    patientId: ID!
    providerId: ID!
    medicationNdc: String!
    quantity: Float!
    daysSupply: Int!
    diagnosisCodes: [String!]!
    clinicalInfo: String
  }

  input PriorAuthUpdateInput {
    status: String
    clinicalInfo: String
    additionalDocuments: [DocumentInput]
  }

  input DocumentInput {
    name: String!
    contentType: String!
    content: String!
  }

  type PriorAuthResponse {
    success: Boolean!
    message: String
    priorAuth: PriorAuth
  }

  type ClaimStatusResponse {
    success: Boolean!
    message: String
    claim: Claim
  }
`;

// Define resolvers for the schema
const resolvers = {
  Query: {
    eligibilityCheck: async (_, { patientId, serviceType }) => {
      try {
        return await payerClient.checkEligibility(patientId, serviceType);
      } catch (error) {
        console.error(`Error checking eligibility for patient ${patientId}:`, error);
        throw error;
      }
    },
    
    memberBenefits: async (_, { patientId }) => {
      try {
        return await payerClient.getMemberBenefits(patientId);
      } catch (error) {
        console.error(`Error fetching benefits for patient ${patientId}:`, error);
        throw error;
      }
    },
    
    priorAuth: async (_, { id }) => {
      try {
        return await payerClient.getPriorAuth(id);
      } catch (error) {
        console.error(`Error fetching prior auth ${id}:`, error);
        throw error;
      }
    },
    
    priorAuthHistory: async (_, { patientId }) => {
      try {
        return await payerClient.getPatientPriorAuths(patientId);
      } catch (error) {
        console.error(`Error fetching prior auth history for patient ${patientId}:`, error);
        throw error;
      }
    },
    
    claim: async (_, { id }) => {
      try {
        return await payerClient.getClaim(id);
      } catch (error) {
        console.error(`Error fetching claim ${id}:`, error);
        throw error;
      }
    },
    
    claimHistory: async (_, { patientId }) => {
      try {
        return await payerClient.getPatientClaims(patientId);
      } catch (error) {
        console.error(`Error fetching claim history for patient ${patientId}:`, error);
        throw error;
      }
    }
  },
  
  PriorAuth: {
    history: async (priorAuth) => {
      try {
        return await payerClient.getPriorAuthHistory(priorAuth.id);
      } catch (error) {
        console.error(`Error fetching history for prior auth ${priorAuth.id}:`, error);
        return [];
      }
    },
    
    __resolveReference: async (reference) => {
      try {
        return await payerClient.getPriorAuth(reference.id);
      } catch (error) {
        console.error(`Error resolving prior auth reference ${reference.id}:`, error);
        return null;
      }
    }
  },
  
  MedicationRequest: {
    priorAuth: async (medicationRequest) => {
      try {
        // Find prior auth by related MedicationRequest
        return await payerClient.getPriorAuthByMedicationRequest(medicationRequest.id);
      } catch (error) {
        console.error(`Error resolving prior auth for medication request ${medicationRequest.id}:`, error);
        return null;
      }
    }
  },
  
  Mutation: {
    createPriorAuth: async (_, { input }) => {
      try {
        const result = await payerClient.createPriorAuth(input);
        return {
          success: true,
          message: "Prior authorization request submitted successfully",
          priorAuth: result
        };
      } catch (error) {
        console.error('Error creating prior auth:', error);
        return {
          success: false,
          message: error.message,
          priorAuth: null
        };
      }
    },
    
    updatePriorAuth: async (_, { id, input }) => {
      try {
        const result = await payerClient.updatePriorAuth(id, input);
        return {
          success: true,
          message: "Prior authorization updated successfully",
          priorAuth: result
        };
      } catch (error) {
        console.error(`Error updating prior auth ${id}:`, error);
        return {
          success: false,
          message: error.message,
          priorAuth: null
        };
      }
    },
    
    checkClaimStatus: async (_, { claimId }) => {
      try {
        const claim = await payerClient.refreshClaimStatus(claimId);
        return {
          success: true,
          message: `Claim status is ${claim.status}`,
          claim
        };
      } catch (error) {
        console.error(`Error checking status for claim ${claimId}:`, error);
        return {
          success: false,
          message: error.message,
          claim: null
        };
      }
    }
  }
};
```

### Mobile App Integration

The Federated Graph API supports integration with patient and provider mobile applications:

#### Key Integration Points:
- **Mobile-Optimized Queries**: Specialized GraphQL queries for mobile clients
- **Offline Support**: Implementing strategies for offline data access and synchronization
- **Push Notifications**: Coordinating GraphQL subscriptions with mobile push notifications
- **Authentication**: Supporting secure authentication for mobile applications

#### Integration Pattern:
```typescript
// Mobile App Apollo Client Setup
import { ApolloClient, InMemoryCache, HttpLink, split } from '@apollo/client';
import { getMainDefinition } from '@apollo/client/utilities';
import { WebSocketLink } from '@apollo/client/link/ws';
import { persistCache, MMKVStorage } from 'apollo3-cache-persist';
import { setContext } from '@apollo/client/link/context';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { MMKV } from 'react-native-mmkv';

// Initialize storage
const storage = new MMKV();
const mmkvStorageWrapper = {
  getItem: (key) => {
    const value = storage.getString(key);
    return Promise.resolve(value);
  },
  setItem: (key, value) => {
    storage.set(key, value);
    return Promise.resolve(true);
  },
  removeItem: (key) => {
    storage.delete(key);
    return Promise.resolve();
  }
};

// Create cache with persistence
const cache = new InMemoryCache({
  typePolicies: {
    Query: {
      fields: {
        // Field policies for pagination, caching, etc.
        patientPrescriptions: {
          keyArgs: ["patientId"],
          merge(existing = [], incoming) {
            return [...existing, ...incoming];
          }
        }
      }
    }
  }
});

// Set up cache persistence
async function setupApolloClient() {
  await persistCache({
    cache,
    storage: MMKVStorage(mmkvStorageWrapper),
    maxSize: 1024 * 1024 * 10, // 10MB
    debug: __DEV__
  });

  // Authentication link
  const authLink = setContext(async (_, { headers }) => {
    const token = await AsyncStorage.getItem('auth_token');
    return {
      headers: {
        ...headers,
        authorization: token ? `Bearer ${token}` : "",
      }
    };
  });

  // HTTP link for queries and mutations
  const httpLink = new HttpLink({
    uri: 'https://graphql-gateway.cmm.internal/graphql',
  });

  // WebSocket link for subscriptions
  const wsLink = new WebSocketLink({
    uri: 'wss://graphql-gateway.cmm.internal/graphql',
    options: {
      reconnect: true,
      connectionParams: async () => {
        const token = await AsyncStorage.getItem('auth_token');
        return {
          authorization: token ? `Bearer ${token}` : "",
        };
      },
    },
  });

  // Split link based on operation type
  const splitLink = split(
    ({ query }) => {
      const definition = getMainDefinition(query);
      return (
        definition.kind === 'OperationDefinition' &&
        definition.operation === 'subscription'
      );
    },
    wsLink,
    authLink.concat(httpLink),
  );

  // Create Apollo Client
  return new ApolloClient({
    link: splitLink,
    cache,
    defaultOptions: {
      watchQuery: {
        fetchPolicy: 'cache-and-network',
        nextFetchPolicy: 'cache-first',
      },
    },
  });
}

// Example of mobile-optimized query fragments
const PATIENT_DETAILS_FRAGMENT = gql`
  fragment PatientDetails on Patient {
    id
    name {
      family
      given
    }
    gender
    birthDate
    identifier {
      system
      value
    }
  }
`;

const MEDICATION_ITEM_FRAGMENT = gql`
  fragment MedicationItem on MedicationRequest {
    id
    status
    authoredOn
    medicationCodeableConcept {
      text
      coding {
        display
      }
    }
    dosageInstruction {
      text
    }
    prescription {
      id
      refillsRemaining
      pharmacy {
        name
        phone
      }
    }
  }
`;

// Example of mobile-optimized query
const GET_PATIENT_MEDICATIONS = gql`
  query GetPatientMedications($patientId: ID!) {
    patientById(id: $patientId) {
      ...PatientDetails
      medicationRequests {
        ...MedicationItem
      }
    }
  }
  ${PATIENT_DETAILS_FRAGMENT}
  ${MEDICATION_ITEM_FRAGMENT}
`;

// Example of offline-first mutation with queue
async function enqueueRefillRequest(client, prescriptionId) {
  try {
    // Check if online
    const isConnected = await NetInfo.fetch().then(state => state.isConnected);
    
    if (isConnected) {
      // If online, perform mutation directly
      return await client.mutate({
        mutation: REQUEST_REFILL_MUTATION,
        variables: { prescriptionId }
      });
    } else {
      // If offline, add to queue
      const queue = JSON.parse(await AsyncStorage.getItem('mutation_queue') || '[]');
      queue.push({
        type: 'REQUEST_REFILL',
        prescriptionId,
        timestamp: Date.now()
      });
      await AsyncStorage.setItem('mutation_queue', JSON.stringify(queue));
      
      // Return optimistic response
      return {
        data: {
          requestRefill: {
            success: true,
            message: "Refill request will be processed when online",
            requestId: null,
            estimatedReadyTime: null,
            __typename: "RefillResponse"
          }
        }
      };
    }
  } catch (error) {
    console.error('Error handling refill request:', error);
    throw error;
  }
}
```

## Message Transformation Patterns

### Schema Stitching

Combining schemas from multiple services into a cohesive federated graph:

```typescript
// Schema Stitching with Apollo Federation Gateway
import { ApolloServer } from '@apollo/server';
import { ApolloGateway, IntrospectAndCompose } from '@apollo/gateway';

// Define subgraph services
const supergraphSdl = new IntrospectAndCompose({
  subgraphs: [
    { name: 'patients', url: 'http://patient-service.cmm.internal:4001/graphql' },
    { name: 'medications', url: 'http://medication-service.cmm.internal:4002/graphql' },
    { name: 'priorauths', url: 'http://priorauth-service.cmm.internal:4003/graphql' },
    { name: 'pharmacies', url: 'http://pharmacy-service.cmm.internal:4004/graphql' },
    { name: 'providers', url: 'http://provider-service.cmm.internal:4005/graphql' },
    { name: 'ehr', url: 'http://ehr-service.cmm.internal:4006/graphql' },
  ],
});

// Initialize Gateway with service list
const gateway = new ApolloGateway({
  supergraphSdl,
  // Customize gateway behavior
  buildService({ name, url }) {
    return new RemoteGraphQLDataSource({
      url,
      willSendRequest({ request, context }) {
        // Pass user context to subgraphs
        request.http.headers.set(
          'user-id',
          context.userId
        );
        
        // Add tracing headers
        request.http.headers.set(
          'x-trace-id',
          context.traceId
        );
      },
    });
  },
});

// Create Apollo Server with Gateway
const server = new ApolloServer({
  gateway,
  context: ({ req }) => {
    // Extract authentication and context information
    const userId = getUserIdFromRequest(req);
    const traceId = getTraceId(req);
    
    return {
      userId,
      traceId,
      isAuthenticated: !!userId
    };
  }
});

// Helper functions
function getUserIdFromRequest(req) {
  // Extract user ID from authorization header
  const authHeader = req.headers.authorization;
  if (!authHeader) return null;
  
  // Implementation depends on auth strategy
  return extractUserIdFromToken(authHeader);
}

function getTraceId(req) {
  // Extract or generate trace ID for request tracing
  return req.headers['x-trace-id'] || generateTraceId();
}
```

### Response Caching

Implementing efficient caching strategies for GraphQL responses:

```typescript
// GraphQL Response Caching with Redis
import { ApolloServer } from '@apollo/server';
import { ApolloGateway } from '@apollo/gateway';
import { BaseRedisCache } from 'apollo-server-cache-redis';
import Redis from 'ioredis';
import responseCachePlugin from 'apollo-server-plugin-response-cache';

// Create Redis client
const redis = new Redis({
  host: 'redis.cmm.internal',
  port: 6379,
  password: process.env.REDIS_PASSWORD,
  // Additional configuration
});

// Create Gateway
const gateway = new ApolloGateway({
  // Gateway configuration
});

// Create Apollo Server with caching
const server = new ApolloServer({
  gateway,
  cache: new BaseRedisCache({
    client: redis
  }),
  plugins: [
    responseCachePlugin({
      // Cache configuration
      sessionId: ({ context }) => context.userId || null,
      shouldReadFromCache: ({ context }) => !context.bypassCache,
      shouldWriteToCache: ({ context }) => !context.bypassCache,
      // TTL calculation based on query complexity
      ttl: ({ context, source }) => {
        if (source.includes('patientById')) {
          return 300; // 5 minutes for patient data
        }
        if (source.includes('priorAuth')) {
          return 60; // 1 minute for prior auth status
        }
        return 3600; // 1 hour for other queries
      }
    })
  ],
  context: ({ req }) => {
    // Context configuration
    return {
      userId: getUserIdFromRequest(req),
      bypassCache: req.headers['cache-control'] === 'no-cache'
    };
  }
});

// Directive-based cache control
const typeDefs = gql`
  enum CacheControlScope {
    PUBLIC
    PRIVATE
  }

  directive @cacheControl(
    maxAge: Int
    scope: CacheControlScope
    inheritMaxAge: Boolean
  ) on FIELD_DEFINITION | OBJECT | INTERFACE | UNION
  
  type Patient @cacheControl(maxAge: 300) {
    # Patient fields
  }
  
  type PriorAuth @cacheControl(maxAge: 60) {
    # PriorAuth fields
  }
`;
```

## Related Resources
- [Federated Graph API Overview](./overview.md)
- [Federated Graph API Core APIs](../02-core-functionality/core-apis.md)
- [Federated Graph API Data Model](../02-core-functionality/data-model.md)
- [FHIR Interoperability Platform Integration](../../fhir-interoperability-platform/01-getting-started/integration-points.md)
- [Event-Driven Architecture Integration](../../event-driven-architecture/01-overview/integration-points.md)
- [API Marketplace Integration](../../api-marketplace/01-getting-started/integration-points.md)