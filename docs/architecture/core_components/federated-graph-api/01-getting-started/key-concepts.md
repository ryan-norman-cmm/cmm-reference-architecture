# Federated Graph API Key Concepts

## Introduction

The Federated Graph API is built on several key concepts that enable a modular, scalable, and maintainable approach to GraphQL API development. Understanding these concepts is essential for effectively working with the federated architecture in the CMM Technology Platform. This document explains the fundamental concepts, terminology, and patterns used in our implementation.

## Core Concepts

### GraphQL Federation

GraphQL Federation is an architectural pattern that allows you to divide your GraphQL schema into multiple, independently deployable services (subgraphs) while presenting a unified API to clients. This approach enables:

- **Domain Separation**: Teams can own specific portions of the schema aligned with their domain expertise
- **Independent Development**: Services can be developed and deployed independently
- **Scalability**: Each service can be scaled according to its specific load patterns
- **Incremental Adoption**: New capabilities can be added to the API without disrupting existing functionality

### Supergraph and Subgraphs

- **Supergraph**: The complete, unified GraphQL schema composed from all subgraphs
- **Subgraph**: An individual GraphQL service that implements a portion of the overall schema

```typescript
// Example: Defining a subgraph in TypeScript
import { buildSubgraphSchema } from '@apollo/subgraph';
import { gql } from 'graphql-tag';

// Define the schema with federation directives
const typeDefs = gql`
  extend schema @link(url: "https://specs.apollo.dev/federation/v2.0", import: ["@key"])
  
  type Patient @key(fields: "id") {
    id: ID!
    name: String!
    dateOfBirth: String!
  }
  
  type Query {
    patient(id: ID!): Patient
    patients: [Patient!]!
  }
`;

// Build the federated schema
const schema = buildSubgraphSchema([{ typeDefs, resolvers }]);
```

### Federation Gateway

The Federation Gateway (sometimes called the Router) is the entry point for all client requests. It performs several critical functions:

- **Schema Composition**: Combines subgraph schemas into a unified supergraph
- **Query Planning**: Determines how to break down and execute queries across subgraphs
- **Request Routing**: Forwards query portions to the appropriate subgraphs
- **Response Assembly**: Combines subgraph responses into a complete result
- **Error Handling**: Manages and normalizes errors from subgraphs

```typescript
// Example: Configuring a Federation Gateway in TypeScript
import { ApolloGateway, IntrospectAndCompose } from '@apollo/gateway';
import { ApolloServer } from '@apollo/server';

// Configure the gateway with subgraphs
const gateway = new ApolloGateway({
  supergraphSdl: new IntrospectAndCompose({
    subgraphs: [
      { name: 'patients', url: 'http://patients-service:4001/graphql' },
      { name: 'encounters', url: 'http://encounters-service:4002/graphql' },
      { name: 'medications', url: 'http://medications-service:4003/graphql' }
    ]
  })
});

// Create an Apollo Server instance with the gateway
const server = new ApolloServer({ gateway });
```

## Federation Directives

Federation uses special directives to define how types relate across subgraphs:

### @key Directive

The `@key` directive identifies an entity by specifying which fields uniquely identify it. This allows entities to be referenced across subgraphs.

```graphql
type Patient @key(fields: "id") {
  id: ID!
  name: String!
}
```

### @external Directive

The `@external` directive indicates that a field is defined in another subgraph but is required in the current subgraph for reference.

```graphql
type Patient @key(fields: "id") {
  id: ID! @external
  name: String! @external
  encounters: [Encounter!]! # Local field
}
```

### @requires Directive

The `@requires` directive indicates that a field needs specific fields from another subgraph to resolve.

```graphql
type Patient @key(fields: "id") {
  id: ID! @external
  dateOfBirth: String! @external
  age: Int! @requires(fields: "dateOfBirth") # Calculated from dateOfBirth
}
```

### @provides Directive

The `@provides` directive indicates that a field can provide specific fields from a referenced entity, potentially saving an additional subgraph request.

```graphql
type Encounter {
  id: ID!
  patient: Patient! @provides(fields: "name") # Encounter provides patient name
}
```

## Entity References

Entities are types that can be referenced across subgraphs. They are identified by the `@key` directive and require special resolver functions to handle references.

### __resolveReference Function

The `__resolveReference` function resolves references to entities from other subgraphs.

```typescript
const resolvers = {
  Patient: {
    // Resolves references to Patient entities from other subgraphs
    __resolveReference: async (reference) => {
      // reference contains the fields specified in @key
      return await fetchPatientById(reference.id);
    },
    // Other field resolvers...
  }
};
```

## Query Planning and Execution

### Query Plan

When the gateway receives a query, it creates a query plan that determines how to break down the query and which subgraphs to call.

1. **Parse and Validate**: The gateway parses and validates the query against the supergraph schema
2. **Create Query Plan**: The gateway determines which subgraphs are needed and in what order
3. **Execute Plan**: The gateway sends portions of the query to each required subgraph
4. **Assemble Results**: The gateway combines the responses into a single result

### Entity Joins

When a query spans multiple subgraphs, the gateway performs entity joins to combine data:

1. **Initial Fetch**: The gateway fetches data from the first subgraph
2. **Entity Extraction**: It extracts entity references (keys) from the response
3. **Subsequent Fetches**: It sends these references to other subgraphs to fetch additional fields
4. **Merge Results**: It merges all responses into a complete entity

## Schema Design Principles

### Domain-Driven Design

Subgraphs should align with bounded contexts from domain-driven design:

- **Patients Subgraph**: Manages patient demographics and identifiers
- **Encounters Subgraph**: Handles clinical encounters and visits
- **Medications Subgraph**: Manages medications and prescriptions

### Type Ownership

Each type should have a clear owner, with other subgraphs extending it as needed:

- **Primary Owner**: Defines the core fields and `@key` fields
- **Extended by**: Other subgraphs add domain-specific fields

### Schema Evolution

Federated schemas should evolve carefully to maintain compatibility:

- **Additive Changes**: Add new types and optional fields
- **Deprecation**: Mark fields as deprecated before removal
- **Versioning**: Use versioning strategies for major changes

## Authentication and Authorization

### Authentication Flow

1. **Client Authentication**: Clients authenticate with an identity provider and receive a JWT
2. **Gateway Validation**: The gateway validates the JWT and extracts user information
3. **Context Propagation**: User context is propagated to subgraphs for authorization

```typescript
// Example: Authentication in the gateway
const server = new ApolloServer({
  gateway,
  context: async ({ req }) => {
    // Extract and validate JWT token
    const token = req.headers.authorization?.split(' ')[1] || '';
    const user = await validateToken(token);
    
    return { user };
  }
});
```

### Authorization Patterns

- **Gateway-Level Authorization**: Coarse-grained access control at the gateway
- **Subgraph-Level Authorization**: Domain-specific access control in each subgraph
- **Field-Level Authorization**: Fine-grained control using directives or resolvers

```graphql
# Example: Authorization directive
type Patient @key(fields: "id") {
  id: ID!
  name: String!
  ssn: String! @auth(requires: "ADMIN")
}
```

## Performance Optimization

### DataLoader Pattern

The DataLoader pattern batches and caches database requests to prevent N+1 query problems.

```typescript
// Example: Using DataLoader in a resolver
import DataLoader from 'dataloader';

// Create a batch loading function
const batchLoadPatients = async (ids) => {
  const patients = await PatientModel.findByIds(ids);
  return ids.map(id => patients.find(p => p.id === id) || null);
};

// In the context function
const context = () => ({
  loaders: {
    patients: new DataLoader(batchLoadPatients)
  }
});

// In the resolver
const resolvers = {
  Query: {
    patient: (_, { id }, { loaders }) => {
      return loaders.patients.load(id);
    }
  }
};
```

### Caching Strategies

- **Response Caching**: Cache entire query responses at the gateway
- **Entity Caching**: Cache individual entities across requests
- **Partial Query Caching**: Cache portions of queries that don't change frequently

## Conclusion

Understanding these key concepts provides the foundation for working effectively with the Federated Graph API. As you develop and extend the API, these patterns and principles will guide you in creating a scalable, maintainable, and performant GraphQL ecosystem for healthcare applications.
