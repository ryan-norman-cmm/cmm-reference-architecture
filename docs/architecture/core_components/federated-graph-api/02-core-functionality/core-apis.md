# Federated Graph API Core APIs

## Introduction

The Federated Graph API provides a unified GraphQL interface for accessing healthcare data across multiple domains. This document outlines the core APIs available through the federated graph, including the primary queries, mutations, and subscriptions that form the foundation of the API. These APIs are implemented across various subgraphs but are presented to clients as a single, cohesive GraphQL schema.

## GraphQL Schema Overview

The federated GraphQL schema combines entities and operations from multiple subgraphs into a unified API. The core schema includes:

- **Entities**: Patient, Encounter, Medication, Provider, etc.
- **Queries**: Operations to retrieve data
- **Mutations**: Operations to create, update, or delete data
- **Subscriptions**: Real-time data updates

## Core Entities

### Patient Entity

The Patient entity represents a healthcare patient and is a central entity in the federated graph.

```graphql
type Patient @key(fields: "id") {
  id: ID!
  mrn: String!
  firstName: String!
  lastName: String!
  dateOfBirth: String!
  gender: Gender!
  contactInfo: ContactInfo
  encounters: [Encounter!]!
  medications: [Medication!]!
  allergies: [Allergy!]!
  conditions: [Condition!]!
  createdAt: String!
  updatedAt: String!
}

enum Gender {
  MALE
  FEMALE
  OTHER
  UNKNOWN
}

type ContactInfo {
  email: String
  phone: String
  address: Address
}

type Address {
  line1: String!
  line2: String
  city: String!
  state: String!
  postalCode: String!
  country: String!
}
```

### Encounter Entity

The Encounter entity represents a clinical encounter or visit.

```graphql
type Encounter @key(fields: "id") {
  id: ID!
  patient: Patient!
  provider: Provider!
  facility: Facility!
  type: EncounterType!
  status: EncounterStatus!
  startTime: String!
  endTime: String
  reason: String
  diagnoses: [Diagnosis!]!
  notes: [ClinicalNote!]!
  createdAt: String!
  updatedAt: String!
}

enum EncounterType {
  AMBULATORY
  EMERGENCY
  INPATIENT
  VIRTUAL
  HOME_VISIT
}

enum EncounterStatus {
  SCHEDULED
  IN_PROGRESS
  COMPLETED
  CANCELLED
}
```

### Medication Entity

The Medication entity represents a medication order or prescription.

```graphql
type Medication @key(fields: "id") {
  id: ID!
  patient: Patient!
  provider: Provider!
  name: String!
  rxNorm: String
  dosage: String!
  frequency: String!
  route: String!
  startDate: String!
  endDate: String
  status: MedicationStatus!
  pharmacy: Pharmacy
  createdAt: String!
  updatedAt: String!
}

enum MedicationStatus {
  ACTIVE
  COMPLETED
  CANCELLED
  ON_HOLD
}
```

## Core Queries

The following queries form the foundation of the read operations in the Federated Graph API.

### Patient Queries

```graphql
type Query {
  # Get a patient by ID
  patient(id: ID!): Patient
  
  # Get a patient by MRN
  patientByMRN(mrn: String!): Patient
  
  # Get a list of patients with pagination
  patients(limit: Int = 10, offset: Int = 0): [Patient!]!
  
  # Search for patients by various criteria
  searchPatients(query: PatientSearchInput!): [Patient!]!
}

input PatientSearchInput {
  name: String
  dateOfBirth: String
  mrn: String
  gender: Gender
}
```

**TypeScript Implementation Example:**

```typescript
// Patient query resolvers in TypeScript
const resolvers = {
  Query: {
    patient: async (_, { id }, { dataSources, user }) => {
      // Authorization check
      if (!hasPermission(user, 'read:patient')) {
        throw new ForbiddenError('Not authorized to view patient data');
      }
      
      return await dataSources.patientAPI.getPatientById(id);
    },
    
    patientByMRN: async (_, { mrn }, { dataSources, user }) => {
      // Authorization check
      if (!hasPermission(user, 'read:patient')) {
        throw new ForbiddenError('Not authorized to view patient data');
      }
      
      return await dataSources.patientAPI.getPatientByMRN(mrn);
    },
    
    patients: async (_, { limit, offset }, { dataSources, user }) => {
      // Authorization check
      if (!hasPermission(user, 'read:patient')) {
        throw new ForbiddenError('Not authorized to view patient data');
      }
      
      return await dataSources.patientAPI.getPatients(limit, offset);
    },
    
    searchPatients: async (_, { query }, { dataSources, user }) => {
      // Authorization check
      if (!hasPermission(user, 'read:patient')) {
        throw new ForbiddenError('Not authorized to view patient data');
      }
      
      return await dataSources.patientAPI.searchPatients(query);
    }
  }
};
```

### Encounter Queries

```graphql
type Query {
  # Get an encounter by ID
  encounter(id: ID!): Encounter
  
  # Get encounters for a patient
  patientEncounters(patientId: ID!, limit: Int = 10, offset: Int = 0): [Encounter!]!
  
  # Get encounters by date range
  encountersByDateRange(startDate: String!, endDate: String!, limit: Int = 10, offset: Int = 0): [Encounter!]!
  
  # Get encounters by provider
  providerEncounters(providerId: ID!, limit: Int = 10, offset: Int = 0): [Encounter!]!
}
```

### Medication Queries

```graphql
type Query {
  # Get a medication by ID
  medication(id: ID!): Medication
  
  # Get medications for a patient
  patientMedications(patientId: ID!, status: MedicationStatus, limit: Int = 10, offset: Int = 0): [Medication!]!
  
  # Get medications prescribed by a provider
  providerMedications(providerId: ID!, limit: Int = 10, offset: Int = 0): [Medication!]!
}
```

## Core Mutations

The following mutations form the foundation of the write operations in the Federated Graph API.

### Patient Mutations

```graphql
type Mutation {
  # Create a new patient
  createPatient(input: CreatePatientInput!): Patient!
  
  # Update an existing patient
  updatePatient(id: ID!, input: UpdatePatientInput!): Patient!
  
  # Merge duplicate patient records
  mergePatients(primaryId: ID!, secondaryId: ID!): Patient!
}

input CreatePatientInput {
  mrn: String!
  firstName: String!
  lastName: String!
  dateOfBirth: String!
  gender: Gender!
  contactInfo: ContactInfoInput
}

input UpdatePatientInput {
  firstName: String
  lastName: String
  gender: Gender
  contactInfo: ContactInfoInput
}

input ContactInfoInput {
  email: String
  phone: String
  address: AddressInput
}

input AddressInput {
  line1: String!
  line2: String
  city: String!
  state: String!
  postalCode: String!
  country: String!
}
```

**TypeScript Implementation Example:**

```typescript
// Patient mutation resolvers in TypeScript
const resolvers = {
  Mutation: {
    createPatient: async (_, { input }, { dataSources, user }) => {
      // Authorization check
      if (!hasPermission(user, 'create:patient')) {
        throw new ForbiddenError('Not authorized to create patients');
      }
      
      // Validate input
      validatePatientInput(input);
      
      // Create patient
      const patient = await dataSources.patientAPI.createPatient(input);
      
      // Publish event to event broker
      await publishEvent('patient.created', {
        patientId: patient.id,
        userId: user.id,
        timestamp: new Date().toISOString()
      });
      
      return patient;
    },
    
    updatePatient: async (_, { id, input }, { dataSources, user }) => {
      // Authorization check
      if (!hasPermission(user, 'update:patient')) {
        throw new ForbiddenError('Not authorized to update patients');
      }
      
      // Validate input
      validatePatientInput(input);
      
      // Update patient
      const patient = await dataSources.patientAPI.updatePatient(id, input);
      
      // Publish event to event broker
      await publishEvent('patient.updated', {
        patientId: patient.id,
        userId: user.id,
        timestamp: new Date().toISOString()
      });
      
      return patient;
    },
    
    mergePatients: async (_, { primaryId, secondaryId }, { dataSources, user }) => {
      // Authorization check
      if (!hasPermission(user, 'merge:patient')) {
        throw new ForbiddenError('Not authorized to merge patients');
      }
      
      // Merge patients
      const patient = await dataSources.patientAPI.mergePatients(primaryId, secondaryId);
      
      // Publish event to event broker
      await publishEvent('patient.merged', {
        primaryId,
        secondaryId,
        userId: user.id,
        timestamp: new Date().toISOString()
      });
      
      return patient;
    }
  }
};
```

### Encounter Mutations

```graphql
type Mutation {
  # Create a new encounter
  createEncounter(input: CreateEncounterInput!): Encounter!
  
  # Update an existing encounter
  updateEncounter(id: ID!, input: UpdateEncounterInput!): Encounter!
  
  # Change encounter status
  updateEncounterStatus(id: ID!, status: EncounterStatus!): Encounter!
}

input CreateEncounterInput {
  patientId: ID!
  providerId: ID!
  facilityId: ID!
  type: EncounterType!
  startTime: String!
  endTime: String
  reason: String
}

input UpdateEncounterInput {
  providerId: ID
  facilityId: ID
  type: EncounterType
  startTime: String
  endTime: String
  reason: String
}
```

### Medication Mutations

```graphql
type Mutation {
  # Create a new medication order
  createMedication(input: CreateMedicationInput!): Medication!
  
  # Update an existing medication order
  updateMedication(id: ID!, input: UpdateMedicationInput!): Medication!
  
  # Change medication status
  updateMedicationStatus(id: ID!, status: MedicationStatus!): Medication!
}

input CreateMedicationInput {
  patientId: ID!
  providerId: ID!
  name: String!
  rxNorm: String
  dosage: String!
  frequency: String!
  route: String!
  startDate: String!
  endDate: String
  pharmacyId: ID
}

input UpdateMedicationInput {
  dosage: String
  frequency: String
  route: String
  startDate: String
  endDate: String
  pharmacyId: ID
}
```

## Core Subscriptions

Subscriptions enable real-time updates for clients. The following subscriptions are available in the Federated Graph API.

```graphql
type Subscription {
  # Subscribe to patient updates
  patientUpdated(id: ID!): Patient!
  
  # Subscribe to encounter status changes
  encounterStatusChanged(patientId: ID): Encounter!
  
  # Subscribe to new medication orders
  medicationCreated(patientId: ID): Medication!
  
  # Subscribe to medication status changes
  medicationStatusChanged(patientId: ID): Medication!
}
```

**TypeScript Implementation Example:**

```typescript
// Subscription resolvers in TypeScript
import { PubSub } from 'graphql-subscriptions';

const pubsub = new PubSub();

const resolvers = {
  Subscription: {
    patientUpdated: {
      subscribe: (_, { id }, { user }) => {
        // Authorization check
        if (!hasPermission(user, 'read:patient')) {
          throw new ForbiddenError('Not authorized to subscribe to patient updates');
        }
        
        return pubsub.asyncIterator(`PATIENT_UPDATED:${id}`);
      }
    },
    
    encounterStatusChanged: {
      subscribe: (_, { patientId }, { user }) => {
        // Authorization check
        if (!hasPermission(user, 'read:encounter')) {
          throw new ForbiddenError('Not authorized to subscribe to encounter updates');
        }
        
        const channel = patientId ? 
          `ENCOUNTER_STATUS_CHANGED:PATIENT:${patientId}` : 
          'ENCOUNTER_STATUS_CHANGED';
        
        return pubsub.asyncIterator(channel);
      }
    },
    
    medicationCreated: {
      subscribe: (_, { patientId }, { user }) => {
        // Authorization check
        if (!hasPermission(user, 'read:medication')) {
          throw new ForbiddenError('Not authorized to subscribe to medication updates');
        }
        
        const channel = patientId ? 
          `MEDICATION_CREATED:PATIENT:${patientId}` : 
          'MEDICATION_CREATED';
        
        return pubsub.asyncIterator(channel);
      }
    },
    
    medicationStatusChanged: {
      subscribe: (_, { patientId }, { user }) => {
        // Authorization check
        if (!hasPermission(user, 'read:medication')) {
          throw new ForbiddenError('Not authorized to subscribe to medication updates');
        }
        
        const channel = patientId ? 
          `MEDICATION_STATUS_CHANGED:PATIENT:${patientId}` : 
          'MEDICATION_STATUS_CHANGED';
        
        return pubsub.asyncIterator(channel);
      }
    }
  }
};

// Function to publish events to subscribers
export function publishSubscriptionEvent(eventName, patientId, data) {
  // Publish to patient-specific channel
  if (patientId) {
    pubsub.publish(`${eventName}:PATIENT:${patientId}`, data);
  }
  
  // Publish to global channel
  pubsub.publish(eventName, data);
}
```

## Error Handling

The Federated Graph API uses a standardized error format to provide consistent error responses across all operations.

```typescript
// Standard error format
interface GraphQLError {
  message: string;        // Human-readable error message
  code: string;           // Error code (e.g., UNAUTHORIZED, NOT_FOUND)
  path: string[];         // Path to the field that caused the error
  extensions?: {          // Additional error metadata
    classification: string; // Error classification (e.g., DataFetchingException)
    stacktrace?: string[];  // Stack trace (in development mode only)
  };
}

// Example error response
{
  "errors": [
    {
      "message": "Patient with ID '123' not found",
      "code": "NOT_FOUND",
      "path": ["patient"],
      "extensions": {
        "classification": "DataFetchingException"
      }
    }
  ],
  "data": {
    "patient": null
  }
}
```

## Authentication and Authorization

The Federated Graph API uses JWT-based authentication and role-based authorization.

```typescript
// Authentication middleware
import { expressMiddleware } from '@apollo/server/express4';
import jwt from 'jsonwebtoken';

app.use(
  '/graphql',
  expressMiddleware(server, {
    context: async ({ req }) => {
      // Extract JWT token from Authorization header
      const token = req.headers.authorization?.split(' ')[1] || '';
      
      try {
        // Verify and decode the token
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        
        // Create user context
        const user = {
          id: decoded.sub,
          roles: decoded.roles || [],
          permissions: decoded.permissions || []
        };
        
        return { user };
      } catch (error) {
        // Return empty user context if token is invalid
        return { user: null };
      }
    }
  })
);

// Authorization helper function
function hasPermission(user, permission) {
  if (!user) return false;
  return user.permissions.includes(permission);
}
```

## Pagination

The Federated Graph API supports two pagination methods:

### Offset-Based Pagination

```graphql
type Query {
  patients(limit: Int = 10, offset: Int = 0): [Patient!]!
}
```

### Cursor-Based Pagination

```graphql
type Query {
  patientsConnection(first: Int = 10, after: String): PatientConnection!
}

type PatientConnection {
  edges: [PatientEdge!]!
  pageInfo: PageInfo!
}

type PatientEdge {
  node: Patient!
  cursor: String!
}

type PageInfo {
  hasNextPage: Boolean!
  hasPreviousPage: Boolean!
  startCursor: String
  endCursor: String
}
```

## Conclusion

The Core APIs of the Federated Graph API provide a comprehensive set of operations for interacting with healthcare data. These APIs are designed to be consistent, secure, and scalable, enabling a wide range of healthcare applications to be built on top of the platform. As you develop applications that interact with the Federated Graph API, refer to this documentation for guidance on the available operations and their expected behavior.
