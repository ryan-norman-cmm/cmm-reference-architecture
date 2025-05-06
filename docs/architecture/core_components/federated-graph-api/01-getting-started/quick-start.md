# Federated Graph API Quick Start

This guide provides a step-by-step process to help you quickly get started with the Federated Graph API core component.

## Prerequisites
- Access to the CMM platform environment (development, staging, or production)
- Provisioned credentials for the Federated Graph API (API key or OAuth credentials)
- Network access to the Federated Graph API endpoint
- Familiarity with GraphQL concepts and tools

## Step 1: Install and Run Apollo Router

> **Recommended:** Follow the official Apollo Router getting started guide for setup and local development: [Apollo Router - Get Started (Official Docs)](https://www.apollographql.com/docs/router/getting-started/)

### Install Apollo Router
Apollo Router is distributed as a pre-built binary. Download the latest release from the [Apollo Router releases page](https://github.com/apollographql/router/releases) or use the install script:

```sh
curl -sSL https://router.apollo.dev/download/nix/latest | sh
```

For more installation options (Linux, macOS, Windows, Docker), see the [Apollo Router install docs](https://www.apollographql.com/docs/router/installation/).

### Configure and Run the Router
1. Create a `supergraph.yaml` or `supergraph.graphql` file describing your federated subgraphs. See [Apollo Router supergraph config](https://www.apollographql.com/docs/router/supergraphs/supergraph-config/).
2. Start the router:

```sh
./router --supergraph supergraph.yaml
```

The router will start and listen on `http://localhost:4000` by default.

For troubleshooting, advanced configuration, and more, refer to the [official Apollo Router getting started guide](https://www.apollographql.com/docs/router/getting-started/).

## Step 2: Install Apollo Client Dependencies
Install the Apollo Client for TypeScript/Node.js:

```sh
npm install @apollo/client graphql
```

## Step 3: Connect to the Federated Graph API
Use the provided credentials and endpoint to connect as a client:

```typescript
import { ApolloClient, InMemoryCache, HttpLink, gql } from '@apollo/client/core';
import fetch from 'cross-fetch';

const client = new ApolloClient({
  link: new HttpLink({
    uri: 'http://localhost:4000', // or your deployed router URL
    headers: {
      Authorization: 'Bearer YOUR_API_KEY',
    },
    fetch,
  }),
  cache: new InMemoryCache(),
});
```

## Step 4: Perform a Basic Operation
Query patient data:

```typescript
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
  variables: { id: 'example-patient-id' },
});
console.log(data);
```

## Step 5: Validate Setup
- Ensure you can query data without errors using your client or integration tests.
- Access the Apollo Router Admin UI at [http://localhost:8088](http://localhost:8088) (or your configured endpoint) to view router status, health, and metrics. See [Apollo Router Admin UI docs](https://www.apollographql.com/docs/router/telemetry/admin-ui/) for details.
- For troubleshooting setup, authentication, or network issues, see the [Apollo Router troubleshooting guide](https://www.apollographql.com/docs/router/troubleshooting/).

## Next Steps
- [Explore Advanced GraphQL Operations](../03-advanced-topics/advanced-graphql-operations.md)
- [Integration Guide: FHIR Interoperability Platform](../../fhir-interoperability-platform/01-getting-started/quick-start.md)
- [Integration Guide: Event Broker](../../event-broker/01-getting-started/quick-start.md)
- [Integration Guide: API Marketplace](../../api-marketplace/01-getting-started/quick-start.md)
- [Best Practices: GraphQL Schema Design](../03-advanced-topics/schema-design.md)
- [Error Handling & Troubleshooting](../03-advanced-topics/error-handling.md)

## Related Resources
- [Apollo GraphQL Documentation](https://www.apollographql.com/docs/)
- [GraphQL Specification](https://spec.graphql.org/)
- [Federated Graph API Overview](./overview.md)
- [Federated Graph API Architecture](./architecture.md)
- [Federated Graph API Key Concepts](./key-concepts.md)
