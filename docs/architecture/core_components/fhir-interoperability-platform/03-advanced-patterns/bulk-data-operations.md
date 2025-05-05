# FHIR Bulk Data Operations

## Overview

Bulk Data Operations enable efficient, large-scale data exchange in the FHIR Interoperability Platform. These operations are essential for population health management, analytics, data migrations, and reporting scenarios where working with individual resources would be inefficient. This guide covers the implementation and usage of FHIR Bulk Data Access API (also known as Flat FHIR) within the platform.

## Key Concepts

The FHIR Bulk Data specification defines several key operations:

- **System-level Export**: Export data for all patients in the system
- **Group-level Export**: Export data for patients in a specific group
- **Patient-level Export**: Export all data for a specific patient
- **Bulk Data Import**: Import large volumes of FHIR resources efficiently

These operations are asynchronous by design, allowing for the processing of large datasets without timeouts or excessive resource consumption.

## Bulk Data Export

### System-Level Export

System-level export retrieves data for all patients in the system:

```bash
# Initiate a system-level export
curl -X GET https://fhir-platform.example.org/fhir/$export \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Accept: application/fhir+json" \
  -H "Prefer: respond-async"
```

Response:

```http
HTTP/1.1 202 Accepted
Content-Location: https://fhir-platform.example.org/fhir/$export-status/abc123
```

### Group-Level Export

Group-level export retrieves data for patients in a specific group:

```bash
# Initiate a group-level export
curl -X GET https://fhir-platform.example.org/fhir/Group/diabetes-patients/$export \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Accept: application/fhir+json" \
  -H "Prefer: respond-async"
```

### Patient-Level Export

Patient-level export retrieves all data for a specific patient:

```bash
# Initiate a patient-level export
curl -X GET https://fhir-platform.example.org/fhir/Patient/123/$export \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Accept: application/fhir+json" \
  -H "Prefer: respond-async"
```

### Export Parameters

All export operations support several query parameters:

- **_type**: Filter by resource types (e.g., `_type=Patient,Observation,Encounter`)
- **_since**: Only include resources modified after this time
- **_elements**: Include only specific elements in the exported resources
- **_outputFormat**: Specify the output format (default is `application/fhir+ndjson`)

```bash
# Export with parameters
curl -X GET "https://fhir-platform.example.org/fhir/$export?_type=Patient,Encounter&_since=2023-01-01T00:00:00Z" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Accept: application/fhir+json" \
  -H "Prefer: respond-async"
```

### Checking Export Status

Use the Content-Location URL to check the status of an export operation:

```bash
# Check export status
curl -X GET https://fhir-platform.example.org/fhir/$export-status/abc123 \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

Response when in progress:

```http
HTTP/1.1 202 Accepted
X-Progress: 50% complete
```

Response when complete:

```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "transactionTime": "2023-06-15T13:28:17.239+00:00",
  "request": "https://fhir-platform.example.org/fhir/$export",
  "requiresAccessToken": true,
  "output": [
    {
      "type": "Patient",
      "url": "https://storage.example.org/exports/abc123/Patient.ndjson"
    },
    {
      "type": "Encounter",
      "url": "https://storage.example.org/exports/abc123/Encounter.ndjson"
    },
    {
      "type": "Observation",
      "url": "https://storage.example.org/exports/abc123/Observation.ndjson"
    }
  ],
  "error": []
}
```

### Downloading Export Files

Download the exported files using the URLs in the response:

```bash
# Download an export file
curl -X GET https://storage.example.org/exports/abc123/Patient.ndjson \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

The exported files are in NDJSON (Newline Delimited JSON) format, with one FHIR resource per line.

### Canceling an Export

To cancel an in-progress export operation:

```bash
# Cancel an export
curl -X DELETE https://fhir-platform.example.org/fhir/$export-status/abc123 \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

## Bulk Data Import

The FHIR Interoperability Platform supports bulk data import using the `$import` operation.

### Initiating an Import

```bash
# Initiate a bulk data import
curl -X POST https://fhir-platform.example.org/fhir/$import \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "resourceType": "Parameters",
    "parameter": [
      {
        "name": "inputFormat",
        "valueString": "application/fhir+ndjson"
      },
      {
        "name": "inputSource",
        "valueUri": "https://example.org/fhir/import-source"
      },
      {
        "name": "input",
        "part": [
          {
            "name": "type",
            "valueString": "Patient"
          },
          {
            "name": "url",
            "valueUrl": "https://storage.example.org/imports/Patient.ndjson"
          }
        ]
      },
      {
        "name": "input",
        "part": [
          {
            "name": "type",
            "valueString": "Encounter"
          },
          {
            "name": "url",
            "valueUrl": "https://storage.example.org/imports/Encounter.ndjson"
          }
        ]
      }
    ]
  }'
```

Response:

```http
HTTP/1.1 202 Accepted
Content-Location: https://fhir-platform.example.org/fhir/$import-status/def456
```

### Checking Import Status

```bash
# Check import status
curl -X GET https://fhir-platform.example.org/fhir/$import-status/def456 \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

Response when complete:

```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "transactionTime": "2023-06-15T14:35:22.456+00:00",
  "request": "https://fhir-platform.example.org/fhir/$import",
  "output": [
    {
      "type": "Patient",
      "count": 1500,
      "inputUrl": "https://storage.example.org/imports/Patient.ndjson"
    },
    {
      "type": "Encounter",
      "count": 3200,
      "inputUrl": "https://storage.example.org/imports/Encounter.ndjson"
    }
  ],
  "error": []
}
```

## Implementation Considerations

### Performance Optimization

1. **Parallel Processing**: Implement parallel processing for both export and import operations
2. **Streaming**: Use streaming to process data without loading everything into memory
3. **Batching**: Process data in batches to manage memory usage
4. **Storage Strategy**: Use efficient storage solutions for temporary and permanent data storage

```java
// Example of parallel processing in Java
public class BulkDataExporter {
    public void exportPatientData(List<String> patientIds) {
        patientIds.parallelStream().forEach(patientId -> {
            try {
                exportPatientResources(patientId);
            } catch (Exception e) {
                logError("Error exporting patient " + patientId, e);
            }
        });
    }
    
    private void exportPatientResources(String patientId) {
        // Implementation details
    }
}
```

### Security Considerations

1. **Access Control**: Implement strict access controls for bulk operations
2. **Data Minimization**: Export only necessary data elements
3. **Audit Logging**: Maintain comprehensive audit logs of all bulk operations
4. **Secure Storage**: Ensure exported data is stored securely
5. **Time-Limited Access**: Make export files available for a limited time

```java
// Example of audit logging for bulk operations
public class BulkOperationAuditor {
    public void logExportOperation(String userId, String exportType, List<String> resourceTypes) {
        AuditEvent auditEvent = new AuditEvent();
        auditEvent.setAction(AuditEvent.AuditEventAction.E);
        auditEvent.setRecorded(new Date());
        
        AuditEvent.AuditEventAgentComponent agent = new AuditEvent.AuditEventAgentComponent();
        agent.setWho(new Reference("User/" + userId));
        auditEvent.addAgent(agent);
        
        AuditEvent.AuditEventEntityComponent entity = new AuditEvent.AuditEventEntityComponent();
        entity.setWhat(new Reference("System"));
        entity.setDescription("Bulk data export of types: " + String.join(", ", resourceTypes));
        auditEvent.addEntity(entity);
        
        fhirClient.create().resource(auditEvent).execute();
    }
}
```

### Error Handling

1. **Partial Success**: Support partial success scenarios where some resources fail but others succeed
2. **Detailed Error Reporting**: Provide detailed error information for failed operations
3. **Retry Mechanisms**: Implement intelligent retry mechanisms for transient failures

```json
{
  "transactionTime": "2023-06-15T14:35:22.456+00:00",
  "request": "https://fhir-platform.example.org/fhir/$import",
  "output": [
    {
      "type": "Patient",
      "count": 1450,
      "inputUrl": "https://storage.example.org/imports/Patient.ndjson"
    }
  ],
  "error": [
    {
      "type": "Patient",
      "inputUrl": "https://storage.example.org/imports/Patient.ndjson",
      "count": 50,
      "errors": [
        {
          "lineNumber": 27,
          "resourceId": "Patient/123",
          "message": "Invalid identifier system"
        },
        {
          "lineNumber": 42,
          "resourceId": "Patient/456",
          "message": "Missing required field: gender"
        }
      ]
    }
  ]
}
```

## Healthcare Use Cases

### Population Health Management

Bulk data operations enable population health analytics by exporting data for specific patient cohorts:

```bash
# Export data for diabetes patients
curl -X GET https://fhir-platform.example.org/fhir/Group/diabetes-patients/$export?_type=Patient,Observation,MedicationRequest \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Accept: application/fhir+json" \
  -H "Prefer: respond-async"
```

### Data Migration

Bulk operations facilitate migration between systems:

1. Export data from the source system
2. Transform data if necessary
3. Import data into the target system

### Clinical Research

Researchers can extract de-identified datasets for approved studies:

```bash
# Export de-identified data for research
curl -X GET "https://fhir-platform.example.org/fhir/Group/study-cohort/$export?_type=Patient,Observation&_elements=Observation.code,Observation.value,Observation.effective,Patient.birthDate,Patient.gender" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Accept: application/fhir+json" \
  -H "Prefer: respond-async"
```

## Troubleshooting

### Common Issues

1. **Timeout During Status Check**: For very large exports, status checks might timeout
   - Solution: Implement exponential backoff for status checks

2. **Memory Issues During Import**: Large imports can cause memory problems
   - Solution: Use streaming and batching to manage memory usage

3. **Missing Resources After Import**: Some resources might be missing after import
   - Solution: Implement validation and reconciliation processes

### Diagnostic Steps

```bash
# Check server logs for export errors
tail -f /var/log/fhir-platform/bulk-operations.log

# Verify export file contents
head -n 10 /path/to/export/Patient.ndjson

# Count resources in an export file
wc -l /path/to/export/Patient.ndjson
```

## Related Documentation

- [FHIR Server APIs](../02-core-functionality/server-apis.md): API endpoints for FHIR operations
- [Data Persistence](../02-core-functionality/data-persistence.md): Storage options for FHIR data
- [Query Optimization](query-optimization.md): Optimizing FHIR queries for performance
