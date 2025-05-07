# FHIR Interoperability Platform Access Controls

## Introduction
This document describes the access control model implemented in the FHIR Interoperability Platform. The platform provides a comprehensive, role-based access control (RBAC) system integrated with attribute-based access control (ABAC) capabilities to secure healthcare data according to regulatory requirements and organizational policies. The access control system ensures that users have appropriate access to FHIR resources based on their roles, the sensitivity of the data, patient consent, and the context of the access request.

## Role-Based Access Control (RBAC)

The FHIR Interoperability Platform implements a hierarchical role-based access control model that defines what operations users can perform on which resources.

### User Roles

| Role | Description | Primary Responsibilities |
|------|-------------|--------------------------|
| **System Administrator** | Technical administrators with full system access | System configuration, user management, backup/restore operations |
| **Security Administrator** | Administrators focused on security controls | Identity management, access reviews, security monitoring |
| **Clinician** | Healthcare providers with full clinical data access | Patient care, clinical documentation, medication orders |
| **Nurse** | Nursing staff with patient care responsibilities | Vital signs recording, medication administration, care coordination |
| **Pharmacist** | Pharmacy staff responsible for medication management | Medication dispensing, drug interaction checks, medication history review |
| **Care Coordinator** | Staff coordinating patient care across providers | Care plan management, referral coordination, appointment scheduling |
| **Medical Records Staff** | Staff managing patient records | Record management, documentation, data quality |
| **Front Desk** | Administrative staff handling patient intake | Registration, scheduling, demographic updates |
| **Billing/Coding** | Staff handling billing and insurance claims | Claims processing, coding, coverage verification |
| **Researcher** | Staff conducting research on de-identified data | Population health analysis, clinical research, quality improvement |
| **Auditor** | Staff reviewing system and data access | Access review, compliance monitoring, incident investigation |
| **Patient** | Individuals accessing their own health records | View personal records, manage consent, communicate with providers |
| **Application** | System-to-system integrations | Automated workflows, data exchange, notifications |

### Permission Matrix

The following table outlines the permissions assigned to each role for different FHIR resource types:

| Resource Type | System Admin | Clinician | Nurse | Pharmacist | Care Coordinator | Medical Records | Front Desk | Billing | Researcher | Patient |
|---------------|--------------|-----------|-------|------------|------------------|----------------|------------|---------|------------|---------|
| Patient | CRUD | R | R | R | R | CRUD | CRUD | R | R* | R* |
| Practitioner | CRUD | R | R | R | R | R | R | R | R* | - |
| Organization | CRUD | R | R | R | R | R | R | R | R* | - |
| Location | CRUD | R | R | R | R | R | R | R | R* | - |
| Encounter | CRUD | CRUD | R | R | CRUD | CRUD | CRU | R | R* | R* |
| Condition | CRUD | CRUD | R | R | R | R | - | R | R* | R* |
| Observation | CRUD | CRUD | CRUD | R | R | R | - | R | R* | R* |
| MedicationRequest | CRUD | CRUD | R | CRUD | R | R | - | R | R* | R* |
| MedicationDispense | CRUD | R | R | CRUD | R | R | - | R | R* | R* |
| Procedure | CRUD | CRUD | R | R | R | R | - | CRUD | R* | R* |
| Immunization | CRUD | CRUD | CRUD | R | R | R | - | R | R* | R* |
| AllergyIntolerance | CRUD | CRUD | CRUD | R | R | R | - | R | R* | R* |
| CarePlan | CRUD | CRUD | R | R | CRUD | R | - | R | R* | R* |
| DiagnosticReport | CRUD | CRUD | R | R | R | R | - | R | R* | R* |
| DocumentReference | CRUD | CRUD | R | R | R | CRUD | - | R | R* | R* |
| ServiceRequest | CRUD | CRUD | R | R | CRUD | R | R | CRUD | R* | R* |
| Coverage | CRUD | R | R | R | R | R | CRUD | CRUD | - | R* |
| Claim | CRUD | - | - | - | - | - | CR | CRUD | - | R* |
| AuditEvent | R | - | - | - | - | - | - | - | - | - |
| Consent | CRUD | CR | R | R | CR | CR | R | R | - | CRUD* |

Legend:
- C: Create permissions
- R: Read permissions
- U: Update permissions
- D: Delete permissions
- R*: Read with de-identification or filtered access
- CRUD*: Full access to own records only

### Resource-Specific Permission Constraints

Beyond the basic CRUD permissions, additional constraints apply to certain resource types:

#### Sensitive Data Access Constraints

| Resource Type | Sensitivity Category | Access Requirements |
|---------------|----------------------|--------------------|
| Condition (Mental Health) | Sensitive | Requires clinical role and treating provider relationship |
| Condition (Substance Abuse) | Restricted | Requires clinical role, treating provider relationship, and patient consent |
| Condition (HIV/AIDS) | Restricted | Requires clinical role, treating provider relationship, and patient consent |
| DocumentReference (Mental Health) | Sensitive | Requires clinical role and treating provider relationship |
| DocumentReference (Substance Abuse) | Restricted | Requires clinical role, treating provider relationship, and patient consent |
| DocumentReference (HIV/AIDS) | Restricted | Requires clinical role, treating provider relationship, and patient consent |
| MedicationRequest (Controlled Substances) | Sensitive | Requires prescriber credentials and appropriate DEA authorization |

## Policy Enforcement

The FHIR Interoperability Platform enforces access control policies at multiple levels:

### Authentication Layer

- **OAuth 2.0/OpenID Connect**: Standard-based authentication for users and applications
- **SMART on FHIR**: Healthcare-specific authentication profiles for EHR-launched applications
- **Mutual TLS**: Certificate-based authentication for system-to-system integrations
- **JWT Validation**: Token validation with signature verification and claims validation

### Authorization Layer

Authorization decisions are made using a policy engine that evaluates multiple factors:

1. **User Identity**: Authenticated user or service account
2. **Role Assignments**: Roles assigned to the user
3. **Resource Type**: Type of FHIR resource being accessed
4. **Operation**: Action being performed (create, read, update, delete, search)
5. **Resource Content**: Content of the resource being accessed (for data categorization)
6. **Patient Context**: Relationship between user and patient
7. **Purpose of Use**: Declared purpose for the access request
8. **Consent Directives**: Patient consent records affecting data sharing

### Enforcement Mechanisms

| Mechanism | Description | Implementation |
|-----------|-------------|----------------|
| **Pre-Request Filtering** | Prevents unauthorized requests based on user role and resource type | Request interceptor at API gateway |
| **Search Parameter Restrictions** | Limits which search parameters can be used by different roles | Parameter validation in search handler |
| **Result Filtering** | Filters search results to include only authorized resources | Post-processing of search results |
| **Field-Level Filtering** | Redacts or masks sensitive fields based on user role | Resource transformation during response generation |
| **Content-Based Filtering** | Filters resources based on content tags (e.g., sensitivity) | Metadata evaluation during authorization |
| **Compartment Enforcement** | Restricts access to resources within a patient compartment | Patient reference validation |
| **Consent Enforcement** | Enforces patient consent directives for data sharing | Consent evaluation against access requests |

## Authentication Integration

The FHIR Interoperability Platform supports multiple authentication mechanisms to integrate with the organizational identity infrastructure:

### Supported Authentication Methods

1. **Username/Password**: Basic authentication for direct user access
2. **OAuth 2.0/OpenID Connect**: Token-based authentication using organizational identity providers
3. **SAML**: Security Assertion Markup Language integration for enterprise SSO
4. **Client Certificates**: Certificate-based authentication for system integrations
5. **API Keys**: Simple authentication for internal services and development
6. **JWT Bearer Tokens**: JSON Web Token authentication for cross-service communication

### Identity Provider Integration

The platform integrates with the following identity providers:

- **Active Directory/LDAP**: Enterprise directory integration
- **Azure AD/Microsoft Entra ID**: Cloud identity provider
- **Okta**: Identity as a service platform
- **Auth0**: Authentication and authorization service
- **Custom IdPs**: Support for custom identity providers through standard protocols

### Implementation Example

```yaml
# Authentication Configuration
authentication:
  providers:
    - type: oauth2
      name: enterprise-idp
      issuerUrl: https://auth.covermymeds.com
      clientId: fhir-platform-client
      clientSecret: ${OAUTH_CLIENT_SECRET}
      scopes:
        - openid
        - profile
        - fhir-api
      userInfoMapping:
        id: sub
        name: name
        email: email
        roles: groups
    
    - type: smart-on-fhir
      name: smart-apps
      issuerUrl: https://fhir-api.covermymeds.com
      audience: https://fhir-api.covermymeds.com/fhir/r4
      tokenLifetime: 3600
      refreshTokenLifetime: 86400
      
    - type: service-account
      name: system-services
      issuerUrl: https://auth.covermymeds.com
      audience: https://fhir-api.covermymeds.com
      keyStore: /config/keys/service-accounts
      requiredClaims:
        - iss
        - sub
        - aud
        - exp
      
  session:
    cookieSecure: true
    cookieHttpOnly: true
    cookieSameSite: strict
    sessionTimeout: 3600
    
  jwt:
    signingAlgorithm: RS256
    publicKeys: /config/keys/auth-public-keys.jwks
    
  mfa:
    enabled: true
    requiredFor:
      - system-admin
      - security-admin
    exemptIpRanges:
      - 10.0.0.0/8
```

## Example Policy (YAML)

```yaml
# Access Policy Configuration
policies:
  # Default policy for all users
  - name: default
    description: Default permissions applied to all authenticated users
    effect: deny
    resources:
      - "Patient/**"
      - "Encounter/**"
      - "Observation/**"
      - "Condition/**"
      - "MedicationRequest/**"
      
  # System administrator policy
  - name: system-admin
    description: Full system access for administrators
    effect: allow
    subjects:
      - "role:system-admin"
    resources:
      - "**"
    actions:
      - "create"
      - "read"
      - "update"
      - "delete"
      - "search"
      
  # Clinician policy
  - name: clinician
    description: Clinical data access for healthcare providers
    effect: allow
    subjects:
      - "role:clinician"
    resources:
      - "Patient/**"
      - "Encounter/**"
      - "Observation/**"
      - "Condition/**"
      - "MedicationRequest/**"
      - "AllergyIntolerance/**"
      - "Procedure/**"
      - "Immunization/**"
      - "CarePlan/**"
      - "Goal/**"
      - "DiagnosticReport/**"
      - "DocumentReference/**"
    actions:
      - "read"
      - "search"
    conditions:
      - "{{$resource.meta.security.code}} != 'restricted' || patientConsent()"
      
  # Clinician create/update policy
  - name: clinician-write
    description: Write access for clinicians
    effect: allow
    subjects:
      - "role:clinician"
    resources:
      - "Encounter/**"
      - "Observation/**"
      - "Condition/**"
      - "MedicationRequest/**"
      - "AllergyIntolerance/**"
      - "Procedure/**"
      - "Immunization/**"
      - "CarePlan/**"
      - "Goal/**"
      - "DiagnosticReport/**"
      - "DocumentReference/**"
    actions:
      - "create"
      - "update"
    conditions:
      - "careRelationship() || emergencyAccess()"
      
  # Nurse policy
  - name: nurse
    description: Clinical data access for nursing staff
    effect: allow
    subjects:
      - "role:nurse"
    resources:
      - "Patient/**"
      - "Encounter/**"
      - "Observation/**"
      - "Condition/**"
      - "MedicationRequest/**"
      - "AllergyIntolerance/**"
      - "Immunization/**"
    actions:
      - "read"
      - "search"
    conditions:
      - "{{$resource.meta.security.code}} != 'restricted' || patientConsent()"
      
  # Pharmacist policy
  - name: pharmacist
    description: Medication-related access for pharmacy staff
    effect: allow
    subjects:
      - "role:pharmacist"
    resources:
      - "Patient/**"
      - "MedicationRequest/**"
      - "MedicationDispense/**"
      - "MedicationStatement/**"
      - "MedicationAdministration/**"
      - "AllergyIntolerance/**"
    actions:
      - "read"
      - "search"
      
  # Patient access policy
  - name: patient
    description: Patient access to their own records
    effect: allow
    subjects:
      - "role:patient"
    resources:
      - "Patient/{{user.patientId}}"
      - "Encounter/**"
      - "Observation/**"
      - "Condition/**"
      - "MedicationRequest/**"
      - "AllergyIntolerance/**"
      - "Procedure/**"
      - "Immunization/**"
      - "CarePlan/**"
    actions:
      - "read"
      - "search"
    conditions:
      - "{{$resource.subject.reference}} == 'Patient/{{user.patientId}}'"
      - "{{$resource.meta.security.code}} != 'restricted'"
      
  # Researcher policy
  - name: researcher
    description: De-identified data access for researchers
    effect: allow
    subjects:
      - "role:researcher"
    resources:
      - "Patient/**"
      - "Encounter/**"
      - "Observation/**"
      - "Condition/**"
      - "Procedure/**"
      - "Immunization/**"
    actions:
      - "read"
      - "search"
    transformations:
      - type: "deidentify"
        config:
          removeIdentifiers: true
          generalizeZip: true
          generalizeDates: "month"
          removeNarratives: true
```

## Break Glass Mechanism

The FHIR Interoperability Platform includes a "break glass" mechanism for emergency access to patient data when normal access controls would prevent access but clinical necessity requires it:

```json
{
  "breakGlass": {
    "enabled": true,
    "requireReason": true,
    "allowedRoles": ["clinician", "nurse", "pharmacist"],
    "logging": {
      "level": "critical",
      "alertNotification": true,
      "reviewRequired": true
    },
    "timeLimit": 4,
    "timeUnit": "hours",
    "emergencyAccessCode": {
      "enabled": true,
      "codeExpiry": 5,
      "codeExpiryUnit": "minutes",
      "codeLength": 8
    }
  }
}
```

### Break Glass Workflow

1. Clinician attempts to access restricted patient data
2. Access control system blocks access
3. Clinician invokes break glass procedure
4. System prompts for emergency access reason
5. Clinician enters reason and emergency access code (if required)
6. System grants temporary access with time limitation
7. All access is logged with special emergency designation
8. Security team receives real-time notification
9. Access is reviewed during regular audit cycle

## Related Resources
- [FHIR Interoperability Platform Audit Compliance](./audit-compliance.md)
- [FHIR Interoperability Platform Data Governance](./data-governance.md)
- [FHIR Interoperability Platform Core APIs](../02-core-functionality/core-apis.md)
- [FHIR Security and Privacy Module](https://hl7.org/fhir/security.html)
- [SMART App Launch Implementation Guide](http://hl7.org/fhir/smart-app-launch/)