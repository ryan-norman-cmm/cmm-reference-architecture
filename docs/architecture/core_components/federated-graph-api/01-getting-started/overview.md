# Federated Graph API Overview

## Introduction
The Federated Graph API unifies access to all platform data and services through a single GraphQL endpoint, powered by Apollo Router and GraphOS. It provides a consistent, efficient interface for client applications to query and mutate data across multiple backend services while maintaining separation of concerns and service autonomy.

## Key Features
- Unified GraphQL interface for all platform services
- Service federation and composition
- Fine-grained access control and security
- High performance and scalability
- Real-time subscriptions
- Schema governance and validation

## Architecture Overview
- The Federated Graph API acts as a composition layer that unifies multiple GraphQL subgraphs into a single cohesive graph.
- It leverages Apollo Federation to delegate queries to the appropriate backend services.
- The architecture enables teams to independently develop and deploy their own subgraphs while maintaining a unified API for clients.

## Integration Points
- Integrates with the FHIR Interoperability Platform to expose healthcare data
- Connects with the Event Broker for real-time subscriptions
- Provides a unified API layer for the API Marketplace
- Enables consistent data access for frontend applications

## Use Cases
- Building unified healthcare dashboards and applications
- Enabling complex, cross-service data queries
- Supporting real-time data updates in user interfaces
- Simplifying client-side data fetching and state management
- Enforcing consistent access control across services

## Learn More
- [Apollo Federation Overview](https://www.apollographql.com/docs/federation/) — Comprehensive guide to GraphQL federation concepts
- [GraphQL in Healthcare](https://www.youtube.com/watch?v=nCWE6eonL7k) — YouTube presentation on GraphQL for healthcare data
- [The GraphQL Guide](https://graphql.guide/) — Complete resource for GraphQL development

## Next Steps
- [Federated Graph API Architecture](./architecture.md)
- [Federated Graph API Quick Start](./quick-start.md)
- [Federated Graph API Core APIs](../02-core-functionality/core-apis.md)
