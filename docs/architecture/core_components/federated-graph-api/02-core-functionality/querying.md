# Querying the Federated Graph

## Introduction

Effective querying is essential for getting the most value from your Federated Graph API. This guide explains how to construct and optimize GraphQL queries for healthcare data, covering basic query patterns, query variables, fragments, error handling, and pagination strategies. By mastering these techniques, you can create efficient, maintainable queries that retrieve exactly the data your applications need.

### Quick Start

1. Use the GraphQL Playground or Apollo Studio Explorer to experiment with queries
2. Structure queries to request only the fields you need
3. Utilize variables for dynamic queries
4. Create fragments for reusable field selections
5. Implement proper error handling in your client applications

### Related Components

- [Federated Graph API Overview](../01-getting-started/overview.md): Understand the overall architecture
- [Legacy System Integration](legacy-integration.md): Learn about integrating legacy systems in your graph
- [Query Optimization](../03-advanced-patterns/query-optimization.md): Advanced techniques for optimizing queries
- [Authentication](authentication.md): Secure your queries with proper authentication

## Basic Query Patterns

GraphQL queries allow you to request exactly the data you need. This section covers the fundamental patterns for querying healthcare data.

### Simple Queries

Start with simple queries that retrieve specific resources.

```graphql
# Example: Query a single patient by ID
query GetPatient {
  patient(id: "123") {
    id
    name {
      given
      family
    }
    birthDate
    gender
    address {
      line
      city
      state
      postalCode
      country
    }
    telecom {
      system
      value
      use
    }
  }
}
```

### Nested Queries

Retrieve related data in a single query using nested fields.

```graphql
# Example: Query a patient with related clinical data
query GetPatientWithClinicalData {
  patient(id: "123") {
    id
    name {
      given
      family
    }
    birthDate
    gender
    # Nested query for conditions
    conditions {
      id
      clinicalStatus {
        coding {
          code
          display
        }
      }
      code {
        coding {
          system
          code
          display
        }
      }
      onsetDateTime
      recordedDate
    }
    # Nested query for observations
    observations {
      id
      code {
        coding {
          system
          code
          display
        }
      }
      valueQuantity {
        value
        unit
      }
      effectiveDateTime
      status
    }
  }
}
```

### Multiple Root Queries

Combine multiple root-level queries in a single request.

```graphql
# Example: Query multiple resources in one request
query GetPatientAndPractitioner {
  patient(id: "123") {
    id
    name {
      given
      family
    }
    birthDate
  }
  
  practitioner(id: "456") {
    id
    name {
      given
      family
    }
    qualification {
      code {
        coding {
          display
        }
      }
    }
  }
  
  organization(id: "789") {
    id
    name
    address {
      line
      city
      state
    }
  }
}
```

### Search Queries

Use search parameters to find resources matching specific criteria.

```graphql
# Example: Search for patients matching criteria
query SearchPatients {
  searchPatients(family: "Smith", gender: FEMALE) {
    edges {
      node {
        id
        name {
          given
          family
        }
        birthDate
        gender
        address {
          city
          state
        }
      }
      cursor
    }
    pageInfo {
      hasNextPage
      endCursor
    }
    totalCount
  }
}
```

## Query Variables

Query variables allow you to make your queries dynamic and reusable. This section explains how to use variables effectively.

### Defining Variables

Define variables in your query and pass values at runtime.

```graphql
# Example: Query with variables
query GetPatient($id: ID!) {
  patient(id: $id) {
    id
    name {
      given
      family
    }
    birthDate
    gender
  }
}

# Variables (JSON)
{
  "id": "123"
}
```

### Optional Variables with Default Values

Use default values for optional variables.

```graphql
# Example: Search query with optional variables and defaults
query SearchPatients(
  $name: String,
  $gender: Gender,
  $count: Int = 10,
  $page: String
) {
  searchPatients(
    name: $name,
    gender: $gender,
    _count: $count,
    _page: $page
  ) {
    edges {
      node {
        id
        name {
          given
          family
        }
        birthDate
        gender
      }
      cursor
    }
    pageInfo {
      hasNextPage
      endCursor
    }
  }
}

# Variables (JSON)
{
  "name": "Smith",
  "gender": "FEMALE"
  # count will default to 10
}
```

### Variable Types and Validation

GraphQL enforces type checking for variables.

```graphql
# Example: Complex variable types
query SearchObservations(
  $patientId: ID!,
  $dateRange: DateRangeInput,
  $codes: [String!]
) {
  searchObservations(
    patient: $patientId,
    date: $dateRange,
    code: $codes
  ) {
    edges {
      node {
        id
        code {
          coding {
            display
          }
        }
        valueQuantity {
          value
          unit
        }
        effectiveDateTime
      }
    }
  }
}

# Variables (JSON)
{
  "patientId": "123",
  "dateRange": {
    "ge": "2023-01-01",
    "le": "2023-12-31"
  },
  "codes": [
    "8480-6",  # Systolic blood pressure
    "8462-4"   # Diastolic blood pressure
  ]
}
```

## Fragments and Reusable Components

Fragments allow you to create reusable pieces of queries. This section explains how to use fragments effectively.

### Basic Fragments

Create fragments for common field selections.

```graphql
# Example: Using fragments for common fields
fragment PatientIdentity on Patient {
  id
  name {
    given
    family
    prefix
  }
  birthDate
  gender
}

fragment PatientContact on Patient {
  telecom {
    system
    value
    use
  }
  address {
    line
    city
    state
    postalCode
    country
  }
}

query GetPatient($id: ID!) {
  patient(id: $id) {
    ...PatientIdentity
    ...PatientContact
    generalPractitioner {
      reference
      display
    }
  }
}
```

### Nested Fragments

Fragments can include other fragments.

```graphql
# Example: Nested fragments
fragment CodeableConcept on CodeableConcept {
  coding {
    system
    code
    display
  }
  text
}

fragment ConditionSummary on Condition {
  id
  clinicalStatus {
    ...CodeableConcept
  }
  code {
    ...CodeableConcept
  }
  onsetDateTime
  recordedDate
}

query GetPatientConditions($patientId: ID!) {
  patient(id: $patientId) {
    ...PatientIdentity
    conditions {
      ...ConditionSummary
    }
  }
}
```

### Fragments with Type Conditions

Use fragments with type conditions for polymorphic fields.

```graphql
# Example: Fragments with type conditions
fragment PatientReference on Patient {
  id
  name {
    given
    family
  }
  birthDate
}

fragment PractitionerReference on Practitioner {
  id
  name {
    given
    family
  }
  qualification {
    code {
      coding {
        display
      }
    }
  }
}

fragment OrganizationReference on Organization {
  id
  name
  address {
    line
    city
  }
}

query GetReference($reference: String!) {
  resolveReference(reference: $reference) {
    ... on Patient {
      ...PatientReference
    }
    ... on Practitioner {
      ...PractitionerReference
    }
    ... on Organization {
      ...OrganizationReference
    }
  }
}
```

## Error Handling

Proper error handling is essential for robust applications. This section explains how to handle GraphQL errors effectively.

### GraphQL Error Structure

GraphQL errors have a consistent structure that includes message, locations, path, and extensions.

```json
{
  "errors": [
    {
      "message": "Patient with ID '999' not found",
      "locations": [{ "line": 2, "column": 3 }],
      "path": ["patient"],
      "extensions": {
        "code": "NOT_FOUND",
        "classification": "DataFetchingException"
      }
    }
  ],
  "data": {
    "patient": null
  }
}
```

### Client-Side Error Handling

Implement proper error handling in your client applications.

```typescript
// Example: Error handling with Apollo Client
import { ApolloClient, InMemoryCache, ApolloLink, HttpLink } from '@apollo/client';
import { onError } from '@apollo/client/link/error';

// Create an error handling link
const errorLink = onError(({ graphQLErrors, networkError }) => {
  if (graphQLErrors) {
    graphQLErrors.forEach(({ message, locations, path, extensions }) => {
      console.error(
        `[GraphQL error]: Message: ${message}, Location: ${locations}, Path: ${path}`,
        extensions
      );
      
      // Handle specific error codes
      switch (extensions?.code) {
        case 'UNAUTHENTICATED':
          // Redirect to login page or refresh token
          redirectToLogin();
          break;
        case 'FORBIDDEN':
          // Show permission denied message
          showPermissionDenied();
          break;
        case 'NOT_FOUND':
          // Show not found message
          showNotFound();
          break;
        default:
          // Show generic error message
          showErrorMessage(message);
      }
    });
  }
  
  if (networkError) {
    console.error(`[Network error]: ${networkError}`);
    // Show network error message
    showNetworkError();
  }
});

// Create the Apollo Client with error handling
const client = new ApolloClient({
  link: ApolloLink.from([
    errorLink,
    new HttpLink({ uri: 'https://api.example.com/graphql' })
  ]),
  cache: new InMemoryCache()
});
```

### Component-Level Error Handling

Handle errors at the component level for a better user experience.

```tsx
// Example: React component with error handling
import React from 'react';
import { useQuery } from '@apollo/client';
import { GET_PATIENT } from './queries';

function PatientProfile({ patientId }) {
  const { loading, error, data } = useQuery(GET_PATIENT, {
    variables: { id: patientId },
    errorPolicy: 'all' // Return partial data even if there are errors
  });
  
  if (loading) return <LoadingSpinner />;
  
  // Handle different error scenarios
  if (error) {
    // Check for specific error codes
    const errorCode = error.graphQLErrors?.[0]?.extensions?.code;
    
    switch (errorCode) {
      case 'NOT_FOUND':
        return <NotFoundMessage message="Patient not found" />;
      case 'FORBIDDEN':
        return <AccessDeniedMessage message="You don't have permission to view this patient" />;
      case 'UNAUTHENTICATED':
        return <LoginPrompt message="Please log in to view patient data" />;
      default:
        return <ErrorMessage error={error} />;
    }
  }
  
  // Render the patient data
  const patient = data?.patient;
  if (!patient) return <NotFoundMessage message="Patient not found" />;
  
  return (
    <div className="patient-profile">
      <h1>{patient.name[0]?.family}, {patient.name[0]?.given.join(' ')}</h1>
      <p>Birth Date: {formatDate(patient.birthDate)}</p>
      <p>Gender: {formatGender(patient.gender)}</p>
      {/* Additional patient information */}
    </div>
  );
}
```

### Partial Results

GraphQL can return partial results when some fields have errors.

```typescript
// Example: Handling partial results
function PatientDashboard({ patientId }) {
  const { loading, error, data } = useQuery(GET_PATIENT_DASHBOARD, {
    variables: { id: patientId },
    errorPolicy: 'all' // Return partial data even if there are errors
  });
  
  if (loading) return <LoadingSpinner />;
  
  // Extract patient data even if there are errors
  const patient = data?.patient;
  if (!patient) return <NotFoundMessage message="Patient not found" />;
  
  // Check for specific field errors
  const hasConditionsError = error?.graphQLErrors?.some(
    err => err.path?.includes('conditions')
  );
  
  const hasObservationsError = error?.graphQLErrors?.some(
    err => err.path?.includes('observations')
  );
  
  return (
    <div className="patient-dashboard">
      <PatientHeader patient={patient} />
      
      <div className="dashboard-panels">
        {/* Conditions panel with error handling */}
        <Panel title="Conditions">
          {hasConditionsError ? (
            <ErrorMessage message="Unable to load conditions" />
          ) : patient.conditions?.length > 0 ? (
            <ConditionsList conditions={patient.conditions} />
          ) : (
            <EmptyState message="No conditions recorded" />
          )}
        </Panel>
        
        {/* Observations panel with error handling */}
        <Panel title="Recent Observations">
          {hasObservationsError ? (
            <ErrorMessage message="Unable to load observations" />
          ) : patient.observations?.length > 0 ? (
            <ObservationsList observations={patient.observations} />
          ) : (
            <EmptyState message="No observations recorded" />
          )}
        </Panel>
        
        {/* Additional panels */}
      </div>
    </div>
  );
}
```

## Pagination Strategies

Pagination is essential for handling large datasets. This section explains different pagination strategies for GraphQL queries.

### Cursor-Based Pagination

Cursor-based pagination is recommended for most healthcare data queries.

```graphql
# Example: Cursor-based pagination
query SearchPatients($cursor: String, $limit: Int = 10) {
  searchPatients(_count: $limit, _page: $cursor) {
    edges {
      node {
        id
        name {
          given
          family
        }
        birthDate
      }
      cursor
    }
    pageInfo {
      hasNextPage
      hasPreviousPage
      startCursor
      endCursor
    }
    totalCount
  }
}

# Variables for first page
{
  "limit": 10
}

# Variables for next page
{
  "cursor": "next-page-token-from-previous-query",
  "limit": 10
}
```

### Implementing Pagination in a Client Application

```typescript
// Example: Implementing pagination in a React component
import React, { useState } from 'react';
import { useQuery } from '@apollo/client';
import { SEARCH_PATIENTS } from './queries';

function PatientList() {
  const [cursor, setCursor] = useState(null);
  const { loading, error, data, fetchMore } = useQuery(SEARCH_PATIENTS, {
    variables: { cursor, limit: 10 }
  });
  
  if (loading && !data) return <LoadingSpinner />;
  if (error) return <ErrorMessage error={error} />;
  
  const { edges, pageInfo, totalCount } = data.searchPatients;
  
  const loadNextPage = () => {
    fetchMore({
      variables: {
        cursor: pageInfo.endCursor,
        limit: 10
      },
      updateQuery: (prev, { fetchMoreResult }) => {
        if (!fetchMoreResult) return prev;
        
        return {
          searchPatients: {
            __typename: 'PatientConnection',
            edges: [...prev.searchPatients.edges, ...fetchMoreResult.searchPatients.edges],
            pageInfo: fetchMoreResult.searchPatients.pageInfo,
            totalCount: fetchMoreResult.searchPatients.totalCount
          }
        };
      }
    });
  };
  
  return (
    <div className="patient-list">
      <h1>Patients ({totalCount})</h1>
      
      {edges.map(({ node }) => (
        <PatientCard key={node.id} patient={node} />
      ))}
      
      {pageInfo.hasNextPage && (
        <button 
          onClick={loadNextPage}
          disabled={loading}
        >
          {loading ? 'Loading...' : 'Load More'}
        </button>
      )}
    </div>
  );
}
```

### Offset-Based Pagination

Offset-based pagination can be used for simpler use cases.

```graphql
# Example: Offset-based pagination
query SearchPatients($offset: Int = 0, $limit: Int = 10) {
  searchPatients(_offset: $offset, _count: $limit) {
    items {
      id
      name {
        given
        family
      }
      birthDate
    }
    totalCount
  }
}

# Variables for first page
{
  "offset": 0,
  "limit": 10
}

# Variables for second page
{
  "offset": 10,
  "limit": 10
}
```

## Healthcare-Specific Query Patterns

This section covers query patterns specific to healthcare data.

### Patient Summary Query

Retrieve a comprehensive patient summary with related data.

```graphql
# Example: Patient summary query
query PatientSummary($id: ID!) {
  patient(id: $id) {
    id
    name {
      given
      family
      prefix
    }
    birthDate
    gender
    address {
      line
      city
      state
      postalCode
      country
    }
    telecom {
      system
      value
      use
    }
    
    # Active conditions
    activeConditions: conditions(clinicalStatus: "active") {
      id
      code {
        coding {
          display
        }
      }
      onsetDateTime
      recordedDate
    }
    
    # Current medications
    activeMedications: medicationRequests(status: "active") {
      id
      medicationCodeableConcept {
        coding {
          display
        }
      }
      dosageInstruction {
        text
        timing {
          code {
            coding {
              display
            }
          }
        }
      }
      authoredOn
    }
    
    # Recent observations
    recentObservations: observations(_count: 10, _sort: "-date") {
      id
      code {
        coding {
          display
        }
      }
      valueQuantity {
        value
        unit
      }
      valueString
      valueCodeableConcept {
        coding {
          display
        }
      }
      effectiveDateTime
    }
    
    # Allergies
    allergies {
      id
      code {
        coding {
          display
        }
      }
      reaction {
        manifestation {
          coding {
            display
          }
        }
        severity
      }
    }
    
    # Recent encounters
    recentEncounters: encounters(_count: 5, _sort: "-date") {
      id
      status
      class {
        display
      }
      type {
        coding {
          display
        }
      }
      period {
        start
        end
      }
      serviceProvider {
        reference
        display
      }
    }
  }
}
```

### Clinical Dashboard Query

Retrieve data for a clinical dashboard.

```graphql
# Example: Clinical dashboard query
query ClinicalDashboard($patientId: ID!, $observationCodes: [String!]) {
  patient(id: $patientId) {
    id
    name {
      given
      family
    }
    birthDate
    gender
    
    # Vital signs tracking
    vitalSigns: observations(
      category: "vital-signs",
      code: $observationCodes,
      _count: 20,
      _sort: "-date"
    ) {
      id
      code {
        coding {
          system
          code
          display
        }
      }
      valueQuantity {
        value
        unit
      }
      effectiveDateTime
      status
    }
    
    # Lab results
    labResults: observations(
      category: "laboratory",
      _count: 10,
      _sort: "-date"
    ) {
      id
      code {
        coding {
          display
        }
      }
      valueQuantity {
        value
        unit
        system
        code
      }
      referenceRange {
        low {
          value
          unit
        }
        high {
          value
          unit
        }
        text
      }
      interpretation {
        coding {
          code
          display
        }
      }
      effectiveDateTime
    }
    
    # Medication adherence
    medicationAdherence: medicationStatements(
      _count: 10,
      _sort: "-date"
    ) {
      id
      medicationCodeableConcept {
        coding {
          display
        }
      }
      status
      effectivePeriod {
        start
        end
      }
      dateAsserted
      note {
        text
      }
    }
    
    # Care plans
    carePlans(status: "active") {
      id
      title
      status
      intent
      category {
        coding {
          display
        }
      }
      activity {
        detail {
          status
          description
          scheduledTiming {
            repeat {
              frequency
              period
              periodUnit
            }
          }
        }
      }
      created
    }
  }
}

# Variables
{
  "patientId": "123",
  "observationCodes": [
    "8480-6",  # Systolic BP
    "8462-4",  # Diastolic BP
    "8867-4",  # Heart rate
    "2708-6"   # Oxygen saturation
  ]
}
```

## Conclusion

Effective querying is essential for getting the most value from your Federated Graph API. By mastering basic query patterns, using variables for dynamic queries, creating reusable fragments, implementing proper error handling, and using appropriate pagination strategies, you can create efficient, maintainable queries that retrieve exactly the data your healthcare applications need.

As you implement queries for your GraphQL API, remember to:

1. Request only the fields you need to minimize response size
2. Use variables to make your queries dynamic and reusable
3. Create fragments for common field selections
4. Implement proper error handling at both global and component levels
5. Use appropriate pagination strategies for large datasets

With these principles in mind, your Federated Graph API will provide a powerful, flexible interface for accessing healthcare data.
