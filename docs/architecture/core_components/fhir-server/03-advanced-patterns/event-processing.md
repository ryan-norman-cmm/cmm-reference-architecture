# Event Processing with FHIR

## Introduction

Healthcare systems generate a continuous stream of events as patients are admitted, treatments are administered, and clinical decisions are made. Event-driven architecture enables real-time processing of these healthcare events, allowing systems to react immediately to changes in patient status, clinical workflows, and administrative processes. This guide explains how to process FHIR resources in event streams, integrate with Kafka, and implement robust error handling mechanisms.

### Quick Start

1. Set up a Kafka cluster with appropriate topics for FHIR resource events
2. Configure FHIR resource change subscriptions in Aidbox
3. Implement event producers that publish FHIR resources to Kafka topics
4. Create event consumers that process FHIR resources from Kafka topics
5. Implement error handling and retry mechanisms for failed event processing

### Related Components

- [FHIR Server Setup Guide](fhir-server-setup-guide.md): Configure your Aidbox FHIR server
- [Saving FHIR Resources](saving-fhir-resources.md): Learn how to create and update resources
- [FHIR Subscription Implementation](fhir-subscriptions.md) (Coming Soon): Configure event notifications
- [Event Architecture Decisions](fhir-event-decisions.md) (Coming Soon): Understand event design choices

## Event-Driven Architecture with FHIR

Event-driven architecture with FHIR involves capturing changes to FHIR resources and publishing them as events to a message broker like Kafka. These events can then be consumed by various services that need to react to changes in healthcare data.

### Key Components

| Component | Description | Responsibility |
|-----------|-------------|----------------|
| FHIR Server | Source of healthcare data | Manages FHIR resources and generates change events |
| Event Producer | Publishes FHIR events | Captures resource changes and formats them as events |
| Message Broker (Kafka) | Event distribution | Routes events to appropriate consumers |
| Event Consumer | Processes FHIR events | Reacts to events with business logic |
| Dead Letter Queue | Error handling | Stores events that failed processing for retry |

## Kafka Integration Patterns

### Setting Up Kafka for FHIR Events

```yaml
# Example docker-compose.yml snippet for Kafka
services:
  zookeeper:
    image: confluentinc/cp-zookeeper:7.0.1
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
      ZOOKEEPER_TICK_TIME: 2000

  kafka:
    image: confluentinc/cp-kafka:7.0.1
    depends_on:
      - zookeeper
    ports:
      - "9092:9092"
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:29092,PLAINTEXT_HOST://localhost:9092
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT
      KAFKA_INTER_BROKER_LISTENER_NAME: PLAINTEXT
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
```

### Topic Design for FHIR Resources

When designing Kafka topics for FHIR events, consider the following patterns:

1. **Resource-Based Topics**: Create topics based on resource types (e.g., `fhir.Patient`, `fhir.Observation`)
2. **Action-Based Topics**: Create topics based on actions (e.g., `fhir.created`, `fhir.updated`, `fhir.deleted`)
3. **Hybrid Approach**: Combine resource types and actions (e.g., `fhir.Patient.created`, `fhir.Observation.updated`)

```typescript
// Example topic naming constants
const FHIR_TOPICS = {
  PATIENT_CREATED: 'fhir.Patient.created',
  PATIENT_UPDATED: 'fhir.Patient.updated',
  OBSERVATION_CREATED: 'fhir.Observation.created',
  MEDICATION_REQUEST_CREATED: 'fhir.MedicationRequest.created'
};
```

## Producing FHIR Events

### Capturing FHIR Resource Changes

There are several approaches to capture changes to FHIR resources:

1. **Webhook Subscriptions**: Configure Aidbox to send webhooks on resource changes
2. **Database Change Data Capture (CDC)**: Use tools like Debezium to capture database changes
3. **Application Logic**: Explicitly publish events in your application code

### Example: Publishing FHIR Events to Kafka

```typescript
import { Kafka } from 'kafkajs';
import { AidboxClient } from '@aidbox/sdk-r4';
import { Patient } from '@aidbox/sdk-r4/types';

// Initialize Kafka client
const kafka = new Kafka({
  clientId: 'fhir-event-producer',
  brokers: ['localhost:9092']
});

const producer = kafka.producer();

// Initialize Aidbox client
const aidboxClient = new AidboxClient({
  baseUrl: 'http://localhost:8888',
  auth: {
    type: 'basic',
    username: 'root',
    password: 'secret'
  }
});

// Function to publish a Patient resource change event
async function publishPatientEvent(patient: Patient, action: 'created' | 'updated' | 'deleted'): Promise<void> {
  await producer.connect();
  
  try {
    // Create the event payload
    const event = {
      resourceType: 'Patient',
      action,
      timestamp: new Date().toISOString(),
      resource: patient
    };
    
    // Publish to the appropriate topic
    await producer.send({
      topic: `fhir.Patient.${action}`,
      messages: [
        { 
          key: patient.id, 
          value: JSON.stringify(event),
          headers: {
            'content-type': 'application/fhir+json'
          }
        }
      ]
    });
    
    console.log(`Published ${action} event for Patient ${patient.id}`);
  } catch (error) {
    console.error(`Error publishing Patient event: ${error}`);
    throw error;
  } finally {
    await producer.disconnect();
  }
}

// Example usage in an API endpoint
async function createPatientWithEvent(patientData: Omit<Patient, 'id'>): Promise<Patient> {
  // Create the patient in FHIR server
  const patient = await aidboxClient.create<Patient>({
    resourceType: 'Patient',
    ...patientData
  });
  
  // Publish the event
  await publishPatientEvent(patient, 'created');
  
  return patient;
}
```

## Consuming FHIR Events

### Setting Up a Kafka Consumer

```typescript
import { Kafka } from 'kafkajs';

// Initialize Kafka client
const kafka = new Kafka({
  clientId: 'fhir-event-consumer',
  brokers: ['localhost:9092']
});

const consumer = kafka.consumer({ groupId: 'patient-processing-group' });

// Function to start consuming Patient events
async function startPatientEventConsumer(): Promise<void> {
  await consumer.connect();
  await consumer.subscribe({ topics: ['fhir.Patient.created', 'fhir.Patient.updated'], fromBeginning: false });
  
  await consumer.run({
    eachMessage: async ({ topic, partition, message }) => {
      try {
        // Parse the event
        const event = JSON.parse(message.value?.toString() || '{}');
        const patient = event.resource;
        
        console.log(`Processing ${event.action} event for Patient ${patient.id}`);
        
        // Process the patient based on the event type
        switch (event.action) {
          case 'created':
            await processNewPatient(patient);
            break;
          case 'updated':
            await processUpdatedPatient(patient);
            break;
          default:
            console.warn(`Unknown action: ${event.action}`);
        }
      } catch (error) {
        console.error('Error processing message:', error);
        // Implement error handling strategy (see Error Handling section)
      }
    }
  });
}

async function processNewPatient(patient: any): Promise<void> {
  // Implement business logic for new patients
  console.log(`Processing new patient: ${patient.id}`);
  // Example: Send welcome message, create account, etc.
}

async function processUpdatedPatient(patient: any): Promise<void> {
  // Implement business logic for updated patients
  console.log(`Processing updated patient: ${patient.id}`);
  // Example: Update indexes, notify care team, etc.
}

// Start the consumer
startPatientEventConsumer().catch(console.error);
```

## Command vs. Event Separation

When implementing event-driven architecture with FHIR, it's important to distinguish between commands and events:

### Commands

Commands represent intentions to change the system state. They are directed at a specific service and expect a response.

**Example Command Structure:**

```json
{
  "type": "CreatePatient",
  "data": {
    "resourceType": "Patient",
    "name": [{
      "family": "Smith",
      "given": ["John"]
    }],
    "birthDate": "1970-01-01",
    "gender": "male"
  },
  "metadata": {
    "requestId": "12345",
    "timestamp": "2025-05-02T12:34:56Z",
    "source": "patient-registration-service"
  }
}
```

### Events

Events represent facts that have occurred in the system. They are published to notify interested parties about a change.

**Example Event Structure:**

```json
{
  "type": "PatientCreated",
  "data": {
    "resourceType": "Patient",
    "id": "patient-123",
    "name": [{
      "family": "Smith",
      "given": ["John"]
    }],
    "birthDate": "1970-01-01",
    "gender": "male"
  },
  "metadata": {
    "eventId": "67890",
    "timestamp": "2025-05-02T12:34:57Z",
    "source": "fhir-server",
    "correlationId": "12345"
  }
}
```

### Command-Event Flow

1. A service sends a command to create a FHIR resource
2. The FHIR server processes the command and creates the resource
3. The FHIR server publishes an event indicating the resource was created
4. Other services consume the event and react accordingly

## Error Handling and Retry Mechanisms

Robust error handling is critical in event-driven systems to ensure data integrity and system reliability.

### Common Error Scenarios

1. **Transient Errors**: Temporary issues like network problems or service unavailability
2. **Persistent Errors**: Ongoing issues like invalid data or business rule violations
3. **System Errors**: Unexpected exceptions or crashes in the consuming application

### Implementing a Dead Letter Queue

A Dead Letter Queue (DLQ) is a destination for messages that cannot be processed successfully after multiple attempts.

```typescript
// Example error handling with Dead Letter Queue
import { Kafka } from 'kafkajs';

const kafka = new Kafka({
  clientId: 'fhir-event-consumer',
  brokers: ['localhost:9092']
});

const consumer = kafka.consumer({ groupId: 'patient-processing-group' });
const dlqProducer = kafka.producer();

async function startConsumerWithErrorHandling(): Promise<void> {
  await consumer.connect();
  await dlqProducer.connect();
  
  await consumer.subscribe({ topics: ['fhir.Patient.created'], fromBeginning: false });
  
  await consumer.run({
    eachMessage: async ({ topic, partition, message }) => {
      try {
        const event = JSON.parse(message.value?.toString() || '{}');
        await processPatientEvent(event);
      } catch (error) {
        console.error('Error processing message:', error);
        
        // Get retry count from headers or default to 0
        const retryCount = parseInt(message.headers?.retryCount?.toString() || '0');
        
        if (retryCount < 3) {
          // Retry the message with incremented retry count
          await dlqProducer.send({
            topic: 'fhir.Patient.created.retry',
            messages: [{
              key: message.key,
              value: message.value,
              headers: {
                ...message.headers,
                retryCount: Buffer.from((retryCount + 1).toString()),
                error: Buffer.from(error.message),
                failedAt: Buffer.from(new Date().toISOString())
              }
            }]
          });
          console.log(`Message sent to retry topic, attempt ${retryCount + 1}`);
        } else {
          // Send to dead letter queue after max retries
          await dlqProducer.send({
            topic: 'fhir.Patient.created.dlq',
            messages: [{
              key: message.key,
              value: message.value,
              headers: {
                ...message.headers,
                retryCount: Buffer.from(retryCount.toString()),
                error: Buffer.from(error.message),
                failedAt: Buffer.from(new Date().toISOString())
              }
            }]
          });
          console.log('Message sent to dead letter queue after max retries');
        }
      }
    }
  });
}

async function processPatientEvent(event: any): Promise<void> {
  // Implement business logic
  // Throw an error if processing fails
}

// Start the consumer with error handling
startConsumerWithErrorHandling().catch(console.error);
```

### Retry Strategies

1. **Immediate Retry**: Retry the operation immediately (good for transient errors)
2. **Exponential Backoff**: Increase the delay between retries (reduces system load)
3. **Scheduled Retry**: Retry at a specific time (useful for time-dependent operations)

```typescript
// Example exponential backoff implementation
function calculateBackoffDelay(attempt: number, baseDelay: number = 1000): number {
  return Math.min(
    baseDelay * Math.pow(2, attempt), // Exponential increase
    60000 // Maximum delay of 1 minute
  );
}

async function retryWithBackoff<T>(operation: () => Promise<T>, maxRetries: number = 3): Promise<T> {
  let lastError: Error;
  
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await operation();
    } catch (error) {
      console.error(`Attempt ${attempt + 1} failed:`, error);
      lastError = error as Error;
      
      if (attempt < maxRetries) {
        const delay = calculateBackoffDelay(attempt);
        console.log(`Retrying in ${delay}ms...`);
        await new Promise(resolve => setTimeout(resolve, delay));
      }
    }
  }
  
  throw new Error(`Operation failed after ${maxRetries} retries: ${lastError.message}`);
}
```

## Monitoring and Observability

Effective monitoring is essential for event-driven systems to ensure reliable operation and quick troubleshooting.

### Key Metrics to Monitor

1. **Message Throughput**: Number of events processed per second
2. **Processing Latency**: Time taken to process each event
3. **Error Rate**: Percentage of events that fail processing
4. **Retry Count**: Number of retries per event
5. **DLQ Size**: Number of messages in the dead letter queue

### Implementing Distributed Tracing

```typescript
import { Kafka } from 'kafkajs';
import opentelemetry from '@opentelemetry/api';

const tracer = opentelemetry.trace.getTracer('fhir-event-processor');

async function processEventWithTracing(event: any): Promise<void> {
  // Create a span for this event processing
  const span = tracer.startSpan(`process_${event.type}`);
  
  // Add event metadata to the span
  span.setAttribute('event.id', event.metadata.eventId);
  span.setAttribute('event.type', event.type);
  span.setAttribute('event.resource.type', event.data.resourceType);
  span.setAttribute('event.resource.id', event.data.id);
  
  try {
    // Process the event
    await processEvent(event);
    
    // Mark the span as successful
    span.setStatus({ code: opentelemetry.SpanStatusCode.OK });
  } catch (error) {
    // Record the error in the span
    span.setStatus({
      code: opentelemetry.SpanStatusCode.ERROR,
      message: error.message
    });
    span.recordException(error);
    
    // Re-throw the error for the caller to handle
    throw error;
  } finally {
    // End the span
    span.end();
  }
}
```

## Conclusion

Event-driven architecture with FHIR enables real-time processing of healthcare data, allowing systems to react immediately to changes and maintain a consistent view of patient information across multiple services. By implementing the patterns described in this guide, you can build robust, scalable healthcare applications that process FHIR resources efficiently and reliably.

Key takeaways:

1. Use Kafka as a reliable message broker for FHIR events
2. Design topics based on resource types and actions
3. Implement robust error handling with retry mechanisms and dead letter queues
4. Distinguish between commands and events in your architecture
5. Monitor your event processing pipeline for performance and reliability

By following these best practices, you can build event-driven healthcare applications that scale effectively and provide real-time insights into patient care.
