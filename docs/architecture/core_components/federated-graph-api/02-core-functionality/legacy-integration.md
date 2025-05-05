# Legacy System Integration

## Introduction

Legacy system integration refers to the process of connecting older, often mission-critical systems—such as REST APIs, SOAP services, or direct databases—to a modern Federated GraphQL API. In healthcare, many organizations rely on legacy systems for electronic health records, billing, and lab data. Integrating these systems into your federated graph is essential for delivering unified, real-time access to data across your organization without requiring a complete system overhaul.

This guide provides practical strategies and implementation patterns for:
- Wrapping legacy REST APIs as GraphQL subgraphs
- Connecting directly to legacy databases
- Implementing effective caching to improve performance
- Handling errors and ensuring robust integrations

By following these approaches, you can modernize your data access layer, support digital transformation initiatives, and deliver a seamless developer experience while maintaining the reliability of your existing systems.

### Quick Start

1. Identify the legacy systems you need to integrate
2. Create a dedicated subgraph for each legacy system
3. Implement resolvers that connect to the legacy APIs or databases
4. Add caching to improve performance
5. Implement comprehensive error handling

### Related Components

- [Creating Subgraphs](creating-subgraphs.md): Learn the basics of subgraph implementation
- [Authentication](authentication.md): Secure access to legacy systems
- [Schema Federation Patterns](../03-advanced-patterns/schema-federation.md): Advanced federation techniques
- [Query Optimization](../03-advanced-patterns/query-optimization.md): Performance improvements for legacy integrations

## Wrapping REST APIs as Subgraphs

### Overview

Wrapping legacy REST APIs as GraphQL subgraphs allows you to expose existing backend functionality through your federated graph, enabling modern, unified data access without rewriting legacy services. This approach is especially valuable in healthcare, where many critical systems expose REST endpoints for patient records, billing, scheduling, and more.

### Rationale
- **Progressive modernization**: Modernize your API layer incrementally, without disrupting existing systems.
- **Unified developer experience**: Expose all data through a single GraphQL endpoint, regardless of backend technology.
- **Improved security and observability**: Centralize authentication, logging, and monitoring at the API gateway.

### Approach
1. **Analyze REST endpoints**: Identify the resources and operations you want to expose (e.g., `/patients`, `/appointments`).
2. **Design GraphQL types**: Map REST resource representations to GraphQL types and operations.
3. **Implement a data source**: Use Apollo's RESTDataSource or similar to call the REST API from your subgraph.
4. **Handle authentication**: Propagate or transform authentication tokens as needed.
5. **Transform responses**: Convert REST responses to the appropriate GraphQL types, handling errors and edge cases.

### Architecture Diagram

```mermaid
graph TD
    A[GraphQL Gateway] --> B[Legacy Subgraph]
    B --> C[REST API]
    C --> D[Legacy System]
```

### Example Implementation

Below is a simplified example of wrapping a RESTful patient API as a GraphQL subgraph using Apollo Server and RESTDataSource.

```typescript
// patientAPI.ts
import { RESTDataSource } from 'apollo-datasource-rest';

// Define TypeScript interfaces for our data models
interface Patient {
  id: string;
  mrn: string;
  firstName: string;
  lastName: string;
  birthDate: string;
  gender: string;
  address?: PatientAddress;
}

interface PatientAddress {
  line1: string;
  line2?: string;
  city: string;
  state: string;
  postalCode: string;
}

interface PatientSearchParams {
  name?: string;
  mrn?: string;
  birthDate?: string;
  limit?: number;
  offset?: number;
}

class PatientAPI extends RESTDataSource {
  constructor() {
    super();
    // Configure for Azure App Service or AKS-hosted legacy API
    // Use Key Vault for secure storage of connection strings in production
    this.baseURL = process.env.PATIENT_API_URL || 'https://legacy.example.com/api/';
  }

  // Fetch a single patient by ID
  async getPatientById(id: string): Promise<Patient> {
    try {
      return await this.get<Patient>(`patients/${id}`);
    } catch (error) {
      return this.handleError(error);
    }
  }

  // Fetch all patients (with optional query params)
  async getPatients(params: PatientSearchParams = {}): Promise<Patient[]> {
    try {
      return await this.get<Patient[]>('patients', params);
    } catch (error) {
      return this.handleError(error);
    }
  }

  // Error handling for REST calls
  handleError(error: any): never {
    if (error.extensions?.response?.status === 404) {
      throw new Error('Patient not found');
    }
    throw new Error('Failed to fetch patient data');
  }
}

export default PatientAPI;
```

```typescript
// schema.ts
import { gql } from 'apollo-server';

// Define the GraphQL schema with federation directives
const typeDefs = gql`
  extend type Query {
    patient(id: ID!): Patient
    patients(limit: Int, offset: Int): PatientConnection!
  }

  type Patient @key(fields: "id") {
    id: ID!
    firstName: String!
    lastName: String!
    birthDate: String
    gender: String
    address: PatientAddress
  }

  type PatientAddress {
    line1: String!
    line2: String
    city: String!
    state: String!
    postalCode: String!
  }

  type PatientConnection {
    items: [Patient!]!
    totalCount: Int!
  }
`;

export default typeDefs;
```

```typescript
// resolvers.ts
import { IResolvers } from 'apollo-server';
import { Patient } from './types';

interface DataSources {
  patientAPI: {
    getPatientById(id: string): Promise<Patient>;
    getPatients(params?: any): Promise<Patient[]>;
  };
}

const resolvers: IResolvers = {
  Query: {
    patient: async (_, { id }, { dataSources }: { dataSources: DataSources }) => {
      return dataSources.patientAPI.getPatientById(id);
    },
    patients: async (_, { limit, offset }, { dataSources }: { dataSources: DataSources }) => {
      return dataSources.patientAPI.getPatients({ limit, offset });
    },
  },
  Patient: {
    __resolveReference: (reference, { dataSources }) => {
      return dataSources.patientAPI.getPatientById(reference.id);
    },
  },
};

module.exports = resolvers;
```

```javascript
// index.js
const { ApolloServer } = require('apollo-server');
const { buildFederatedSchema } = require('@apollo/federation');
const typeDefs = require('./schema');
const resolvers = require('./resolvers');
const PatientAPI = require('./patientAPI');

const server = new ApolloServer({
  schema: buildFederatedSchema([{ typeDefs, resolvers }]),
  dataSources: () => ({
    patientAPI: new PatientAPI(),
  }),
});

server.listen({ port: 4001 }).then(({ url }) => {
  console.log(`🚀 Legacy subgraph ready at ${url}`);
});
```

### Error Handling Example

If the REST API returns a 404, the subgraph returns a user-friendly error message:

```graphql
query {
  patient(id: "9999") {
    id
    name
  }
}
```

**Response:**
```json
{
  "errors": [
    {
      "message": "Patient not found",
      "path": ["patient"]
    }
  ],
  "data": {
    "patient": null
  }
}
```

By following this approach, you can progressively modernize your API layer, provide a unified data access point, and ensure robust error handling for legacy system integration.

### Azure Deployment Considerations

When deploying your legacy system integration subgraphs to Azure, consider the following best practices:

1. **Azure Key Vault Integration**: Store sensitive connection strings and API keys in Azure Key Vault rather than environment variables or configuration files.
   ```typescript
   // Using Azure Key Vault with @azure/identity and @azure/keyvault-secrets
   import { DefaultAzureCredential } from '@azure/identity';
   import { SecretClient } from '@azure/keyvault-secrets';
   
   // Initialize Key Vault client once during application startup
   const credential = new DefaultAzureCredential();
   const keyVaultUrl = process.env.KEY_VAULT_URL;
   const secretClient = new SecretClient(keyVaultUrl, credential);
   
   // Fetch secret when needed
   async function getPatientApiUrl() {
     const secret = await secretClient.getSecret('patient-api-url');
     return secret.value;
   }
   ```

2. **Container Configuration**: For AKS deployments, use Kubernetes ConfigMaps and Secrets to manage environment-specific configurations.
   ```yaml
   # kubernetes-config.yaml
   apiVersion: v1
   kind: ConfigMap
   metadata:
     name: legacy-api-config
   data:
     PATIENT_API_URL: "https://legacy-api.example.com/api/v1"
     TIMEOUT_MS: "5000"
   ---
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: patient-subgraph
   spec:
     replicas: 2
     template:
       spec:
         containers:
         - name: patient-subgraph
           image: acr.azurecr.io/patient-subgraph:v1.0.0
           envFrom:
           - configMapRef:
               name: legacy-api-config
   ```

3. **Health Checks**: Implement robust health checks to ensure your subgraph can detect and report when legacy systems are unavailable.
   ```typescript
   // health.ts
   import express from 'express';
   
   export async function healthCheck(req: express.Request, res: express.Response) {
     try {
       // Check connection to legacy system
       await testLegacyConnection();
       res.status(200).json({ status: 'healthy' });
     } catch (error) {
       res.status(503).json({ status: 'unhealthy', error: error.message });
     }
   }
   ```

4. **Monitoring and Logging**: Configure Application Insights for comprehensive monitoring and logging.
   ```typescript
   // app.ts
   import * as appInsights from 'applicationinsights';
   
   // Initialize Application Insights
   appInsights.setup(process.env.APPINSIGHTS_INSTRUMENTATIONKEY)
     .setAutoDependencyCorrelation(true)
     .setAutoCollectRequests(true)
     .setAutoCollectPerformance(true)
     .setAutoCollectExceptions(true)
     .setAutoCollectDependencies(true)
     .start();
   ```

5. **Circuit Breakers**: Implement circuit breakers to prevent cascading failures when legacy systems are unstable.
   ```typescript
   // Using Opossum for circuit breaking
   import CircuitBreaker from 'opossum';
   
   const breaker = new CircuitBreaker(async (id) => {
     return await legacyApiCall(id);
   }, {
     timeout: 3000,             // If function takes longer than 3 seconds, trigger a failure
     errorThresholdPercentage: 50, // When 50% of requests fail, open the circuit
     resetTimeout: 30000       // After 30 seconds, try again
   });
   
   breaker.on('open', () => {
     console.log('Circuit breaker opened - legacy system appears to be down');
     // Log to Application Insights
     appInsights.defaultClient.trackEvent({name: 'CircuitBreakerOpened'});
   });
   ```

By implementing these Azure-specific patterns, you can ensure your legacy system integrations are robust, secure, and maintainable in a cloud-native environment.

## Database-Direct Subgraphs

### Overview

In some scenarios, legacy systems may not expose a REST API but allow direct access to their underlying databases. Creating a database-direct subgraph enables you to query these databases from your federated graph, providing access to critical data without requiring changes to the legacy application. This approach is common for integrating older EHR, billing, or laboratory systems in healthcare.

### Rationale
- **Immediate data access**: Enables real-time queries on legacy data sources.
- **Bypass legacy APIs**: Useful when existing APIs are incomplete, slow, or unavailable.
- **Unified API layer**: Exposes direct database queries through GraphQL, maintaining a consistent developer experience.

### Implementation Steps
1. **Analyze the legacy database schema**: Identify tables, relationships, and key fields.
2. **Design GraphQL types**: Map tables and relationships to GraphQL types and fields.
3. **Implement a data access layer**: Use an ORM (e.g., Sequelize, TypeORM) or direct SQL queries.
4. **Handle connection pooling**: Ensure efficient and safe database connections.
5. **Transform and validate data**: Map raw database results to GraphQL types, handling nulls, types, and errors.

### Architecture Diagram

```mermaid
graph TD
    A[GraphQL Gateway] --> B[Database Subgraph]
    B --> C[(Legacy Database)]
```

### Example Implementation

Below is a simplified example of a subgraph connecting directly to a legacy PostgreSQL database using `pg` and Apollo Server.

```javascript
// db.js
const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.LEGACY_DB_URL || 'postgres://user:pass@localhost:5432/legacydb',
  max: 10, // Connection pool size
});

module.exports = pool;
```

```javascript
// schema.js
const { gql } = require('apollo-server');

const typeDefs = gql`
  type BillingRecord @key(fields: "id") {
    id: ID!
    patientId: ID!
    amount: Float!
    status: String!
    createdAt: String!
  }

  type Query {
    billingRecord(id: ID!): BillingRecord
    billingRecords(patientId: ID!): [BillingRecord!]!
  }
`;

export default typeDefs;
```

```typescript
// server.ts
import { ApolloServer } from 'apollo-server';
import typeDefs from './schema';
import resolvers from './resolvers';
        return null;
      }
    },
  },
};

module.exports = resolvers;
```

### Error Handling Example

If a billing record does not exist, the API returns `null` for the record and does not throw an unhandled error. Database errors are logged and a generic error message is returned to the client.

By following this approach, you can expose legacy database data in your federated graph, enabling unified access and progressive modernization while maintaining robust error handling and connection management.

## Caching Strategies

### Overview

Caching is critical when integrating legacy systems, especially those with limited scalability or slow response times. By introducing caching at the subgraph or gateway level, you can dramatically improve performance, reduce load on legacy backends, and provide a more responsive experience for consumers of your federated graph.

### Rationale
- **Performance**: Reduce latency for frequently accessed data.
- **Reliability**: Prevent transient backend outages from disrupting the API.
- **Scalability**: Minimize repeated load on legacy systems that may not scale well.

### Types of Caching
- **In-memory caching**: Fast, simple, and suitable for small-scale or stateless deployments.
- **Distributed caching (e.g., Redis)**: Scalable and resilient, ideal for multi-instance deployments.
- **HTTP caching**: Use HTTP cache headers for client-side or CDN caching.

### Implementation Steps
1. Identify data that is safe to cache (e.g., reference data, read-heavy resources).
2. Choose a caching strategy (in-memory, Redis, or hybrid).
3. Configure cache expiration (TTL) based on data volatility.
4. Implement cache invalidation on updates or deletes.
5. Monitor cache hit/miss rates to tune performance.

### Example: Apollo Server with Redis Cache

```javascript
const { ApolloServer } = require('apollo-server');
const { buildFederatedSchema } = require('@apollo/federation');
const { RedisCache } = require('apollo-server-cache-redis');
const typeDefs = require('./schema');
const resolvers = require('./resolvers');

const server = new ApolloServer({
  schema: buildFederatedSchema([{ typeDefs, resolvers }]),
  cache: new RedisCache({
    host: process.env.REDIS_HOST || 'localhost',
    port: 6379,
    password: process.env.REDIS_PASSWORD,
  }),
  cacheControl: {
    defaultMaxAge: 60, // Cache for 60 seconds by default
    calculateHttpHeaders: true,
  },
});

server.listen({ port: 4001 }).then(({ url }) => {
  console.log(`🚀 Subgraph with Redis cache ready at ${url}`);
});
```

### Example: Resolver-Level Caching

```javascript
// In your resolver
const resolvers = {
  Query: {
    patient: async (_, { id }, { dataSources, cache }) => {
      const cacheKey = `patient:${id}`;
      // Try cache first
      let patient = await cache.get(cacheKey);
      if (patient) return JSON.parse(patient);
      // Fallback to REST/database
      patient = await dataSources.patientAPI.getPatientById(id);
      if (patient) {
        await cache.set(cacheKey, JSON.stringify(patient), 'EX', 60); // 60s TTL
      }
      return patient;
    },
  },
};
```

### Error Handling and Invalidation
- Always set reasonable TTLs to avoid serving stale data.
- Invalidate or update cache entries when underlying data changes (e.g., after a mutation).
- Log cache errors, but do not allow cache failures to break the API—fallback to the backend if the cache is unavailable.

By thoughtfully applying caching strategies, you can provide a fast, reliable federated API experience even when integrating with slow or fragile legacy systems.

## Error Handling

### Overview

Robust error handling is essential when integrating legacy systems, which may be less reliable or have inconsistent error reporting. Your federated graph should translate backend errors into clear, actionable messages for API consumers, while ensuring that sensitive or internal details are not exposed.

### Rationale
- **User experience**: Provide meaningful feedback to clients instead of cryptic or technical errors.
- **Resilience**: Prevent a single backend failure from breaking the entire API.
- **Security**: Avoid leaking sensitive system details in error messages.

### Implementation Guidance
1. **Standardize error responses**: Use GraphQL error extensions to provide error codes and user-friendly messages.
2. **Timeouts and retries**: Set reasonable timeouts for legacy API/database calls and implement retries for transient errors.
3. **Partial results**: Return partial data with errors where possible, rather than failing the entire query.
4. **Logging and monitoring**: Log errors with enough detail for troubleshooting, but do not expose internal details to clients.

### Example: Standardized Error Propagation

```javascript
// In your RESTDataSource or database wrapper
handleError(error) {
  if (error.extensions?.response?.status === 404) {
    const notFound = new Error('Resource not found');
    notFound.extensions = { code: 'NOT_FOUND' };
    throw notFound;
  }
  if (error.code === 'ETIMEDOUT') {
    const timeout = new Error('Service unavailable');
    timeout.extensions = { code: 'SERVICE_UNAVAILABLE' };
    throw timeout;
  }
  // Generic fallback
  const generic = new Error('An unexpected error occurred');
  generic.extensions = { code: 'INTERNAL_ERROR' };
  throw generic;
}
```

### Example: Partial Results in Resolvers

```javascript
const resolvers = {
  Query: {
    patient: async (_, { id }, { dataSources }) => {
      try {
        return await dataSources.patientAPI.getPatientById(id);
      } catch (error) {
        // Log error internally
        console.error('Failed to fetch patient:', error);
        // Return null for this field, error will be included in GraphQL errors array
        return null;
      }
    },
    billingRecords: async (_, { patientId }, { dataSources }) => {
      try {
        return await dataSources.billingAPI.getBillingRecords(patientId);
      } catch (error) {
        // Return empty array if backend is unavailable
        return [];
      }
    },
  },
};
```

### Example: Error Extensions in GraphQL Response

```json
{
  "errors": [
    {
      "message": "Resource not found",
      "extensions": {
        "code": "NOT_FOUND"
      },
      "path": ["patient"]
    }
  ],
  "data": {
    "patient": null
  }
}
```

### Best Practices
- Use descriptive error codes (e.g., `NOT_FOUND`, `SERVICE_UNAVAILABLE`, `INTERNAL_ERROR`).
- Avoid exposing stack traces or internal system details in error messages.
- Return partial data with errors where possible, following GraphQL's error propagation model.
- Monitor and alert on error rates to proactively address backend issues.

By adopting these patterns, you ensure that your federated API remains robust, user-friendly, and secure—even when integrating with unreliable or inconsistent legacy systems.

## Conclusion

Integrating legacy systems into a federated GraphQL API enables organizations to modernize their data access layer while preserving critical investments in existing infrastructure. By wrapping REST APIs, connecting directly to databases, implementing effective caching, and adopting robust error handling, you can deliver a unified, secure, and performant API experience—even in complex healthcare environments.

**Key takeaways:**
- Use subgraph wrappers and data sources to progressively modernize legacy REST and database systems.
- Apply caching and batching strategies to improve performance and reduce load on fragile backends.
- Implement comprehensive error handling to ensure reliability and user-friendly responses.
- Monitor integration health and error rates using Apollo GraphOS or similar tools.
- Document integration patterns and edge cases to support ongoing maintenance and onboarding.

By following these patterns and best practices, you can bridge the gap between legacy and modern systems, accelerate digital transformation, and deliver real-time, unified data access for healthcare and beyond.
