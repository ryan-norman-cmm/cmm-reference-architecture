# Federated Graph API Quick Start

## Introduction

Setting up a Federated Graph API in the CMM Technology Platform involves configuring a cloud-native gateway and TypeScript-based subgraphs. This guide provides step-by-step instructions for setting up a complete federated GraphQL environment using modern technologies like Apollo Federation 2.0, TypeScript, and containerized deployments. By following these steps, you'll have a scalable, type-safe federated GraphQL API that can be extended with additional subgraphs as your healthcare application needs evolve.

### Quick Start

1. Install Node.js and npm (or yarn)
2. Set up the Apollo Gateway project
3. Create your first subgraph
4. Configure the gateway to use your subgraph
5. Test your federated graph with GraphQL Playground

### Related Components

- [Federated Graph API Overview](overview.md): Understand the overall architecture
- [Creating Subgraphs](../02-core-functionality/creating-subgraphs.md): Learn how to create additional subgraphs
- [Authentication](../02-core-functionality/authentication.md): Secure your federated graph
- [Deployment](../05-operations/deployment.md): Deploy your federated graph to production

## Prerequisites

Before setting up your Federated Graph API, ensure you have the following prerequisites installed:

- Node.js (v18 or later)
- npm (v9 or later) or yarn
- TypeScript (v5.0 or later)
- Docker and Docker Compose (for containerized deployments)
- Git (for version control)
- kubectl (for Kubernetes deployments)

```bash
# Check Node.js and TypeScript versions
node --version
npm --version
tsc --version

# Verify Docker installation
docker --version
docker-compose --version

# Verify Kubernetes CLI
kubectl version --client
```

## Setting Up the Apollo Gateway with TypeScript

The Apollo Gateway serves as the entry point for your federated GraphQL API, routing queries to the appropriate subgraphs and combining the results. We'll implement it using TypeScript for type safety and containerize it for cloud deployments.

### Create a New Gateway Project with TypeScript

```bash
# Create a new directory for your gateway
mkdir federated-healthcare-api
cd federated-healthcare-api

# Initialize a new TypeScript project
npm init -y
npm install typescript ts-node @types/node --save-dev
npx tsc --init

# Install Apollo Federation dependencies
npm install @apollo/gateway @apollo/server graphql
```

### Configure TypeScript

Update your `tsconfig.json` file with the following settings:

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "esModuleInterop": true,
    "sourceMap": true,
    "outDir": "./dist",
    "strict": true,
    "lib": ["ES2022"],
    "skipLibCheck": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "**/*.test.ts"]
}
```

### Create the Gateway Server with TypeScript

Create a new file at `src/gateway.ts` with the following content:

```typescript
// src/gateway.ts
import { ApolloServer } from '@apollo/server';
import { startStandaloneServer } from '@apollo/server/standalone';
import { ApolloGateway, IntrospectAndCompose } from '@apollo/gateway';
import { expressMiddleware } from '@apollo/server/express4';
import express from 'express';
import http from 'http';
import cors from 'cors';
import { json } from 'body-parser';

// Define environment variables with defaults for cloud configuration
const PORT = process.env.PORT || 4000;
const SUBGRAPH_LIST = process.env.SUBGRAPH_LIST ? 
  JSON.parse(process.env.SUBGRAPH_LIST) : 
  [];

// Initialize the gateway with supergraph composition
const gateway = new ApolloGateway({
  supergraphSdl: new IntrospectAndCompose({
    subgraphs: SUBGRAPH_LIST.length > 0 ? SUBGRAPH_LIST : [
      // Default subgraphs for local development
      { name: 'patients', url: 'http://localhost:4001/graphql' },
      { name: 'encounters', url: 'http://localhost:4002/graphql' },
      { name: 'medications', url: 'http://localhost:4003/graphql' }
    ]
  })
});

// Create an Apollo Server instance
const server = new ApolloServer({
  gateway
});

// Set up Express middleware for advanced configuration
async function startApolloServer() {
  // Start the Apollo Server
  await server.start();
  
  // Create Express app and HTTP server for more control
  const app = express();
  const httpServer = http.createServer(app);
  
  // Set up health check endpoint for Kubernetes
  app.get('/health', (req, res) => {
    res.status(200).send('OK');
  });
  
  // Set up Apollo middleware with authentication
  app.use(
    '/graphql',
    cors<cors.CorsRequest>(),
    json(),
    expressMiddleware(server, {
      context: async ({ req }) => {
        // Extract JWT token from Authorization header
        const token = req.headers.authorization || '';
        
        // In a production environment, verify the token
        // const user = await verifyToken(token);
        
        return { 
          token,
          // user,
          // Add additional context items here
        };
      }
    })
  );
  
  // Start the HTTP server
  await new Promise<void>((resolve) => {
    httpServer.listen({ port: PORT }, resolve);
  });
  
  console.log(`🚀 Gateway ready at http://localhost:${PORT}/graphql`);
  return { server, app, httpServer };
}

// Start the server
startApolloServer().catch(err => {
  console.error('Failed to start Apollo Server:', err);
});
```

### Containerize the Gateway

Create a `Dockerfile` in the root directory:

```dockerfile
FROM node:18-alpine as builder

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY tsconfig.json ./
COPY src/ ./src/

RUN npm run build

# Production image
FROM node:18-alpine

WORKDIR /app

COPY --from=builder /app/package*.json ./
COPY --from=builder /app/dist/ ./dist/

RUN npm ci --only=production

EXPOSE 4000

CMD ["node", "dist/gateway.js"]
```

## Creating Your First Subgraph with TypeScript

Subgraphs are individual GraphQL services that contribute to your federated graph. Let's create a TypeScript-based subgraph for patient data.

### Create a Subgraph Project

```bash
# Create a new directory for your subgraph
mkdir -p subgraphs/patients-subgraph
cd subgraphs/patients-subgraph

# Initialize a new TypeScript project
npm init -y
npm install typescript ts-node @types/node --save-dev
npx tsc --init

# Install Apollo Federation dependencies
npm install @apollo/subgraph @apollo/server graphql
```

### Create the Subgraph Schema with TypeScript

Create a new file at `src/schema.ts` with the following content:

```typescript
// src/schema.ts
import { gql } from 'graphql-tag';

// Define the GraphQL schema using Federation 2.0 directives
export const typeDefs = gql`
  # Extend the federation schema
  extend schema @link(url: "https://specs.apollo.dev/federation/v2.0", import: ["@key", "@external", "@shareable"])

  # Define the Patient entity
  type Patient @key(fields: "id") {
    id: ID!
    mrn: String!
    firstName: String!
    lastName: String!
    dateOfBirth: String!
    gender: Gender!
    contactInfo: ContactInfo
    createdAt: String!
    updatedAt: String!
  }

  # Define supporting types
  type ContactInfo @shareable {
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

  # Define enums
  enum Gender {
    MALE
    FEMALE
    OTHER
    UNKNOWN
  }

  # Define queries
  type Query {
    patient(id: ID!): Patient
    patients(limit: Int = 10, offset: Int = 0): [Patient!]!
    searchPatients(query: String!): [Patient!]!
  }

  # Define mutations
  type Mutation {
    createPatient(input: PatientInput!): Patient!
    updatePatient(id: ID!, input: PatientInput!): Patient!
  }

  # Define input types
  input PatientInput {
    mrn: String!
    firstName: String!
    lastName: String!
    dateOfBirth: String!
    gender: Gender!
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
`;
```

### Create Resolvers

Create a new file named `resolvers.ts` with the following content:

```typescript
// resolvers.ts
```typescript
// src/resolvers.ts
import { Resolvers } from './types';

// Define TypeScript interfaces for our data model
interface Patient {
  id: string;
  mrn: string;
  firstName: string;
  lastName: string;
  dateOfBirth: string;
  gender: 'MALE' | 'FEMALE' | 'OTHER' | 'UNKNOWN';
  contactInfo?: {
    email?: string;
    phone?: string;
    address?: {
      line1: string;
      line2?: string;
      city: string;
      state: string;
      postalCode: string;
      country: string;
    };
  };
  createdAt: string;
  updatedAt: string;
}

// Sample data for development
const patients: Patient[] = [
  {
    id: '1',
    mrn: 'MRN12345',
    firstName: 'John',
    lastName: 'Doe',
    dateOfBirth: '1980-01-01',
    gender: 'MALE',
    contactInfo: {
      email: 'john.doe@example.com',
      phone: '555-123-4567',
      address: {
        line1: '123 Main St',
        city: 'Anytown',
        state: 'CA',
        postalCode: '12345',
        country: 'USA'
      }
    },
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString()
  },
  {
    id: '2',
    mrn: 'MRN67890',
    firstName: 'Jane',
    lastName: 'Smith',
    dateOfBirth: '1985-05-15',
    gender: 'FEMALE',
    contactInfo: {
      email: 'jane.smith@example.com',
      phone: '555-987-6543',
      address: {
        line1: '456 Oak Ave',
        city: 'Somewhere',
        state: 'NY',
        postalCode: '67890',
        country: 'USA'
      }
    },
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString()
  }
];

// Implement resolvers with TypeScript types
export const resolvers: Resolvers = {
  Query: {
    patient: (_, { id }) => patients.find(p => p.id === id) || null,
    patients: (_, { limit = 10, offset = 0 }) => patients.slice(offset, offset + limit),
    searchPatients: (_, { query }) => {
      const lowercaseQuery = query.toLowerCase();
      return patients.filter(p => 
        p.firstName.toLowerCase().includes(lowercaseQuery) || 
        p.lastName.toLowerCase().includes(lowercaseQuery) || 
        p.mrn.toLowerCase().includes(lowercaseQuery)
      );
    }
  },
  Mutation: {
    createPatient: (_, { input }) => {
      const newPatient: Patient = {
        id: String(patients.length + 1),
        mrn: input.mrn,
        firstName: input.firstName,
        lastName: input.lastName,
        dateOfBirth: input.dateOfBirth,
        gender: input.gender,
        contactInfo: input.contactInfo,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString()
      };
      patients.push(newPatient);
      return newPatient;
    },
    updatePatient: (_, { id, input }) => {
      const patientIndex = patients.findIndex(p => p.id === id);
      if (patientIndex === -1) throw new Error(`Patient with ID ${id} not found`);
      
      // Update patient fields
      const updatedPatient = {
        ...patients[patientIndex],
        ...input,
        updatedAt: new Date().toISOString()
      };
      
      patients[patientIndex] = updatedPatient;
      return updatedPatient;
    }
  },
  Patient: {
    __resolveReference: (reference) => {
      return patients.find(p => p.id === reference.id) || null;
    }
  }
};

// Generate TypeScript types from GraphQL schema
// Create a file named src/types.ts with the following content:
// ```typescript
// export interface Resolvers {
//   Query: {
//     patient: (parent: any, args: { id: string }, context: any, info: any) => Patient | null;
//     patients: (parent: any, args: { limit?: number, offset?: number }, context: any, info: any) => Patient[];
//     searchPatients: (parent: any, args: { query: string }, context: any, info: any) => Patient[];
//   };
//   Mutation: {
//     createPatient: (parent: any, args: { input: PatientInput }, context: any, info: any) => Patient;
//     updatePatient: (parent: any, args: { id: string, input: PatientInput }, context: any, info: any) => Patient;
//   };
//   Patient: {
//     __resolveReference: (reference: { id: string }) => Patient | null;
//   };
// }
// ```
```

### Create the Subgraph Server with TypeScript

Create a new file at `src/index.ts` with the following content:

```typescript
// src/index.ts
import { ApolloServer } from '@apollo/server';
import { startStandaloneServer } from '@apollo/server/standalone';
import { buildSubgraphSchema } from '@apollo/subgraph';
import { expressMiddleware } from '@apollo/server/express4';
import express from 'express';
import http from 'http';
import cors from 'cors';
import { json } from 'body-parser';

import { typeDefs } from './schema';
import { resolvers } from './resolvers';

// Define environment variables with defaults for cloud configuration
const PORT = process.env.PORT || 4001;

// Create the federated schema
const schema = buildSubgraphSchema([{ typeDefs, resolvers }]);

// Initialize the Apollo Server with the federated schema
const server = new ApolloServer({
  schema,
  // Enable introspection for development (disable in production)
  introspection: process.env.NODE_ENV !== 'production'
});

// Set up Express middleware for advanced configuration
async function startApolloServer() {
  // Start the Apollo Server
  await server.start();
  
  // Create Express app and HTTP server for more control
  const app = express();
  const httpServer = http.createServer(app);
  
  // Set up health check endpoint for Kubernetes
  app.get('/health', (req, res) => {
    res.status(200).send('OK');
  });
  
  // Set up Apollo middleware with authentication
  app.use(
    '/graphql',
    cors<cors.CorsRequest>(),
    json(),
    expressMiddleware(server, {
      context: async ({ req }) => {
        // Extract JWT token from Authorization header
        const token = req.headers.authorization || '';
        
        return { token };
      }
    })
  );
  
  // Start the HTTP server
  await new Promise<void>((resolve) => {
    httpServer.listen({ port: PORT }, resolve);
  });
  
  console.log(`🚀 Patients subgraph ready at http://localhost:${PORT}/graphql`);
  return { server, app, httpServer };
}

// Start the server
startApolloServer().catch(err => {
  console.error('Failed to start Apollo Server:', err);
});
```

### Containerize the Subgraph

Create a `Dockerfile` in the subgraph directory:

```dockerfile
FROM node:18-alpine as builder

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY tsconfig.json ./
COPY src/ ./src/

RUN npm run build

# Production image
FROM node:18-alpine

WORKDIR /app

COPY --from=builder /app/package*.json ./
COPY --from=builder /app/dist/ ./dist/

RUN npm ci --only=production

EXPOSE 4001

CMD ["node", "dist/index.js"]
```

### Start the Subgraph

```bash
# For development
npx ts-node src/index.ts

# Or build and run for production
npm run build
node dist/index.js

# Or using Docker
docker build -t patients-subgraph .
docker run -p 4001:4001 patients-subgraph
```

## Connecting the Gateway to Your Subgraphs

Now that you have a subgraph running, let's update the gateway configuration to use it and prepare for a cloud-native deployment.

### Update the Gateway Configuration

Modify your `src/gateway.ts` file to include your subgraph and add service discovery capabilities:

```typescript
// src/gateway.ts
import { ApolloServer } from '@apollo/server';
import { startStandaloneServer } from '@apollo/server/standalone';
import { ApolloGateway, IntrospectAndCompose, RemoteGraphQLDataSource } from '@apollo/gateway';
import { expressMiddleware } from '@apollo/server/express4';
import express from 'express';
import http from 'http';
import cors from 'cors';
import { json } from 'body-parser';

// Custom data source class that adds authentication headers to subgraph requests
class AuthenticatedDataSource extends RemoteGraphQLDataSource {
  willSendRequest({ request, context }: any) {
    // Pass the user's token to downstream services
    if (context.token) {
      request.http.headers.set('Authorization', context.token);
    }
    
    // Add additional headers for tracing and monitoring
    request.http.headers.set('x-request-id', context.requestId || generateRequestId());
  }
}

// Helper function to generate a unique request ID
function generateRequestId(): string {
  return `req-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
}

// Define environment variables with defaults for cloud configuration
const PORT = process.env.PORT || 4000;

// Service discovery - either from environment variables or Kubernetes service discovery
const getSubgraphs = () => {
  // If running in Kubernetes, use service discovery
  if (process.env.KUBERNETES_SERVICE_HOST) {
    return [
      { name: 'patients', url: 'http://patients-service:4001/graphql' },
      { name: 'encounters', url: 'http://encounters-service:4002/graphql' },
      { name: 'medications', url: 'http://medications-service:4003/graphql' }
    ];
  }
  
  // For local development or custom configuration
  if (process.env.SUBGRAPH_LIST) {
    return JSON.parse(process.env.SUBGRAPH_LIST);
  }
  
  // Default for local development
  return [
    { name: 'patients', url: 'http://localhost:4001/graphql' }
    // Add more subgraphs as you create them
  ];
};

// Initialize the gateway with supergraph composition and authenticated data source
const gateway = new ApolloGateway({
  supergraphSdl: new IntrospectAndCompose({
    subgraphs: getSubgraphs()
  }),
  buildService({ url }) {
    return new AuthenticatedDataSource({ url });
  }
});

// Rest of the code remains the same...
```

### Create a Docker Compose File for Local Development

Create a `docker-compose.yml` file in the root directory to run the gateway and subgraphs together:

```yaml
version: '3.8'

services:
  gateway:
    build: .
    ports:
      - '4000:4000'
    environment:
      - PORT=4000
      - NODE_ENV=development
    depends_on:
      - patients-subgraph

  patients-subgraph:
    build: ./subgraphs/patients-subgraph
    ports:
      - '4001:4001'
    environment:
      - PORT=4001
      - NODE_ENV=development

  # Add more subgraphs as you create them
```

### Kubernetes Deployment

Create Kubernetes manifests for production deployment in a `k8s` directory:

```yaml
# k8s/gateway-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: federated-gateway
  labels:
    app: federated-gateway
spec:
  replicas: 2
  selector:
    matchLabels:
      app: federated-gateway
  template:
    metadata:
      labels:
        app: federated-gateway
    spec:
      containers:
      - name: gateway
        image: ${YOUR_REGISTRY}/federated-gateway:latest
        ports:
        - containerPort: 4000
        env:
        - name: PORT
          value: "4000"
        - name: NODE_ENV
          value: "production"
        livenessProbe:
          httpGet:
            path: /health
            port: 4000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 4000
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: federated-gateway
spec:
  selector:
    app: federated-gateway
  ports:
  - port: 80
    targetPort: 4000
  type: ClusterIP
```

### Start the Gateway and Subgraphs

```bash
# For local development with Docker Compose
docker-compose up -d

# For Kubernetes deployment
kubectl apply -f k8s/
```

## Testing Your Federated Graph

With both your gateway and subgraphs running, you can now test your federated graph using modern tools and approaches.

### Local Testing with Apollo Explorer

1. Open your browser and navigate to `http://localhost:4000/graphql`
2. You should see the Apollo Explorer interface
3. Try running a patient query:

```graphql
query GetPatients {
  patients(limit: 5) {
    id
    mrn
    firstName
    lastName
    dateOfBirth
    gender
    contactInfo {
      email
      phone
    }
  }
}
```

4. Try running a mutation to create a new patient:

```graphql
mutation CreatePatient {
  createPatient(input: {
    mrn: "MRN98765"
    firstName: "Robert"
    lastName: "Johnson"
    dateOfBirth: "1975-08-22"
    gender: MALE
    contactInfo: {
      email: "robert.johnson@example.com"
      phone: "555-321-9876"
      address: {
        line1: "789 Pine St"
        city: "Metropolis"
        state: "IL"
        postalCode: "54321"
        country: "USA"
      }
    }
  }) {
    id
    mrn
    firstName
    lastName
  }
}
```

### Automated Testing with Jest and TypeScript

Create a test directory with a sample test file at `src/__tests__/gateway.test.ts`:

```typescript
// src/__tests__/gateway.test.ts
import { ApolloServer } from '@apollo/server';
import { buildSubgraphSchema } from '@apollo/subgraph';
import { typeDefs } from '../schema';
import { resolvers } from '../resolvers';
import { gql } from 'graphql-tag';

describe('Federated Graph API', () => {
  let testServer: ApolloServer;

  beforeAll(async () => {
    // Create a test server with the schema
    const schema = buildSubgraphSchema([{ typeDefs, resolvers }]);
    testServer = new ApolloServer({ schema });
    await testServer.start();
  });

  afterAll(async () => {
    await testServer.stop();
  });

  it('should query patients', async () => {
    const query = gql`
      query {
        patients(limit: 2) {
          id
          mrn
          firstName
          lastName
        }
      }
    `;

    const response = await testServer.executeOperation({ query });
    expect(response.body.kind).toBe('single');
    expect(response.body.singleResult.errors).toBeUndefined();
    expect(response.body.singleResult.data?.patients).toHaveLength(2);
  });

  it('should create a patient', async () => {
    const mutation = gql`
      mutation {
        createPatient(input: {
          mrn: "TEST123"
          firstName: "Test"
          lastName: "User"
          dateOfBirth: "2000-01-01"
          gender: MALE
        }) {
          id
          mrn
          firstName
          lastName
        }
      }
    `;

    const response = await testServer.executeOperation({ query: mutation });
    expect(response.body.kind).toBe('single');
    expect(response.body.singleResult.errors).toBeUndefined();
    expect(response.body.singleResult.data?.createPatient).toMatchObject({
      mrn: "TEST123",
      firstName: "Test",
      lastName: "User"
    });
  });
});
```

### Performance Testing with k6

Create a performance test file at `performance/k6-test.js`:

```javascript
// performance/k6-test.js
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  vus: 10,  // Virtual users
  duration: '30s',
  thresholds: {
    http_req_duration: ['p(95)<500'], // 95% of requests should be below 500ms
  },
};

export default function() {
  const query = `
    query {
      patients(limit: 10) {
        id
        mrn
        firstName
        lastName
      }
    }
  `;

  const response = http.post('http://localhost:4000/graphql', JSON.stringify({
    query: query
  }), {
    headers: {
      'Content-Type': 'application/json',
    },
  });

  check(response, {
    'status is 200': (r) => r.status === 200,
    'no errors': (r) => !JSON.parse(r.body).errors,
    'has data': (r) => JSON.parse(r.body).data,
  });

  sleep(1);
}
```

## Next Steps

Now that you have a modern, TypeScript-based federated GraphQL API running, you can:

1. **Expand Your Schema**: Create additional subgraphs for encounters, medications, and other healthcare domains
2. **Implement Advanced Authentication**: Add OAuth 2.0 or OpenID Connect with role-based permissions
3. **Set Up Observability**: Integrate with cloud monitoring tools like Prometheus, Grafana, and OpenTelemetry
4. **Implement CI/CD**: Create GitHub Actions or other CI/CD pipelines for automated testing and deployment
5. **Add Schema Validation**: Implement schema validation and linting in your development workflow
6. **Deploy to Kubernetes**: Use Helm charts for production deployment to Kubernetes

Refer to the following documentation for guidance on these next steps:

- [Authentication](../02-core-functionality/authentication.md): Secure your federated graph
- [Schema Federation Patterns](../03-advanced-patterns/schema-federation.md): Design patterns for healthcare data
- [Monitoring](../05-operations/monitoring.md): Set up comprehensive monitoring
- [Deployment](../05-operations/deployment.md): Deploy to production environments

## Troubleshooting

### Common Issues in Cloud-Native Deployments

#### Gateway Cannot Connect to Subgraphs

If your gateway cannot connect to your subgraphs in a cloud environment:

- Check Kubernetes service discovery and DNS resolution
- Verify network policies allow communication between gateway and subgraph pods
- Ensure service names and ports are correctly configured in environment variables
- Check for TLS certificate issues if using HTTPS
- Examine Kubernetes logs for connection errors:
  ```bash
  kubectl logs deployment/federated-gateway
  kubectl logs deployment/patients-subgraph
  ```

#### TypeScript Compilation Errors

If you encounter TypeScript compilation issues:

- Ensure your `tsconfig.json` settings are correct for your Node.js version
- Check for type compatibility issues in GraphQL resolvers
- Verify that all required type definitions are imported correctly
- Run TypeScript in watch mode during development:
  ```bash
  npx tsc --watch
  ```

#### Schema Composition Errors

If you encounter schema composition errors in a federated setup:

- Ensure all entity keys are properly defined with the `@key` directive
- Check for naming conflicts across subgraphs
- Verify that extended types have the same key fields in all subgraphs
- Use the Apollo Federation Rover CLI to validate your supergraph:
  ```bash
  npx rover supergraph compose --config ./supergraph.yaml
  ```

#### Docker and Kubernetes Issues

- **Docker Build Failures**: Ensure your Dockerfile has the correct build steps for TypeScript
- **Container Startup Issues**: Check for environment variables required at runtime
- **Kubernetes Pod Crashes**: Check for resource constraints or configuration issues:
  ```bash
  kubectl describe pod federated-gateway
  kubectl logs -p federated-gateway
  ```

#### Performance Issues

If your federated graph is slow in production:

- Enable Apollo Federation query planning logs to identify bottlenecks
- Implement DataLoader pattern to batch and cache database requests
- Consider implementing Apollo Cache Control for response caching
- Use distributed tracing with OpenTelemetry to identify slow subgraphs
- Scale subgraphs independently based on their specific load patterns
- Monitor GraphQL query complexity and implement query cost analysis

```typescript
// Example: Adding DataLoader to a resolver
import DataLoader from 'dataloader';

// Create a batch loading function
const batchLoadPatients = async (ids: readonly string[]) => {
  console.log(`Loading ${ids.length} patients in a single batch`);
  
  // In a real app, this would be a database query
  const patients = await PatientModel.findByIds(ids);
  
  // Return patients in the same order as the ids
  return ids.map(id => patients.find(patient => patient.id === id) || null);
};

// Create a new data loader in your context function
const context = async ({ req }) => {
  return {
    token: req.headers.authorization || '',
    loaders: {
      patients: new DataLoader(batchLoadPatients)
    }
  };
};

// Use the loader in your resolver
const resolvers = {
  Query: {
    patient: (_, { id }, { loaders }) => {
      return loaders.patients.load(id);
    }
  }
};
```

## Conclusion

You now have a modern, cloud-native Federated Graph API built with TypeScript that you can extend and customize to meet your healthcare application needs. This architecture provides type safety, scalability, and maintainability for complex healthcare data scenarios.

As you continue to develop your federated graph:

1. Leverage TypeScript's type system to ensure data consistency across subgraphs
2. Use cloud-native deployment patterns for resilience and scalability
3. Implement comprehensive monitoring and observability
4. Follow security best practices for healthcare data protection

Refer to the other guides in this documentation for advanced techniques and best practices as you expand your federated graph implementation.
