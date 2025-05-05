# Golden Record Management in FHIR

## Introduction

Golden records represent the single source of truth for patient information, consolidating data from multiple sources into a unified, accurate representation. Effective golden record management is crucial for healthcare organizations to maintain data integrity, improve care coordination, and enhance patient experience. This guide explains how to create and maintain golden patient records in FHIR systems, including conflict resolution strategies and update mechanisms.

### Quick Start

1. Define your golden record strategy and data governance policies
2. Implement a master patient index using FHIR Patient resources
3. Create mechanisms for resolving conflicts between source systems
4. Establish update strategies for maintaining golden records
5. Implement audit trails to track changes to golden records

### Related Components

- [Patient Matching in FHIR](fhir-patient-matching.md): Learn about matching patient records across systems
- [Identity Linking](fhir-identity-linking.md) (Coming Soon): Link patient identities across systems
- [Data Tagging in FHIR](data-tagging-in-fhir.md): Track data ownership and provenance
- [Patient Consent Management](fhir-consent-management.md) (Coming Soon): Manage patient consent preferences

## Creating and Maintaining Master Patient Records

A master patient record (golden record) consolidates information from multiple source systems into a single, authoritative record.

### Golden Record Structure

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
 * Creates a golden record for a patient
 * @param sourcePatients Array of source patient records
 * @returns The created golden record
 */
async function createGoldenRecord(
  sourcePatients: Patient[]
): Promise<Patient> {
  try {
    if (sourcePatients.length === 0) {
      throw new Error('At least one source patient is required');
    }
    
    // Create meta object with golden record tag
    const meta: Meta = {
      tag: [
        {
          system: 'http://example.org/fhir/tags',
          code: 'golden-record',
          display: 'Golden Record'
        }
      ]
    };
    
    // Create identifiers array with all source identifiers
    const identifiers = sourcePatients.flatMap(patient => patient.identifier || []);
    
    // Create links to source patients
    const link = sourcePatients.map(patient => ({
      other: {
        reference: `Patient/${patient.id}`
      },
      type: 'seealso'
    }));
    
    // Merge demographic data using best available information
    const goldenRecord: Partial<Patient> = {
      resourceType: 'Patient',
      meta,
      identifier: identifiers,
      active: true,
      link,
      // Use the most complete name from source records
      name: selectBestName(sourcePatients),
      // Use the most recent birthDate
      birthDate: selectBestBirthDate(sourcePatients),
      // Use the most frequent gender value
      gender: selectMostFrequentGender(sourcePatients),
      // Combine address information
      address: combineAddresses(sourcePatients),
      // Combine telecom information
      telecom: combineTelecom(sourcePatients),
      // Add extension to track source records
      extension: [
        {
          url: 'http://example.org/fhir/StructureDefinition/golden-record-sources',
          extension: sourcePatients.map(patient => ({
            url: 'source',
            valueReference: {
              reference: `Patient/${patient.id}`
            }
          }))
        }
      ]
    };
    
    // Create the golden record
    const result = await client.create<Patient>(goldenRecord);
    console.log(`Golden record created with ID: ${result.id}`);
    return result;
  } catch (error) {
    console.error('Error creating golden record:', error);
    throw error;
  }
}

/**
 * Selects the most complete name from source patients
 */
function selectBestName(patients: Patient[]): any[] {
  // Sort names by completeness (most elements wins)
  const allNames = patients.flatMap(patient => patient.name || []);
  
  if (allNames.length === 0) {
    return [{ use: 'official', family: 'Unknown' }];
  }
  
  // Score each name for completeness
  const scoredNames = allNames.map(name => {
    let score = 0;
    if (name.family) score += 1;
    if (name.given && name.given.length > 0) score += name.given.length;
    if (name.prefix && name.prefix.length > 0) score += 0.5;
    if (name.suffix && name.suffix.length > 0) score += 0.5;
    return { name, score };
  });
  
  // Sort by score (highest first)
  scoredNames.sort((a, b) => b.score - a.score);
  
  // Return the highest scoring name
  return [scoredNames[0].name];
}

/**
 * Selects the most recent birth date from source patients
 */
function selectBestBirthDate(patients: Patient[]): string | undefined {
  const birthDates = patients
    .map(patient => patient.birthDate)
    .filter(Boolean) as string[];
  
  if (birthDates.length === 0) {
    return undefined;
  }
  
  // Return the most recent birth date (latest update)
  return birthDates.sort().pop();
}

/**
 * Selects the most frequent gender value from source patients
 */
function selectMostFrequentGender(patients: Patient[]): string | undefined {
  const genders = patients
    .map(patient => patient.gender)
    .filter(Boolean) as string[];
  
  if (genders.length === 0) {
    return undefined;
  }
  
  // Count occurrences of each gender
  const genderCounts: Record<string, number> = {};
  for (const gender of genders) {
    genderCounts[gender] = (genderCounts[gender] || 0) + 1;
  }
  
  // Find the gender with the highest count
  let mostFrequentGender = genders[0];
  let highestCount = genderCounts[mostFrequentGender];
  
  for (const [gender, count] of Object.entries(genderCounts)) {
    if (count > highestCount) {
      mostFrequentGender = gender;
      highestCount = count;
    }
  }
  
  return mostFrequentGender;
}

/**
 * Combines addresses from source patients
 */
function combineAddresses(patients: Patient[]): any[] {
  const allAddresses = patients.flatMap(patient => patient.address || []);
  
  if (allAddresses.length === 0) {
    return [];
  }
  
  // Remove duplicates based on line, city, state, and postalCode
  const uniqueAddresses: any[] = [];
  const addressKeys = new Set<string>();
  
  for (const address of allAddresses) {
    const key = JSON.stringify({
      line: address.line,
      city: address.city,
      state: address.state,
      postalCode: address.postalCode
    });
    
    if (!addressKeys.has(key)) {
      addressKeys.add(key);
      uniqueAddresses.push(address);
    }
  }
  
  return uniqueAddresses;
}

/**
 * Combines telecom information from source patients
 */
function combineTelecom(patients: Patient[]): any[] {
  const allTelecom = patients.flatMap(patient => patient.telecom || []);
  
  if (allTelecom.length === 0) {
    return [];
  }
  
  // Remove duplicates based on system and value
  const uniqueTelecom: any[] = [];
  const telecomKeys = new Set<string>();
  
  for (const telecom of allTelecom) {
    const key = `${telecom.system}:${telecom.value}`;
    
    if (!telecomKeys.has(key)) {
      telecomKeys.add(key);
      uniqueTelecom.push(telecom);
    }
  }
  
  return uniqueTelecom;
}
```

## Resolving Conflicts Between Source Systems

When data from multiple source systems conflicts, you need strategies to determine which data to use in the golden record.

### Conflict Resolution Strategies

```typescript
/**
 * Conflict resolution strategy
 */
enum ConflictResolutionStrategy {
  MOST_RECENT = 'MOST_RECENT', // Use the most recently updated data
  SOURCE_PRIORITY = 'SOURCE_PRIORITY', // Use data from the highest priority source
  MOST_COMPLETE = 'MOST_COMPLETE', // Use the most complete data
  MANUAL = 'MANUAL' // Require manual resolution
}

/**
 * Source system priority configuration
 */
interface SourcePriority {
  system: string;
  priority: number; // Higher number = higher priority
}

/**
 * Default source system priorities
 */
const defaultSourcePriorities: SourcePriority[] = [
  { system: 'http://example.org/fhir/source/ehr', priority: 100 },
  { system: 'http://example.org/fhir/source/pms', priority: 90 },
  { system: 'http://example.org/fhir/source/lab', priority: 80 },
  { system: 'http://example.org/fhir/source/claims', priority: 70 }
];

/**
 * Creates a golden record with conflict resolution
 * @param sourcePatients Array of source patient records
 * @param strategy Conflict resolution strategy
 * @param sourcePriorities Source system priorities (for SOURCE_PRIORITY strategy)
 * @returns The created golden record
 */
async function createGoldenRecordWithConflictResolution(
  sourcePatients: Patient[],
  strategy: ConflictResolutionStrategy = ConflictResolutionStrategy.MOST_RECENT,
  sourcePriorities: SourcePriority[] = defaultSourcePriorities
): Promise<Patient> {
  try {
    if (sourcePatients.length === 0) {
      throw new Error('At least one source patient is required');
    }
    
    // Create meta object with golden record tag
    const meta: Meta = {
      tag: [
        {
          system: 'http://example.org/fhir/tags',
          code: 'golden-record',
          display: 'Golden Record'
        }
      ]
    };
    
    // Create identifiers array with all source identifiers
    const identifiers = sourcePatients.flatMap(patient => patient.identifier || []);
    
    // Create links to source patients
    const link = sourcePatients.map(patient => ({
      other: {
        reference: `Patient/${patient.id}`
      },
      type: 'seealso'
    }));
    
    // Resolve demographic data conflicts based on strategy
    let name, birthDate, gender, address, telecom;
    
    switch (strategy) {
      case ConflictResolutionStrategy.MOST_RECENT:
        // Sort patients by meta.lastUpdated (most recent first)
        const sortedByDate = [...sourcePatients].sort((a, b) => {
          const dateA = a.meta?.lastUpdated ? new Date(a.meta.lastUpdated).getTime() : 0;
          const dateB = b.meta?.lastUpdated ? new Date(b.meta.lastUpdated).getTime() : 0;
          return dateB - dateA;
        });
        
        // Use data from the most recently updated patient
        name = sortedByDate[0].name;
        birthDate = sortedByDate[0].birthDate;
        gender = sortedByDate[0].gender;
        address = sortedByDate[0].address;
        telecom = sortedByDate[0].telecom;
        break;
      
      case ConflictResolutionStrategy.SOURCE_PRIORITY:
        // Sort patients by source system priority (highest first)
        const sortedByPriority = [...sourcePatients].sort((a, b) => {
          const systemA = a.identifier?.[0]?.system || '';
          const systemB = b.identifier?.[0]?.system || '';
          
          const priorityA = sourcePriorities.find(sp => sp.system === systemA)?.priority || 0;
          const priorityB = sourcePriorities.find(sp => sp.system === systemB)?.priority || 0;
          
          return priorityB - priorityA;
        });
        
        // Use data from the highest priority source
        name = sortedByPriority[0].name;
        birthDate = sortedByPriority[0].birthDate;
        gender = sortedByPriority[0].gender;
        address = sortedByPriority[0].address;
        telecom = sortedByPriority[0].telecom;
        break;
      
      case ConflictResolutionStrategy.MOST_COMPLETE:
        // Use the most complete data for each field
        name = selectBestName(sourcePatients);
        birthDate = selectBestBirthDate(sourcePatients);
        gender = selectMostFrequentGender(sourcePatients);
        address = combineAddresses(sourcePatients);
        telecom = combineTelecom(sourcePatients);
        break;
      
      case ConflictResolutionStrategy.MANUAL:
        // Create a task for manual resolution
        await createManualResolutionTask(sourcePatients);
        
        // Use the most complete data as a starting point
        name = selectBestName(sourcePatients);
        birthDate = selectBestBirthDate(sourcePatients);
        gender = selectMostFrequentGender(sourcePatients);
        address = combineAddresses(sourcePatients);
        telecom = combineTelecom(sourcePatients);
        break;
    }
    
    // Create the golden record
    const goldenRecord: Partial<Patient> = {
      resourceType: 'Patient',
      meta,
      identifier: identifiers,
      active: true,
      link,
      name,
      birthDate,
      gender,
      address,
      telecom,
      // Add extension to track source records and resolution strategy
      extension: [
        {
          url: 'http://example.org/fhir/StructureDefinition/golden-record-sources',
          extension: sourcePatients.map(patient => ({
            url: 'source',
            valueReference: {
              reference: `Patient/${patient.id}`
            }
          }))
        },
        {
          url: 'http://example.org/fhir/StructureDefinition/conflict-resolution-strategy',
          valueString: strategy
        }
      ]
    };
    
    // Create the golden record
    const result = await client.create<Patient>(goldenRecord);
    console.log(`Golden record created with ID: ${result.id} using ${strategy} strategy`);
    return result;
  } catch (error) {
    console.error('Error creating golden record with conflict resolution:', error);
    throw error;
  }
}

/**
 * Creates a task for manual conflict resolution
 * @param sourcePatients Array of source patient records
 * @returns The created Task resource
 */
async function createManualResolutionTask(sourcePatients: Patient[]): Promise<any> {
  try {
    const task = {
      resourceType: 'Task',
      status: 'requested',
      intent: 'order',
      code: {
        coding: [{
          system: 'http://example.org/fhir/CodeSystem/task-type',
          code: 'golden-record-resolution',
          display: 'Golden Record Conflict Resolution'
        }]
      },
      description: 'Resolve conflicts in patient data for golden record creation',
      focus: {
        reference: `Patient/${sourcePatients[0].id}`
      },
      for: {
        reference: `Patient/${sourcePatients[0].id}`
      },
      authoredOn: new Date().toISOString(),
      input: sourcePatients.map((patient, index) => ({
        type: {
          text: `Source Patient ${index + 1}`
        },
        valueReference: {
          reference: `Patient/${patient.id}`
        }
      }))
    };
    
    const result = await client.create(task);
    console.log(`Manual resolution task created with ID: ${result.id}`);
    return result;
  } catch (error) {
    console.error('Error creating manual resolution task:', error);
    throw error;
  }
}
```

## Update Strategies for Golden Records

Golden records must be kept up-to-date as source systems change.

### Implementing Update Mechanisms

```typescript
/**
 * Update strategy for golden records
 */
enum UpdateStrategy {
  AUTOMATIC = 'AUTOMATIC', // Automatically update golden record when source changes
  REVIEW = 'REVIEW', // Create a task for review before updating
  SELECTIVE = 'SELECTIVE' // Only update specific fields automatically
}

/**
 * Updates a golden record when a source patient changes
 * @param goldenRecordId The ID of the golden record
 * @param updatedPatient The updated source patient
 * @param strategy The update strategy
 * @returns The updated golden record
 */
async function updateGoldenRecord(
  goldenRecordId: string,
  updatedPatient: Patient,
  strategy: UpdateStrategy = UpdateStrategy.AUTOMATIC
): Promise<Patient> {
  try {
    // Get the current golden record
    const goldenRecord = await client.read<Patient>({
      resourceType: 'Patient',
      id: goldenRecordId
    });
    
    // Get all source patients
    const sourcePatientRefs = goldenRecord.link
      ?.filter(link => link.type === 'seealso')
      .map(link => link.other.reference) || [];
    
    // Check if the updated patient is a source for this golden record
    const updatedPatientRef = `Patient/${updatedPatient.id}`;
    if (!sourcePatientRefs.includes(updatedPatientRef)) {
      throw new Error('Updated patient is not a source for this golden record');
    }
    
    // Get all source patients
    const sourcePatients: Patient[] = [];
    for (const ref of sourcePatientRefs) {
      const id = ref.split('/')[1];
      const patient = await client.read<Patient>({
        resourceType: 'Patient',
        id
      });
      
      // Replace the updated patient in the sources
      if (patient.id === updatedPatient.id) {
        sourcePatients.push(updatedPatient);
      } else {
        sourcePatients.push(patient);
      }
    }
    
    // Handle update based on strategy
    switch (strategy) {
      case UpdateStrategy.AUTOMATIC:
        // Recreate the golden record with the updated source
        return await createGoldenRecordWithConflictResolution(
          sourcePatients,
          ConflictResolutionStrategy.MOST_COMPLETE
        );
      
      case UpdateStrategy.REVIEW:
        // Create a task for review
        await createUpdateReviewTask(goldenRecordId, updatedPatient);
        return goldenRecord;
      
      case UpdateStrategy.SELECTIVE:
        // Only update specific fields
        return await updateSelectiveFields(goldenRecord, updatedPatient, sourcePatients);
    }
  } catch (error) {
    console.error('Error updating golden record:', error);
    throw error;
  }
}

/**
 * Creates a task for reviewing golden record updates
 * @param goldenRecordId The ID of the golden record
 * @param updatedPatient The updated source patient
 * @returns The created Task resource
 */
async function createUpdateReviewTask(
  goldenRecordId: string,
  updatedPatient: Patient
): Promise<any> {
  try {
    const task = {
      resourceType: 'Task',
      status: 'requested',
      intent: 'order',
      code: {
        coding: [{
          system: 'http://example.org/fhir/CodeSystem/task-type',
          code: 'golden-record-update-review',
          display: 'Golden Record Update Review'
        }]
      },
      description: 'Review updates to source patient for golden record',
      focus: {
        reference: `Patient/${goldenRecordId}`
      },
      for: {
        reference: `Patient/${goldenRecordId}`
      },
      authoredOn: new Date().toISOString(),
      input: [
        {
          type: {
            text: 'Golden Record'
          },
          valueReference: {
            reference: `Patient/${goldenRecordId}`
          }
        },
        {
          type: {
            text: 'Updated Source Patient'
          },
          valueReference: {
            reference: `Patient/${updatedPatient.id}`
          }
        }
      ]
    };
    
    const result = await client.create(task);
    console.log(`Update review task created with ID: ${result.id}`);
    return result;
  } catch (error) {
    console.error('Error creating update review task:', error);
    throw error;
  }
}

/**
 * Updates selective fields in a golden record
 * @param goldenRecord The current golden record
 * @param updatedPatient The updated source patient
 * @param allSourcePatients All source patients
 * @returns The updated golden record
 */
async function updateSelectiveFields(
  goldenRecord: Patient,
  updatedPatient: Patient,
  allSourcePatients: Patient[]
): Promise<Patient> {
  // Fields that are safe to update automatically
  const safeFields = ['telecom', 'address'];
  
  // Create a copy of the golden record
  const updatedGoldenRecord = { ...goldenRecord };
  
  // Update safe fields
  for (const field of safeFields) {
    if (field === 'telecom' && updatedPatient.telecom) {
      updatedGoldenRecord.telecom = combineTelecom(allSourcePatients);
    } else if (field === 'address' && updatedPatient.address) {
      updatedGoldenRecord.address = combineAddresses(allSourcePatients);
    }
  }
  
  // Update the golden record
  const result = await client.update<Patient>(updatedGoldenRecord);
  console.log(`Golden record ${result.id} selectively updated`);
  return result;
}
```

## Conclusion

Effective golden record management is essential for maintaining a single source of truth for patient information in healthcare systems. By implementing robust creation, conflict resolution, and update strategies, you can ensure that your golden records provide accurate and comprehensive patient information.

Key takeaways:

1. Create golden records that consolidate information from multiple source systems
2. Implement conflict resolution strategies to handle discrepancies between sources
3. Establish update mechanisms to keep golden records current
4. Consider different approaches based on data sensitivity and reliability
5. Maintain audit trails to track changes to golden records

By following these guidelines, you can create a golden record management system that provides a unified view of patient information across your healthcare organization.
