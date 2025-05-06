# Event Broker Data Model

## Introduction
The Event Broker data model defines the structure of events, topics, schemas, and related metadata within the event streaming platform. This document describes the core data structures, their relationships, and the schemas that govern event data across the CoverMyMeds Technology Platform. Understanding this data model is essential for teams producing or consuming events, as well as for those responsible for event governance and platform operations.

## Data Structures

### Event
An event is the fundamental unit of data in the Event Broker. It represents a meaningful occurrence in the system and contains both payload data and metadata.

**Key Attributes:**
- **Key**: Unique identifier or business key for event partitioning and ordering
- **Value**: The actual event payload containing the event data
- **Headers**: Metadata attributes associated with the event
- **Timestamp**: When the event occurred or was produced
- **Offset**: Sequential position identifier within a partition
- **Partition**: The partition within a topic where the event is stored
- **Topic**: The named channel where the event is published

### Topic
A topic is a named feed or channel of events. Topics organize events into logical streams based on event type, source system, or business domain.

**Key Attributes:**
- **Name**: Unique identifier for the topic
- **Partitions**: Number of partitions for parallel processing
- **Replication Factor**: Number of replicas for fault tolerance
- **Configuration**: Topic-specific settings (retention, compaction, etc.)
- **Access Controls**: Security policies governing topic access

### Consumer Group
A consumer group represents a logical grouping of consumers that process events collectively.

**Key Attributes:**
- **Group ID**: Unique identifier for the consumer group
- **Members**: Individual consumer instances within the group
- **Offsets**: Tracking of consumed event positions per partition
- **Status**: Current state of the consumer group (stable, rebalancing, etc.)
- **Consumer Lag**: Difference between produced and consumed events

### Schema
A schema defines the structure, data types, and constraints for event payload data.

**Key Attributes:**
- **ID**: Unique identifier for the schema
- **Subject**: Association with topic and event type
- **Version**: Schema version number
- **Definition**: Actual schema definition (Avro, JSON Schema, or Protobuf)
- **Compatibility Type**: Rules for evolution (backward, forward, full)

### Connector
A connector is a configurable component that moves data between the Event Broker and external systems.

**Key Attributes:**
- **Name**: Unique identifier for the connector
- **Class**: Implementation class for the connector
- **Configuration**: Connection and mapping settings
- **Status**: Current operational state
- **Tasks**: Individual execution units for the connector

## Relationships

### Event-Topic Relationship
- **Nature**: Many-to-One (Many events belong to one topic)
- **Cardinality**: A topic contains 0 to billions of events
- **Lifecycle**: Events are immutable once written to a topic
- **Access Pattern**: Events are accessed sequentially by offset within partitions

### Topic-Schema Relationship
- **Nature**: Many-to-Many (Topics can have multiple schema versions, schemas can apply to multiple topics)
- **Cardinality**: A topic typically has 1 key schema and 1 value schema (with multiple versions)
- **Consistency**: Schema Registry enforces compatibility between versions
- **Subject Naming**: Typically follows a pattern of `<topic-name>-(key|value)`

### Consumer Group-Topic Relationship
- **Nature**: Many-to-Many (Consumer groups can subscribe to multiple topics, topics can have multiple consumer groups)
- **Cardinality**: A typical consumer group subscribes to 1-10 topics
- **Offset Management**: Each consumer group independently tracks its position in each topic-partition
- **Partition Assignment**: Partitions are exclusively assigned to one consumer within a group

### Connector-Topic Relationship
- **Nature**: Many-to-Many (Connectors can produce/consume from multiple topics)
- **Cardinality**: Varies by connector type and configuration
- **Data Flow**: Source connectors produce to topics, sink connectors consume from topics
- **Transformation**: Connectors can transform data between external systems and event format

## Data Flows

### Event Production Flow
1. **Producer Application**: Generates an event based on application state change
2. **Schema Validation**: Event is validated against the registered schema (if enabled)
3. **Topic Assignment**: Event is assigned to a specific topic and partition
4. **Persistence**: Event is durably stored across replicated brokers
5. **Acknowledgment**: Success confirmation is returned to the producer (based on ack settings)

### Event Consumption Flow
1. **Topic Subscription**: Consumer subscribes to one or more topics
2. **Partition Assignment**: Consumer group coordinator assigns partitions to consumers
3. **Event Fetching**: Consumer retrieves batches of events from assigned partitions
4. **Schema Resolution**: Events are deserialized using the appropriate schema version
5. **Processing**: Consumer application processes the events
6. **Offset Commitment**: Consumer commits processed position back to the broker

### Schema Evolution Flow
1. **Schema Definition**: New or updated schema is created for a subject
2. **Compatibility Check**: Schema Registry validates compatibility with existing versions
3. **Registration**: New schema version is registered if compatible
4. **Producer Adoption**: Producers begin using the new schema version
5. **Consumer Compatibility**: Consumers can read both old and new formats (if backward compatible)

### Connector Data Flow
1. **Connector Configuration**: Connector is configured with source/sink details
2. **Task Creation**: Connector creates tasks for parallel operation
3. **Data Extraction/Ingestion**: Tasks extract or ingest data from external systems
4. **Transformation**: Data is transformed between external and event formats
5. **Production/Consumption**: Data is produced to or consumed from topics

## Example Schemas

### Healthcare Event Envelope Schema (Avro)

```json
{
  "type": "record",
  "name": "EventEnvelope",
  "namespace": "com.covermymeds.events",
  "fields": [
    {
      "name": "metadata",
      "type": {
        "type": "record",
        "name": "Metadata",
        "fields": [
          { "name": "eventId", "type": "string" },
          { "name": "eventType", "type": "string" },
          { "name": "eventSource", "type": "string" },
          { "name": "correlationId", "type": ["null", "string"], "default": null },
          { "name": "causationId", "type": ["null", "string"], "default": null },
          { "name": "timestamp", "type": "long", "logicalType": "timestamp-millis" },
          { "name": "version", "type": "string" },
          { 
            "name": "securityContext", 
            "type": ["null", {
              "type": "record",
              "name": "SecurityContext",
              "fields": [
                { "name": "principal", "type": "string" },
                { "name": "claims", "type": { "type": "map", "values": "string" } }
              ]
            }],
            "default": null
          }
        ]
      }
    },
    {
      "name": "payload",
      "type": ["null", "bytes"],
      "default": null
    }
  ]
}
```

### Medication Order Event Schema (Avro)

```json
{
  "type": "record",
  "name": "MedicationOrderEvent",
  "namespace": "com.covermymeds.events.pharmacy",
  "fields": [
    {
      "name": "orderId", 
      "type": "string",
      "doc": "Unique identifier for the medication order"
    },
    {
      "name": "patientId", 
      "type": "string",
      "doc": "Identifier for the patient"
    },
    {
      "name": "prescriberId", 
      "type": "string",
      "doc": "Identifier for the prescribing provider"
    },
    {
      "name": "pharmacyId", 
      "type": ["null", "string"],
      "default": null,
      "doc": "Identifier for the dispensing pharmacy, if assigned"
    },
    {
      "name": "medication", 
      "type": {
        "type": "record",
        "name": "Medication",
        "fields": [
          { "name": "ndc", "type": "string", "doc": "National Drug Code" },
          { "name": "name", "type": "string", "doc": "Medication name" },
          { "name": "strength", "type": "string", "doc": "Medication strength" },
          { "name": "form", "type": "string", "doc": "Medication form" },
          { "name": "quantity", "type": "double", "doc": "Prescribed quantity" },
          { "name": "daysSupply", "type": "int", "doc": "Days supply" }
        ]
      }
    },
    {
      "name": "sigText", 
      "type": "string",
      "doc": "Prescription instructions"
    },
    {
      "name": "status", 
      "type": {
        "type": "enum",
        "name": "OrderStatus",
        "symbols": ["PENDING", "ACTIVE", "COMPLETED", "CANCELLED", "ON_HOLD"]
      },
      "doc": "Current status of the order"
    },
    {
      "name": "priorAuthorization", 
      "type": ["null", {
        "type": "record",
        "name": "PriorAuthorization",
        "fields": [
          { "name": "required", "type": "boolean" },
          { "name": "status", "type": ["null", "string"], "default": null },
          { "name": "paNumber", "type": ["null", "string"], "default": null },
          { "name": "expirationDate", "type": ["null", "long"], "logicalType": "timestamp-millis", "default": null }
        ]
      }],
      "default": null,
      "doc": "Prior authorization details, if applicable"
    },
    {
      "name": "createdAt", 
      "type": "long",
      "logicalType": "timestamp-millis",
      "doc": "When the order was created"
    },
    {
      "name": "updatedAt", 
      "type": "long",
      "logicalType": "timestamp-millis",
      "doc": "When the order was last updated"
    }
  ]
}
```

### Topic Configuration Schema (JSON)

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Topic Configuration",
  "type": "object",
  "required": ["name", "partitions", "replicationFactor", "config"],
  "properties": {
    "name": {
      "type": "string",
      "pattern": "^[a-zA-Z0-9._-]+$",
      "description": "Topic name"
    },
    "partitions": {
      "type": "integer",
      "minimum": 1,
      "description": "Number of partitions"
    },
    "replicationFactor": {
      "type": "integer",
      "minimum": 1,
      "description": "Replication factor"
    },
    "config": {
      "type": "object",
      "properties": {
        "retention.ms": {
          "type": "integer",
          "minimum": 1,
          "description": "Retention period in milliseconds"
        },
        "cleanup.policy": {
          "type": "string",
          "enum": ["delete", "compact", "delete,compact"],
          "description": "Cleanup policy for messages"
        },
        "min.insync.replicas": {
          "type": "integer",
          "minimum": 1,
          "description": "Minimum number of in-sync replicas"
        },
        "max.message.bytes": {
          "type": "integer",
          "minimum": 1024,
          "description": "Maximum message size in bytes"
        },
        "compression.type": {
          "type": "string",
          "enum": ["uncompressed", "gzip", "snappy", "lz4", "zstd"],
          "description": "Compression type"
        }
      },
      "additionalProperties": true
    },
    "schemaConfig": {
      "type": "object",
      "properties": {
        "keySchema": {
          "type": "string",
          "description": "Subject name for key schema"
        },
        "valueSchema": {
          "type": "string",
          "description": "Subject name for value schema"
        },
        "compatibility": {
          "type": "string",
          "enum": ["BACKWARD", "BACKWARD_TRANSITIVE", "FORWARD", "FORWARD_TRANSITIVE", "FULL", "FULL_TRANSITIVE", "NONE"],
          "description": "Schema compatibility setting"
        }
      }
    },
    "owner": {
      "type": "string",
      "description": "Team owning this topic"
    },
    "description": {
      "type": "string",
      "description": "Topic description and purpose"
    },
    "dataSensitivity": {
      "type": "string",
      "enum": ["PUBLIC", "INTERNAL", "CONFIDENTIAL", "RESTRICTED", "PHI"],
      "description": "Data sensitivity classification"
    }
  }
}
```

### Consumer Group Configuration (TypeScript)

```typescript
interface ConsumerGroupConfig {
  /**
   * Unique identifier for the consumer group
   */
  groupId: string;
  
  /**
   * Topics to subscribe to
   */
  topics: string[];
  
  /**
   * Consumer configuration settings
   */
  config: {
    /**
     * Consumer rebalance timeout in milliseconds
     */
    sessionTimeout: number;
    
    /**
     * Maximum time between heartbeats in milliseconds
     */
    heartbeatInterval: number;
    
    /**
     * How to handle missing offsets when group initializes
     * 'earliest' - Start from the beginning of the topic
     * 'latest' - Start from the end of the topic
     */
    autoOffsetReset: 'earliest' | 'latest';
    
    /**
     * Maximum number of bytes to fetch in a single request
     */
    maxBytes: number;
    
    /**
     * Maximum time to block waiting for messages
     */
    maxWaitTimeInMs: number;
    
    /**
     * Allow automatic creation of topics when subscribing
     */
    allowAutoTopicCreation: boolean;
    
    /**
     * How frequently to commit offsets in milliseconds
     */
    autoCommitInterval: number;
  };
  
  /**
   * Processing settings
   */
  processing: {
    /**
     * Number of partitions to process concurrently
     */
    concurrency: number;
    
    /**
     * Maximum number of messages to process at once
     */
    batchSize: number;
    
    /**
     * Error handling strategy
     */
    errorHandling: 'continue' | 'dead-letter-queue' | 'retry' | 'pause';
  };
  
  /**
   * Monitoring settings
   */
  monitoring: {
    /**
     * Maximum acceptable lag in messages before alerting
     */
    lagThreshold: number;
    
    /**
     * Lag measurement interval in milliseconds
     */
    lagCheckInterval: number;
  };
  
  /**
   * Team responsible for this consumer group
   */
  owner: string;
  
  /**
   * Description of the consumer group's purpose
   */
  description: string;
}
```

## Related Resources
- [Event Broker Core APIs](./core-apis.md)
- [Topic Management](./topic-management.md)
- [Schema Registry Management](../04-governance-compliance/schema-registry-management.md)
- [Event Schema Design](../03-advanced-patterns/customization.md)
- [Confluent Schema Registry Documentation](https://docs.confluent.io/platform/current/schema-registry/index.html)