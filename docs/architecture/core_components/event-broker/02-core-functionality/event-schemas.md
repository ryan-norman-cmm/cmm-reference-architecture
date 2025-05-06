# Event Schemas

## Overview

Event schemas define the structure, format, and validation rules for events flowing through the Event Broker. Well-designed schemas are crucial for ensuring data quality, enabling interoperability, and supporting schema evolution as healthcare requirements change. This document covers the implementation of event schemas using Confluent Cloud Schema Registry, focusing on healthcare-specific considerations, TypeScript implementations, and cloud-native best practices.

## Schema Registry Fundamentals

The Confluent Cloud Schema Registry provides a fully managed, cloud-native repository for managing and validating event schemas in our Kafka-based Event Broker. It serves as the source of truth for event formats and enables several critical capabilities for healthcare data management:

- **Schema Validation**: Ensures all published healthcare events conform to their defined schemas
- **Schema Evolution**: Manages compatible changes to schemas over time while preserving patient data integrity
- **Serialization/Deserialization**: Handles conversion between wire format and TypeScript objects
- **Documentation**: Serves as self-documenting API for healthcare event consumers
- **Governance**: Enforces organizational standards for healthcare event design
- **Multi-Region Support**: Enables global schema availability with regional compliance
- **Security**: Provides fine-grained access control for sensitive healthcare schemas

## Schema Formats in Confluent Cloud

Confluent Cloud Schema Registry supports multiple schema formats, each with different strengths for healthcare data modeling in cloud-native environments:

### Apache Avro

Avro remains our primary schema format for healthcare events in Confluent Cloud due to its compact binary serialization and rich type system. Here's how we define and use Avro schemas with TypeScript:

#### Avro Schema Definition

```json
{
  "type": "record",
  "name": "PatientAdmission",
  "namespace": "org.healthcare.events.patient",
  "doc": "Event generated when a patient is admitted to a facility",
  "fields": [
    {
      "name": "eventId",
      "type": "string",
      "doc": "Unique identifier for this event"
    },
    {
      "name": "eventTimestamp",
      "type": "long",
      "logicalType": "timestamp-millis",
      "doc": "When the event occurred (epoch millis)"
    },
    {
      "name": "patientId",
      "type": "string",
      "doc": "Patient identifier"
    },
    {
      "name": "facilityId",
      "type": "string",
      "doc": "Facility where admission occurred"
    },
    {
      "name": "admissionType",
      "type": {
        "type": "enum",
        "name": "AdmissionType",
        "symbols": ["EMERGENCY", "ELECTIVE", "URGENT", "NEWBORN", "TRANSFER"]
      },
      "doc": "Type of admission"
    },
    {
      "name": "admittingProvider",
      "type": ["null", "string"],
      "default": null,
      "doc": "Provider responsible for admission"
    },
    {
      "name": "admissionTimestamp",
      "type": "long",
      "logicalType": "timestamp-millis",
      "doc": "When the admission occurred"
    },
    {
      "name": "diagnosisCodes",
      "type": {
        "type": "array",
        "items": "string"
      },
      "doc": "Initial diagnosis codes"
    },
    {
      "name": "metadata",
      "type": {
        "type": "map",
        "values": "string"
      },
      "doc": "Additional contextual information"
    }
  ]
}
```

#### TypeScript Interface

We generate TypeScript interfaces from Avro schemas to ensure type safety:

```typescript
// Generated TypeScript interface for PatientAdmission schema
export enum AdmissionType {
  EMERGENCY = 'EMERGENCY',
  ELECTIVE = 'ELECTIVE',
  URGENT = 'URGENT',
  NEWBORN = 'NEWBORN',
  TRANSFER = 'TRANSFER'
}

export interface PatientAdmission {
  eventId: string;
  eventTimestamp: number; // timestamp-millis (epoch milliseconds)
  patientId: string;
  facilityId: string;
  admissionType: AdmissionType;
  admittingProvider: string | null;
  admissionTimestamp: number; // timestamp-millis (epoch milliseconds)
  diagnosisCodes: string[];
  metadata: Record<string, string>;
}
```

**Key Advantages for Healthcare in Confluent Cloud:**
- **Compact Binary Format**: Efficient for high-volume healthcare data with reduced cloud bandwidth costs
- **Rich Type System**: Supports complex healthcare data structures with TypeScript type safety
- **Built-in Documentation**: Self-documenting with field descriptions for healthcare domain knowledge
- **Strong Validation**: Enforces data quality at the source with cloud-based schema validation
- **Multi-Region Support**: Schemas can be replicated across regions for global healthcare operations
- **TypeScript Integration**: Native TypeScript support for modern healthcare applications

### JSON Schema

JSON Schema provides a more flexible approach for certain healthcare events in Confluent Cloud, particularly when working with external systems that prefer JSON:

#### JSON Schema Definition

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "http://healthcare.org/schemas/MedicationDispensed.json",
  "title": "Medication Dispensed",
  "description": "Event generated when a medication is dispensed to a patient",
  "type": "object",
  "properties": {
    "eventId": {
      "type": "string",
      "description": "Unique identifier for this event"
    },
    "eventTimestamp": {
      "type": "string",
      "format": "date-time",
      "description": "When the event occurred (ISO-8601)"
    },
    "patientId": {
      "type": "string",
      "description": "Patient identifier"
    },
    "pharmacyId": {
      "type": "string",
      "description": "Pharmacy identifier"
    },
    "medication": {
      "type": "object",
      "description": "Medication details",
      "properties": {
        "ndc": {
          "type": "string",
          "description": "National Drug Code"
        },
        "name": {
          "type": "string",
          "description": "Medication name"
        },
        "strength": {
          "type": "string",
          "description": "Medication strength"
        },
        "quantity": {
          "type": "number",
          "description": "Quantity dispensed"
        },
        "daysSupply": {
          "type": "integer",
          "description": "Days supply dispensed"
        }
      },
      "required": ["ndc", "name", "quantity"]
    },
    "dispensedTimestamp": {
      "type": "string",
      "format": "date-time",
      "description": "When the medication was dispensed"
    },
    "dispensingProvider": {
      "type": "string",
      "description": "Provider who dispensed the medication"
    }
  },
  "required": ["eventId", "eventTimestamp", "patientId", "pharmacyId", "medication", "dispensedTimestamp"]
}
```

#### TypeScript Interface

We define TypeScript interfaces for JSON Schema to ensure type safety in our applications:

```typescript
// TypeScript interface for MedicationDispensed schema
export interface MedicationDispensed {
  eventId: string;
  eventTimestamp: string; // ISO-8601 date-time string
  patientId: string;
  pharmacyId: string;
  medication: {
    ndc: string;
    name: string;
    strength?: string;
    quantity: number;
    daysSupply?: number;
  };
  dispensedTimestamp: string; // ISO-8601 date-time string
  dispensingProvider: string;
}

// Type guard to validate MedicationDispensed objects
export function isMedicationDispensed(obj: any): obj is MedicationDispensed {
  return (
    typeof obj === 'object' &&
    obj !== null &&
    typeof obj.eventId === 'string' &&
    typeof obj.eventTimestamp === 'string' &&
    typeof obj.patientId === 'string' &&
    typeof obj.pharmacyId === 'string' &&
    typeof obj.medication === 'object' &&
    typeof obj.medication.ndc === 'string' &&
    typeof obj.medication.name === 'string' &&
    typeof obj.medication.quantity === 'number' &&
    typeof obj.dispensedTimestamp === 'string' &&
    typeof obj.dispensingProvider === 'string'
  );
}
```

#### Confluent Cloud Schema Registry Integration

```typescript
// Example: Registering JSON Schema in Confluent Cloud Schema Registry
import axios from 'axios';

async function registerJsonSchema(
  schemaName: string,
  schemaJson: object,
  apiKey: string,
  apiSecret: string,
  schemaRegistryUrl: string
): Promise<number> {
  try {
    const auth = Buffer.from(`${apiKey}:${apiSecret}`).toString('base64');
    
    const response = await axios({
      method: 'POST',
      url: `${schemaRegistryUrl}/subjects/${schemaName}/versions`,
      headers: {
        'Content-Type': 'application/vnd.schemaregistry.v1+json',
        'Authorization': `Basic ${auth}`
      },
      data: {
        schemaType: 'JSON',
        schema: JSON.stringify(schemaJson)
      }
    });
    
    console.log(`Registered JSON Schema for ${schemaName}, version: ${response.data.id}`);
    return response.data.id;
  } catch (error) {
    console.error('Error registering JSON Schema:', error.response?.data || error.message);
    throw error;
  }
}
```

**Key Advantages for Healthcare in Confluent Cloud:**
- **Human Readable**: Easier to understand for non-technical healthcare stakeholders
- **Widespread Adoption**: Familiar to many healthcare developers and systems
- **Flexible Validation**: Supports complex validation rules for healthcare data
- **Web Integration**: Native support in web and mobile healthcare applications
- **Self-Describing**: Schema and data in the same format for easier debugging
- **TypeScript Support**: Strong typing for healthcare data validation
- **Cloud-Native Management**: Centralized schema management in Confluent Cloud

### Protocol Buffers

Protocol Buffers (Protobuf) are used in Confluent Cloud for high-performance healthcare scenarios where efficiency is critical:

#### Protobuf Schema Definition

```protobuf
syntax = "proto3";

package healthcare.events.clinical;

import "google/protobuf/timestamp.proto";

message VitalSigns {
  string event_id = 1;
  int64 event_timestamp = 2;  // Milliseconds since epoch
  string patient_id = 3;
  string encounter_id = 4;
  string provider_id = 5;
  string facility_id = 6;
  
  message VitalSign {
    string code = 1;  // LOINC code
    string display = 2;  // Human-readable name
    double value = 3;  // Measurement value
    string unit = 4;  // Unit of measure
  }
  
  repeated VitalSign vital_signs = 7;
  
  string location = 9;
  map<string, string> metadata = 10;
}
```

#### TypeScript Integration

We use protobufjs with TypeScript for type-safe Protocol Buffer handling:

```typescript
// Generated TypeScript interfaces from Protocol Buffers
export interface VitalSigns {
  eventId: string;
  eventTimestamp: number; // Milliseconds since epoch
  patientId: string;
  encounterId: string;
  providerId: string;
  facilityId: string;
  vitalSigns: VitalSign[];
  deviceId?: string;
  location?: string;
  metadata?: { [key: string]: string };
}

export interface VitalSign {
  code: string; // LOINC code
  display: string; // Human-readable name
  value: number; // Measurement value
  unit: string; // Unit of measure
}

// Example: Using Protocol Buffers with Confluent Cloud Schema Registry
import axios from 'axios';
import * as protobuf from 'protobufjs';

/**
 * Register a Protocol Buffer schema with Confluent Cloud Schema Registry
 */
async function registerProtobufSchema(
  schemaName: string,
  protoDefinition: string,
  apiKey: string,
  apiSecret: string,
  schemaRegistryUrl: string
): Promise<number> {
  try {
    const auth = Buffer.from(`${apiKey}:${apiSecret}`).toString('base64');
    
    const response = await axios({
      method: 'POST',
      url: `${schemaRegistryUrl}/subjects/${schemaName}/versions`,
      headers: {
        'Content-Type': 'application/vnd.schemaregistry.v1+json',
        'Authorization': `Basic ${auth}`
      },
      data: {
        schemaType: 'PROTOBUF',
        schema: protoDefinition
      }
    });
    
    console.log(`Registered Protobuf Schema for ${schemaName}, version: ${response.data.id}`);
    return response.data.id;
  } catch (error) {
    console.error('Error registering Protobuf Schema:', error.response?.data || error.message);
    throw error;
  }
}

/**
 * Create a Protobuf message for vital signs
 */
async function createVitalSignsMessage(
  patientId: string,
  encounterId: string,
  vitalSigns: VitalSign[]
): Promise<Uint8Array> {
  // Load the Protobuf definition
  const root = await protobuf.load('healthcare_events.proto');
  
  // Get the message type
  const VitalSignsMessage = root.lookupType('healthcare.events.clinical.VitalSigns');
  
  // Create the message payload
  const payload = {
    eventId: `vs-${Date.now()}-${Math.random().toString(36).substring(2, 10)}`,
    eventTimestamp: Date.now(),
    patientId,
    encounterId,
    providerId: 'provider-123',
    facilityId: 'facility-456',
    vitalSigns,
    metadata: {
      source: 'bedside-monitor',
      version: '1.0.0'
    }
  };
  
  // Verify the payload
  const verificationError = VitalSignsMessage.verify(payload);
  if (verificationError) {
    throw new Error(`Invalid vital signs data: ${verificationError}`);
  }
  
  // Create the message
  const message = VitalSignsMessage.create(payload);
  
  // Encode the message
  return VitalSignsMessage.encode(message).finish();
}
```

**Key Advantages for Healthcare in Confluent Cloud:**
- **Extremely Efficient**: Most compact format for high-volume healthcare data, reducing cloud costs
- **Strong Typing**: Enforces data integrity with TypeScript integration
- **Cross-Language Support**: Works across multiple programming languages for diverse healthcare systems
- **Versioning**: Built-in versioning capabilities for evolving healthcare standards
- **High Performance**: Optimized for real-time healthcare applications like patient monitoring
- **Cloud-Native Integration**: Seamless integration with Confluent Cloud Schema Registry
- **Performance**: Fast serialization/deserialization for time-sensitive healthcare applications

## Schema Design Principles

### Healthcare Event Schema Standards

When designing schemas for healthcare events in Confluent Cloud, follow these key principles with TypeScript integration:

1. **Consistent Event Metadata with TypeScript**
   - Every event should include standard metadata fields with strong typing:
   ```typescript
   export interface EventMetadata {
     eventId: string;           // UUID v4 for global uniqueness
     eventTimestamp: string;    // ISO-8601 with timezone
     eventType: string;         // Classification of the event
     eventSource: string;       // System that generated the event
     version: string;           // Schema version
     region?: string;           // Cloud region where event originated
     correlationId?: string;    // For event correlation
     traceId?: string;          // For distributed tracing
   }
   
   // Base interface for all healthcare events
   export interface HealthcareEvent {
     metadata: EventMetadata;
     // Event-specific fields will be added by extending interfaces
   }
   ```

2. **Patient Context with Privacy Controls**
   - Include patient identifiers consistently with TypeScript interfaces:
   ```typescript
   export interface PatientContext {
     patientId: string;         // Primary patient identifier
     mrn?: string;             // Medical record number (when applicable)
     // Use a Record for flexible external identifiers
     externalIds?: Record<string, string>; // Map of identifiers from external systems
     // Add data residency and privacy flags for cloud compliance
     dataResidency?: string;    // Required region for data storage
     dataPrivacyLevel: PrivacyLevel; // Controls data handling requirements
   }
   
   export enum PrivacyLevel {
     PHI = 'PHI',           // Protected Health Information (highest protection)
     PII = 'PII',           // Personally Identifiable Information
     DEIDENTIFIED = 'DEIDENTIFIED', // De-identified data
     PUBLIC = 'PUBLIC'      // Public information (lowest protection)
   }
   
   // Example patient event interface
   export interface PatientEvent extends HealthcareEvent {
     patient: PatientContext;
     // Event-specific fields
   }
   ```

3. **Healthcare Terminology with Cloud Registry Integration**
   - Use standard coding systems with TypeScript and Schema Registry validation:
   ```typescript
   export interface Coding {
     code: string;             // The actual code value
     system: string;           // The coding system (e.g., "http://loinc.org")
     display: string;          // Human-readable description
     version?: string;         // Coding system version
   }
   
   // Example: Function to validate codes against Confluent Cloud Schema Registry
   async function validateCoding(
     coding: Coding,
     apiKey: string,
     apiSecret: string,
     schemaRegistryUrl: string
   ): Promise<boolean> {
     const auth = Buffer.from(`${apiKey}:${apiSecret}`).toString('base64');
     
     try {
       // Fetch the terminology value set from Schema Registry
       const response = await axios({
         method: 'GET',
         url: `${schemaRegistryUrl}/subjects/terminology.${coding.system}/versions/latest`,
         headers: {
           'Authorization': `Basic ${auth}`
         }
       });
       
       // Parse the schema and check if the code is valid
       const schema = JSON.parse(response.data.schema);
       return schema.codes.includes(coding.code);
     } catch (error) {
       console.error('Error validating code:', error.message);
       return false;
     }
   }
   ```

4. **Temporal Precision with TypeScript**
   - Use strongly typed date handling in TypeScript:
   ```typescript
   export interface TemporalEvent extends HealthcareEvent {
     // ISO-8601 string with timezone for human readability and interoperability
     eventTime: string;  // When the event occurred in ISO-8601 format
     
     // Epoch milliseconds for precise calculations and sorting
     eventTimeEpochMs: number; // Same time as eventTime but in epoch milliseconds
     
     // Processing timestamp for analytics and monitoring
     processingTime: string; // When the event was processed
     
     // Timezone information for cross-region healthcare operations
     timezone: string; // e.g., 'America/New_York'
   }
   
   // Helper function to create consistent timestamps
   export function createTemporalFields(): Pick<TemporalEvent, 'eventTime' | 'eventTimeEpochMs' | 'processingTime' | 'timezone'> {
     const now = new Date();
     const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone;
     
     return {
       eventTime: now.toISOString(),
       eventTimeEpochMs: now.getTime(),
       processingTime: now.toISOString(),
       timezone
     };
   }
   ```

5. **Privacy Considerations for Cloud Environments**
   - Implement TypeScript-based privacy controls for multi-region cloud deployments:
   ```typescript
   // Privacy levels for healthcare data in Confluent Cloud
   export enum PrivacyLevel {
     PHI = 'PHI',           // Protected Health Information (highest protection)
     PII = 'PII',           // Personally Identifiable Information
     DEIDENTIFIED = 'DEIDENTIFIED', // De-identified data
     PUBLIC = 'PUBLIC'      // Public information (lowest protection)
   }
   
   // Data residency requirements for healthcare data
   export interface DataResidencyRequirement {
     requiredRegion?: string;     // Region where data must be stored (e.g., 'us-east-1')
     allowedRegions?: string[];   // Regions where data may be stored
     prohibitedRegions?: string[]; // Regions where data must not be stored
     dataClassification: PrivacyLevel; // Privacy level of the data
   }
   
   // Example: Function to check if a Confluent Cloud region meets residency requirements
   export function validateDataResidency(
     eventData: { dataResidency?: DataResidencyRequirement },
     currentRegion: string
   ): boolean {
     if (!eventData.dataResidency) return true; // No requirements specified
     
     const { requiredRegion, allowedRegions, prohibitedRegions } = eventData.dataResidency;
     
     // Check if a specific region is required
     if (requiredRegion && requiredRegion !== currentRegion) {
       console.error(`Data must be stored in ${requiredRegion}, but current region is ${currentRegion}`);
       return false;
     }
     
     // Check if current region is allowed
     if (allowedRegions && allowedRegions.length > 0) {
       if (!allowedRegions.includes(currentRegion)) {
         console.error(`Current region ${currentRegion} is not in allowed regions: ${allowedRegions.join(', ')}`);
         return false;
       }
     }
     
     // Check if current region is prohibited
     if (prohibitedRegions && prohibitedRegions.includes(currentRegion)) {
       console.error(`Current region ${currentRegion} is in prohibited regions: ${prohibitedRegions.join(', ')}`);
       return false;
     }
     
     return true;
   }
   ```

## Schema Evolution in Confluent Cloud

Healthcare data requirements change over time. Confluent Cloud Schema Registry provides robust schema evolution capabilities that allow us to adapt schemas while maintaining compatibility with existing consumers and historical data.

### Evolution Principles with TypeScript

1. **Backward Compatibility in Confluent Cloud**
   - New schema versions should be readable by older consumers
   - Configure Schema Registry compatibility settings in Confluent Cloud
   - TypeScript interfaces should maintain backward compatibility:
   ```typescript
   // Original interface
   export interface PatientData {
     patientId: string;
     name: string;
     dateOfBirth: string;
   }
   
   // Evolved interface with backward compatibility
   export interface PatientDataV2 {
     patientId: string;
     name: string;
     dateOfBirth: string;
     // New fields are optional to maintain backward compatibility
     phoneNumber?: string;
     emailAddress?: string;
   }
   
   // Function to check if a schema update is backward compatible
   export async function checkBackwardCompatibility(
     subject: string,
     newSchema: string,
     apiKey: string,
     apiSecret: string,
     schemaRegistryUrl: string
   ): Promise<boolean> {
     const auth = Buffer.from(`${apiKey}:${apiSecret}`).toString('base64');
     
     try {
       const response = await axios({
         method: 'POST',
         url: `${schemaRegistryUrl}/compatibility/subjects/${subject}/versions/latest`,
         headers: {
           'Content-Type': 'application/vnd.schemaregistry.v1+json',
           'Authorization': `Basic ${auth}`
         },
         data: {
           schema: newSchema
         }
       });
       
       return response.data.is_compatible;
     } catch (error) {
       console.error('Error checking schema compatibility:', error.message);
       return false;
     }
   }
   ```

2. **Use Optional Fields with TypeScript**
   - Make new fields optional with defaults using TypeScript's optional properties
   - Implement helper functions to handle missing fields in older data versions
   ```typescript
   // Helper function to safely access potentially missing fields
   export function getFieldWithDefault<T, K extends keyof T>(
     obj: T,
     field: K,
     defaultValue: T[K]
   ): T[K] {
     return obj[field] !== undefined ? obj[field] : defaultValue;
   }
   
   // Example usage with evolved schema
   function processPatient(patient: PatientDataV2) {
     // Safely access new fields that might not exist in older data
     const phoneNumber = getFieldWithDefault(patient, 'phoneNumber', 'Unknown');
     const emailAddress = getFieldWithDefault(patient, 'emailAddress', 'No email provided');
     
     // Process patient data...
   }
   ```

3. **Avoid Removing Fields with TypeScript**
   - Healthcare data often has long retention requirements
   - Use TypeScript interfaces to maintain field structure while marking as deprecated:
   ```typescript
   // Interface with deprecated field
   export interface MedicationOrder {
     orderId: string;
     patientId: string;
     medication: string;
     dosage: string;
     /**
      * @deprecated Use 'prescribingProvider' instead
      */
     doctor: string;
     prescribingProvider: string;
   }
   
   // Helper function to migrate from deprecated fields
   export function migrateDeprecatedFields<T>(data: T): T {
     // Create a copy to avoid modifying the original
     const result = { ...data };
     
     // Example: Migrate from 'doctor' to 'prescribingProvider'
     if ('doctor' in result && !('prescribingProvider' in result)) {
       (result as any).prescribingProvider = (result as any).doctor;
     }
     
     return result;
   }
   ```

4. **Version Schemas Explicitly with Confluent Cloud**
   - Include version in schema name and TypeScript interfaces
   - Use Confluent Cloud Schema Registry for version management:
   ```typescript
   // Function to register a new schema version in Confluent Cloud
   export async function registerSchemaVersion(
     subject: string,
     schema: string,
     apiKey: string,
     apiSecret: string,
     schemaRegistryUrl: string
   ): Promise<number> {
     const auth = Buffer.from(`${apiKey}:${apiSecret}`).toString('base64');
     
     try {
       const response = await axios({
         method: 'POST',
         url: `${schemaRegistryUrl}/subjects/${subject}/versions`,
         headers: {
           'Content-Type': 'application/vnd.schemaregistry.v1+json',
           'Authorization': `Basic ${auth}`
         },
         data: {
           schema
         }
       });
       
       console.log(`Registered schema version ${response.data.id} for ${subject}`);
       return response.data.id;
     } catch (error) {
       console.error('Error registering schema version:', error.message);
       throw error;
     }
   }
   ```

5. **Test Compatibility Before Deployment with CI/CD**
   - Verify compatibility with the Confluent Cloud Schema Registry API
   - Automate compatibility testing in CI/CD pipelines:
   ```typescript
   // Example: GitHub Actions workflow for schema compatibility testing
   /*
   name: Schema Compatibility Check
   
   on:
     pull_request:
       paths:
         - 'schemas/**'
   
   jobs:
     check-compatibility:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v2
         - uses: actions/setup-node@v2
           with:
             node-version: '16'
         - name: Install dependencies
           run: npm ci
         - name: Run schema compatibility tests
           run: npm run test:schema-compatibility
           env:
             CONFLUENT_CLOUD_API_KEY: ${{ secrets.CONFLUENT_CLOUD_API_KEY }}
             CONFLUENT_CLOUD_API_SECRET: ${{ secrets.CONFLUENT_CLOUD_API_SECRET }}
             SCHEMA_REGISTRY_URL: ${{ secrets.SCHEMA_REGISTRY_URL }}
   */
   
   // Implementation of schema compatibility test
   export async function testSchemaCompatibility(
     schemaDirectory: string,
     apiKey: string,
     apiSecret: string,
     schemaRegistryUrl: string
   ): Promise<boolean> {
     let allCompatible = true;
     const schemaFiles = fs.readdirSync(schemaDirectory);
     
     for (const file of schemaFiles) {
       if (!file.endsWith('.json')) continue;
       
       const schemaPath = path.join(schemaDirectory, file);
       const schema = fs.readFileSync(schemaPath, 'utf8');
       const subject = path.basename(file, '.json');
       
       try {
         const isCompatible = await checkBackwardCompatibility(
           subject,
           schema,
           apiKey,
           apiSecret,
           schemaRegistryUrl
         );
         
         if (!isCompatible) {
           console.error(`Schema ${subject} is not backward compatible`);
           allCompatible = false;
         } else {
           console.log(`Schema ${subject} is backward compatible`);
         }
       } catch (error) {
         console.error(`Error checking compatibility for ${subject}:`, error.message);
         allCompatible = false;
       }
     }
     
     return allCompatible;
   }
   ```

## Confluent Cloud Schema Registry Implementation

### Cloud Configuration

Confluent Cloud Schema Registry is configured for healthcare environments with the following settings:

```typescript
// Example: TypeScript configuration for Confluent Cloud Schema Registry
import { SchemaRegistryAPIClient } from '@confluent/schema-registry';
import axios from 'axios';

/**
 * Configure Confluent Cloud Schema Registry for healthcare environments
 */
async function configureSchemaRegistry(
  apiKey: string,
  apiSecret: string,
  schemaRegistryUrl: string
): Promise<void> {
  try {
    // Create authentication header
    const auth = Buffer.from(`${apiKey}:${apiSecret}`).toString('base64');
    
    // Configure compatibility settings for healthcare data
    const compatibilitySettings = {
      'avro.compatibility.level': 'BACKWARD',
      'json.schema.compatibility.level': 'BACKWARD',
      'protobuf.compatibility.level': 'BACKWARD'
    };
    
    // Apply global compatibility settings
    await axios({
      method: 'PUT',
      url: `${schemaRegistryUrl}/config`,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Basic ${auth}`
      },
      data: {
        compatibility: 'BACKWARD'
      }
    });
    
    console.log('Configured global compatibility settings for Schema Registry');
    
    // Configure subject naming strategy for healthcare data
    // This ensures consistent naming across healthcare applications
    await axios({
      method: 'PUT',
      url: `${schemaRegistryUrl}/config/subject.name.strategy`,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Basic ${auth}`
      },
      data: {
        'subject.name.strategy': 'io.confluent.kafka.serializers.subject.TopicNameStrategy'
      }
    });
    
    console.log('Configured subject naming strategy for healthcare schemas');
    
    // Create Schema Registry client for programmatic access
    const schemaRegistry = new SchemaRegistryAPIClient({
      baseUrl: schemaRegistryUrl,
      auth: {
        username: apiKey,
        password: apiSecret
      }
    });
    
    return schemaRegistry;
  } catch (error) {
    console.error('Error configuring Schema Registry:', error.message);
    throw error;
  }
}

/**
 * Configure multi-region Schema Registry for healthcare data
 */
async function configureMultiRegionSchemaRegistry(
  primaryRegion: {
    apiKey: string;
    apiSecret: string;
    schemaRegistryUrl: string;
  },
  secondaryRegions: Array<{
    apiKey: string;
    apiSecret: string;
    schemaRegistryUrl: string;
  }>
): Promise<void> {
  try {
    // Configure primary region
    await configureSchemaRegistry(
      primaryRegion.apiKey,
      primaryRegion.apiSecret,
      primaryRegion.schemaRegistryUrl
    );
    
    // Configure secondary regions with import mode
    for (const region of secondaryRegions) {
      const auth = Buffer.from(`${region.apiKey}:${region.apiSecret}`).toString('base64');
      
      // Set import mode for secondary regions
      await axios({
        method: 'PUT',
        url: `${region.schemaRegistryUrl}/mode`,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Basic ${auth}`
        },
        data: {
          mode: 'IMPORT'
        }
      });
      
      console.log(`Configured Schema Registry in import mode for region: ${region.schemaRegistryUrl}`);
    }
  } catch (error) {
    console.error('Error configuring multi-region Schema Registry:', error.message);
    throw error;
  }
}
```

### Cloud-Native Schema Management Workflow

The workflow for managing healthcare event schemas in Confluent Cloud follows a modern CI/CD approach:

1. **Development with TypeScript**
   ```typescript
   // Example: Schema development workflow with TypeScript
   import { readFileSync, writeFileSync } from 'fs';
   import { compile } from 'json-schema-to-typescript';
   
   /**
    * Generate TypeScript interfaces from JSON Schema
    */
   async function generateTypeScriptInterfaces(
     schemaPath: string,
     outputPath: string
   ): Promise<void> {
     try {
       // Read the schema file
       const schema = JSON.parse(readFileSync(schemaPath, 'utf8'));
       
       // Generate TypeScript interface
       const ts = await compile(schema, schema.title, {
         bannerComment: `/**
 * Generated TypeScript interface for ${schema.title}
 * Generated from schema version ${schema.version || '1.0.0'}
 * DO NOT EDIT DIRECTLY
 */`,
         style: {
           singleQuote: true,
           semi: true,
           tabWidth: 2
         }
       });
       
       // Write the TypeScript interface to file
       writeFileSync(outputPath, ts);
       console.log(`Generated TypeScript interface at ${outputPath}`);
     } catch (error) {
       console.error('Error generating TypeScript interface:', error.message);
       throw error;
     }
   }
   ```

2. **Automated Testing with CI/CD**
   - Implement automated schema validation in CI/CD pipelines
   - Test with producer and consumer applications
   - Verify compatibility with existing schemas
   - Validate healthcare-specific requirements
   ```typescript
   // Example: Jest test for schema validation
   import Ajv from 'ajv';
   import { readFileSync } from 'fs';
   
   describe('Healthcare Schema Validation', () => {
     const ajv = new Ajv({ allErrors: true });
     
     test('Patient Admission schema validates sample data', () => {
       // Load schema
       const schema = JSON.parse(readFileSync('./schemas/PatientAdmission.json', 'utf8'));
       const validate = ajv.compile(schema);
       
       // Sample data
       const data = {
         eventId: 'evt-123456',
         eventTimestamp: '2025-05-06T01:07:35-04:00',
         patientId: 'pat-789012',
         facilityId: 'fac-345678',
         admissionType: 'EMERGENCY',
         admissionTimestamp: '2025-05-06T01:00:00-04:00',
         diagnosisCodes: ['R07.9', 'I10']
       };
       
       // Validate
       const valid = validate(data);
       if (!valid) console.log(validate.errors);
       expect(valid).toBeTruthy();
     });
   });
   ```

3. **Approval with Pull Request Workflow**
   - Submit schema changes via pull request
   - Automated compatibility checks with Confluent Cloud Schema Registry
   - Review by healthcare domain experts
   - Compliance verification for healthcare regulations

4. **Deployment to Confluent Cloud**
   - Automated schema registration in Confluent Cloud Schema Registry
   - Multi-region deployment for global healthcare operations
   - Version management with semantic versioning
   ```typescript
   // Example: Automated schema deployment to Confluent Cloud
   import { glob } from 'glob';
   import { readFileSync } from 'fs';
   import { SchemaRegistryAPIClient } from '@confluent/schema-registry';
   
   async function deploySchemas(
     schemaDirectory: string,
     apiKey: string,
     apiSecret: string,
     schemaRegistryUrl: string
   ): Promise<void> {
     // Create Schema Registry client
     const schemaRegistry = new SchemaRegistryAPIClient({
       baseUrl: schemaRegistryUrl,
       auth: {
         username: apiKey,
         password: apiSecret
       }
     });
     
     // Find all schema files
     const schemaFiles = glob.sync(`${schemaDirectory}/**/*.json`);
     
     for (const file of schemaFiles) {
       const schema = JSON.parse(readFileSync(file, 'utf8'));
       const subject = `${schema.namespace}.${schema.name}`;
       
       try {
         // Register schema
         const { id } = await schemaRegistry.register(
           subject,
           { schema: JSON.stringify(schema), schemaType: 'AVRO' }
         );
         
         console.log(`Registered schema ${subject} with ID ${id}`);
       } catch (error) {
         console.error(`Error registering schema ${subject}:`, error.message);
         throw error;
       }
     }
   }
   ```
   - Track schema usage metrics

5. **Schema Evolution**
   - Propose changes through governance process
   - Test compatibility with existing data
   - Deploy with appropriate versioning

## Healthcare Schema Examples in Confluent Cloud

### Clinical Event Schemas with TypeScript

#### Patient Admission

The patient admission event captures when a patient is admitted to a healthcare facility, implemented with TypeScript and Confluent Cloud:

**Avro Schema:**
```json
{
  "type": "record",
  "name": "PatientAdmission",
  "namespace": "org.healthcare.events.clinical",
  "fields": [
    { "name": "eventId", "type": "string" },
    { "name": "eventTimestamp", "type": { "type": "long", "logicalType": "timestamp-millis" } },
    { "name": "patientId", "type": "string" },
    { "name": "encounterType", "type": { "type": "enum", "name": "EncounterType", "symbols": ["INPATIENT", "EMERGENCY", "AMBULATORY", "VIRTUAL"] } },
    { "name": "admittingDiagnosis", "type": ["null", { "type": "array", "items": "string" }], "default": null },
    { "name": "admittingProvider", "type": ["null", "string"], "default": null },
    { "name": "facilityId", "type": "string" },
    { "name": "bedId", "type": ["null", "string"], "default": null },
    { "name": "admissionTimestamp", "type": { "type": "long", "logicalType": "timestamp-millis" } },
    { "name": "dataPrivacyLevel", "type": { "type": "enum", "name": "PrivacyLevel", "symbols": ["PHI", "PII", "DEIDENTIFIED", "PUBLIC"] }, "default": "PHI" },
    { "name": "region", "type": ["null", "string"], "default": null }
  ]
}
```

**TypeScript Interface:**
```typescript
// Generated TypeScript interface for PatientAdmission schema
export enum EncounterType {
  INPATIENT = 'INPATIENT',
  EMERGENCY = 'EMERGENCY',
  AMBULATORY = 'AMBULATORY',
  VIRTUAL = 'VIRTUAL'
}

export enum PrivacyLevel {
  PHI = 'PHI',
  PII = 'PII',
  DEIDENTIFIED = 'DEIDENTIFIED',
  PUBLIC = 'PUBLIC'
}

export interface PatientAdmission {
  eventId: string;
  eventTimestamp: number; // timestamp-millis
  patientId: string;
  encounterType: EncounterType;
  admittingDiagnosis: string[] | null;
  admittingProvider: string | null;
  facilityId: string;
  bedId: string | null;
  admissionTimestamp: number; // timestamp-millis
  dataPrivacyLevel: PrivacyLevel;
  region: string | null;
}

// Example: Publishing a patient admission event to Confluent Cloud
import { Kafka } from 'kafkajs';
import { SchemaRegistry } from '@kafkajs/confluent-schema-registry';

async function publishPatientAdmission(
  patientAdmission: PatientAdmission,
  bootstrapServers: string,
  apiKey: string,
  apiSecret: string,
  schemaRegistryUrl: string,
  schemaRegistryApiKey: string,
  schemaRegistryApiSecret: string
): Promise<void> {
  // Configure Kafka client for Confluent Cloud
  const kafka = new Kafka({
    clientId: 'healthcare-admission-producer',
    brokers: [bootstrapServers],
    ssl: true,
    sasl: {
      mechanism: 'plain',
      username: apiKey,
      password: apiSecret
    }
  });
  
  // Configure Schema Registry client
  const registry = new SchemaRegistry({
    host: schemaRegistryUrl,
    auth: {
      username: schemaRegistryApiKey,
      password: schemaRegistryApiSecret
    }
  });
  
  // Get the schema ID
  const schemaId = await registry.getLatestSchemaId('org.healthcare.events.clinical.PatientAdmission-value');
  
  // Encode the message with the schema
  const encodedMessage = await registry.encode(schemaId, patientAdmission);
  
  // Create producer
  const producer = kafka.producer();
  await producer.connect();
  
  // Send the message
  await producer.send({
    topic: 'healthcare.clinical.patient-admissions',
    messages: [{
      key: patientAdmission.patientId,
      value: encodedMessage,
      headers: {
        'data-privacy-level': patientAdmission.dataPrivacyLevel,
        'source-region': patientAdmission.region || 'unknown'
      }
    }]
  });
  
  await producer.disconnect();
}
```

#### Medication Order

The medication order event captures when a provider orders medication for a patient, implemented with TypeScript and Confluent Cloud:

**Avro Schema:**
```json
{
  "type": "record",
  "name": "MedicationOrder",
  "namespace": "org.healthcare.events.clinical",
  "fields": [
    { "name": "eventId", "type": "string" },
    { "name": "eventTimestamp", "type": { "type": "long", "logicalType": "timestamp-millis" } },
    { "name": "patientId", "type": "string" },
    { "name": "encounterId", "type": ["null", "string"], "default": null },
    { "name": "orderingProvider", "type": "string" },
    { "name": "medication", "type": {
      "type": "record",
      "name": "Medication",
      "fields": [
        { "name": "code", "type": "string" },
        { "name": "display", "type": "string" },
        { "name": "system", "type": "string", "default": "http://www.nlm.nih.gov/research/umls/rxnorm" }
      ]
    }},
    { "name": "dosage", "type": "string" },
    { "name": "frequency", "type": "string" },
    { "name": "route", "type": "string" },
    { "name": "startDate", "type": { "type": "long", "logicalType": "timestamp-millis" } },
    { "name": "endDate", "type": ["null", { "type": "long", "logicalType": "timestamp-millis" }], "default": null },
    { "name": "orderStatus", "type": { "type": "enum", "name": "OrderStatus", "symbols": ["ACTIVE", "COMPLETED", "CANCELLED", "DRAFT", "SUSPENDED"] } },
    { "name": "dataPrivacyLevel", "type": { "type": "enum", "name": "PrivacyLevel", "symbols": ["PHI", "PII", "DEIDENTIFIED", "PUBLIC"] }, "default": "PHI" }
  ]
}
```

**TypeScript Interface:**
```typescript
// Generated TypeScript interface for MedicationOrder schema
export enum OrderStatus {
  ACTIVE = 'ACTIVE',
  COMPLETED = 'COMPLETED',
  CANCELLED = 'CANCELLED',
  DRAFT = 'DRAFT',
  SUSPENDED = 'SUSPENDED'
}

export interface Medication {
  code: string;
  display: string;
  system: string;
}

export interface MedicationOrder {
  eventId: string;
  eventTimestamp: number; // timestamp-millis
  patientId: string;
  encounterId: string | null;
  orderingProvider: string;
  medication: Medication;
  dosage: string;
  frequency: string;
  route: string;
  startDate: number; // timestamp-millis
  endDate: number | null; // timestamp-millis
  orderStatus: OrderStatus;
  dataPrivacyLevel: PrivacyLevel;
}

// Example: Consuming medication order events from Confluent Cloud
import { Kafka, Consumer } from 'kafkajs';
import { SchemaRegistry } from '@kafkajs/confluent-schema-registry';

async function consumeMedicationOrders(
  bootstrapServers: string,
  apiKey: string,
  apiSecret: string,
  schemaRegistryUrl: string,
  schemaRegistryApiKey: string,
  schemaRegistryApiSecret: string,
  groupId: string
): Promise<Consumer> {
  // Configure Kafka client for Confluent Cloud
  const kafka = new Kafka({
    clientId: 'healthcare-medication-consumer',
    brokers: [bootstrapServers],
    ssl: true,
    sasl: {
      mechanism: 'plain',
      username: apiKey,
      password: apiSecret
    }
  });
  
  // Configure Schema Registry client
  const registry = new SchemaRegistry({
    host: schemaRegistryUrl,
    auth: {
      username: schemaRegistryApiKey,
      password: schemaRegistryApiSecret
    }
  });
  
  // Create consumer
  const consumer = kafka.consumer({ groupId });
  await consumer.connect();
  
  // Subscribe to topic
  await consumer.subscribe({ topic: 'healthcare.clinical.medication-orders', fromBeginning: false });
  
  // Process messages
  await consumer.run({
    eachMessage: async ({ topic, partition, message }) => {
      if (!message.value) return;
      
      try {
        // Decode the message using Schema Registry
        const decodedMessage = await registry.decode(message.value) as MedicationOrder;
        
        // Process the medication order
        console.log(`Processing medication order: ${decodedMessage.eventId}`);
        console.log(`  Patient: ${decodedMessage.patientId}`);
        console.log(`  Medication: ${decodedMessage.medication.display}`);
        console.log(`  Status: ${decodedMessage.orderStatus}`);
        
        // Check privacy level for special handling
        if (decodedMessage.dataPrivacyLevel === PrivacyLevel.PHI) {
          console.log('  Privacy: PHI - Applying special handling');
          // Apply PHI-specific processing rules...
        }
      } catch (error) {
        console.error('Error processing medication order:', error);
      }
    }
  });
  
  return consumer;
}
```
```

### Administrative Event Schemas

#### Insurance Verification

The insurance verification event captures the result of verifying a patient's insurance coverage:

```json
{
  "type": "record",
  "name": "InsuranceVerification",
  "namespace": "org.healthcare.events.administrative",
  "fields": [
    { "name": "eventId", "type": "string" },
    { "name": "eventTimestamp", "type": { "type": "long", "logicalType": "timestamp-millis" } },
    { "name": "patientId", "type": "string" },
    { "name": "encounterId", "type": ["null", "string"], "default": null },
    { "name": "serviceType", "type": ["null", "string"], "default": null },
    { "name": "insurancePlan", "type": {
      "type": "record",
      "name": "InsurancePlan",
      "fields": [
        { "name": "payerId", "type": "string" },
        { "name": "planId", "type": "string" },
        { "name": "planName", "type": "string" },
        { "name": "groupNumber", "type": ["null", "string"], "default": null },
        { "name": "subscriberId", "type": "string" }
      ]
    } },
    { "name": "verificationStatus", "type": { "type": "enum", "name": "VerificationStatus", "symbols": ["VERIFIED", "INACTIVE", "INELIGIBLE", "ERROR"] } },
    { "name": "coverageDetails", "type": ["null", {
      "type": "record",
      "name": "CoverageDetails",
      "fields": [
        { "name": "effectiveDate", "type": { "type": "int", "logicalType": "date" } },
        { "name": "terminationDate", "type": ["null", { "type": "int", "logicalType": "date" }], "default": null },
        { "name": "copayAmount", "type": ["null", "double"], "default": null },
        { "name": "coinsurancePercentage", "type": ["null", "double"], "default": null },
        { "name": "deductibleAmount", "type": ["null", "double"], "default": null },
        { "name": "deductibleMet", "type": ["null", "double"], "default": null },
        { "name": "outOfPocketMax", "type": ["null", "double"], "default": null },
        { "name": "outOfPocketMet", "type": ["null", "double"], "default": null }
      ]
    }], "default": null },
    { "name": "verificationTimestamp", "type": { "type": "long", "logicalType": "timestamp-millis" } },
    { "name": "verificationMethod", "type": { "type": "enum", "name": "VerificationMethod", "symbols": ["ELECTRONIC", "PHONE", "PORTAL", "FAX"] } }
  ]
}
```

## Schema Registry Client Usage

### Producer Implementation

Example of a Java producer using Avro schemas with the Schema Registry:

```java
import io.confluent.kafka.serializers.KafkaAvroSerializer;
import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.common.serialization.StringSerializer;
import org.healthcare.events.clinical.PatientAdmission;

import java.util.Properties;
import java.util.UUID;

public class PatientAdmissionProducer {

    public void publishAdmissionEvent(String patientId, String facilityId, String admittingProvider) {
        // Configure producer with Schema Registry
        Properties props = new Properties();
        props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, "kafka-broker-1:9092,kafka-broker-2:9092");
        props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
        props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, KafkaAvroSerializer.class.getName());
        props.put("schema.registry.url", "https://schema-registry.healthcare.internal:8081");
        props.put("security.protocol", "SSL");
        props.put("ssl.truststore.location", "/etc/kafka/security/kafka.client.truststore.jks");
        props.put("ssl.truststore.password", "truststore-password");
        
        // Create producer
        KafkaProducer<String, PatientAdmission> producer = new KafkaProducer<>(props);
        
        try {
            // Create event
            PatientAdmission admission = PatientAdmission.newBuilder()
                .setEventId(UUID.randomUUID().toString())
                .setEventTimestamp(System.currentTimeMillis())
                .setPatientId(patientId)
                .setFacilityId(facilityId)
                .setAdmittingProvider(admittingProvider)
                .setAdmissionTimestamp(System.currentTimeMillis())
                .setAdmissionType(AdmissionType.ELECTIVE)
                .build();
            
            // Send event
            ProducerRecord<String, PatientAdmission> record = 
                new ProducerRecord<>("clinical.patient.admission", patientId, admission);
            
            producer.send(record, (metadata, exception) -> {
                if (exception != null) {
                    System.err.println("Error publishing admission event: " + exception.getMessage());
                } else {
                    System.out.println("Published admission event: " + 
                        metadata.topic() + "-" + metadata.partition() + ":" + metadata.offset());
                }
            });
        } finally {
            producer.flush();
            producer.close();
        }
    }
}
```

### Consumer Implementation

Example of a Java consumer using Avro schemas with the Schema Registry:

```java
import io.confluent.kafka.serializers.KafkaAvroDeserializer;
import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.clients.consumer.ConsumerRecords;
import org.apache.kafka.clients.consumer.KafkaConsumer;
import org.apache.kafka.common.serialization.StringDeserializer;
import org.healthcare.events.clinical.PatientAdmission;

import java.time.Duration;
import java.util.Collections;
import java.util.Properties;

public class PatientAdmissionConsumer {

    public void consumeAdmissionEvents() {
        // Configure consumer with Schema Registry
        Properties props = new Properties();
        props.put(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, "kafka-broker-1:9092,kafka-broker-2:9092");
        props.put(ConsumerConfig.GROUP_ID_CONFIG, "admission-processor");
        props.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class.getName());
        props.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, KafkaAvroDeserializer.class.getName());
        props.put("schema.registry.url", "https://schema-registry.healthcare.internal:8081");
        props.put("specific.avro.reader", "true");
        props.put("security.protocol", "SSL");
        props.put("ssl.truststore.location", "/etc/kafka/security/kafka.client.truststore.jks");
        props.put("ssl.truststore.password", "truststore-password");
        
        // Create consumer
        KafkaConsumer<String, PatientAdmission> consumer = new KafkaConsumer<>(props);
        
        // Subscribe to topic
        consumer.subscribe(Collections.singletonList("clinical.patient.admission"));
        
        try {
            while (true) {
                ConsumerRecords<String, PatientAdmission> records = consumer.poll(Duration.ofMillis(100));
                
                for (ConsumerRecord<String, PatientAdmission> record : records) {
                    PatientAdmission admission = record.value();
                    
                    // Process the admission event
                    System.out.println("Received admission for patient: " + admission.getPatientId() + 
                        " at facility: " + admission.getFacilityId());
                    
                    // Implement business logic here
                    processAdmission(admission);
                }
            }
        } catch (Exception e) {
            System.err.println("Error consuming admission events: " + e.getMessage());
        } finally {
            consumer.close();
        }
    }
    
    private void processAdmission(PatientAdmission admission) {
        // Implement admission processing logic
        // For example, update patient location, trigger notifications, etc.
    }
}
```

## Related Documentation

- [Topic Design](topic-design.md): Designing effective Kafka topics
- [Connectors](connectors.md): Integrating with healthcare systems
- [Stream Processing](../03-advanced-patterns/stream-processing.md): Processing events in real-time
- [FHIR Events](../04-healthcare-integration/fhir-events.md): FHIR-specific event schemas
