# Event-Driven Architecture Integration Points

## Introduction
This document outlines the integration points between the Event-Driven Architecture capability and other components of the CoverMyMeds Technology Platform, as well as external systems. The Event-Driven Architecture serves as the communication backbone and processing framework for the entire platform, enabling event-driven patterns, real-time data flows, and loosely coupled integration across the healthcare ecosystem. Understanding these integration points is essential for architects, developers, and operators working with the platform.

## Core Capability Integrations

### FHIR Interoperability Platform Integration

The Event-Driven Architecture integrates deeply with the FHIR Interoperability Platform to enable event-driven healthcare data exchange:

#### Key Integration Points:
- **FHIR Resource Change Events**: The FHIR Platform publishes events when resources are created, updated, or deleted
- **FHIR Subscription Implementation**: Event streaming powers the FHIR Subscription mechanism for notifications
- **Event-Sourced FHIR Resources**: Optional event-sourced implementation of FHIR resources
- **Terminology Distribution**: Real-time distribution of terminology updates
- **FHIR Bulk Data Operations**: Event-driven implementation of bulk data operations
- **Data Synchronization**: Maintaining consistent FHIR data across environments

#### Integration Pattern:
```typescript
// FHIR Resource Change Event Producer
import { Kafka } from 'kafkajs';
import { SchemaRegistry } from '@kafkajs/confluent-schema-registry';

// Initialize Kafka producer
const kafka = new Kafka({
  clientId: 'fhir-platform-producer',
  brokers: ['kafka.cmm.internal:9092'],
  // Auth and SSL configuration
});

const producer = kafka.producer();

// Initialize Schema Registry client
const registry = new SchemaRegistry({
  host: 'https://schema-registry.cmm.internal',
  // Auth configuration
});

// Function to publish FHIR resource change events
async function publishFhirResourceChange(resourceType, resourceId, operation, resource) {
  await producer.connect();
  
  // Create event with standard envelope
  const event = {
    metadata: {
      eventId: uuidv4(),
      eventType: `fhir.${resourceType}.${operation}`,
      eventSource: 'fhir-platform',
      correlationId: getCorrelationId(),
      timestamp: Date.now(),
      version: '1.0.0'
    },
    payload: resource
  };
  
  // Encode event with schema
  const schemaId = await registry.getLatestSchemaId(`fhir-${resourceType}-events-value`);
  const encodedPayload = await registry.encode(schemaId, event);
  
  // Send event to appropriate topic
  await producer.send({
    topic: `fhir.${resourceType.toLowerCase()}`,
    messages: [
      {
        key: resourceId,
        value: encodedPayload,
        headers: {
          'resource-type': resourceType,
          'operation': operation
        }
      }
    ]
  });
  
  await producer.disconnect();
}
```

### API Marketplace Integration

The Event-Driven Architecture enables event-driven API patterns in the API Marketplace:

#### Key Integration Points:
- **Webhook Delivery**: Reliable webhook notifications for API consumers via event streams
- **Event-Driven APIs**: AsyncAPI specifications and implementations
- **API Usage Events**: Tracking and analytics for API usage across the platform
- **Real-Time API Updates**: Push-based API updates using event streams
- **API Gateway Event Patterns**: Event-driven routing and transformation
- **Event Discovery**: API catalog integration for event discovery

#### Integration Pattern:
```typescript
// API Webhook Delivery Consumer
import { Kafka } from 'kafkajs';

const kafka = new Kafka({
  clientId: 'api-marketplace-webhook-service',
  brokers: ['kafka.cmm.internal:9092'],
  // Auth and SSL configuration
});

const consumer = kafka.consumer({ groupId: 'webhook-delivery-service' });

// Initialize webhook delivery service
async function initWebhookDelivery() {
  await consumer.connect();
  await consumer.subscribe({ topics: ['api.webhooks.outbound'], fromBeginning: false });
  
  await consumer.run({
    eachMessage: async ({ topic, partition, message }) => {
      // Extract webhook information
      const webhookPayload = JSON.parse(message.value.toString());
      const { url, headers, payload, retryConfig } = webhookPayload;
      
      try {
        // Deliver webhook with exponential backoff retry
        const result = await deliverWebhook(url, headers, payload, retryConfig);
        
        // Publish delivery result event
        await publishWebhookResult(webhookPayload.id, result);
      } catch (error) {
        // Handle delivery failure
        console.error(`Webhook delivery failed: ${error.message}`);
        
        // Send to DLQ if retry limit exceeded
        if (webhookPayload.retryCount >= webhookPayload.retryConfig.maxRetries) {
          await sendToDeadLetterQueue(webhookPayload);
        } else {
          // Schedule retry with increased retry count
          await scheduleRetry(webhookPayload);
        }
      }
    }
  });
}
```

### Federated Graph API Integration

The Event-Driven Architecture powers real-time features in the Federated Graph API:

#### Key Integration Points:
- **GraphQL Subscriptions**: Real-time subscription capabilities via event streams
- **Cache Invalidation**: Event-driven cache invalidation for GraphQL resolvers
- **Event-Driven Federation**: Event-based composition and data federation
- **Real-Time Data Updates**: Live data updates through event-driven resolvers
- **Event-Sourced Graph Data**: Graph data sourced from event streams
- **Complex Event Processing**: Event pattern detection exposed through GraphQL

#### Integration Pattern:
```typescript
// GraphQL Subscription Handler
import { PubSub } from 'graphql-subscriptions';
import { Kafka } from 'kafkajs';

// Create PubSub instance for GraphQL subscriptions
const pubsub = new PubSub();

const kafka = new Kafka({
  clientId: 'graph-api-subscription-service',
  brokers: ['kafka.cmm.internal:9092'],
  // Auth and SSL configuration
});

const consumer = kafka.consumer({ groupId: 'graphql-subscription-service' });

// Initialize subscription handler
async function initSubscriptionHandler() {
  await consumer.connect();
  
  // Subscribe to relevant topics
  await consumer.subscribe({ 
    topics: [
      'fhir.patient',
      'fhir.medicationrequest',
      'fhir.observation',
      'workflow.priorauth'
    ],
    fromBeginning: false 
  });
  
  await consumer.run({
    eachMessage: async ({ topic, partition, message }) => {
      // Extract event data
      const event = JSON.parse(message.value.toString());
      const resourceType = message.headers['resource-type']?.toString();
      const operation = message.headers['operation']?.toString();
      
      // Map to GraphQL subscription event
      const subscriptionTrigger = `${resourceType}_${operation}`;
      
      // Publish to GraphQL subscription system
      pubsub.publish(subscriptionTrigger, {
        [subscriptionTrigger]: {
          id: message.key.toString(),
          data: event.payload,
          operation: operation
        }
      });
    }
  });
}

// Example GraphQL resolver with subscription
const resolvers = {
  Subscription: {
    patientUpdated: {
      subscribe: () => pubsub.asyncIterator(['Patient_update'])
    },
    medicationRequestCreated: {
      subscribe: () => pubsub.asyncIterator(['MedicationRequest_create'])
    }
  }
};
```

### Design System Integration

The Event-Driven Architecture enables real-time user interface capabilities in the Design System:

#### Key Integration Points:
- **Real-Time UI Components**: Event-driven reactive UI components
- **Notification Framework**: Standardized event-based notification system
- **Collaborative Editing**: Real-time collaborative editing via event sourcing
- **Live Dashboard Components**: Stream-powered data visualization
- **Real-Time Form Validation**: Event-based form validation with external systems
- **Offline-First Patterns**: Event queuing for offline-first applications

#### Integration Pattern:
```typescript
// React hook for real-time updates using WebSockets
import { useState, useEffect } from 'react';

// Custom hook for subscribing to events via WebSocket gateway
function useEventSubscription(topic, filter) {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  
  useEffect(() => {
    // Connect to WebSocket gateway
    const socket = new WebSocket('wss://event-gateway.cmm.internal/ws');
    
    // Handle connection open
    socket.onopen = () => {
      // Subscribe to topic with optional filter
      socket.send(JSON.stringify({
        type: 'subscribe',
        topic: topic,
        filter: filter
      }));
    };
    
    // Handle incoming messages
    socket.onmessage = (event) => {
      try {
        const eventData = JSON.parse(event.data);
        setData(eventData);
        setLoading(false);
      } catch (err) {
        setError('Failed to parse event data');
        setLoading(false);
      }
    };
    
    // Handle errors
    socket.onerror = (err) => {
      setError('WebSocket connection error');
      setLoading(false);
    };
    
    // Clean up on unmount
    return () => {
      if (socket.readyState === WebSocket.OPEN) {
        socket.send(JSON.stringify({
          type: 'unsubscribe',
          topic: topic
        }));
        socket.close();
      }
    };
  }, [topic, filter]);
  
  return { data, loading, error };
}

// Example usage in a notification component
function NotificationCenter({ userId }) {
  const { data, loading, error } = useEventSubscription(
    'user.notifications',
    { userId: userId }
  );
  
  if (loading) return <LoadingSpinner />;
  if (error) return <ErrorDisplay message={error} />;
  
  return (
    <NotificationList 
      notifications={data ? data.notifications : []} 
    />
  );
}
```

## External System Integrations

### EHR System Integration

The Event-Driven Architecture facilitates integration with external Electronic Health Record (EHR) systems:

#### Key Integration Points:
- **Real-Time Clinical Data Exchange**: Bi-directional clinical data streaming
- **FHIR-Based Event Integration**: Standardized healthcare event exchange
- **Workflow Orchestration**: Coordinating cross-system clinical workflows
- **Patient Data Synchronization**: Keeping patient data consistent across systems
- **Order Management**: Event-driven medication and lab order processing
- **Clinical Decision Support**: Real-time clinical alerting and decision support

#### Integration Pattern:
```typescript
// EHR Integration Connector
import { Kafka } from 'kafkajs';
import { connect } from 'kafkajs-connect';
import { EhrApiClient } from './ehr-api-client';

// Initialize Kafka Connect source connector
const sourceConnector = connect.sourceConnector({
  name: 'ehr-patient-data-source',
  taskMaxBufferSize: 100,
  
  // Configuration schema for this connector
  configSchema: {
    ehrEndpoint: { type: 'string', required: true },
    ehrCredentials: { type: 'object', required: true },
    pollInterval: { type: 'number', default: 60000 },
    batchSize: { type: 'number', default: 100 }
  },
  
  // Initialize task with configuration
  initialize: async (config) => {
    const ehrClient = new EhrApiClient({
      endpoint: config.ehrEndpoint,
      credentials: config.ehrCredentials
    });
    
    return {
      ehrClient,
      lastPolledTimestamp: Date.now() - (24 * 60 * 60 * 1000) // Start 24 hours ago
    };
  },
  
  // Poll the EHR system for new patient data
  poll: async (task, context) => {
    const { ehrClient, lastPolledTimestamp } = task;
    
    try {
      // Poll for patient data changes since last check
      const patientChanges = await ehrClient.getPatientChanges({
        since: new Date(lastPolledTimestamp),
        limit: context.config.batchSize
      });
      
      // Transform to standard event format
      const events = patientChanges.map(change => ({
        key: change.patientId,
        value: {
          metadata: {
            eventId: uuidv4(),
            eventType: `ehr.patient.${change.changeType}`,
            eventSource: 'ehr-connector',
            correlationId: change.correlationId || uuidv4(),
            timestamp: Date.now(),
            version: '1.0.0'
          },
          payload: mapEhrPatientToStandardFormat(change.patient)
        },
        topic: 'external.ehr.patient-data'
      }));
      
      // Update last polled timestamp
      task.lastPolledTimestamp = Date.now();
      
      return events;
    } catch (error) {
      console.error('Error polling EHR system', error);
      return [];
    }
  }
});
```

### Pharmacy System Integration

The Event-Driven Architecture enables real-time integration with pharmacy management systems:

#### Key Integration Points:
- **Prescription Event Streaming**: Real-time prescription status updates
- **Medication Inventory Events**: Live inventory monitoring and alerts
- **Fulfillment Workflow**: Event-driven prescription fulfillment orchestration
- **Pharmacy Claim Events**: Real-time claim submission and adjudication
- **Medication Price Updates**: Dynamic medication pricing updates
- **Patient Medication History**: Comprehensive medication history via events

#### Integration Pattern:
```typescript
// Pharmacy System Integration - Sink Connector
import { Kafka } from 'kafkajs';
import { connect } from 'kafkajs-connect';
import { PharmacyClient } from './pharmacy-client';

// Initialize Kafka Connect sink connector
const sinkConnector = connect.sinkConnector({
  name: 'pharmacy-prescription-sink',
  
  // Configuration schema for this connector
  configSchema: {
    pharmacyEndpoint: { type: 'string', required: true },
    pharmacyApiKey: { type: 'string', required: true },
    maxRetries: { type: 'number', default: 3 },
    retryBackoffMs: { type: 'number', default: 1000 }
  },
  
  // Initialize task with configuration
  initialize: async (config) => {
    return new PharmacyClient({
      endpoint: config.pharmacyEndpoint,
      apiKey: config.pharmacyApiKey,
      maxRetries: config.maxRetries,
      retryBackoffMs: config.retryBackoffMs
    });
  },
  
  // Process records from Kafka and send to pharmacy system
  put: async (records, pharmacyClient) => {
    const results = [];
    
    for (const record of records) {
      try {
        // Extract prescription from event
        const event = JSON.parse(record.value.toString());
        const prescription = event.payload;
        
        // Determine operation based on event type
        const operation = event.metadata.eventType.split('.').pop();
        
        // Send to pharmacy system
        let result;
        switch (operation) {
          case 'created':
            result = await pharmacyClient.createPrescription(prescription);
            break;
          case 'updated':
            result = await pharmacyClient.updatePrescription(prescription);
            break;
          case 'cancelled':
            result = await pharmacyClient.cancelPrescription(prescription.id);
            break;
          default:
            throw new Error(`Unsupported operation: ${operation}`);
        }
        
        results.push({
          record,
          success: true,
          result
        });
      } catch (error) {
        console.error(`Error processing record for pharmacy system: ${error.message}`);
        results.push({
          record,
          success: false,
          error: error.message
        });
      }
    }
    
    return results;
  }
});
```

### Payer System Integration

The Event-Driven Architecture facilitates real-time integration with healthcare payer systems:

#### Key Integration Points:
- **Prior Authorization Events**: End-to-end prior authorization workflow events
- **Claims Event Stream**: Real-time claim submission, processing, and status
- **Eligibility Verification**: Real-time eligibility check events
- **Benefit Configuration Updates**: Dynamic benefit updates via events
- **Member Enrollment Events**: Member enrollment and demographic changes
- **Provider Network Updates**: Real-time provider network changes

#### Integration Pattern:
```typescript
// Payer Integration - Prior Authorization Producer
import { Kafka } from 'kafkajs';
import { SchemaRegistry } from '@kafkajs/confluent-schema-registry';

// Initialize Kafka producer
const kafka = new Kafka({
  clientId: 'prior-auth-service',
  brokers: ['kafka.cmm.internal:9092'],
  // Auth and SSL configuration
});

const producer = kafka.producer();

// Initialize Schema Registry client
const registry = new SchemaRegistry({
  host: 'https://schema-registry.cmm.internal',
  // Auth configuration
});

// Function to publish prior authorization status updates
async function publishPriorAuthUpdate(priorAuth) {
  await producer.connect();
  
  // Create event with standard envelope
  const event = {
    metadata: {
      eventId: uuidv4(),
      eventType: `priorAuth.status.${priorAuth.status.toLowerCase()}`,
      eventSource: 'prior-auth-service',
      correlationId: priorAuth.correlationId,
      causationId: priorAuth.requestId,
      timestamp: Date.now(),
      version: '1.0.0'
    },
    payload: priorAuth
  };
  
  // Encode event with schema
  const schemaId = await registry.getLatestSchemaId('prior-auth-events-value');
  const encodedPayload = await registry.encode(schemaId, event);
  
  // Send event to appropriate topic
  await producer.send({
    topic: 'workflow.prior-auth.status',
    messages: [
      {
        key: priorAuth.id,
        value: encodedPayload,
        headers: {
          'auth-status': priorAuth.status,
          'payer-id': priorAuth.payerId
        }
      }
    ]
  });
  
  await producer.disconnect();
}
```

### Patient Mobile App Integration

The Event-Driven Architecture supports real-time patient engagement through mobile applications:

#### Key Integration Points:
- **Push Notifications**: Real-time notifications to patient devices
- **Medication Reminders**: Event-driven medication adherence reminders
- **Care Plan Updates**: Real-time care plan changes and notifications
- **Health Monitoring**: Stream processing for patient health data
- **Appointment Management**: Real-time appointment scheduling and updates
- **Care Team Communication**: Event-driven care team messaging

#### Integration Pattern:
```typescript
// Mobile App Notification Gateway
import { Kafka } from 'kafkajs';
import { FirebaseAdmin } from 'firebase-admin';
import { APNSClient } from './apns-client';

// Initialize Kafka consumer
const kafka = new Kafka({
  clientId: 'mobile-notification-gateway',
  brokers: ['kafka.cmm.internal:9092'],
  // Auth and SSL configuration
});

const consumer = kafka.consumer({ groupId: 'mobile-notification-service' });

// Initialize push notification clients
const firebaseClient = new FirebaseAdmin(/* config */);
const apnsClient = new APNSClient(/* config */);

// Start the notification gateway
async function startNotificationGateway() {
  await consumer.connect();
  
  // Subscribe to notification topics
  await consumer.subscribe({ 
    topics: [
      'patient.notifications.mobile',
      'medication.reminders',
      'appointment.updates',
      'care-plan.changes'
    ],
    fromBeginning: false 
  });
  
  await consumer.run({
    eachMessage: async ({ topic, partition, message }) => {
      try {
        // Parse notification payload
        const notification = JSON.parse(message.value.toString());
        const { userId, deviceTokens, platform, title, body, data } = notification;
        
        // Send to appropriate platform
        if (platform === 'android' || platform === 'both') {
          const androidTokens = deviceTokens.filter(token => 
            token.platform === 'android' || token.platform === 'fcm'
          );
          
          if (androidTokens.length > 0) {
            await firebaseClient.sendMulticast({
              tokens: androidTokens.map(t => t.token),
              notification: { title, body },
              data: data
            });
          }
        }
        
        if (platform === 'ios' || platform === 'both') {
          const iosTokens = deviceTokens.filter(token => 
            token.platform === 'ios' || token.platform === 'apns'
          );
          
          if (iosTokens.length > 0) {
            await apnsClient.sendMulticast({
              tokens: iosTokens.map(t => t.token),
              notification: { title, body },
              payload: data
            });
          }
        }
        
        // Track delivery status
        await trackNotificationDelivery(notification, 'sent');
        
      } catch (error) {
        console.error('Error sending push notification', error);
        // Implement appropriate error handling
        await trackNotificationDelivery(notification, 'failed', error.message);
      }
    }
  });
}
```

## Advanced Integration Patterns

### Event-Driven Microservices

Integration pattern for building event-driven microservices:

```typescript
// Event-Driven Microservice Pattern
import { Kafka } from 'kafkajs';
import { SchemaRegistry } from '@kafkajs/confluent-schema-registry';
import express from 'express';

// Initialize Express app
const app = express();

// Initialize Kafka clients
const kafka = new Kafka({
  clientId: 'patient-service',
  brokers: ['kafka.cmm.internal:9092'],
  // Auth and SSL configuration
});

const producer = kafka.producer();
const consumer = kafka.consumer({ groupId: 'patient-service' });
const registry = new SchemaRegistry({
  host: 'https://schema-registry.cmm.internal',
});

// Initialize service
async function initializeService() {
  // Connect to Kafka
  await producer.connect();
  await consumer.connect();
  
  // Subscribe to relevant topics
  await consumer.subscribe({ 
    topics: ['command.patient.create', 'command.patient.update'],
    fromBeginning: false 
  });
  
  // Process commands
  await consumer.run({
    eachMessage: async ({ topic, partition, message }) => {
      try {
        // Parse command
        const command = JSON.parse(message.value.toString());
        
        // Process based on command type
        if (topic === 'command.patient.create') {
          await handleCreatePatient(command);
        } else if (topic === 'command.patient.update') {
          await handleUpdatePatient(command);
        }
      } catch (error) {
        console.error('Error processing command', error);
        // Publish error event
        await publishErrorEvent(topic, error, message);
      }
    }
  });
  
  // Start HTTP API
  app.use(express.json());
  
  // Command API endpoints
  app.post('/patients', async (req, res) => {
    try {
      // Create command
      const command = {
        commandId: uuidv4(),
        timestamp: Date.now(),
        data: req.body
      };
      
      // Publish command
      await producer.send({
        topic: 'command.patient.create',
        messages: [
          {
            key: command.commandId,
            value: JSON.stringify(command)
          }
        ]
      });
      
      res.status(202).json({ 
        commandId: command.commandId, 
        message: 'Command accepted'
      });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });
  
  // Start server
  app.listen(3000, () => {
    console.log('Patient service started on port 3000');
  });
}

// Handle create patient command
async function handleCreatePatient(command) {
  // Process command
  const patientId = uuidv4();
  const patient = {
    id: patientId,
    ...command.data,
    createdAt: Date.now(),
    updatedAt: Date.now()
  };
  
  // Store patient in database
  await storePatient(patient);
  
  // Publish patient created event
  await publishEvent('patient.created', patientId, patient, command.commandId);
}

// Publish event
async function publishEvent(eventType, key, data, causationId) {
  const event = {
    metadata: {
      eventId: uuidv4(),
      eventType,
      timestamp: Date.now(),
      correlationId: causationId,
      causationId
    },
    payload: data
  };
  
  // Get schema ID
  const topic = eventType.split('.')[0];
  const schemaId = await registry.getLatestSchemaId(`${topic}-events-value`);
  
  // Encode and send event
  const encodedEvent = await registry.encode(schemaId, event);
  
  await producer.send({
    topic: eventType.replace('.', '.'),
    messages: [
      {
        key,
        value: encodedEvent
      }
    ]
  });
}
```

### Event Sourcing with CQRS

Integration pattern for event sourcing with CQRS:

```typescript
// Event Sourcing with CQRS Pattern
import { Kafka } from 'kafkajs';
import { SchemaRegistry } from '@kafkajs/confluent-schema-registry';
import { MongoClient } from 'mongodb';

// Initialize Kafka clients
const kafka = new Kafka({
  clientId: 'patient-aggregate-service',
  brokers: ['kafka.cmm.internal:9092'],
});

const producer = kafka.producer();
const consumer = kafka.consumer({ groupId: 'patient-aggregate-service' });
const registry = new SchemaRegistry({
  host: 'https://schema-registry.cmm.internal',
});

// Initialize MongoDB
const mongoClient = new MongoClient('mongodb://read-models.cmm.internal:27017');
const readModels = mongoClient.db('patient').collection('patient_view');

// Initialize event store and projections
async function initialize() {
  await mongoClient.connect();
  await producer.connect();
  await consumer.connect();
  
  // Subscribe to patient events
  await consumer.subscribe({ 
    topics: ['patient.created', 'patient.updated', 'patient.demographics-changed'],
    fromBeginning: true // Important for event sourcing - replay all events
  });
  
  // Process events
  await consumer.run({
    eachMessage: async ({ topic, partition, message }) => {
      try {
        // Decode and parse event
        const event = JSON.parse(message.value.toString());
        const patientId = message.key.toString();
        
        // Update read model
        await updateReadModel(patientId, event);
      } catch (error) {
        console.error('Error processing event', error);
      }
    }
  });
}

// Update read model
async function updateReadModel(patientId, event) {
  const eventType = event.metadata.eventType;
  const data = event.payload;
  
  switch (eventType) {
    case 'patient.created':
      // Insert new patient read model
      await readModels.insertOne({
        _id: patientId,
        ...data,
        version: 1,
        lastUpdated: new Date()
      });
      break;
      
    case 'patient.updated':
      // Update patient read model
      await readModels.updateOne(
        { _id: patientId },
        { 
          $set: { ...data, lastUpdated: new Date() },
          $inc: { version: 1 }
        }
      );
      break;
      
    case 'patient.demographics-changed':
      // Update specific demographics fields
      await readModels.updateOne(
        { _id: patientId },
        { 
          $set: { 
            name: data.name,
            dateOfBirth: data.dateOfBirth,
            gender: data.gender,
            address: data.address,
            lastUpdated: new Date()
          },
          $inc: { version: 1 }
        }
      );
      break;
  }
}

// Load aggregate by replaying events
async function loadPatientAggregate(patientId) {
  // Create admin client to read directly from topic by key
  const admin = kafka.admin();
  await admin.connect();
  
  // Get all partitions for patient topic
  const topicOffsets = await admin.fetchTopicOffsets('patient');
  
  // Initialize patient aggregate
  let patient = null;
  
  // Create consumer to read events for specific patient
  const aggregateConsumer = kafka.consumer({ groupId: `temp-${uuidv4()}` });
  await aggregateConsumer.connect();
  await aggregateConsumer.subscribe({ topics: ['patient'], fromBeginning: true });
  
  // Process events
  return new Promise((resolve, reject) => {
    aggregateConsumer.run({
      eachMessage: async ({ topic, partition, message }) => {
        if (message.key.toString() === patientId) {
          const event = JSON.parse(message.value.toString());
          
          // Apply event to aggregate
          patient = applyEvent(patient, event);
        }
      }
    })
    .then(() => {
      aggregateConsumer.disconnect();
      admin.disconnect();
      resolve(patient);
    })
    .catch(err => {
      aggregateConsumer.disconnect();
      admin.disconnect();
      reject(err);
    });
  });
}

// Apply event to aggregate
function applyEvent(patient, event) {
  const eventType = event.metadata.eventType;
  const data = event.payload;
  
  switch (eventType) {
    case 'patient.created':
      return {
        id: data.id,
        ...data,
        version: 1
      };
      
    case 'patient.updated':
      return {
        ...patient,
        ...data,
        version: patient.version + 1
      };
      
    case 'patient.demographics-changed':
      return {
        ...patient,
        name: data.name,
        dateOfBirth: data.dateOfBirth,
        gender: data.gender,
        address: data.address,
        version: patient.version + 1
      };
      
    default:
      return patient;
  }
}
```

### Stream Processing Integration

Integration pattern for stream processing:

```typescript
// Stream Processing Integration Pattern
import { KafkaStreams, KStream } from 'kafka-streams';

// Configure Kafka Streams
const config = {
  'noptions': {
    'metadata.broker.list': 'kafka.cmm.internal:9092',
    'group.id': 'medication-alert-processor',
    'client.id': 'medication-alert-processor-1',
    'event_cb': true,
    'compression.codec': 'snappy',
    'api.version.request': true,
    'socket.keepalive.enable': true,
    'socket.blocking.max.ms': 100,
    'enable.auto.commit': false,
    'auto.commit.interval.ms': 100,
    'heartbeat.interval.ms': 250,
    'retry.backoff.ms': 250,
    'fetch.min.bytes': 100,
    'fetch.message.max.bytes': 2 * 1024 * 1024,
    'queued.min.messages': 100,
    'fetch.error.backoff.ms': 100,
    'queued.max.messages.kbytes': 50,
    'fetch.wait.max.ms': 1000,
    'queue.buffering.max.ms': 1000,
    'batch.num.messages': 10000
  },
  'tconf': {
    'auto.offset.reset': 'earliest',
    'request.required.acks': 1
  },
  'batchOptions': {
    'batchSize': 500,
    'commitEveryNBatch': 1,
    'concurrency': 1,
    'commitSync': false
  }
};

const kafkaStreams = new KafkaStreams(config);

// Initialize stream processing
async function initializeStreamProcessing() {
  // Create input streams
  const medicationStream = kafkaStreams.getKStream('fhir.medicationrequest');
  const patientStream = kafkaStreams.getKStream('fhir.patient');
  
  // Process medication requests
  const alertStream = medicationStream
    // Parse event
    .map(message => {
      const event = JSON.parse(message.value.toString());
      return {
        key: message.key.toString(),
        value: event.payload,
        metadata: event.metadata
      };
    })
    // Filter for new medication requests
    .filter(event => 
      event.metadata.eventType === 'fhir.MedicationRequest.created' ||
      event.metadata.eventType === 'fhir.MedicationRequest.updated'
    )
    // Extract patient ID and medication details
    .map(event => {
      const medication = event.value;
      return {
        medicationRequestId: medication.id,
        patientId: medication.subject.reference.split('/')[1],
        medication: medication.medicationCodeableConcept,
        dosageInstruction: medication.dosageInstruction,
        authoredOn: medication.authoredOn,
        status: medication.status,
        eventTimestamp: event.metadata.timestamp
      };
    })
    // Join with patient data
    .leftJoin(
      patientStream
        .map(message => {
          const event = JSON.parse(message.value.toString());
          return {
            key: message.key.toString(),
            value: event.payload
          };
        })
        // Key by patient ID
        .map(event => ({
          key: event.key,
          value: {
            id: event.key,
            name: event.value.name,
            birthDate: event.value.birthDate,
            gender: event.value.gender,
            telecom: event.value.telecom
          }
        })),
      // Join on patient ID
      (medicationData, patientData) => {
        if (!patientData) return null; // Skip if patient not found
        return {
          medicationRequestId: medicationData.medicationRequestId,
          patientId: medicationData.patientId,
          patientName: patientData.name[0]?.text || 'Unknown',
          patientBirthDate: patientData.birthDate,
          medication: medicationData.medication,
          dosageInstruction: medicationData.dosageInstruction,
          status: medicationData.status,
          authoredOn: medicationData.authoredOn,
          eventTimestamp: medicationData.eventTimestamp
        };
      }
    )
    // Filter out null results
    .filter(joinedData => joinedData !== null)
    // Detect potential medication interactions
    .asyncMap(async (joinedData) => {
      // Check for interactions against medication database
      const interactions = await checkMedicationInteractions(
        joinedData.patientId, 
        joinedData.medication
      );
      
      if (interactions.length > 0) {
        return {
          ...joinedData,
          interactions,
          alertType: 'MEDICATION_INTERACTION',
          alertSeverity: getMaxSeverity(interactions)
        };
      }
      
      return null;
    })
    // Filter out non-alerts
    .filter(data => data !== null)
    // Generate alert events
    .map(alertData => ({
      key: alertData.medicationRequestId,
      value: JSON.stringify({
        metadata: {
          eventId: uuidv4(),
          eventType: 'alert.medication-interaction',
          timestamp: Date.now(),
          correlationId: alertData.medicationRequestId
        },
        payload: alertData
      })
    }));
  
  // Produce alerts to output topic
  alertStream.to('alerts.medication');
  
  // Start processing
  await kafkaStreams.start();
  console.log('Stream processing started');
}
```

## Related Resources
- [Event-Driven Architecture Overview](./overview.md)
- [EDA Design](./architecture.md)
- [EDA Key Concepts](./key-concepts.md)
- [Event Patterns](../03-core-functionality/event-patterns.md)
- [FHIR Interoperability Platform Integration](../../fhir-interoperability-platform/01-overview/integration-points.md)
- [API Marketplace Webhook Management](../../api-marketplace/03-core-functionality/api-registration.md)
- [Federated Graph API Subscriptions](../../federated-graph-api/03-core-functionality/query-resolution.md)