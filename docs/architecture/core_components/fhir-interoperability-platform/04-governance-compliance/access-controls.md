# Access Control and Security Policies

## Introduction

This document outlines the access control mechanisms and security policies for the FHIR Interoperability Platform component of the CMM Technology Platform. As a platform handling sensitive healthcare data, robust access controls and security measures are essential to ensure data protection, regulatory compliance, and appropriate data access.

## Access Control Model

### SMART on FHIR Authorization

The FHIR Interoperability Platform implements the SMART on FHIR authorization framework, which extends OAuth 2.0 for healthcare-specific use cases:

1. **SMART Scopes**:
   - Resource-based scopes (e.g., `patient/Patient.read`, `user/Observation.write`)
   - Context-based scopes (e.g., `launch/patient`, `launch/encounter`)
   - Granular data access scopes
   - Purpose-specific scopes

2. **Launch Context**:
   - Patient context
   - Encounter context
   - User context
   - Location context

3. **Token-Based Authorization**:
   - JWT tokens with FHIR-specific claims
   - Token validation and verification
   - Token lifetime management
   - Refresh token handling

#### Implementation Example

```typescript
// Example: SMART on FHIR authorization service
import { verify } from 'jsonwebtoken';
import { FhirClient } from '../fhir/client';

interface SmartContext {
  patientId?: string;
  encounterId?: string;
  userId?: string;
  scopes: string[];
  expiresAt: number;
  issuer: string;
  clientId: string;
  tokenType: 'access' | 'refresh';
}

class SmartAuthorizationService {
  private fhirClient: FhirClient;
  private jwksCache: Map<string, any>;
  
  constructor(fhirClient: FhirClient) {
    this.fhirClient = fhirClient;
    this.jwksCache = new Map();
  }
  
  async validateAccessToken(token: string): Promise<{
    valid: boolean;
    context?: SmartContext;
    error?: string;
  }> {
    try {
      // Decode token without verification to get issuer
      const decoded = this.decodeToken(token);
      if (!decoded || !decoded.iss) {
        return { valid: false, error: 'Invalid token format or missing issuer' };
      }
      
      // Get JWKS from issuer
      const jwks = await this.getJwks(decoded.iss);
      if (!jwks) {
        return { valid: false, error: 'Unable to retrieve JWKS from issuer' };
      }
      
      // Verify token signature and claims
      const verifiedToken = await this.verifyToken(token, jwks);
      if (!verifiedToken) {
        return { valid: false, error: 'Token verification failed' };
      }
      
      // Extract SMART context from token
      const smartContext = this.extractSmartContext(verifiedToken);
      
      // Validate token is not expired
      if (Date.now() >= smartContext.expiresAt * 1000) {
        return { valid: false, error: 'Token has expired' };
      }
      
      return { valid: true, context: smartContext };
    } catch (error) {
      return { valid: false, error: (error as Error).message };
    }
  }
  
  async authorizeAccess(
    resourceType: string,
    accessType: 'read' | 'write' | 'search',
    smartContext: SmartContext,
    resourceId?: string
  ): Promise<{
    authorized: boolean;
    reason?: string;
  }> {
    // Check if token has required scopes
    const requiredScopes = this.determineRequiredScopes(resourceType, accessType, smartContext);
    const hasRequiredScopes = this.hasRequiredScopes(smartContext.scopes, requiredScopes);
    
    if (!hasRequiredScopes) {
      return {
        authorized: false,
        reason: `Missing required scopes. Required one of: ${requiredScopes.join(', ')}`,
      };
    }
    
    // For patient-specific resources, check if within patient context
    if (this.isPatientCompartmentResource(resourceType) && smartContext.patientId) {
      // If resource ID is provided, verify it belongs to the patient context
      if (resourceId && accessType !== 'search') {
        const belongsToPatient = await this.verifyResourceBelongsToPatient(
          resourceType,
          resourceId,
          smartContext.patientId
        );
        
        if (!belongsToPatient) {
          return {
            authorized: false,
            reason: 'Resource does not belong to the authorized patient context',
          };
        }
      }
    }
    
    // Additional authorization checks based on resource type
    const additionalChecks = await this.performAdditionalAuthChecks(
      resourceType,
      accessType,
      smartContext,
      resourceId
    );
    
    if (!additionalChecks.authorized) {
      return additionalChecks;
    }
    
    return { authorized: true };
  }
  
  private determineRequiredScopes(
    resourceType: string,
    accessType: 'read' | 'write' | 'search',
    smartContext: SmartContext
  ): string[] {
    const scopes: string[] = [];
    
    // Patient-specific scopes
    if (smartContext.patientId) {
      if (accessType === 'read' || accessType === 'search') {
        scopes.push(`patient/${resourceType}.read`);
        scopes.push(`patient/*.read`);
      } else if (accessType === 'write') {
        scopes.push(`patient/${resourceType}.write`);
        scopes.push(`patient/*.write`);
      }
    }
    
    // User-level scopes
    if (accessType === 'read' || accessType === 'search') {
      scopes.push(`user/${resourceType}.read`);
      scopes.push(`user/*.read`);
    } else if (accessType === 'write') {
      scopes.push(`user/${resourceType}.write`);
      scopes.push(`user/*.write`);
    }
    
    // System-level scopes for privileged operations
    if (accessType === 'read' || accessType === 'search') {
      scopes.push(`system/${resourceType}.read`);
      scopes.push(`system/*.read`);
    } else if (accessType === 'write') {
      scopes.push(`system/${resourceType}.write`);
      scopes.push(`system/*.write`);
    }
    
    return scopes;
  }
  
  private hasRequiredScopes(grantedScopes: string[], requiredScopes: string[]): boolean {
    return requiredScopes.some(requiredScope => {
      return grantedScopes.some(grantedScope => {
        // Exact match
        if (grantedScope === requiredScope) {
          return true;
        }
        
        // Wildcard match
        if (requiredScope.includes('.') && grantedScope.endsWith('.*')) {
          const grantedPrefix = grantedScope.split('.*')[0];
          const requiredPrefix = requiredScope.split('.')[0];
          return grantedPrefix === requiredPrefix;
        }
        
        return false;
      });
    });
  }
  
  // Implementation details for other methods
  // ...
}
```

### Role-Based Access Control

In addition to SMART on FHIR, the platform implements role-based access control (RBAC) for administrative functions and internal operations:

1. **Healthcare-Specific Roles**:
   - Clinical roles (Physician, Nurse, Pharmacist)
   - Administrative roles (Health Information Manager, Billing Specialist)
   - Technical roles (System Administrator, Integration Engineer)
   - Patient/Consumer roles (Patient, Caregiver, Legal Guardian)

2. **Permission Sets**:
   - Resource-type permissions
   - Operation-type permissions
   - Administrative permissions
   - System configuration permissions

3. **Role Hierarchy**:
   - Role inheritance
   - Role composition
   - Context-specific role activation
   - Temporary role elevation

### Attribute-Based Access Control

The platform extends RBAC with attribute-based access control (ABAC) for more dynamic authorization decisions:

1. **Contextual Attributes**:
   - Patient relationship (treating provider, care team member)
   - Encounter context (active encounter, historical encounter)
   - Location context (department, facility)
   - Temporal context (work hours, emergency access)

2. **Resource Attributes**:
   - Sensitivity level
   - Data category (clinical, demographic, financial)
   - Consent status
   - Data source

3. **Policy Evaluation**:
   - Rule-based policy engine
   - Policy combination algorithms
   - Policy decision points
   - Policy enforcement points

## Authentication Mechanisms

### Multi-Factor Authentication

The FHIR Interoperability Platform supports multiple authentication factors:

1. **Knowledge Factors**:
   - Password authentication
   - Security questions
   - PIN codes

2. **Possession Factors**:
   - Mobile authenticator apps
   - Hardware security keys (FHIR/WebAuthn)
   - Smart cards
   - One-time password tokens

3. **Inherence Factors**:
   - Biometric authentication
   - Behavioral biometrics
   - Location verification

### Identity Federation

The platform supports identity federation for seamless authentication:

1. **Standards Support**:
   - OpenID Connect integration
   - SAML 2.0 support
   - OAuth 2.0 authorization
   - JWT token handling

2. **Healthcare Identity Providers**:
   - EHR system integration
   - Health Information Exchange (HIE) integration
   - Patient portal integration
   - Provider directory integration

3. **Cross-Organization Trust**:
   - Trust framework implementation
   - Identity proofing levels
   - Credential validation
   - Federation governance

## FHIR Resource Security

### Resource-Level Security

The platform implements security at the FHIR resource level:

1. **Resource Compartments**:
   - Patient compartment
   - Encounter compartment
   - Practitioner compartment
   - RelatedPerson compartment

2. **Security Labels**:
   - Confidentiality labels (R, S, V, N)
   - Sensitivity labels
   - Integrity labels
   - Handling instructions

3. **Resource-Specific Controls**:
   - Provenance tracking
   - Digital signatures
   - Version control
   - Change tracking

#### Implementation Example

```typescript
// Example: FHIR resource security service
import { Resource, Patient, Bundle } from 'fhir/r4';

interface SecurityLabel {
  system: string;
  code: string;
  display: string;
}

interface ResourceSecurityContext {
  resource: Resource;
  compartments: {
    patient?: string[];
    encounter?: string[];
    practitioner?: string[];
    relatedPerson?: string[];
  };
  securityLabels: SecurityLabel[];
  sensitivityLevel: 'normal' | 'restricted' | 'very-restricted';
  integrityStatus: 'verified' | 'unverified' | 'modified';
}

class FhirResourceSecurityService {
  async getResourceSecurityContext(resource: Resource): Promise<ResourceSecurityContext> {
    // Extract compartments
    const compartments = await this.extractCompartments(resource);
    
    // Extract security labels
    const securityLabels = this.extractSecurityLabels(resource);
    
    // Determine sensitivity level
    const sensitivityLevel = this.determineSensitivityLevel(resource, securityLabels);
    
    // Check integrity status
    const integrityStatus = await this.checkIntegrityStatus(resource);
    
    return {
      resource,
      compartments,
      securityLabels,
      sensitivityLevel,
      integrityStatus,
    };
  }
  
  async authorizeResourceAccess(
    resourceContext: ResourceSecurityContext,
    smartContext: SmartContext,
    accessType: 'read' | 'write'
  ): Promise<{
    authorized: boolean;
    reason?: string;
  }> {
    // Check compartment access
    if (!this.hasCompartmentAccess(resourceContext.compartments, smartContext)) {
      return {
        authorized: false,
        reason: 'Resource does not belong to authorized compartments',
      };
    }
    
    // Check sensitivity level access
    if (!this.hasSensitivityLevelAccess(resourceContext.sensitivityLevel, smartContext)) {
      return {
        authorized: false,
        reason: `Access to ${resourceContext.sensitivityLevel} sensitivity level not authorized`,
      };
    }
    
    // Check security label restrictions
    const labelCheck = this.checkSecurityLabelRestrictions(
      resourceContext.securityLabels,
      smartContext,
      accessType
    );
    
    if (!labelCheck.authorized) {
      return labelCheck;
    }
    
    // For write access, check integrity requirements
    if (accessType === 'write' && !this.meetsIntegrityRequirements(resourceContext, smartContext)) {
      return {
        authorized: false,
        reason: 'Does not meet integrity requirements for modification',
      };
    }
    
    return { authorized: true };
  }
  
  private async extractCompartments(resource: Resource): Promise<ResourceSecurityContext['compartments']> {
    const compartments: ResourceSecurityContext['compartments'] = {};
    
    // Extract patient compartment
    const patientIds = this.extractPatientCompartment(resource);
    if (patientIds.length > 0) {
      compartments.patient = patientIds;
    }
    
    // Extract encounter compartment
    const encounterIds = this.extractEncounterCompartment(resource);
    if (encounterIds.length > 0) {
      compartments.encounter = encounterIds;
    }
    
    // Extract practitioner compartment
    const practitionerIds = this.extractPractitionerCompartment(resource);
    if (practitionerIds.length > 0) {
      compartments.practitioner = practitionerIds;
    }
    
    // Extract relatedPerson compartment
    const relatedPersonIds = this.extractRelatedPersonCompartment(resource);
    if (relatedPersonIds.length > 0) {
      compartments.relatedPerson = relatedPersonIds;
    }
    
    return compartments;
  }
  
  // Implementation details for other methods
  // ...
}
```

### Consent Management

The platform implements FHIR Consent resources for managing patient privacy preferences:

1. **Consent Models**:
   - Opt-in consent
   - Opt-out consent
   - Granular consent
   - Purpose-specific consent

2. **Consent Enforcement**:
   - Consent evaluation at access time
   - Consent decision caching
   - Consent override procedures
   - Break-glass mechanisms

3. **Consent Lifecycle**:
   - Consent capture
   - Consent validation
   - Consent revocation
   - Consent versioning

## API Security

### Transport Security

The FHIR Interoperability Platform implements robust transport security:

1. **TLS Implementation**:
   - TLS 1.2+ requirement
   - Strong cipher suites
   - Certificate validation
   - Certificate pinning

2. **API Gateway Security**:
   - Request validation
   - Response validation
   - Rate limiting
   - DDoS protection

3. **Network Controls**:
   - Network segmentation
   - IP whitelisting
   - VPN requirements
   - Firewall rules

### API Access Controls

The platform implements multiple layers of API access controls:

1. **Authentication Controls**:
   - API key management
   - OAuth token validation
   - Certificate authentication
   - Session management

2. **Authorization Controls**:
   - Scope-based authorization
   - Resource-level permissions
   - Operation-level permissions
   - Context-based restrictions

3. **Usage Controls**:
   - Rate limiting
   - Quota management
   - Usage monitoring
   - Abnormal usage detection

## Audit and Monitoring

### Comprehensive Audit Logging

The platform implements comprehensive audit logging for all security events:

1. **Authentication Events**:
   - Login attempts
   - Logout events
   - Session management
   - Authentication failures

2. **Authorization Events**:
   - Access attempts
   - Access denials
   - Permission changes
   - Role assignments

3. **Data Access Events**:
   - Resource reads
   - Resource writes
   - Search operations
   - Bulk operations

4. **Administrative Events**:
   - Configuration changes
   - User management
   - System maintenance
   - Security policy updates

### Security Monitoring

The platform implements security monitoring capabilities:

1. **Real-time Monitoring**:
   - Anomaly detection
   - Threat detection
   - Suspicious activity alerts
   - Performance monitoring

2. **Compliance Monitoring**:
   - Policy compliance verification
   - Regulatory requirement monitoring
   - Security control effectiveness
   - Vulnerability monitoring

3. **Operational Monitoring**:
   - System health monitoring
   - Service availability
   - Error rate monitoring
   - Capacity planning

## Compliance Considerations

### HIPAA Compliance

The FHIR Interoperability Platform is designed to support HIPAA compliance:

1. **Access Controls** (u00a7164.312(a)(1)):
   - Unique user identification
   - Emergency access procedures
   - Automatic logoff
   - Encryption and decryption

2. **Audit Controls** (u00a7164.312(b)):
   - Comprehensive audit logging
   - Audit log protection
   - Audit log review procedures

3. **Integrity Controls** (u00a7164.312(c)(1)):
   - Data validation
   - Error checking
   - Digital signatures
   - Version control

4. **Transmission Security** (u00a7164.312(e)(1)):
   - Encryption of data in transit
   - Integrity checking
   - Authentication of endpoints
   - Secure transmission protocols

### 21 CFR Part 11 Compliance

The platform supports 21 CFR Part 11 requirements for electronic records and signatures:

1. **Electronic Records Controls**:
   - System validation
   - Record generation and maintenance
   - Record protection
   - Record retention and retrieval

2. **Electronic Signature Controls**:
   - Signature binding to records
   - Signature components
   - Signature verification
   - Signature non-repudiation

3. **Procedural Controls**:
   - System documentation
   - Operational checks
   - Authority checks
   - Device checks

## Implementation Guidelines

### Integration with Enterprise IAM

Guidelines for integrating with enterprise identity and access management systems:

1. **Identity Provider Integration**:
   - SAML 2.0 configuration
   - OpenID Connect setup
   - User attribute mapping
   - Group-to-role mapping

2. **Single Sign-On Implementation**:
   - SSO initiation configuration
   - Session management
   - Logout handling
   - Identity federation

3. **Role Synchronization**:
   - Enterprise role mapping
   - Automated role assignment
   - Role hierarchy alignment
   - Privilege reconciliation

### Healthcare-Specific Security Controls

Specialized security controls for healthcare environments:

1. **Break-Glass Procedures**:
   - Emergency access protocols
   - Approval workflows
   - Comprehensive audit logging
   - Post-access review

2. **Clinical Context Security**:
   - Patient context validation
   - Clinical workflow integration
   - Context-aware access decisions
   - Clinical role validation

3. **Consent Management**:
   - Patient consent directives
   - Consent enforcement
   - Consent override procedures
   - Consent audit logging

## Conclusion

The access control and security policies for the FHIR Interoperability Platform provide a comprehensive approach to securing healthcare data while ensuring appropriate access for authorized users and systems. By implementing robust authentication, authorization, and security controls, the platform enables secure interoperability while maintaining compliance with regulatory requirements.

The security practices outlined in this document should be regularly reviewed and updated to address evolving threats, regulatory changes, and organizational requirements.
