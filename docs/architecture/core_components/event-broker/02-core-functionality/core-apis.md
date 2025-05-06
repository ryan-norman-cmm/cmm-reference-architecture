# Event Broker Core APIs

## Introduction
The Event Broker provides a comprehensive set of APIs for producers and consumers to interact with the event streaming platform. These APIs enable publishing events, subscribing to topics, managing schemas, and configuring the event infrastructure. The Event Broker is built on Confluent Kafka, which provides native client libraries for multiple programming languages as well as REST interfaces for broader accessibility.

## API Endpoints

### Producer APIs

| API | Description | Purpose |
|-----|-------------|---------|
| Producer API | Kafka client interface for publishing events | Send events to specific topics with configurable delivery guarantees |
| Schema Registry API | REST interface for schema management | Register, retrieve, and validate schemas for events |
| Admin API | Configuration interface for topic management | Create, modify, and configure topics and partitioning |

### Consumer APIs

| API | Description | Purpose |
|-----|-------------|---------|
| Consumer API | Kafka client interface for subscribing to events | Receive events from topics with configurable consumer semantics |
| Consumer Groups API | Interface for managing consumer offsets and groups | Coordinate distributed consumers and track consumption progress |
| Streams API | Stream processing interface | Process, transform, and analyze event streams in real-time |

### Management APIs

| API | Description | Purpose |
|-----|-------------|---------|
| Cluster Management API | REST interface for broker administration | Monitor and manage the Kafka cluster |
| Metrics API | Telemetry collection interface | Access performance and health metrics |
| ACL API | Security configuration interface | Manage access control policies for topics and operations |
| Connect API | Data integration framework | Configure and manage connectors to external systems |

## Authentication & Authorization

The Event Broker supports multiple authentication and authorization mechanisms:

### Authentication Methods
- **SASL/PLAIN**: Username/password authentication (secured with TLS)
- **SASL/SCRAM**: Challenge-response authentication for improved security
- **mTLS**: Mutual TLS authentication using client certificates
- **OAuth 2.0**: Token-based authentication for integration with identity providers
- **LDAP**: Directory-based authentication (via integration with SASL)

### Authorization Mechanisms
- **ACL-based Authorization**: Fine-grained access control lists for topics and operations
- **Role-Based Access Control**: Predefined roles with specific permissions (using Confluent RBAC)
- **Resource-Based Policies**: Attribute-based policies for advanced access control scenarios
- **Audit Logging**: Comprehensive tracking of authentication and authorization events

### Security Configuration Example

```typescript
import { Kafka } from 'kafkajs';

// Producer with SASL/PLAIN authentication
const kafka = new Kafka({
  clientId: 'my-app',
  brokers: ['kafka-broker:9092'],
  ssl: true,
  sasl: {
    mechanism: 'plain',
    username: 'app-producer',
    password: 'app-producer-secret'
  },
});

const producer = kafka.producer();
```

## Example Requests & Responses

### Publishing an Event

```typescript
import { Kafka } from 'kafkajs';

const kafka = new Kafka({
  clientId: 'prescription-service',
  brokers: ['event-broker.cmm.internal:9092'],
  ssl: true,
  sasl: {
    mechanism: 'plain',
    username: process.env.KAFKA_USERNAME,
    password: process.env.KAFKA_PASSWORD
  },
});

const producer = kafka.producer({
  // Configuration options
  allowAutoTopicCreation: false,
  transactionTimeout: 30000,
  idempotent: true,
});

// Connect to the broker
await producer.connect();

// Function to publish a medication order event
async function publishMedicationOrder(medicationOrder) {
  try {
    // Create a message key based on the order ID for partitioning
    const key = `medication-order-${medicationOrder.id}`;
    
    // Publish the event
    const result = await producer.send({
      topic: 'medication-orders',
      messages: [
        {
          key,
          value: JSON.stringify(medicationOrder),
          headers: {
            'event-type': 'medication-order-created',
            'event-source': 'prescription-service',
            'correlation-id': medicationOrder.correlationId,
            'timestamp': Date.now().toString(),
          },
        },
      ],
    });
    
    console.log(`Event published successfully: ${JSON.stringify(result)}`);
    return result;
  } catch (error) {
    console.error(`Failed to publish event: ${error.message}`);
    throw error;
  }
}

// Clean up resources when done
await producer.disconnect();
```

### Consuming Events

```typescript
import { Kafka } from 'kafkajs';

const kafka = new Kafka({
  clientId: 'pharmacy-service',
  brokers: ['event-broker.cmm.internal:9092'],
  ssl: true,
  sasl: {
    mechanism: 'plain',
    username: process.env.KAFKA_USERNAME,
    password: process.env.KAFKA_PASSWORD
  },
});

const consumer = kafka.consumer({
  groupId: 'pharmacy-medication-processor',
  // Consumer configuration
  sessionTimeout: 30000,
  heartbeatInterval: 3000,
  maxBytes: 5242880, // 5MB
});

// Connect to the broker
await consumer.connect();

// Subscribe to the topic
await consumer.subscribe({
  topic: 'medication-orders',
  fromBeginning: false, // Start consuming from the latest offset
});

// Process incoming events
await consumer.run({
  partitionsConsumedConcurrently: 3,
  eachMessage: async ({ topic, partition, message, heartbeat }) => {
    try {
      // Extract message headers
      const eventType = message.headers['event-type']?.toString();
      const correlationId = message.headers['correlation-id']?.toString();
      
      // Parse the message value
      const medicationOrder = JSON.parse(message.value.toString());
      
      console.log(`Processing ${eventType} with ID: ${medicationOrder.id}`);
      
      // Process the medication order
      await processMedicationOrder(medicationOrder);
      
      // Periodically send heartbeats for long-running processing
      await heartbeat();
      
      console.log(`Successfully processed order: ${medicationOrder.id}`);
    } catch (error) {
      console.error(`Error processing message: ${error.message}`);
      // Implement error handling strategy (retry, DLQ, etc.)
    }
  },
});

// Clean up resources when shutting down
await consumer.disconnect();
```

### Schema Registry API Example

```typescript
import { SchemaRegistry } from '@kafkajs/confluent-schema-registry';

// Initialize the Schema Registry client
const registry = new SchemaRegistry({
  host: 'https://schema-registry.cmm.internal',
  auth: {
    username: process.env.SCHEMA_REGISTRY_USERNAME,
    password: process.env.SCHEMA_REGISTRY_PASSWORD,
  },
});

// Register a new Avro schema for medication orders
async function registerMedicationOrderSchema() {
  const schema = {
    type: 'record',
    name: 'MedicationOrder',
    namespace: 'com.covermymeds.events',
    fields: [
      { name: 'id', type: 'string' },
      { name: 'patientId', type: 'string' },
      { name: 'medication', type: 'string' },
      { name: 'dosage', type: 'string' },
      { name: 'prescriberId', type: 'string' },
      { name: 'pharmacyId', type: ['null', 'string'] },
      { name: 'status', type: 'string' },
      { name: 'createdAt', type: 'long', logicalType: 'timestamp-millis' },
      { name: 'updatedAt', type: 'long', logicalType: 'timestamp-millis' },
    ],
  };
  
  try {
    // Register the schema under a subject name (usually topic-value)
    const { id } = await registry.register(schema, { subject: 'medication-orders-value' });
    console.log(`Schema registered with ID: ${id}`);
    return id;
  } catch (error) {
    console.error(`Failed to register schema: ${error.message}`);
    throw error;
  }
}

// Encode a message using a registered schema
async function encodeWithSchema(order, schemaId) {
  try {
    const encodedOrder = await registry.encode(schemaId, order);
    return encodedOrder;
  } catch (error) {
    console.error(`Failed to encode message: ${error.message}`);
    throw error;
  }
}

// Decode a message using the schema registry
async function decodeWithSchema(encodedMessage) {
  try {
    const decodedOrder = await registry.decode(encodedMessage);
    return decodedOrder;
  } catch (error) {
    console.error(`Failed to decode message: ${error.message}`);
    throw error;
  }
}
```

## Error Handling

The Event Broker APIs provide several mechanisms for handling errors and ensuring reliable event processing.

### Common Error Codes

| Error Code | Description | Troubleshooting |
|------------|-------------|-----------------|
| UNKNOWN_TOPIC_OR_PARTITION | Topic or partition does not exist | Verify topic name and creation status |
| LEADER_NOT_AVAILABLE | Broker leader for partition is unavailable | Check broker health and wait for leader election |
| NOT_LEADER_FOR_PARTITION | Broker is not the leader for this partition | Retry with automatic broker discovery |
| REQUEST_TIMED_OUT | Request exceeded the configured timeout | Check network connectivity and broker load |
| NOT_ENOUGH_REPLICAS | Unable to satisfy the requested acknowledgment level | Check broker health and replication factor |
| NOT_ENOUGH_REPLICAS_AFTER_APPEND | Message was written but not fully replicated | Verify replication health |
| TOPIC_AUTHORIZATION_FAILED | Client is not authorized for this topic | Check ACL configuration and client credentials |
| GROUP_AUTHORIZATION_FAILED | Client is not authorized for this consumer group | Verify consumer group permissions |
| CLUSTER_AUTHORIZATION_FAILED | Client is not authorized for cluster operations | Check cluster-level permissions |
| INVALID_REQUIRED_ACKS | Invalid acknowledgment configuration | Use valid ack settings (0, 1, -1) |

### Producer Error Handling

```typescript
// Producer error handling with retries
const producer = kafka.producer({
  // Error handling and retry configuration
  retry: {
    initialRetryTime: 100,
    retries: 8, // Exponential backoff with 8 retries
    maxRetryTime: 30000, // Maximum backoff of 30 seconds
    factor: 2, // Exponential factor
  },
});

// Handle producer-level errors
producer.on(producer.events.CONNECT_ERROR, (error) => {
  console.error('Connection error:', error);
  // Implement reconnection logic or alert operations
});

// Transaction error handling
const transaction = await producer.transaction();
try {
  // Add messages to transaction
  await transaction.send({
    topic: 'medication-orders',
    messages: [/* messages */],
  });
  
  // Commit the transaction
  await transaction.commit();
} catch (error) {
  // Abort transaction on error
  await transaction.abort();
  console.error('Transaction failed:', error);
}
```

### Consumer Error Handling

```typescript
// Consumer error handling
await consumer.run({
  eachMessage: async ({ topic, partition, message }) => {
    try {
      // Process message
    } catch (error) {
      // Error handling options:
      
      // 1. Log and continue (for non-critical errors)
      console.error('Message processing error:', error);
      
      // 2. Send to Dead Letter Queue (for persistent errors)
      await sendToDLQ(topic, message);
      
      // 3. Implement retry logic with backoff
      await retryWithBackoff(() => processMessage(message));
      
      // 4. Pause consumption for recovery
      await consumer.pause([{ topic, partitions: [partition] }]);
      setTimeout(() => consumer.resume([{ topic, partitions: [partition] }]), 5000);
    }
  },
});

// Handle consumer-level errors
consumer.on(consumer.events.CRASH, async ({ error, groupId }) => {
  console.error(`Consumer group ${groupId} crashed:`, error);
  // Implement recovery logic or alert operations
});

// Dead Letter Queue implementation
async function sendToDLQ(sourceTopic, failedMessage) {
  const dlqProducer = kafka.producer();
  await dlqProducer.connect();
  
  await dlqProducer.send({
    topic: `${sourceTopic}.dlq`,
    messages: [{
      // Original message content
      value: failedMessage.value,
      // Add error context in headers
      headers: {
        ...failedMessage.headers,
        'error-reason': Buffer.from('processing-failed'),
        'source-topic': Buffer.from(sourceTopic),
        'failure-timestamp': Buffer.from(Date.now().toString()),
      },
    }],
  });
  
  await dlqProducer.disconnect();
}
```

## Related Resources
- [Event Broker Overview](../01-getting-started/overview.md)
- [Event Broker Key Concepts](../01-getting-started/key-concepts.md)
- [Event Schema Design](../03-advanced-patterns/advanced-use-cases.md)
- [Topic Management](./topic-management.md)
- [Confluent Kafka Documentation](https://docs.confluent.io/platform/current/clients/index.html)
- [KafkaJS Documentation](https://kafka.js.org/)