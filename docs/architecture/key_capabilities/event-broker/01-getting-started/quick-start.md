# Event Broker Quick Start

This guide provides a comprehensive, step-by-step approach to get you up and running with the Event Broker core component for healthcare event messaging and real-time data integration.

## Prerequisites
- Access to the CMM platform environment (development, staging, or production)
- Provisioned credentials for the Event Broker (Kafka username/password or certificates)
- Network access to the Event Broker endpoints
- Basic familiarity with Apache Kafka concepts (topics, producers, consumers)
- Node.js 14+ or Java 11+ for running the example code

## Setup Options

### Option A: Local Development Environment

Follow these steps to set up a local development environment for working with the Event Broker:

#### Step 1: Install Docker

Download and install Docker Desktop from [docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop/).

Verify your installation:
```bash
docker --version
docker-compose --version
```

#### Step 2: Set Up Confluent Kafka Platform

1. Create a new directory for your Kafka project:
```bash
mkdir kafka-healthcare-dev && cd kafka-healthcare-dev
```

2. Create a `docker-compose.yml` file with the following content:
```yaml
---
version: '2'
services:
  zookeeper:
    image: confluentinc/cp-zookeeper:7.3.0
    hostname: zookeeper
    container_name: zookeeper
    ports:
      - "2181:2181"
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
      ZOOKEEPER_TICK_TIME: 2000

  broker:
    image: confluentinc/cp-server:7.3.0
    hostname: broker
    container_name: broker
    depends_on:
      - zookeeper
    ports:
      - "9092:9092"
      - "9101:9101"
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: 'zookeeper:2181'
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://broker:29092,PLAINTEXT_HOST://localhost:9092
      KAFKA_METRIC_REPORTERS: io.confluent.metrics.reporter.ConfluentMetricsReporter
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
      KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS: 0
      KAFKA_CONFLUENT_LICENSE_TOPIC_REPLICATION_FACTOR: 1
      KAFKA_CONFLUENT_BALANCER_TOPIC_REPLICATION_FACTOR: 1
      KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: 1
      KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: 1
      KAFKA_JMX_PORT: 9101
      KAFKA_JMX_HOSTNAME: localhost
      KAFKA_CONFLUENT_SCHEMA_REGISTRY_URL: http://schema-registry:8081
      CONFLUENT_METRICS_REPORTER_BOOTSTRAP_SERVERS: broker:29092
      CONFLUENT_METRICS_REPORTER_TOPIC_REPLICAS: 1
      CONFLUENT_METRICS_ENABLE: 'true'
      CONFLUENT_SUPPORT_CUSTOMER_ID: 'anonymous'

  schema-registry:
    image: confluentinc/cp-schema-registry:7.3.0
    hostname: schema-registry
    container_name: schema-registry
    depends_on:
      - broker
    ports:
      - "8081:8081"
    environment:
      SCHEMA_REGISTRY_HOST_NAME: schema-registry
      SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS: 'broker:29092'
      SCHEMA_REGISTRY_LISTENERS: http://0.0.0.0:8081

  control-center:
    image: confluentinc/cp-enterprise-control-center:7.3.0
    hostname: control-center
    container_name: control-center
    depends_on:
      - broker
      - schema-registry
    ports:
      - "9021:9021"
    environment:
      CONTROL_CENTER_BOOTSTRAP_SERVERS: 'broker:29092'
      CONTROL_CENTER_SCHEMA_REGISTRY_URL: "http://schema-registry:8081"
      CONTROL_CENTER_REPLICATION_FACTOR: 1
      CONTROL_CENTER_INTERNAL_TOPICS_PARTITIONS: 1
      CONTROL_CENTER_MONITORING_INTERCEPTOR_TOPIC_PARTITIONS: 1
      CONFLUENT_METRICS_TOPIC_REPLICATION: 1
      PORT: 9021
```

3. Start the platform:
```bash
docker-compose up -d
```

4. Wait for the containers to start (1-2 minutes). Verify all containers are running:
```bash
docker-compose ps
```

5. Access the Confluent Control Center at [http://localhost:9021](http://localhost:9021) in your browser.

### Option B: Using an Existing CMM Platform Environment

If you're connecting to a pre-deployed Event Broker in your organization's environment:

1. Obtain the broker connection details from your platform team:
   - Bootstrap server addresses (e.g., `kafka-broker.cmm-dev.example.com:9092`)
   - Authentication credentials (username/password or certificates)
   - Required security settings (TLS, SASL mechanisms)

2. Configure your client with these settings (see code examples below).

## Step 3: Create Event Topics

Topics organize your event streams by domain or function. For healthcare applications, follow these naming and configuration best practices:

### Option A: Using Control Center (Local or Remote)

1. Access the Control Center UI at [http://localhost:9021](http://localhost:9021) or your deployed instance URL.
2. Navigate to the "Topics" section in your cluster.
3. Click "Add a topic".
4. Configure a healthcare-related topic with these recommended settings:
   - Name: Use the format `{domain}.{entity}.{event}` (e.g., `healthcare.prescription.created`)
   - Partitions: Start with 12 for development (scale based on throughput needs)
   - Replication Factor: 3 for production (1 for local development)
   - Retention: 7 days (configure based on your data retention requirements)
   - Cleanup Policy: Delete (or compact for reference data)

### Option B: Using Kafka CLI Tools

For local development with Docker Compose:

```bash
# Create a topic for prescription events
docker exec broker kafka-topics --create --topic healthcare.prescription.created \
  --bootstrap-server broker:29092 \
  --replication-factor 1 \
  --partitions 3

# Create a topic for patient updates
docker exec broker kafka-topics --create --topic healthcare.patient.updated \
  --bootstrap-server broker:29092 \
  --replication-factor 1 \
  --partitions 3

# List all topics
docker exec broker kafka-topics --list --bootstrap-server broker:29092
```

## Step 4: Set Up and Use Client Libraries

### TypeScript/Node.js with KafkaJS

First, create a new Node.js project and install dependencies:

```bash
mkdir healthcare-events-demo && cd healthcare-events-demo
npm init -y
npm install kafkajs uuid dotenv typescript ts-node @types/node
```

Create a `.env` file for configuration:

```
# Local development
KAFKA_BROKERS=localhost:9092
KAFKA_CLIENT_ID=healthcare-events-client

# For production environments, uncomment and configure:
# KAFKA_BROKERS=broker1:9092,broker2:9092,broker3:9092
# KAFKA_USERNAME=your-username
# KAFKA_PASSWORD=your-password
# KAFKA_USE_SSL=true
```

Create a `kafka-client.ts` for reusable client configuration:

```typescript
// kafka-client.ts
import { Kafka, KafkaConfig, logLevel } from 'kafkajs';
import * as dotenv from 'dotenv';

dotenv.config();

const brokers = (process.env.KAFKA_BROKERS || 'localhost:9092').split(',');
const clientId = process.env.KAFKA_CLIENT_ID || 'healthcare-events-client';

// Configure security if needed
const kafkaConfig: KafkaConfig = {
  clientId,
  brokers,
  logLevel: logLevel.INFO,
};

// Add SASL authentication if credentials are provided
if (process.env.KAFKA_USERNAME && process.env.KAFKA_PASSWORD) {
  kafkaConfig.ssl = process.env.KAFKA_USE_SSL === 'true';
  kafkaConfig.sasl = {
    mechanism: 'plain',
    username: process.env.KAFKA_USERNAME,
    password: process.env.KAFKA_PASSWORD,
  };
}

export const kafka = new Kafka(kafkaConfig);
export const producer = kafka.producer();
export const consumer = kafka.consumer({ 
  groupId: process.env.KAFKA_CONSUMER_GROUP || 'healthcare-consumer-group' 
});
```

### Example 1: Producing Healthcare Events

Create a file called `produce-prescription-event.ts`:

```typescript
// produce-prescription-event.ts
import { v4 as uuidv4 } from 'uuid';
import { producer } from './kafka-client';

// Healthcare event schema (follows FHIR-aligned structure)
interface PrescriptionEvent {
  eventId: string;
  eventType: string;
  timestamp: string;
  data: {
    prescriptionId: string;
    medicationReference: {
      system: string;
      code: string;
      display: string;
    };
    patientId: string;
    practitionerId: string;
    dosageInstruction: string;
    dateWritten: string;
    status: string;
  };
  metadata: {
    source: string;
    version: string;
  };
}

async function producePrescriptionEvent() {
  try {
    // Connect to Kafka
    await producer.connect();
    console.log('Producer connected successfully');

    // Create a healthcare event
    const prescriptionEvent: PrescriptionEvent = {
      eventId: uuidv4(),
      eventType: 'prescription.created',
      timestamp: new Date().toISOString(),
      data: {
        prescriptionId: `rx-${uuidv4().substring(0, 8)}`,
        medicationReference: {
          system: 'http://www.nlm.nih.gov/research/umls/rxnorm',
          code: '1000006',
          display: 'Atorvastatin 20 MG Oral Tablet',
        },
        patientId: 'patient-12345',
        practitionerId: 'practitioner-54321',
        dosageInstruction: 'Take one tablet by mouth once daily',
        dateWritten: new Date().toISOString(),
        status: 'active',
      },
      metadata: {
        source: 'pharmacy-system',
        version: '1.0.0',
      },
    };

    // Send the event to Kafka
    const result = await producer.send({
      topic: 'healthcare.prescription.created',
      messages: [
        {
          // Use patientId as the key for partitioning (ensures ordering per patient)
          key: prescriptionEvent.data.patientId,
          // Convert to JSON string
          value: JSON.stringify(prescriptionEvent),
          // Add headers for metadata
          headers: {
            'event-type': Buffer.from(prescriptionEvent.eventType),
            'content-type': Buffer.from('application/json'),
            'source': Buffer.from(prescriptionEvent.metadata.source),
          },
        },
      ],
    });

    console.log('Event published successfully:', result);
    
    // Graceful disconnect
    await producer.disconnect();
    console.log('Producer disconnected');
  } catch (error) {
    console.error('Error producing prescription event:', error);
    // Ensure producer disconnects even on error
    try {
      await producer.disconnect();
    } catch (e) {
      console.error('Error disconnecting producer:', e);
    }
    process.exit(1);
  }
}

// Run the producer
producePrescriptionEvent();
```

### Example 2: Consuming Healthcare Events

Create a file called `consume-prescription-events.ts`:

```typescript
// consume-prescription-events.ts
import { consumer } from './kafka-client';

async function consumePrescriptionEvents() {
  try {
    // Connect to Kafka
    await consumer.connect();
    console.log('Consumer connected successfully');

    // Subscribe to the topic
    await consumer.subscribe({
      topic: 'healthcare.prescription.created',
      fromBeginning: false // Set to true to read from the beginning of the topic
    });

    // Set up the message handler
    await consumer.run({
      eachMessage: async ({ topic, partition, message }) => {
        try {
          // Extract key, value and headers
          const key = message.key?.toString();
          const value = message.value?.toString();
          
          if (!value) {
            console.warn('Received message with empty value, skipping');
            return;
          }

          // Parse the event data
          const event = JSON.parse(value);
          
          // Log event information
          console.log(`Received event from partition ${partition}:`);
          console.log(`  Patient ID: ${key}`);
          console.log(`  Event ID: ${event.eventId}`);
          console.log(`  Event Type: ${event.eventType}`);
          console.log(`  Timestamp: ${event.timestamp}`);
          console.log(`  Prescription ID: ${event.data.prescriptionId}`);
          console.log(`  Medication: ${event.data.medicationReference.display}`);
          console.log(`  Status: ${event.data.status}`);
          console.log(`  Offset: ${message.offset}`);
          console.log('-----------------------------------');

          // Here you would typically:
          // 1. Validate the event schema
          // 2. Process the event (update database, trigger workflows, etc.)
          // 3. Acknowledge completion (happens automatically with KafkaJS)
          
        } catch (parseError) {
          console.error('Error processing message:', parseError);
          // Consider a dead-letter queue for invalid messages
        }
      },
    });

    // The consumer keeps running until manually stopped
    console.log('Consumer is running. Press Ctrl+C to exit.');
  } catch (error) {
    console.error('Error in consumer:', error);
    
    // Ensure consumer disconnects on error
    try {
      await consumer.disconnect();
    } catch (e) {
      console.error('Error disconnecting consumer:', e);
    }
    process.exit(1);
  }
}

// Setup graceful shutdown
process.on('SIGINT', async () => {
  try {
    console.log('Disconnecting consumer...');
    await consumer.disconnect();
    console.log('Consumer disconnected');
    process.exit(0);
  } catch (e) {
    console.error('Error during graceful shutdown:', e);
    process.exit(1);
  }
});

// Run the consumer
consumePrescriptionEvents();
```

### Example 3: Working with Schema Registry and Avro

For healthcare data, maintaining strict schema control is essential. Here's how to use Schema Registry with Avro schemas:

First, install the required packages:

```bash
npm install @kafkajs/confluent-schema-registry avsc
```

Create a file called `schema-registry-example.ts`:

```typescript
// schema-registry-example.ts
import { Kafka } from 'kafkajs';
import { SchemaRegistry } from '@kafkajs/confluent-schema-registry';
import * as dotenv from 'dotenv';

dotenv.config();

// Configure Schema Registry client
const registry = new SchemaRegistry({
  host: process.env.SCHEMA_REGISTRY_URL || 'http://localhost:8081',
});

// Configure Kafka client
const kafka = new Kafka({
  clientId: 'schema-registry-example',
  brokers: (process.env.KAFKA_BROKERS || 'localhost:9092').split(','),
});

const producer = kafka.producer();
const consumer = kafka.consumer({ groupId: 'schema-registry-group' });

// Define a PrescriptionEvent Avro schema
const prescriptionEventSchema = {
  type: 'record',
  name: 'PrescriptionEvent',
  namespace: 'com.covermymeds.healthcare',
  fields: [
    { name: 'eventId', type: 'string' },
    { name: 'eventType', type: 'string' },
    { name: 'timestamp', type: 'string' },
    {
      name: 'data',
      type: {
        type: 'record',
        name: 'PrescriptionData',
        fields: [
          { name: 'prescriptionId', type: 'string' },
          {
            name: 'medicationReference',
            type: {
              type: 'record',
              name: 'MedicationReference',
              fields: [
                { name: 'system', type: 'string' },
                { name: 'code', type: 'string' },
                { name: 'display', type: 'string' },
              ],
            },
          },
          { name: 'patientId', type: 'string' },
          { name: 'practitionerId', type: 'string' },
          { name: 'dosageInstruction', type: 'string' },
          { name: 'dateWritten', type: 'string' },
          { name: 'status', type: 'string' },
        ],
      },
    },
    {
      name: 'metadata',
      type: {
        type: 'record',
        name: 'Metadata',
        fields: [
          { name: 'source', type: 'string' },
          { name: 'version', type: 'string' },
        ],
      },
    },
  ],
};

async function produceWithSchemaRegistry() {
  try {
    // Register the schema (or get existing schema ID)
    const { id } = await registry.register(prescriptionEventSchema);
    console.log(`Schema registered with ID: ${id}`);

    // Connect to Kafka
    await producer.connect();
    console.log('Producer connected');

    // Create a prescription event (same fields as schema)
    const prescriptionEvent = {
      eventId: `evt-${Date.now()}`,
      eventType: 'prescription.created',
      timestamp: new Date().toISOString(),
      data: {
        prescriptionId: `rx-${Date.now()}`,
        medicationReference: {
          system: 'http://www.nlm.nih.gov/research/umls/rxnorm',
          code: '1000006',
          display: 'Atorvastatin 20 MG Oral Tablet',
        },
        patientId: 'patient-12345',
        practitionerId: 'practitioner-54321',
        dosageInstruction: 'Take one tablet by mouth once daily',
        dateWritten: new Date().toISOString(),
        status: 'active',
      },
      metadata: {
        source: 'pharmacy-system',
        version: '1.0.0',
      },
    };

    // Encode the message with the schema
    const encodedValue = await registry.encode(id, prescriptionEvent);

    // Send to Kafka
    await producer.send({
      topic: 'healthcare.prescription.created',
      messages: [
        {
          key: prescriptionEvent.data.patientId,
          value: encodedValue,
        },
      ],
    });

    console.log('Avro-encoded message sent');
    await producer.disconnect();
  } catch (error) {
    console.error('Error producing with Schema Registry:', error);
    await producer.disconnect();
  }
}

async function consumeWithSchemaRegistry() {
  try {
    await consumer.connect();
    console.log('Consumer connected');

    await consumer.subscribe({
      topic: 'healthcare.prescription.created',
      fromBeginning: true,
    });

    await consumer.run({
      eachMessage: async ({ topic, partition, message }) => {
        try {
          // Decode the Avro message
          const decodedValue = await registry.decode(message.value);
          
          console.log(`Received Avro message on partition ${partition}:`);
          console.log(`  Patient ID: ${message.key?.toString()}`);
          console.log(`  Prescription ID: ${decodedValue.data.prescriptionId}`);
          console.log(`  Medication: ${decodedValue.data.medicationReference.display}`);
          console.log('-----------------------------------');
        } catch (decodeError) {
          console.error('Error decoding message:', decodeError);
        }
      },
    });

    console.log('Consumer is running. Press Ctrl+C to exit.');
  } catch (error) {
    console.error('Error consuming with Schema Registry:', error);
    await consumer.disconnect();
  }
}

// Run both functions (in a real app, you'd separate these)
async function run() {
  try {
    await produceWithSchemaRegistry();
    await consumeWithSchemaRegistry();
  } catch (error) {
    console.error('Error:', error);
  }
}

run();
```

## Run the Examples

To run the examples:

```bash
# Compile and run the producer
npx ts-node produce-prescription-event.ts

# Compile and run the consumer (in a separate terminal)
npx ts-node consume-prescription-events.ts

# Compile and run the Schema Registry example
npx ts-node schema-registry-example.ts
```

## Advanced Features and Best Practices

### Healthcare Event Patterns

For healthcare messaging, consider these event patterns:

1. **Patient-centric partitioning**: Always use patient ID as the message key to ensure events for the same patient are processed in order

2. **FHIR-aligned event structure**: Structure your events to align with FHIR resources

3. **Event types**: Use consistent naming for event types:
   - `{entity}.created` - New resource creation
   - `{entity}.updated` - Resource update
   - `{entity}.deleted` - Resource deletion
   - `{workflow}.completed` - Workflow completion

4. **Idempotent consumers**: Design consumers to handle duplicate events safely

### Event Schema Design

Follow these best practices:

1. **Schema evolution**: Design schemas to be forward and backward compatible
2. **Required fields**: Mark critical fields as required
3. **Documentation**: Document the purpose and constraints of each field
4. **Versioning**: Include a version field in all events

## Troubleshooting Common Issues

### Connection Problems

1. **Cannot connect to Kafka broker**:
   - Verify network connectivity: `telnet localhost 9092`
   - Check broker logs: `docker logs broker`
   - Ensure correct broker address in client config

2. **Authentication failures**:
   - Verify credentials and configuration
   - Check if SSL/TLS is required

### Producer Issues

1. **Messages not appearing in topic**:
   - Check topic exists: `kafka-topics --list`
   - Verify producer is sending to correct topic
   - Check if producer acknowledges/callbacks are firing

### Consumer Issues

1. **Consumer not receiving messages**:
   - Verify consumer group: Check Control Center for consumer groups
   - Check if consumer is subscribed to the right topic
   - Verify offset management (correct fromBeginning setting)
   - Examine consumer lag in Control Center

### Schema Registry Issues

1. **Schema compatibility errors**:
   - Check compatibility settings
   - Review schema evolution rules
   - Use Schema Registry UI to inspect schemas

## Next Steps

Now that you have a foundation with the Event Broker, consider these next steps:

- [Explore Schema Registry & Advanced Kafka Features](../03-advanced-patterns/schema-registry.md)
- [Integration Guide: FHIR Interoperability Platform](../../fhir-interoperability-platform/01-getting-started/quick-start.md)
- [Integration Guide: Federated Graph API](../../federated-graph-api/01-getting-started/quick-start.md)
- [Integration Guide: API Marketplace](../../api-marketplace/01-getting-started/quick-start.md)
- [Best Practices: Event Schema Design](../03-advanced-patterns/event-schema-design.md)
- [Error Handling & Troubleshooting](../03-advanced-patterns/error-handling.md)

## Related Resources
- [Confluent Kafka Documentation](https://docs.confluent.io/platform/current/clients/index.html)
- [Event Broker Overview](./overview.md)
- [Event Broker Architecture](./architecture.md)
- [Event Broker Key Concepts](./key-concepts.md)
- [KafkaJS Documentation](https://kafka.js.org/)
