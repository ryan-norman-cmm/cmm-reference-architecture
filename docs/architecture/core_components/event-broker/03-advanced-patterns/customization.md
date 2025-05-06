# Event Broker Customization

## Introduction

This document outlines the customization options available for the Event Broker component of the CMM Technology Platform. The Event Broker, built on Confluent Kafka, provides various mechanisms for customization to meet specific healthcare requirements. This guide explains how to customize the Event Broker's configuration, behavior, and integration patterns while maintaining compatibility with the overall platform.

## Configuration Customization

### Broker Configuration

The Event Broker's core behavior can be customized through broker configuration:

```properties
# Performance Tuning
num.network.threads=8                  # Number of threads for network requests
num.io.threads=16                      # Number of threads for disk I/O
socket.send.buffer.bytes=1048576       # Socket send buffer size
socket.receive.buffer.bytes=1048576    # Socket receive buffer size
socket.request.max.bytes=104857600     # Maximum size of a request

# Topic Defaults
num.partitions=8                       # Default number of partitions per topic
default.replication.factor=3           # Default replication factor
min.insync.replicas=2                  # Minimum in-sync replicas for durability

# Log Configuration
log.retention.hours=168                # 7 days retention by default
log.segment.bytes=1073741824           # 1GB segment size
log.cleanup.policy=delete              # Delete old segments

# Healthcare-Specific Settings
compression.type=lz4                   # Efficient compression for healthcare data
message.max.bytes=20971520             # 20MB max message size for large healthcare documents
```

### Client Configuration

Kafka clients can be customized for healthcare-specific requirements using TypeScript and Confluent Cloud features:

#### Producer Configuration

```typescript
// Import required libraries
import { Kafka, CompressionTypes, Partitioners, logLevel } from 'kafkajs';
import { SchemaRegistry } from '@kafkajs/confluent-schema-registry';
import { v4 as uuidv4 } from 'uuid';

// Define the healthcare event interface
interface HealthcareEvent<T> {
  metadata: {
    eventId: string;
    eventType: string;
    eventSource: string;
    eventTime: number;
    correlationId: string;
    version: string;
    traceId?: string;
    partitionKey?: string;
    schemaId?: number;
    dataClassification?: string;
    retentionPolicy?: string;
  };
  data: T;
}

// Configure Confluent Cloud producer for healthcare data
const configureHealthcareProducer = async () => {
  // Confluent Cloud configuration
  const kafkaConfig = {
    clientId: 'healthcare-event-producer',
    brokers: ['${CONFLUENT_BOOTSTRAP_SERVERS}'],
    ssl: true,
    sasl: {
      mechanism: 'plain',
      username: '${CONFLUENT_CLOUD_KEY}',
      password: '${CONFLUENT_CLOUD_SECRET}'
    },
    connectionTimeout: 5000,
    requestTimeout: 30000,
    retry: {
      initialRetryTime: 100,
      retries: 10
    },
    logLevel: logLevel.ERROR
  };

  // Create Kafka client
  const kafka = new Kafka(kafkaConfig);

  // Configure Schema Registry
  const schemaRegistry = new SchemaRegistry({
    host: 'https://schema-registry.confluent.cloud',
    auth: {
      username: '${SCHEMA_REGISTRY_KEY}',
      password: '${SCHEMA_REGISTRY_SECRET}'
    }
  });

  // Create producer with advanced configuration
  const producer = kafka.producer({
    createPartitioner: Partitioners.DefaultPartitioner,
    allowAutoTopicCreation: false,
    idempotent: true,                // Prevent duplicates (exactly-once delivery)
    transactionalId: 'healthcare-tx', // Enable transactions for atomic writes
    maxInFlightRequests: 5,          // Limit concurrent requests
    compression: CompressionTypes.LZ4, // Efficient compression for healthcare data
    metadataMaxAge: 300000,           // 5 minutes metadata refresh
    // Performance tuning
    batchSize: 65536,                // 64KB batch size
    linger: 5,                      // Wait up to 5ms for batching
    maxOutgoingBatchSize: 10485760,  // 10MB max batch size
    queueBufferingMaxMessages: 100000 // Max messages to buffer in memory
  });

  // Connect to Confluent Cloud
  await producer.connect();

  // Set up monitoring and metrics
  producer.on('producer.connect', () => {
    console.log('Producer connected to Confluent Cloud');
  });

  producer.on('producer.disconnect', () => {
    console.log('Producer disconnected from Confluent Cloud');
  });

  // Return producer and schema registry for use
  return { producer, schemaRegistry };
};

// Example function to send healthcare events
async function sendHealthcareEvent<T>(
  producer: any,
  schemaRegistry: any,
  topic: string,
  event: HealthcareEvent<T>,
  schemaType: string
) {
  try {
    // Register or fetch schema ID
    const { id } = await schemaRegistry.getLatestSchemaId(schemaType);
    event.metadata.schemaId = id;
    
    // Add trace ID for observability
    event.metadata.traceId = event.metadata.traceId || uuidv4();
    
    // Encode message with Avro schema
    const encodedValue = await schemaRegistry.encode(id, event);
    
    // Send message to Confluent Cloud
    const result = await producer.send({
      topic,
      compression: CompressionTypes.LZ4,
      messages: [
        {
          key: event.metadata.partitionKey || event.data.patientId,
          value: encodedValue,
          headers: {
            'event-type': event.metadata.eventType,
            'trace-id': event.metadata.traceId,
            'data-classification': event.metadata.dataClassification || 'PHI',
            'source-system': event.metadata.eventSource,
            'event-time': event.metadata.eventTime.toString()
          }
        }
      ]
    });
    
    console.log(`Healthcare event sent successfully: ${event.metadata.eventId}`);
    return result;
  } catch (error) {
    console.error('Error sending healthcare event:', error);
    // Implement dead letter queue handling for Confluent Cloud
    await sendToDeadLetterQueue(producer, event, error);
    throw error;
  }
}

// Example usage
async function main() {
  const { producer, schemaRegistry } = await configureHealthcareProducer();
  
  try {
    // Create a healthcare event
    const patientAdmittedEvent: HealthcareEvent<any> = {
      metadata: {
        eventId: uuidv4(),
        eventType: 'patient.admitted',
        eventSource: 'ehr-system',
        eventTime: Date.now(),
        correlationId: uuidv4(),
        version: '1.0',
        dataClassification: 'PHI',
        retentionPolicy: 'healthcare-7yr'
      },
      data: {
        patientId: 'P123456',
        encounterId: 'E789012',
        // Additional patient data...
      }
    };
    
    // Send the event
    await sendHealthcareEvent(
      producer,
      schemaRegistry,
      'clinical.patient.admitted',
      patientAdmittedEvent,
      'com.healthcare.events.clinical.PatientAdmittedEvent'
    );
  } catch (error) {
    console.error('Failed to send event:', error);
  } finally {
    // Graceful shutdown
    await producer.disconnect();
  }
}
```

#### Consumer Configuration

```typescript
// Import required libraries
import { Kafka, logLevel, EachMessagePayload } from 'kafkajs';
import { SchemaRegistry } from '@kafkajs/confluent-schema-registry';
import { Tracer } from '@opentelemetry/api';
import { createTracer } from '@opentelemetry/tracing';

// Define the healthcare event interface
interface HealthcareEvent<T> {
  metadata: {
    eventId: string;
    eventType: string;
    eventSource: string;
    eventTime: number;
    correlationId: string;
    version: string;
    traceId?: string;
    schemaId?: number;
    dataClassification?: string;
  };
  data: T;
}

// Configure Confluent Cloud consumer for healthcare data
const configureHealthcareConsumer = async () => {
  // Confluent Cloud configuration
  const kafkaConfig = {
    clientId: 'healthcare-event-consumer',
    brokers: ['${CONFLUENT_BOOTSTRAP_SERVERS}'],
    ssl: true,
    sasl: {
      mechanism: 'plain',
      username: '${CONFLUENT_CLOUD_KEY}',
      password: '${CONFLUENT_CLOUD_SECRET}'
    },
    connectionTimeout: 5000,
    requestTimeout: 30000,
    retry: {
      initialRetryTime: 300,
      retries: 10,
      factor: 1.5 // Exponential backoff
    },
    logLevel: logLevel.ERROR
  };

  // Create Kafka client
  const kafka = new Kafka(kafkaConfig);

  // Configure Schema Registry
  const schemaRegistry = new SchemaRegistry({
    host: 'https://schema-registry.confluent.cloud',
    auth: {
      username: '${SCHEMA_REGISTRY_KEY}',
      password: '${SCHEMA_REGISTRY_SECRET}'
    }
  });

  // Create consumer with advanced configuration
  const consumer = kafka.consumer({
    groupId: 'clinical-data-processor',
    // Confluent Cloud optimizations
    sessionTimeout: 30000,             // 30 seconds session timeout
    heartbeatInterval: 3000,           // 3 seconds heartbeat interval
    maxBytesPerPartition: 10485760,    // 10MB max bytes per partition
    maxWaitTimeInMs: 500,             // 500ms max wait time
    minBytes: 1024,                   // 1KB minimum fetch size
    maxBytes: 52428800,               // 50MB max fetch size
    readUncommitted: false,            // Only read committed messages
    // Rebalance strategy
    rebalanceTimeout: 60000,           // 60 seconds rebalance timeout
    // Performance tuning
    maxInFlightRequests: 5,           // Limit concurrent requests
    metadataMaxAge: 300000,            // 5 minutes metadata refresh
    allowAutoTopicCreation: false      // Prevent accidental topic creation
  });

  // Connect to Confluent Cloud
  await consumer.connect();

  // Set up monitoring and metrics
  consumer.on('consumer.connect', () => {
    console.log('Consumer connected to Confluent Cloud');
  });

  consumer.on('consumer.disconnect', () => {
    console.log('Consumer disconnected from Confluent Cloud');
  });

  consumer.on('consumer.crash', (event) => {
    console.error('Consumer crashed:', event);
    // Implement crash recovery logic
  });

  // Initialize OpenTelemetry tracing
  const tracer = createTracer({
    name: 'healthcare-consumer-tracer',
    // Configure with Confluent Cloud Observability
    // or your preferred observability platform
  });

  // Return consumer, schema registry, and tracer for use
  return { consumer, schemaRegistry, tracer };
};

// Example function to process healthcare events
async function processHealthcareEvents(topics: string[]) {
  const { consumer, schemaRegistry, tracer } = await configureHealthcareConsumer();
  
  try {
    // Subscribe to healthcare topics
    await Promise.all(
      topics.map(topic => consumer.subscribe({ topic, fromBeginning: true }))
    );
    
    // Process messages with error handling and observability
    await consumer.run({
      // Process each message individually for better control
      eachMessage: async ({ topic, partition, message }: EachMessagePayload) => {
        // Start a new trace for this message
        const span = tracer.startSpan('process-healthcare-event');
        
        try {
          // Extract headers for observability
          const traceId = message.headers?.['trace-id']?.toString();
          const eventType = message.headers?.['event-type']?.toString();
          const dataClassification = message.headers?.['data-classification']?.toString();
          
          // Add context to span
          span.setAttribute('kafka.topic', topic);
          span.setAttribute('kafka.partition', partition);
          span.setAttribute('kafka.offset', message.offset);
          span.setAttribute('event.type', eventType || 'unknown');
          span.setAttribute('data.classification', dataClassification || 'unknown');
          
          // Decode message using Schema Registry
          const decodedMessage = await schemaRegistry.decode(message.value);
          
          // Process the healthcare event based on type
          switch (eventType) {
            case 'patient.admitted':
              await processPatientAdmission(decodedMessage, span);
              break;
            case 'patient.discharged':
              await processPatientDischarge(decodedMessage, span);
              break;
            case 'observation.vitals':
              await processVitalSigns(decodedMessage, span);
              break;
            default:
              console.log(`Processing generic healthcare event: ${eventType}`);
              await processGenericEvent(decodedMessage, span);
          }
          
          // Commit offsets manually for better control
          // This is done after successful processing to ensure at-least-once delivery
          await consumer.commitOffsets([
            { topic, partition, offset: (parseInt(message.offset) + 1).toString() }
          ]);
          
          // Record successful processing
          span.setAttribute('processing.success', true);
        } catch (error) {
          // Record error in span
          span.setAttribute('processing.success', false);
          span.setAttribute('error', true);
          span.setAttribute('error.message', error.message);
          
          // Handle different types of errors
          if (error.name === 'SchemaRegistryError') {
            // Schema validation error - send to dead letter queue
            await sendToDeadLetterQueue(topic, message, error, 'SCHEMA_ERROR');
          } else if (error.retriable) {
            // Retriable error - don't commit offset to allow reprocessing
            console.error(`Retriable error processing message: ${error.message}`);
          } else {
            // Non-retriable error - send to dead letter queue and commit offset
            await sendToDeadLetterQueue(topic, message, error, 'PROCESSING_ERROR');
            await consumer.commitOffsets([
              { topic, partition, offset: (parseInt(message.offset) + 1).toString() }
            ]);
          }
        } finally {
          // End the span
          span.end();
        }
      }
    });
  } catch (error) {
    console.error('Fatal consumer error:', error);
    // Implement recovery strategy
  }
}

// Example usage
async function main() {
  try {
    // Start consuming from healthcare topics
    await processHealthcareEvents([
      'clinical.patient.admitted',
      'clinical.patient.discharged',
      'clinical.observation.vitals'
    ]);
    
    // Handle graceful shutdown
    process.on('SIGTERM', async () => {
      console.log('Shutting down consumer...');
      await consumer.disconnect();
      process.exit(0);
    });
  } catch (error) {
    console.error('Failed to start consumer:', error);
    process.exit(1);
  }
}
```

## Topic Customization

### Topic Naming Conventions

Customize topic naming conventions for healthcare domains:

```
<domain>.<entity>.<event-type>
```

Examples:
- `clinical.patient.admitted`
- `clinical.order.created`
- `clinical.result.reported`
- `administrative.appointment.scheduled`
- `financial.claim.submitted`

### Topic Configuration

Customize topic settings for different healthcare data types:

```bash
# Create topic for clinical events with longer retention
kafka-topics --create --topic clinical.events \
  --bootstrap-server kafka-broker:9092 \
  --partitions 16 \
  --replication-factor 3 \
  --config retention.ms=2592000000 \
  --config min.insync.replicas=2 \
  --config cleanup.policy=delete

# Create topic for reference data with compaction
kafka-topics --create --topic reference.data \
  --bootstrap-server kafka-broker:9092 \
  --partitions 8 \
  --replication-factor 3 \
  --config min.insync.replicas=2 \
  --config cleanup.policy=compact

# Create topic for PHI data with encryption
kafka-topics --create --topic patient.demographics \
  --bootstrap-server kafka-broker:9092 \
  --partitions 16 \
  --replication-factor 3 \
  --config min.insync.replicas=2 \
  --config retention.ms=7776000000 \
  --config segment.bytes=536870912
```

## Schema Customization

### Healthcare Schema Design

Customize schemas for healthcare data types:

#### Schema Registry with TypeScript and Confluent Cloud

Using TypeScript with Confluent Cloud Schema Registry provides type safety and schema evolution capabilities:

```typescript
// Define TypeScript interfaces that match the AVRO schema

// Provider interface
interface Provider {
  providerId: string;
  name: string;
  specialty?: string;
  npi?: string;  // National Provider Identifier
}

// Department interface
interface Department {
  departmentId: string;
  name: string;
}

// Bed Assignment interface
interface BedAssignment {
  unit: string;
  room: string;
  bed: string;
}

// Admission Type enum
enum AdmissionType {
  ELECTIVE = 'ELECTIVE',
  URGENT = 'URGENT',
  EMERGENCY = 'EMERGENCY',
  TRANSFER = 'TRANSFER'
}

// Event Metadata with Confluent Cloud extensions
interface EventMetadata {
  eventId: string;
  eventType: string;
  eventSource: string;
  eventTime: number;
  correlationId: string;
  version: string;
  // Confluent Cloud extensions
  traceId?: string;
  schemaId?: number;
  dataClassification?: string;
  retentionPolicy?: string;
}

// Patient Admitted Event interface
interface PatientAdmittedEvent {
  metadata: EventMetadata;
  patientId: string;
  encounterId: string;
  admissionTime: number;
  admittingProvider: Provider;
  admittingDepartment: Department;
  admissionType: AdmissionType;
  admissionReason: string;
  bedAssignment?: BedAssignment;
  // Confluent Cloud specific fields
  sourceSystem?: string;
  dataQuality?: {
    completeness: number;
    validationStatus: 'PASSED' | 'WARNING' | 'FAILED';
    validationMessages?: string[];
  };
}

// Register schema with Confluent Cloud Schema Registry
import { SchemaRegistry, SchemaType } from '@kafkajs/confluent-schema-registry';

// AVRO schema definition for Confluent Cloud Schema Registry
const patientAdmittedEventSchema = {
  type: 'record',
  name: 'PatientAdmittedEvent',
  namespace: 'com.healthcare.events.clinical',
  fields: [
    {
      name: 'metadata',
      type: {
        type: 'record',
        name: 'EventMetadata',
        fields: [
          {name: 'eventId', type: 'string'},
          {name: 'eventType', type: 'string'},
          {name: 'eventSource', type: 'string'},
          {name: 'eventTime', type: 'long'},
          {name: 'correlationId', type: 'string'},
          {name: 'version', type: 'string'},
          // Confluent Cloud extensions
          {name: 'traceId', type: ['null', 'string'], default: null},
          {name: 'schemaId', type: ['null', 'int'], default: null},
          {name: 'dataClassification', type: ['null', 'string'], default: null},
          {name: 'retentionPolicy', type: ['null', 'string'], default: null}
        ]
      }
    },
    {name: 'patientId', type: 'string'},
    {name: 'encounterId', type: 'string'},
    {name: 'admissionTime', type: 'long'},
    {
      name: 'admittingProvider',
      type: {
        type: 'record',
        name: 'Provider',
        fields: [
          {name: 'providerId', type: 'string'},
          {name: 'name', type: 'string'},
          {name: 'specialty', type: ['null', 'string'], default: null},
          {name: 'npi', type: ['null', 'string'], default: null}
        ]
      }
    },
    {
      name: 'admittingDepartment',
      type: {
        type: 'record',
        name: 'Department',
        fields: [
          {name: 'departmentId', type: 'string'},
          {name: 'name', type: 'string'}
        ]
      }
    },
    {
      name: 'admissionType',
      type: {
        type: 'enum',
        name: 'AdmissionType',
        symbols: ['ELECTIVE', 'URGENT', 'EMERGENCY', 'TRANSFER']
      }
    },
    {name: 'admissionReason', type: 'string'},
    {
      name: 'bedAssignment',
      type: ['null', {
        type: 'record',
        name: 'BedAssignment',
        fields: [
          {name: 'unit', type: 'string'},
          {name: 'room', type: 'string'},
          {name: 'bed', type: 'string'}
        ]
      }],
      default: null
    },
    // Confluent Cloud specific fields
    {name: 'sourceSystem', type: ['null', 'string'], default: null},
    {
      name: 'dataQuality',
      type: ['null', {
        type: 'record',
        name: 'DataQuality',
        fields: [
          {name: 'completeness', type: 'double'},
          {name: 'validationStatus', type: {
            type: 'enum',
            name: 'ValidationStatus',
            symbols: ['PASSED', 'WARNING', 'FAILED']
          }},
          {name: 'validationMessages', type: ['null', {
            type: 'array',
            items: 'string'
          }], default: null}
        ]
      }],
      default: null
    }
  ]
};

// Function to register schema with Confluent Cloud Schema Registry
async function registerSchema() {
  // Configure Schema Registry client
  const registry = new SchemaRegistry({
    host: 'https://schema-registry.confluent.cloud',
    auth: {
      username: '${SCHEMA_REGISTRY_KEY}',
      password: '${SCHEMA_REGISTRY_SECRET}'
    }
  });
  
  try {
    // Register the schema with compatibility checking
    const { id } = await registry.register({
      type: SchemaType.AVRO,
      schema: JSON.stringify(patientAdmittedEventSchema),
      subject: 'clinical.patient.admitted-value',
      compatibility: 'BACKWARD' // Ensure backward compatibility
    });
    
    console.log(`Schema registered with ID: ${id}`);
    return id;
  } catch (error) {
    if (error.message.includes('Incompatible schema')) {
      console.error('Schema compatibility check failed:', error.message);
      // Handle schema evolution issues
    } else {
      console.error('Failed to register schema:', error);
    }
    throw error;
  }
}

// Example usage with schema validation
async function producePatientAdmittedEvent(event: PatientAdmittedEvent) {
  const registry = new SchemaRegistry({
    host: 'https://schema-registry.confluent.cloud',
    auth: {
      username: '${SCHEMA_REGISTRY_KEY}',
      password: '${SCHEMA_REGISTRY_SECRET}'
    }
  });
  
  try {
    // Get the latest schema ID
    const { id } = await registry.getLatestSchemaId('clinical.patient.admitted-value');
    
    // Encode the event with schema validation
    const encodedEvent = await registry.encode(id, event);
    
    // Now send the encoded event to Kafka
    // ...
    
    return { success: true, schemaId: id };
  } catch (error) {
    console.error('Error with schema registry:', error);
    throw error;
  }
}
```

### Schema Registry Configuration

Customize Schema Registry for healthcare requirements:

```properties
# Schema Registry Configuration
schema.registry.url=https://schema-registry:8081
schema.compatibility.level=BACKWARD     # Ensure backward compatibility
schema.subject.strategy=io.confluent.kafka.serializers.subject.TopicNameStrategy

# Healthcare-specific configuration
schema.registry.resource.extension.class=com.healthcare.kafka.schema.HealthcareSchemaValidator
schema.registry.schema.version.fetcher=com.healthcare.kafka.schema.CachedSchemaVersionFetcher
```

## Security Customization

### Authentication Customization

Implement healthcare-specific authentication:

```properties
# SASL/PLAIN with LDAP integration
listener.name.sasl_ssl.plain.sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required \
  username="admin" \
  password="${file:/etc/kafka/secrets/credentials:admin_password}" \
  user_admin="${file:/etc/kafka/secrets/credentials:admin_password}" \
  user_clinical="${file:/etc/kafka/secrets/credentials:clinical_password}" \
  user_analytics="${file:/etc/kafka/secrets/credentials:analytics_password}";

# SASL/OAUTHBEARER with OAuth integration
listener.name.sasl_ssl.oauthbearer.sasl.jaas.config=org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required \
  oauth.client.id="kafka-broker" \
  oauth.client.secret="${file:/etc/kafka/secrets/oauth:client_secret}" \
  oauth.token.endpoint.uri="https://auth.healthcare.org/oauth2/token" \
  oauth.jwks.endpoint.uri="https://auth.healthcare.org/oauth2/jwks";

listener.name.sasl_ssl.oauthbearer.sasl.server.callback.handler.class=com.healthcare.kafka.security.HealthcareOAuthBearerValidatorCallbackHandler;
```

### Authorization Customization

Implement healthcare-specific authorization:

```properties
# Custom authorizer for healthcare data access control
authorizer.class.name=com.healthcare.kafka.security.HealthcareAuthorizer

# Authorization configuration
healthcare.authorizer.permission.store=jdbc
healthcare.authorizer.permission.store.jdbc.url=jdbc:postgresql://permissions-db:5432/kafka_acls
healthcare.authorizer.permission.store.jdbc.user=${file:/etc/kafka/secrets/db:username}
healthcare.authorizer.permission.store.jdbc.password=${file:/etc/kafka/secrets/db:password}

# PHI access control
healthcare.authorizer.phi.topic.prefixes=clinical,patient,phi
healthcare.authorizer.phi.access.role=PHI_ACCESS
healthcare.authorizer.audit.topic=security.audit.phi-access
```

### Encryption Customization

Implement healthcare-specific encryption:

```properties
# TLS configuration
ssl.keystore.location=/etc/kafka/secrets/kafka.keystore.jks
ssl.keystore.password=${file:/etc/kafka/secrets/ssl:keystore_password}
ssl.key.password=${file:/etc/kafka/secrets/ssl:key_password}
ssl.truststore.location=/etc/kafka/secrets/kafka.truststore.jks
ssl.truststore.password=${file:/etc/kafka/secrets/ssl:truststore_password}
ssl.client.auth=required
ssl.enabled.protocols=TLSv1.2,TLSv1.3
ssl.cipher.suites=TLS_AES_256_GCM_SHA384,TLS_CHACHA20_POLY1305_SHA256,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
```

## Connector Customization

### HL7 Connector Customization

Customize HL7 connector for healthcare integration:

```json
{
  "name": "hl7-source",
  "config": {
    "connector.class": "com.healthcare.kafka.connect.hl7.Hl7SourceConnector",
    "tasks.max": "3",
    "channels": "ADT,ORM,ORU",
    "port": "2575",
    "batch.size": "100",
    "queue.capacity": "1000",
    "topic.prefix": "hl7.",
    "message.handler.class": "com.healthcare.hl7.CustomHL7MessageHandler",
    "schema.registry.url": "https://schema-registry:8081",
    "hl7.version": "2.5",
    "hl7.validation.enabled": "true",
    "hl7.security.enabled": "true",
    "hl7.security.username": "${file:/etc/kafka/connect/secrets/hl7:username}",
    "hl7.security.password": "${file:/etc/kafka/connect/secrets/hl7:password}"
  }
}
```

### FHIR Connector Customization

Customize FHIR connector for healthcare integration:

```json
{
  "name": "fhir-source",
  "config": {
    "connector.class": "com.healthcare.kafka.connect.fhir.FhirSourceConnector",
    "tasks.max": "2",
    "fhir.server.url": "https://fhir-server:8000/fhir",
    "fhir.server.auth.type": "oauth2",
    "fhir.server.auth.oauth2.token.url": "https://auth-server/token",
    "fhir.server.auth.oauth2.client.id": "${file:/etc/kafka/connect/secrets/fhir:client_id}",
    "fhir.server.auth.oauth2.client.secret": "${file:/etc/kafka/connect/secrets/fhir:client_secret}",
    "fhir.resources": "Patient,Encounter,Observation,MedicationRequest",
    "fhir.subscription.enabled": "true",
    "fhir.subscription.type": "rest-hook",
    "fhir.subscription.criteria": "Observation?status=final",
    "topic.prefix": "fhir.",
    "topic.creation.enabled": "true",
    "schema.registry.url": "https://schema-registry:8081",
    "value.converter": "io.confluent.connect.avro.AvroConverter",
    "value.converter.schema.registry.url": "https://schema-registry:8081",
    "transforms": "extractResource",
    "transforms.extractResource.type": "com.healthcare.kafka.connect.transforms.FhirResourceExtractor"
  }
}
```

## Stream Processing Customization

### Kafka Streams Customization

Customize Kafka Streams for healthcare analytics using TypeScript and Confluent Cloud features:

```typescript
// Import required libraries
import { KafkaStreams, KStream, StreamsConfig } from '@confluentinc/kafka-streams-js';
import { SchemaRegistry } from '@kafkajs/confluent-schema-registry';
import { MetricsReporter } from '@confluentinc/monitoring-interceptors';

// Define healthcare event interfaces
interface HealthcareEvent<T> {
  metadata: {
    eventId: string;
    eventType: string;
    eventSource: string;
    eventTime: number;
    correlationId: string;
    version: string;
    traceId?: string;
  };
  data: T;
}

// Configure Confluent Cloud Kafka Streams for healthcare analytics
const configureHealthcareStreams = async () => {
  // Confluent Cloud configuration
  const streamsConfig = {
    'application.id': 'healthcare-analytics',
    'bootstrap.servers': '${CONFLUENT_BOOTSTRAP_SERVERS}',
    
    // Confluent Cloud authentication
    'sasl.mechanism': 'PLAIN',
    'security.protocol': 'SASL_SSL',
    'sasl.username': '${CONFLUENT_CLOUD_KEY}',
    'sasl.password': '${CONFLUENT_CLOUD_SECRET}',
    
    // Schema Registry configuration
    'schema.registry.url': 'https://schema-registry.confluent.cloud',
    'basic.auth.credentials.source': 'USER_INFO',
    'basic.auth.user.info': '${SCHEMA_REGISTRY_KEY}:${SCHEMA_REGISTRY_SECRET}',
    
    // Confluent Cloud optimizations
    'processing.guarantee': 'exactly_once_v2', // Confluent's improved exactly-once processing
    'num.stream.threads': 4,
    'cache.max.bytes.buffering': 10485760, // 10MB cache
    'commit.interval.ms': 30000,
    'state.dir': '/var/lib/kafka-streams',
    
    // Confluent Cloud monitoring and metrics
    'confluent.monitoring.interceptor.bootstrap.servers': '${CONFLUENT_BOOTSTRAP_SERVERS}',
    'confluent.monitoring.interceptor.security.protocol': 'SASL_SSL',
    'confluent.monitoring.interceptor.sasl.mechanism': 'PLAIN',
    'confluent.monitoring.interceptor.sasl.jaas.config': 
      'org.apache.kafka.common.security.plain.PlainLoginModule required ' +
      `username="${CONFLUENT_CLOUD_KEY}" password="${CONFLUENT_CLOUD_SECRET}";`,
    
    // Advanced Confluent Cloud features
    'topology.optimization': 'all', // Enable Confluent's topology optimizations
    'built.in.metrics.enable': true,
    'metrics.recording.level': 'DEBUG',
    'metrics.sample.window.ms': 30000,
    
    // Healthcare-specific configurations
    'healthcare.phi.encryption.enabled': true,
    'healthcare.audit.logging.enabled': true
  };

  // Create Kafka Streams instance
  const streams = new KafkaStreams(streamsConfig);

  // Configure Schema Registry
  const schemaRegistry = new SchemaRegistry({
    host: 'https://schema-registry.confluent.cloud',
    auth: {
      username: '${SCHEMA_REGISTRY_KEY}',
      password: '${SCHEMA_REGISTRY_SECRET}'
    }
  });

  // Configure metrics reporter for Confluent Cloud observability
  const metricsReporter = new MetricsReporter({
    'bootstrap.servers': '${CONFLUENT_BOOTSTRAP_SERVERS}',
    'security.protocol': 'SASL_SSL',
    'sasl.mechanism': 'PLAIN',
    'sasl.username': '${CONFLUENT_CLOUD_KEY}',
    'sasl.password': '${CONFLUENT_CLOUD_SECRET}',
    'client.id': 'healthcare-analytics-metrics'
  });

  // Return configured instances
  return { streams, schemaRegistry, metricsReporter };
};

// Build healthcare analytics topology
const buildHealthcareAnalyticsTopology = (streams: any, schemaRegistry: any) => {
  // Create the topology builder
  const builder = streams.getNewBuilder();
  
  // Create source streams with Schema Registry integration
  const patientAdmissions: KStream<string, any> = builder.stream('clinical.patient.admitted', {
    keySerde: streams.getSerdes().String,
    valueSerde: streams.getSerdes().Avro // Automatically uses Schema Registry
  });
  
  const patientDischarges: KStream<string, any> = builder.stream('clinical.patient.discharged', {
    keySerde: streams.getSerdes().String,
    valueSerde: streams.getSerdes().Avro
  });
  
  const vitalSigns: KStream<string, any> = builder.stream('clinical.observation.vitals', {
    keySerde: streams.getSerdes().String,
    valueSerde: streams.getSerdes().Avro
  });
  
  // Calculate length of stay for patients
  // Join admissions and discharges by patient encounter ID
  const patientEncounters = patientAdmissions
    .selectKey((_, admission) => admission.data.encounterId)
    .join(
      patientDischarges.selectKey((_, discharge) => discharge.data.encounterId),
      (admission, discharge) => ({
        patientId: admission.data.patientId,
        encounterId: admission.data.encounterId,
        admissionTime: admission.data.admissionTime,
        dischargeTime: discharge.data.dischargeTime,
        lengthOfStay: (discharge.data.dischargeTime - admission.data.admissionTime) / (1000 * 60 * 60 * 24), // in days
        department: admission.data.admittingDepartment.name,
        admissionType: admission.data.admissionType,
        primaryDiagnosis: discharge.data.dischargeDiagnoses?.[0]?.display || 'Unknown'
      })
    );
  
  // Calculate department-level metrics
  const departmentMetrics = patientEncounters
    .groupBy((_, encounter) => encounter.department)
    .aggregate(
      () => ({ // Initial aggregation value
        totalEncounters: 0,
        totalLengthOfStay: 0,
        avgLengthOfStay: 0,
        encountersByType: {
          EMERGENCY: 0,
          ELECTIVE: 0,
          URGENT: 0,
          TRANSFER: 0
        }
      }),
      (department, encounter, aggregate) => {
        // Update the aggregate with this encounter
        aggregate.totalEncounters += 1;
        aggregate.totalLengthOfStay += encounter.lengthOfStay;
        aggregate.avgLengthOfStay = aggregate.totalLengthOfStay / aggregate.totalEncounters;
        aggregate.encountersByType[encounter.admissionType] += 1;
        return aggregate;
      }
    );
  
  // Process vital signs for anomaly detection
  const abnormalVitals = vitalSigns
    .flatMap((patientId, vitalSignEvent) => {
      const abnormalReadings = [];
      
      // Check each vital sign for abnormal values
      for (const vital of vitalSignEvent.data.vitalSigns) {
        let isAbnormal = false;
        
        switch (vital.type) {
          case 'heart_rate':
            isAbnormal = vital.value < vital.normalRange.low || vital.value > vital.normalRange.high;
            break;
          case 'blood_pressure':
            isAbnormal = vital.systolic < vital.normalRange.systolic.low || 
                       vital.systolic > vital.normalRange.systolic.high ||
                       vital.diastolic < vital.normalRange.diastolic.low ||
                       vital.diastolic > vital.normalRange.diastolic.high;
            break;
          // Handle other vital types
        }
        
        if (isAbnormal) {
          abnormalReadings.push({
            key: patientId,
            value: {
              patientId,
              encounterId: vitalSignEvent.data.encounterId,
              vitalType: vital.type,
              vitalValue: vital.value,
              timestamp: vitalSignEvent.metadata.eventTime,
              normalRange: vital.normalRange
            }
          });
        }
      }
      
      return abnormalReadings;
    });
  
  // Send abnormal vitals to a dedicated topic
  abnormalVitals.to('clinical.vitals.abnormal', {
    keySerde: streams.getSerdes().String,
    valueSerde: streams.getSerdes().Json
  });
  
  // Send department metrics to analytics topic
  departmentMetrics.toStream().to('analytics.department.metrics', {
    keySerde: streams.getSerdes().String,
    valueSerde: streams.getSerdes().Json
  });
  
  return builder.build();
};
// Start the healthcare analytics streams application
async function startHealthcareAnalytics() {
  try {
    // Configure streams and schema registry
    const { streams, schemaRegistry, metricsReporter } = await configureHealthcareStreams();
    
    // Build the topology
    const topology = buildHealthcareAnalyticsTopology(streams, schemaRegistry);
    
    // Set the topology
    streams.setTopology(topology);
    
    // Start the metrics reporter
    metricsReporter.start();
    
    // Start the streams with error handling
    await streams.start();
    console.log('Healthcare analytics streams started successfully');
    
    // Add shutdown hook
    process.on('SIGTERM', async () => {
      console.log('Shutting down healthcare analytics streams...');
      await streams.stop();
      metricsReporter.stop();
      process.exit(0);
    });
  } catch (error) {
    console.error('Failed to start healthcare analytics streams:', error);
    process.exit(1);
  }
}

// Execute the streams application
startHealthcareAnalytics();

### ksqlDB Customization with Confluent Cloud

Customize ksqlDB for healthcare analytics using Confluent Cloud's fully-managed ksqlDB service:

```sql
-- Configure ksqlDB properties for Confluent Cloud
SET 'auto.offset.reset' = 'earliest';
SET 'ksql.streams.cache.max.bytes.buffering' = '10000000'; -- 10MB cache
SET 'ksql.streams.num.stream.threads' = '4';
SET 'ksql.streams.processing.guarantee' = 'exactly_once_v2'; -- Confluent Cloud feature

-- Configure Schema Registry integration
SET 'ksql.schema.registry.url' = 'https://schema-registry.confluent.cloud';
SET 'ksql.schema.registry.basic.auth.credentials.source' = 'USER_INFO';
SET 'ksql.schema.registry.basic.auth.user.info' = '${SCHEMA_REGISTRY_KEY}:${SCHEMA_REGISTRY_SECRET}';

-- Enable Confluent Cloud monitoring and metrics
SET 'ksql.streams.producer.confluent.monitoring.interceptor.bootstrap.servers' = '${CONFLUENT_BOOTSTRAP_SERVERS}';
SET 'ksql.streams.producer.confluent.monitoring.interceptor.security.protocol' = 'SASL_SSL';
SET 'ksql.streams.producer.confluent.monitoring.interceptor.sasl.mechanism' = 'PLAIN';
SET 'ksql.streams.producer.confluent.monitoring.interceptor.sasl.jaas.config' = 
  'org.apache.kafka.common.security.plain.PlainLoginModule required ' +
  'username="${CONFLUENT_CLOUD_KEY}" password="${CONFLUENT_CLOUD_SECRET}";';

-- Create a stream for patient admissions with AVRO schema integration
CREATE STREAM patient_admissions (
  patient_id VARCHAR KEY,
  encounter_id VARCHAR,
  admission_time BIGINT,
  admitting_provider STRUCT<
    provider_id VARCHAR, 
    name VARCHAR, 
    specialty VARCHAR, 
    npi VARCHAR
  >,
  admitting_department STRUCT<department_id VARCHAR, name VARCHAR>,
  admission_type VARCHAR,
  admission_reason VARCHAR,
  bed_assignment STRUCT<unit VARCHAR, room VARCHAR, bed VARCHAR>,
  -- Confluent Cloud specific fields
  source_system VARCHAR,
  data_quality STRUCT<
    completeness DOUBLE, 
    validation_status VARCHAR, 
    validation_messages ARRAY<VARCHAR>
  >,
  -- Metadata with tracing information
  metadata STRUCT<
    event_id VARCHAR,
    event_type VARCHAR,
    event_source VARCHAR,
    event_time BIGINT,
    correlation_id VARCHAR,
    version VARCHAR,
    trace_id VARCHAR,
    schema_id INT,
    data_classification VARCHAR,
    retention_policy VARCHAR
  >
) WITH (
  KAFKA_TOPIC = 'clinical.patient.admitted',
  VALUE_FORMAT = 'AVRO',
  PARTITIONS = 6,
  REPLICAS = 3,
  TIMESTAMP = 'metadata->event_time'
);

-- Create a stream for patient discharges with AVRO schema integration
CREATE STREAM patient_discharges (
  patient_id VARCHAR KEY,
  encounter_id VARCHAR,
  discharge_time BIGINT,
  discharging_provider STRUCT<
    provider_id VARCHAR, 
    name VARCHAR, 
    specialty VARCHAR, 
    npi VARCHAR
  >,
  discharge_disposition VARCHAR,
  discharge_diagnoses ARRAY<STRUCT<
    code VARCHAR, 
    system VARCHAR, 
    display VARCHAR, 
    severity VARCHAR, 
    type VARCHAR
  >>,
  length_of_stay DOUBLE,
  medications ARRAY<STRUCT<
    medication VARCHAR, 
    dosage VARCHAR, 
    frequency VARCHAR, 
    duration VARCHAR
  >>,
  follow_up_appointments ARRAY<STRUCT<
    specialty VARCHAR, 
    timeframe VARCHAR, 
    provider VARCHAR, 
    scheduled BOOLEAN
  >>,
  -- Confluent Cloud specific fields
  source_system VARCHAR,
  data_quality STRUCT<
    completeness DOUBLE, 
    validation_status VARCHAR, 
    validation_messages ARRAY<VARCHAR>
  >,
  compliance_status STRUCT<
    medication_reconciliation BOOLEAN, 
    discharge_instructions BOOLEAN, 
    follow_up_scheduled BOOLEAN
  >,
  -- Metadata with tracing information
  metadata STRUCT<
    event_id VARCHAR,
    event_type VARCHAR,
    event_source VARCHAR,
    event_time BIGINT,
    correlation_id VARCHAR,
    version VARCHAR,
    trace_id VARCHAR,
    schema_id INT,
    data_classification VARCHAR,
    retention_policy VARCHAR
  >
) WITH (
  KAFKA_TOPIC = 'clinical.patient.discharged',
  VALUE_FORMAT = 'AVRO',
  PARTITIONS = 6,
  REPLICAS = 3,
  TIMESTAMP = 'metadata->event_time'
);

-- Create a materialized view for length of stay analytics with Confluent Cloud optimization
CREATE TABLE patient_length_of_stay WITH (
  KAFKA_TOPIC = 'analytics.patient.length_of_stay',
  PARTITIONS = 6,
  REPLICAS = 3,
  VALUE_FORMAT = 'AVRO',
  RETENTION_MS = 7776000000 -- 90 days retention (Confluent Cloud feature)
) AS
  SELECT
    a.encounter_id,
    a.patient_id,
    a.admitting_department->name AS department,
    a.admission_type,
    a.admission_time,
    d.discharge_time,
    CAST((d.discharge_time - a.admission_time) / (1000 * 60 * 60 * 24) AS DOUBLE) AS los_days,
    d.discharge_disposition,
    d.discharge_diagnoses[1]->display AS primary_diagnosis,
    a.metadata->correlation_id AS correlation_id,
    -- Confluent Cloud specific fields for analytics
    a.source_system AS admission_source,
    d.source_system AS discharge_source,
    d.compliance_status->medication_reconciliation AS medication_reconciliation_complete,
    d.compliance_status->follow_up_scheduled AS follow_up_scheduled
  FROM patient_admissions a
  JOIN patient_discharges d
  WITHIN 30 DAYS -- Confluent Cloud time-based join window
  ON a.encounter_id = d.encounter_id
  EMIT CHANGES;

-- Create a stream for department-level analytics with Confluent Cloud features
CREATE STREAM department_analytics WITH (
  KAFKA_TOPIC = 'analytics.department.metrics',
  PARTITIONS = 6,
  REPLICAS = 3,
  VALUE_FORMAT = 'AVRO',
  RETENTION_MS = 7776000000 -- 90 days retention
) AS
  SELECT
    department,
    COUNT(*) AS total_encounters,
    AVG(los_days) AS avg_length_of_stay,
    COUNT_DISTINCT(patient_id) AS unique_patients,
    SUM(CASE WHEN admission_type = 'EMERGENCY' THEN 1 ELSE 0 END) AS emergency_admissions,
    SUM(CASE WHEN admission_type = 'ELECTIVE' THEN 1 ELSE 0 END) AS elective_admissions,
    SUM(CASE WHEN los_days > 7 THEN 1 ELSE 0 END) AS extended_stays,
    -- Add compliance metrics
    SUM(CASE WHEN medication_reconciliation_complete THEN 1 ELSE 0 END) AS med_rec_complete_count,
    CAST(SUM(CASE WHEN medication_reconciliation_complete THEN 1 ELSE 0 END) AS DOUBLE) / COUNT(*) * 100 AS med_rec_compliance_pct,
    SUM(CASE WHEN follow_up_scheduled THEN 1 ELSE 0 END) AS follow_up_scheduled_count,
    CAST(SUM(CASE WHEN follow_up_scheduled THEN 1 ELSE 0 END) AS DOUBLE) / COUNT(*) * 100 AS follow_up_compliance_pct
  FROM patient_length_of_stay
  WINDOW TUMBLING (SIZE 24 HOURS) -- Confluent Cloud windowing feature
  GROUP BY department
  EMIT CHANGES;

-- Create a real-time dashboard for clinical operations
CREATE TABLE department_daily_metrics WITH (
  KAFKA_TOPIC = 'analytics.department.daily',
  PARTITIONS = 6,
  REPLICAS = 3,
  VALUE_FORMAT = 'AVRO',
  RETENTION_MS = 7776000000 -- 90 days retention
) AS
  SELECT
    department,
    TIMESTAMPTOSTRING(WINDOWSTART, 'yyyy-MM-dd') AS date,
    COUNT(*) AS discharge_count,
    AVG(los_days) AS avg_length_of_stay,
    -- Add quality metrics
    CAST(SUM(CASE WHEN med_rec_compliance_pct >= 95 THEN 1 ELSE 0 END) AS DOUBLE) / COUNT(*) * 100 AS quality_compliance_pct
  FROM department_analytics
  WINDOW TUMBLING (SIZE 24 HOURS)
  GROUP BY department, WINDOWSTART
  EMIT CHANGES;

CREATE STREAM department_los_metrics AS
  SELECT
    department,
    admission_type,
    discharge_disposition,
    AVG(los_days) AS average_los,
    MIN(los_days) AS min_los,
    MAX(los_days) AS max_los
  FROM patient_length_of_stay
  WINDOW TUMBLING (SIZE 7 DAYS)
  GROUP BY department, admission_type, discharge_disposition
  EMIT CHANGES;

## Monitoring Customization

### Metrics Customization with Confluent Cloud

Customize monitoring metrics for healthcare operations using TypeScript and Confluent Cloud's observability features:

```typescript
// Import required libraries
import { Counter, Gauge, Histogram, Summary } from 'prom-client';
import { ConfluentMetricsReporter } from '@confluentinc/metrics';
import { OpenTelemetry, metrics } from '@opentelemetry/api';
import { Resource } from '@opentelemetry/resources';
import { SemanticResourceAttributes } from '@opentelemetry/semantic-conventions';

// Configure OpenTelemetry for Confluent Cloud integration
const configureTelemetry = () => {
  // Create a resource that identifies your healthcare service
  const resource = new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: 'healthcare-event-broker',
    [SemanticResourceAttributes.SERVICE_VERSION]: '1.0.0',
    [SemanticResourceAttributes.DEPLOYMENT_ENVIRONMENT]: 'production',
    'healthcare.domain': 'clinical',
    'healthcare.component': 'event-broker'
  });

  // Configure Confluent Cloud Metrics Reporter
  const metricsReporter = new ConfluentMetricsReporter({
    'bootstrap.servers': '${CONFLUENT_BOOTSTRAP_SERVERS}',
    'security.protocol': 'SASL_SSL',
    'sasl.mechanism': 'PLAIN',
    'sasl.username': '${CONFLUENT_CLOUD_KEY}',
    'sasl.password': '${CONFLUENT_CLOUD_SECRET}',
    'client.id': 'healthcare-metrics',
    // Confluent Cloud specific settings
    'confluent.metrics.reporter.bootstrap.servers': '${CONFLUENT_BOOTSTRAP_SERVERS}',
    'confluent.metrics.reporter.sasl.mechanism': 'PLAIN',
    'confluent.metrics.reporter.security.protocol': 'SASL_SSL',
    'confluent.metrics.reporter.sasl.jaas.config': 
      'org.apache.kafka.common.security.plain.PlainLoginModule required ' +
      `username="${CONFLUENT_CLOUD_KEY}" password="${CONFLUENT_CLOUD_SECRET}";`,
    'confluent.metrics.reporter.topic.replicas': 3
  });

  return { resource, metricsReporter };
};

// Create healthcare-specific metrics
const createHealthcareMetrics = (registry: any) => {
  // Clinical event metrics with Confluent Cloud dimensions
  const clinicalEvents = new Counter({
    name: 'healthcare_clinical_events_total',
    help: 'Total number of clinical events processed',
    labelNames: ['event_type', 'source_system', 'department', 'data_classification'],
    registers: [registry]
  });

  // Patient metrics
  const patientAdmissions = new Counter({
    name: 'healthcare_patient_admissions_total',
    help: 'Total number of patient admissions',
    labelNames: ['department', 'admission_type', 'facility'],
    registers: [registry]
  });

  const patientDischarges = new Counter({
    name: 'healthcare_patient_discharges_total',
    help: 'Total number of patient discharges',
    labelNames: ['department', 'discharge_disposition', 'facility'],
    registers: [registry]
  });

  const patientTransfers = new Counter({
    name: 'healthcare_patient_transfers_total',
    help: 'Total number of patient transfers',
    labelNames: ['source_department', 'target_department', 'facility'],
    registers: [registry]
  });

  // Length of stay metrics
  const lengthOfStay = new Histogram({
    name: 'healthcare_length_of_stay_days',
    help: 'Patient length of stay in days',
    labelNames: ['department', 'admission_type', 'discharge_disposition'],
    buckets: [1, 2, 3, 5, 7, 10, 14, 21, 30, 60, 90],
    registers: [registry]
  });

  // Clinical alert metrics
  const clinicalAlerts = new Counter({
    name: 'healthcare_clinical_alerts_total',
    help: 'Total number of clinical alerts generated',
    labelNames: ['severity', 'alert_type', 'department'],
    registers: [registry]
  });

  // Compliance metrics
  const complianceMetrics = new Gauge({
    name: 'healthcare_compliance_percentage',
    help: 'Compliance percentage for healthcare processes',
    labelNames: ['metric_type', 'department'],
    registers: [registry]
  });

  // Performance metrics with Confluent Cloud dimensions
  const messageProcessingTime = new Histogram({
    name: 'kafka_message_processing_seconds',
    help: 'Time taken to process Kafka messages',
    labelNames: ['topic', 'event_type', 'consumer_group'],
    buckets: [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1, 5],
    registers: [registry]
  });

  const messageLag = new Gauge({
    name: 'kafka_consumer_lag',
    help: 'Lag in messages for Kafka consumer',
    labelNames: ['topic', 'partition', 'consumer_group'],
    registers: [registry]
  });

  // Schema Registry metrics
  const schemaRegistryRequests = new Counter({
    name: 'schema_registry_requests_total',
    help: 'Total number of Schema Registry requests',
    labelNames: ['operation', 'subject', 'status_code'],
    registers: [registry]
  });

  // Return all metrics
  return {
    clinicalEvents,
    patientAdmissions,
    patientDischarges,
    patientTransfers,
    lengthOfStay,
    clinicalAlerts,
    complianceMetrics,
    messageProcessingTime,
    messageLag,
    schemaRegistryRequests
  };
};

// Example usage with Confluent Cloud integration
const monitorHealthcareEvents = async () => {
  // Configure telemetry
  const { resource, metricsReporter } = configureTelemetry();
  
  // Start Confluent Cloud metrics reporter
  await metricsReporter.start();
  
  // Create registry and metrics
  const registry = new metrics.Registry();
  const healthcareMetrics = createHealthcareMetrics(registry);
  
  // Example: Track patient admission
  const trackPatientAdmission = (event: any) => {
    // Increment clinical events counter
    healthcareMetrics.clinicalEvents.inc({
      event_type: 'patient.admitted',
      source_system: event.metadata.eventSource,
      department: event.data.admittingDepartment.name,
      data_classification: event.metadata.dataClassification || 'PHI'
    });
    
    // Increment patient admissions counter
    healthcareMetrics.patientAdmissions.inc({
      department: event.data.admittingDepartment.name,
      admission_type: event.data.admissionType,
      facility: event.data.facility.name
    });
    
    // Send metrics to Confluent Cloud
    metricsReporter.report({
      'healthcare.events.admission': 1,
      'healthcare.department': event.data.admittingDepartment.name,
      'healthcare.admission.type': event.data.admissionType
    });
  };
  
  // Example: Track patient discharge and length of stay
  const trackPatientDischarge = (event: any, lengthOfStayDays: number) => {
    // Increment clinical events counter
    healthcareMetrics.clinicalEvents.inc({
      event_type: 'patient.discharged',
      source_system: event.metadata.eventSource,
      department: event.data.dischargingDepartment.name,
      data_classification: event.metadata.dataClassification || 'PHI'
    });
    
    // Increment patient discharges counter
    healthcareMetrics.patientDischarges.inc({
      department: event.data.dischargingDepartment.name,
      discharge_disposition: event.data.dischargeDisposition,
      facility: event.data.facility.name
    });
    
    // Record length of stay
    healthcareMetrics.lengthOfStay.observe(
      {
        department: event.data.dischargingDepartment.name,
        admission_type: event.data.admissionType,
        discharge_disposition: event.data.dischargeDisposition
      },
      lengthOfStayDays
    );
    
    // Track compliance metrics
    if (event.data.complianceStatus) {
      healthcareMetrics.complianceMetrics.set(
        { metric_type: 'medication_reconciliation', department: event.data.dischargingDepartment.name },
        event.data.complianceStatus.medicationReconciliation ? 100 : 0
      );
      
      healthcareMetrics.complianceMetrics.set(
        { metric_type: 'follow_up_scheduled', department: event.data.dischargingDepartment.name },
        event.data.complianceStatus.followUpScheduled ? 100 : 0
      );
    }
    
    // Send metrics to Confluent Cloud
    metricsReporter.report({
      'healthcare.events.discharge': 1,
      'healthcare.department': event.data.dischargingDepartment.name,
      'healthcare.discharge.disposition': event.data.dischargeDisposition,
      'healthcare.length_of_stay': lengthOfStayDays
    });
  };
  
  // Example: Track clinical alerts
  const trackClinicalAlert = (alert: any) => {
    healthcareMetrics.clinicalAlerts.inc({
      severity: alert.severity,
      alert_type: alert.alertType,
      department: alert.department
    });
    
    // Send metrics to Confluent Cloud
    metricsReporter.report({
      'healthcare.alerts': 1,
      'healthcare.alerts.severity': alert.severity,
      'healthcare.alerts.type': alert.alertType
    });
  };
  
  // Example: Track message processing time
  const trackMessageProcessing = (topic: string, eventType: string, consumerGroup: string, processingTimeMs: number) => {
    healthcareMetrics.messageProcessingTime.observe(
      { topic, event_type: eventType, consumer_group: consumerGroup },
      processingTimeMs / 1000 // Convert to seconds
    );
  };
  
  // Example: Track consumer lag
  const trackConsumerLag = (topic: string, partition: number, consumerGroup: string, lag: number) => {
    healthcareMetrics.messageLag.set({ topic, partition: partition.toString(), consumer_group: consumerGroup }, lag);
  };
  
  // Handle graceful shutdown
  process.on('SIGTERM', async () => {
    console.log('Shutting down metrics reporter...');
    await metricsReporter.stop();
    process.exit(0);
  });
  
  return {
    trackPatientAdmission,
    trackPatientDischarge,
    trackClinicalAlert,
    trackMessageProcessing,
    trackConsumerLag
  };
};

// Execute monitoring setup
monitorHealthcareEvents().catch(error => {
  console.error('Failed to initialize healthcare monitoring:', error);
  process.exit(1);
});
```

### Alerting Customization

Customize alerting for healthcare-specific conditions:

```yaml
# Prometheus alerting rules for healthcare events
groups:
- name: healthcare-alerts
  rules:
  - alert: CriticalClinicalAlerts
    expr: rate(clinical_alerts_critical_total[5m]) > 5
    for: 2m
    labels:
      severity: critical
      domain: clinical
    annotations:
      summary: "High rate of critical clinical alerts"
      description: "There have been {{ $value }} critical clinical alerts in the last 5 minutes."

  - alert: PatientFlowAnomaly
    expr: abs(rate(clinical_events_admissions_total[1h]) - rate(clinical_events_discharges_total[1h])) > 10
    for: 30m
    labels:
      severity: warning
      domain: operations
    annotations:
      summary: "Patient flow anomaly detected"
      description: "Significant imbalance between admission and discharge rates."

  - alert: KafkaBrokerDown
    expr: kafka_server_active_controller_count{job="kafka"} == 0
    for: 1m
    labels:
      severity: critical
      domain: infrastructure
    annotations:
      summary: "Kafka broker down"
      description: "No active controller in the Kafka cluster."

  - alert: HighMemoryUsage
    expr: (sum by (instance) (jvm_memory_bytes_used{job="kafka"}) / sum by (instance) (jvm_memory_bytes_max{job="kafka"})) * 100 > 85
    for: 5m
    labels:
      severity: warning
      domain: infrastructure
    annotations:
      summary: "Kafka high memory usage ({{ $labels.instance }})"
      description: "Kafka broker {{ $labels.instance }} has memory usage of {{ $value }}% for more than 5 minutes."

  - alert: ClinicalTopicInactivity
    expr: rate(kafka_server_broker_topic_metrics_messages_in_one_minute_rate{topic=~"clinical.*"}[5m]) == 0
    for: 15m
    labels:
      severity: warning
      domain: healthcare
    annotations:
      summary: "Clinical topic inactivity ({{ $labels.topic }})"
      description: "Clinical topic {{ $labels.topic }} has no messages for more than 15 minutes during business hours."
```

## Conclusion

The Event Broker provides extensive customization options to meet the specific requirements of healthcare organizations. By leveraging these customization mechanisms, you can tailor the Event Broker's behavior, performance, security, and integration patterns while maintaining compatibility with the overall CMM Technology Platform. These customizations enable you to build a robust, secure, and efficient event-driven architecture for healthcare applications.

## Related Documentation

- [Event Broker Architecture](../01-getting-started/architecture.md)
- [Core APIs](../02-core-functionality/core-apis.md)
- [Extension Points](./extension-points.md)
- [Advanced Use Cases](./advanced-use-cases.md)
