# Event Schemas

## Overview

Event schemas define the structure, format, and validation rules for events flowing through the Event Broker. Well-designed schemas are crucial for ensuring data quality, enabling interoperability, and supporting schema evolution as healthcare requirements change. This document covers the implementation of event schemas using Confluent Schema Registry, focusing on healthcare-specific considerations and best practices.

## Schema Registry Fundamentals

The Confluent Schema Registry provides a centralized repository for managing and validating event schemas in our Kafka-based Event Broker. It serves as the source of truth for event formats and enables several critical capabilities:

- **Schema Validation**: Ensures all published events conform to their defined schemas
- **Schema Evolution**: Manages compatible changes to schemas over time
- **Serialization/Deserialization**: Handles conversion between wire format and application objects
- **Documentation**: Serves as self-documenting API for event consumers
- **Governance**: Enforces organizational standards for event design

## Schema Formats

The Schema Registry supports multiple schema formats, each with different strengths for healthcare data modeling:

### Apache Avro

Avro is our primary schema format for healthcare events due to its compact binary serialization and rich type system:

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

**Key Advantages for Healthcare:**
- **Compact Binary Format**: Efficient for high-volume healthcare data
- **Rich Type System**: Supports complex healthcare data structures
- **Built-in Documentation**: Self-documenting with field descriptions
- **Strong Validation**: Enforces data quality at the source
- **Language Interoperability**: Supports multiple programming languages

### JSON Schema

JSON Schema provides a more flexible approach for certain healthcare events, particularly when working with external systems that prefer JSON:

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
      "description": "Pharmacy where medication was dispensed"
    },
    "prescriptionId": {
      "type": "string",
      "description": "Identifier for the prescription"
    },
    "medication": {
      "type": "object",
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
        "form": {
          "type": "string",
          "description": "Medication form (tablet, capsule, etc.)"
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

**Key Advantages for Healthcare:**
- **Human Readable**: Easier to understand for non-technical stakeholders
- **Widespread Adoption**: Familiar to many healthcare developers
- **Flexible Validation**: Supports complex validation rules
- **Web Integration**: Native format for web applications
- **Direct JSON Compatibility**: No conversion needed for JSON-based systems

### Protocol Buffers

Protocol Buffers (protobuf) offer another efficient serialization option, particularly useful for high-performance healthcare applications:

```protobuf
syntax = "proto3";

package healthcare.events.clinical;

import "google/protobuf/timestamp.proto";

message VitalSignsRecorded {
  // Event metadata
  string event_id = 1;
  google.protobuf.Timestamp event_timestamp = 2;
  
  // Clinical context
  string patient_id = 3;
  string encounter_id = 4;
  string recorded_by_provider = 5;
  google.protobuf.Timestamp recorded_timestamp = 6;
  
  // Vital signs
  message VitalSign {
    string code = 1;  // LOINC code
    string display = 2;  // Human-readable name
    double value = 3;  // Measured value
    string unit = 4;  // Unit of measure
  }
  
  repeated VitalSign vital_signs = 7;
  
  // Optional context
  string device_id = 8;
  string location = 9;
  map<string, string> metadata = 10;
}
```

**Key Advantages for Healthcare:**
- **Extremely Efficient**: Even more compact than Avro
- **Strong Typing**: Enforces data integrity
- **Language Support**: Extensive support across programming languages
- **Versioning**: Built-in versioning capabilities
- **Performance**: Fast serialization/deserialization for time-sensitive healthcare applications

## Schema Design Principles

### Healthcare Event Schema Standards

When designing schemas for healthcare events, follow these key principles:

1. **Consistent Event Metadata**
   - Every event should include standard metadata fields:
     - `eventId`: Unique identifier for the event
     - `eventTimestamp`: When the event occurred
     - `eventType`: Classification of the event
     - `eventSource`: System that generated the event
     - `version`: Schema version

2. **Patient Context**
   - Include patient identifiers consistently:
     - `patientId`: Primary patient identifier
     - `mrn`: Medical record number (when applicable)
     - `externalIds`: Map of identifiers from external systems

3. **Healthcare Terminology**
   - Use standard coding systems:
     - `code`: The actual code value
     - `system`: The coding system (e.g., "http://loinc.org")
     - `display`: Human-readable description

4. **Temporal Precision**
   - Use ISO-8601 or timestamp-millis for all date/time fields
   - Include timezone information for cross-timezone healthcare operations
   - Distinguish between event time and processing time

5. **Privacy Considerations**
   - Include only necessary PHI in events
   - Consider field-level encryption for sensitive data
   - Add data classification metadata (PHI, PII, etc.)

### Schema Evolution

Healthcare requirements evolve over time, requiring changes to event schemas. The Schema Registry supports several compatibility types:

| Compatibility Type | Description | Use Case |
|-------------------|-------------|----------|
| BACKWARD | New schema can read old data | Adding optional fields |
| FORWARD | Old schema can read new data | Removing optional fields |
| FULL | Both backward and forward compatible | Safest for most changes |
| NONE | No compatibility checking | Major version changes |

**Best Practices for Healthcare Schema Evolution:**

1. **Default to BACKWARD Compatibility**
   - Ensures new consumers can read historical healthcare data
   - Critical for longitudinal patient records

2. **Use Optional Fields**
   - Make new fields optional with defaults
   - Allows gradual adoption across healthcare systems

3. **Avoid Removing Fields**
   - Healthcare data often has long retention requirements
   - Mark fields as deprecated instead of removing

4. **Version Schemas Explicitly**
   - Include version in schema name or metadata
   - Document changes between versions

5. **Test Compatibility Before Deployment**
   - Verify compatibility with the Schema Registry API
   - Test with both old and new message formats

## Schema Registry Implementation

### Configuration

The Schema Registry is deployed with the following configuration for healthcare environments:

```properties
# Basic configuration
listeners=http://0.0.0.0:8081
host.name=schema-registry.healthcare.internal
kafka.bootstrap.servers=PLAINTEXT://kafka-broker-1:9092,PLAINTEXT://kafka-broker-2:9092

# Security configuration
ssl.keystore.location=/etc/schema-registry/ssl/schema-registry.keystore.jks
ssl.keystore.password=${SSL_KEYSTORE_PASSWORD}
ssl.key.password=${SSL_KEY_PASSWORD}
ssl.truststore.location=/etc/schema-registry/ssl/schema-registry.truststore.jks
ssl.truststore.password=${SSL_TRUSTSTORE_PASSWORD}

# Authentication and authorization
authentication.method=BASIC
authentication.roles=SCHEMA_REGISTRY_ADMIN,SCHEMA_REGISTRY_USER
authentication.realm=SCHEMA_REGISTRY_SECURITY

# Schema compatibility settings
avro.compatibility.level=BACKWARD
json.schema.compatibility.level=BACKWARD
protobuf.compatibility.level=BACKWARD

# Healthcare-specific settings
schema.registry.group.id=healthcare-schemas
schema.registry.url=https://schema-registry.healthcare.internal:8081
```

### Schema Management Workflow

The workflow for managing healthcare event schemas includes:

1. **Schema Development**
   - Create schema in development environment
   - Document fields and purpose
   - Review with domain experts

2. **Schema Testing**
   - Validate against sample healthcare data
   - Test serialization/deserialization
   - Verify compatibility with existing schemas

3. **Schema Registration**
   - Register schema with Schema Registry
   - Set appropriate compatibility level
   - Document in schema catalog

4. **Schema Deployment**
   - Update applications to use new schema
   - Monitor for serialization errors
   - Track schema usage metrics

5. **Schema Evolution**
   - Propose changes through governance process
   - Test compatibility with existing data
   - Deploy with appropriate versioning

## Healthcare Schema Examples

### Clinical Event Schemas

#### Patient Admission

The patient admission event captures when a patient is admitted to a healthcare facility:

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
    { "name": "admissionTimestamp", "type": { "type": "long", "logicalType": "timestamp-millis" } }
  ]
}
```

#### Medication Order

The medication order event captures when a provider orders medication for a patient:

```json
{
  "type": "record",
  "name": "MedicationOrder",
  "namespace": "org.healthcare.events.medication",
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
        { "name": "codeSystem", "type": "string", "default": "RxNorm" },
        { "name": "display", "type": "string" },
        { "name": "form", "type": ["null", "string"], "default": null },
        { "name": "strength", "type": ["null", "string"], "default": null }
      ]
    } },
    { "name": "dosage", "type": {
      "type": "record",
      "name": "Dosage",
      "fields": [
        { "name": "amount", "type": "double" },
        { "name": "unit", "type": "string" },
        { "name": "frequency", "type": "string" },
        { "name": "route", "type": "string" },
        { "name": "duration", "type": ["null", "int"], "default": null },
        { "name": "durationUnit", "type": ["null", "string"], "default": null }
      ]
    } },
    { "name": "orderTimestamp", "type": { "type": "long", "logicalType": "timestamp-millis" } },
    { "name": "startTimestamp", "type": ["null", { "type": "long", "logicalType": "timestamp-millis" }], "default": null },
    { "name": "endTimestamp", "type": ["null", { "type": "long", "logicalType": "timestamp-millis" }], "default": null },
    { "name": "status", "type": { "type": "enum", "name": "OrderStatus", "symbols": ["ORDERED", "VERIFIED", "DISPENSED", "ADMINISTERED", "DISCONTINUED", "EXPIRED"] } }
  ]
}
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
