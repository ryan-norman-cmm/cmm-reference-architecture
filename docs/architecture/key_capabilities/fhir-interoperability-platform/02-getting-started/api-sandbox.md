# FHIR Interoperability Platform API Sandbox

## Introduction

The **FHIR Interoperability Platform** API Sandbox provides an interactive environment for exploring and testing FHIR APIs without writing code. This document guides you through accessing the sandbox environment, authenticating, and using the interactive tools to experiment with the FHIR capabilities.

## Sandbox Environment

The sandbox environment is a fully functional replica of the production environment with the following key differences:

- No real patient data (synthetic test data only)
- Lower rate limits and resource quotas
- Isolated from production systems
- Immediate provisioning (no approval process)
- Reset daily to a clean state
- Includes pre-populated healthcare data sets for common scenarios:
  - Primary care patients with chronic conditions
  - Hospital encounters with observations and procedures
  - Medication workflows with prescriptions and dispensing
  - Insurance coverage and claims data

## Accessing the Sandbox

### Authentication

The sandbox uses simplified authentication compared to production:

1. Navigate to the sandbox portal: `https://fhir-sandbox.dev.cmm.azure.com`
2. Log in using your CMM Azure AD credentials
3. The system will automatically provision a sandbox account and API keys

**Sandbox API Key Example:**
```
x-cmm-sandbox-api-key: sb_fhir_platform_00000000000000000000000000000000
```

For SMART on FHIR application testing, the sandbox also supports:

- Client credentials flow for backend services
- Authorization code flow for patient-facing apps
- Launch context simulation (patient, encounter, practitioner)

**SMART Registration Example:**
```json
{
  "client_id": "sandbox_app_123",
  "client_name": "Sandbox Test App",
  "redirect_uris": ["https://localhost:3000/callback"],
  "token_endpoint_auth_method": "client_secret_basic",
  "scope": "launch/patient patient/*.read",
  "grant_types": ["authorization_code"]
}
```

### Sandbox Limitations

| Resource | Sandbox Limit | Production Limit |
|----------|---------------|------------------|
| Requests per minute | 60 | 1,000 |
| Concurrent connections | 5 | 50 |
| Maximum payload size | 1 MB | 10 MB |
| Storage allocation | 100 MB | Unlimited |
| Session duration | 24 hours | Unlimited |
| FHIR resource count | 10,000 | Unlimited |
| Subscription notifications | Email only | Multiple channels |
| SMART apps | 5 | Unlimited |

## Interactive API Explorer

The sandbox includes an interactive API explorer based on Swagger UI:

1. Navigate to `https://fhir-sandbox.dev.cmm.azure.com/explorer`
2. Your sandbox API key is automatically included in requests
3. Explore available FHIR resources organized by category
4. Try operations directly from the browser UI

### Using the Explorer

![API Explorer Interface](https://placehold.co/600x400?text=FHIR+API+Explorer+Screenshot)

1. **Browse Resources**: Expand resource categories in the left navigation
2. **Set Parameters**: Fill in required and optional parameters
3. **Execute Requests**: Click "Try it out" and then "Execute"
4. **View Results**: See complete request/response details
5. **Copy as cURL**: Generate cURL commands for any request

The Explorer also provides access to:
- FHIR REST API operations (Create, Read, Update, Delete, Search)
- FHIR operations (e.g., $validate, $everything, $expand)
- GraphQL endpoint for complex queries
- SMART on FHIR app testing tools

### Sample Requests

The API explorer includes sample requests for common healthcare operations:

#### Example 1: Patient Search

```http
GET /fhir/Patient?family=Smith&birthdate=gt1970-01-01&_sort=birthdate
Accept: application/fhir+json
```

Response (partial):
```json
{
  "resourceType": "Bundle",
  "type": "searchset",
  "total": 3,
  "entry": [
    {
      "resource": {
        "resourceType": "Patient",
        "id": "patient-123",
        "name": [
          {
            "family": "Smith",
            "given": ["John", "Edward"]
          }
        ],
        "birthDate": "1972-07-12",
        "gender": "male",
        "address": [
          {
            "line": ["123 Main St"],
            "city": "Columbus",
            "state": "OH",
            "postalCode": "43215"
          }
        ]
      }
    },
    // Additional patients...
  ]
}
```

#### Example 2: Create Medication Request

```http
POST /fhir/MedicationRequest
Content-Type: application/fhir+json

{
  "resourceType": "MedicationRequest",
  "status": "active",
  "intent": "order",
  "medicationCodeableConcept": {
    "coding": [
      {
        "system": "http://www.nlm.nih.gov/research/umls/rxnorm",
        "code": "308056",
        "display": "Amoxicillin 500 MG Oral Capsule"
      }
    ]
  },
  "subject": {
    "reference": "Patient/patient-123"
  },
  "authoredOn": "2023-05-15",
  "requester": {
    "reference": "Practitioner/practitioner-456"
  },
  "dosageInstruction": [
    {
      "text": "Take 1 capsule by mouth three times daily for 10 days",
      "timing": {
        "repeat": {
          "frequency": 3,
          "period": 1,
          "periodUnit": "d"
        }
      },
      "doseAndRate": [
        {
          "doseQuantity": {
            "value": 1,
            "unit": "capsule",
            "system": "http://unitsofmeasure.org",
            "code": "{capsule}"
          }
        }
      ]
    }
  ],
  "dispenseRequest": {
    "numberOfRepeatsAllowed": 0,
    "quantity": {
      "value": 30,
      "unit": "capsule",
      "system": "http://unitsofmeasure.org",
      "code": "{capsule}"
    },
    "expectedSupplyDuration": {
      "value": 10,
      "unit": "days",
      "system": "http://unitsofmeasure.org",
      "code": "d"
    }
  }
}
```

#### Example 3: GraphQL Query for Patient with Conditions

```graphql
{
  PatientList(family: "Smith", _count: 1) {
    id
    name { given family }
    birthDate
    Condition {
      id
      code { coding { display } }
      onsetDateTime
      clinicalStatus { coding { code } }
    }
    MedicationRequest {
      status
      medicationCodeableConcept { coding { display } }
      authoredOn
    }
  }
}
```

## Postman Collection

For more advanced testing, a Postman collection is available:

1. Download the FHIR Interoperability Platform Postman collection: [Download Link](https://fhir-sandbox.dev.cmm.azure.com/downloads/fhir-platform-collection.json)
2. Import the collection into Postman
3. Configure the collection variables:
   - `sandbox_url`: `https://fhir-sandbox.dev.cmm.azure.com`
   - `api_key`: Your sandbox API key

The collection includes:
- Pre-configured authentication
- Organized request folders by FHIR resource type
- Example payloads for each FHIR resource
- Environment variables for easy switching between sandbox and production
- Tests to validate responses against FHIR specification
- SMART on FHIR authentication flows

Additional healthcare-specific features:
- Clinical workflows (referrals, care plans)
- Medication workflows (prescribe, dispense, administer)
- Insurance coverage verification
- Prior authorization requests
- Clinical decision support (CDS Hooks)

## Mock Servers

For offline development, we provide mock servers that simulate FHIR API behavior:

### Docker-based Mock

```bash
# Pull and run the mock server
docker pull covermymeds/fhir-platform-mock:latest
docker run -p 8080:8080 covermymeds/fhir-platform-mock:latest

# The mock server is available at http://localhost:8080
```

The mock server includes:
- Full FHIR R4 API implementation
- Pre-loaded synthetic patient data
- SMART on FHIR authorization support
- Configurable response delays and errors
- Ability to save and persist changes during development

### Static Response Files

Alternatively, download static response files for offline use:
- [FHIR JSON Response Pack](https://fhir-sandbox.dev.cmm.azure.com/downloads/fhir-responses.zip)
- [FHIR OpenAPI Specification](https://fhir-sandbox.dev.cmm.azure.com/downloads/fhir-openapi.yaml)
- [Sample Patient Bundle](https://fhir-sandbox.dev.cmm.azure.com/downloads/sample-patient-bundle.json)

## Data Generation

The sandbox includes tools to generate synthetic test data:

1. Navigate to `https://fhir-sandbox.dev.cmm.azure.com/data-generator`
2. Select the data type you need:
   - Patient demographics
   - Clinical conditions and observations
   - Medications and allergies
   - Insurance coverage and claims
   - Provider and organization data
3. Configure generation parameters:
   - Number of resources
   - Clinical complexity
   - Demographic distribution
   - Condition prevalence rates
   - Medication adherence patterns
4. Generate synthetic data that conforms to FHIR standards
5. Import the generated data into your sandbox instance

## Testing Webhooks

To test FHIR Subscriptions and event notifications:

1. Navigate to `https://fhir-sandbox.dev.cmm.azure.com/webhooks`
2. Register a webhook URL (can be a service like webhook.site for testing)
3. Select the FHIR resource types and interactions you want to monitor:
   - Resource types (Patient, Encounter, Observation, etc.)
   - Interactions (create, update, delete)
   - Custom search criteria (for filtered subscriptions)
4. Trigger events using the appropriate FHIR API calls
5. View the webhook delivery details and payload

The subscription notification includes:
- Resource type and ID
- Interaction type
- Timestamp
- Change summary
- Full or partial resource representation
- Provenance information

## Troubleshooting

| Issue | Resolution |
|-------|------------|
| Authentication failure | Verify you're using the sandbox API key, not a production key |
| "Resource not found" | Check the URL path - sandbox uses `/fhir/[resource]` structure |
| Sandbox reset | Sandbox environments reset daily at 00:00 UTC |
| FHIR validation errors | Review resource against FHIR profiles in the US Core IG |
| Rate limiting | Implement proper backoff strategy (even in sandbox) |
| SMART app launch failure | Verify redirect URI matches exactly what's registered |
| Missing related resources | Use `_include` and `_revinclude` parameters to retrieve related resources |

## Next Steps

After exploring the API in the sandbox:

- Review the [Core APIs Documentation](../03-core-functionality/core-apis.md)
- Explore the [Data Model](../03-core-functionality/data-model.md)
- Set up a [local development environment](./local-setup.md)
- Learn about [FHIR Profiles and Extensions](../04-advanced-patterns/customization.md)

## Support

For help with the sandbox environment:

- Chat: Join the Microsoft Teams channel `#fhir-platform-sandbox-support`
- Email: [fhir-sandbox-support@covermymeds.com](mailto:fhir-sandbox-support@covermymeds.com)
- Office Hours: Sandbox support team is available weekdays 9am-5pm ET
- FHIR Clinics: Drop-in sessions every Wednesday, 2-4pm ET

## Related Resources

- [Learning Resources](./learning-resources.md)
- [Core APIs Documentation](../03-core-functionality/core-apis.md)
- [Aidbox Documentation](https://docs.aidbox.app/)
- [HL7 FHIR Specification](https://hl7.org/fhir/)