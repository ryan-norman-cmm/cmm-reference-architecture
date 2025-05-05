# Data Tagging in FHIR

## Introduction

Data tagging is a critical aspect of healthcare information management that enables tracking data ownership, source systems, and maintaining a complete audit trail. In FHIR, tags provide a flexible mechanism to associate metadata with resources, facilitating data governance, provenance tracking, and security management. This guide explains how to implement effective data tagging strategies in your FHIR implementation.

### Quick Start

1. Define a tagging strategy based on your organization's data governance requirements
2. Implement resource tagging using FHIR meta.tag, meta.security, and meta.profile elements
3. Create Provenance resources to track data origins and modifications
4. Configure tag-based access control for security enforcement
5. Implement audit logging for all resource changes

### Related Components

- [FHIR Client Authentication](fhir-client-authentication.md): Configure secure access to your FHIR server
- [Saving FHIR Resources](saving-fhir-resources.md): Learn how to create and update resources
- [Entitlement Management](fhir-entitlement-management.md) (Coming Soon): Control access to tagged resources
- [Security Architecture Decisions](fhir-security-decisions.md) (Coming Soon): Understand security implementation choices

## Tagging Data Ownership

Ownership tags identify which entity (organization, system, or user) owns or is responsible for a FHIR resource.

### Implementing Ownership Tags

```typescript
import { AidboxClient } from '@aidbox/sdk-r4';
import { Patient, Meta } from '@aidbox/sdk-r4/types';

const client = new AidboxClient({
  baseUrl: 'http://localhost:8888',
  auth: {
    type: 'basic',
    username: 'root',
    password: 'secret'
  }
});

/**
 * Creates a patient resource with ownership tags
 * @param patientData The patient data to create
 * @param owningOrganization The organization that owns this data
 * @returns The created Patient resource
 */
async function createPatientWithOwnershipTag(
  patientData: Partial<Patient>,
  owningOrganization: string
): Promise<Patient> {
  try {
    // Create meta object with ownership tag if it doesn't exist
    const meta: Meta = patientData.meta || {};
    
    // Initialize tags array if it doesn't exist
    meta.tag = meta.tag || [];
    
    // Add ownership tag
    meta.tag.push({
      system: 'http://example.org/fhir/ownership',
      code: owningOrganization,
      display: `Owned by ${owningOrganization}`
    });
    
    // Update patient data with meta
    const patientWithMeta: Partial<Patient> = {
      ...patientData,
      meta
    };
    
    // Create the patient
    const result = await client.create<Patient>(patientWithMeta);
    console.log(`Patient created with ID ${result.id} and ownership tag ${owningOrganization}`);
    return result;
  } catch (error) {
    console.error('Error creating patient with ownership tag:', error);
    throw error;
  }
}

/**
 * Searches for patients owned by a specific organization
 * @param owningOrganization The organization that owns the data
 * @returns Array of Patient resources
 */
async function findPatientsByOwner(owningOrganization: string): Promise<Patient[]> {
  try {
    const bundle = await client.search<Patient>({
      resourceType: 'Patient',
      params: {
        '_tag': `http://example.org/fhir/ownership|${owningOrganization}`
      }
    });
    
    return bundle.entry?.map(entry => entry.resource as Patient) || [];
  } catch (error) {
    console.error('Error searching patients by owner:', error);
    throw error;
  }
}
```

### Ownership Tag Patterns

Consider these patterns for ownership tagging:

| Pattern | Description | Example |
|---------|-------------|--------|
| Organization-based | Tags resources by the organization that owns them | `http://example.org/fhir/ownership|OrganizationA` |
| System-based | Tags resources by the source system | `http://example.org/fhir/ownership|EHR-System` |
| User-based | Tags resources by the creating user | `http://example.org/fhir/ownership|practitioner-123` |
| Multi-level | Combines multiple ownership levels | Multiple tags for organization, system, and user |

## Source System Tracking

Source system tags identify the origin of data, which is essential for data provenance and troubleshooting.

### Implementing Source System Tags

```typescript
/**
 * Adds source system tags to a FHIR resource
 * @param resource The FHIR resource to tag
 * @param sourceSystem The source system identifier
 * @param sourceSystemVersion Optional version of the source system
 * @returns The resource with source system tags
 */
function addSourceSystemTags<T extends { meta?: Meta }>(  
  resource: T,
  sourceSystem: string,
  sourceSystemVersion?: string
): T {
  // Create meta object if it doesn't exist
  const meta: Meta = resource.meta || {};
  
  // Initialize tags array if it doesn't exist
  meta.tag = meta.tag || [];
  
  // Add source system tag
  meta.tag.push({
    system: 'http://example.org/fhir/source-system',
    code: sourceSystem,
    display: `Source: ${sourceSystem}`
  });
  
  // Add version tag if provided
  if (sourceSystemVersion) {
    meta.tag.push({
      system: 'http://example.org/fhir/source-system-version',
      code: sourceSystemVersion,
      display: `Version: ${sourceSystemVersion}`
    });
  }
  
  // Return the resource with updated meta
  return {
    ...resource,
    meta
  };
}

/**
 * Creates a resource with source system tracking
 * @param resourceType The type of resource to create
 * @param resourceData The resource data
 * @param sourceSystem The source system identifier
 * @param sourceSystemVersion Optional version of the source system
 * @returns The created resource
 */
async function createResourceWithSourceTracking<T>(
  resourceType: string,
  resourceData: any,
  sourceSystem: string,
  sourceSystemVersion?: string
): Promise<T> {
  try {
    // Add resourceType if not present
    const data = {
      resourceType,
      ...resourceData
    };
    
    // Add source system tags
    const taggedData = addSourceSystemTags(data, sourceSystem, sourceSystemVersion);
    
    // Create the resource
    const result = await client.create<T>(taggedData);
    console.log(`${resourceType} created with source system tag ${sourceSystem}`);
    return result;
  } catch (error) {
    console.error(`Error creating ${resourceType} with source tracking:`, error);
    throw error;
  }
}
```

## Provenance Implementation

FHIR Provenance resources provide a standardized way to track the origins and modifications of resources.

### Creating Provenance Records

```typescript
import { Provenance } from '@aidbox/sdk-r4/types';

/**
 * Creates a Provenance resource to track changes to a FHIR resource
 * @param targetResource The resource being tracked
 * @param agent The entity responsible for the change
 * @param activity The type of activity performed
 * @returns The created Provenance resource
 */
async function createProvenanceRecord(
  targetResource: { resourceType: string; id: string },
  agent: {
    type: 'Organization' | 'Practitioner' | 'Device' | 'Patient';
    id: string;
    display: string;
  },
  activity: 'create' | 'update' | 'delete' | 'merge' | 'import'
): Promise<Provenance> {
  try {
    const provenance: Partial<Provenance> = {
      resourceType: 'Provenance',
      target: [
        {
          reference: `${targetResource.resourceType}/${targetResource.id}`
        }
      ],
      recorded: new Date().toISOString(),
      agent: [
        {
          type: {
            coding: [
              {
                system: 'http://terminology.hl7.org/CodeSystem/provenance-participant-type',
                code: 'author',
                display: 'Author'
              }
            ]
          },
          who: {
            reference: `${agent.type}/${agent.id}`,
            display: agent.display
          }
        }
      ],
      activity: {
        coding: [
          {
            system: 'http://terminology.hl7.org/CodeSystem/v3-DataOperation',
            code: activity,
            display: activity.charAt(0).toUpperCase() + activity.slice(1)
          }
        ]
      }
    };
    
    const result = await client.create<Provenance>(provenance);
    console.log(`Provenance record created for ${targetResource.resourceType}/${targetResource.id}`);
    return result;
  } catch (error) {
    console.error('Error creating provenance record:', error);
    throw error;
  }
}

/**
 * Creates a resource and its associated provenance record
 * @param resourceType The type of resource to create
 * @param resourceData The resource data
 * @param agent The entity responsible for the creation
 * @returns The created resource
 */
async function createResourceWithProvenance<T extends { id?: string }>(
  resourceType: string,
  resourceData: any,
  agent: {
    type: 'Organization' | 'Practitioner' | 'Device' | 'Patient';
    id: string;
    display: string;
  }
): Promise<T> {
  try {
    // Create the resource
    const resource = await client.create<T>({
      resourceType,
      ...resourceData
    });
    
    // Create provenance record
    await createProvenanceRecord(
      { resourceType, id: resource.id as string },
      agent,
      'create'
    );
    
    return resource;
  } catch (error) {
    console.error(`Error creating ${resourceType} with provenance:`, error);
    throw error;
  }
}
```

### Querying Provenance Records

```typescript
/**
 * Retrieves the provenance history for a resource
 * @param resourceType The type of resource
 * @param resourceId The ID of the resource
 * @returns Array of Provenance resources
 */
async function getResourceProvenance(
  resourceType: string,
  resourceId: string
): Promise<Provenance[]> {
  try {
    const bundle = await client.search<Provenance>({
      resourceType: 'Provenance',
      params: {
        'target': `${resourceType}/${resourceId}`
      }
    });
    
    return bundle.entry?.map(entry => entry.resource as Provenance) || [];
  } catch (error) {
    console.error('Error retrieving provenance records:', error);
    throw error;
  }
}

/**
 * Retrieves resources created by a specific agent
 * @param agentType The type of agent (Organization, Practitioner, etc.)
 * @param agentId The ID of the agent
 * @returns Array of Provenance resources
 */
async function getResourcesByAgent(
  agentType: string,
  agentId: string
): Promise<Provenance[]> {
  try {
    const bundle = await client.search<Provenance>({
      resourceType: 'Provenance',
      params: {
        'agent:who': `${agentType}/${agentId}`
      }
    });
    
    return bundle.entry?.map(entry => entry.resource as Provenance) || [];
  } catch (error) {
    console.error('Error retrieving resources by agent:', error);
    throw error;
  }
}
```

## Audit Requirements

Audit logging is essential for tracking who accessed what data and when, which is critical for compliance with regulations like HIPAA.

### Implementing Audit Logging

```typescript
import { AuditEvent } from '@aidbox/sdk-r4/types';

/**
 * Creates an AuditEvent for resource access or modification
 * @param action The action performed (create, read, update, delete)
 * @param resourceType The type of resource accessed
 * @param resourceId The ID of the resource accessed
 * @param user The user who performed the action
 * @param outcome The outcome of the action (success, error, etc.)
 * @returns The created AuditEvent
 */
async function createAuditEvent(
  action: 'create' | 'read' | 'update' | 'delete',
  resourceType: string,
  resourceId: string,
  user: {
    id: string;
    name: string;
  },
  outcome: 'success' | 'error' | 'serious-failure' = 'success'
): Promise<AuditEvent> {
  try {
    const auditEvent: Partial<AuditEvent> = {
      resourceType: 'AuditEvent',
      type: {
        system: 'http://terminology.hl7.org/CodeSystem/audit-event-type',
        code: 'rest',
        display: 'RESTful Operation'
      },
      action: action === 'read' ? 'E' : 'C', // E=Execute (read), C=Create/Update/Delete
      recorded: new Date().toISOString(),
      outcome: outcome === 'success' ? '0' : (outcome === 'error' ? '4' : '8'), // 0=Success, 4=Minor error, 8=Serious failure
      agent: [
        {
          type: {
            coding: [
              {
                system: 'http://terminology.hl7.org/CodeSystem/v3-RoleClass',
                code: 'AGNT',
                display: 'Agent'
              }
            ]
          },
          who: {
            identifier: {
              value: user.id
            },
            display: user.name
          }
        }
      ],
      source: {
        observer: {
          display: 'FHIR Server'
        }
      },
      entity: [
        {
          what: {
            reference: `${resourceType}/${resourceId}`
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
        }
      ]
    };
    
    const result = await client.create<AuditEvent>(auditEvent);
    console.log(`Audit event created for ${action} on ${resourceType}/${resourceId}`);
    return result;
  } catch (error) {
    console.error('Error creating audit event:', error);
    throw error;
  }
}

/**
 * Wrapper function to create a resource with audit logging
 * @param resourceType The type of resource to create
 * @param resourceData The resource data
 * @param user The user performing the action
 * @returns The created resource
 */
async function createResourceWithAudit<T extends { id?: string }>(
  resourceType: string,
  resourceData: any,
  user: {
    id: string;
    name: string;
  }
): Promise<T> {
  try {
    // Create the resource
    const resource = await client.create<T>({
      resourceType,
      ...resourceData
    });
    
    // Create audit event
    await createAuditEvent(
      'create',
      resourceType,
      resource.id as string,
      user
    );
    
    return resource;
  } catch (error) {
    console.error(`Error creating ${resourceType} with audit:`, error);
    
    // Create audit event for failure
    if (error.resourceType && error.id) {
      await createAuditEvent(
        'create',
        resourceType,
        error.id,
        user,
        'error'
      );
    }
    
    throw error;
  }
}

/**
 * Wrapper function to read a resource with audit logging
 * @param resourceType The type of resource to read
 * @param resourceId The ID of the resource to read
 * @param user The user performing the action
 * @returns The read resource
 */
async function readResourceWithAudit<T>(
  resourceType: string,
  resourceId: string,
  user: {
    id: string;
    name: string;
  }
): Promise<T> {
  try {
    // Read the resource
    const resource = await client.read<T>({
      resourceType,
      id: resourceId
    });
    
    // Create audit event
    await createAuditEvent(
      'read',
      resourceType,
      resourceId,
      user
    );
    
    return resource;
  } catch (error) {
    console.error(`Error reading ${resourceType}/${resourceId} with audit:`, error);
    
    // Create audit event for failure
    await createAuditEvent(
      'read',
      resourceType,
      resourceId,
      user,
      'error'
    );
    
    throw error;
  }
}
```

### Querying Audit Logs

```typescript
/**
 * Searches for audit events based on various criteria
 * @param params Search parameters
 * @returns Array of AuditEvent resources
 */
async function searchAuditEvents(params: {
  userId?: string;
  patientId?: string;
  action?: 'create' | 'read' | 'update' | 'delete';
  startDate?: string;
  endDate?: string;
}): Promise<AuditEvent[]> {
  try {
    const searchParams: Record<string, string> = {};
    
    // Add search parameters if provided
    if (params.userId) {
      searchParams['agent:who.identifier'] = params.userId;
    }
    
    if (params.patientId) {
      searchParams['entity:what'] = `Patient/${params.patientId}`;
    }
    
    if (params.action) {
      searchParams['action'] = params.action === 'read' ? 'E' : 'C';
    }
    
    if (params.startDate || params.endDate) {
      const dateRange = [];
      if (params.startDate) dateRange.push(`ge${params.startDate}`);
      if (params.endDate) dateRange.push(`le${params.endDate}`);
      searchParams['date'] = dateRange.join(',');
    }
    
    const bundle = await client.search<AuditEvent>({
      resourceType: 'AuditEvent',
      params: searchParams
    });
    
    return bundle.entry?.map(entry => entry.resource as AuditEvent) || [];
  } catch (error) {
    console.error('Error searching audit events:', error);
    throw error;
  }
}
```

## Comprehensive Tagging Strategy

A comprehensive tagging strategy combines ownership, source tracking, provenance, and audit logging.

### Implementing a Complete Tagging Solution

```typescript
/**
 * Comprehensive resource creation with all tagging mechanisms
 * @param resourceType The type of resource to create
 * @param resourceData The resource data
 * @param context The context information for tagging
 * @returns The created resource
 */
async function createResourceWithComprehensiveTagging<T extends { id?: string }>(
  resourceType: string,
  resourceData: any,
  context: {
    user: {
      id: string;
      name: string;
      type: 'Practitioner' | 'Patient' | 'RelatedPerson';
    };
    organization: {
      id: string;
      name: string;
    };
    sourceSystem: string;
    sourceSystemVersion?: string;
  }
): Promise<T> {
  try {
    // Add resourceType if not present
    let data = {
      resourceType,
      ...resourceData
    };
    
    // Add meta if not present
    if (!data.meta) {
      data.meta = {};
    }
    
    // Add tags if not present
    if (!data.meta.tag) {
      data.meta.tag = [];
    }
    
    // Add ownership tag
    data.meta.tag.push({
      system: 'http://example.org/fhir/ownership',
      code: context.organization.id,
      display: `Owned by ${context.organization.name}`
    });
    
    // Add source system tag
    data.meta.tag.push({
      system: 'http://example.org/fhir/source-system',
      code: context.sourceSystem,
      display: `Source: ${context.sourceSystem}`
    });
    
    // Add version tag if provided
    if (context.sourceSystemVersion) {
      data.meta.tag.push({
        system: 'http://example.org/fhir/source-system-version',
        code: context.sourceSystemVersion,
        display: `Version: ${context.sourceSystemVersion}`
      });
    }
    
    // Create the resource
    const resource = await client.create<T>(data);
    
    // Create provenance record
    await createProvenanceRecord(
      { resourceType, id: resource.id as string },
      {
        type: context.user.type,
        id: context.user.id,
        display: context.user.name
      },
      'create'
    );
    
    // Create audit event
    await createAuditEvent(
      'create',
      resourceType,
      resource.id as string,
      {
        id: context.user.id,
        name: context.user.name
      }
    );
    
    return resource;
  } catch (error) {
    console.error(`Error creating ${resourceType} with comprehensive tagging:`, error);
    throw error;
  }
}
```

## Conclusion

Effective data tagging in FHIR is essential for maintaining data governance, tracking provenance, and ensuring compliance with healthcare regulations. By implementing a comprehensive tagging strategy that includes ownership tags, source system tracking, provenance records, and audit logging, you can create a robust foundation for secure and traceable healthcare data management.

Key takeaways:

1. Use meta.tag elements to track data ownership and source systems
2. Implement Provenance resources to maintain a complete history of data changes
3. Create AuditEvent resources to log all data access and modifications
4. Combine these approaches for a comprehensive data governance solution
5. Design your tagging strategy to support your organization's security and compliance requirements

By following these guidelines, you can ensure that your FHIR implementation provides the necessary data governance capabilities to support secure and compliant healthcare data management.
