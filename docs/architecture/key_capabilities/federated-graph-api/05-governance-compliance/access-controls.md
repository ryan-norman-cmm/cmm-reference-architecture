# Federated Graph API Access Controls

## Introduction
The Federated Graph API implements a comprehensive access control model to secure healthcare data and operations across the federated graph. This document outlines the role-based access control (RBAC) model, policy enforcement mechanisms, and authentication integration points to ensure secure and compliant access to the GraphQL API.

## Role-Based Access Control (RBAC)

The Federated Graph API implements a layered RBAC model that enforces access control at multiple levels:

### User Roles

| Role | Description | Scope | Example Use Cases |
|------|-------------|-------|------------------|
| `GraphAPI.Admin` | Full administrative access to the Federated Graph API | Global | Schema management, monitoring, operation auditing |
| `GraphAPI.Developer` | Access to development tools and non-PHI operations | Global | Schema exploration, introspection, testing |
| `GraphAPI.Schema.Manager` | Ability to manage schema registry and composition | Global | Schema publishing, schema checks, schema validation |
| `GraphAPI.Metrics.Reader` | Ability to view operational metrics | Global | Performance monitoring, usage analysis |
| `GraphAPI.Auditor` | Access to audit logs and compliance records | Global | Security review, compliance verification |
| `GraphAPI.Service` | Machine-to-machine service account access | Customizable | Backend service integration, data processing |

### Domain-Specific Roles

| Role | Description | Scope | Example Use Cases |
|------|-------------|-------|------------------|
| `Patient.Reader` | Read access to patient demographic data | Patient domain | Patient search, profile viewing |
| `Patient.Writer` | Write access to patient demographic data | Patient domain | Patient registration, profile updates |
| `Patient.Admin` | Administrative access to patient data | Patient domain | Patient record merging, bulk updates |
| `Clinical.Reader` | Read access to clinical data | Clinical domain | Viewing medical history, conditions |
| `Clinical.Writer` | Write access to clinical data | Clinical domain | Documenting conditions, updating status |
| `Medication.Reader` | Read access to medication data | Medication domain | Viewing medication history |
| `Medication.Writer` | Write access to medication data | Medication domain | Prescribing medications |
| `Pharmacy.Reader` | Read access to pharmacy data | Pharmacy domain | Viewing pharmacy information |
| `Pharmacy.Writer` | Write access to pharmacy data | Pharmacy domain | Updating pharmacy details |
| `Appointment.Reader` | Read access to appointment data | Scheduling domain | Viewing appointments |
| `Appointment.Writer` | Write access to appointment data | Scheduling domain | Scheduling appointments |

### Permission Sets

| Permission Set | Included Permissions | Description |
|----------------|----------------------|-------------|
| `patient:read` | `patient:demographics:read`, `patient:contact:read` | Read basic patient information |
| `patient:write` | `patient:demographics:write`, `patient:contact:write` | Create/update basic patient information |
| `clinical:read` | `clinical:conditions:read`, `clinical:observations:read`, `clinical:procedures:read` | Read clinical data |
| `clinical:write` | `clinical:conditions:write`, `clinical:observations:write`, `clinical:procedures:write` | Create/update clinical data |
| `medication:read` | `medication:prescriptions:read`, `medication:history:read` | Read medication data |
| `medication:write` | `medication:prescriptions:write` | Create/update medication data |
| `appointment:read` | `appointment:schedule:read` | Read appointment data |
| `appointment:write` | `appointment:schedule:write` | Create/update appointment data |

## Policy Enforcement

### Architecture

The Federated Graph API implements policy enforcement in multiple layers:

1. **Gateway Layer**: The Apollo Router enforces authentication and coarse-grained authorization policies
2. **Subgraph Layer**: Individual subgraphs enforce domain-specific access control
3. **Field Level**: GraphQL directives enforce field-level permissions
4. **Entity Level**: Entity-specific access control rules are evaluated during resolution

### Policy Decision Points

Policy decisions are made using a combination of:

1. **User Claims**: Identity information from authentication tokens
2. **Context Data**: Request context including client info, network origin, etc.
3. **Resource Attributes**: Properties of the requested resources
4. **Organizational Policies**: Organization-specific access control rules
5. **Compliance Requirements**: HIPAA and other regulatory constraints

### Implementation

The Federated Graph API implements policy enforcement using:

1. **Apollo Router Authorization**: JWT-based authorization rules in the gateway
2. **GraphQL Directives**: Field-level access control through `@requiresPermission` and related directives
3. **Custom Authorization Service**: A dedicated authorization service for complex policy decisions
4. **Domain-Specific Enforcement**: Domain-specific rules in subgraph resolvers

## Authentication Integration

The Federated Graph API supports multiple authentication methods:

### JWT-Based Authentication

The primary authentication method uses JWT tokens issued by the organization's identity provider:

- **Token Format**: JSON Web Tokens (JWTs) with RS256 signature
- **Claims**: Standard claims (`sub`, `iat`, `exp`) plus custom claims for roles and permissions
- **Validation**: Tokens validated using JWKS from trusted issuer
- **Lifetime**: Configurable token lifetime with sliding expiration support

### OAuth 2.0 Integration

The Federated Graph API integrates with OAuth 2.0 for client application authorization:

- **Grant Types**: Authorization Code, Client Credentials, Implicit (legacy)
- **Scopes**: Mapped to GraphQL resources and operations
- **Token Exchange**: Support for token exchange for service-to-service communication
- **Token Introspection**: Real-time token validation through introspection endpoint

### Client Authentication

For machine-to-machine integrations, the Federated Graph API supports:

- **API Keys**: For simple integrations and development
- **Client Certificates**: For secure service-to-service communication
- **mTLS**: For high-security environments and regulated contexts

### Session-Based Authentication

For web-based applications, the Federated Graph API supports:

- **Cookie-Based Sessions**: Secure, HTTP-only cookies for web applications
- **CSRF Protection**: Protections against cross-site request forgery
- **Session Validation**: Real-time session validation against identity provider

## Example Policy (YAML)

```yaml
# Apollo Router Authorization Configuration
authorization:
  require_authentication: true
  
  # JWT claims mapping
  jwt:
    claims_map:
      - name: "roles"
        location: "https://covermymeds.com/roles"
      - name: "permissions"
        location: "https://covermymeds.com/permissions"
      - name: "sub"
        location: "sub"
      - name: "organizationId"
        location: "https://covermymeds.com/organizationId"
  
  # Schema directives
  directives:
    enabled: true
    requires:
      roles: 
        # Schema element to role mapping
        types:
          Patient:
            __default: "Patient.Reader"
            appointments: "Appointment.Reader"
            medications: "Medication.Reader"
            clinicalNotes: "Clinical.Reader"
          Medication:
            __default: "Medication.Reader"
          Appointment:
            __default: "Appointment.Reader"
            create: "Appointment.Writer"
            cancel: "Appointment.Writer"
            reschedule: "Appointment.Writer"
          PriorAuthorization:
            __default: "PA.Reader"
            submit: "PA.Writer"
            update: "PA.Writer"
      
      # Field-level permission requirements
      permissions:
        types:
          Patient:
            __default: "patient:read"
            update: "patient:write"
            create: "patient:write"
            delete: "patient:admin"
          Medication:
            __default: "medication:read"
            prescribe: "medication:write"
          Appointment:
            __default: "appointment:read"
            schedule: "appointment:write"
            cancel: "appointment:write"
            reschedule: "appointment:write"
          PriorAuthorization:
            __default: "pa:read"
            submit: "pa:write"
            cancel: "pa:write"

# Custom Coprocessor for Complex Authorization
coprocessor:
  url: "http://auth-service.internal:4001/authorize"
  timeout: 5s
  router:
    request:
      headers: true
      body: false
    response:
      headers: true
      body: false
```

Example of a subgraph-specific policy:

```yaml
# Patient Subgraph Authorization Policy
apiVersion: graphql.covermymeds.com/v1
kind: GraphQLAuthPolicy
metadata:
  name: patient-subgraph-auth
  namespace: federated-graph
spec:
  subgraphName: patient-subgraph
  rules:
    - operations: ["Query.patients", "Query.patientById", "Query.searchPatients"]
      requiredPermissions: ["patient:read"]
    - operations: ["Mutation.createPatient", "Mutation.updatePatient"]
      requiredPermissions: ["patient:write"]
    - operations: ["Mutation.mergePatients", "Mutation.deletePatient"]
      requiredPermissions: ["patient:admin"]
    - operations: ["Patient.insuranceCoverage", "Patient.financialInfo"]
      requiredPermissions: ["patient:financial:read"]
    - operations: ["Patient.appointments"]
      requiredPermissions: ["appointment:read"]
    - operations: ["Patient.medications"]
      requiredPermissions: ["medication:read"]
    - operations: ["Patient.clinicalNotes"]
      requiredPermissions: ["clinical:notes:read"]
  fieldRedaction:
    - field: "Patient.socialSecurityNumber"
      requiredPermissions: ["patient:sensitive:read"]
      fallback: "REDACTED"
    - field: "Patient.address"
      requiredPermissions: ["patient:demographics:read"]
      fallback: null
    - field: "Patient.phoneNumber"
      requiredPermissions: ["patient:contact:read"]
      fallback: null
  organizationBoundaries:
    - fields: ["Patient"]
      organizationField: "managingOrganization.id"
```

## Related Resources
- [Federated Graph API Audit Compliance](./audit-compliance.md)
- [Federated Graph API Data Governance](./data-governance.md)
- [Apollo Router Authorization Documentation](https://www.apollographql.com/docs/router/configuration/authorization)