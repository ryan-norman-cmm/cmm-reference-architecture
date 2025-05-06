# Event Broker Core APIs

## Introduction

This document describes the core APIs provided by the Event Broker component of the CMM Technology Platform. These APIs enable applications to produce and consume events, manage topics, and interact with the event streaming platform. The Event Broker, built on Confluent Kafka, provides a comprehensive set of APIs for event-driven healthcare applications.

## API Overview

The Event Broker provides several categories of APIs:

1. **Client APIs**: For producing and consuming events
2. **Admin APIs**: For managing Kafka resources
3. **Schema Registry APIs**: For managing event schemas
4. **Connect APIs**: For integrating with external systems
5. **Stream Processing APIs**: For real-time data processing
6. **REST Proxy APIs**: For HTTP-based access to Kafka

## Client APIs

### Producer API

The Producer API enables applications to publish events to topics:

```typescript
// Create producer configuration
const producerConfig = {
  'bootstrap.servers': 'kafka-broker:9092',
  'key.serializer': Serializers.STRING,
  'value.serializer': Serializers.AVRO,  // Using Confluent Schema Registry
  
  // Confluent Cloud configuration
  'sasl.mechanism': 'PLAIN',
  'security.protocol': 'SASL_SSL',
  'sasl.username': '${CONFLUENT_CLOUD_KEY}',
  'sasl.password': '${CONFLUENT_CLOUD_SECRET}',
  
  // Reliability settings
  'enable.idempotence': true,  // Exactly-once semantics
  'acks': 'all',  // Wait for all replicas
  'compression.type': 'lz4',  // Efficient compression
  'linger.ms': 10,  // Batch messages
  
  // Schema Registry configuration
  'schema.registry.url': 'https://schema-registry.confluent.cloud',
  'basic.auth.credentials.source': 'USER_INFO',
  'basic.auth.user.info': '${SCHEMA_REGISTRY_KEY}:${SCHEMA_REGISTRY_SECRET}'
};

// Define the patient event interface
interface PatientEvent {
  patientId: string;
  eventType: string;
  timestamp: number;
  department: string;
}

// Create the producer
const producer = new Kafka.Producer(producerConfig);

// Connect to the Kafka cluster
await producer.connect();

// Create a patient admission event
const event: PatientEvent = {
  patientId: 'P123456',
  eventType: 'ADMISSION',
  timestamp: Date.now(),
  department: 'Emergency'
};

// Send the event
try {
  const result = await producer.produce({
    topic: 'clinical.patient.admitted',
    key: event.patientId,
    value: event,
    // Optional partition and timestamp
    // partition: 0,
    // timestamp: Date.now()
  });
  
  console.log(`Event sent successfully to ${result.topic}-${result.partition} @ ${result.offset}`);
} catch (error) {
  console.error('Failed to send event', error);
} finally {
  // Flush and close the producer when done
  await producer.flush();
  await producer.disconnect();
}
```

#### Key Producer Configurations

| Configuration | Description | Default | Healthcare Recommendation |
|---------------|-------------|---------|---------------------------|
| `bootstrap.servers` | List of Kafka brokers | - | Use load-balanced endpoint |
| `key.serializer` | Serializer for event keys | - | Use appropriate serializer for key type |
| `value.serializer` | Serializer for event values | - | Use schema-based serializer |
| `acks` | Acknowledgment level | 1 | Use `all` for critical healthcare events |
| `retries` | Number of retries | 2147483647 | Keep default for healthcare |
| `delivery.timeout.ms` | Maximum time to wait for send to succeed | 120000 | Increase for critical events |
| `linger.ms` | Time to wait for more events before sending | 0 | Set to 5-10ms for efficiency |
| `batch.size` | Maximum batch size in bytes | 16384 | Increase to 32768-65536 for throughput |
| `compression.type` | Compression algorithm | none | Use `lz4` for healthcare data |

### Consumer API

The Consumer API enables applications to subscribe to topics and process events:

```typescript
// Create consumer configuration
const consumerConfig = {
  'bootstrap.servers': 'kafka-broker:9092',
  'group.id': 'patient-admission-processor',
  'key.deserializer': Deserializers.STRING,
  'value.deserializer': Deserializers.AVRO,  // Using Confluent Schema Registry
  'auto.offset.reset': 'earliest',  // Start from earliest available message
  
  // Confluent Cloud configuration
  'sasl.mechanism': 'PLAIN',
  'security.protocol': 'SASL_SSL',
  'sasl.username': '${CONFLUENT_CLOUD_KEY}',
  'sasl.password': '${CONFLUENT_CLOUD_SECRET}',
  
  // Reliability settings
  'enable.auto.commit': false,  // Manual commit for reliability
  'isolation.level': 'read_committed',  // Only read committed transactions
  
  // Schema Registry configuration
  'schema.registry.url': 'https://schema-registry.confluent.cloud',
  'basic.auth.credentials.source': 'USER_INFO',
  'basic.auth.user.info': '${SCHEMA_REGISTRY_KEY}:${SCHEMA_REGISTRY_SECRET}',
  
  // Confluent Cloud Monitoring
  'confluent.monitoring.interceptor.bootstrap.servers': 'kafka-broker:9092',
  'confluent.monitoring.interceptor.security.protocol': 'SASL_SSL',
  'confluent.monitoring.interceptor.sasl.mechanism': 'PLAIN',
  'confluent.monitoring.interceptor.sasl.jaas.config': 'org.apache.kafka.common.security.plain.PlainLoginModule required username="${CONFLUENT_CLOUD_KEY}" password="${CONFLUENT_CLOUD_SECRET}";'
};

// Define the patient event interface
interface PatientEvent {
  patientId: string;
  eventType: string;
  timestamp: number;
  department: string;
}

// Create the consumer
const consumer = new Kafka.Consumer(consumerConfig);

// Define event handler
consumer.on('data', async (data) => {
  const event: PatientEvent = data.value;
  
  console.log(`Received event: patient=${event.patientId}, timestamp=${event.timestamp}, department=${event.department}`);
  
  // Process the event
  await processPatientAdmission(event);
  
  // Commit offset manually after processing
  consumer.commit(data);
});

// Handle errors
consumer.on('error', (error) => {
  console.error('Error in consumer:', error);
});

// Connect and subscribe to the topic
try {
  await consumer.connect();
  await consumer.subscribe(['clinical.patient.admitted']);
  
  // Start consuming (this will trigger the 'data' event handler)
  consumer.consume();
  
  // Add shutdown handler
  process.on('SIGTERM', async () => {
    console.log('Disconnecting consumer...');
    await consumer.disconnect();
  });
} catch (error) {
  console.error('Failed to set up consumer:', error);
}
```

#### Key Consumer Configurations

| Configuration | Description | Default | Healthcare Recommendation |
|---------------|-------------|---------|---------------------------|
| `bootstrap.servers` | List of Kafka brokers | - | Use load-balanced endpoint |
| `group.id` | Consumer group identifier | - | Use descriptive names for healthcare processors |
| `key.deserializer` | Deserializer for event keys | - | Match producer serializer |
| `value.deserializer` | Deserializer for event values | - | Match producer serializer |
| `auto.offset.reset` | Position when no offset exists | latest | Use `earliest` for healthcare to avoid missing events |
| `enable.auto.commit` | Automatic offset commits | true | Set to `false` for critical healthcare processing |
| `isolation.level` | Transaction isolation level | read_uncommitted | Use `read_committed` for healthcare data |
| `max.poll.records` | Maximum records per poll | 500 | Adjust based on processing capacity |
| `session.timeout.ms` | Consumer group session timeout | 10000 | Increase for complex healthcare event processing |

## Admin API

The Admin API enables programmatic management of Kafka resources:

```typescript
// Create admin client configuration
const adminConfig = {
  'bootstrap.servers': 'kafka-broker:9092',
  
  // Confluent Cloud configuration
  'sasl.mechanism': 'PLAIN',
  'security.protocol': 'SASL_SSL',
  'sasl.username': '${CONFLUENT_CLOUD_KEY}',
  'sasl.password': '${CONFLUENT_CLOUD_SECRET}'
};

// Create the admin client
const adminClient = Kafka.AdminClient.create(adminConfig);

// Define topic configuration
const topicConfig = {
  // Topic name
  topic: 'clinical.patient.vitals',
  
  // Number of partitions - sized for throughput
  numPartitions: 8,
  
  // Replication factor - using Confluent Cloud's recommended value
  replicationFactor: 3,
  
  // Topic configurations
  configEntries: [
    // 7 days retention
    { name: 'retention.ms', value: '604800000' },
    
    // Cleanup policy
    { name: 'cleanup.policy', value: 'delete' },
    
    // Confluent Cloud optimizations
    { name: 'min.insync.replicas', value: '2' },
    { name: 'unclean.leader.election.enable', value: 'false' },
    
    // Confluent Tiered Storage for cost optimization
    { name: 'confluent.tier.enable', value: 'true' },
    { name: 'confluent.tier.local.hotset.ms', value: '86400000' }, // 1 day in hot storage
    { name: 'confluent.tier.local.hotset.bytes', value: '1073741824' } // 1GB in hot storage
  ]
};

// Create the topic
async function createTopic() {
  try {
    // Check if topic exists first (Confluent Cloud best practice)
    const existingTopics = await adminClient.listTopics();
    if (existingTopics.topics.includes(topicConfig.topic)) {
      console.log(`Topic ${topicConfig.topic} already exists`);
      return;
    }
    
    // Create the topic
    await adminClient.createTopics({
      topics: [topicConfig],
      validateOnly: false // Set to true to validate without creating
    });
    
    console.log(`Topic ${topicConfig.topic} created successfully`);
  } catch (error) {
    console.error('Failed to create topic:', error);
  } finally {
    // Close the admin client
    await adminClient.disconnect();
  }
}

// Execute topic creation
createTopic();
```

### Topic Management APIs

| Operation | Description | Example Use Case |
|-----------|-------------|------------------|
| `createTopics` | Create new topics | Creating topics for new healthcare event types |
| `deleteTopics` | Delete topics | Removing deprecated event streams |
| `listTopics` | List available topics | Discovering available healthcare event streams |
| `describeTopics` | Get topic details | Inspecting healthcare topic configuration |
| `describeConfigs` | Get topic configuration | Auditing topic settings for compliance |
| `alterConfigs` | Modify topic configuration | Adjusting retention for regulatory requirements |

### Consumer Group Management APIs

| Operation | Description | Example Use Case |
|-----------|-------------|------------------|
| `listConsumerGroups` | List consumer groups | Monitoring active healthcare event processors |
| `describeConsumerGroups` | Get consumer group details | Troubleshooting event processing issues |
| `deleteConsumerGroups` | Delete consumer groups | Cleaning up inactive processors |

## Schema Registry API

The Schema Registry API enables management of event schemas:

```typescript
// Create Schema Registry client configuration
const schemaRegistryConfig = {
  // Confluent Cloud Schema Registry URL
  baseUrl: 'https://schema-registry.confluent.cloud',
  
  // Authentication for Confluent Cloud
  auth: {
    username: '${SCHEMA_REGISTRY_KEY}',
    password: '${SCHEMA_REGISTRY_SECRET}'
  }
};

// Create Schema Registry client
const schemaRegistry = new ConfluentSchemaRegistry(schemaRegistryConfig);

// Define a schema for patient events using AVRO
const schema = {
  type: 'record',
  name: 'PatientEvent',
  namespace: 'com.healthcare.events',
  fields: [
    { name: 'patientId', type: 'string' },
    { name: 'eventType', type: 'string' },
    { name: 'timestamp', type: 'long', logicalType: 'timestamp-millis' },
    { name: 'department', type: ['null', 'string'], default: null }
  ]
};

// Register the schema with compatibility checking
async function registerSchema() {
  try {
    // Check compatibility before registering (Confluent Schema Registry feature)
    const compatibilityResult = await schemaRegistry.checkCompatibility({
      subject: 'clinical.patient.admitted-value',
      schema: JSON.stringify(schema),
      version: 'latest'
    });
    
    if (compatibilityResult.is_compatible) {
      // Register the schema
      const result = await schemaRegistry.register({
        subject: 'clinical.patient.admitted-value',
        schema: JSON.stringify(schema),
        schemaType: 'AVRO'
      });
      
      console.log(`Schema registered with ID: ${result.id}`);
      
      // Use Confluent Schema Registry's schema evolution features
      // Set compatibility mode to BACKWARD (Confluent recommended default)
      await schemaRegistry.updateCompatibility({
        subject: 'clinical.patient.admitted-value',
        compatibility: 'BACKWARD'
      });
    } else {
      console.error('Schema is not compatible with previous versions');
    }
  } catch (error) {
    console.error('Failed to register schema:', error);
  }
}

// Execute schema registration
registerSchema();
```

### Schema Management APIs

| Operation | Description | Example Use Case |
|-----------|-------------|------------------|
| `register` | Register a new schema | Adding a new healthcare event schema |
| `getById` | Retrieve schema by ID | Deserializing healthcare events |
| `getBySubject` | Retrieve schemas for a subject | Inspecting healthcare event structure |
| `getAllVersions` | Get all versions of a schema | Tracking schema evolution |
| `updateCompatibility` | Update compatibility rules | Enforcing backward compatibility |
| `testCompatibility` | Test schema compatibility | Validating schema changes |

## Connect API

The Connect API enables integration with external systems:

```typescript
// Create connector configuration for Confluent Cloud
const connectorConfig = {
  // Connector name
  name: 'ehr-db-source',
  
  // Connector class - using Confluent's fully-managed connector
  'connector.class': 'PostgresSource',
  
  // Kafka topic configuration
  'topic.prefix': 'db-',
  
  // Database connection details
  'connection.host': 'db.example.com',
  'connection.port': '5432',
  'connection.database': 'ehrdb',
  'connection.user': '${file:/secrets/db-credentials:username}',
  'connection.password': '${file:/secrets/db-credentials:password}',
  
  // Tables to sync
  'table.include.list': 'patients,encounters,observations',
  
  // Incremental snapshot mode (Confluent optimized feature)
  'snapshot.mode': 'always',
  'snapshot.fetch.size': '10000',
  
  // CDC configuration using Debezium (Confluent optimized)
  'plugin.name': 'pgoutput',
  'publication.name': 'ehr_publication',
  'slot.name': 'ehr_replication_slot',
  
  // Schema handling with Confluent Schema Registry
  'key.converter': 'io.confluent.connect.avro.AvroConverter',
  'key.converter.schema.registry.url': 'https://schema-registry.confluent.cloud',
  'key.converter.basic.auth.credentials.source': 'USER_INFO',
  'key.converter.basic.auth.user.info': '${SCHEMA_REGISTRY_KEY}:${SCHEMA_REGISTRY_SECRET}',
  
  'value.converter': 'io.confluent.connect.avro.AvroConverter',
  'value.converter.schema.registry.url': 'https://schema-registry.confluent.cloud',
  'value.converter.basic.auth.credentials.source': 'USER_INFO',
  'value.converter.basic.auth.user.info': '${SCHEMA_REGISTRY_KEY}:${SCHEMA_REGISTRY_SECRET}',
  
  // Confluent Cloud specific configurations
  'tasks.max': '2',
  'transforms': 'unwrap',
  'transforms.unwrap.type': 'io.debezium.transforms.ExtractNewRecordState',
  'transforms.unwrap.drop.tombstones': 'false',
  'transforms.unwrap.delete.handling.mode': 'rewrite'
};

// Create Confluent Cloud Connect API client
const connectClient = new ConfluentConnectClient({
  // Confluent Cloud Connect API endpoint
  baseUrl: 'https://api.confluent.cloud/connect/v1/environments/${ENVIRONMENT_ID}/clusters/${CLUSTER_ID}',
  
  // Authentication for Confluent Cloud
  auth: {
    username: '${CONFLUENT_CLOUD_KEY}',
    password: '${CONFLUENT_CLOUD_SECRET}'
  }
});

// Create and manage the connector
async function createConnector() {
  try {
    // Check if connector already exists
    try {
      const existingConnector = await connectClient.getConnector(connectorConfig.name);
      console.log(`Connector ${connectorConfig.name} already exists`);
      
      // Update the connector if it exists
      const updatedConnector = await connectClient.updateConnectorConfig(
        connectorConfig.name,
        connectorConfig
      );
      console.log(`Connector ${connectorConfig.name} updated`);
      return;
    } catch (error) {
      // Connector doesn't exist, continue with creation
    }
    
    // Create the connector
    const result = await connectClient.createConnector(connectorConfig);
    console.log(`Connector ${result.name} created successfully`);
    
    // Monitor connector status (Confluent Cloud feature)
    const status = await connectClient.getConnectorStatus(connectorConfig.name);
    console.log(`Connector status: ${status.connector.state}`);
  } catch (error) {
    console.error('Failed to create connector:', error);
  }
}

// Execute connector creation
createConnector();
```

### Connector Management APIs

| Operation | Description | Example Use Case |
|-----------|-------------|------------------|
| `createConnector` | Create a new connector | Setting up EHR data integration |
| `deleteConnector` | Delete a connector | Removing deprecated integrations |
| `pauseConnector` | Pause a connector | Temporarily stopping data flow |
| `resumeConnector` | Resume a paused connector | Restarting data integration |
| `getConnector` | Get connector details | Inspecting integration configuration |
| `getConnectorConfig` | Get connector configuration | Auditing connector settings |
| `getConnectorStatus` | Get connector status | Monitoring integration health |
| `restartConnector` | Restart a connector | Recovering from errors |

## Stream Processing API

### Kafka Streams API

The Kafka Streams API enables real-time stream processing:

```typescript
// Import Confluent Cloud Kafka Streams library
import { KafkaStreams, KStream, StreamsConfig } from '@confluentinc/kafka-streams-js';

// Define the vital sign interface
interface VitalSign {
  patientId: string;
  type: string;
  value: number;
  unit: string;
  timestamp: number;
}

// Define the alert interface
interface VitalSignAlert {
  patientId: string;
  type: string;
  value: number;
  unit: string;
  severity: 'CRITICAL' | 'WARNING' | 'INFO';
  message: string;
  timestamp: number;
}

// Create stream configuration for Confluent Cloud
const streamsConfig = {
  'application.id': 'vital-signs-processor',
  'bootstrap.servers': 'kafka-broker:9092',
  
  // Confluent Cloud configuration
  'sasl.mechanism': 'PLAIN',
  'security.protocol': 'SASL_SSL',
  'sasl.username': '${CONFLUENT_CLOUD_KEY}',
  'sasl.password': '${CONFLUENT_CLOUD_SECRET}',
  
  // Schema Registry configuration
  'schema.registry.url': 'https://schema-registry.confluent.cloud',
  'basic.auth.credentials.source': 'USER_INFO',
  'basic.auth.user.info': '${SCHEMA_REGISTRY_KEY}:${SCHEMA_REGISTRY_SECRET}',
  
  // Exactly-once processing (Confluent feature)
  'processing.guarantee': 'exactly_once_v2',
  
  // Confluent Monitoring
  'confluent.monitoring.interceptor.bootstrap.servers': 'kafka-broker:9092',
  'confluent.monitoring.interceptor.security.protocol': 'SASL_SSL',
  'confluent.monitoring.interceptor.sasl.mechanism': 'PLAIN',
  'confluent.monitoring.interceptor.sasl.jaas.config': 'org.apache.kafka.common.security.plain.PlainLoginModule required username="${CONFLUENT_CLOUD_KEY}" password="${CONFLUENT_CLOUD_SECRET}";',
  
  // Performance tuning
  'num.stream.threads': 4,
  'cache.max.bytes.buffering': 10485760, // 10MB cache
  'commit.interval.ms': 1000 // 1 second commit interval
};

// Create the Kafka Streams instance
const streams = new KafkaStreams(streamsConfig);

// Define the topology builder function
const buildTopology = () => {
  // Create the topology builder
  const builder = streams.getNewBuilder();
  
  // Read from vitals topic with schema registry integration
  const vitalSigns: KStream<string, VitalSign> = builder.stream('clinical.patient.vitals', {
    keySerde: streams.getSerdes().String,
    valueSerde: streams.getSerdes().Avro // Automatically uses Schema Registry
  });
  
  // Filter for abnormal vital signs
  const abnormalVitals = vitalSigns.filter((vital) => {
    // Check if vital sign is outside normal range
    switch (vital.type) {
      case 'heart_rate':
        return vital.value < 60 || vital.value > 100;
      case 'blood_pressure_systolic':
        return vital.value < 90 || vital.value > 140;
      case 'blood_pressure_diastolic':
        return vital.value < 60 || vital.value > 90;
      case 'temperature':
        return vital.value < 36.5 || vital.value > 38.0;
      case 'respiratory_rate':
        return vital.value < 12 || vital.value > 20;
      case 'oxygen_saturation':
        return vital.value < 95;
      default:
        return false;
    }
  });
  
  // Transform to alerts with severity
  const alerts = abnormalVitals.map<string, VitalSignAlert>((vital) => {
    // Determine alert severity
    let severity: 'CRITICAL' | 'WARNING' | 'INFO' = 'INFO';
    let message = '';
    
    switch (vital.type) {
      case 'heart_rate':
        if (vital.value < 50 || vital.value > 120) {
          severity = 'CRITICAL';
          message = `Critical heart rate: ${vital.value} ${vital.unit}`;
        } else {
          severity = 'WARNING';
          message = `Abnormal heart rate: ${vital.value} ${vital.unit}`;
        }
        break;
      // Similar logic for other vital types
      default:
        severity = 'INFO';
        message = `Abnormal ${vital.type}: ${vital.value} ${vital.unit}`;
    }
    
    return {
      patientId: vital.patientId,
      type: vital.type,
      value: vital.value,
      unit: vital.unit,
      severity,
      message,
      timestamp: Date.now()
    };
  });
  
  // Branch alerts by severity (using Confluent Cloud features)
  const [criticalAlerts, warningAlerts, infoAlerts] = alerts.branch(
    (alert) => alert.severity === 'CRITICAL',
    (alert) => alert.severity === 'WARNING',
    (alert) => alert.severity === 'INFO'
  );
  
  // Publish to appropriate topics
  criticalAlerts.to('clinical.alerts.critical', {
    keySerde: streams.getSerdes().String,
    valueSerde: streams.getSerdes().Avro
  });
  
  warningAlerts.to('clinical.alerts.warning', {
    keySerde: streams.getSerdes().String,
    valueSerde: streams.getSerdes().Avro
  });
  
  infoAlerts.to('clinical.alerts.info', {
    keySerde: streams.getSerdes().String,
    valueSerde: streams.getSerdes().Avro
  });
  
  return builder.build();
};

// Build the topology
const topology = buildTopology();

// Start the streams application
async function startStreams() {
  try {
    // Set the topology
    streams.setTopology(topology);
    
    // Clean up local state (for development)
    // In production, you might want to skip this step
    await streams.cleanUp();
    
    // Start the streams
    await streams.start();
    console.log('Vital signs processor started successfully');
    
    // Add shutdown hook
    process.on('SIGTERM', async () => {
      console.log('Shutting down streams application...');
      await streams.stop();
    });
  } catch (error) {
    console.error('Failed to start streams application:', error);
  }
}

// Execute streams application
startStreams();
```

### ksqlDB API

ksqlDB provides a SQL-like interface for stream processing:

```sql
-- Confluent Cloud ksqlDB - Create a stream for vital signs with schema registry integration
CREATE STREAM vital_signs (
  patient_id VARCHAR KEY,
  vital_type VARCHAR,
  value DOUBLE,
  unit VARCHAR,
  timestamp BIGINT
) WITH (
  KAFKA_TOPIC = 'clinical.patient.vitals',
  VALUE_FORMAT = 'AVRO',
  PARTITIONS = 8,
  REPLICAS = 3,
  TIMESTAMP = 'timestamp'
);

-- Create a materialized view for patient vital signs history
-- Using Confluent Cloud ksqlDB's windowing features
CREATE TABLE patient_vitals_history AS
SELECT
  patient_id,
  vital_type,
  LATEST_BY_OFFSET(value) AS latest_value,
  LATEST_BY_OFFSET(unit) AS unit,
  LATEST_BY_OFFSET(timestamp) AS latest_timestamp,
  COUNT(*) AS measurement_count,
  AVG(value) AS avg_value,
  MIN(value) AS min_value,
  MAX(value) AS max_value,
  COLLECT_LIST(STRUCT(value := value, timestamp := timestamp)) AS history
FROM vital_signs
WINDOW TUMBLING (SIZE 24 HOURS)
GROUP BY patient_id, vital_type
EMIT CHANGES;

-- Create a stream for abnormal vital signs with severity classification
-- Using Confluent Cloud ksqlDB's advanced processing features
CREATE STREAM abnormal_vitals WITH (
  KAFKA_TOPIC = 'clinical.alerts',
  VALUE_FORMAT = 'AVRO',
  PARTITIONS = 8,
  REPLICAS = 3
) AS
SELECT 
  patient_id,
  vital_type,
  value,
  unit,
  timestamp,
  CASE
    WHEN vital_type = 'heart_rate' AND (value < 50 OR value > 120) THEN 'CRITICAL'
    WHEN vital_type = 'heart_rate' AND (value < 60 OR value > 100) THEN 'WARNING'
    WHEN vital_type = 'blood_pressure_systolic' AND (value < 80 OR value > 160) THEN 'CRITICAL'
    WHEN vital_type = 'blood_pressure_systolic' AND (value < 90 OR value > 140) THEN 'WARNING'
    WHEN vital_type = 'blood_pressure_diastolic' AND (value < 50 OR value > 100) THEN 'CRITICAL'
    WHEN vital_type = 'blood_pressure_diastolic' AND (value < 60 OR value > 90) THEN 'WARNING'
    WHEN vital_type = 'temperature' AND (value < 35.0 OR value > 39.0) THEN 'CRITICAL'
    WHEN vital_type = 'temperature' AND (value < 36.5 OR value > 38.0) THEN 'WARNING'
    WHEN vital_type = 'respiratory_rate' AND (value < 8 OR value > 30) THEN 'CRITICAL'
    WHEN vital_type = 'respiratory_rate' AND (value < 12 OR value > 20) THEN 'WARNING'
    WHEN vital_type = 'oxygen_saturation' AND value < 90 THEN 'CRITICAL'
    WHEN vital_type = 'oxygen_saturation' AND value < 95 THEN 'WARNING'
    ELSE 'INFO'
  END AS severity,
  CASE
    WHEN vital_type = 'heart_rate' AND (value < 50 OR value > 120) THEN 'Critical heart rate detected'
    WHEN vital_type = 'heart_rate' AND (value < 60 OR value > 100) THEN 'Abnormal heart rate detected'
    -- Similar messages for other vital types
    ELSE CONCAT('Abnormal ', vital_type, ' detected')
  END AS alert_message,
  -- Add context from patient history using ksqlDB's stream-table join
  -- This is a Confluent Cloud ksqlDB feature for enriching data
  IFNULL(FETCH_FIELD_FROM_LATEST(
    history, 
    LAMBDA(x => x->timestamp < timestamp), 
    LAMBDA(x => x->value)
  ), NULL) AS previous_value
FROM vital_signs
WHERE
  vital_type = 'heart_rate' AND (value < 60 OR value > 100) OR
  vital_type = 'blood_pressure_systolic' AND (value < 90 OR value > 140) OR
  vital_type = 'blood_pressure_diastolic' AND (value < 60 OR value > 90) OR
  vital_type = 'temperature' AND (value < 36.5 OR value > 38.0) OR
  vital_type = 'respiratory_rate' AND (value < 12 OR value > 20) OR
  vital_type = 'oxygen_saturation' AND value < 95
EMIT CHANGES;

-- Create a push query to monitor critical alerts in real-time
-- This would be used in a Confluent Cloud ksqlDB application
SELECT
  patient_id,
  vital_type,
  value,
  unit,
  severity,
  alert_message,
  TIMESTAMPTOSTRING(timestamp, 'yyyy-MM-dd HH:mm:ss') AS event_time
FROM abnormal_vitals
WHERE severity = 'CRITICAL'
EMIT CHANGES;
```

## REST Proxy API

The REST Proxy API provides HTTP access to Kafka:

### Producing Events via REST

```typescript
// Using Confluent Cloud REST Proxy with TypeScript
// This example uses the Axios HTTP client
import axios from 'axios';

// Confluent Cloud REST Proxy configuration
const restProxyConfig = {
  // Confluent Cloud REST Proxy endpoint
  baseUrl: 'https://rest-proxy.confluent.cloud',
  
  // Authentication for Confluent Cloud
  auth: {
    username: '${CONFLUENT_CLOUD_KEY}',
    password: '${CONFLUENT_CLOUD_SECRET}'
  },
  
  // Default headers
  headers: {
    'Content-Type': 'application/vnd.kafka.avro.v2+json', // Using AVRO with Schema Registry
    'Accept': 'application/vnd.kafka.v2+json'
  }
};

// Define the patient event interface
interface PatientEvent {
  patientId: string;
  eventType: string;
  timestamp: number;
  department: string;
}

// Function to produce events via REST Proxy
async function produceEvent(event: PatientEvent) {
  try {
    // Prepare the request payload
    const payload = {
      // Schema Registry configuration for Confluent Cloud
      value_schema_id: '${SCHEMA_ID}', // Schema ID from Confluent Schema Registry
      records: [
        {
          key: event.patientId,
          value: event
        }
      ]
    };
    
    // Send the request to Confluent Cloud REST Proxy
    const response = await axios({
      method: 'post',
      url: `${restProxyConfig.baseUrl}/topics/clinical.patient.admitted`,
      auth: restProxyConfig.auth,
      headers: restProxyConfig.headers,
      data: payload
    });
    
    console.log('Event produced successfully:', response.data);
    return response.data;
  } catch (error) {
    console.error('Failed to produce event:', error);
    throw error;
  }
}

// Example usage
const event: PatientEvent = {
  patientId: 'P123456',
  eventType: 'ADMISSION',
  timestamp: Date.now(),
  department: 'Emergency'
};

produceEvent(event);
```

### Consuming Events via REST

```typescript
// Using Confluent Cloud REST Proxy with TypeScript for consuming events
// This example uses the Axios HTTP client
import axios from 'axios';

// Confluent Cloud REST Proxy configuration
const restProxyConfig = {
  // Confluent Cloud REST Proxy endpoint
  baseUrl: 'https://rest-proxy.confluent.cloud',
  
  // Authentication for Confluent Cloud
  auth: {
    username: '${CONFLUENT_CLOUD_KEY}',
    password: '${CONFLUENT_CLOUD_SECRET}'
  }
};

// Define the patient event interface
interface PatientEvent {
  patientId: string;
  eventType: string;
  timestamp: number;
  department: string;
}

// Function to create a consumer instance
async function createConsumer() {
  try {
    // Create consumer instance
    const createResponse = await axios({
      method: 'post',
      url: `${restProxyConfig.baseUrl}/consumers/patient-admission-group`,
      auth: restProxyConfig.auth,
      headers: {
        'Content-Type': 'application/vnd.kafka.v2+json'
      },
      data: {
        name: 'patient-admission-consumer',
        format: 'avro', // Using AVRO with Schema Registry
        'auto.offset.reset': 'earliest',
        // Confluent Cloud specific configurations
        'schema.registry.url': 'https://schema-registry.confluent.cloud',
        'basic.auth.credentials.source': 'USER_INFO',
        'basic.auth.user.info': '${SCHEMA_REGISTRY_KEY}:${SCHEMA_REGISTRY_SECRET}'
      }
    });
    
    console.log('Consumer created:', createResponse.data);
    
    // Get the base URI for the consumer
    const baseUri = createResponse.data.base_uri;
    
    // Subscribe to topics
    await axios({
      method: 'post',
      url: `${baseUri}/subscription`,
      auth: restProxyConfig.auth,
      headers: {
        'Content-Type': 'application/vnd.kafka.v2+json'
      },
      data: {
        topics: ['clinical.patient.admitted']
      }
    });
    
    console.log('Subscribed to topics');
    
    return baseUri;
  } catch (error) {
    console.error('Failed to create consumer:', error);
    throw error;
  }
}

// Function to consume events
async function consumeEvents(baseUri: string) {
  try {
    // Poll for records
    const response = await axios({
      method: 'get',
      url: `${baseUri}/records`,
      auth: restProxyConfig.auth,
      headers: {
        'Accept': 'application/vnd.kafka.avro.v2+json'
      }
    });
    
    // Process the events
    const events = response.data as Array<{
      key: string;
      value: PatientEvent;
      partition: number;
      offset: number;
      topic: string;
    }>;
    
    events.forEach(event => {
      console.log(`Received event: patient=${event.value.patientId}, ` +
                 `timestamp=${event.value.timestamp}, ` +
                 `department=${event.value.department}`);
      
      // Process the event
      processPatientAdmission(event.value);
    });
    
    return events;
  } catch (error) {
    console.error('Failed to consume events:', error);
    throw error;
  }
}

// Function to commit offsets
async function commitOffsets(baseUri: string) {
  try {
    await axios({
      method: 'post',
      url: `${baseUri}/offsets`,
      auth: restProxyConfig.auth,
      headers: {
        'Content-Type': 'application/vnd.kafka.v2+json'
      },
      data: {
        // Empty request commits current offsets
      }
    });
    
    console.log('Offsets committed');
  } catch (error) {
    console.error('Failed to commit offsets:', error);
    throw error;
  }
}

// Function to close the consumer
async function closeConsumer(baseUri: string) {
  try {
    await axios({
      method: 'delete',
      url: baseUri,
      auth: restProxyConfig.auth
    });
    
    console.log('Consumer closed');
  } catch (error) {
    console.error('Failed to close consumer:', error);
    throw error;
  }
}

// Example usage with polling loop
async function pollForEvents() {
  let baseUri: string | null = null;
  
  try {
    // Create consumer and subscribe to topics
    baseUri = await createConsumer();
    
    // Poll for events in a loop
    const intervalId = setInterval(async () => {
      try {
        // Consume events
        const events = await consumeEvents(baseUri!);
        
        // If events were received, commit offsets
        if (events.length > 0) {
          await commitOffsets(baseUri!);
        }
      } catch (error) {
        console.error('Error in polling loop:', error);
        clearInterval(intervalId);
        
        // Clean up consumer on error
        if (baseUri) {
          await closeConsumer(baseUri);
        }
      }
    }, 1000); // Poll every second
    
    // Set up cleanup on process exit
    process.on('SIGINT', async () => {
      clearInterval(intervalId);
      if (baseUri) {
        await closeConsumer(baseUri);
      }
      process.exit(0);
    });
  } catch (error) {
    console.error('Failed to set up event polling:', error);
    
    // Clean up consumer on error
    if (baseUri) {
      await closeConsumer(baseUri);
    }
  }
}

// Start polling for events
pollForEvents();
```

## Healthcare-Specific API Patterns

### FHIR Event Publishing

Pattern for publishing FHIR resource changes as events:

```typescript
// Import required libraries
import { Kafka, Partitioners, CompressionTypes } from 'kafkajs';
import { FhirClient } from 'fhir-kit-client';

// Define FHIR resource interface
interface FhirResource {
  resourceType: string;
  resourceId: string;
  operation: 'CREATE' | 'UPDATE' | 'DELETE';
  content: string;
  timestamp: number;
  version?: string;
}

// Create Confluent Cloud Kafka configuration
const kafkaConfig = {
  clientId: 'fhir-event-publisher',
  brokers: ['kafka-broker:9092'],
  ssl: true,
  sasl: {
    mechanism: 'plain',
    username: '${CONFLUENT_CLOUD_KEY}',
    password: '${CONFLUENT_CLOUD_SECRET}'
  },
  connectionTimeout: 3000,
  retry: {
    initialRetryTime: 100,
    retries: 8
  }
};

// Create Kafka client
const kafka = new Kafka(kafkaConfig);

// Create producer with Confluent Cloud optimizations
const producer = kafka.producer({
  createPartitioner: Partitioners.DefaultPartitioner,
  allowAutoTopicCreation: false,
  transactionTimeout: 30000,
  idempotent: true, // Exactly-once semantics
  maxInFlightRequests: 5,
  compression: CompressionTypes.Lz4 // Efficient compression
});

// Connect producer on startup
await producer.connect();

// Set up graceful shutdown
process.on('SIGTERM', async () => {
  console.log('Disconnecting producer...');
  await producer.disconnect();
});

// FHIR resource change handler
async function handleResourceChange(resource: any, operation: 'CREATE' | 'UPDATE' | 'DELETE') {
  try {
    // Extract resource type and ID
    const resourceType = resource.resourceType;
    const resourceId = resource.id;
    
    // Create FHIR resource wrapper
    const fhirResource: FhirResource = {
      resourceType,
      resourceId,
      operation,
      content: JSON.stringify(resource),
      timestamp: Date.now(),
      version: resource.meta?.versionId
    };
    
    // Create topic name based on resource type and operation
    // Using Confluent Cloud's recommended topic naming convention
    const topic = `fhir.${resourceType.toLowerCase()}.${operation.toLowerCase()}`;
    
    // Send record with Confluent Cloud features
    await producer.send({
      topic,
      compression: CompressionTypes.Lz4,
      messages: [
        {
          key: resourceId,
          value: JSON.stringify(fhirResource),
          headers: {
            'resource-type': resourceType,
            'operation-type': operation,
            'timestamp': Date.now().toString(),
            // Add tracing headers for Confluent Cloud observability
            'X-Request-ID': generateRequestId(),
            'X-Correlation-ID': getCorrelationId()
          }
        }
      ]
    });
    
    console.log(`FHIR resource change published: ${resourceType}-${resourceId}`);
    
    // Use Confluent Cloud's Schema Registry for schema validation
    // This would be implemented with a schema-registry-compatible serializer
  } catch (error) {
    console.error('Failed to publish FHIR resource change', error);
    // Implement retry logic or dead-letter queue for failed events
    await sendToDeadLetterQueue(resource, operation, error);
  }
}

// Example FHIR subscription hook integration
const fhirClient = new FhirClient({
  baseUrl: 'https://fhir-server/fhir'
});

// Set up FHIR subscription for Patient resources
async function setupFhirSubscription() {
  const subscription = {
    resourceType: 'Subscription',
    status: 'active',
    reason: 'Monitor patient resource changes',
    criteria: 'Patient',
    channel: {
      type: 'rest-hook',
      endpoint: 'https://kafka-connect-webhook/fhir-events',
      payload: 'application/fhir+json',
      header: ['Authorization: Bearer ${FHIR_TOKEN}']
    }
  };
  
  await fhirClient.create({
    resourceType: 'Subscription',
    body: subscription
  });
}

// Helper functions
function generateRequestId(): string {
  return Math.random().toString(36).substring(2, 15);
}

function getCorrelationId(): string {
  // Get from current context or generate new one
  return global.correlationId || generateRequestId();
}

async function sendToDeadLetterQueue(resource: any, operation: string, error: any) {
  try {
    await producer.send({
      topic: 'fhir.dead-letter-queue',
      messages: [
        {
          key: `${resource.resourceType}-${resource.id}`,
          value: JSON.stringify({
            resource,
            operation,
            error: error.message,
            timestamp: Date.now()
          })
        }
      ]
    });
  } catch (dlqError) {
    console.error('Failed to send to dead letter queue', dlqError);
  }
}
```

### Clinical Alert Processing

Pattern for processing clinical alerts from event streams:

```java
// Create clinical alert consumer
Properties props = new Properties();
props.put(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, "kafka-broker:9092");
props.put(ConsumerConfig.GROUP_ID_CONFIG, "clinical-alert-processor");
props.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class.getName());
props.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, ClinicalAlertDeserializer.class.getName());
props.put(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, "earliest");

Consumer<String, ClinicalAlert> consumer = new KafkaConsumer<>(props);

// Subscribe to clinical alert topics
consumer.subscribe(Arrays.asList(
    "clinical.alerts.critical",
    "clinical.alerts.high",
    "clinical.alerts.medium"
));

// Process alerts
try {
    while (true) {
        ConsumerRecords<String, ClinicalAlert> records = consumer.poll(Duration.ofMillis(100));
        
        for (ConsumerRecord<String, ClinicalAlert> record : records) {
            ClinicalAlert alert = record.value();
            
            // Process based on severity
            switch (alert.getSeverity()) {
                case CRITICAL:
                    processCriticalAlert(alert);
                    break;
                case HIGH:
                    processHighAlert(alert);
                    break;
                case MEDIUM:
                    processMediumAlert(alert);
                    break;
            }
        }
        
        // Commit offsets after processing
        consumer.commitSync();
    }
} finally {
    consumer.close();
}
```

## Security Considerations

### Authentication

Example of client authentication with SASL/PLAIN:

```java
// Producer with SASL/PLAIN authentication
Properties props = new Properties();
props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, "kafka-broker:9092");
props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, PatientEventSerializer.class.getName());

// Security configurations
props.put(CommonClientConfigs.SECURITY_PROTOCOL_CONFIG, "SASL_SSL");
props.put(SaslConfigs.SASL_MECHANISM, "PLAIN");
props.put(SaslConfigs.SASL_JAAS_CONFIG, 
    "org.apache.kafka.common.security.plain.PlainLoginModule required " +
    "username=\"clinical-service\" " +
    "password=\"${file:/secrets/kafka-credentials:password}\";";
);

// TLS configurations
props.put(SslConfigs.SSL_TRUSTSTORE_LOCATION_CONFIG, "/etc/kafka/secrets/kafka.truststore.jks");
props.put(SslConfigs.SSL_TRUSTSTORE_PASSWORD_CONFIG, "${file:/secrets/ssl-credentials:truststore-password}");

// Create the producer
Producer<String, PatientEvent> producer = new KafkaProducer<>(props);
```

### Authorization

Example of topic ACL configuration using the Admin API:

```java
// Create admin client with authentication
Properties props = new Properties();
props.put(AdminClientConfig.BOOTSTRAP_SERVERS_CONFIG, "kafka-broker:9092");

// Security configurations
props.put(CommonClientConfigs.SECURITY_PROTOCOL_CONFIG, "SASL_SSL");
props.put(SaslConfigs.SASL_MECHANISM, "PLAIN");
props.put(SaslConfigs.SASL_JAAS_CONFIG, 
    "org.apache.kafka.common.security.plain.PlainLoginModule required " +
    "username=\"admin\" " +
    "password=\"${file:/secrets/kafka-credentials:admin-password}\";";
);

AdminClient adminClient = AdminClient.create(props);

// Create ACL for clinical service to read clinical topics
AccessControlEntry ace = new AccessControlEntry(
    "User:clinical-service",                 // Principal
    "*",                                      // Host (any)
    AclOperation.READ,                       // Operation
    AclPermissionType.ALLOW                  // Permission type
);

ResourcePattern resourcePattern = new ResourcePattern(
    ResourceType.TOPIC,                      // Resource type
    "clinical.*",                            // Resource name pattern
    PatternType.PREFIXED                     // Pattern type
);

AclBinding aclBinding = new AclBinding(resourcePattern, ace);

// Create the ACL
adminClient.createAcls(Collections.singleton(aclBinding));
```

## Conclusion

The Event Broker Core APIs provide a comprehensive set of interfaces for building event-driven healthcare applications. These APIs enable the production and consumption of healthcare events, management of event streams, and integration with various healthcare systems. By leveraging these APIs, developers can create scalable, reliable, and secure healthcare applications that respond to events in real-time.

## Related Documentation

- [Event Broker Overview](../01-getting-started/overview.md)
- [Event Broker Architecture](../01-getting-started/architecture.md)
- [Event Schemas](./event-schemas.md)
- [Topic Design](./topic-design.md)
- [Connectors](./connectors.md)
