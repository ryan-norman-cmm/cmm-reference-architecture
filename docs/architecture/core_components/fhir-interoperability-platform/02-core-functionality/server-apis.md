# FHIR Server APIs

## Overview

The FHIR Interoperability Platform provides a comprehensive set of RESTful APIs that conform to the HL7 FHIR specification. These APIs enable applications to create, read, update, delete, and search for healthcare resources in a standardized way. This document covers the core API endpoints, their usage patterns, and implementation considerations for healthcare interoperability scenarios.

## API Basics

The FHIR Server APIs follow RESTful principles, with resources identified by URLs and standard HTTP methods used for operations:

- **GET**: Retrieve a resource or search for resources
- **POST**: Create a new resource or execute an operation
- **PUT**: Update an existing resource
- **DELETE**: Delete a resource
- **PATCH**: Partially update a resource

## Resource Endpoints

### Resource Instance Operations

```
GET    [base]/[resourceType]/[id]           # Read a resource
PUT    [base]/[resourceType]/[id]           # Update a resource
DELETE [base]/[resourceType]/[id]           # Delete a resource
PATCH  [base]/[resourceType]/[id]           # Patch a resource
```

#### Example: Reading a Patient Resource

```bash
# Retrieve a specific patient by ID
curl -X GET https://fhir-platform.example.org/fhir/Patient/123 \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Accept: application/fhir+json"
```

Response:

```json
{
  "resourceType": "Patient",
  "id": "123",
  "meta": {
    "versionId": "1",
    "lastUpdated": "2023-05-01T12:00:00Z"
  },
  "identifier": [
    {
      "system": "http://hospital.example.org/identifiers/mrn",
      "value": "MRN12345"
    }
  ],
  "name": [
    {
      "family": "Smith",
      "given": ["John"]
    }
  ],
  "gender": "male",
  "birthDate": "1970-01-01"
}
```

#### Example: Updating a Patient Resource

```bash
# Update a patient resource
curl -X PUT https://fhir-platform.example.org/fhir/Patient/123 \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/fhir+json" \
  -d '{
    "resourceType": "Patient",
    "id": "123",
    "identifier": [
      {
        "system": "http://hospital.example.org/identifiers/mrn",
        "value": "MRN12345"
      }
    ],
    "name": [
      {
        "family": "Smith",
        "given": ["John", "Jacob"]
      }
    ],
    "gender": "male",
    "birthDate": "1970-01-01",
    "telecom": [
      {
        "system": "phone",
        "value": "555-555-5555",
        "use": "home"
      }
    ]
  }'
```

### Resource Type Operations

```
GET    [base]/[resourceType]                # Search for resources
POST   [base]/[resourceType]                # Create a resource
GET    [base]/[resourceType]/_history       # History for all resources of type
GET    [base]/[resourceType]/_search        # Search for resources (POST-based search)
POST   [base]/[resourceType]/_search        # Search for resources (POST-based search)
```

#### Example: Creating a New Observation

```bash
# Create a new observation
curl -X POST https://fhir-platform.example.org/fhir/Observation \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/fhir+json" \
  -d '{
    "resourceType": "Observation",
    "status": "final",
    "category": [
      {
        "coding": [
          {
            "system": "http://terminology.hl7.org/CodeSystem/observation-category",
            "code": "vital-signs",
            "display": "Vital Signs"
          }
        ]
      }
    ],
    "code": {
      "coding": [
        {
          "system": "http://loinc.org",
          "code": "8867-4",
          "display": "Heart rate"
        }
      ]
    },
    "subject": {
      "reference": "Patient/123"
    },
    "effectiveDateTime": "2023-05-01T12:00:00Z",
    "valueQuantity": {
      "value": 80,
      "unit": "beats/minute",
      "system": "http://unitsofmeasure.org",
      "code": "/min"
    }
  }'
```

#### Example: Searching for Resources

```bash
# Search for patients with a specific name
curl -X GET "https://fhir-platform.example.org/fhir/Patient?family=Smith&given=John" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Accept: application/fhir+json"

# Search for observations for a specific patient
curl -X GET "https://fhir-platform.example.org/fhir/Observation?subject=Patient/123&category=vital-signs" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Accept: application/fhir+json"
```

### Instance History Operations

```
GET    [base]/[resourceType]/[id]/_history           # Resource version history
GET    [base]/[resourceType]/[id]/_history/[vid]     # Read specific version
```

#### Example: Retrieving Resource History

```bash
# Get the version history of a patient resource
curl -X GET https://fhir-platform.example.org/fhir/Patient/123/_history \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Accept: application/fhir+json"

# Get a specific version of a patient resource
curl -X GET https://fhir-platform.example.org/fhir/Patient/123/_history/2 \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Accept: application/fhir+json"
```

## System-Level Operations

```
GET    [base]/metadata                      # Capability statement (conformance)
GET    [base]/$operations                   # List of supported operations
GET    [base]/_history                      # History for all resources
GET    [base]                               # Retrieve server root
```

#### Example: Retrieving Capability Statement

```bash
# Get the server's capability statement
curl -X GET https://fhir-platform.example.org/fhir/metadata \
  -H "Accept: application/fhir+json"
```

## Extended Operations

The FHIR Interoperability Platform supports several extended operations beyond the core FHIR API:

### Batch and Transaction Operations

```
POST   [base]                               # Batch/transaction bundle
```

#### Example: Submitting a Transaction Bundle

```bash
# Submit a transaction bundle
curl -X POST https://fhir-platform.example.org/fhir \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/fhir+json" \
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
          "name": [
            {
              "family": "Johnson",
              "given": ["Robert"]
            }
          ],
          "gender": "male",
          "birthDate": "1980-06-15"
        }
      },
      {
        "request": {
          "method": "POST",
          "url": "Observation"
        },
        "resource": {
          "resourceType": "Observation",
          "status": "final",
          "code": {
            "coding": [
              {
                "system": "http://loinc.org",
                "code": "8480-6",
                "display": "Systolic blood pressure"
              }
            ]
          },
          "subject": {
            "reference": "urn:uuid:12345678-1234-1234-1234-123456789012"
          },
          "valueQuantity": {
            "value": 120,
            "unit": "mmHg",
            "system": "http://unitsofmeasure.org",
            "code": "mm[Hg]"
          }
        }
      }
    ]
  }'
```

### Validation Operation

```
POST   [base]/[resourceType]/$validate      # Validate a resource
```

#### Example: Validating a Resource

```bash
# Validate a patient resource
curl -X POST https://fhir-platform.example.org/fhir/Patient/$validate \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/fhir+json" \
  -d '{
    "resourceType": "Patient",
    "name": [
      {
        "family": "Smith",
        "given": ["John"]
      }
    ],
    "gender": "male",
    "birthDate": "1970-01-01"
  }'
```

### Document Operations

```
POST   [base]/DocumentReference/$docref     # Generate a document
```

### Bulk Data Operations

```
GET    [base]/$export                       # System-level export
GET    [base]/Group/[id]/$export            # Group-level export
GET    [base]/Patient/[id]/$export          # Patient-level export
```

See [Bulk Data Operations](../03-advanced-patterns/bulk-data-operations.md) for detailed information.

## Search Parameters

The FHIR API supports a rich set of search parameters for filtering resources:

### Common Search Parameters

- **_id**: Search by resource id
- **_lastUpdated**: Search by last updated date
- **_tag**: Search by tag
- **_profile**: Search by profile
- **_security**: Search by security label
- **_text**: Search on narrative text
- **_content**: Search on the entire resource
- **_list**: Search for resources in a list
- **_has**: Reverse chaining
- **_type**: Search for resources of a specific type

### Resource-Specific Search Parameters

Each resource type has specific search parameters. For example, Patient resources support:

- **identifier**: Search by identifier
- **name**: Search by name
- **family**: Search by family name
- **given**: Search by given name
- **birthdate**: Search by birth date
- **gender**: Search by gender
- **address**: Search by address
- **telecom**: Search by telecom details

### Search Result Parameters

- **_count**: Number of results per page
- **_sort**: Sort order
- **_include**: Include referenced resources
- **_revinclude**: Include resources that reference the matched resources
- **_summary**: Return only summary information
- **_elements**: Return only specific elements
- **_contained**: Control handling of contained resources
- **_containedType**: Control handling of contained resources

#### Example: Complex Search with Parameters

```bash
# Search for recent observations for a specific patient, including the patient resource
curl -X GET "https://fhir-platform.example.org/fhir/Observation?subject=Patient/123&_lastUpdated=gt2023-01-01&_sort=-date&_count=10&_include=Observation:subject" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Accept: application/fhir+json"
```

## Content Types

The FHIR Interoperability Platform supports multiple content types:

- **application/fhir+json**: FHIR resources in JSON format (default)
- **application/fhir+xml**: FHIR resources in XML format
- **application/json**: Standard JSON (treated as FHIR JSON)
- **application/xml**: Standard XML (treated as FHIR XML)

Specify the desired format using the `Accept` header for responses and the `Content-Type` header for requests.

## Error Handling

The FHIR API uses standard HTTP status codes and OperationOutcome resources to communicate errors:

### Common HTTP Status Codes

- **200 OK**: Successful operation
- **201 Created**: Resource created successfully
- **400 Bad Request**: Invalid request
- **401 Unauthorized**: Authentication required
- **403 Forbidden**: Insufficient permissions
- **404 Not Found**: Resource not found
- **409 Conflict**: Resource version conflict
- **422 Unprocessable Entity**: Business rule violation
- **500 Internal Server Error**: Server error

### OperationOutcome Example

```json
{
  "resourceType": "OperationOutcome",
  "issue": [
    {
      "severity": "error",
      "code": "invalid",
      "diagnostics": "The birthDate '2023-13-32' is not a valid date",
      "location": ["Patient.birthDate"]
    }
  ]
}
```

## API Versioning

The FHIR Interoperability Platform supports multiple FHIR versions:

- **FHIR R4 (4.0.1)**: Primary supported version
- **FHIR R5 (5.0.0)**: Available for specific endpoints

Specify the desired FHIR version using the `fhirVersion` parameter or a version-specific endpoint:

```bash
# Specify FHIR version via parameter
curl -X GET "https://fhir-platform.example.org/fhir/Patient/123?fhirVersion=4.0.1" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"

# Use version-specific endpoint
curl -X GET https://fhir-platform.example.org/r4/Patient/123 \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

## Authentication and Authorization

The FHIR Interoperability Platform uses OAuth 2.0 for authentication and authorization. See [FHIR RBAC](rbac.md) for detailed information on role-based access control.

```bash
# Example authentication flow
# 1. Obtain an access token
curl -X POST https://auth.example.org/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials&client_id=YOUR_CLIENT_ID&client_secret=YOUR_CLIENT_SECRET&scope=patient/*.read"

# 2. Use the token to access FHIR resources
curl -X GET https://fhir-platform.example.org/fhir/Patient/123 \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

## Healthcare-Specific API Patterns

### Patient-Centric Queries

Many healthcare applications need to retrieve all data for a specific patient:

```bash
# Get all data for a patient using _include and _revinclude
curl -X GET "https://fhir-platform.example.org/fhir/Patient?_id=123&_include=*&_revinclude=*" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"

# Alternative: use compartment search
curl -X GET https://fhir-platform.example.org/fhir/Patient/123/\* \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### Clinical Data Queries

Retrieve clinical observations with specific codes:

```bash
# Get all blood pressure readings for a patient
curl -X GET "https://fhir-platform.example.org/fhir/Observation?subject=Patient/123&code=http://loinc.org|8480-6,http://loinc.org|8462-4" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### Medication Management

Track a patient's medications:

```bash
# Get active medications for a patient
curl -X GET "https://fhir-platform.example.org/fhir/MedicationRequest?subject=Patient/123&status=active" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

## API Limitations and Considerations

### Performance Considerations

1. **Resource Size**: Large resources may impact performance
2. **Search Complexity**: Complex searches may be resource-intensive
3. **Include Depth**: Deep includes can cause performance issues
4. **Pagination**: Use appropriate page sizes for large result sets

### Security Considerations

1. **PHI Protection**: All API calls containing PHI must use TLS
2. **Minimal Disclosure**: Request only the data elements needed
3. **Audit Logging**: All API access is logged for compliance
4. **Rate Limiting**: APIs may be rate-limited to prevent abuse

## Related Documentation

- [FHIR RBAC](rbac.md): Role-based access control for FHIR resources
- [FHIR Data Persistence](data-persistence.md): How FHIR data is stored and retrieved
- [FHIR Subscriptions](subscriptions.md): Event-based notifications for FHIR resources
- [Bulk Data Operations](../03-advanced-patterns/bulk-data-operations.md): Large-scale data operations
