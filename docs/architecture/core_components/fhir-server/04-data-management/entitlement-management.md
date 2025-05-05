# Entitlement Management

## Introduction

Entitlement management in FHIR systems controls who can access what data and under what circumstances. It combines authentication, authorization, and access control to ensure that sensitive healthcare information is only accessible to authorized users with legitimate needs. This guide explains how to implement robust entitlement management in your FHIR server implementation, covering role-based access control, patient-centered data access, and regulatory considerations.

### Quick Start

1. Define roles and permissions aligned with your organization's security requirements
2. Implement role-based access control using FHIR Consent and security tags
3. Configure patient-centered data access to respect patient privacy preferences
4. Implement attribute-based access control for fine-grained permissions
5. Establish audit mechanisms to track access and authorization decisions

### Related Components

- [FHIR Client Authentication](fhir-client-authentication.md): Configure secure access to your FHIR server
- [Data Tagging in FHIR](data-tagging-in-fhir.md): Learn about resource tagging for security
- [Patient Mastering Guide](fhir-patient-mastering.md) (Coming Soon): Manage patient identity and consent
- [Security Architecture Decisions](fhir-security-decisions.md) (Coming Soon): Understand security implementation choices

## Creating and Managing Entitlements

Entitlements define what actions users can perform on which resources. In FHIR, entitlements can be implemented using a combination of standard resources and extensions.

### Defining Entitlement Models

```typescript
import { AidboxClient } from '@aidbox/sdk-r4';
import { Consent } from '@aidbox/sdk-r4/types';

const client = new AidboxClient({
  baseUrl: 'http://localhost:8888',
  auth: {
    type: 'basic',
    username: 'root',
    password: 'secret'
  }
});

/**
 * Creates a Consent resource to define entitlements
 * @param patientId The patient whose data is being protected
 * @param practitionerId The practitioner receiving access
 * @param resourceTypes The resource types covered by this consent
 * @param action The allowed actions (read, write, etc.)
 * @returns The created Consent resource
 */
async function createEntitlementConsent(
  patientId: string,
  practitionerId: string,
  resourceTypes: string[],
  action: 'read' | 'write' | 'both'
): Promise<Consent> {
  try {
    const consent: Partial<Consent> = {
      resourceType: 'Consent',
      status: 'active',
      scope: {
        coding: [{
          system: 'http://terminology.hl7.org/CodeSystem/consentscope',
          code: 'patient-privacy',
          display: 'Privacy Consent'
        }]
      },
      category: [{
        coding: [{
          system: 'http://terminology.hl7.org/CodeSystem/consentcategorycodes',
          code: 'patientconsent',
          display: 'Patient Consent'
        }]
      }],
      patient: {
        reference: `Patient/${patientId}`
      },
      dateTime: new Date().toISOString(),
      performer: [{
        reference: `Practitioner/${practitionerId}`
      }],
      organization: [{
        reference: 'Organization/example-org'
      }],
      policyRule: {
        coding: [{
          system: 'http://terminology.hl7.org/CodeSystem/v3-ActCode',
          code: 'OPTIN',
          display: 'Opt-in'
        }]
      },
      provision: {
        type: 'permit',
        actor: [{
          role: {
            coding: [{
              system: 'http://terminology.hl7.org/CodeSystem/v3-RoleCode',
              code: 'PROV',
              display: 'healthcare provider'
            }]
          },
          reference: {
            reference: `Practitioner/${practitionerId}`
          }
        }],
        action: action === 'both' ? [
          {
            coding: [{
              system: 'http://terminology.hl7.org/CodeSystem/consentaction',
              code: 'access',
              display: 'Access'
            }]
          },
          {
            coding: [{
              system: 'http://terminology.hl7.org/CodeSystem/consentaction',
              code: 'correct',
              display: 'Correct'
            }]
          }
        ] : [
          {
            coding: [{
              system: 'http://terminology.hl7.org/CodeSystem/consentaction',
              code: action === 'read' ? 'access' : 'correct',
              display: action === 'read' ? 'Access' : 'Correct'
            }]
          }
        ],
        data: resourceTypes.map(resourceType => ({
          meaning: 'instance',
          reference: {
            reference: `${resourceType}?patient=${patientId}`
          }
        }))
      }
    };
    
    const result = await client.create<Consent>(consent);
    console.log(`Entitlement consent created with ID: ${result.id}`);
    return result;
  } catch (error) {
    console.error('Error creating entitlement consent:', error);
    throw error;
  }
}
```

### Managing Entitlements Programmatically

```typescript
/**
 * Updates an existing entitlement consent
 * @param consentId The ID of the consent to update
 * @param status The new status (active, inactive, etc.)
 * @param resourceTypes The resource types covered by this consent
 * @returns The updated Consent resource
 */
async function updateEntitlementConsent(
  consentId: string,
  status: 'active' | 'inactive' | 'entered-in-error',
  resourceTypes?: string[]
): Promise<Consent> {
  try {
    // First, retrieve the current consent
    const consent = await client.read<Consent>({
      resourceType: 'Consent',
      id: consentId
    });
    
    // Update the status
    consent.status = status;
    
    // Update resource types if provided
    if (resourceTypes && consent.provision) {
      consent.provision.data = resourceTypes.map(resourceType => ({
        meaning: 'instance',
        reference: {
          reference: `${resourceType}?patient=${consent.patient.reference.split('/')[1]}`
        }
      }));
    }
    
    // Save the updated consent
    const result = await client.update<Consent>(consent);
    console.log(`Entitlement consent ${consentId} updated to ${status}`);
    return result;
  } catch (error) {
    console.error(`Error updating entitlement consent ${consentId}:`, error);
    throw error;
  }
}

/**
 * Retrieves all entitlements for a specific patient
 * @param patientId The ID of the patient
 * @returns Array of Consent resources
 */
async function getPatientEntitlements(patientId: string): Promise<Consent[]> {
  try {
    const bundle = await client.search<Consent>({
      resourceType: 'Consent',
      params: {
        patient: patientId,
        status: 'active',
        _sort: '-date'
      }
    });
    
    return bundle.entry?.map(entry => entry.resource as Consent) || [];
  } catch (error) {
    console.error(`Error retrieving entitlements for patient ${patientId}:`, error);
    throw error;
  }
}

/**
 * Retrieves all entitlements granted to a specific practitioner
 * @param practitionerId The ID of the practitioner
 * @returns Array of Consent resources
 */
async function getPractitionerEntitlements(practitionerId: string): Promise<Consent[]> {
  try {
    const bundle = await client.search<Consent>({
      resourceType: 'Consent',
      params: {
        'actor:reference': `Practitioner/${practitionerId}`,
        status: 'active',
        _sort: '-date'
      }
    });
    
    return bundle.entry?.map(entry => entry.resource as Consent) || [];
  } catch (error) {
    console.error(`Error retrieving entitlements for practitioner ${practitionerId}:`, error);
    throw error;
  }
}
```

## Role-Based Access Control

Role-Based Access Control (RBAC) assigns permissions to roles, which are then assigned to users. This simplifies access management in large organizations.

### Implementing RBAC with FHIR

```typescript
/**
 * Defines a role with specific permissions
 * @param roleName The name of the role
 * @param permissions The permissions granted by this role
 * @returns The created role
 */
async function defineRole(
  roleName: string,
  permissions: Array<{
    resourceType: string;
    actions: Array<'read' | 'write' | 'delete'>;
  }>
): Promise<any> {
  try {
    // Create a custom resource for roles
    const role = {
      resourceType: 'Role', // Custom resource type
      name: roleName,
      permissions: permissions,
      meta: {
        profile: ['http://example.org/fhir/StructureDefinition/role']
      }
    };
    
    const result = await client.request({
      method: 'POST',
      url: '/Role',
      data: role
    });
    
    console.log(`Role ${roleName} created`);
    return result.data;
  } catch (error) {
    console.error(`Error creating role ${roleName}:`, error);
    throw error;
  }
}

/**
 * Assigns a role to a user
 * @param userId The ID of the user
 * @param roleId The ID of the role
 * @returns The created role assignment
 */
async function assignRoleToUser(
  userId: string,
  roleId: string
): Promise<any> {
  try {
    // Create a custom resource for role assignments
    const roleAssignment = {
      resourceType: 'RoleAssignment', // Custom resource type
      user: {
        reference: `Practitioner/${userId}`
      },
      role: {
        reference: `Role/${roleId}`
      },
      meta: {
        profile: ['http://example.org/fhir/StructureDefinition/role-assignment']
      }
    };
    
    const result = await client.request({
      method: 'POST',
      url: '/RoleAssignment',
      data: roleAssignment
    });
    
    console.log(`Role ${roleId} assigned to user ${userId}`);
    return result.data;
  } catch (error) {
    console.error(`Error assigning role ${roleId} to user ${userId}:`, error);
    throw error;
  }
}

/**
 * Checks if a user has permission to perform an action on a resource type
 * @param userId The ID of the user
 * @param resourceType The type of resource
 * @param action The action to check
 * @returns Whether the user has permission
 */
async function checkUserPermission(
  userId: string,
  resourceType: string,
  action: 'read' | 'write' | 'delete'
): Promise<boolean> {
  try {
    // Get all role assignments for the user
    const roleAssignments = await client.request({
      method: 'GET',
      url: `/RoleAssignment?user=Practitioner/${userId}`
    });
    
    // No assignments means no permissions
    if (!roleAssignments.data.entry || roleAssignments.data.entry.length === 0) {
      return false;
    }
    
    // Get all roles assigned to the user
    const roleIds = roleAssignments.data.entry.map(
      (entry: any) => entry.resource.role.reference.split('/')[1]
    );
    
    // Check each role for the required permission
    for (const roleId of roleIds) {
      const role = await client.request({
        method: 'GET',
        url: `/Role/${roleId}`
      });
      
      const hasPermission = role.data.permissions.some(
        (permission: any) => (
          permission.resourceType === resourceType &&
          permission.actions.includes(action)
        )
      );
      
      if (hasPermission) {
        return true;
      }
    }
    
    return false;
  } catch (error) {
    console.error(`Error checking permission for user ${userId}:`, error);
    throw error;
  }
}
```

### Common RBAC Roles in Healthcare

| Role | Description | Typical Permissions |
|------|-------------|---------------------|
| Physician | Primary care provider | Read/write access to all patient data |
| Nurse | Clinical support staff | Read access to all patient data, write access to observations |
| Pharmacist | Medication management | Read/write access to medications and allergies |
| Administrator | System administrator | Read/write access to non-clinical data |
| Patient | Self-service access | Read access to own data only |

## Patient-Centered Data Access

Patient-centered data access ensures that patients have control over who can access their health information.

### Implementing Patient Consent

```typescript
/**
 * Creates a patient consent directive
 * @param patientId The ID of the patient
 * @param allowedPractitioners Practitioners allowed to access data
 * @param deniedPractitioners Practitioners denied access to data
 * @param purpose The purpose for which access is granted
 * @returns The created Consent resource
 */
async function createPatientConsent(
  patientId: string,
  allowedPractitioners: string[],
  deniedPractitioners: string[] = [],
  purpose: 'TREAT' | 'ETREAT' | 'HRESCH' | 'PATRQT' = 'TREAT'
): Promise<Consent> {
  try {
    const consent: Partial<Consent> = {
      resourceType: 'Consent',
      status: 'active',
      scope: {
        coding: [{
          system: 'http://terminology.hl7.org/CodeSystem/consentscope',
          code: 'patient-privacy',
          display: 'Privacy Consent'
        }]
      },
      category: [{
        coding: [{
          system: 'http://terminology.hl7.org/CodeSystem/consentcategorycodes',
          code: 'patientconsent',
          display: 'Patient Consent'
        }]
      }],
      patient: {
        reference: `Patient/${patientId}`
      },
      dateTime: new Date().toISOString(),
      performer: [{
        reference: `Patient/${patientId}`
      }],
      policyRule: {
        coding: [{
          system: 'http://terminology.hl7.org/CodeSystem/v3-ActCode',
          code: 'OPTIN',
          display: 'Opt-in'
        }]
      },
      provision: {
        type: 'permit',
        purpose: [{
          system: 'http://terminology.hl7.org/CodeSystem/v3-ActReason',
          code: purpose,
          display: getPurposeDisplay(purpose)
        }],
        actor: allowedPractitioners.map(practitionerId => ({
          role: {
            coding: [{
              system: 'http://terminology.hl7.org/CodeSystem/v3-RoleCode',
              code: 'PROV',
              display: 'healthcare provider'
            }]
          },
          reference: {
            reference: `Practitioner/${practitionerId}`
          }
        })),
        action: [{
          coding: [{
            system: 'http://terminology.hl7.org/CodeSystem/consentaction',
            code: 'access',
            display: 'Access'
          }]
        }]
      }
    };
    
    // Add exception for denied practitioners if any
    if (deniedPractitioners.length > 0) {
      consent.provision = {
        ...consent.provision,
        provision: [{
          type: 'deny',
          actor: deniedPractitioners.map(practitionerId => ({
            role: {
              coding: [{
                system: 'http://terminology.hl7.org/CodeSystem/v3-RoleCode',
                code: 'PROV',
                display: 'healthcare provider'
              }]
            },
            reference: {
              reference: `Practitioner/${practitionerId}`
            }
          }))
        }]
      };
    }
    
    const result = await client.create<Consent>(consent);
    console.log(`Patient consent created with ID: ${result.id}`);
    return result;
  } catch (error) {
    console.error('Error creating patient consent:', error);
    throw error;
  }
}

/**
 * Helper function to get the display text for a purpose code
 */
function getPurposeDisplay(purpose: 'TREAT' | 'ETREAT' | 'HRESCH' | 'PATRQT'): string {
  switch (purpose) {
    case 'TREAT':
      return 'Treatment';
    case 'ETREAT':
      return 'Emergency Treatment';
    case 'HRESCH':
      return 'Healthcare Research';
    case 'PATRQT':
      return 'Patient Requested';
    default:
      return 'Unknown';
  }
}
```

### Checking Patient Consent

```typescript
/**
 * Checks if a practitioner has consent to access a patient's data
 * @param practitionerId The ID of the practitioner
 * @param patientId The ID of the patient
 * @param purpose The purpose for which access is requested
 * @returns Whether consent exists
 */
async function checkPatientConsent(
  practitionerId: string,
  patientId: string,
  purpose: 'TREAT' | 'ETREAT' | 'HRESCH' | 'PATRQT' = 'TREAT'
): Promise<boolean> {
  try {
    // Get active consents for this patient
    const bundle = await client.search<Consent>({
      resourceType: 'Consent',
      params: {
        patient: patientId,
        status: 'active',
        'provision-actor': `Practitioner/${practitionerId}`,
        'provision-type': 'permit'
      }
    });
    
    // No consents means no access
    if (!bundle.entry || bundle.entry.length === 0) {
      return false;
    }
    
    // Check each consent for the required purpose
    for (const entry of bundle.entry) {
      const consent = entry.resource as Consent;
      
      // Check if this consent is for the requested purpose
      const hasPurpose = consent.provision?.purpose?.some(
        p => p.coding?.some(c => c.code === purpose)
      );
      
      if (hasPurpose) {
        // Check if there's a specific denial for this practitioner
        const isDenied = consent.provision?.provision?.some(
          p => p.type === 'deny' && p.actor?.some(
            a => a.reference?.reference === `Practitioner/${practitionerId}`
          )
        );
        
        if (!isDenied) {
          return true;
        }
      }
    }
    
    return false;
  } catch (error) {
    console.error(`Error checking consent for practitioner ${practitionerId} and patient ${patientId}:`, error);
    throw error;
  }
}
```

## Regulatory and Contractual Considerations

Healthcare data is subject to various regulations and contractual obligations that affect entitlement management.

### Implementing HIPAA Compliance

```typescript
/**
 * Creates a HIPAA-compliant access control policy
 * @param organizationId The ID of the covered entity
 * @param minimalNecessary Whether to enforce minimal necessary access
 * @param breakGlassEnabled Whether to allow break-glass access
 * @returns The created policy
 */
async function createHIPAAPolicy(
  organizationId: string,
  minimalNecessary: boolean = true,
  breakGlassEnabled: boolean = true
): Promise<any> {
  try {
    // Create a custom resource for HIPAA policies
    const policy = {
      resourceType: 'SecurityPolicy', // Custom resource type
      organization: {
        reference: `Organization/${organizationId}`
      },
      type: 'HIPAA',
      settings: {
        minimalNecessary,
        breakGlassEnabled,
        auditEnabled: true, // Always enable auditing for HIPAA
        retentionPeriodDays: 365 * 6 // 6 years retention
      },
      meta: {
        profile: ['http://example.org/fhir/StructureDefinition/hipaa-policy']
      }
    };
    
    const result = await client.request({
      method: 'POST',
      url: '/SecurityPolicy',
      data: policy
    });
    
    console.log(`HIPAA policy created for organization ${organizationId}`);
    return result.data;
  } catch (error) {
    console.error(`Error creating HIPAA policy for organization ${organizationId}:`, error);
    throw error;
  }
}

/**
 * Implements break-glass access for emergency situations
 * @param practitionerId The ID of the practitioner requesting access
 * @param patientId The ID of the patient
 * @param reason The reason for break-glass access
 * @returns The created emergency access record
 */
async function createBreakGlassAccess(
  practitionerId: string,
  patientId: string,
  reason: string
): Promise<any> {
  try {
    // Create a custom resource for break-glass access
    const breakGlass = {
      resourceType: 'EmergencyAccess', // Custom resource type
      practitioner: {
        reference: `Practitioner/${practitionerId}`
      },
      patient: {
        reference: `Patient/${patientId}`
      },
      reason,
      accessStart: new Date().toISOString(),
      accessEnd: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(), // 24 hours
      status: 'active',
      meta: {
        profile: ['http://example.org/fhir/StructureDefinition/emergency-access']
      }
    };
    
    const result = await client.request({
      method: 'POST',
      url: '/EmergencyAccess',
      data: breakGlass
    });
    
    // Create an audit event for this break-glass access
    await client.create({
      resourceType: 'AuditEvent',
      type: {
        system: 'http://terminology.hl7.org/CodeSystem/audit-event-type',
        code: 'emergency-override',
        display: 'Emergency Override'
      },
      action: 'E',
      recorded: new Date().toISOString(),
      outcome: '0',
      agent: [{
        type: {
          coding: [{
            system: 'http://terminology.hl7.org/CodeSystem/v3-RoleClass',
            code: 'AGNT',
            display: 'Agent'
          }]
        },
        who: {
          reference: `Practitioner/${practitionerId}`
        },
        requestor: true
      }],
      source: {
        observer: {
          display: 'FHIR Server'
        }
      },
      entity: [{
        what: {
          reference: `Patient/${patientId}`
        },
        type: {
          system: 'http://terminology.hl7.org/CodeSystem/audit-entity-type',
          code: '1',
          display: 'Person'
        },
        role: {
          system: 'http://terminology.hl7.org/CodeSystem/object-role',
          code: '1',
          display: 'Patient'
        }
      }]
    });
    
    console.log(`Break-glass access created for practitioner ${practitionerId} and patient ${patientId}`);
    return result.data;
  } catch (error) {
    console.error(`Error creating break-glass access:`, error);
    throw error;
  }
}
```

## Conclusion

Effective entitlement management is essential for securing healthcare data while ensuring appropriate access for patient care. By implementing role-based access control, patient-centered data access, and regulatory compliance mechanisms, you can create a robust security framework for your FHIR implementation.

Key takeaways:

1. Use FHIR Consent resources to define and manage entitlements
2. Implement role-based access control to simplify permission management
3. Enable patient-centered data access through patient consent directives
4. Address regulatory requirements like HIPAA through appropriate policies
5. Implement break-glass access for emergency situations

By following these guidelines, you can ensure that your FHIR implementation provides the necessary security controls to protect sensitive healthcare information while enabling appropriate access for patient care.
