# Federated Graph API Key Concepts

## Introduction
This document outlines the fundamental concepts and terminology of the Federated Graph API core component, which is built on Apollo Federation and GraphQL. It serves as a reference for developers, architects, and stakeholders working with the Federated Graph API.

## Core Terminology

- **GraphQL**: A query language for APIs and a runtime for executing those queries against your data. GraphQL provides a complete and understandable description of the data in your API.

- **Subgraph**: An individual GraphQL service that implements a portion of your graph and is composed into the unified supergraph. Each subgraph is typically owned by a specific team or domain.

- **Supergraph**: The unified GraphQL schema that combines all subgraphs into a cohesive whole. The supergraph is what clients interact with.

- **Router**: The gateway service (Apollo Router) that receives client requests, plans query execution, and delegates operations to the appropriate subgraphs.

- **Schema**: The type system description that defines what data can be queried and how it's structured. In GraphQL, the schema serves as a contract between the client and server.

- **Entity**: A type that can be referenced across subgraphs and has a unique identifier. Entities enable the Router to join data from multiple services.

- **Query**: A read operation in GraphQL that requests specific fields from types defined in the schema.

- **Mutation**: A write operation in GraphQL that modifies data on the server and returns a result.

- **Subscription**: A long-lived operation that creates a real-time connection to the server, enabling the client to receive updates when specified events occur.

## Fundamental Concepts

### Federation Architecture

Federation is an architecture for composing multiple GraphQL services into a unified graph:

1. **Declarative Composition**: Subgraphs declare what parts of the schema they're responsible for
2. **Distributed Execution**: Queries spanning multiple subgraphs are broken down and executed in parallel
3. **Type Sharing**: Multiple subgraphs can contribute fields to the same type
4. **Reference Resolution**: Entities are resolved across subgraph boundaries using unique identifiers
5. **Separation of Concerns**: Teams own their domains independently while contributing to the unified graph

### Schema Composition

Schema composition is the process of combining subgraph schemas into a supergraph:

- **Type Merging**: Combining type definitions from multiple subgraphs
- **Field Contributions**: Multiple subgraphs can add fields to the same type
- **Interface Implementation**: Types across subgraphs can implement shared interfaces
- **Schema Validation**: Ensuring the composed schema is valid and resolves correctly
- **Composition Errors**: Identifying and resolving conflicts between subgraphs

### Query Planning and Execution

When the Router receives a query, it:

1. **Creates a Query Plan**: Analyzes the query and determines which subgraphs need to be queried
2. **Executes the Plan**: Sends portions of the query to appropriate subgraphs
3. **Fetches References**: Resolves entities across subgraph boundaries
4. **Assembles the Result**: Combines all subgraph responses into a unified response
5. **Returns the Response**: Sends the complete response back to the client

### Schema Evolution

The Federated Graph API supports controlled schema evolution:

- **Schema Checks**: Validating schema changes against production traffic
- **Versioning**: Managing changes to types and fields over time
- **Deprecation**: Marking fields as deprecated before removal
- **Compatibility Rules**: Ensuring backward compatibility for clients
- **Schema Registry**: Tracking schema changes and validating deployments

### GraphQL Security

The Federated Graph API implements multiple security layers:

- **Authentication**: Verifying the identity of clients
- **Authorization**: Determining what data a client can access
- **Field-Level Permissions**: Controlling access at the field level
- **Rate Limiting**: Protecting against abuse and overload
- **Input Validation**: Ensuring input data meets requirements
- **Query Complexity Analysis**: Preventing resource-intensive queries

## Glossary

| Term | Definition |
|------|------------|
| AST | Abstract Syntax Tree; the parsed representation of a GraphQL document |
| Directive | A way of attaching custom behavior to a field or type in GraphQL |
| Resolver | A function that resolves a value for a type or field in the GraphQL schema |
| Introspection | The ability to query a GraphQL schema for details about itself |
| Fragment | A reusable piece of a GraphQL query that can be shared across queries |
| Operation | A query, mutation, or subscription in GraphQL |
| Variables | Dynamic values that can be passed into queries to make them reusable |
| Nullability | Whether a field can return null or must always return a value |
| Scalar | A primitive type in GraphQL (Int, Float, String, Boolean, ID) |
| Cursor | A pointer to a specific location in a dataset, used for pagination |

## Related Resources
- [Federated Graph API Overview](./overview.md)
- [Federated Graph API Architecture](./architecture.md)
- [Federated Graph API Quick Start](./quick-start.md)
- [Apollo Federation Documentation](https://www.apollographql.com/docs/federation/)