# Extending FHIR Resources

## Introduction

While FHIR provides a comprehensive set of standard resources, healthcare organizations often need to capture additional data elements specific to their workflows and requirements. This guide explains how to extend FHIR resources to meet specific requirements while maintaining standards compliance. FHIR provides built-in extension mechanisms that allow you to add custom data elements to resources without breaking interoperability.

### Quick Start

1. Determine the appropriate extension mechanism for your use case:
   - Simple extensions for single data elements
   - Complex extensions for structured data
   - Profiles for constraining and extending resources
   - Terminology binding for coded values
2. Define your extensions with unique URLs following the pattern `http://[domain]/fhir/StructureDefinition/[name]`
3. Implement extensions in TypeScript using the `@aidbox/sdk-r4` package
4. Validate resources against profiles to ensure compliance

### Related Components

- [Saving FHIR Resources](saving-fhir-resources.md): Learn how to create and update resources
- [FHIR Server Setup Guide](fhir-server-setup-guide.md): Configure your Aidbox FHIR server
- [Extension Design Decisions](fhir-extension-decisions.md) (Coming Soon): Understand extension design choices

## Extension Mechanisms

FHIR offers several ways to extend resources:

1. **Simple Extensions**: Adding custom data elements to existing resources
2. **Complex Extensions**: Adding structured data with multiple components
3. **Profiles**: Constraining and extending resources for specific use cases
4. **Terminology Binding**: Using custom code systems and value sets

## Creating Extensions

### Simple Extensions

Simple extensions add a single data element to a resource. They're defined with a URL that identifies the extension and a value.

```json
{
  "resourceType": "Patient",
  "id": "example",
  "extension": [
    {
      "url": "http://example.org/fhir/StructureDefinition/preferred-pharmacy",
      "valueReference": {
        "reference": "Organization/pharmacy123"
      }
    }
  ],
  "name": [
    {
      "family": "Smith",
      "given": ["John"]
    }
  ]
}
```

### Complex Extensions

Complex extensions contain multiple components, each with its own URL and value:

```json
{
  "resourceType": "Patient",
  "id": "example",
  "extension": [
    {
      "url": "http://example.org/fhir/StructureDefinition/medication-access-details",
      "extension": [
        {
          "url": "preferred-pharmacy",
          "valueReference": {
            "reference": "Organization/pharmacy123"
          }
        },
        {
          "url": "delivery-preference",
          "valueString": "mail"
        },
        {
          "url": "special-handling",
          "valueBoolean": true
        }
      ]
    }
  ]
}
```

## Defining Extensions with TypeScript

When working with TypeScript and the Aidbox SDK, you can define extensions as interfaces:

```typescript
import { AidboxClient } from '@aidbox/sdk-r4';
import { Patient, Extension } from '@aidbox/sdk-r4/types';

// Define extension interfaces
interface PreferredPharmacyExtension extends Extension {
  url: 'http://example.org/fhir/StructureDefinition/preferred-pharmacy';
  valueReference: {
    reference: string;
  };
}

interface MedicationAccessDetailsExtension extends Extension {
  url: 'http://example.org/fhir/StructureDefinition/medication-access-details';
  extension: [
    {
      url: 'preferred-pharmacy';
      valueReference: {
        reference: string;
      };
    },
    {
      url: 'delivery-preference';
      valueString: string;
    },
    {
      url: 'special-handling';
      valueBoolean: boolean;
    }
  ];
}

// Extended Patient interface
interface ExtendedPatient extends Patient {
  extension?: (PreferredPharmacyExtension | MedicationAccessDetailsExtension)[];
}

// Create a client instance
const client = new AidboxClient({
  baseUrl: 'http://localhost:8888',
  auth: {
    type: 'basic',
    username: 'root',
    password: 'secret'
  }
});

// Create a patient with extensions
async function createPatientWithExtensions(): Promise<ExtendedPatient> {
  const patient: ExtendedPatient = {
    resourceType: 'Patient',
    name: [
      {
        family: 'Smith',
        given: ['John']
      }
    ],
    extension: [
      {
        url: 'http://example.org/fhir/StructureDefinition/medication-access-details',
        extension: [
          {
            url: 'preferred-pharmacy',
            valueReference: {
              reference: 'Organization/pharmacy123'
            }
          },
          {
            url: 'delivery-preference',
            valueString: 'mail'
          },
          {
            url: 'special-handling',
            valueBoolean: true
          }
        ]
      }
    ]
  };

  return await client.create<ExtendedPatient>(patient);
}
```

## Creating Profiles

Profiles are formal definitions of how to use FHIR resources for a specific use case. They're defined using StructureDefinition resources.

### Profile Definition

Here's an example of a StructureDefinition that defines a profile for medication access patients:

```json
{
  "resourceType": "StructureDefinition",
  "id": "medication-access-patient",
  "url": "http://example.org/fhir/StructureDefinition/medication-access-patient",
  "name": "MedicationAccessPatient",
  "status": "active",
  "fhirVersion": "4.0.1",
  "kind": "resource",
  "abstract": false,
  "type": "Patient",
  "baseDefinition": "http://hl7.org/fhir/StructureDefinition/Patient",
  "derivation": "constraint",
  "differential": {
    "element": [
      {
        "id": "Patient",
        "path": "Patient",
        "constraint": [
          {
            "key": "ma-1",
            "severity": "error",
            "human": "Patient must have at least one name",
            "expression": "name.exists()"
          }
        ]
      },
      {
        "id": "Patient.extension",
        "path": "Patient.extension",
        "slicing": {
          "discriminator": [
            {
              "type": "value",
              "path": "url"
            }
          ],
          "ordered": false,
          "rules": "open"
        },
        "min": 0
      },
      {
        "id": "Patient.extension:medicationAccessDetails",
        "path": "Patient.extension",
        "sliceName": "medicationAccessDetails",
        "min": 0,
        "max": "1",
        "type": [
          {
            "code": "Extension",
            "profile": [
              "http://example.org/fhir/StructureDefinition/medication-access-details"
            ]
          }
        ]
      }
    ]
  }
}
```

### Using Profiles with Aidbox

To use a profile in Aidbox, you need to:

1. Upload the StructureDefinition to your Aidbox server
2. Reference the profile in the resource's meta.profile element

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

async function createProfiledPatient(): Promise<Patient> {
  const patient: Patient = {
    resourceType: 'Patient',
    meta: {
      profile: ['http://example.org/fhir/StructureDefinition/medication-access-patient']
    },
    name: [
      {
        family: 'Smith',
        given: ['John']
      }
    ],
    extension: [
      {
        url: 'http://example.org/fhir/StructureDefinition/medication-access-details',
        extension: [
          {
            url: 'preferred-pharmacy',
            valueReference: {
              reference: 'Organization/pharmacy123'
            }
          }
        ]
      }
    ]
  };

  return await client.create<Patient>(patient);
}
```

## Terminology Binding

Terminology binding connects data elements to specific value sets or code systems. This ensures consistent coding across resources.

### Creating a Custom CodeSystem

```json
{
  "resourceType": "CodeSystem",
  "id": "medication-delivery-preferences",
  "url": "http://example.org/fhir/CodeSystem/medication-delivery-preferences",
  "name": "MedicationDeliveryPreferences",
  "status": "active",
  "content": "complete",
  "concept": [
    {
      "code": "mail",
      "display": "Mail Delivery"
    },
    {
      "code": "pickup",
      "display": "Pharmacy Pickup"
    },
    {
      "code": "courier",
      "display": "Courier Delivery"
    }
  ]
}
```

### Creating a ValueSet

```json
{
  "resourceType": "ValueSet",
  "id": "medication-delivery-preferences",
  "url": "http://example.org/fhir/ValueSet/medication-delivery-preferences",
  "name": "MedicationDeliveryPreferences",
  "status": "active",
  "compose": {
    "include": [
      {
        "system": "http://example.org/fhir/CodeSystem/medication-delivery-preferences"
      }
    ]
  }
}
```

### Using Terminology in Extensions

```typescript
import { AidboxClient } from '@aidbox/sdk-r4';
import { Patient, Extension } from '@aidbox/sdk-r4/types';

interface DeliveryPreferenceExtension extends Extension {
  url: 'http://example.org/fhir/StructureDefinition/delivery-preference';
  valueCodeableConcept: {
    coding: [
      {
        system: 'http://example.org/fhir/CodeSystem/medication-delivery-preferences';
        code: string;
        display?: string;
      }
    ];
  };
}

async function createPatientWithCodedExtension(): Promise<Patient> {
  const patient: Patient = {
    resourceType: 'Patient',
    name: [
      {
        family: 'Smith',
        given: ['John']
      }
    ],
    extension: [
      {
        url: 'http://example.org/fhir/StructureDefinition/delivery-preference',
        valueCodeableConcept: {
          coding: [
            {
              system: 'http://example.org/fhir/CodeSystem/medication-delivery-preferences',
              code: 'mail',
              display: 'Mail Delivery'
            }
          ]
        }
      }
    ]
  };

  const client = new AidboxClient({
    baseUrl: 'http://localhost:8888',
    auth: {
      type: 'basic',
      username: 'root',
      password: 'secret'
    }
  });

  return await client.create<Patient>(patient);
}
```

## Validation Rules

Validation ensures that resources conform to profiles and business rules. Aidbox provides several validation mechanisms:

1. **Schema Validation**: Ensures resources conform to the base FHIR schema
2. **Profile Validation**: Ensures resources conform to referenced profiles
3. **Custom Validation**: Allows for custom business rules

### Custom Validation with Aidbox

Aidbox allows you to define custom validation rules using the Zen language:

```clojure
;; Define a validation rule for Patient resources
(defn validate-patient [patient]
  (when-not (get-in patient [:name])
    {:message "Patient must have at least one name"
     :path [:name]
     :type :require})
  
  (when-not (get-in patient [:birthDate])
    {:message "Patient must have a birth date"
     :path [:birthDate]
     :type :require}))

;; Register the validation function
(def validate-patient-rule
  {:zen/tags #{:zen.fhir/validation}
   :resourceType "Patient"
   :validate validate-patient})
```

## Best Practices

1. **Use Standard Extensions When Available**: Before creating custom extensions, check if there's a standard FHIR extension that meets your needs.

2. **Document Your Extensions**: Create clear documentation for your extensions, including their purpose, data types, and usage examples.

3. **Use Consistent URLs**: Use consistent, versioned URLs for your extensions and profiles.

4. **Minimize Custom Extensions**: Only create custom extensions when necessary. Overuse can reduce interoperability.

5. **Test Validation**: Thoroughly test your profiles and extensions to ensure they validate correctly.

6. **Consider Backward Compatibility**: When updating extensions or profiles, consider backward compatibility to avoid breaking existing implementations.

## Conclusion

Extending FHIR resources allows you to adapt the standard to your specific needs while maintaining interoperability. By using extensions, profiles, and terminology binding, you can create a robust, standards-compliant healthcare data model that meets your requirements.
