# FHIR Standards Tutorial

## Introduction

FHIR (Fast Healthcare Interoperability Resources) provides a standardized approach to healthcare data exchange that combines the best features of previous standards with modern web technologies. This tutorial explains the fundamental concepts of FHIR, including resource types and relationships, implementation guide basics, standard extensions, and RESTful API patterns. Understanding these core concepts provides the foundation for effective FHIR implementation in healthcare applications.

### Quick Start

1. Learn about FHIR resource types and their relationships
2. Understand how implementation guides standardize FHIR usage
3. Explore standard extensions for extending FHIR resources
4. Master RESTful API patterns for interacting with FHIR servers
5. Practice with working code examples using TypeScript

### Related Components

- [FHIR Benefits Overview](fhir-benefits-overview.md): Understand the advantages of FHIR
- [FHIR Server Setup Guide](fhir-server-setup-guide.md): Configure your FHIR environment
- [Accessing FHIR Resources](accessing-fhir-resources.md): Learn how to retrieve resources
- [Saving FHIR Resources](saving-fhir-resources.md): Learn how to create and update resources

## Resource Types and Relationships

FHIR defines a set of standardized resources that represent healthcare concepts, with well-defined relationships between them.

### Core Resource Types

FHIR resources are the building blocks of healthcare data exchange, each representing a specific healthcare concept.

| Resource Category | Examples | Purpose |
|-------------------|----------|----------|
| Clinical | Patient, Condition, Observation | Core clinical data |
| Administrative | Encounter, Appointment, Organization | Administrative information |
| Financial | Claim, Coverage, Account | Billing and financial data |
| Workflow | Task, ServiceRequest, CarePlan | Clinical and administrative processes |
| Conformance | StructureDefinition, ValueSet | Define how resources are used |

### Resource Structure

All FHIR resources share a common structure that includes metadata, a human-readable narrative, and resource-specific data elements.

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
 * Creates a patient resource demonstrating the common FHIR resource structure
 * @returns The created Patient resource
 */
async function createPatientResource(): Promise<Patient> {
  try {
    const patient: Partial<Patient> = {
      // Resource type - always required
      resourceType: 'Patient',
      
      // Metadata - common across all resources
      meta: {
        // Profile that this resource claims to conform to
        profile: ['http://hl7.org/fhir/us/core/StructureDefinition/us-core-patient'],
        // Tags for various purposes
        tag: [
          {
            system: 'http://example.org/fhir/tags',
            code: 'test-patient',
            display: 'Test Patient'
          }
        ]
      },
      
      // Human-readable narrative
      text: {
        status: 'generated',
        div: '<div xmlns="http://www.w3.org/1999/xhtml">John Smith, Male, DOB: 1970-01-01</div>'
      },
      
      // Resource-specific data elements
      identifier: [
        {
          system: 'http://example.org/fhir/identifier/mrn',
          value: 'MRN12345'
        }
      ],
      active: true,
      name: [
        {
          use: 'official',
          family: 'Smith',
          given: ['John', 'Jacob']
        }
      ],
      gender: 'male',
      birthDate: '1970-01-01',
      address: [
        {
          use: 'home',
          line: ['123 Main St'],
          city: 'Anytown',
          state: 'CA',
          postalCode: '12345',
          country: 'USA'
        }
      ],
      telecom: [
        {
          system: 'phone',
          value: '555-555-5555',
          use: 'home'
        },
        {
          system: 'email',
          value: 'john.smith@example.com'
        }
      ]
    };
    
    const result = await client.create<Patient>(patient);
    console.log(`Patient created with ID: ${result.id}`);
    return result;
  } catch (error) {
    console.error('Error creating patient resource:', error);
    throw error;
  }
}
```

### Resource References

FHIR resources are connected through references, creating a web of relationships that represent the complex nature of healthcare data.

```typescript
import { Observation, Practitioner } from '@aidbox/sdk-r4/types';

/**
 * Creates an observation with references to other resources
 * @param patientId The ID of the patient
 * @param practitionerId The ID of the practitioner
 * @param encounterId The ID of the encounter
 * @returns The created Observation resource
 */
async function createObservationWithReferences(
  patientId: string,
  practitionerId: string,
  encounterId: string
): Promise<Observation> {
  try {
    const observation: Partial<Observation> = {
      resourceType: 'Observation',
      status: 'final',
      code: {
        coding: [
          {
            system: 'http://loinc.org',
            code: '8867-4',
            display: 'Heart rate'
          }
        ],
        text: 'Heart rate'
      },
      // Reference to the patient
      subject: {
        reference: `Patient/${patientId}`,
        display: 'John Smith'
      },
      // Reference to the encounter
      encounter: {
        reference: `Encounter/${encounterId}`
      },
      effectiveDateTime: new Date().toISOString(),
      issued: new Date().toISOString(),
      // Reference to the practitioner
      performer: [
        {
          reference: `Practitioner/${practitionerId}`,
          display: 'Dr. Jane Doe'
        }
      ],
      valueQuantity: {
        value: 80,
        unit: 'beats/minute',
        system: 'http://unitsofmeasure.org',
        code: '/min'
      }
    };
    
    const result = await client.create<Observation>(observation);
    console.log(`Observation created with ID: ${result.id}`);
    return result;
  } catch (error) {
    console.error('Error creating observation with references:', error);
    throw error;
  }
}

/**
 * Resolves a reference to retrieve the referenced resource
 * @param reference The reference string (e.g., 'Patient/123')
 * @returns The referenced resource
 */
async function resolveReference<T>(reference: string): Promise<T> {
  try {
    // Split the reference into resource type and ID
    const [resourceType, id] = reference.split('/');
    
    if (!resourceType || !id) {
      throw new Error(`Invalid reference format: ${reference}`);
    }
    
    // Retrieve the referenced resource
    const resource = await client.read<T>({
      resourceType,
      id
    });
    
    return resource;
  } catch (error) {
    console.error(`Error resolving reference ${reference}:`, error);
    throw error;
  }
}
```

### Resource Containment

FHIR supports resource containment, allowing one resource to contain another as an embedded resource.

```typescript
import { MedicationRequest } from '@aidbox/sdk-r4/types';

/**
 * Creates a medication request with a contained medication
 * @param patientId The ID of the patient
 * @param practitionerId The ID of the practitioner
 * @returns The created MedicationRequest resource
 */
async function createMedicationRequestWithContainedMedication(
  patientId: string,
  practitionerId: string
): Promise<MedicationRequest> {
  try {
    const medicationRequest: Partial<MedicationRequest> = {
      resourceType: 'MedicationRequest',
      status: 'active',
      intent: 'order',
      // Contained medication resource
      contained: [
        {
          resourceType: 'Medication',
          id: 'med1', // Local ID for reference within this resource
          code: {
            coding: [
              {
                system: 'http://www.nlm.nih.gov/research/umls/rxnorm',
                code: '1049502',
                display: 'Acetaminophen 325 MG Oral Tablet'
              }
            ],
            text: 'Acetaminophen 325 MG Oral Tablet'
          },
          form: {
            coding: [
              {
                system: 'http://snomed.info/sct',
                code: '385055001',
                display: 'Tablet'
              }
            ],
            text: 'Tablet'
          }
        }
      ],
      // Reference to the contained medication
      medicationReference: {
        reference: '#med1'
      },
      subject: {
        reference: `Patient/${patientId}`
      },
      requester: {
        reference: `Practitioner/${practitionerId}`
      },
      dosageInstruction: [
        {
          text: 'Take 1-2 tablets every 4-6 hours as needed for pain',
          timing: {
            repeat: {
              frequency: 1,
              period: 4,
              periodUnit: 'h'
            }
          },
          doseAndRate: [
            {
              doseRange: {
                low: {
                  value: 1,
                  unit: 'tablet',
                  system: 'http://unitsofmeasure.org',
                  code: 'TAB'
                },
                high: {
                  value: 2,
                  unit: 'tablet',
                  system: 'http://unitsofmeasure.org',
                  code: 'TAB'
                }
              }
            }
          ]
        }
      ]
    };
    
    const result = await client.create<MedicationRequest>(medicationRequest);
    console.log(`MedicationRequest created with ID: ${result.id}`);
    return result;
  } catch (error) {
    console.error('Error creating medication request with contained medication:', error);
    throw error;
  }
}
```

## Implementation Guide Basics

Implementation guides (IGs) provide specific guidance on how to use FHIR for particular use cases or domains.

### Understanding Implementation Guides

Implementation guides define profiles, extensions, value sets, and other artifacts that constrain and extend FHIR for specific use cases.

| Component | Purpose | Example |
|-----------|---------|----------|
| Profiles | Constrain resources for specific use cases | US Core Patient Profile |
| Extensions | Define additional data elements | Birth sex extension |
| Value Sets | Define coded values for specific elements | Medication request status codes |
| Operations | Define additional interactions | $everything operation |

### Common Implementation Guides

```typescript
import { Patient } from '@aidbox/sdk-r4/types';

/**
 * Creates a patient conforming to the US Core Implementation Guide
 * @param patientData Basic patient data
 * @returns The created US Core Patient resource
 */
async function createUSCorePatient(
  patientData: {
    familyName: string;
    givenNames: string[];
    gender: 'male' | 'female' | 'other' | 'unknown';
    birthDate: string;
  }
): Promise<Patient> {
  try {
    const patient: Partial<Patient> = {
      resourceType: 'Patient',
      meta: {
        profile: ['http://hl7.org/fhir/us/core/StructureDefinition/us-core-patient']
      },
      name: [
        {
          family: patientData.familyName,
          given: patientData.givenNames
        }
      ],
      gender: patientData.gender,
      birthDate: patientData.birthDate,
      // US Core required extension for race
      extension: [
        {
          url: 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-race',
          extension: [
            {
              url: 'ombCategory',
              valueCoding: {
                system: 'urn:oid:2.16.840.1.113883.6.238',
                code: '2106-3',
                display: 'White'
              }
            },
            {
              url: 'text',
              valueString: 'White'
            }
          ]
        },
        // US Core required extension for ethnicity
        {
          url: 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-ethnicity',
          extension: [
            {
              url: 'ombCategory',
              valueCoding: {
                system: 'urn:oid:2.16.840.1.113883.6.238',
                code: '2186-5',
                display: 'Not Hispanic or Latino'
              }
            },
            {
              url: 'text',
              valueString: 'Not Hispanic or Latino'
            }
          ]
        },
        // US Core optional extension for birth sex
        {
          url: 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-birthsex',
          valueCode: patientData.gender === 'male' ? 'M' : (patientData.gender === 'female' ? 'F' : 'UNK')
        }
      ]
    };
    
    const result = await client.create<Patient>(patient);
    console.log(`US Core Patient created with ID: ${result.id}`);
    return result;
  } catch (error) {
    console.error('Error creating US Core Patient:', error);
    throw error;
  }
}
```

### Validating Against Implementation Guides

```typescript
/**
 * Validates a resource against an implementation guide profile
 * @param resource The resource to validate
 * @param profile The profile URL to validate against
 * @returns Validation results
 */
async function validateResourceAgainstProfile(
  resource: any,
  profile: string
): Promise<any> {
  try {
    // Add the profile to the resource's meta.profile if not already present
    if (!resource.meta) {
      resource.meta = {};
    }
    
    if (!resource.meta.profile) {
      resource.meta.profile = [];
    }
    
    if (!resource.meta.profile.includes(profile)) {
      resource.meta.profile.push(profile);
    }
    
    // Perform validation using the $validate operation
    const validationResult = await client.request({
      method: 'POST',
      url: `/${resource.resourceType}/$validate`,
      data: resource
    });
    
    return validationResult.data;
  } catch (error) {
    console.error(`Error validating resource against profile ${profile}:`, error);
    throw error;
  }
}
```

## Standard Extensions

FHIR provides standard extensions for common use cases that aren't covered by the base resources.

### Using Standard Extensions

```typescript
import { Patient } from '@aidbox/sdk-r4/types';

/**
 * Adds standard extensions to a patient resource
 * @param patientId The ID of the patient to update
 * @returns The updated Patient resource
 */
async function addStandardExtensionsToPatient(patientId: string): Promise<Patient> {
  try {
    // Get the current patient
    const patient = await client.read<Patient>({
      resourceType: 'Patient',
      id: patientId
    });
    
    // Initialize extensions array if it doesn't exist
    if (!patient.extension) {
      patient.extension = [];
    }
    
    // Add standard extensions
    
    // Birth place extension
    patient.extension.push({
      url: 'http://hl7.org/fhir/StructureDefinition/patient-birthPlace',
      valueAddress: {
        city: 'San Francisco',
        state: 'CA',
        country: 'USA'
      }
    });
    
    // Mother's maiden name extension
    patient.extension.push({
      url: 'http://hl7.org/fhir/StructureDefinition/patient-mothersMaidenName',
      valueString: 'Johnson'
    });
    
    // Religion extension
    patient.extension.push({
      url: 'http://hl7.org/fhir/StructureDefinition/patient-religion',
      valueCodeableConcept: {
        coding: [
          {
            system: 'http://terminology.hl7.org/CodeSystem/v3-ReligiousAffiliation',
            code: '1013',
            display: 'Christian'
          }
        ],
        text: 'Christian'
      }
    });
    
    // Update the patient
    const result = await client.update<Patient>(patient);
    console.log(`Patient ${patientId} updated with standard extensions`);
    return result;
  } catch (error) {
    console.error(`Error adding standard extensions to patient ${patientId}:`, error);
    throw error;
  }
}
```

### Common Standard Extensions

| Extension | Purpose | Resource Types |
|-----------|---------|----------------|
| patient-birthPlace | Birth location | Patient |
| patient-mothersMaidenName | Mother's maiden name | Patient |
| patient-religion | Religious affiliation | Patient |
| humanname-own-prefix | Name prefix | HumanName |
| humanname-own-name | Person's name | HumanName |
| iso21090-uncertainty | Uncertainty in a value | Many |

## RESTful API Patterns

FHIR defines a RESTful API for interacting with resources, following standard HTTP methods and patterns.

### CRUD Operations

FHIR supports standard CRUD (Create, Read, Update, Delete) operations on resources.

```typescript
import { Patient } from '@aidbox/sdk-r4/types';

/**
 * Demonstrates CRUD operations on a Patient resource
 */
async function demonstrateCRUDOperations(): Promise<void> {
  try {
    // CREATE - Create a new patient
    const newPatient: Partial<Patient> = {
      resourceType: 'Patient',
      name: [
        {
          family: 'Doe',
          given: ['Jane']
        }
      ],
      gender: 'female',
      birthDate: '1980-01-01'
    };
    
    const createdPatient = await client.create<Patient>(newPatient);
    console.log(`Patient created with ID: ${createdPatient.id}`);
    
    // READ - Retrieve the patient by ID
    const retrievedPatient = await client.read<Patient>({
      resourceType: 'Patient',
      id: createdPatient.id as string
    });
    console.log(`Retrieved patient: ${retrievedPatient.name?.[0]?.family}, ${retrievedPatient.name?.[0]?.given?.[0]}`);
    
    // UPDATE - Update the patient
    retrievedPatient.telecom = [
      {
        system: 'phone',
        value: '555-555-5555',
        use: 'home'
      }
    ];
    
    const updatedPatient = await client.update<Patient>(retrievedPatient);
    console.log(`Patient updated with telecom: ${updatedPatient.telecom?.[0]?.value}`);
    
    // DELETE - Delete the patient
    await client.delete({
      resourceType: 'Patient',
      id: createdPatient.id as string
    });
    console.log(`Patient ${createdPatient.id} deleted`);
  } catch (error) {
    console.error('Error demonstrating CRUD operations:', error);
    throw error;
  }
}
```

### Search Operations

FHIR provides powerful search capabilities for finding resources based on various criteria.

```typescript
import { Bundle, Patient } from '@aidbox/sdk-r4/types';

/**
 * Demonstrates various search operations on Patient resources
 */
async function demonstrateSearchOperations(): Promise<void> {
  try {
    // Simple search by name
    const patientsByName = await client.search<Patient>({
      resourceType: 'Patient',
      params: {
        'name': 'Smith'
      }
    });
    console.log(`Found ${patientsByName.entry?.length || 0} patients with name Smith`);
    
    // Search with multiple parameters
    const patientsByNameAndGender = await client.search<Patient>({
      resourceType: 'Patient',
      params: {
        'name': 'Smith',
        'gender': 'male'
      }
    });
    console.log(`Found ${patientsByNameAndGender.entry?.length || 0} male patients with name Smith`);
    
    // Search with date range
    const patientsByBirthDate = await client.search<Patient>({
      resourceType: 'Patient',
      params: {
        'birthdate': 'ge1970-01-01',
        'birthdate': 'lt1980-01-01'
      }
    });
    console.log(`Found ${patientsByBirthDate.entry?.length || 0} patients born in the 1970s`);
    
    // Search with _include to include referenced resources
    const patientsWithPractitioner = await client.search<Patient>({
      resourceType: 'Patient',
      params: {
        '_include': 'Patient:general-practitioner'
      }
    });
    console.log(`Found ${patientsWithPractitioner.entry?.length || 0} resources (patients and their practitioners)`);
    
    // Search with _revinclude to include resources that reference the matched resources
    const patientsWithObservations = await client.search<Patient>({
      resourceType: 'Patient',
      params: {
        '_revinclude': 'Observation:subject'
      }
    });
    console.log(`Found ${patientsWithObservations.entry?.length || 0} resources (patients and observations about them)`);
    
    // Chained search - find patients with a specific condition
    const patientsWithDiabetes = await client.search<Patient>({
      resourceType: 'Patient',
      params: {
        '_has:Condition:patient:code': 'http://snomed.info/sct|44054006'
      }
    });
    console.log(`Found ${patientsWithDiabetes.entry?.length || 0} patients with diabetes`);
  } catch (error) {
    console.error('Error demonstrating search operations:', error);
    throw error;
  }
}
```

### Transaction Operations

FHIR supports transactions for executing multiple operations atomically.

```typescript
import { Bundle } from '@aidbox/sdk-r4/types';

/**
 * Demonstrates a transaction operation to create multiple resources atomically
 */
async function demonstrateTransactionOperation(): Promise<Bundle> {
  try {
    // Create a transaction bundle
    const transactionBundle: Partial<Bundle> = {
      resourceType: 'Bundle',
      type: 'transaction',
      entry: [
        // Create a patient
        {
          resource: {
            resourceType: 'Patient',
            name: [
              {
                family: 'Transaction',
                given: ['Test']
              }
            ],
            gender: 'male',
            birthDate: '1990-01-01'
          },
          request: {
            method: 'POST',
            url: 'Patient'
          }
        },
        // Create a condition for the patient
        // Note: We'll use the reference Patient/{{Patient-id}} which will be replaced
        // with the actual ID of the patient created in the first entry
        {
          resource: {
            resourceType: 'Condition',
            subject: {
              reference: 'Patient/{{Patient-id}}'
            },
            code: {
              coding: [
                {
                  system: 'http://snomed.info/sct',
                  code: '44054006',
                  display: 'Diabetes mellitus type 2'
                }
              ],
              text: 'Type 2 Diabetes'
            },
            clinicalStatus: {
              coding: [
                {
                  system: 'http://terminology.hl7.org/CodeSystem/condition-clinical',
                  code: 'active',
                  display: 'Active'
                }
              ]
            },
            verificationStatus: {
              coding: [
                {
                  system: 'http://terminology.hl7.org/CodeSystem/condition-ver-status',
                  code: 'confirmed',
                  display: 'Confirmed'
                }
              ]
            },
            onsetDateTime: '2020-01-01'
          },
          request: {
            method: 'POST',
            url: 'Condition'
          }
        },
        // Create an observation for the patient
        {
          resource: {
            resourceType: 'Observation',
            status: 'final',
            code: {
              coding: [
                {
                  system: 'http://loinc.org',
                  code: '8867-4',
                  display: 'Heart rate'
                }
              ],
              text: 'Heart rate'
            },
            subject: {
              reference: 'Patient/{{Patient-id}}'
            },
            effectiveDateTime: new Date().toISOString(),
            valueQuantity: {
              value: 80,
              unit: 'beats/minute',
              system: 'http://unitsofmeasure.org',
              code: '/min'
            }
          },
          request: {
            method: 'POST',
            url: 'Observation'
          }
        }
      ]
    };
    
    // Execute the transaction
    const result = await client.request({
      method: 'POST',
      url: '/',
      data: transactionBundle
    });
    
    console.log('Transaction completed successfully');
    return result.data as Bundle;
  } catch (error) {
    console.error('Error demonstrating transaction operation:', error);
    throw error;
  }
}
```

### Operations

FHIR defines special operations that go beyond the basic CRUD operations.

```typescript
/**
 * Demonstrates the $everything operation to get all resources for a patient
 * @param patientId The ID of the patient
 * @returns Bundle containing all resources for the patient
 */
async function demonstrateEverythingOperation(patientId: string): Promise<Bundle> {
  try {
    // Execute the $everything operation
    const result = await client.request({
      method: 'GET',
      url: `/Patient/${patientId}/$everything`
    });
    
    const bundle = result.data as Bundle;
    console.log(`$everything operation returned ${bundle.entry?.length || 0} resources for patient ${patientId}`);
    return bundle;
  } catch (error) {
    console.error(`Error demonstrating $everything operation for patient ${patientId}:`, error);
    throw error;
  }
}

/**
 * Demonstrates the $validate operation to validate a resource
 * @param resource The resource to validate
 * @returns Validation results
 */
async function demonstrateValidateOperation(resource: any): Promise<any> {
  try {
    // Execute the $validate operation
    const result = await client.request({
      method: 'POST',
      url: `/${resource.resourceType}/$validate`,
      data: resource
    });
    
    console.log(`$validate operation completed for ${resource.resourceType}`);
    return result.data;
  } catch (error) {
    console.error(`Error demonstrating $validate operation for ${resource.resourceType}:`, error);
    throw error;
  }
}
```

## Conclusion

FHIR provides a comprehensive framework for healthcare data exchange that combines the best features of previous standards with modern web technologies. By understanding resource types and relationships, implementation guides, standard extensions, and RESTful API patterns, developers can effectively implement FHIR in healthcare applications.

Key takeaways:

1. FHIR resources are the building blocks of healthcare data exchange, with well-defined relationships between them
2. Implementation guides provide specific guidance on how to use FHIR for particular use cases or domains
3. Standard extensions allow for extending FHIR resources in a consistent way
4. RESTful API patterns provide a standardized approach to interacting with FHIR servers

By mastering these core concepts, developers can leverage FHIR to build interoperable healthcare applications that improve data exchange and ultimately enhance patient care.
