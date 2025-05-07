# FHIR Interoperability Platform Customization

## Introduction
This document describes the customization options available for the FHIR Interoperability Platform. The platform offers extensive customization capabilities to meet specific healthcare workflows, extend standard FHIR resources, and integrate with existing systems. By leveraging these customization options, you can tailor the FHIR Interoperability Platform to meet CoverMyMeds' unique requirements while maintaining standards compliance.

## Customizable Elements

### Custom FHIR Resources

The FHIR Interoperability Platform allows for the creation of custom FHIR resources to support CoverMyMeds-specific workflows:

| Custom Resource | Purpose | Example Use Cases |
|-----------------|---------|-------------------|
| **PriorAuthorization** | Manages prior authorization requests | Medication approval workflows, authorization tracking |
| **PADetermination** | Stores decisions on PA requests | Approval/denial tracking, determination history |
| **DrugPrice** | Provides pricing information for medications | Cost transparency, benefit optimization |
| **PAHUBAttachment** | Manages document attachments for PA workflows | Clinical documentation, supporting evidence |
| **PAQuestion** | Captures PA form questions and responses | Questionnaire management, form automation |

### FHIR Resource Profiles

You can create custom FHIR profiles to constrain and extend standard FHIR resources for specific use cases:

- **Profile Definition**: Use the StructureDefinition resource to define constraints, extensions, and value sets
- **Profile Validation**: Apply validation rules to ensure resources conform to profiles
- **Implementation Guide Support**: Create comprehensive implementation guides for specific workflows

### FHIR Extensions

Create custom extensions to add new elements to standard FHIR resources:

- **Simple Extensions**: Add simple data types (strings, codes, etc.) to resources
- **Complex Extensions**: Add nested, structured data to resources
- **Extension Registry**: Register extensions in a central repository for consistent usage

### Custom Operations

Define custom FHIR operations for specialized functionality beyond standard CRUD operations:

- **Resource-Level Operations**: Operations that target specific resource types
- **System-Level Operations**: Operations that operate across the entire system
- **Custom Endpoints**: Create specialized API endpoints for specific workflows

### Terminology Support

Customize code systems and value sets for domain-specific terminology:

- **Custom Code Systems**: Define organization-specific code systems
- **Value Set Management**: Create and manage specialized value sets
- **Terminology Mappings**: Map between different terminology systems

### Search Parameter Customization

Add custom search parameters to enable specific query capabilities:

- **Resource-Specific Parameters**: Add parameters for querying specific resource types
- **Composite Parameters**: Create parameters that search across multiple fields
- **Special Parameters**: Implement advanced search capabilities

## Configuration Options

### Server Configuration

The FHIR Interoperability Platform offers several server-level configuration options:

```yaml
# Aidbox Configuration Example
database:
  dbName: aidbox
  dbUser: postgres
  dbPassword: ${DB_PASSWORD}
  dbHost: postgres
  dbPort: 5432

auth:
  jwt:
    secret: ${JWT_SECRET}
  signingAlgorithm: RS256
  tokenExpiration: 3600

fhir:
  version: R4
  resourceValidation: true
  supportedResources:
    - Patient
    - Practitioner
    - Organization
    - MedicationRequest
    - PriorAuthorization  # Custom resource

extensions:
  enabled: true
  strictValidation: false
  
profiling:
  enabled: true
  defaultProfiles:
    Patient: http://hl7.org/fhir/us/core/StructureDefinition/us-core-patient
    MedicationRequest: http://hl7.org/fhir/us/core/StructureDefinition/us-core-medicationrequest

subscriptions:
  enabled: true
  backendType: kafka
  kafkaTopic: fhir-subscriptions
  
apiGateway:
  rateLimit: 100
  enableCORS: true
  allowedOrigins: "*.covermymeds.com"
```

### Subscription Configuration

Configure real-time notifications for resource changes:

```yaml
# Subscription Service Configuration
subscriptionService:
  notificationMethods:
    - rest-hook
    - websocket
    - email
    - kafka
  deliveryRetryPolicy:
    maxRetries: 5
    retryInterval: 60
    exponentialBackoff: true
  security:
    signedNotifications: true
    jwtAuthentication: true
  channels:
    kafka:
      brokers: "kafka1:9092,kafka2:9092"
      clientId: "fhir-subscription-service"
      topic: "fhir-notifications"
    email:
      smtpServer: "smtp.covermymeds.com"
      fromAddress: "notifications@covermymeds.com"
      subjectTemplate: "FHIR Notification: {{resourceType}} Update"
```

### Terminology Service Configuration

Configure terminology services for code system and value set management:

```yaml
# Terminology Service Configuration
terminologyService:
  enableExpand: true
  enableValidate: true
  enableTranslate: true
  enableLookup: true
  codeSystemUploads: true
  valueSetUploads: true
  externalTerminologyServers:
    - name: "VSAC"
      url: "https://cts.nlm.nih.gov/fhir/"
      authType: "api-key"
    - name: "SNOWSTORM"
      url: "https://snowstorm.example.org/fhir/"
      authType: "basic"
  caching:
    enabled: true
    ttlSeconds: 86400
    maxEntries: 1000
```

### Custom Operation Configuration

Register and configure custom operations:

```yaml
# Custom Operations Configuration
operations:
  - name: "check-prior-authorization"
    type: "system"
    handler: "priorAuthorizationService.checkRequirement"
    contentTypes:
      - "application/fhir+json"
    methods:
      - "POST"
    parameters:
      - name: "patient"
        type: "reference"
        required: true
      - name: "medication"
        type: "reference"
        required: true
  - name: "convert-to-fhir"
    type: "system"
    handler: "conversionService.convertToFhir"
    contentTypes:
      - "application/xml"
      - "application/json"
    methods:
      - "POST"
    parameters:
      - name: "source"
        type: "string"
        required: true
      - name: "sourceFormat"
        type: "code"
        required: true
```

## Example Customization

### Custom FHIR Profile Example

```json
{
  "resourceType": "StructureDefinition",
  "id": "cmm-medication-request",
  "url": "http://covermymeds.com/fhir/StructureDefinition/cmm-medication-request",
  "name": "CMMCustomMedicationRequest",
  "title": "CoverMyMeds Custom MedicationRequest Profile",
  "status": "active",
  "description": "Profile of MedicationRequest for CoverMyMeds workflows",
  "fhirVersion": "4.0.1",
  "kind": "resource",
  "abstract": false,
  "type": "MedicationRequest",
  "baseDefinition": "http://hl7.org/fhir/us/core/StructureDefinition/us-core-medicationrequest",
  "derivation": "constraint",
  "differential": {
    "element": [
      {
        "id": "MedicationRequest",
        "path": "MedicationRequest"
      },
      {
        "id": "MedicationRequest.extension",
        "path": "MedicationRequest.extension",
        "slicing": {
          "discriminator": [
            {
              "type": "value",
              "path": "url"
            }
          ],
          "ordered": false,
          "rules": "open"
        }
      },
      {
        "id": "MedicationRequest.extension:priorAuthorizationStatus",
        "path": "MedicationRequest.extension",
        "sliceName": "priorAuthorizationStatus",
        "min": 0,
        "max": "1",
        "type": [
          {
            "code": "Extension",
            "profile": [
              "http://covermymeds.com/fhir/StructureDefinition/prior-authorization-status"
            ]
          }
        ]
      },
      {
        "id": "MedicationRequest.extension:formularyStatus",
        "path": "MedicationRequest.extension",
        "sliceName": "formularyStatus",
        "min": 0,
        "max": "1",
        "type": [
          {
            "code": "Extension",
            "profile": [
              "http://covermymeds.com/fhir/StructureDefinition/formulary-status"
            ]
          }
        ]
      },
      {
        "id": "MedicationRequest.extension:patientCopay",
        "path": "MedicationRequest.extension",
        "sliceName": "patientCopay",
        "min": 0,
        "max": "1",
        "type": [
          {
            "code": "Extension",
            "profile": [
              "http://covermymeds.com/fhir/StructureDefinition/patient-copay"
            ]
          }
        ]
      },
      {
        "id": "MedicationRequest.identifier",
        "path": "MedicationRequest.identifier",
        "slicing": {
          "discriminator": [
            {
              "type": "value",
              "path": "system"
            }
          ],
          "ordered": false,
          "rules": "open"
        }
      },
      {
        "id": "MedicationRequest.identifier:cmmPrescriptionId",
        "path": "MedicationRequest.identifier",
        "sliceName": "cmmPrescriptionId",
        "min": 0,
        "max": "1",
        "type": [
          {
            "code": "Identifier"
          }
        ],
        "patternIdentifier": {
          "system": "http://covermymeds.com/fhir/identifier/prescription"
        }
      },
      {
        "id": "MedicationRequest.statusReason",
        "path": "MedicationRequest.statusReason",
        "binding": {
          "strength": "preferred",
          "valueSet": "http://covermymeds.com/fhir/ValueSet/prescription-status-reason"
        }
      },
      {
        "id": "MedicationRequest.priorAuthorization",
        "path": "MedicationRequest.priorAuthorization",
        "min": 0,
        "max": "1",
        "type": [
          {
            "code": "Reference",
            "targetProfile": [
              "http://covermymeds.com/fhir/StructureDefinition/PriorAuthorization"
            ]
          }
        ]
      }
    ]
  }
}
```

### Custom Extension Example

```json
{
  "resourceType": "StructureDefinition",
  "id": "prior-authorization-status",
  "url": "http://covermymeds.com/fhir/StructureDefinition/prior-authorization-status",
  "name": "PriorAuthorizationStatus",
  "title": "Prior Authorization Status Extension",
  "status": "active",
  "description": "Extension to indicate prior authorization status for a medication",
  "fhirVersion": "4.0.1",
  "kind": "complex-type",
  "abstract": false,
  "context": [
    {
      "type": "element",
      "expression": "MedicationRequest"
    }
  ],
  "type": "Extension",
  "baseDefinition": "http://hl7.org/fhir/StructureDefinition/Extension",
  "derivation": "constraint",
  "differential": {
    "element": [
      {
        "id": "Extension",
        "path": "Extension"
      },
      {
        "id": "Extension.extension",
        "path": "Extension.extension",
        "slicing": {
          "discriminator": [
            {
              "type": "value",
              "path": "url"
            }
          ],
          "ordered": false,
          "rules": "open"
        }
      },
      {
        "id": "Extension.extension:status",
        "path": "Extension.extension",
        "sliceName": "status",
        "min": 1,
        "max": "1"
      },
      {
        "id": "Extension.extension:status.url",
        "path": "Extension.extension.url",
        "min": 1,
        "max": "1",
        "fixedString": "status"
      },
      {
        "id": "Extension.extension:status.value[x]",
        "path": "Extension.extension.value[x]",
        "min": 1,
        "max": "1",
        "type": [
          {
            "code": "code"
          }
        ],
        "binding": {
          "strength": "required",
          "valueSet": "http://covermymeds.com/fhir/ValueSet/pa-status"
        }
      },
      {
        "id": "Extension.extension:statusDate",
        "path": "Extension.extension",
        "sliceName": "statusDate",
        "min": 0,
        "max": "1"
      },
      {
        "id": "Extension.extension:statusDate.url",
        "path": "Extension.extension.url",
        "min": 1,
        "max": "1",
        "fixedString": "statusDate"
      },
      {
        "id": "Extension.extension:statusDate.value[x]",
        "path": "Extension.extension.value[x]",
        "min": 1,
        "max": "1",
        "type": [
          {
            "code": "dateTime"
          }
        ]
      },
      {
        "id": "Extension.extension:approvalId",
        "path": "Extension.extension",
        "sliceName": "approvalId",
        "min": 0,
        "max": "1"
      },
      {
        "id": "Extension.extension:approvalId.url",
        "path": "Extension.extension.url",
        "min": 1,
        "max": "1",
        "fixedString": "approvalId"
      },
      {
        "id": "Extension.extension:approvalId.value[x]",
        "path": "Extension.extension.value[x]",
        "min": 1,
        "max": "1",
        "type": [
          {
            "code": "string"
          }
        ]
      },
      {
        "id": "Extension.url",
        "path": "Extension.url",
        "min": 1,
        "max": "1",
        "fixedUri": "http://covermymeds.com/fhir/StructureDefinition/prior-authorization-status"
      },
      {
        "id": "Extension.value[x]",
        "path": "Extension.value[x]",
        "min": 0,
        "max": "0"
      }
    ]
  }
}
```

### Custom Operation Implementation

```typescript
// Implementation of the check-prior-authorization operation
import { AidboxClient } from '@aidbox/sdk-r4';
import { PriorAuthorizationService } from '../services/PriorAuthorizationService';

export async function checkPriorAuthorizationOperation(client, request) {
  try {
    // Validate the request
    const parameters = request.resource;
    if (parameters.resourceType !== 'Parameters') {
      throw new Error('Invalid request: expected Parameters resource');
    }
    
    // Extract parameters
    const patientParam = parameters.parameter.find(p => p.name === 'patient');
    const medicationParam = parameters.parameter.find(p => p.name === 'medication');
    
    if (!patientParam || !medicationParam) {
      throw new Error('Missing required parameters: patient and/or medication');
    }
    
    const patientRef = patientParam.valueReference.reference;
    const medicationRef = medicationParam.valueReference.reference;
    
    if (!patientRef || !medicationRef) {
      throw new Error('Invalid references in parameters');
    }
    
    // Create the PA service and check requirements
    const paService = new PriorAuthorizationService(client);
    const result = await paService.checkRequirement(patientRef, medicationRef);
    
    // Format the response as Parameters
    return {
      resourceType: 'Parameters',
      parameter: [
        {
          name: 'required',
          valueBoolean: result.required
        },
        {
          name: 'probability',
          valueDecimal: result.probability
        },
        {
          name: 'requiredDocumentation',
          resource: {
            resourceType: 'DocumentReference',
            status: 'current',
            description: 'Required documentation for prior authorization',
            content: result.documentation.map(doc => ({
              attachment: {
                contentType: 'text/plain',
                title: doc.title,
                description: doc.description
              }
            }))
          }
        }
      ]
    };
  } catch (error) {
    // Handle errors
    console.error('Error in PA check operation:', error);
    return {
      resourceType: 'OperationOutcome',
      issue: [
        {
          severity: 'error',
          code: 'processing',
          diagnostics: error.message
        }
      ]
    };
  }
}

// Register the operation with Aidbox
export function registerCustomOperations(app) {
  app.operation({
    name: 'check-prior-authorization', 
    type: 'system',
    handler: checkPriorAuthorizationOperation
  });
}
```

## Best Practices

### Profile Development

1. **Start with US Core Profiles**: Use US Core profiles as a base when possible to maintain interoperability
2. **Extension Design**: Create extensions that are reusable across resources
3. **Profile Documentation**: Document constraints, extensions, and usage examples
4. **Profile Validation**: Ensure profiles validate correctly against the base FHIR specification
5. **Consistent Naming**: Use consistent naming conventions for profiles and extensions

### Resource Customization

1. **Minimize Custom Resources**: Only create custom resources when standard resources cannot be extended
2. **Reference Standard Resources**: When using custom resources, maintain references to standard resources
3. **Forward Compatibility**: Design custom resources to be forward-compatible with FHIR updates
4. **Implementation Guide**: Develop a comprehensive implementation guide for custom resources
5. **Mapping Definitions**: Provide mappings to standard resources where applicable

### Resource Extensions

1. **Extension Registry**: Maintain a central registry of extensions
2. **Documentation**: Document each extension thoroughly with examples
3. **Validation Rules**: Define clear validation rules for extensions
4. **Minimal Extensions**: Keep extensions to a minimum for better interoperability
5. **Consistent Structure**: Use consistent patterns for similar extensions

### SearchParameter Configuration

1. **Robust Testing**: Test search parameters with a variety of inputs
2. **Performance Considerations**: Ensure search parameters are indexed for performance
3. **Consistent Naming**: Use consistent naming for search parameters
4. **Documentation**: Document search parameter behavior and examples
5. **Parameter Types**: Choose appropriate parameter types for the use case

### Terminology Customization

1. **Standard Codes First**: Use standard codes (SNOMED, LOINC, etc.) when available
2. **Custom Code Documentation**: Document custom codes thoroughly
3. **Mapping Standards**: Provide mappings to standard terminology
4. **Value Set Management**: Implement version control for value sets
5. **Terminology Service**: Use the FHIR terminology service for validation

## Related Resources
- [FHIR Interoperability Platform Advanced Use Cases](./advanced-use-cases.md)
- [FHIR Interoperability Platform Extension Points](./extension-points.md)
- [FHIR Interoperability Platform Core APIs](../02-core-functionality/core-apis.md)
- [FHIR Interoperability Platform Data Model](../02-core-functionality/data-model.md)
- [HL7 FHIR Profiling](https://hl7.org/fhir/R4/profiling.html)
- [US Core Implementation Guide](https://hl7.org/fhir/us/core/)