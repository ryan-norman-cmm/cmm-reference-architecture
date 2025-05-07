# FHIR Interoperability Platform Data Model

## Introduction
This document describes the data model of the FHIR Interoperability Platform, which is based on the HL7 FHIR (Fast Healthcare Interoperability Resources) R4 specification and implemented using Health Samurai's Aidbox. The data model provides a standardized approach to representing healthcare information, ensuring semantic interoperability across the CoverMyMeds ecosystem and with external healthcare partners.

## Data Structures

The FHIR Interoperability Platform organizes healthcare data into discrete resources, each representing a specific healthcare concept. Resources are categorized into different domains based on their function and purpose.

### Core Resource Types

#### Patient-Centric Resources

| Resource Type | Description | Primary Use Cases |
|---------------|-------------|-------------------|
| **Patient** | Demographic information about an individual receiving healthcare services | Patient identification, demographic analysis |
| **Person** | Demographics and administrative information about a person independent of a specific healthcare context | Identity management, linking patient records |
| **RelatedPerson** | Information about a person with a relationship to a patient relevant to healthcare | Caregivers, emergency contacts, guarantors |
| **Practitioner** | Demographics and administrative information about a healthcare provider | Provider directories, order attribution |
| **PractitionerRole** | Roles and organization affiliations of a practitioner | Provider network management, scheduling |
| **Organization** | Details of a formally recognized group with a healthcare purpose | Provider networks, payers, pharmacies |

#### Clinical Resources

| Resource Type | Description | Primary Use Cases |
|---------------|-------------|-------------------|
| **Condition** | Clinical conditions, problems, or diagnoses | Problem lists, diagnosis coding |
| **Observation** | Measurements and simple assertions about a patient | Lab results, vital signs, social determinants |
| **MedicationRequest** | Ordering of medication for a patient | Prescription writing, medication management |
| **MedicationDispense** | Dispensing of medication to a patient | Pharmacy fulfillment, medication tracking |
| **MedicationStatement** | Record of medication being taken by a patient | Medication reconciliation, adherence monitoring |
| **Medication** | Definition of a medication product | Medication catalog, drug information |
| **AllergyIntolerance** | Records of allergies and intolerances | Allergy screening, contraindication alerts |
| **Procedure** | Actions performed on or for a patient | Surgical procedures, interventions |
| **Immunization** | Administration of a vaccine | Immunization records, vaccination history |

#### Administrative Resources

| Resource Type | Description | Primary Use Cases |
|---------------|-------------|-------------------|
| **Encounter** | Healthcare encounter between patient and provider | Visit records, episode management |
| **Coverage** | Insurance or payment information for healthcare services | Benefits verification, claims processing |
| **Claim** | Request for reimbursement for healthcare services | Claims submission, adjudication |
| **ClaimResponse** | Response to a claim for healthcare services | Claim status, payment details |
| **Appointment** | Planned meeting between patient and provider | Scheduling, availability management |
| **Schedule** | Availability of resources for appointments | Provider availability, resource scheduling |
| **Task** | Activity that needs to be performed | Workflow management, action tracking |

#### Workflow Resources

| Resource Type | Description | Primary Use Cases |
|---------------|-------------|-------------------|
| **ServiceRequest** | Order or request for a procedure or diagnostic | Order management, referrals |
| **CarePlan** | Healthcare plan for patient or group | Care coordination, treatment planning |
| **CareTeam** | Group of practitioners and others with a role in patient care | Team-based care, care coordination |
| **Goal** | Desired health state for a patient | Care planning, outcome tracking |

#### Foundation Resources

| Resource Type | Description | Primary Use Cases |
|---------------|-------------|-------------------|
| **Subscription** | Definition of a push-based subscription from server to client | Real-time notifications, event monitoring |
| **OperationOutcome** | Information about the outcome of an operation | Error reporting, validation results |
| **Parameters** | Operation parameters and output | API interaction, complex operations |
| **Bundle** | Container for a collection of resources | Batch processing, transaction handling |
| **Binary** | Uninterpreted content | Document attachments, images |
| **DocumentReference** | Reference to a clinical document | Document management, clinical notes |
| **AuditEvent** | Record of security or privacy relevant events | Security monitoring, access auditing |
| **Provenance** | Record of activities that created or modified resources | Data lineage, attribution |

### CoverMyMeds-Specific Resources

| Resource Type | Description | Primary Use Cases |
|---------------|-------------|-------------------|
| **PriorAuthorization** | Request for prior authorization of a medication or service | PA workflow, coverage determination |
| **PADetermination** | Decision on a prior authorization request | PA status tracking, approval documentation |
| **DrugPrice** | Pricing information for medications | Cost transparency, benefit optimization |
| **PAHUBAttachment** | Document attachments for prior authorization workflows | PA supporting documentation |
| **PAQuestion** | Questions and responses for PA questionnaires | PA form completion, clinical documentation |

## Relationships

FHIR resources are related to each other through references, creating a connected graph of healthcare data. The following diagram illustrates key relationships between commonly used resources:

```
Patient <---- MedicationRequest ---- Medication
   |                |
   |                v
   |          Practitioner
   |                |
   v                v
Encounter <--- Organization
   |
   v
Condition
```

### Common Relationship Types

1. **Hierarchical Relationships**
   - Patient to Encounter (patient has encounters)
   - Organization to Location (organization operates locations)
   - CarePlan to Goal (care plan addresses goals)

2. **Temporal Relationships**
   - MedicationRequest to MedicationDispense (prescription to fulfillment)
   - ServiceRequest to Procedure (order to execution)
   - Appointment to Encounter (scheduled to actual visit)

3. **Contextual Relationships**
   - MedicationRequest to Encounter (medication ordered during visit)
   - Observation to Encounter (observation made during visit)
   - Procedure to Encounter (procedure performed during visit)

4. **Domain-Specific Relationships**
   - Patient to PriorAuthorization (patient needs authorization)
   - MedicationRequest to PriorAuthorization (medication requires authorization)
   - PriorAuthorization to PADetermination (request leads to determination)

## Data Flows

### Resource Creation Flow

1. Client submits a resource via REST/GraphQL API
2. Resource is validated against applicable profiles and business rules
3. Resource is stored in the persistence layer
4. Notifications are generated for subscribers
5. Related resources are updated as needed (e.g., references updated)
6. Response is returned to the client

### Data Integration Flow

1. External system sends healthcare data (e.g., HL7 v2, CDA, CCDA)
2. Data is transformed into FHIR resources
3. Resources are validated and normalized
4. Resources are stored in the FHIR repository
5. References between resources are established
6. Notifications are generated for downstream systems

### Query and Retrieval Flow

1. Client requests resources via API
2. Authentication and authorization checks are performed
3. Search parameters are processed and optimized
4. Query is executed against the repository
5. Results are filtered based on security policies
6. Matching resources are bundled and returned to the client

### Subscription Flow

1. Client creates a Subscription resource specifying interest criteria
2. Platform monitors for relevant resource changes
3. When a matching event occurs, notification is prepared
4. Notification is delivered via specified channel (REST hook, WebSocket, etc.)
5. Delivery confirmation is tracked and retries performed if needed

## Example Schemas

### Patient Resource

```json
{
  "resourceType": "Patient",
  "id": "example-patient",
  "meta": {
    "profile": [
      "http://hl7.org/fhir/us/core/StructureDefinition/us-core-patient"
    ],
    "security": [
      {
        "system": "http://terminology.hl7.org/CodeSystem/v3-ActCode",
        "code": "R",
        "display": "Restricted"
      }
    ]
  },
  "identifier": [
    {
      "use": "official",
      "type": {
        "coding": [
          {
            "system": "http://terminology.hl7.org/CodeSystem/v2-0203",
            "code": "MR",
            "display": "Medical Record Number"
          }
        ],
        "text": "Medical Record Number"
      },
      "system": "http://covermymeds.com/fhir/identifier/mrn",
      "value": "12345678"
    },
    {
      "use": "secondary",
      "type": {
        "coding": [
          {
            "system": "http://terminology.hl7.org/CodeSystem/v2-0203",
            "code": "SS",
            "display": "Social Security Number"
          }
        ],
        "text": "Social Security Number"
      },
      "system": "http://hl7.org/fhir/sid/us-ssn",
      "value": "123-45-6789"
    }
  ],
  "active": true,
  "name": [
    {
      "use": "official",
      "family": "Smith",
      "given": [
        "Jane",
        "Maria"
      ],
      "prefix": [
        "Ms."
      ]
    }
  ],
  "telecom": [
    {
      "system": "phone",
      "value": "(555) 123-4567",
      "use": "home"
    },
    {
      "system": "email",
      "value": "jane.smith@example.com",
      "use": "work"
    }
  ],
  "gender": "female",
  "birthDate": "1980-01-01",
  "address": [
    {
      "use": "home",
      "type": "physical",
      "line": [
        "123 Main St"
      ],
      "city": "Columbus",
      "state": "OH",
      "postalCode": "43201",
      "country": "USA"
    }
  ],
  "communication": [
    {
      "language": {
        "coding": [
          {
            "system": "urn:ietf:bcp:47",
            "code": "en",
            "display": "English"
          }
        ],
        "text": "English"
      },
      "preferred": true
    }
  ],
  "generalPractitioner": [
    {
      "reference": "Practitioner/example-practitioner",
      "display": "Dr. John Doe"
    }
  ],
  "managingOrganization": {
    "reference": "Organization/example-organization",
    "display": "General Hospital"
  }
}
```

### PriorAuthorization Resource (CoverMyMeds Custom Resource)

```json
{
  "resourceType": "PriorAuthorization",
  "id": "example-pa",
  "meta": {
    "profile": [
      "http://covermymeds.com/fhir/StructureDefinition/PriorAuthorization"
    ]
  },
  "identifier": [
    {
      "system": "http://covermymeds.com/fhir/identifier/pa-id",
      "value": "PA12345678"
    }
  ],
  "status": "active",
  "intent": "order",
  "category": {
    "coding": [
      {
        "system": "http://covermymeds.com/fhir/CodeSystem/pa-category",
        "code": "medication",
        "display": "Medication"
      }
    ]
  },
  "priority": "routine",
  "subject": {
    "reference": "Patient/example-patient",
    "display": "Jane Smith"
  },
  "authoredOn": "2023-04-15T15:30:00Z",
  "requester": {
    "reference": "Practitioner/example-practitioner",
    "display": "Dr. John Doe"
  },
  "performer": {
    "reference": "Organization/example-payer",
    "display": "ABC Insurance"
  },
  "insurance": [
    {
      "reference": "Coverage/example-coverage",
      "display": "ABC Insurance Premium Plan"
    }
  ],
  "medication": {
    "reference": "Medication/example-medication",
    "display": "Humira 40 MG/0.8 ML Auto-Injector"
  },
  "medicationRequest": {
    "reference": "MedicationRequest/example-prescription"
  },
  "reasonCode": [
    {
      "coding": [
        {
          "system": "http://snomed.info/sct",
          "code": "195967001",
          "display": "Asthma"
        }
      ]
    }
  ],
  "bodySite": [
    {
      "coding": [
        {
          "system": "http://snomed.info/sct",
          "code": "181268008",
          "display": "Entire abdomen"
        }
      ]
    }
  ],
  "note": [
    {
      "text": "Patient has failed multiple first-line therapies. Requesting approval for Humira."
    }
  ],
  "supportingInfo": [
    {
      "reference": "DocumentReference/example-lab-result",
      "display": "Lab Results"
    },
    {
      "reference": "DocumentReference/example-clinical-note",
      "display": "Clinical Notes"
    }
  ],
  "paStatuses": [
    {
      "status": "submitted",
      "statusDate": "2023-04-15T15:30:00Z"
    },
    {
      "status": "inProgress",
      "statusDate": "2023-04-15T16:45:00Z"
    }
  ]
}
```

### Medication Resource

```json
{
  "resourceType": "Medication",
  "id": "example-medication",
  "meta": {
    "profile": [
      "http://hl7.org/fhir/us/core/StructureDefinition/us-core-medication"
    ]
  },
  "identifier": [
    {
      "system": "http://hl7.org/fhir/sid/ndc",
      "value": "0074-3799-02"
    }
  ],
  "code": {
    "coding": [
      {
        "system": "http://www.nlm.nih.gov/research/umls/rxnorm",
        "code": "1156891",
        "display": "adalimumab 40 MG/0.8 ML [Humira]"
      },
      {
        "system": "http://hl7.org/fhir/sid/ndc",
        "code": "0074-3799-02",
        "display": "HUMIRA PEN 40 MG/0.8 ML"
      }
    ],
    "text": "Humira (adalimumab) 40 MG/0.8 ML Auto-Injector"
  },
  "status": "active",
  "manufacturer": {
    "reference": "Organization/example-manufacturer",
    "display": "AbbVie Inc."
  },
  "form": {
    "coding": [
      {
        "system": "http://snomed.info/sct",
        "code": "385219001",
        "display": "Injection solution"
      }
    ],
    "text": "Injection solution"
  },
  "amount": {
    "numerator": {
      "value": 0.8,
      "unit": "mL",
      "system": "http://unitsofmeasure.org",
      "code": "mL"
    },
    "denominator": {
      "value": 1,
      "unit": "pen",
      "system": "http://terminology.hl7.org/CodeSystem/v3-orderableDrugForm",
      "code": "PEN"
    }
  },
  "ingredient": [
    {
      "itemCodeableConcept": {
        "coding": [
          {
            "system": "http://www.nlm.nih.gov/research/umls/rxnorm",
            "code": "327361",
            "display": "adalimumab"
          }
        ],
        "text": "adalimumab"
      },
      "isActive": true,
      "strength": {
        "numerator": {
          "value": 40,
          "unit": "mg",
          "system": "http://unitsofmeasure.org",
          "code": "mg"
        },
        "denominator": {
          "value": 0.8,
          "unit": "mL",
          "system": "http://unitsofmeasure.org",
          "code": "mL"
        }
      }
    }
  ],
  "batch": {
    "lotNumber": "ABC123",
    "expirationDate": "2024-12-31"
  }
}
```

### MedicationRequest Resource

```json
{
  "resourceType": "MedicationRequest",
  "id": "example-prescription",
  "meta": {
    "profile": [
      "http://hl7.org/fhir/us/core/StructureDefinition/us-core-medicationrequest"
    ]
  },
  "identifier": [
    {
      "system": "http://covermymeds.com/fhir/identifier/prescription",
      "value": "RX12345678"
    }
  ],
  "status": "active",
  "intent": "order",
  "category": [
    {
      "coding": [
        {
          "system": "http://terminology.hl7.org/CodeSystem/medicationrequest-category",
          "code": "outpatient",
          "display": "Outpatient"
        }
      ]
    }
  ],
  "priority": "routine",
  "medicationReference": {
    "reference": "Medication/example-medication",
    "display": "Humira 40 MG/0.8 ML Auto-Injector"
  },
  "subject": {
    "reference": "Patient/example-patient",
    "display": "Jane Smith"
  },
  "encounter": {
    "reference": "Encounter/example-encounter"
  },
  "authoredOn": "2023-04-15T14:20:00Z",
  "requester": {
    "reference": "Practitioner/example-practitioner",
    "display": "Dr. John Doe"
  },
  "recorder": {
    "reference": "PractitionerRole/example-practitioner-role"
  },
  "reasonCode": [
    {
      "coding": [
        {
          "system": "http://snomed.info/sct",
          "code": "195967001",
          "display": "Asthma"
        }
      ]
    }
  ],
  "dosageInstruction": [
    {
      "text": "Inject 40 mg subcutaneously every other week",
      "patientInstruction": "Inject the contents of one pen under your skin every other week.",
      "timing": {
        "repeat": {
          "frequency": 1,
          "period": 2,
          "periodUnit": "wk"
        }
      },
      "route": {
        "coding": [
          {
            "system": "http://snomed.info/sct",
            "code": "34206005",
            "display": "Subcutaneous route"
          }
        ],
        "text": "Subcutaneous"
      },
      "doseAndRate": [
        {
          "type": {
            "coding": [
              {
                "system": "http://terminology.hl7.org/CodeSystem/dose-rate-type",
                "code": "ordered",
                "display": "Ordered"
              }
            ]
          },
          "doseQuantity": {
            "value": 40,
            "unit": "mg",
            "system": "http://unitsofmeasure.org",
            "code": "mg"
          }
        }
      ]
    }
  ],
  "dispenseRequest": {
    "validityPeriod": {
      "start": "2023-04-15",
      "end": "2023-10-15"
    },
    "numberOfRepeatsAllowed": 5,
    "quantity": {
      "value": 2,
      "unit": "pen",
      "system": "http://terminology.hl7.org/CodeSystem/v3-orderableDrugForm",
      "code": "PEN"
    },
    "expectedSupplyDuration": {
      "value": 28,
      "unit": "days",
      "system": "http://unitsofmeasure.org",
      "code": "d"
    },
    "performer": {
      "reference": "Organization/example-pharmacy",
      "display": "Community Pharmacy"
    }
  },
  "substitution": {
    "allowedBoolean": false,
    "reason": {
      "coding": [
        {
          "system": "http://terminology.hl7.org/CodeSystem/v3-ActReason",
          "code": "RR",
          "display": "Regulatory requirement"
        }
      ]
    }
  },
  "priorAuthorization": {
    "reference": "PriorAuthorization/example-pa"
  }
}
```

## Related Resources
- [FHIR Interoperability Platform Core APIs](./core-apis.md)
- [FHIR Interoperability Platform Advanced Use Cases](../03-advanced-patterns/advanced-use-cases.md)
- [FHIR Interoperability Platform Data Governance](../04-governance-compliance/data-governance.md)
- [HL7 FHIR R4 Resources](https://hl7.org/fhir/R4/resourcelist.html)
- [US Core Implementation Guide](https://hl7.org/fhir/us/core/)