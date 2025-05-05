# Saving FHIR Resources

## Introduction

FHIR resources are the standardized data structures that represent healthcare information in a consistent, interoperable format. This guide provides instructions for creating, updating, and managing FHIR resources through the Aidbox FHIR server. It covers both REST API and SDK approaches, with specific focus on TypeScript implementation using the `@aidbox/sdk-r4` package.

### Quick Start

1. Install the Aidbox SDK: `npm install @aidbox/sdk-r4`
2. Configure the client with appropriate authentication
3. Create resources using `client.create<ResourceType>(resource)`
4. Update resources using `client.update<ResourceType>(resource)`
5. Handle errors with try/catch blocks and appropriate error handling

### Related Components

- [FHIR Server Setup Guide](fhir-server-setup-guide.md): Configure your Aidbox FHIR server
- [FHIR Client Authentication](fhir-client-authentication.md): Set up secure access to your FHIR server
- [Extending FHIR Resources](extending-fhir-resources.md): Learn how to customize FHIR resources
- [Data Modeling Decisions](fhir-data-modeling-decisions.md) (Coming Soon): Understand resource modeling choices

## Resource Basics

### Common FHIR Resources in CoverMyMeds Workflows

The CoverMyMeds technology platform primarily uses these FHIR resources for medication access workflows:

| Resource Type | Description | Primary Use in CoverMyMeds |
|---------------|-------------|----------------------------|
| Patient | Demographic information about individuals | Core entity for medication access workflows |
| Practitioner | Healthcare providers, including physicians and pharmacists | Authorizing users for prior authorizations |
| Organization | Healthcare clinics, hospitals, pharmacies, and payers | Organization identity for workflow routing |
| Coverage | Insurance coverage details | Determining patient benefit coverage |
| MedicationRequest | Prescription orders | Basis for prior authorization requests |
| ServiceRequest | Requests for procedures or services | Alternative basis for prior authorization |
| Medication | Medication details | Drug data for prior authorization workflows |
| Task | Actionable work items | Workflow orchestration |
| Questionnaire | Structured forms | Electronic prior authorization forms |
| QuestionnaireResponse | Completed forms | Completed prior authorization submissions |

### Resource Structure

All FHIR resources follow a common structure:

```json
{
  "resourceType": "Patient",
  "id": "example",
  "meta": {
    "versionId": "1",
    "lastUpdated": "2025-05-01T14:30:00Z",
    "profile": ["http://hl7.org/fhir/us/core/StructureDefinition/us-core-patient"]
  },
  "text": {
    "status": "generated",
    "div": "<div xmlns=\"http://www.w3.org/1999/xhtml\">Patient example</div>"
  },
  // Resource-specific data elements
  "name": [
    {
      "family": "Smith",
      "given": ["John", "Edward"]
    }
  ],
  "birthDate": "1970-01-01"
}
```

Key components:
- `resourceType`: Identifies the resource type
- `id`: Unique identifier (assigned by the server if not provided)
- `meta`: Metadata including versioning and profile information
- Resource-specific data elements

## Creating Resources

Resources can be created through the FHIR RESTful API or through the Aidbox SDK.

### Using the REST API

To create a resource using the RESTful API:

```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "resourceType": "Patient",
    "name": [
      {
        "family": "Smith",
        "given": ["John"]
      }
    ],
    "birthDate": "1970-01-01",
    "gender": "male"
  }' \
  http://localhost:8888/fhir/Patient
```

The server will respond with the created resource, including the assigned ID and metadata.

### Using the Aidbox SDK

```typescript
import { AidboxClient } from '@aidbox/sdk-r4';
import { Patient } from '@aidbox/sdk-r4/types';

// Create a client instance
const client = new AidboxClient({
  baseUrl: 'http://localhost:8888',
  auth: {
    type: 'basic',
    username: 'root',
    password: 'secret'
  }
});

// Create a patient
async function createPatient(): Promise<Patient> {
  try {
    const newPatient = await client.create<Patient>({
      resourceType: 'Patient',
      name: [
        {
          family: 'Smith',
          given: ['John']
        }
      ],
      birthDate: '1970-01-01',
      gender: 'male'
    });
    
    console.log('Created patient:', newPatient);
    return newPatient;
  } catch (error) {
    console.error('Error creating patient:', error);
    throw error;
  }
}
```

### Alternative TypeScript Example Using Type Definitions

```typescript
import { AidboxClient } from '@aidbox/sdk-r4';
import { Patient, HumanName, AdministrativeGender } from '@aidbox/sdk-r4/types';

class PatientService {
  private client: AidboxClient;
  
  constructor() {
    this.client = new AidboxClient({
      baseUrl: 'http://localhost:8888',
      auth: {
        type: 'basic',
        username: 'root',
        password: 'secret'
      }
    });
  }
  
  async createPatient(): Promise<Patient> {
    // Create a structured patient with proper typing
    const name: HumanName = {
      family: 'Smith',
      given: ['John']
    };
    
    const patient: Patient = {
      resourceType: 'Patient',
      name: [name],
      birthDate: '1970-01-01',
      gender: AdministrativeGender.MALE
    };
    
    // Create the patient
    return await this.client.create<Patient>(patient);
  }
}
```

## Updating Resources

Updating resources requires knowing the resource ID and can be done using PUT or PATCH operations.

### Using PUT (Full Resource Update)

```bash
curl -X PUT \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "resourceType": "Patient",
    "id": "example",
    "name": [
      {
        "family": "Smith",
        "given": ["John", "Edward"]
      }
    ],
    "birthDate": "1970-01-01",
    "gender": "male",
    "telecom": [
      {
        "system": "phone",
        "value": "555-123-4567",
        "use": "home"
      }
    ]
  }' \
  http://localhost:8888/fhir/Patient/example
```

### Using PATCH (Partial Resource Update)

Aidbox supports JSON Patch for partial updates:

```bash
curl -X PATCH \
  -H "Content-Type: application/json-patch+json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '[
    {
      "op": "add",
      "path": "/telecom/0",
      "value": {
        "system": "phone",
        "value": "555-123-4567",
        "use": "home"
      }
    }
  ]' \
  http://localhost:8888/fhir/Patient/example
```

### Using the Aidbox SDK (JavaScript)

```javascript
// Update a patient
async function updatePatient(id, updates) {
  try {
    // First, get the current patient
    const patient = await client.resource('Patient').get(id);
    
    // Apply updates
    const updatedPatient = { ...patient, ...updates };
    
    // Save the updated patient
    const result = await client.resource('Patient').update(id, updatedPatient);
    
    console.log('Updated patient:', result);
    return result;
  } catch (error) {
    console.error('Error updating patient:', error);
    throw error;
  }
}
```

## Resource Validation

Aidbox validates resources against FHIR profiles when they are created or updated. The CoverMyMeds technology platform environment is configured with the following validation settings:

1. US Core profiles for base resources
2. Da Vinci PAS profiles for prior authorization resources
3. Custom CoverMyMeds profiles for specific workflows

### Pre-Validation

You can validate a resource before saving it using the `$validate` operation:

```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "resourceType": "Patient",
    "name": [
      {
        "family": "Smith",
        "given": ["John"]
      }
    ],
    "birthDate": "1970-01-01",
    "gender": "male"
  }' \
  http://localhost:8888/fhir/Patient/$validate
```

### Using the SDK for Validation

```javascript
async function validatePatient(patientData) {
  try {
    const result = await client.resource('Patient').validate(patientData);
    return result.valid;
  } catch (error) {
    console.error('Validation error:', error);
    return false;
  }
}
```

### Custom Validation Profiles

In the CoverMyMeds environment, we use custom profiles for certain resources. Specify these profiles using the `meta.profile` element:

```json
{
  "resourceType": "MedicationRequest",
  "meta": {
    "profile": ["https://fhir.covermymeds.com/StructureDefinition/cmm-medication-request"]
  },
  // Resource data
}
```

## Batch Operations

Batch operations allow submitting multiple operations in a single request.

### Creating Multiple Resources

```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "resourceType": "Bundle",
    "type": "batch",
    "entry": [
      {
        "request": {
          "method": "POST",
          "url": "Patient"
        },
        "resource": {
          "resourceType": "Patient",
          "name": [
            {
              "family": "Smith",
              "given": ["John"]
            }
          ],
          "birthDate": "1970-01-01"
        }
      },
      {
        "request": {
          "method": "POST",
          "url": "Organization"
        },
        "resource": {
          "resourceType": "Organization",
          "name": "Example Clinic",
          "telecom": [
            {
              "system": "phone",
              "value": "555-123-4567"
            }
          ]
        }
      }
    ]
  }' \
  http://localhost:8888/fhir
```

### Using the SDK for Batch Operations

```typescript
import { AidboxClient } from '@aidbox/sdk-r4';
import { Bundle, Patient, Organization } from '@aidbox/sdk-r4/types';

const client = new AidboxClient({
  baseUrl: 'http://localhost:8888',
  auth: {
    type: 'basic',
    username: 'root',
    password: 'secret'
  }
});

async function createPatientAndOrganization(): Promise<Bundle> {
  try {
    const bundle: Bundle = {
      resourceType: 'Bundle',
      type: 'batch',
      entry: [
        {
          request: {
            method: 'POST',
            url: 'Patient'
          },
          resource: {
            resourceType: 'Patient',
            name: [
              {
                family: 'Smith',
                given: ['John']
              }
            ],
            birthDate: '1970-01-01'
          } as Patient
        },
        {
          request: {
            method: 'POST',
            url: 'Organization'
          },
          resource: {
            resourceType: 'Organization',
            name: 'Example Clinic',
            telecom: [
              {
                system: 'phone',
                value: '555-123-4567'
              }
            ]
          } as Organization
        }
      ]
    };
    
    const result = await client.create<Bundle>(bundle);
    return result;
  } catch (error) {
    console.error('Error with batch operation:', error);
    throw error;
  }
}
```

## Transaction Support

Unlike batches, transactions are atomic - either all operations succeed or all fail.

### Creating Interdependent Resources

```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "resourceType": "Bundle",
    "type": "transaction",
    "entry": [
      {
        "request": {
          "method": "POST",
          "url": "Patient"
        },
        "resource": {
          "resourceType": "Patient",
          "id": "temp-id-1",
          "name": [
            {
              "family": "Smith",
              "given": ["John"]
            }
          ],
          "birthDate": "1970-01-01"
        }
      },
      {
        "request": {
          "method": "POST",
          "url": "MedicationRequest"
        },
        "resource": {
          "resourceType": "MedicationRequest",
          "status": "active",
          "intent": "order",
          "subject": {
            "reference": "Patient/temp-id-1"
          },
          "medicationCodeableConcept": {
            "coding": [
              {
                "system": "http://www.nlm.nih.gov/research/umls/rxnorm",
                "code": "203150",
                "display": "Acetaminophen 325 MG Oral Tablet"
              }
            ]
          }
        }
      }
    ]
  }' \
  http://localhost:8888/fhir
```

In this example, the second resource references the first one using a temporary ID that will be resolved during transaction processing.

## Error Handling

When working with FHIR resources, proper error handling is crucial. Aidbox returns standardized OperationOutcome resources for errors.

### Common Error Codes

| HTTP Code | Description | Common Causes |
|-----------|-------------|---------------|
| 400 | Bad Request | Malformed JSON, invalid resource format |
| 401 | Unauthorized | Missing or invalid credentials |
| 403 | Forbidden | Insufficient permissions |
| 404 | Not Found | Resource ID doesn't exist |
| 409 | Conflict | Version conflict during concurrent updates |
| 422 | Unprocessable Entity | Validation errors in resource content |

### Example Error Response

```json
{
  "resourceType": "OperationOutcome",
  "issue": [
    {
      "severity": "error",
      "code": "invalid",
      "diagnostics": "Invalid value 'invalidGender' for element 'gender'. Expected one of: [male, female, other, unknown]",
      "location": ["Patient.gender"]
    }
  ]
}
```

### Error Handling in TypeScript

```typescript
import { AidboxClient } from '@aidbox/sdk-r4';
import { Patient, OperationOutcome, OperationOutcomeIssue } from '@aidbox/sdk-r4/types';

interface PatientResult {
  success: boolean;
  patient?: Patient;
  error?: string;
}

const client = new AidboxClient({
  baseUrl: 'http://localhost:8888',
  auth: {
    type: 'basic',
    username: 'root',
    password: 'secret'
  }
});

async function safeCreatePatient(patientData: Partial<Patient>): Promise<PatientResult> {
  try {
    const newPatient = await client.create<Patient>(patientData as Patient);
    return { success: true, patient: newPatient };
  } catch (error: any) {
    console.error('Error creating patient:', error);
    
    // Check if the error has an OperationOutcome
    if (error.response?.data?.resourceType === 'OperationOutcome') {
      const outcome = error.response.data as OperationOutcome;
      return {
        success: false,
        error: outcome.issue.map((i: OperationOutcomeIssue) => 
          `${i.severity}: ${i.diagnostics}`).join(', ')
      };
    }
    
    return { success: false, error: error.message };
  }
}
```

## Resource Versioning

Aidbox automatically versions all resources. Each update creates a new version that can be retrieved if needed.

### Accessing Version History

```bash
# Get the version history of a resource
curl -X GET \
  -H "Authorization: Bearer YOUR_TOKEN" \
  http://localhost:8888/fhir/Patient/example/_history
```

### Getting a Specific Version

```bash
# Get a specific version of a resource
curl -X GET \
  -H "Authorization: Bearer YOUR_TOKEN" \
  http://localhost:8888/fhir/Patient/example/_history/2
```

### Version-Aware Updates

To prevent concurrent update conflicts, use version-aware updates with the `If-Match` header:

```bash
curl -X PUT \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "If-Match: W/\"2\"" \
  -d '{
    "resourceType": "Patient",
    "id": "example",
    "meta": {
      "versionId": "2"
    },
    // Updated resource data
  }' \
  http://localhost:8888/fhir/Patient/example
```

## Best Practices

When working with FHIR resources in the CoverMyMeds environment, follow these best practices:

### Resource Creation

1. **Use Appropriate Resource Types**
   - MedicationRequest for prescriptions
   - ServiceRequest for procedures
   - Task for workflow items

2. **Include Required Fields**
   - Follow US Core and Da Vinci implementation guides
   - Include CoverMyMeds-specific extensions when needed

3. **Set Reasonable Data Sizes**
   - Keep resources under 1MB in size
   - Break large data sets into separate resources with references

### Resource References

1. **Use Consistent Reference Formats**
   - Always use `ResourceType/id` format (e.g., `Patient/123`)
   - For internal references in a Bundle, use temporary IDs with UUID format

2. **Check Reference Integrity**
   - Ensure referenced resources exist
   - Use transactions for creating interdependent resources

### Performance Considerations

1. **Batch Operations**
   - Use batch or transaction Bundles for creating multiple related resources
   - Limit batch size to 100 resources per request

2. **Conditional Operations**
   - Use conditional creates/updates to prevent duplicates
   - Example: `PUT /fhir/Patient?identifier=http://example.org/mrn|12345`

3. **Minimal Updates**
   - When updating, only include changed fields when possible
   - Use PATCH for targeted updates

## Code Examples

### Complete Prior Authorization Workflow Example

```typescript
import { AidboxClient } from '@aidbox/sdk-r4';
import {
  Bundle,
  Patient,
  Practitioner,
  MedicationRequest,
  Task,
  Reference,
  HumanName,
  Identifier,
  CodeableConcept,
  Dosage,
  MedicationDispenseRequest,
  TaskStatus,
  TaskIntent
} from '@aidbox/sdk-r4/types';

interface PatientData {
  name: HumanName;
  birthDate: string;
  gender: string;
  identifiers: Identifier[];
}

interface ProviderData {
  name: HumanName;
  identifiers: Identifier[];
}

interface PrescriptionData {
  medication: CodeableConcept;
  dosage: Dosage;
  dispenseRequest: MedicationDispenseRequest;
}

const client = new AidboxClient({
  baseUrl: 'http://localhost:8888',
  auth: {
    type: 'basic',
    username: 'root',
    password: 'secret'
  }
});

async function createPriorAuthorizationRequest(
  patientData: PatientData,
  prescriptionData: PrescriptionData,
  providerData: ProviderData
): Promise<Bundle> {
  try {
    // Create bundle for transaction
    const bundle: Bundle = {
      resourceType: 'Bundle',
      type: 'transaction',
      entry: [
        // Patient resource
        {
          request: {
            method: 'POST',
            url: 'Patient'
          },
          resource: {
            resourceType: 'Patient',
            id: 'temp-patient-id',
            meta: {
              profile: ['http://hl7.org/fhir/us/core/StructureDefinition/us-core-patient']
            },
            name: [patientData.name],
            birthDate: patientData.birthDate,
            gender: patientData.gender,
            identifier: patientData.identifiers
          } as Patient
        },
        // Practitioner resource
        {
          request: {
            method: 'POST',
            url: 'Practitioner'
          },
          resource: {
            resourceType: 'Practitioner',
            id: 'temp-practitioner-id',
            meta: {
              profile: ['http://hl7.org/fhir/us/core/StructureDefinition/us-core-practitioner']
            },
            name: [providerData.name],
            identifier: providerData.identifiers
          } as Practitioner
        },
        // MedicationRequest resource
        {
          request: {
            method: 'POST',
            url: 'MedicationRequest'
          },
          resource: {
            resourceType: 'MedicationRequest',
            id: 'temp-med-request-id',
            meta: {
              profile: ['http://hl7.org/fhir/us/core/StructureDefinition/us-core-medicationrequest']
            },
            status: 'active',
            intent: 'order',
            subject: {
              reference: 'Patient/temp-patient-id'
            } as Reference,
            requester: {
              reference: 'Practitioner/temp-practitioner-id'
            } as Reference,
            medicationCodeableConcept: prescriptionData.medication,
            dosageInstruction: [prescriptionData.dosage],
            dispenseRequest: prescriptionData.dispenseRequest
          } as MedicationRequest
        },
        // Task resource for prior authorization
        {
          request: {
            method: 'POST',
            url: 'Task'
          },
          resource: {
            resourceType: 'Task',
            meta: {
              profile: ['http://hl7.org/fhir/us/davinci-pas/StructureDefinition/task-pas']
            },
            status: TaskStatus.REQUESTED,
            intent: TaskIntent.ORDER,
            code: {
              coding: [
                {
                  system: 'http://hl7.org/fhir/us/davinci-pas/CodeSystem/task-code',
                  code: 'prior-authorization',
                  display: 'Prior Authorization'
                }
              ]
            },
            focus: {
              reference: 'MedicationRequest/temp-med-request-id'
            } as Reference,
            for: {
              reference: 'Patient/temp-patient-id'
            } as Reference,
            requester: {
              reference: 'Practitioner/temp-practitioner-id'
            } as Reference
          } as Task
        }
      ]
    };
    
    // Submit transaction
    const result = await client.create<Bundle>(bundle);
    return result;
  } catch (error) {
    console.error('Error creating prior authorization request:', error);
    throw error;
  }
}
```

### Updating a Task Status

```typescript
import { AidboxClient } from '@aidbox/sdk-r4';
import { Task, Extension, TaskStatus, CodeableConcept } from '@aidbox/sdk-r4/types';

const client = new AidboxClient({
  baseUrl: 'http://localhost:8888',
  auth: {
    type: 'basic',
    username: 'root',
    password: 'secret'
  }
});

async function updateTaskStatus(
  taskId: string, 
  newStatus: TaskStatus, 
  statusReason?: string
): Promise<Task> {
  try {
    // Get the current task
    const task = await client.getById<Task>('Task', taskId);
    
    // Store previous status for audit
    const previousStatus = task.status;
    
    // Update status
    task.status = newStatus;
    
    // Add status reason if provided
    if (statusReason) {
      task.statusReason = {
        text: statusReason
      } as CodeableConcept;
    }
    
    // Add audit extension
    const now = new Date().toISOString();
    if (!task.extension) {
      task.extension = [];
    }
    
    const auditExtension: Extension = {
      url: 'https://fhir.covermymeds.com/StructureDefinition/status-update-audit',
      extension: [
        {
          url: 'timestamp',
          valueDateTime: now
        },
        {
          url: 'user',
          valueString: 'current-user-id'
        },
        {
          url: 'previousStatus',
          valueCode: previousStatus
        }
      ]
    };
    
    task.extension.push(auditExtension);
    
    // Update the task
    const updatedTask = await client.update<Task>(task);
    return updatedTask;
  } catch (error) {
    console.error('Error updating task status:', error);
    throw error;
  }
}
```

### Resource Search and Update

```typescript
import { AidboxClient } from '@aidbox/sdk-r4';
import { 
  Task, 
  Bundle, 
  BundleEntry,
  Observation, 
  Reference, 
  CodeableConcept, 
  Coding,
  Annotation,
  ObservationStatus,
  TaskStatus
} from '@aidbox/sdk-r4/types';

class PriorAuthService {
  private client: AidboxClient;
  
  constructor() {
    this.client = new AidboxClient({
      baseUrl: 'http://localhost:8888',
      auth: {
        type: 'basic',
        username: 'root',
        password: 'secret'
      }
    });
  }
  
  async findPendingTasks(): Promise<Task[]> {
    try {
      // Search for pending prior authorization tasks
      const results = await this.client.search<Task>('Task', {
        status: 'requested',
        code: 'http://hl7.org/fhir/us/davinci-pas/CodeSystem/task-code|prior-authorization'
      });
      
      return results;
    } catch (error) {
      console.error('Error finding pending tasks:', error);
      throw error;
    }
  }
  
  async approveTask(task: Task, comment?: string): Promise<Task> {
    try {
      // Update task to approved status
      task.status = TaskStatus.COMPLETED;
      
      // Create outcome observation
      const observation = await this.createOutcomeObservation(task, 'approved', comment);
      
      // Add outcome observation reference to task
      if (!task.output) {
        task.output = [];
      }
      
      const outcomeReference: Reference = {
        reference: `Observation/${observation.id}`
      };
      
      task.output.push({
        type: {
          coding: [{
            system: 'http://hl7.org/fhir/us/davinci-pas/CodeSystem/task-output',
            code: 'outcome',
            display: 'Prior Authorization Outcome'
          }]
        },
        valueReference: outcomeReference
      });
      
      // Save the updated task
      return await this.client.update<Task>(task);
    } catch (error) {
      console.error('Error approving task:', error);
      throw error;
    }
  }
  
  private async createOutcomeObservation(task: Task, outcome: string, comment?: string): Promise<Observation> {
    try {
      // Create the outcome coding
      const outcomeCoding: Coding = {
        system: 'http://hl7.org/fhir/us/davinci-pas/CodeSystem/task-outcome',
        code: outcome,
        display: outcome.charAt(0).toUpperCase() + outcome.slice(1)
      };
      
      // Create the observation
      const observation: Observation = {
        resourceType: 'Observation',
        status: ObservationStatus.FINAL,
        code: {
          coding: [outcomeCoding]
        },
        focus: [{
          reference: `Task/${task.id}`
        }]
      };
      
      // Add comment if provided
      if (comment) {
        observation.note = [{
          text: comment
        }];
      }
      
      // Save the observation
      return await this.client.create<Observation>(observation);
    } catch (error) {
      console.error('Error creating outcome observation:', error);
      throw error;
    }
  }
}
```
