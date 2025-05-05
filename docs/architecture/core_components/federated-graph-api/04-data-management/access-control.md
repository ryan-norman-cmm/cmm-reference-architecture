# Data Access Control

## Introduction

Data access control is the practice of ensuring that only authorized users can view or modify sensitive information in your federated GraphQL API. In healthcare, robust access control is critical for protecting patient privacy, complying with regulations, and supporting multi-tenant architectures. This document provides actionable strategies for:
- Implementing user-based access control (RBAC)
- Isolating data for different tenants or organizations
- Masking or filtering sensitive data at the API layer
- Auditing and logging data access for compliance

By following these patterns, you can build a secure, compliant, and trustworthy federated graph for healthcare and other sensitive domains.

## Access Control with Apollo GraphOS

Apollo GraphOS Enterprise provides advanced access control features for federated GraphQL APIs, including:
- Operation safelisting (allow only approved queries/mutations)
- Field-level analytics to identify and secure sensitive data
- Role-based access control (RBAC) integration with your identity provider
- Usage analytics and audit logging for compliance

### Example: Operation Safelisting in GraphOS
- Upload a safelist of allowed operations in the GraphOS UI or via Rover CLI.
- Only safelisted operations can be executed by clients, preventing unauthorized or costly queries.

### Example: Schema Checks and RBAC Integration
```yaml
name: GraphOS Access Control Check
on: [pull_request]
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Install Rover
        run: npm install -g @apollo/rover
      - name: Check Safelist and RBAC
        run: |
          rover safelist check my-graph@current --file ./safelist.json
```

- Integrate GraphOS RBAC with your identity provider for centralized policy management.
- Use field-level analytics and Explorer to review sensitive field access and tighten controls as needed.
- Monitor and audit all access via GraphOS dashboards and logs.
- Reference the official docs for advanced usage: [Apollo GraphOS Access Control](https://www.apollographql.com/docs/graphos/)

---

### Quick Start

1. Implement user-based access control with roles and permissions
2. Set up tenant isolation for multi-tenant environments
3. Configure data masking for sensitive fields
4. Implement comprehensive audit logging
5. Test your access control implementation

### Related Components

- [Authentication](../02-core-functionality/authentication.md): Authenticate users before applying access control
- [Custom Directives](../03-advanced-patterns/custom-directives.md): Use directives for declarative access control
- [Schema Governance](schema-governance.md): Manage access control across teams
- [Monitoring](../05-operations/monitoring.md): Monitor access patterns and potential security issues

## User-Based Access Control

### Overview

User-based access control (UBAC), often implemented as role-based access control (RBAC), restricts data access based on user identity and assigned roles. In a federated GraphQL API, RBAC ensures that only users with the appropriate permissions can access sensitive resources or perform specific operations.

### Rationale
- **Security**: Prevent unauthorized access to protected data.
- **Compliance**: Enforce regulatory requirements (HIPAA, GDPR, etc.).
- **Flexibility**: Support multiple user types (clinicians, patients, admins, etc.).

### Implementation Steps
1. Define roles and permissions in your authentication/identity provider.
2. Propagate user roles to the GraphQL context at the gateway.
3. Enforce RBAC in resolvers or using authorization directives.

### Example: RBAC Enforcement in a Resolver
```javascript
const { ForbiddenError } = require('apollo-server');

const resolvers = {
  Query: {
    patient: async (_, { id }, context) => {
      const user = context.user;
      if (!user || !user.roles.includes('clinician')) {
        throw new ForbiddenError('You do not have permission to access patient data');
      }
      return context.dataSources.patientAPI.getPatientById(id);
    }
  }
};
```

### Example: RBAC with Authorization Directive
```graphql
directive @requireRole(role: String!) on FIELD_DEFINITION

type Patient {
  id: ID!
  name: String!
  birthDate: String
}

extend type Query {
  patient(id: ID!): Patient @requireRole(role: "clinician")
}
```

### Best Practices
- Define roles and permissions centrally and keep them in sync with your schema.
- Use schema directives for declarative, reusable RBAC enforcement.
- Test access control for both allowed and denied scenarios.
- Log access attempts for auditing and compliance.


## Tenant Isolation

### Overview

Tenant isolation ensures that data belonging to one organization, department, or customer (tenant) is not accessible to others in a multi-tenant federated GraphQL API. This is especially important in healthcare, where multiple clinics or hospital systems may share the same infrastructure but must keep patient data strictly separated.

### Rationale
- **Privacy**: Prevent data leakage between tenants.
- **Compliance**: Meet regulatory requirements for data segregation.
- **Scalability**: Support many organizations on a single platform.

### Implementation Steps
1. Identify the tenant context for each request (e.g., from JWT claims, headers, or session).
2. Propagate tenant context to subgraphs via the gateway context.
3. Filter queries and mutations in resolvers based on the tenant context.

### Example: Tenant Context in Gateway
```javascript
const server = new ApolloServer({
  gateway,
  context: ({ req }) => {
    // Extract tenant from a header or JWT
    const tenantId = req.headers['x-tenant-id'] || getTenantFromJWT(req.headers.authorization);
    return { tenantId };
  }
});
```

### Example: Resolver-Level Tenant Filtering
```javascript
const resolvers = {
  Query: {
    patients: async (_, __, context) => {
      // Only return patients for the current tenant
      return context.dataSources.patientAPI.getPatientsByTenant(context.tenantId);
    }
  }
};
```

### Best Practices
- Always enforce tenant filtering in every resolver that accesses tenant data.
- Validate tenant context at the gateway and subgraph entry points.
- Log and monitor cross-tenant access attempts for auditing.
- Document tenant isolation logic and test for edge cases (e.g., admin users, shared resources).


## Data Masking and Filtering

### Overview

Data masking and filtering are techniques used to prevent exposure of sensitive information to unauthorized users. In a federated GraphQL API, you can mask fields (e.g., SSN, contact info) or filter results (e.g., only show patients assigned to a clinician) based on user roles, permissions, or context.

### Rationale
- **Privacy**: Hide or redact sensitive fields for unauthorized users.
- **Security**: Prevent accidental data leaks in API responses.
- **Compliance**: Meet regulatory requirements for data minimization.

### Implementation Steps
1. Identify sensitive fields in your schema (e.g., SSN, address, insurance details).
2. Use transformation directives (e.g., `@mask`) or conditional logic in resolvers to redact or filter data.
3. Apply field-level authorization to restrict access based on user roles.

### Example: Masking a Sensitive Field with a Directive
```graphql
directive @mask(maskWith: String = "****") on FIELD_DEFINITION

type Patient {
  id: ID!
  name: String!
  ssn: String @mask(maskWith: "XXX-XX-****")
}
```

### Example: Filtering Results in a Resolver
```javascript
const resolvers = {
  Query: {
    patients: async (_, __, context) => {
      const user = context.user;
      let patients = await context.dataSources.patientAPI.getAllPatients();
      // Only show assigned patients for non-admin users
      if (!user.roles.includes('admin')) {
        patients = patients.filter(p => p.assignedClinicianId === user.id);
      }
      return patients;
    }
  }
};
```

### Best Practices
- Document which fields are masked or filtered and under what conditions.
- Use declarative directives for masking to ensure consistency.
- Test masking and filtering logic for both authorized and unauthorized users.
- Regularly review and update masking/filtering rules as requirements change.


## Audit Logging

### Overview

Audit logging tracks who accessed what data, when, and how. In a federated GraphQL API—especially in healthcare—comprehensive audit logs are essential for compliance, security investigations, and operational transparency.

### Rationale
- **Compliance**: Meet regulatory requirements (HIPAA, GDPR, etc.) for data access tracking.
- **Security**: Detect unauthorized or suspicious access patterns.
- **Accountability**: Provide traceability for data changes and queries.

### Implementation Steps
1. Capture relevant context for each request (user ID, roles, operation, resource, timestamp, client IP).
2. Log access at the gateway and/or subgraph level for both queries and mutations.
3. Store logs in a secure, tamper-evident system (e.g., centralized log management, SIEM).
4. Regularly review and audit logs for anomalies.

### Example: Logging Access at the Gateway
```javascript
const server = new ApolloServer({
  gateway,
  plugins: [{
    requestDidStart(requestContext) {
      const { user, operationName, request } = requestContext.context;
      const timestamp = new Date().toISOString();
      console.log(`[AUDIT]`, {
        userId: user?.id,
        operation: operationName,
        query: request.query,
        variables: request.variables,
        timestamp
      });
    }
  }]
});
```

### Example: Logging Mutations in a Resolver
```javascript
const resolvers = {
  Mutation: {
    updatePatient: async (_, args, context) => {
      // ...mutation logic...
      context.logger.info({
        event: 'updatePatient',
        userId: context.user.id,
        patientId: args.id,
        timestamp: new Date().toISOString()
      });
      return updatedPatient;
    }
  }
};
```

### Best Practices
- Log both successful and failed access attempts.
- Store logs securely and back them up regularly.
- Use structured logging (JSON) for easier analysis and integration with SIEM tools.
- Automate log review and alerting for suspicious activity.
- Document your logging strategy for compliance and operational readiness.


## Conclusion

Effective data access control is essential for protecting sensitive information, complying with regulations, and building trust in your federated GraphQL API. By combining RBAC, tenant isolation, data masking, and audit logging, you can create a secure and compliant API that meets the needs of modern healthcare and other sensitive domains.

**Key takeaways:**
- Implement RBAC and field-level authorization for strong user-based access control.
- Enforce tenant isolation to prevent cross-organization data leakage.
- Use masking and filtering to minimize exposure of sensitive data.
- Log and audit all access attempts for compliance and security.

Continue to review and update your access control strategies as your application evolves and regulatory requirements change.

