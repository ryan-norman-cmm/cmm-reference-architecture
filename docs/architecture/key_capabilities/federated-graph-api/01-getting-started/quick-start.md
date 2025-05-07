# Federated Graph API Quick Start

This guide provides a comprehensive, hands-on approach to get you up and running with the Federated Graph API for unified healthcare data access across multiple systems.

## Prerequisites
- Access to the CMM platform environment (development, staging, or production)
- Provisioned credentials for the Federated Graph API (API key or OAuth credentials)
- Network access to the Federated Graph API endpoint
- Basic familiarity with GraphQL concepts
- Node.js 14+ for running the example code

## Setup Options

### Option A: Local Development Environment

Follow these steps to set up a local development environment for working with the Federated Graph API:

#### Step 1: Install Apollo Router

Apollo Router is the high-performance gateway that powers our federated GraphQL API. Choose one of the following installation methods:

**Method 1: Using the Install Script (Recommended for macOS/Linux)**

```bash
# Download and install the latest version
curl -sSL https://router.apollo.dev/download/nix/latest | sh

# Verify installation
./router --version
```

**Method 2: Using Docker**

```bash
# Pull the Apollo Router image
docker pull ghcr.io/apollographql/router:latest

# Create a directory for configuration
mkdir -p apollo-router-demo/config
cd apollo-router-demo
```

**Method 3: Manual Download**

Download the appropriate binary for your platform from the [Apollo Router releases page](https://github.com/apollographql/router/releases).

#### Step 2: Configure a Local Supergraph

For local development, you'll need a supergraph schema that defines your federated GraphQL API. Here's how to set up a simple healthcare-focused example:

1. Create a directory for your configuration:

```bash
mkdir -p federation-demo
cd federation-demo
```

2. Create a file named `supergraph.graphql` with this sample schema (healthcare domain example):

```graphql
schema
  @core(feature: "https://specs.apollo.dev/core/v0.1")
  @core(feature: "https://specs.apollo.dev/join/v0.1") {
  query: Query
  mutation: Mutation
}

type Query {
  patient(id: ID!): Patient
  practitioner(id: ID!): Practitioner 
  medicationRequest(id: ID!): MedicationRequest
  searchPatients(name: String): [Patient]
}

type Mutation {
  createMedicationRequest(input: MedicationRequestInput!): MedicationRequestResult!
  updatePatient(id: ID!, input: PatientInput!): PatientResult!
}

type Patient @join__type(graph: FHIR) {
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
  medicationRequests: [MedicationRequest] @join__field(graph: PRESCRIPTIONS)
  coverage: [Coverage] @join__field(graph: INSURANCE)
}

type Practitioner @join__type(graph: FHIR) {
  id: ID!
  identifier: [Identifier]
  name: [HumanName]
  gender: String
  birthDate: String
  address: [Address]
  telecom: [ContactPoint]
  active: Boolean
  qualification: [Qualification]
  patients: [Patient] @join__field(graph: PATIENTS)
}

type HumanName {
  use: String
  text: String
  family: String
  given: [String]
  prefix: [String]
  suffix: [String]
}

type Identifier {
  system: String
  value: String
}

type ContactPoint {
  system: String
  value: String
  use: String
}

type Address {
  use: String
  type: String
  text: String
  line: [String]
  city: String
  state: String
  postalCode: String
  country: String
}

type Reference {
  reference: String
  type: String
  display: String
}

type Qualification {
  identifier: [Identifier]
  code: CodeableConcept
  period: Period
}

type CodeableConcept {
  coding: [Coding]
  text: String
}

type Coding {
  system: String
  version: String
  code: String
  display: String
}

type Period {
  start: String
  end: String
}

type MedicationRequest @join__type(graph: PRESCRIPTIONS) {
  id: ID!
  status: String
  intent: String
  medicationCodeableConcept: CodeableConcept
  subject: Reference
  requester: Reference
  authoredOn: String
  dosageInstruction: [Dosage]
  dispenseRequest: DispenseRequest
  priorAuthorization: PriorAuthorization @join__field(graph: PRIOR_AUTH)
}

type Dosage {
  text: String
  timing: Timing
  doseAndRate: [DoseAndRate]
}

type Timing {
  code: CodeableConcept
  repeat: RepeatPattern
}

type RepeatPattern {
  frequency: Int
  period: Float
  periodUnit: String
}

type DoseAndRate {
  type: CodeableConcept
  doseQuantity: Quantity
}

type Quantity {
  value: Float
  unit: String
  system: String
  code: String
}

type DispenseRequest {
  validityPeriod: Period
  numberOfRepeatsAllowed: Int
  quantity: Quantity
  expectedSupplyDuration: Duration
}

type Duration {
  value: Float
  unit: String
  system: String
  code: String
}

type PriorAuthorization @join__type(graph: PRIOR_AUTH) {
  id: ID!
  status: String
  created: String
  medicationRequest: Reference
  supportingInformation: [Reference]
  outcome: String
  reviewer: Reference
  validPeriod: Period
}

type Coverage @join__type(graph: INSURANCE) {
  id: ID!
  status: String
  subscriber: Reference
  beneficiary: Reference
  relationship: CodeableConcept
  payor: [Reference]
  order: Int
  network: String
  costToBeneficiary: [CostToBeneficiary]
}

type CostToBeneficiary {
  type: CodeableConcept
  value: Money
}

type Money {
  value: Float
  currency: String
}

input MedicationRequestInput {
  status: String!
  intent: String!
  medicationCodeableConcept: CodeableConceptInput!
  subjectId: String!
  requesterId: String
  dosageInstructions: [String]
}

input CodeableConceptInput {
  coding: [CodingInput]
  text: String
}

input CodingInput {
  system: String!
  code: String!
  display: String
}

input PatientInput {
  name: [HumanNameInput]
  gender: String
  birthDate: String
  address: [AddressInput]
  telecom: [ContactPointInput]
  active: Boolean
}

input HumanNameInput {
  use: String
  text: String
  family: String
  given: [String]
  prefix: [String]
  suffix: [String]
}

input AddressInput {
  use: String
  type: String
  text: String
  line: [String]
  city: String
  state: String
  postalCode: String
  country: String
}

input ContactPointInput {
  system: String
  value: String
  use: String
}

type PatientResult {
  success: Boolean!
  message: String
  patient: Patient
}

type MedicationRequestResult {
  success: Boolean!
  message: String
  medicationRequest: MedicationRequest
}
```

3. Create a file named `router.yaml` with the following configuration:

```yaml
health-check:
  enabled: true

supergraph:
  path: /graphql
  introspection: true

homepage:
  enabled: true

cors:
  origins:
    - http://localhost:3000
    - https://studio.apollographql.com
  allow_credentials: true

headers:
  all:
    request:
      - propagate:
          named: Authorization

sandbox:
  enabled: true

include_subgraph_errors:
  all: true
```

#### Step 3: Start the Apollo Router

Now you can start the Apollo Router with your configuration:

```bash
# If using the binary
./router --supergraph supergraph.graphql --config router.yaml

# If using Docker
docker run -v "$(pwd)/supergraph.graphql:/dist/supergraph.graphql" \
  -v "$(pwd)/router.yaml:/dist/router.yaml" \
  -p 4000:4000 -p 8088:8088 \
  ghcr.io/apollographql/router:latest
```

You should see output indicating the router is running. The GraphQL endpoint will be available at http://localhost:4000/graphql, and the admin interface at http://localhost:8088.

### Option B: Using an Existing CMM Platform Environment

If you're connecting to a pre-deployed Federated Graph API in your organization's environment:

1. Obtain the API connection details from your platform team:
   - GraphQL endpoint URL (e.g., `https://graph-api.cmm-dev.example.com/graphql`)
   - Authentication credentials (API key or OAuth client credentials)
   - Any required headers or security settings

2. Configure your client with these settings (see client examples below).

## Step 4: Set Up a GraphQL Client

Let's set up a client application to interact with the Federated Graph API. We'll use Apollo Client for this example.

### Create a New Project

```bash
mkdir healthcare-graphql-app && cd healthcare-graphql-app
npm init -y
npm install @apollo/client graphql cross-fetch dotenv typescript ts-node @types/node
```

### Create Config and Client Files

Create a `.env` file for configuration:

```
# Local development
GRAPHQL_ENDPOINT=http://localhost:4000/graphql
API_KEY=your-development-api-key

# For production environments, uncomment and configure:
# GRAPHQL_ENDPOINT=https://graph-api.cmm-prod.example.com/graphql
# API_KEY=your-production-api-key
```

Create a file named `apollo-client.ts` for configuring the GraphQL client:

```typescript
// apollo-client.ts
import { ApolloClient, InMemoryCache, HttpLink, ApolloLink, from } from '@apollo/client/core';
import { onError } from '@apollo/client/link/error';
import fetch from 'cross-fetch';
import * as dotenv from 'dotenv';

dotenv.config();

// Get configuration from environment variables
const endpoint = process.env.GRAPHQL_ENDPOINT || 'http://localhost:4000/graphql';
const apiKey = process.env.API_KEY || 'development-api-key';

// Create an error handling link
const errorLink = onError(({ graphQLErrors, networkError }) => {
  if (graphQLErrors) {
    graphQLErrors.forEach(({ message, locations, path, extensions }) => {
      console.error(
        `[GraphQL error]: Message: ${message}, Location: ${locations}, Path: ${path}, Code: ${extensions?.code}`
      );
    });
  }
  if (networkError) {
    console.error(`[Network error]: ${networkError}`);
  }
});

// Create an auth link to add the API key to all requests
const authLink = new ApolloLink((operation, forward) => {
  operation.setContext({
    headers: {
      Authorization: `Bearer ${apiKey}`,
    },
  });
  return forward(operation);
});

// Create the HTTP link to the GraphQL API
const httpLink = new HttpLink({
  uri: endpoint,
  fetch,
});

// Create the Apollo Client
export const client = new ApolloClient({
  link: from([errorLink, authLink, httpLink]),
  cache: new InMemoryCache({
    typePolicies: {
      Patient: {
        // Configure cache behavior for Patient objects
        keyFields: ['id'],
        fields: {
          medicationRequests: {
            // Simple non-normalized field policy example
            merge(existing = [], incoming) {
              return [...incoming];
            },
          },
        },
      },
    },
  }),
  defaultOptions: {
    watchQuery: {
      fetchPolicy: 'cache-and-network',
    },
    query: {
      fetchPolicy: 'network-only',
      errorPolicy: 'all',
    },
    mutate: {
      errorPolicy: 'all',
    },
  },
});
```

## Step 5: GraphQL Operation Examples

Let's create some practical examples for healthcare data operations. Create a file called `healthcare-queries.ts`:

```typescript
// healthcare-queries.ts
import { gql } from '@apollo/client/core';
import { client } from './apollo-client';

// Define query operations
const GET_PATIENT = gql`
  query GetPatient($id: ID!) {
    patient(id: $id) {
      id
      name {
        given
        family
        prefix
      }
      gender
      birthDate
      address {
        line
        city
        state
        postalCode
      }
      telecom {
        system
        value
        use
      }
      medicationRequests {
        id
        status
        medicationCodeableConcept {
          coding {
            system
            code
            display
          }
          text
        }
        authoredOn
      }
    }
  }
`;

const SEARCH_PATIENTS = gql`
  query SearchPatients($name: String) {
    searchPatients(name: $name) {
      id
      name {
        given
        family
      }
      gender
      birthDate
    }
  }
`;

const GET_MEDICATION_REQUEST = gql`
  query GetMedicationRequest($id: ID!) {
    medicationRequest(id: $id) {
      id
      status
      intent
      medicationCodeableConcept {
        coding {
          system
          code
          display
        }
        text
      }
      subject {
        reference
        display
      }
      requester {
        reference
        display
      }
      authoredOn
      dosageInstruction {
        text
        timing {
          repeat {
            frequency
            period
            periodUnit
          }
        }
        doseAndRate {
          doseQuantity {
            value
            unit
          }
        }
      }
      priorAuthorization {
        id
        status
        outcome
        validPeriod {
          start
          end
        }
      }
    }
  }
`;

// Define mutation operations
const CREATE_MEDICATION_REQUEST = gql`
  mutation CreateMedicationRequest($input: MedicationRequestInput!) {
    createMedicationRequest(input: $input) {
      success
      message
      medicationRequest {
        id
        status
        medicationCodeableConcept {
          text
        }
      }
    }
  }
`;

const UPDATE_PATIENT = gql`
  mutation UpdatePatient($id: ID!, $input: PatientInput!) {
    updatePatient(id: $id, input: $input) {
      success
      message
      patient {
        id
        name {
          given
          family
        }
        telecom {
          system
          value
        }
      }
    }
  }
`;

// Example functions to execute these operations
async function fetchPatientProfile(patientId: string) {
  try {
    console.log(`Fetching details for patient ID: ${patientId}`);
    
    const { data, errors } = await client.query({
      query: GET_PATIENT,
      variables: { id: patientId },
    });
    
    if (errors) {
      console.error('Errors fetching patient:', errors);
      return null;
    }
    
    // Format and display patient information
    const patient = data.patient;
    console.log('\nPatient Profile:');
    console.log('----------------');
    
    // Format name
    const name = patient.name[0];
    const fullName = [
      name.prefix?.join(' ') || '',
      name.given?.join(' ') || '',
      name.family || ''
    ].filter(Boolean).join(' ');
    
    console.log(`Name: ${fullName}`);
    console.log(`Gender: ${patient.gender}`);
    console.log(`Birth Date: ${patient.birthDate}`);
    
    // Format address
    if (patient.address && patient.address.length > 0) {
      const address = patient.address[0];
      const formattedAddress = [
        address.line?.join(', ') || '',
        address.city || '',
        address.state || '',
        address.postalCode || ''
      ].filter(Boolean).join(', ');
      
      console.log(`Address: ${formattedAddress}`);
    }
    
    // Format contact information
    if (patient.telecom && patient.telecom.length > 0) {
      console.log('\nContact Information:');
      patient.telecom.forEach((contact: any) => {
        console.log(`${contact.system}: ${contact.value} (${contact.use || 'primary'})`);
      });
    }
    
    // Format medications
    if (patient.medicationRequests && patient.medicationRequests.length > 0) {
      console.log('\nCurrent Medications:');
      patient.medicationRequests.forEach((rx: any, index: number) => {
        const med = rx.medicationCodeableConcept?.text || 
                   (rx.medicationCodeableConcept?.coding?.[0]?.display || 'Unknown medication');
        console.log(`${index + 1}. ${med} (Status: ${rx.status}, Prescribed: ${rx.authoredOn})`);
      });
    } else {
      console.log('\nNo current medications found.');
    }
    
    return patient;
  } catch (error) {
    console.error('Error fetching patient profile:', error);
    return null;
  }
}

async function searchPatientsByName(nameQuery: string) {
  try {
    console.log(`Searching for patients with name containing: ${nameQuery}`);
    
    const { data, errors } = await client.query({
      query: SEARCH_PATIENTS,
      variables: { name: nameQuery },
    });
    
    if (errors) {
      console.error('Errors searching patients:', errors);
      return null;
    }
    
    const patients = data.searchPatients;
    
    if (patients.length === 0) {
      console.log(`No patients found matching "${nameQuery}"`);
      return [];
    }
    
    console.log(`\nFound ${patients.length} patient(s) matching "${nameQuery}":`);
    console.log('----------------');
    
    patients.forEach((patient: any, index: number) => {
      const name = patient.name[0];
      const fullName = [
        name.given?.join(' ') || '',
        name.family || ''
      ].filter(Boolean).join(' ');
      
      console.log(`${index + 1}. ${fullName} (ID: ${patient.id}, DOB: ${patient.birthDate})`);
    });
    
    return patients;
  } catch (error) {
    console.error('Error searching patients:', error);
    return null;
  }
}

async function getMedicationRequestDetails(rxId: string) {
  try {
    console.log(`Fetching medication request details for ID: ${rxId}`);
    
    const { data, errors } = await client.query({
      query: GET_MEDICATION_REQUEST,
      variables: { id: rxId },
    });
    
    if (errors) {
      console.error('Errors fetching medication request:', errors);
      return null;
    }
    
    const rx = data.medicationRequest;
    
    console.log('\nMedication Request Details:');
    console.log('-------------------------');
    console.log(`ID: ${rx.id}`);
    console.log(`Status: ${rx.status}`);
    console.log(`Intent: ${rx.intent}`);
    
    // Medication details
    const med = rx.medicationCodeableConcept;
    const medName = med.text || (med.coding?.[0]?.display || 'Unknown medication');
    console.log(`Medication: ${medName}`);
    
    if (med.coding && med.coding.length > 0) {
      const coding = med.coding[0];
      console.log(`  Code: ${coding.code} (System: ${coding.system})`);
    }
    
    // Patient and requester
    console.log(`Patient: ${rx.subject.display || rx.subject.reference}`);
    console.log(`Prescriber: ${rx.requester?.display || rx.requester?.reference || 'Unknown'}`);
    console.log(`Date Prescribed: ${rx.authoredOn}`);
    
    // Dosage instructions
    if (rx.dosageInstruction && rx.dosageInstruction.length > 0) {
      console.log('\nDosage Instructions:');
      rx.dosageInstruction.forEach((dosage: any, index: number) => {
        console.log(`  ${index + 1}. ${dosage.text || 'No text instructions'}`);
        
        // Timing
        if (dosage.timing?.repeat) {
          const repeat = dosage.timing.repeat;
          console.log(`     Frequency: ${repeat.frequency || '1'} time(s) per ${repeat.period || '1'} ${repeat.periodUnit || 'day'}`);
        }
        
        // Dose amount
        if (dosage.doseAndRate && dosage.doseAndRate.length > 0) {
          const dose = dosage.doseAndRate[0]?.doseQuantity;
          if (dose) {
            console.log(`     Amount: ${dose.value} ${dose.unit}`);
          }
        }
      });
    }
    
    // Prior authorization
    if (rx.priorAuthorization) {
      const pa = rx.priorAuthorization;
      console.log('\nPrior Authorization:');
      console.log(`  Status: ${pa.status}`);
      console.log(`  Outcome: ${pa.outcome || 'Pending'}`);
      
      if (pa.validPeriod) {
        console.log(`  Valid From: ${pa.validPeriod.start || 'N/A'}`);
        console.log(`  Valid Until: ${pa.validPeriod.end || 'N/A'}`);
      }
    }
    
    return rx;
  } catch (error) {
    console.error('Error fetching medication request details:', error);
    return null;
  }
}

async function createNewMedicationRequest(patientId: string, medicationInfo: any) {
  try {
    console.log(`Creating new medication request for patient: ${patientId}`);
    
    const input = {
      status: "active",
      intent: "order",
      medicationCodeableConcept: {
        coding: [
          {
            system: "http://www.nlm.nih.gov/research/umls/rxnorm",
            code: medicationInfo.code,
            display: medicationInfo.display
          }
        ],
        text: medicationInfo.text
      },
      subjectId: patientId,
      requesterId: medicationInfo.requesterId,
      dosageInstructions: [medicationInfo.instructions]
    };
    
    const { data, errors } = await client.mutate({
      mutation: CREATE_MEDICATION_REQUEST,
      variables: { input },
    });
    
    if (errors) {
      console.error('Errors creating medication request:', errors);
      return null;
    }
    
    const result = data.createMedicationRequest;
    
    if (result.success) {
      console.log('\nMedication Request Created Successfully!');
      console.log(`Message: ${result.message || 'Creation successful'}`);
      console.log(`New Medication Request ID: ${result.medicationRequest.id}`);
      console.log(`Status: ${result.medicationRequest.status}`);
      console.log(`Medication: ${result.medicationRequest.medicationCodeableConcept.text}`);
    } else {
      console.error(`Failed to create medication request: ${result.message}`);
    }
    
    return result;
  } catch (error) {
    console.error('Error creating medication request:', error);
    return null;
  }
}

async function updatePatientContact(patientId: string, newContactInfo: any) {
  try {
    console.log(`Updating contact information for patient: ${patientId}`);
    
    const input = {
      telecom: newContactInfo.telecom
    };
    
    const { data, errors } = await client.mutate({
      mutation: UPDATE_PATIENT,
      variables: { id: patientId, input },
    });
    
    if (errors) {
      console.error('Errors updating patient:', errors);
      return null;
    }
    
    const result = data.updatePatient;
    
    if (result.success) {
      console.log('\nPatient Updated Successfully!');
      console.log(`Message: ${result.message || 'Update successful'}`);
      
      console.log('\nUpdated Contact Information:');
      result.patient.telecom.forEach((contact: any) => {
        console.log(`${contact.system}: ${contact.value}`);
      });
    } else {
      console.error(`Failed to update patient: ${result.message}`);
    }
    
    return result;
  } catch (error) {
    console.error('Error updating patient:', error);
    return null;
  }
}

// Main function to run the examples
async function runExamples() {
  try {
    // Example 1: Fetch a patient's profile
    await fetchPatientProfile('patient-12345');
    
    // Example 2: Search for patients by name
    const searchResults = await searchPatientsByName('Smith');
    
    // Example 3: Get medication request details
    if (searchResults && searchResults.length > 0) {
      // For an actual patient ID from the search results
      const patientId = searchResults[0].id;
      console.log(`\nFetching medication requests for patient ${patientId}...`);
      
      // First get the patient to access their medication requests
      const patientDetails = await fetchPatientProfile(patientId);
      
      if (patientDetails && patientDetails.medicationRequests && patientDetails.medicationRequests.length > 0) {
        const rxId = patientDetails.medicationRequests[0].id;
        await getMedicationRequestDetails(rxId);
      } else {
        console.log('No medication requests found for this patient.');
        
        // Example 4: Create a new medication request
        console.log('\nCreating a new medication request...');
        await createNewMedicationRequest(patientId, {
          code: '308056",
          display: "Amoxicillin 500 MG Oral Capsule",
          text: "Amoxicillin 500mg capsules",
          requesterId: "practitioner-67890",
          instructions: "Take one capsule by mouth three times daily for 10 days"
        });
      }
      
      // Example 5: Update patient contact information
      console.log('\nUpdating patient contact information...');
      await updatePatientContact(patientId, {
        telecom: [
          { system: "phone", value: "555-123-4567", use: "home" },
          { system: "email", value: "patient@example.com", use: "work" }
        ]
      });
    }
    
    console.log('\nAll examples completed.');
  } catch (error) {
    console.error('Error running examples:', error);
  } finally {
    // Clean up resources
    client.stop();
  }
}

// Run the examples
runExamples();
```

### Create a Client-side App (React Example)

For a more complete client-side application example, create a React app that uses the Federated Graph API:

```bash
# Create a new React application
npx create-react-app healthcare-portal --template typescript
cd healthcare-portal

# Install dependencies
npm install @apollo/client graphql
```

Create a basic patient search and display component:

```tsx
// src/components/PatientSearch.tsx
import React, { useState } from 'react';
import { gql, useQuery, useLazyQuery } from '@apollo/client';

const SEARCH_PATIENTS = gql`
  query SearchPatients($name: String) {
    searchPatients(name: $name) {
      id
      name {
        given
        family
      }
      gender
      birthDate
    }
  }
`;

const GET_PATIENT_DETAILS = gql`
  query GetPatientDetails($id: ID!) {
    patient(id: $id) {
      id
      name {
        given
        family
        prefix
      }
      gender
      birthDate
      address {
        line
        city
        state
        postalCode
      }
      telecom {
        system
        value
        use
      }
      medicationRequests {
        id
        status
        medicationCodeableConcept {
          coding {
            display
          }
          text
        }
        authoredOn
      }
    }
  }
`;

const PatientSearch: React.FC = () => {
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedPatientId, setSelectedPatientId] = useState<string | null>(null);
  
  // Search query
  const { loading: searchLoading, error: searchError, data: searchResults, refetch } = 
    useQuery(SEARCH_PATIENTS, {
      variables: { name: searchTerm },
      skip: !searchTerm,
    });
  
  // Patient details query (lazy loaded)
  const [getPatientDetails, { loading: detailsLoading, error: detailsError, data: patientDetails }] = 
    useLazyQuery(GET_PATIENT_DETAILS);
  
  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    refetch({ name: searchTerm });
  };
  
  const handlePatientSelect = (id: string) => {
    setSelectedPatientId(id);
    getPatientDetails({ variables: { id } });
  };
  
  // Format patient name
  const formatName = (name: any) => {
    if (!name) return 'Unknown';
    return [
      name.prefix?.join(' ') || '',
      name.given?.join(' ') || '',
      name.family || ''
    ].filter(Boolean).join(' ');
  };
  
  return (
    <div className="patient-search-container">
      <h1>Patient Portal</h1>
      
      <form onSubmit={handleSearch} className="search-form">
        <div className="form-group">
          <label htmlFor="patientSearch">Search Patients:</label>
          <input
            type="text"
            id="patientSearch"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            placeholder="Enter patient name"
            required
          />
        </div>
        <button type="submit">Search</button>
      </form>
      
      {searchLoading && <p>Searching for patients...</p>}
      {searchError && <p className="error">Error searching patients: {searchError.message}</p>}
      
      {searchResults?.searchPatients && (
        <div className="search-results">
          <h2>Search Results</h2>
          {searchResults.searchPatients.length === 0 ? (
            <p>No patients found matching "{searchTerm}"</p>
          ) : (
            <ul>
              {searchResults.searchPatients.map((patient: any) => (
                <li key={patient.id} onClick={() => handlePatientSelect(patient.id)}>
                  <strong>{formatName(patient.name[0])}</strong>
                  <div>Gender: {patient.gender}, DOB: {patient.birthDate}</div>
                </li>
              ))}
            </ul>
          )}
        </div>
      )}
      
      {detailsLoading && <p>Loading patient details...</p>}
      {detailsError && <p className="error">Error loading details: {detailsError.message}</p>}
      
      {patientDetails?.patient && (
        <div className="patient-details">
          <h2>Patient Details</h2>
          <div className="patient-profile">
            <h3>{formatName(patientDetails.patient.name[0])}</h3>
            <div className="demographics">
              <p><strong>Gender:</strong> {patientDetails.patient.gender}</p>
              <p><strong>Date of Birth:</strong> {patientDetails.patient.birthDate}</p>
            </div>
            
            {patientDetails.patient.address && patientDetails.patient.address.length > 0 && (
              <div className="address">
                <h4>Address</h4>
                <p>
                  {patientDetails.patient.address[0].line?.join(', ')}<br />
                  {patientDetails.patient.address[0].city}, {patientDetails.patient.address[0].state} {patientDetails.patient.address[0].postalCode}
                </p>
              </div>
            )}
            
            {patientDetails.patient.telecom && patientDetails.patient.telecom.length > 0 && (
              <div className="contact-info">
                <h4>Contact Information</h4>
                <ul>
                  {patientDetails.patient.telecom.map((contact: any, index: number) => (
                    <li key={index}>
                      <strong>{contact.system}:</strong> {contact.value} ({contact.use || 'primary'})
                    </li>
                  ))}
                </ul>
              </div>
            )}
            
            {patientDetails.patient.medicationRequests && (
              <div className="medications">
                <h4>Current Medications</h4>
                {patientDetails.patient.medicationRequests.length === 0 ? (
                  <p>No medications on file</p>
                ) : (
                  <ul>
                    {patientDetails.patient.medicationRequests.map((rx: any) => (
                      <li key={rx.id}>
                        <strong>
                          {rx.medicationCodeableConcept?.text || 
                            rx.medicationCodeableConcept?.coding?.[0]?.display || 
                            'Unknown medication'}
                        </strong>
                        <div>Status: {rx.status}, Prescribed: {rx.authoredOn}</div>
                      </li>
                    ))}
                  </ul>
                )}
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
};

export default PatientSearch;
```

Configure Apollo Client in your React app:

```tsx
// src/index.tsx
import React from 'react';
import ReactDOM from 'react-dom';
import { ApolloClient, InMemoryCache, ApolloProvider, HttpLink } from '@apollo/client';
import App from './App';
import './index.css';

const client = new ApolloClient({
  link: new HttpLink({
    uri: process.env.REACT_APP_GRAPHQL_ENDPOINT || 'http://localhost:4000/graphql',
    headers: {
      Authorization: `Bearer ${process.env.REACT_APP_API_KEY || 'development-key'}`,
    },
  }),
  cache: new InMemoryCache(),
});

ReactDOM.render(
  <React.StrictMode>
    <ApolloProvider client={client}>
      <App />
    </ApolloProvider>
  </React.StrictMode>,
  document.getElementById('root')
);
```

## Step 6: Run and Test the Examples

### Node.js Console Application

Run the Node.js examples with:

```bash
# Run the queries and mutations example
npx ts-node healthcare-queries.ts
```

### React Application

Run the React application with:

```bash
# Start the React development server
npm start
```

Browse to http://localhost:3000 to see the patient search application.

## Step 7: Understand the Federation Schema

The Federated Graph API combines data from multiple subgraphs:

1. **FHIR Subgraph**: Core healthcare resources (Patient, Practitioner, etc.)
2. **PRESCRIPTIONS Subgraph**: Medication and prescription data
3. **INSURANCE Subgraph**: Coverage and benefit information
4. **PRIOR_AUTH Subgraph**: Prior authorization workflows

Each subgraph is owned by different teams and can evolve independently while contributing to a unified API.

## Troubleshooting Common Issues

### Authentication Problems

1. **Invalid API token**:
   - Check that your API key or OAuth token is valid and not expired
   - Verify you're using the correct authentication method (Bearer token, etc.)
   - Look for 401/403 error responses

2. **CORS issues**:
   - For web applications, ensure the server has CORS configured to allow your client domain
   - Check browser console for CORS errors

### GraphQL Operation Issues

1. **Invalid query syntax**:
   - Use Apollo Sandbox/Explorer to validate your queries: http://localhost:4000
   - Check error messages for specific syntax issues
   - Verify field names match the schema

2. **Missing required fields**:
   - Ensure all non-nullable fields have values in mutations
   - Check for proper variable formatting

3. **Type issues**:
   - Verify ID values are passed as strings (GraphQL IDs are strings)
   - Check that input types match schema requirements

### Connectivity Issues

1. **Cannot connect to router**:
   - Verify the router is running: `curl -X POST http://localhost:4000/graphql`
   - Check for network errors in the console
   - For Docker setups, verify port mapping

2. **Schema errors**:
   - If using a local schema, validate it with a tool like Apollo Rover

## Advanced Features

### Implementing Entity Resolvers

For references across subgraphs, implement entity resolvers:

```typescript
// Patient entity resolver example
export const resolvers = {
  Patient: {
    __resolveReference: async (ref, { dataSources }) => {
      return dataSources.fhirApi.getPatient(ref.id);
    },
    medicationRequests: async (patient, _, { dataSources }) => {
      return dataSources.prescriptionApi.getMedicationRequestsByPatientId(patient.id);
    }
  }
};
```

### Using Apollo Client for Reactive UIs

For more complex UIs, consider using Apollo's reactive features:

```typescript
// Dynamic query with variables
const GET_PATIENT_MEDICATIONS = gql`
  query GetPatientMedications($patientId: ID!) {
    patient(id: $patientId) {
      id
      medicationRequests {
        id
        medicationCodeableConcept {
          text
        }
      }
    }
  }
`;

function MedicationList({ patientId }) {
  const { loading, error, data } = useQuery(GET_PATIENT_MEDICATIONS, {
    variables: { patientId },
    pollInterval: 30000, // Real-time updates every 30 seconds
  });

  if (loading) return <p>Loading medications...</p>;
  if (error) return <p>Error loading medications: {error.message}</p>;

  return (
    <ul>
      {data.patient.medicationRequests.map(rx => (
        <li key={rx.id}>{rx.medicationCodeableConcept.text}</li>
      ))}
    </ul>
  );
}
```

## Integration with Other Core Components

The Federated Graph API is designed to integrate seamlessly with other core components of the CoverMyMeds architecture. Here are detailed integration patterns for each component:

### FHIR Interoperability Platform Integration

The Federated Graph API can expose FHIR resources through GraphQL resolvers:

```typescript
// federation-fhir-integration.ts
import { ApolloClient, InMemoryCache, HttpLink, gql } from '@apollo/client/core';
import { AidboxClient } from '@aidbox/sdk-r4';
import fetch from 'cross-fetch';

// Configure Apollo Client for the Federated Graph API
const graphqlClient = new ApolloClient({
  link: new HttpLink({
    uri: 'http://localhost:4000/graphql', // Replace with your GraphQL endpoint
    headers: {
      Authorization: 'Bearer YOUR_API_KEY',
    },
    fetch,
  }),
  cache: new InMemoryCache(),
});

// Configure FHIR Client
const fhirClient = new AidboxClient({
  url: 'http://localhost:8888', // Replace with your FHIR server URL
  auth: {
    username: 'admin',
    password: 'password', // Replace with your FHIR server password
  },
});

// Example: Implement a resolver that fetches data from FHIR
async function fhirResolver(typeName: string, id: string) {
  try {
    // Fetch the resource from FHIR
    const resource = await fhirClient.fhirRead(typeName, id);
    return resource;
  } catch (error) {
    console.error(`Error fetching ${typeName}/${id} from FHIR:`, error);
    throw error;
  }
}

// Example: Query the Federated Graph API for a patient, which will resolve to FHIR data
async function getPatientWithMedicationRequests(patientId: string) {
  try {
    const PATIENT_QUERY = gql`
      query GetPatientWithMedications($id: ID!) {
        patient(id: $id) {
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
              coding {
                display
              }
              text
            }
          }
        }
      }
    `;

    const { data } = await graphqlClient.query({
      query: PATIENT_QUERY,
      variables: { id: patientId },
    });

    console.log('Patient data from federated graph:', data.patient);
    return data.patient;
  } catch (error) {
    console.error('Error querying federated graph:', error);
    throw error;
  }
}

// Example: Create a medication request in FHIR and query it through GraphQL
async function createMedicationRequestAndQuery() {
  try {
    // 1. First create a patient in FHIR
    const patient = await fhirClient.fhirCreate('Patient', {
      resourceType: 'Patient',
      name: [{ family: 'Wagner', given: ['Robert'] }],
      gender: 'male',
      birthDate: '1965-07-12',
    });
    console.log('Created patient in FHIR:', patient.id);

    // 2. Create a medication request for this patient
    const medicationRequest = await fhirClient.fhirCreate('MedicationRequest', {
      resourceType: 'MedicationRequest',
      status: 'active',
      intent: 'order',
      medicationCodeableConcept: {
        coding: [{
          system: 'http://www.nlm.nih.gov/research/umls/rxnorm',
          code: '312617',
          display: 'Lisinopril 20 MG Oral Tablet'
        }],
        text: 'Lisinopril 20mg tablets',
      },
      subject: {
        reference: `Patient/${patient.id}`,
      },
      authoredOn: new Date().toISOString(),
    });
    console.log('Created medication request in FHIR:', medicationRequest.id);

    // 3. Now query the federated graph to get this data
    // In a real application, you might need to wait for the federation 
    // to recognize the new resources
    console.log('Querying patient data through the Federated Graph API...');
    const patientData = await getPatientWithMedicationRequests(patient.id);
    
    return { patient, medicationRequest, patientData };
  } catch (error) {
    console.error('Error in FHIR-GraphQL integration flow:', error);
    throw error;
  }
}

// Execute the example if run directly
if (require.main === module) {
  createMedicationRequestAndQuery()
    .then(result => {
      console.log('Integration example completed successfully');
    })
    .catch(console.error);
}
```

Run this integration example:

```bash
npx ts-node federation-fhir-integration.ts
```

### Event Broker Integration

The Federated Graph API can respond to events from the Event Broker:

```typescript
// federation-event-integration.ts
import { Kafka } from 'kafkajs';
import { ApolloClient, InMemoryCache, HttpLink, gql } from '@apollo/client/core';
import fetch from 'cross-fetch';

// Configure Kafka client
const kafka = new Kafka({
  clientId: 'federated-graph-service',
  brokers: ['localhost:9092'], // Replace with your broker addresses
});

const consumer = kafka.consumer({ groupId: 'federated-graph-consumer' });
const producer = kafka.producer();

// Configure GraphQL client
const client = new ApolloClient({
  link: new HttpLink({
    uri: 'http://localhost:4000/graphql', // Replace with your GraphQL endpoint
    headers: {
      Authorization: 'Bearer YOUR_API_KEY',
    },
    fetch,
  }),
  cache: new InMemoryCache(),
});

// Example: Subscribe to events and update cache or trigger GraphQL operations
async function consumeHealthcareEvents() {
  try {
    await consumer.connect();
    
    // Subscribe to patient update events
    await consumer.subscribe({
      topics: ['healthcare.patient.updated'],
      fromBeginning: false,
    });
    
    console.log('Starting to consume healthcare events...');
    
    await consumer.run({
      eachMessage: async ({ topic, partition, message }) => {
        try {
          const eventString = message.value?.toString();
          if (!eventString) return;
          
          const event = JSON.parse(eventString);
          console.log(`Processing ${event.eventType} event for ${event.data.resourceType}/${event.data.id}`);
          
          // Example: Invalidate cache for the updated resource
          client.cache.evict({ 
            id: client.cache.identify({
              __typename: event.data.resourceType,
              id: event.data.id,
            }),
          });
          client.cache.gc();
          
          console.log(`Invalidated cache for ${event.data.resourceType}/${event.data.id}`);
          
          // Example: Execute a query to refetch the updated data
          if (event.data.resourceType === 'Patient') {
            const PATIENT_QUERY = gql`
              query GetPatient($id: ID!) {
                patient(id: $id) {
                  id
                  name {
                    given
                    family
                  }
                  gender
                  birthDate
                }
              }
            `;
            
            const { data } = await client.query({
              query: PATIENT_QUERY,
              variables: { id: event.data.id },
              fetchPolicy: 'network-only', // Force refetch from server
            });
            
            console.log('Refetched patient data:', data.patient);
            
            // Example: Publish an event indicating the GraphQL data was updated
            await producer.connect();
            await producer.send({
              topic: 'graphql.data.updated',
              messages: [
                {
                  key: event.data.id,
                  value: JSON.stringify({
                    eventId: `evt-${Date.now()}`,
                    eventType: 'graphql.patient.updated',
                    timestamp: new Date().toISOString(),
                    data: {
                      typename: 'Patient',
                      id: event.data.id,
                      fields: ['name', 'gender', 'birthDate'],
                    },
                    metadata: {
                      source: 'federated-graph-api',
                      triggerEvent: event.eventId,
                    },
                  }),
                },
              ],
            });
            
            await producer.disconnect();
          }
        } catch (error) {
          console.error('Error processing event:', error);
        }
      },
    });
  } catch (error) {
    console.error('Error in event consumer:', error);
    throw error;
  }
}

// Example: Simulate publishing a patient update event to test the consumer
async function publishPatientUpdateEvent(patientId: string) {
  try {
    await producer.connect();
    
    const event = {
      eventId: `evt-${Date.now()}`,
      eventType: 'Patient.updated',
      timestamp: new Date().toISOString(),
      data: {
        resourceType: 'Patient',
        id: patientId,
        name: [{ family: 'Smith', given: ['John', 'Robert'] }],
        gender: 'male',
        birthDate: '1982-08-24',
      },
      metadata: {
        source: 'fhir-platform',
        version: '1.0',
      },
    };
    
    await producer.send({
      topic: 'healthcare.patient.updated',
      messages: [
        {
          key: patientId,
          value: JSON.stringify(event),
          headers: {
            'event-type': Buffer.from(event.eventType),
            'resource-type': Buffer.from('Patient'),
          },
        },
      ],
    });
    
    console.log(`Published patient update event for ${patientId}`);
    await producer.disconnect();
  } catch (error) {
    console.error('Error publishing event:', error);
    await producer.disconnect();
    throw error;
  }
}

// Execute example functions
if (require.main === module) {
  Promise.all([
    consumeHealthcareEvents(), // This will keep running
    // After 5 seconds, publish a test event
    new Promise(resolve => setTimeout(async () => {
      try {
        await publishPatientUpdateEvent('patient-123');
        resolve(null);
      } catch (error) {
        console.error(error);
        resolve(null);
      }
    }, 5000)),
  ]).catch(console.error);
}
```

Run this event integration example:

```bash
npx ts-node federation-event-integration.ts
```

### API Marketplace Integration

You can register your Federated Graph API in the API Marketplace:

```typescript
// federation-api-marketplace-integration.ts
import * as fs from 'fs';
import fetch from 'cross-fetch';

async function generateGraphQLOpenApiSpec() {
  // Fetch the GraphQL schema
  const introspectionQuery = `
    query IntrospectionQuery {
      __schema {
        queryType { name }
        mutationType { name }
        subscriptionType { name }
        types {
          ...FullType
        }
      }
    }

    fragment FullType on __Type {
      kind
      name
      description
      fields(includeDeprecated: true) {
        name
        description
        args {
          ...InputValue
        }
        type {
          ...TypeRef
        }
        isDeprecated
        deprecationReason
      }
      inputFields {
        ...InputValue
      }
      interfaces {
        ...TypeRef
      }
      enumValues(includeDeprecated: true) {
        name
        description
        isDeprecated
        deprecationReason
      }
      possibleTypes {
        ...TypeRef
      }
    }

    fragment InputValue on __InputValue {
      name
      description
      type { ...TypeRef }
      defaultValue
    }

    fragment TypeRef on __Type {
      kind
      name
      ofType {
        kind
        name
        ofType {
          kind
          name
          ofType {
            kind
            name
            ofType {
              kind
              name
              ofType {
                kind
                name
                ofType {
                  kind
                  name
                  ofType {
                    kind
                    name
                  }
                }
              }
            }
          }
        }
      }
    }
  `;

  try {
    // Make introspection query to GraphQL endpoint
    const response = await fetch('http://localhost:4000/graphql', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer YOUR_API_KEY',
      },
      body: JSON.stringify({ query: introspectionQuery }),
    });

    if (!response.ok) {
      throw new Error(`GraphQL introspection failed: ${response.statusText}`);
    }

    const introspectionResult = await response.json();
    const schema = introspectionResult.data;

    // Convert GraphQL schema to simplified OpenAPI spec
    // This is a basic transformation - a complete converter would be more complex
    const openApiSpec = {
      openapi: '3.0.0',
      info: {
        title: 'Federated Graph API',
        version: '1.0.0',
        description: 'GraphQL API for unified healthcare data access',
        contact: {
          name: 'API Support',
          email: 'api-support@covermymeds.com',
          url: 'https://developers.covermymeds.com',
        },
      },
      servers: [
        {
          url: 'https://graph-api.covermymeds.com/graphql',
          description: 'Production GraphQL API',
        },
        {
          url: 'https://graph-api-staging.covermymeds.com/graphql',
          description: 'Staging GraphQL API',
        },
      ],
      paths: {
        '/graphql': {
          post: {
            summary: 'GraphQL endpoint',
            description: 'Execute GraphQL queries, mutations, and subscriptions',
            requestBody: {
              required: true,
              content: {
                'application/json': {
                  schema: {
                    type: 'object',
                    required: ['query'],
                    properties: {
                      query: {
                        type: 'string',
                        description: 'GraphQL query string',
                      },
                      variables: {
                        type: 'object',
                        description: 'Variables for the GraphQL query',
                      },
                      operationName: {
                        type: 'string',
                        description: 'Name of the operation to execute',
                      },
                    },
                  },
                  examples: {},
                },
              },
            },
            responses: {
              '200': {
                description: 'Successful GraphQL operation',
                content: {
                  'application/json': {
                    schema: {
                      type: 'object',
                      properties: {
                        data: {
                          type: 'object',
                          description: 'Result data',
                        },
                        errors: {
                          type: 'array',
                          description: 'Errors, if any',
                          items: {
                            type: 'object',
                          },
                        },
                      },
                    },
                  },
                },
              },
              '400': {
                description: 'Invalid GraphQL request',
              },
              '401': {
                description: 'Unauthorized',
              },
            },
            security: [
              {
                bearerAuth: [],
              },
            ],
          },
        },
      },
      components: {
        securitySchemes: {
          bearerAuth: {
            type: 'http',
            scheme: 'bearer',
            bearerFormat: 'JWT',
          },
        },
        schemas: {},
      },
    };

    // Add GraphQL schema types as components
    if (schema.__schema && schema.__schema.types) {
      // Add examples for common queries
      openApiSpec.paths['/graphql'].post.requestBody.content['application/json'].examples = {
        'Patient Query': {
          value: {
            query: `
              query GetPatient($id: ID!) {
                patient(id: $id) {
                  id
                  name {
                    given
                    family
                  }
                  gender
                  birthDate
                }
              }
            `,
            variables: {
              id: 'patient-123',
            },
          },
        },
        'Medication Request Query': {
          value: {
            query: `
              query GetMedicationRequest($id: ID!) {
                medicationRequest(id: $id) {
                  id
                  status
                  medicationCodeableConcept {
                    text
                  }
                  subject {
                    reference
                  }
                }
              }
            `,
            variables: {
              id: 'medicationrequest-456',
            },
          },
        },
      };

      // Convert GraphQL types to OpenAPI schemas
      // This is a simplified conversion and would need more work for a complete spec
      schema.__schema.types.forEach(type => {
        if (type.kind === 'OBJECT' && !type.name.startsWith('__')) {
          const properties = {};
          
          if (type.fields) {
            type.fields.forEach(field => {
              properties[field.name] = {
                type: 'object', // Simplified mapping
                description: field.description || `${field.name} field`,
              };
            });
          }
          
          openApiSpec.components.schemas[type.name] = {
            type: 'object',
            description: type.description || `${type.name} type`,
            properties,
          };
        }
      });
    }

    // Write the OpenAPI specification to file
    fs.writeFileSync('federated-graph-api-spec.json', JSON.stringify(openApiSpec, null, 2));
    console.log('OpenAPI specification generated: federated-graph-api-spec.json');
    console.log('This file can be used to register the Federated Graph API in the API Marketplace.');

    return openApiSpec;
  } catch (error) {
    console.error('Error generating OpenAPI specification:', error);
    throw error;
  }
}

// Generate OpenAPI documentation from GraphQL schema
if (require.main === module) {
  generateGraphQLOpenApiSpec().catch(console.error);
}
```

Generate the API Marketplace specification:

```bash
npx ts-node federation-api-marketplace-integration.ts
```

### Using These Integrations

To effectively integrate the Federated Graph API with other core components:

1. **FHIR Integration**:
   - Map FHIR resources to GraphQL types and fields
   - Implement resolvers that fetch data from the FHIR API
   - Handle authorization and data transformation between GraphQL and FHIR

2. **Event-Driven Integration**:
   - Subscribe to events from the Event Broker to keep GraphQL data fresh
   - Implement event handlers that update the GraphQL cache or trigger refetches
   - Publish events when GraphQL operations modify underlying data

3. **API Discovery**:
   - Register your GraphQL schema in the API Marketplace
   - Document query capabilities, mutations, and subscription operations
   - Provide example queries and expected responses

4. **Cross-Component Data Flow**:
   - Use the Federated Graph API as a unified entry point to access data from multiple systems
   - Implement entity resolvers that can extend resources across subgraphs
   - Design consistent naming and relationship patterns across all systems

These integration patterns enable building powerful healthcare applications that combine data from multiple sources with a single, unified API.

## Next Steps

Now that you have a foundation with the Federated Graph API, consider these next steps:

- [Explore Advanced GraphQL Operations](../03-advanced-patterns/advanced-graphql-operations.md)
- [Integration Guide: FHIR Interoperability Platform](../../fhir-interoperability-platform/01-getting-started/quick-start.md)
- [Integration Guide: Event Broker](../../event-broker/01-getting-started/quick-start.md)
- [Integration Guide: API Marketplace](../../api-marketplace/01-getting-started/quick-start.md)
- [Best Practices: GraphQL Schema Design](../03-advanced-patterns/schema-design.md)
- [Error Handling & Troubleshooting](../03-advanced-patterns/error-handling.md)

## Related Resources
- [Apollo GraphQL Documentation](https://www.apollographql.com/docs/)
- [GraphQL Federation Specification](https://www.apollographql.com/docs/federation/federation-spec/)
- [Apollo Router Documentation](https://www.apollographql.com/docs/router/)
- [Apollo Client Documentation](https://www.apollographql.com/docs/react/)
- [Federated Graph API Overview](./overview.md)
- [Federated Graph API Architecture](./architecture.md)
- [Federated Graph API Key Concepts](./key-concepts.md)
