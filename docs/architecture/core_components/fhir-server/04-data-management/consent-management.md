# Patient Consent Management in FHIR

## Introduction

Patient consent management is a critical aspect of healthcare information systems that ensures patient privacy preferences are captured, stored, and enforced. Effective consent management allows patients to control how their health information is shared and used, while enabling healthcare providers to access necessary information for care delivery. This guide explains how to implement patient consent management in FHIR systems, covering consent capture, enforcement, and cross-organizational consent management.

### Quick Start

1. Define your consent management strategy based on regulatory requirements and organizational policies
2. Implement FHIR Consent resources to capture patient privacy preferences
3. Create consent enforcement mechanisms at the data access layer
4. Develop workflows for capturing and updating consent directives
5. Implement audit mechanisms to track consent-related activities

### Related Components

- [Patient Matching in FHIR](fhir-patient-matching.md): Learn about matching patient records across systems
- [Golden Record Management](fhir-golden-records.md): Create and maintain master patient records
- [Identity Linking](fhir-identity-linking.md): Link patient identities across systems
- [Entitlement Management](fhir-entitlement-management.md): Control access to FHIR resources

## Capturing and Enforcing Patient Consent

FHIR provides the Consent resource for capturing and managing patient consent directives.

### Implementing Consent Resources

```typescript
import { AidboxClient } from '@aidbox/sdk-r4';
import { Consent, Patient } from '@aidbox/sdk-r4/types';

const client = new AidboxClient({
  baseUrl: 'http://localhost:8888',
  auth: {
    type: 'basic',
    username: 'root',
    password: 'secret'
  }
});

/**
 * Consent categories
 */
enum ConsentCategory {
  RESEARCH = 'RESEARCH',
  TREATMENT = 'TREATMENT',
  PRIVACY = 'PRIVACY',
  INFORMATION_DISCLOSURE = 'INFORMATION_DISCLOSURE'
}

/**
 * Consent policy types
 */
enum ConsentPolicyType {
  OPT_IN = 'OPTIN', // Default deny, explicitly allowed
  OPT_OUT = 'OPTOUT' // Default allow, explicitly denied
}

/**
 * Creates a patient consent directive
 * @param patientId The ID of the patient
 * @param category The consent category
 * @param policyType The consent policy type
 * @param allowedRecipients Array of allowed recipient references
 * @param deniedRecipients Array of denied recipient references
 * @param purpose Optional purpose of use
 * @returns The created Consent resource
 */
async function createPatientConsent(
  patientId: string,
  category: ConsentCategory,
  policyType: ConsentPolicyType,
  allowedRecipients: string[] = [],
  deniedRecipients: string[] = [],
  purpose?: string
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
          code: category.toLowerCase(),
          display: category.charAt(0) + category.slice(1).toLowerCase().replace('_', ' ')
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
          code: policyType,
          display: policyType === ConsentPolicyType.OPT_IN ? 'Opt-in' : 'Opt-out'
        }]
      },
      provision: {
        type: policyType === ConsentPolicyType.OPT_IN ? 'permit' : 'deny'
      }
    };
    
    // Add purpose if provided
    if (purpose) {
      consent.provision = {
        ...consent.provision,
        purpose: [{
          system: 'http://terminology.hl7.org/CodeSystem/v3-ActReason',
          code: purpose,
          display: getPurposeDisplay(purpose)
        }]
      };
    }
    
    // Add allowed recipients
    if (allowedRecipients.length > 0) {
      if (policyType === ConsentPolicyType.OPT_IN) {
        // For opt-in, allowed recipients are in the main provision
        consent.provision = {
          ...consent.provision,
          actor: allowedRecipients.map(recipient => ({
            role: {
              coding: [{
                system: 'http://terminology.hl7.org/CodeSystem/v3-RoleCode',
                code: 'RECIP',
                display: 'recipient'
              }]
            },
            reference: {
              reference: recipient
            }
          }))
        };
      } else {
        // For opt-out, allowed recipients are exceptions to the denial
        consent.provision = {
          ...consent.provision,
          provision: [{
            type: 'permit',
            actor: allowedRecipients.map(recipient => ({
              role: {
                coding: [{
                  system: 'http://terminology.hl7.org/CodeSystem/v3-RoleCode',
                  code: 'RECIP',
                  display: 'recipient'
                }]
              },
              reference: {
                reference: recipient
              }
            }))
          }]
        };
      }
    }
    
    // Add denied recipients
    if (deniedRecipients.length > 0) {
      if (policyType === ConsentPolicyType.OPT_IN) {
        // For opt-in, denied recipients are exceptions to the permission
        if (!consent.provision.provision) {
          consent.provision.provision = [];
        }
        
        consent.provision.provision.push({
          type: 'deny',
          actor: deniedRecipients.map(recipient => ({
            role: {
              coding: [{
                system: 'http://terminology.hl7.org/CodeSystem/v3-RoleCode',
                code: 'RECIP',
                display: 'recipient'
              }]
            },
            reference: {
              reference: recipient
            }
          }))
        });
      } else {
        // For opt-out, denied recipients are in the main provision
        consent.provision = {
          ...consent.provision,
          actor: deniedRecipients.map(recipient => ({
            role: {
              coding: [{
                system: 'http://terminology.hl7.org/CodeSystem/v3-RoleCode',
                code: 'RECIP',
                display: 'recipient'
              }]
            },
            reference: {
              reference: recipient
            }
          }))
        };
      }
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
function getPurposeDisplay(purpose: string): string {
  const purposeMap: Record<string, string> = {
    'TREAT': 'Treatment',
    'ETREAT': 'Emergency Treatment',
    'HRESCH': 'Healthcare Research',
    'PATRQT': 'Patient Requested',
    'PUBHLTH': 'Public Health',
    'HPAYMT': 'Healthcare Payment'
  };
  
  return purposeMap[purpose] || purpose;
}
```

### Checking Patient Consent

```typescript
/**
 * Checks if a recipient has consent to access a patient's data
 * @param patientId The ID of the patient
 * @param recipientId The ID of the recipient
 * @param category The consent category
 * @param purpose The purpose for access
 * @returns Whether consent exists
 */
async function checkPatientConsent(
  patientId: string,
  recipientId: string,
  category: ConsentCategory,
  purpose?: string
): Promise<boolean> {
  try {
    // Get active consents for this patient and category
    const bundle = await client.search<Consent>({
      resourceType: 'Consent',
      params: {
        patient: patientId,
        status: 'active',
        category: category.toLowerCase(),
        _sort: '-date'
      }
    });
    
    // No consents means no explicit consent
    if (!bundle.entry || bundle.entry.length === 0) {
      return false;
    }
    
    // Get the most recent consent
    const consent = bundle.entry[0].resource as Consent;
    
    // Check policy type
    const policyType = consent.policyRule?.coding?.[0]?.code as ConsentPolicyType;
    const isOptIn = policyType === ConsentPolicyType.OPT_IN;
    
    // Check purpose if specified
    if (purpose && consent.provision?.purpose) {
      const hasPurpose = consent.provision.purpose.some(
        p => p.coding?.some(c => c.code === purpose)
      );
      
      if (!hasPurpose) {
        return false;
      }
    }
    
    // Check if recipient is explicitly mentioned
    const recipientReference = getRecipientReference(recipientId);
    
    // For opt-in, check if recipient is allowed and not denied
    if (isOptIn) {
      // Check if recipient is in the allowed list
      const isAllowed = consent.provision?.actor?.some(
        actor => actor.reference?.reference === recipientReference
      ) || false;
      
      // Check if recipient is in the denied list
      const isDenied = consent.provision?.provision?.some(
        provision => 
          provision.type === 'deny' && 
          provision.actor?.some(actor => actor.reference?.reference === recipientReference)
      ) || false;
      
      return isAllowed && !isDenied;
    } 
    // For opt-out, check if recipient is not denied or is explicitly allowed
    else {
      // Check if recipient is in the denied list
      const isDenied = consent.provision?.actor?.some(
        actor => actor.reference?.reference === recipientReference
      ) || false;
      
      // Check if recipient is in the allowed list
      const isAllowed = consent.provision?.provision?.some(
        provision => 
          provision.type === 'permit' && 
          provision.actor?.some(actor => actor.reference?.reference === recipientReference)
      ) || false;
      
      return !isDenied || isAllowed;
    }
  } catch (error) {
    console.error(`Error checking consent for patient ${patientId} and recipient ${recipientId}:`, error);
    throw error;
  }
}

/**
 * Gets the reference string for a recipient
 */
function getRecipientReference(recipientId: string): string {
  // Check if the ID already includes a resource type
  if (recipientId.includes('/')) {
    return recipientId;
  }
  
  // Assume Practitioner if no resource type is specified
  return `Practitioner/${recipientId}`;
}
```

### Implementing Consent Enforcement

```typescript
/**
 * Enforces consent when accessing patient data
 * @param patientId The ID of the patient
 * @param recipientId The ID of the recipient
 * @param resourceType The type of resource being accessed
 * @param purpose The purpose for access
 * @returns Whether access is allowed
 */
async function enforceConsent(
  patientId: string,
  recipientId: string,
  resourceType: string,
  purpose?: string
): Promise<boolean> {
  try {
    // Determine the appropriate consent category based on resource type
    const category = getConsentCategoryForResource(resourceType);
    
    // Check consent
    const hasConsent = await checkPatientConsent(
      patientId,
      recipientId,
      category,
      purpose
    );
    
    // Log consent check for audit purposes
    await logConsentCheck(
      patientId,
      recipientId,
      resourceType,
      category,
      purpose,
      hasConsent
    );
    
    return hasConsent;
  } catch (error) {
    console.error(`Error enforcing consent for patient ${patientId} and recipient ${recipientId}:`, error);
    throw error;
  }
}

/**
 * Determines the appropriate consent category for a resource type
 */
function getConsentCategoryForResource(resourceType: string): ConsentCategory {
  // Map resource types to consent categories
  const resourceCategoryMap: Record<string, ConsentCategory> = {
    'Patient': ConsentCategory.PRIVACY,
    'Observation': ConsentCategory.TREATMENT,
    'Condition': ConsentCategory.TREATMENT,
    'MedicationRequest': ConsentCategory.TREATMENT,
    'DiagnosticReport': ConsentCategory.TREATMENT,
    'ResearchSubject': ConsentCategory.RESEARCH,
    'Claim': ConsentCategory.INFORMATION_DISCLOSURE
  };
  
  return resourceCategoryMap[resourceType] || ConsentCategory.PRIVACY;
}

/**
 * Logs a consent check for audit purposes
 */
async function logConsentCheck(
  patientId: string,
  recipientId: string,
  resourceType: string,
  category: ConsentCategory,
  purpose?: string,
  allowed?: boolean
): Promise<void> {
  try {
    const auditEvent = {
      resourceType: 'AuditEvent',
      type: {
        system: 'http://terminology.hl7.org/CodeSystem/audit-event-type',
        code: 'consent-check',
        display: 'Consent Check'
      },
      action: 'E', // Execute
      recorded: new Date().toISOString(),
      outcome: allowed ? '0' : '4', // 0 = Success, 4 = Minor failure
      agent: [
        {
          type: {
            coding: [{
              system: 'http://terminology.hl7.org/CodeSystem/v3-RoleClass',
              code: 'RECIP',
              display: 'recipient'
            }]
          },
          who: {
            reference: getRecipientReference(recipientId)
          },
          requestor: true
        }
      ],
      source: {
        observer: {
          display: 'Consent Enforcement Service'
        }
      },
      entity: [
        {
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
        },
        {
          type: {
            system: 'http://terminology.hl7.org/CodeSystem/audit-entity-type',
            code: '2',
            display: 'System Object'
          },
          what: {
            reference: resourceType
          },
          name: 'Resource Type'
        }
      ]
    };
    
    // Add purpose if provided
    if (purpose) {
      auditEvent.entity.push({
        type: {
          system: 'http://terminology.hl7.org/CodeSystem/audit-entity-type',
          code: '2',
          display: 'System Object'
        },
        what: {
          display: purpose
        },
        name: 'Purpose of Use'
      });
    }
    
    await client.create(auditEvent);
  } catch (error) {
    console.error('Error logging consent check:', error);
    // Don't throw error to avoid disrupting the main flow
  }
}
```

## Consent Workflows

Implementing effective consent workflows ensures that patient preferences are captured accurately and kept up-to-date.

### Consent Capture Workflow

```typescript
/**
 * Consent status
 */
enum ConsentStatus {
  ACTIVE = 'active',
  INACTIVE = 'inactive',
  REJECTED = 'rejected',
  PROPOSED = 'proposed',
  DRAFT = 'draft',
  ENTERED_IN_ERROR = 'entered-in-error'
}

/**
 * Creates a draft consent for patient review
 * @param patientId The ID of the patient
 * @param category The consent category
 * @param policyType The consent policy type
 * @param description Description of the consent
 * @returns The created draft Consent resource
 */
async function createDraftConsent(
  patientId: string,
  category: ConsentCategory,
  policyType: ConsentPolicyType,
  description: string
): Promise<Consent> {
  try {
    const consent: Partial<Consent> = {
      resourceType: 'Consent',
      status: ConsentStatus.DRAFT,
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
          code: category.toLowerCase(),
          display: category.charAt(0) + category.slice(1).toLowerCase().replace('_', ' ')
        }]
      }],
      patient: {
        reference: `Patient/${patientId}`
      },
      dateTime: new Date().toISOString(),
      policyRule: {
        coding: [{
          system: 'http://terminology.hl7.org/CodeSystem/v3-ActCode',
          code: policyType,
          display: policyType === ConsentPolicyType.OPT_IN ? 'Opt-in' : 'Opt-out'
        }]
      },
      provision: {
        type: policyType === ConsentPolicyType.OPT_IN ? 'permit' : 'deny'
      }
    };
    
    // Add description as text
    consent.text = {
      status: 'generated',
      div: `<div xmlns="http://www.w3.org/1999/xhtml">${description}</div>`
    };
    
    const result = await client.create<Consent>(consent);
    console.log(`Draft consent created with ID: ${result.id}`);
    return result;
  } catch (error) {
    console.error('Error creating draft consent:', error);
    throw error;
  }
}

/**
 * Updates the status of a consent
 * @param consentId The ID of the consent
 * @param status The new status
 * @returns The updated Consent resource
 */
async function updateConsentStatus(
  consentId: string,
  status: ConsentStatus
): Promise<Consent> {
  try {
    // Get the current consent
    const consent = await client.read<Consent>({
      resourceType: 'Consent',
      id: consentId
    });
    
    // Update the status
    consent.status = status;
    
    // Update the consent
    const result = await client.update<Consent>(consent);
    console.log(`Consent ${consentId} status updated to ${status}`);
    return result;
  } catch (error) {
    console.error(`Error updating consent ${consentId} status:`, error);
    throw error;
  }
}

/**
 * Creates a task for patient consent review
 * @param patientId The ID of the patient
 * @param consentId The ID of the consent to review
 * @returns The created Task resource
 */
async function createConsentReviewTask(
  patientId: string,
  consentId: string
): Promise<any> {
  try {
    const task = {
      resourceType: 'Task',
      status: 'requested',
      intent: 'proposal',
      code: {
        coding: [{
          system: 'http://example.org/fhir/CodeSystem/task-type',
          code: 'consent-review',
          display: 'Consent Review'
        }]
      },
      description: 'Review and approve or reject consent',
      focus: {
        reference: `Consent/${consentId}`
      },
      for: {
        reference: `Patient/${patientId}`
      },
      authoredOn: new Date().toISOString(),
      owner: {
        reference: `Patient/${patientId}`
      }
    };
    
    const result = await client.create(task);
    console.log(`Consent review task created with ID: ${result.id}`);
    return result;
  } catch (error) {
    console.error('Error creating consent review task:', error);
    throw error;
  }
}
```

## Managing Consent Across Organizations

Cross-organizational consent management ensures that patient preferences are respected across the healthcare ecosystem.

### Implementing Federated Consent

```typescript
/**
 * Creates a federated consent that applies across organizations
 * @param patientId The ID of the patient
 * @param category The consent category
 * @param policyType The consent policy type
 * @param organizations Array of organization references
 * @returns The created Consent resource
 */
async function createFederatedConsent(
  patientId: string,
  category: ConsentCategory,
  policyType: ConsentPolicyType,
  organizations: string[]
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
          code: category.toLowerCase(),
          display: category.charAt(0) + category.slice(1).toLowerCase().replace('_', ' ')
        }]
      }],
      patient: {
        reference: `Patient/${patientId}`
      },
      dateTime: new Date().toISOString(),
      performer: [{
        reference: `Patient/${patientId}`
      }],
      organization: organizations.map(org => ({
        reference: org
      })),
      policyRule: {
        coding: [{
          system: 'http://terminology.hl7.org/CodeSystem/v3-ActCode',
          code: policyType,
          display: policyType === ConsentPolicyType.OPT_IN ? 'Opt-in' : 'Opt-out'
        }]
      },
      provision: {
        type: policyType === ConsentPolicyType.OPT_IN ? 'permit' : 'deny'
      }
    };
    
    // Add extension for federated consent
    consent.extension = [
      {
        url: 'http://example.org/fhir/StructureDefinition/federated-consent',
        valueBoolean: true
      }
    ];
    
    const result = await client.create<Consent>(consent);
    console.log(`Federated consent created with ID: ${result.id}`);
    return result;
  } catch (error) {
    console.error('Error creating federated consent:', error);
    throw error;
  }
}

/**
 * Checks if a recipient has consent across organizations
 * @param patientId The ID of the patient
 * @param recipientId The ID of the recipient
 * @param category The consent category
 * @param organizationId The ID of the organization
 * @returns Whether consent exists
 */
async function checkFederatedConsent(
  patientId: string,
  recipientId: string,
  category: ConsentCategory,
  organizationId: string
): Promise<boolean> {
  try {
    // Get active federated consents for this patient and category
    const bundle = await client.search<Consent>({
      resourceType: 'Consent',
      params: {
        patient: patientId,
        status: 'active',
        category: category.toLowerCase(),
        organization: organizationId,
        _sort: '-date'
      }
    });
    
    // Filter for federated consents
    const federatedConsents = bundle.entry
      ?.map(entry => entry.resource as Consent)
      .filter(consent => 
        consent.extension?.some(ext => 
          ext.url === 'http://example.org/fhir/StructureDefinition/federated-consent' &&
          ext.valueBoolean === true
        )
      ) || [];
    
    if (federatedConsents.length === 0) {
      return false;
    }
    
    // Get the most recent federated consent
    const consent = federatedConsents[0];
    
    // Check policy type and recipient
    return checkPatientConsent(
      patientId,
      recipientId,
      category
    );
  } catch (error) {
    console.error(`Error checking federated consent for patient ${patientId} and recipient ${recipientId}:`, error);
    throw error;
  }
}
```

## Conclusion

Effective patient consent management is essential for respecting patient privacy preferences while enabling appropriate access to healthcare information. By implementing FHIR Consent resources, consent enforcement mechanisms, and cross-organizational consent management, you can create a robust consent management system that balances patient privacy with healthcare delivery needs.

Key takeaways:

1. Use FHIR Consent resources to capture patient privacy preferences
2. Implement consent enforcement at the data access layer
3. Develop workflows for capturing and updating consent directives
4. Consider cross-organizational consent management for federated healthcare environments
5. Maintain audit trails to track consent-related activities

By following these guidelines, you can create a consent management system that effectively respects patient privacy preferences across your healthcare organization.
