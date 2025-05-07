# Federated Graph API Customization

## Introduction
The Federated Graph API provides multiple customization options that enable teams to tailor the GraphQL interface to their specific requirements without compromising the integrity of the federated graph. This document outlines the customizable elements, configuration options, and best practices for extending the Federated Graph API.

## Customizable Elements

### Gateway Customization

| Customizable Element | Description | Use Cases |
|----------------------|-------------|-----------|
| **Apollo Router Configuration** | Customize routing, caching, and request handling | Fine-tune performance, implement custom request handling |
| **Authentication Mechanisms** | Configure identity providers and auth methods | Integrate with existing IdP, implement custom auth flows |
| **Authorization Rules** | Define authorization scopes and permissions | Implement field-level authorization, role-based access |
| **Request/Response Plugins** | Add custom processing logic for requests/responses | Add custom headers, validate input, transform responses |
| **CORS Configuration** | Configure Cross-Origin Resource Sharing | Support multiple web applications with different origins |
| **Rate Limiting** | Configure rate limiting policies | Protect against abuse, ensure fair service usage |
| **Query Complexity Analysis** | Configure query complexity calculation | Prevent resource-intensive queries |

### Subgraph Customization

| Customizable Element | Description | Use Cases |
|----------------------|-------------|-----------|
| **Resolvers** | Customize data resolution logic | Implement domain-specific data transformations |
| **Custom Scalars** | Define custom scalar types | Add support for domain-specific data formats |
| **Directives** | Create custom directives | Add metadata annotations, implement cross-cutting concerns |
| **Type Policies** | Configure caching and merge behavior | Fine-tune caching strategy, control entity reference resolution |
| **Error Formatting** | Customize error messages and handling | Implement domain-specific error handling |
| **Subgraph Metrics** | Configure metrics collection | Implement domain-specific performance monitoring |

### Schema Customization

| Customizable Element | Description | Use Cases |
|----------------------|-------------|-----------|
| **Type Extensions** | Extend existing types with new fields | Add domain-specific fields to shared entities |
| **Interface Implementation** | Implement shared interfaces | Create consistent behavior across domains |
| **Custom Entity References** | Define custom entity reference resolvers | Optimize entity resolution for specific domains |
| **Schema Comments** | Add documentation to schema elements | Enhance developer experience with domain-specific guidance |
| **Default Values** | Configure default values for fields | Implement sensible defaults for domain-specific fields |
| **Deprecation Policies** | Configure field and type deprecation | Manage schema evolution within a domain |

## Configuration Options

### Gateway Configuration

The Apollo Router's behavior can be customized through the `router.yaml` configuration file:

```yaml
# Example router.yaml configuration
supergraph:
  listen: 0.0.0.0:4000
  
health_check:
  listen: 0.0.0.0:8088
  
telemetry:
  tracing:
    datadog:
      service_name: "federated-graph-api"
  
cors:
  allow_any_origin: false
  allow_credentials: true
  origins:
    - https://app.covermymeds.com
    - https://portal.covermymeds.com
  
headers:
  all:
    request:
      - insert:
          name: "x-service-name"
          value: "federated-graph-api"
  
sandbox:
    enabled: true
    
plugins:
  experimental.expose_query_plan: true

limits:
  max_depth: 15
  max_height: 200
  max_aliases: 30
  max_root_fields: 20
  
compression:
  enabled: true
  
include_subgraph_errors:
  all: true

preview_entities_limit: 10
```

### Subgraph Configuration

Individual subgraphs can be customized through their deployment configuration:

```yaml
# Example subgraph deployment configuration
apiVersion: apps/v1
kind: Deployment
metadata:
  name: patient-subgraph
  namespace: federated-graph
spec:
  replicas: 3
  selector:
    matchLabels:
      app: patient-subgraph
  template:
    metadata:
      labels:
        app: patient-subgraph
    spec:
      containers:
      - name: patient-subgraph
        image: covermymeds/patient-subgraph:1.2.3
        ports:
        - containerPort: 4001
        env:
        - name: NODE_ENV
          value: "production"
        - name: LOG_LEVEL
          value: "info"
        - name: ENABLE_TRACING
          value: "true"
        - name: ENABLE_METRICS
          value: "true"
        - name: CACHE_TTL_SECONDS
          value: "300"
        - name: DEFAULT_QUERY_TIMEOUT_MS
          value: "5000"
        - name: MAX_CONNECTION_POOL_SIZE
          value: "10"
        - name: PATIENT_DATA_SOURCE_URL
          valueFrom:
            configMapKeyRef:
              name: patient-subgraph-config
              key: patient_data_source_url
        - name: AUTH_SECRET
          valueFrom:
            secretKeyRef:
              name: patient-subgraph-secrets
              key: auth_secret
        resources:
          limits:
            cpu: "1"
            memory: "1Gi"
          requests:
            cpu: "0.5"
            memory: "512Mi"
```

### Schema Customization

Customize schema behavior through type definitions and directives:

```graphql
# Example schema customization
extend type Patient @key(fields: "id") {
  # Custom field added by the Clinical domain
  clinicalRiskScore: Float @requiresPermission(permission: "clinical:read")
  
  # Custom field with custom resolver logic
  medicationCompliance: ComplianceStatus @computed
  
  # Field with custom directive for sensitive data
  socialSecurityNumber: String @redact
}

# Custom directive for computed fields
directive @computed on FIELD_DEFINITION

# Custom directive for redacting sensitive data
directive @redact(
  replacement: String = "REDACTED"
) on FIELD_DEFINITION

# Custom scalar for healthcare-specific IDs
scalar FHIR_ID

# Custom interface for medical resources
interface MedicalResource {
  id: FHIR_ID!
  lastUpdated: DateTime!
  version: String!
}

# Implementation of the MedicalResource interface
type Observation implements MedicalResource {
  id: FHIR_ID!
  lastUpdated: DateTime!
  version: String!
  code: CodeableConcept!
  value: ObservationValue
  status: ObservationStatus!
  issued: DateTime
  performer: [Reference!]
}
```

## Example Customization

### Custom Authorization Directive Implementation

This example demonstrates how to implement a custom authorization directive for field-level permissions:

```typescript
// In auth-directives.ts
import { mapSchema, getDirective, MapperKind } from '@graphql-tools/utils';
import { defaultFieldResolver, GraphQLSchema } from 'graphql';

// Create auth directive transformer
export function authDirectiveTransformer(schema: GraphQLSchema): GraphQLSchema {
  return mapSchema(schema, {
    // Process object fields that have the @requiresPermission directive
    [MapperKind.OBJECT_FIELD]: (fieldConfig) => {
      // Get directive from field
      const requiresPermissionDirective = getDirective(
        schema,
        fieldConfig,
        'requiresPermission'
      )?.[0];

      if (requiresPermissionDirective) {
        // Get required permission from directive argument
        const { permission } = requiresPermissionDirective;
        
        // Store original resolver
        const originalResolver = fieldConfig.resolve || defaultFieldResolver;
        
        // Replace resolver with wrapped version that checks permissions
        fieldConfig.resolve = async function (source, args, context, info) {
          const { user } = context;
          
          // Check if user has required permission
          if (!user || !user.permissions.includes(permission)) {
            throw new Error(`Not authorized. Required permission: ${permission}`);
          }
          
          // If authorized, execute original resolver
          return originalResolver(source, args, context, info);
        };
        
        return fieldConfig;
      }
    }
  });
}

// Usage in subgraph server
import { ApolloServer } from '@apollo/server';
import { buildSubgraphSchema } from '@apollo/subgraph';
import { authDirectiveTransformer } from './auth-directives';

const server = new ApolloServer({
  schema: authDirectiveTransformer(
    buildSubgraphSchema([{ typeDefs, resolvers }])
  ),
  // ... other options
});
```

### Custom Metrics Plugin

This example demonstrates how to implement a custom metrics plugin for Apollo Router:

```typescript
// In metrics-plugin.ts
import {
  ApolloServerPlugin,
  GraphQLRequestContext,
  GraphQLRequestListener
} from '@apollo/server';
import { StatsD } from 'hot-shots';

// Create StatsD client
const statsd = new StatsD({
  host: process.env.STATSD_HOST || 'localhost',
  port: parseInt(process.env.STATSD_PORT || '8125', 10),
  prefix: 'fedgraph.'
});

// Custom metrics plugin
export const metricsPlugin = (): ApolloServerPlugin => {
  return {
    async requestDidStart(
      requestContext: GraphQLRequestContext<any>
    ): Promise<GraphQLRequestListener<any>> {
      const startTime = Date.now();
      const operationName = requestContext.request.operationName || 'unknown';
      
      // Increment request counter
      statsd.increment(`operation.${operationName}.count`);
      
      return {
        async didEncounterErrors({ errors }) {
          // Track errors by operation
          errors.forEach((error) => {
            const errorCode = error.extensions?.code || 'UNKNOWN_ERROR';
            statsd.increment(`operation.${operationName}.error.${errorCode}`);
          });
        },
        
        async willSendResponse() {
          // Record request duration
          const duration = Date.now() - startTime;
          statsd.timing(`operation.${operationName}.duration`, duration);
        }
      };
    }
  };
};

// Usage in subgraph server
import { ApolloServer } from '@apollo/server';
import { metricsPlugin } from './metrics-plugin';

const server = new ApolloServer({
  schema,
  plugins: [metricsPlugin()]
});
```

### Custom Federated Type Implementation

This example demonstrates how to implement a custom federated type across subgraphs:

```typescript
// In the Patient subgraph
const typeDefs = gql`
  type Patient @key(fields: "id") {
    id: ID!
    name: HumanName
    birthDate: String
    gender: Gender
    # Other patient fields...
  }
  
  type HumanName {
    use: NameUse
    text: String
    family: String
    given: [String!]
    prefix: [String!]
    suffix: [String!]
  }
  
  enum NameUse {
    USUAL
    OFFICIAL
    TEMP
    NICKNAME
    ANONYMOUS
    OLD
    MAIDEN
  }
  
  enum Gender {
    MALE
    FEMALE
    OTHER
    UNKNOWN
  }
`;

const resolvers = {
  Patient: {
    __resolveReference(reference) {
      return fetchPatientById(reference.id);
    }
  }
};

// In the Claims subgraph
const typeDefs = gql`
  type Patient @key(fields: "id") {
    id: ID!
    claims: [Claim!]
  }
  
  type Claim {
    id: ID!
    type: CodeableConcept
    subType: CodeableConcept
    use: ClaimUse
    patient: Patient!
    billablePeriod: Period
    created: DateTime
    provider: Reference
    priority: CodeableConcept
    insurance: [ClaimInsurance!]
    total: Money
  }
  
  # Other claim-related types...
`;

const resolvers = {
  Patient: {
    __resolveReference(reference) {
      return { id: reference.id };
    },
    claims(patient) {
      return fetchClaimsForPatient(patient.id);
    }
  }
};

// In the Medication subgraph
const typeDefs = gql`
  type Patient @key(fields: "id") {
    id: ID!
    medications: [MedicationStatement!]
  }
  
  type MedicationStatement {
    id: ID!
    status: MedicationStatementStatus!
    medication: Medication!
    subject: Patient!
    dateAsserted: DateTime!
    informationSource: Reference
    derivedFrom: [Reference!]
    reasonCode: [CodeableConcept!]
    dosage: [Dosage!]
  }
  
  # Other medication-related types...
`;

const resolvers = {
  Patient: {
    __resolveReference(reference) {
      return { id: reference.id };
    },
    medications(patient) {
      return fetchMedicationsForPatient(patient.id);
    }
  }
};
```

## Best Practices

### Schema Design

1. **Follow Naming Conventions**
   - Use consistent casing (camelCase for fields, PascalCase for types)
   - Use descriptive names that reflect domain concepts
   - Prefer longer, clearer names over short, ambiguous ones

2. **Design with Federation in Mind**
   - Define clear entity boundaries aligned with service boundaries
   - Use @key directive for entity references
   - Minimize cross-service dependencies

3. **Schema Evolution**
   - Never remove or change field types without deprecation
   - Use the @deprecated directive with a reason
   - Add new fields and types instead of changing existing ones
   - Consider schema versioning for major changes

### Performance Optimization

1. **Optimize Resolver Implementation**
   - Use dataloader for batching and caching
   - Implement efficient entity resolvers
   - Only fetch required fields from data sources

2. **Query Complexity Management**
   - Implement query complexity analysis
   - Set reasonable limits on query depth and breadth
   - Use pagination for large collections

3. **Caching Strategy**
   - Configure entity cache TTLs appropriate to the domain
   - Use cache hints for fine-grained control
   - Implement cache invalidation strategies

### Security Considerations

1. **Authentication Configuration**
   - Use standard JWT validation
   - Configure appropriate token lifetimes
   - Implement refresh token strategies

2. **Authorization Implementation**
   - Apply permission checks consistently
   - Implement field-level authorization
   - Consider both coarse and fine-grained permissions

3. **Input Validation**
   - Validate all user inputs
   - Use custom scalars for domain-specific validation
   - Implement rate limiting and throttling

### Healthcare-Specific Considerations

1. **PHI Handling**
   - Implement field-level redaction for sensitive fields
   - Use proper access control for PHI
   - Ensure compliance with HIPAA regulations

2. **Terminology Standards**
   - Use standard healthcare coding systems (SNOMED, LOINC, RxNorm)
   - Implement validation for terminology codes
   - Support multiple coding systems in parallel

3. **Clinical Data Representation**
   - Align with FHIR standards where possible
   - Use consistent data structures for clinical concepts
   - Support both structured and narrative content

## Related Resources
- [Federated Graph API Advanced Use Cases](./advanced-use-cases.md)
- [Federated Graph API Extension Points](./extension-points.md)
- [Federated Graph API Core APIs](../02-core-functionality/core-apis.md)
- [Apollo Federation Documentation](https://www.apollographql.com/docs/federation/)