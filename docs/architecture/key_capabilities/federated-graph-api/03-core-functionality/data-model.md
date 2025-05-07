# Federated Graph API Data Model

## Introduction
The Federated Graph API data model describes how healthcare data and application resources are represented within the federated GraphQL schema. This document outlines the primary entities, their relationships, and how they are distributed across subgraphs to form a cohesive data model that supports CoverMyMeds' applications.

## Data Structures

### Core Entity Types

| Entity Type | Description | Owning Subgraph |
|-------------|-------------|-----------------|
| `Patient` | Represents a patient in the healthcare system | Patient Subgraph |
| `Practitioner` | Represents healthcare providers | Provider Subgraph |
| `Medication` | Pharmaceutical products prescribed to patients | Medication Subgraph |
| `Prescription` | Medication orders prescribed to patients | Prescription Subgraph |
| `PriorAuthorization` | PA requests for medications requiring approval | PA Subgraph |
| `Appointment` | Scheduled healthcare encounters | Scheduling Subgraph |
| `Organization` | Healthcare organizations (hospitals, clinics, pharmacies) | Organization Subgraph |
| `User` | Platform users and their accounts | User Subgraph |
| `Claim` | Insurance claims for healthcare services | Claims Subgraph |
| `FormularyStatus` | Medication coverage status under insurance plans | Formulary Subgraph |

### Domain-Specific Types

Each subgraph contributes domain-specific types that model its particular area of responsibility:

```graphql
# Example type definitions from the Medication subgraph
type Medication @key(fields: "id") {
  id: ID!
  status: MedicationStatus!
  code: CodeableConcept!
  form: CodeableConcept
  ingredient: [MedicationIngredient!]
  batch: MedicationBatch
  totalDispensed: QuantityValue
  image: String
  manufacturer: Reference
}

type MedicationIngredient {
  item: CodeableReference!
  isActive: Boolean
  strength: Ratio
}

type MedicationBatch {
  lotNumber: String
  expirationDate: DateTime
}

enum MedicationStatus {
  ACTIVE
  INACTIVE
  ENTERED_IN_ERROR
}
```

## Relationships

The federated data model establishes relationships between entities across subgraphs:

### Primary Relationships

| Relationship | Description | Implementation |
|--------------|-------------|----------------|
| Patient → Medications | Medications prescribed to a patient | `Patient.medications` field (reference) |
| Patient → Prescriptions | Prescriptions issued to a patient | `Patient.prescriptions` field (reference) |
| Prescription → Medication | Medication specified in a prescription | `Prescription.medication` field (reference) |
| Prescription → PriorAuthorization | PA request for a prescription | `Prescription.priorAuthorization` field (reference) |
| Patient → Appointments | Appointments scheduled for a patient | `Patient.appointments` field (reference) |
| Practitioner → Appointments | Appointments assigned to a provider | `Practitioner.appointments` field (reference) |
| Prescription → Practitioner | Provider who issued the prescription | `Prescription.prescriber` field (reference) |
| Organization → Practitioners | Providers affiliated with an organization | `Organization.practitioners` field (reference) |

### Entity Resolution

Entities are referenced across subgraph boundaries using the `@key` directive in the schema:

```graphql
# In Patient subgraph
type Patient @key(fields: "id") {
  id: ID!
  name: HumanName!
  birthDate: Date
  gender: Gender
  contact: [ContactPoint!]
  address: [Address!]
  communication: [PatientCommunication!]
  # ... other fields
}

# In Prescription subgraph
type Patient @key(fields: "id") {
  id: ID!
  prescriptions: [Prescription!]!
}

type Prescription @key(fields: "id") {
  id: ID!
  status: PrescriptionStatus!
  patient: Patient! @requires(fields: "patientId")
  patientId: ID!
  medication: Medication! @requires(fields: "medicationId")
  medicationId: ID!
  # ... other fields
}
```

## Data Flows

The Federated Graph API orchestrates several key data flows across subgraphs:

### Patient Record Assembly

When a client queries for a patient's complete record, the Router:

1. Fetches the base patient entity from the Patient subgraph
2. Resolves references to related entities across subgraphs:
   - Medications from the Medication subgraph
   - Prescriptions from the Prescription subgraph
   - Appointments from the Scheduling subgraph
3. Assembles the complete response from all subgraph responses

### Prior Authorization Flow

The PA workflow involves:

1. Client submits prescription data
2. Formulary status is checked in the Formulary subgraph
3. If PA is required, PA subgraph creates a new authorization request
4. Status updates are published via event streams
5. Client can query for PA status updates

### Medication Fulfillment Flow

When a medication is dispensed:

1. Prescription status is updated in the Prescription subgraph
2. Dispensation record is created in the Medication subgraph
3. Claims information is updated in the Claims subgraph
4. Events are published to notify relevant systems
5. Client can query for updated prescription status

## Example Schemas

### Federated Schema (Excerpt)

```graphql
# FHIR-aligned types (base definitions)
type CodeableConcept {
  coding: [Coding!]!
  text: String
}

type Coding {
  system: String!
  version: String
  code: String!
  display: String
  userSelected: Boolean
}

type HumanName {
  use: NameUse
  text: String
  family: String
  given: [String!]
  prefix: [String!]
  suffix: [String!]
}

type Address {
  use: AddressUse
  type: AddressType
  text: String
  line: [String!]
  city: String
  district: String
  state: String
  postalCode: String
  country: String
}

# Core Entity Schema
type Patient @key(fields: "id") {
  id: ID!
  active: Boolean!
  name: [HumanName!]!
  telecom: [ContactPoint!]
  gender: Gender
  birthDate: String
  address: [Address!]
  maritalStatus: CodeableConcept
  contact: [PatientContact!]
  communication: [PatientCommunication!]
  generalPractitioner: [Reference!]
  managingOrganization: Reference
  
  # Extended fields from other subgraphs
  medications: [Medication!]
  prescriptions: [Prescription!]
  priorAuthorizations: [PriorAuthorization!]
  appointments: [Appointment!]
  claims: [Claim!]
  insuranceCoverage: [Coverage!]
}

type Medication @key(fields: "id") {
  id: ID!
  status: MedicationStatus!
  code: CodeableConcept!
  manufacturer: Reference
  form: CodeableConcept
  amount: Ratio
  ingredient: [MedicationIngredient!]
  batch: MedicationBatch
  
  # Extended fields
  formularyStatus(coverageId: ID): FormularyStatus
  alternativeMedications: [Medication!]
  priceInfo: MedicationPriceInfo
}

type Prescription @key(fields: "id") {
  id: ID!
  status: PrescriptionStatus!
  intent: PrescriptionIntent!
  category: [CodeableConcept!]
  medication: Medication!
  subject: Patient!
  authoredOn: DateTime!
  requester: Practitioner
  recorder: Practitioner
  reasonCode: [CodeableConcept!]
  dosageInstruction: [DosageInstruction!]
  dispenseRequest: DispenseRequest
  substitution: Substitution
  priorAuthorization: PriorAuthorization
  
  # Extended fields
  fills: [MedicationDispense!]
  renewalStatus: RenewalStatus
}
```

### Query Example

```graphql
# Query to fetch patient's current medications with PA status
query GetPatientMedications($patientId: ID!) {
  patient(id: $patientId) {
    id
    name {
      given
      family
    }
    prescriptions(status: ACTIVE) {
      id
      medication {
        id
        code {
          coding {
            system
            code
            display
          }
        }
        formularyStatus {
          status
          priorAuthorizationRequired
          restrictions
          alternativesAvailable
        }
      }
      dosageInstruction {
        text
        timing {
          code {
            text
          }
        }
        doseAndRate {
          doseQuantity {
            value
            unit
          }
        }
      }
      priorAuthorization {
        id
        status
        submittedDate
        decisionDate
        expirationDate
        denialReason
      }
    }
  }
}
```

## Related Resources
- [Federated Graph API Core APIs](./core-apis.md)
- [Federated Graph API Key Concepts](../01-getting-started/key-concepts.md)
- [Federation Architecture](../01-getting-started/architecture.md)