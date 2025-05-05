# Identity Linking in FHIR

## Introduction

Identity linking is the process of establishing connections between patient identities across different systems and contexts. In healthcare, effective identity linking ensures that patient information remains consistent and accessible regardless of where care is delivered. This guide explains how to implement identity linking techniques in FHIR systems, including using Link resources, implementing cross-reference tables, and managing identity resolution workflows.

### Quick Start

1. Define your identity linking strategy based on your organization's systems and workflows
2. Implement FHIR Patient.link elements to establish connections between related records
3. Create cross-reference tables to map identifiers across systems
4. Develop identity resolution workflows for handling ambiguous matches
5. Implement audit mechanisms to track identity linking activities

### Related Components

- [Patient Matching in FHIR](fhir-patient-matching.md): Learn about matching patient records across systems
- [Golden Record Management](fhir-golden-records.md): Create and maintain master patient records
- [Data Tagging in FHIR](data-tagging-in-fhir.md): Track data ownership and provenance
- [Patient Consent Management](fhir-consent-management.md) (Coming Soon): Manage patient consent preferences

## Using FHIR Link Resources

FHIR provides built-in mechanisms for linking patient identities through the Patient.link element.

### Implementing Patient Links

```typescript
import { AidboxClient } from '@aidbox/sdk-r4';
import { Patient } from '@aidbox/sdk-r4/types';

const client = new AidboxClient({
  baseUrl: 'http://localhost:8888',
  auth: {
    type: 'basic',
    username: 'root',
    password: 'secret'
  }
});

/**
 * Link types in FHIR Patient resources
 */
enum LinkType {
  REPLACED_BY = 'replaced-by', // This patient record has been replaced by another
  REPLACES = 'replaces', // This patient record replaces another
  REFER = 'refer', // This patient record should be referred to another
  SEEALSO = 'seealso' // This patient record is related to another
}

/**
 * Links two patient records
 * @param sourcePatientId The ID of the source patient
 * @param targetPatientId The ID of the target patient
 * @param linkType The type of link to establish
 * @returns The updated source patient
 */
async function linkPatients(
  sourcePatientId: string,
  targetPatientId: string,
  linkType: LinkType
): Promise<Patient> {
  try {
    // Get the source patient
    const sourcePatient = await client.read<Patient>({
      resourceType: 'Patient',
      id: sourcePatientId
    });
    
    // Initialize link array if it doesn't exist
    if (!sourcePatient.link) {
      sourcePatient.link = [];
    }
    
    // Check if link already exists
    const existingLinkIndex = sourcePatient.link.findIndex(
      link => link.other.reference === `Patient/${targetPatientId}`
    );
    
    if (existingLinkIndex >= 0) {
      // Update existing link
      sourcePatient.link[existingLinkIndex].type = linkType;
    } else {
      // Add new link
      sourcePatient.link.push({
        other: {
          reference: `Patient/${targetPatientId}`
        },
        type: linkType
      });
    }
    
    // Update the source patient
    const result = await client.update<Patient>(sourcePatient);
    console.log(`Patient ${sourcePatientId} linked to ${targetPatientId} with type ${linkType}`);
    
    // If the link type requires reciprocal link, create it
    if (linkType === LinkType.REPLACED_BY) {
      await createReciprocalLink(targetPatientId, sourcePatientId, LinkType.REPLACES);
    } else if (linkType === LinkType.REPLACES) {
      await createReciprocalLink(targetPatientId, sourcePatientId, LinkType.REPLACED_BY);
    } else if (linkType === LinkType.SEEALSO) {
      await createReciprocalLink(targetPatientId, sourcePatientId, LinkType.SEEALSO);
    }
    
    return result;
  } catch (error) {
    console.error(`Error linking patients ${sourcePatientId} and ${targetPatientId}:`, error);
    throw error;
  }
}

/**
 * Creates a reciprocal link between patients
 * @param patientId The ID of the patient to update
 * @param linkedPatientId The ID of the linked patient
 * @param linkType The type of link to establish
 * @returns The updated patient
 */
async function createReciprocalLink(
  patientId: string,
  linkedPatientId: string,
  linkType: LinkType
): Promise<Patient> {
  try {
    // Get the patient
    const patient = await client.read<Patient>({
      resourceType: 'Patient',
      id: patientId
    });
    
    // Initialize link array if it doesn't exist
    if (!patient.link) {
      patient.link = [];
    }
    
    // Check if link already exists
    const existingLinkIndex = patient.link.findIndex(
      link => link.other.reference === `Patient/${linkedPatientId}`
    );
    
    if (existingLinkIndex >= 0) {
      // Update existing link
      patient.link[existingLinkIndex].type = linkType;
    } else {
      // Add new link
      patient.link.push({
        other: {
          reference: `Patient/${linkedPatientId}`
        },
        type: linkType
      });
    }
    
    // Update the patient
    const result = await client.update<Patient>(patient);
    console.log(`Reciprocal link created: Patient ${patientId} linked to ${linkedPatientId} with type ${linkType}`);
    return result;
  } catch (error) {
    console.error(`Error creating reciprocal link between ${patientId} and ${linkedPatientId}:`, error);
    throw error;
  }
}
```

### Finding Linked Patients

```typescript
/**
 * Finds all patients linked to a specific patient
 * @param patientId The ID of the patient
 * @param linkType Optional link type to filter by
 * @returns Array of linked patients with their link types
 */
async function findLinkedPatients(
  patientId: string,
  linkType?: LinkType
): Promise<Array<{ patient: Patient; linkType: LinkType }>> {
  try {
    // Get the patient
    const patient = await client.read<Patient>({
      resourceType: 'Patient',
      id: patientId
    });
    
    // Check if patient has links
    if (!patient.link || patient.link.length === 0) {
      return [];
    }
    
    // Filter links by type if specified
    const links = linkType
      ? patient.link.filter(link => link.type === linkType)
      : patient.link;
    
    // Get linked patients
    const linkedPatients: Array<{ patient: Patient; linkType: LinkType }> = [];
    
    for (const link of links) {
      const linkedPatientId = link.other.reference.split('/')[1];
      const linkedPatient = await client.read<Patient>({
        resourceType: 'Patient',
        id: linkedPatientId
      });
      
      linkedPatients.push({
        patient: linkedPatient,
        linkType: link.type as LinkType
      });
    }
    
    return linkedPatients;
  } catch (error) {
    console.error(`Error finding linked patients for ${patientId}:`, error);
    throw error;
  }
}

/**
 * Finds all patients in a linked chain (e.g., all replacements)
 * @param patientId The ID of the starting patient
 * @param linkType The link type to follow
 * @returns Array of patients in the chain
 */
async function findPatientChain(
  patientId: string,
  linkType: LinkType.REPLACED_BY | LinkType.REPLACES
): Promise<Patient[]> {
  try {
    const chain: Patient[] = [];
    const visited = new Set<string>();
    
    // Get the starting patient
    const startPatient = await client.read<Patient>({
      resourceType: 'Patient',
      id: patientId
    });
    
    chain.push(startPatient);
    visited.add(patientId);
    
    let currentId = patientId;
    let hasNext = true;
    
    // Follow the chain
    while (hasNext) {
      const linkedPatients = await findLinkedPatients(currentId, linkType);
      
      if (linkedPatients.length === 0) {
        hasNext = false;
      } else {
        // Get the first linked patient (assuming a chain)
        const nextPatient = linkedPatients[0].patient;
        const nextId = nextPatient.id as string;
        
        // Check for circular references
        if (visited.has(nextId)) {
          hasNext = false;
        } else {
          chain.push(nextPatient);
          visited.add(nextId);
          currentId = nextId;
        }
      }
    }
    
    return chain;
  } catch (error) {
    console.error(`Error finding patient chain for ${patientId}:`, error);
    throw error;
  }
}
```

## Implementing Cross-Reference Tables

Cross-reference tables map patient identifiers across different systems, providing a centralized lookup mechanism.

### Creating and Managing Cross-References

```typescript
/**
 * Patient identifier mapping
 */
interface IdentifierMapping {
  system: string; // Identifier system
  value: string; // Identifier value
  assigner?: string; // Organization that assigned the identifier
}

/**
 * Creates a cross-reference resource
 * @param patientId The ID of the FHIR Patient resource
 * @param identifiers Array of identifiers from different systems
 * @returns The created cross-reference resource
 */
async function createCrossReference(
  patientId: string,
  identifiers: IdentifierMapping[]
): Promise<any> {
  try {
    // Create a custom resource for cross-references
    const crossReference = {
      resourceType: 'PatientCrossReference', // Custom resource type
      patient: {
        reference: `Patient/${patientId}`
      },
      identifiers: identifiers,
      active: true,
      created: new Date().toISOString(),
      meta: {
        profile: ['http://example.org/fhir/StructureDefinition/patient-cross-reference']
      }
    };
    
    const result = await client.request({
      method: 'POST',
      url: '/PatientCrossReference',
      data: crossReference
    });
    
    console.log(`Cross-reference created for patient ${patientId}`);
    return result.data;
  } catch (error) {
    console.error(`Error creating cross-reference for patient ${patientId}:`, error);
    throw error;
  }
}

/**
 * Finds a patient by identifier using cross-references
 * @param identifier The identifier to search for
 * @returns The patient ID if found
 */
async function findPatientByIdentifier(
  identifier: IdentifierMapping
): Promise<string | null> {
  try {
    // Search for cross-reference with the given identifier
    const response = await client.request({
      method: 'GET',
      url: `/PatientCrossReference?identifiers.system=${encodeURIComponent(identifier.system)}&identifiers.value=${encodeURIComponent(identifier.value)}`
    });
    
    const bundle = response.data;
    
    if (bundle.entry && bundle.entry.length > 0) {
      // Get the patient reference from the first match
      const crossReference = bundle.entry[0].resource;
      const patientReference = crossReference.patient.reference;
      const patientId = patientReference.split('/')[1];
      
      return patientId;
    }
    
    return null;
  } catch (error) {
    console.error(`Error finding patient by identifier ${identifier.system}|${identifier.value}:`, error);
    throw error;
  }
}

/**
 * Updates a cross-reference with new identifiers
 * @param patientId The ID of the FHIR Patient resource
 * @param newIdentifiers Array of new identifiers to add
 * @returns The updated cross-reference resource
 */
async function updateCrossReference(
  patientId: string,
  newIdentifiers: IdentifierMapping[]
): Promise<any> {
  try {
    // Find existing cross-reference
    const response = await client.request({
      method: 'GET',
      url: `/PatientCrossReference?patient=Patient/${patientId}`
    });
    
    const bundle = response.data;
    
    if (bundle.entry && bundle.entry.length > 0) {
      // Update existing cross-reference
      const crossReference = bundle.entry[0].resource;
      const existingIdentifiers = crossReference.identifiers || [];
      
      // Add new identifiers that don't already exist
      for (const newIdentifier of newIdentifiers) {
        const exists = existingIdentifiers.some(
          (existing: IdentifierMapping) => 
            existing.system === newIdentifier.system && 
            existing.value === newIdentifier.value
        );
        
        if (!exists) {
          existingIdentifiers.push(newIdentifier);
        }
      }
      
      // Update the cross-reference
      crossReference.identifiers = existingIdentifiers;
      crossReference.updated = new Date().toISOString();
      
      const result = await client.request({
        method: 'PUT',
        url: `/PatientCrossReference/${crossReference.id}`,
        data: crossReference
      });
      
      console.log(`Cross-reference updated for patient ${patientId}`);
      return result.data;
    } else {
      // Create new cross-reference if none exists
      return await createCrossReference(patientId, newIdentifiers);
    }
  } catch (error) {
    console.error(`Error updating cross-reference for patient ${patientId}:`, error);
    throw error;
  }
}
```

## Managing Identity Resolution Workflows

Identity resolution workflows handle cases where patient matching is ambiguous or requires manual intervention.

### Implementing Resolution Workflows

```typescript
/**
 * Identity resolution status
 */
enum ResolutionStatus {
  PENDING = 'PENDING',
  IN_PROGRESS = 'IN_PROGRESS',
  RESOLVED = 'RESOLVED',
  REJECTED = 'REJECTED'
}

/**
 * Resolution action
 */
enum ResolutionAction {
  LINK = 'LINK',
  MERGE = 'MERGE',
  CREATE_NEW = 'CREATE_NEW',
  IGNORE = 'IGNORE'
}

/**
 * Creates an identity resolution task
 * @param potentialMatches Array of potential matching patients
 * @param sourceSystem The source system of the patient
 * @param demographicData The demographic data to match
 * @returns The created Task resource
 */
async function createIdentityResolutionTask(
  potentialMatches: Array<{ patient: Patient; score: number }>,
  sourceSystem: string,
  demographicData: {
    familyName?: string;
    givenNames?: string[];
    birthDate?: string;
    gender?: string;
  }
): Promise<any> {
  try {
    const task = {
      resourceType: 'Task',
      status: 'requested',
      intent: 'order',
      code: {
        coding: [{
          system: 'http://example.org/fhir/CodeSystem/task-type',
          code: 'identity-resolution',
          display: 'Identity Resolution'
        }]
      },
      description: 'Resolve patient identity across systems',
      authoredOn: new Date().toISOString(),
      lastModified: new Date().toISOString(),
      // Store resolution status in business status
      businessStatus: {
        coding: [{
          system: 'http://example.org/fhir/CodeSystem/resolution-status',
          code: ResolutionStatus.PENDING,
          display: 'Pending'
        }]
      },
      // Input contains the demographic data and potential matches
      input: [
        {
          type: {
            text: 'Source System'
          },
          valueString: sourceSystem
        },
        {
          type: {
            text: 'Demographic Data'
          },
          valueString: JSON.stringify(demographicData)
        },
        ...potentialMatches.map((match, index) => ({
          type: {
            text: `Potential Match ${index + 1}`
          },
          valueReference: {
            reference: `Patient/${match.patient.id}`
          },
          extension: [{
            url: 'http://example.org/fhir/StructureDefinition/match-score',
            valueDecimal: match.score
          }]
        }))
      ]
    };
    
    const result = await client.create(task);
    console.log(`Identity resolution task created with ID: ${result.id}`);
    return result;
  } catch (error) {
    console.error('Error creating identity resolution task:', error);
    throw error;
  }
}

/**
 * Updates the status of an identity resolution task
 * @param taskId The ID of the task
 * @param status The new resolution status
 * @returns The updated Task resource
 */
async function updateResolutionStatus(
  taskId: string,
  status: ResolutionStatus
): Promise<any> {
  try {
    // Get the current task
    const task = await client.read({
      resourceType: 'Task',
      id: taskId
    });
    
    // Update the business status
    task.businessStatus = {
      coding: [{
        system: 'http://example.org/fhir/CodeSystem/resolution-status',
        code: status,
        display: status.charAt(0) + status.slice(1).toLowerCase().replace('_', ' ')
      }]
    };
    
    // Update last modified
    task.lastModified = new Date().toISOString();
    
    // Update task status if resolved or rejected
    if (status === ResolutionStatus.RESOLVED) {
      task.status = 'completed';
    } else if (status === ResolutionStatus.REJECTED) {
      task.status = 'rejected';
    } else if (status === ResolutionStatus.IN_PROGRESS) {
      task.status = 'in-progress';
    }
    
    const result = await client.update(task);
    console.log(`Resolution task ${taskId} status updated to ${status}`);
    return result;
  } catch (error) {
    console.error(`Error updating resolution status for task ${taskId}:`, error);
    throw error;
  }
}

/**
 * Resolves an identity resolution task
 * @param taskId The ID of the task
 * @param action The resolution action
 * @param patientId The ID of the matched patient (if applicable)
 * @returns The updated Task resource
 */
async function resolveIdentityTask(
  taskId: string,
  action: ResolutionAction,
  patientId?: string
): Promise<any> {
  try {
    // Get the current task
    const task = await client.read({
      resourceType: 'Task',
      id: taskId
    });
    
    // Add output with resolution action
    task.output = [
      {
        type: {
          text: 'Resolution Action'
        },
        valueString: action
      }
    ];
    
    // Add patient reference if applicable
    if (patientId && (action === ResolutionAction.LINK || action === ResolutionAction.MERGE)) {
      task.output.push({
        type: {
          text: 'Matched Patient'
        },
        valueReference: {
          reference: `Patient/${patientId}`
        }
      });
    }
    
    // Update status to resolved
    await updateResolutionStatus(taskId, ResolutionStatus.RESOLVED);
    
    // Perform the resolution action
    await performResolutionAction(task, action, patientId);
    
    return task;
  } catch (error) {
    console.error(`Error resolving identity task ${taskId}:`, error);
    throw error;
  }
}

/**
 * Performs the resolution action
 * @param task The resolution task
 * @param action The resolution action
 * @param patientId The ID of the matched patient (if applicable)
 */
async function performResolutionAction(
  task: any,
  action: ResolutionAction,
  patientId?: string
): Promise<void> {
  // Extract demographic data from task input
  const demographicDataInput = task.input.find((input: any) => 
    input.type.text === 'Demographic Data'
  );
  
  if (!demographicDataInput) {
    throw new Error('Demographic data not found in task');
  }
  
  const demographicData = JSON.parse(demographicDataInput.valueString);
  
  switch (action) {
    case ResolutionAction.LINK:
      if (!patientId) {
        throw new Error('Patient ID is required for LINK action');
      }
      
      // Create a new patient with the demographic data
      const newPatient = await client.create<Patient>({
        resourceType: 'Patient',
        name: [{
          family: demographicData.familyName,
          given: demographicData.givenNames
        }],
        birthDate: demographicData.birthDate,
        gender: demographicData.gender
      });
      
      // Link the new patient to the matched patient
      await linkPatients(
        newPatient.id as string,
        patientId,
        LinkType.SEEALSO
      );
      
      console.log(`Created new patient ${newPatient.id} and linked to ${patientId}`);
      break;
    
    case ResolutionAction.MERGE:
      if (!patientId) {
        throw new Error('Patient ID is required for MERGE action');
      }
      
      // Create a new patient with the demographic data
      const patientToMerge = await client.create<Patient>({
        resourceType: 'Patient',
        name: [{
          family: demographicData.familyName,
          given: demographicData.givenNames
        }],
        birthDate: demographicData.birthDate,
        gender: demographicData.gender
      });
      
      // Link the new patient to the matched patient as replaced-by
      await linkPatients(
        patientToMerge.id as string,
        patientId,
        LinkType.REPLACED_BY
      );
      
      console.log(`Created new patient ${patientToMerge.id} and marked as replaced by ${patientId}`);
      break;
    
    case ResolutionAction.CREATE_NEW:
      // Create a new patient with no links
      const standalonePatient = await client.create<Patient>({
        resourceType: 'Patient',
        name: [{
          family: demographicData.familyName,
          given: demographicData.givenNames
        }],
        birthDate: demographicData.birthDate,
        gender: demographicData.gender
      });
      
      console.log(`Created new standalone patient ${standalonePatient.id}`);
      break;
    
    case ResolutionAction.IGNORE:
      // No action needed
      console.log('Identity resolution task ignored');
      break;
  }
}
```

## Conclusion

Effective identity linking is essential for maintaining a unified view of patient information across healthcare systems. By implementing FHIR Patient links, cross-reference tables, and identity resolution workflows, you can create a robust identity management system that ensures patient data remains consistent and accessible.

Key takeaways:

1. Use FHIR Patient.link elements to establish connections between related patient records
2. Implement cross-reference tables to map identifiers across different systems
3. Develop identity resolution workflows for handling ambiguous matches
4. Consider different linking strategies based on your organization's needs
5. Maintain audit trails to track identity linking activities

By following these guidelines, you can create an identity linking system that effectively manages patient identities across your healthcare organization.
