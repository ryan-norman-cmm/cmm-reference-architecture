# Event Broker Integration Points

## Introduction
This document outlines the integration points between the Event Broker and other components of the CoverMyMeds Technology Platform, as well as external systems. The Event Broker serves as the central nervous system for real-time data exchange, enabling event-driven communication across the healthcare ecosystem. Understanding these integration points is essential for architects, developers, and operators working with the platform.

## Core Component Integrations

### FHIR Interoperability Platform Integration

The Event Broker integrates with the FHIR Interoperability Platform to enable event-driven healthcare data exchange:

#### Key Integration Points:
- **FHIR Resource Change Events**: The FHIR Platform publishes events when resources are created, updated, or deleted
- **FHIR Subscription Implementation**: Event Broker powers the FHIR Subscription mechanism for notifications
- **Terminology Updates**: Notifications for value set and code system updates
- **Data Replication**: Support for maintaining synchronized FHIR data across environments

#### Integration Pattern:
```typescript
// FHIR Resource Change Event Producer
import { Kafka } from 'kafkajs';
import { SchemaRegistry } from '@kafkajs/confluent-schema-registry';

// Initialize Kafka producer
const kafka = new Kafka({
  clientId: 'fhir-platform-producer',
  brokers: ['event-broker.cmm.internal:9092'],
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

The Event Broker integrates with the API Marketplace to support event-driven API patterns:

#### Key Integration Points:
- **Webhook Delivery**: Event Broker powers webhook notifications for API consumers
- **API Usage Events**: Tracking and analytics for API usage across the platform
- **Async API Support**: Implementation of asynchronous API patterns
- **Event-Driven APIs**: Publishing API events for consumption by other services

#### Integration Pattern:
```typescript
// API Webhook Delivery Consumer
import { Kafka } from 'kafkajs';

const kafka = new Kafka({
  clientId: 'api-marketplace-webhook-service',
  brokers: ['event-broker.cmm.internal:9092'],
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
        
        // Log delivery result
        console.log(`Webhook delivered to ${url} with status ${result.status}`);
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

The Event Broker integrates with the Federated Graph API to enable real-time data updates:

#### Key Integration Points:
- **GraphQL Subscriptions**: Powering real-time subscription capabilities in GraphQL
- **Cache Invalidation**: Triggering cache invalidation for GraphQL resolvers
- **Event-Based Data Federation**: Supporting data composition across services
- **Real-Time Analytics**: Streaming analytics data for GraphQL operations

#### Integration Pattern:
```typescript
// GraphQL Subscription Handler
import { PubSub } from 'graphql-subscriptions';
import { Kafka } from 'kafkajs';

// Create PubSub instance for GraphQL subscriptions
const pubsub = new PubSub();

const kafka = new Kafka({
  clientId: 'graph-api-subscription-service',
  brokers: ['event-broker.cmm.internal:9092'],
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

The Event Broker provides real-time update capabilities for Design System components:

#### Key Integration Points:
- **Real-Time UI Updates**: Pushing live updates to user interfaces
- **Notification Components**: Powering notification and alert components
- **Activity Feeds**: Supporting real-time activity streams in UI components
- **Form State Synchronization**: Coordinating multi-user form interactions

#### Integration Pattern:
```typescript
// React hook for real-time updates using WebSockets
import { useState, useEffect } from 'react';

// Custom hook for subscribing to Kafka events via WebSocket gateway
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

The Event Broker facilitates integration with external Electronic Health Record (EHR) systems:

#### Key Integration Points:
- **Patient Data Synchronization**: Keeping patient demographics in sync
- **Clinical Document Exchange**: Sharing clinical documents and notes
- **Order Workflow Events**: Managing medication order lifecycles
- **Appointment Notifications**: Handling appointment scheduling events

#### Integration Pattern:
```typescript
// EHR Integration Connector
import { Kafka } from 'kafkajs';
import { connect } from 'kafkajs-connect';
import { EhrApiClient } from './ehr-api-client';

// Initialize Kafka Connect source connector
const sourceConnector = connect.sourceConnector({
  name: 'ehr-medication-orders-source',
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
  
  // Poll the EHR system for new medication orders
  poll: async (task, context) => {
    const { ehrClient, lastPolledTimestamp } = task;
    
    try {
      // Poll for new medication orders since last check
      const newOrders = await ehrClient.getMedicationOrders({
        since: new Date(lastPolledTimestamp),
        limit: context.config.batchSize
      });
      
      // Transform orders to standard event format
      const events = newOrders.map(order => ({
        key: order.id,
        value: {
          metadata: {
            eventId: uuidv4(),
            eventType: 'medicationOrder.created',
            eventSource: 'ehr-connector',
            correlationId: order.encounterNumber,
            timestamp: Date.now(),
            version: '1.0.0'
          },
          payload: mapEhrOrderToStandardFormat(order)
        },
        topic: 'external.ehr.medication-orders'
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

The Event Broker enables integration with pharmacy management systems:

#### Key Integration Points:
- **Prescription Events**: Tracking prescription status changes
- **Inventory Updates**: Managing medication inventory levels
- **Fulfillment Notifications**: Coordinating prescription fulfillment
- **Claims Processing**: Handling pharmacy benefit claim events

#### Integration Pattern:
```typescript
// Pharmacy System Integration - Sink Connector
import { Kafka } from 'kafkajs';
import { connect } from 'kafkajs-connect';
import { PharmacyClient } from './pharmacy-client';

// Initialize Kafka Connect sink connector
const sinkConnector = connect.sinkConnector({
  name: 'pharmacy-system-sink',
  
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
        // Extract medication order from event
        const event = JSON.parse(record.value.toString());
        const medicationOrder = event.payload;
        
        // Determine operation based on event type
        const operation = event.metadata.eventType.split('.').pop();
        
        // Send to pharmacy system
        let result;
        switch (operation) {
          case 'created':
            result = await pharmacyClient.createPrescription(medicationOrder);
            break;
          case 'updated':
            result = await pharmacyClient.updatePrescription(medicationOrder);
            break;
          case 'cancelled':
            result = await pharmacyClient.cancelPrescription(medicationOrder.id);
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

The Event Broker facilitates integration with healthcare payer systems:

#### Key Integration Points:
- **Prior Authorization Events**: Managing prior authorization workflows
- **Eligibility Checks**: Processing benefit eligibility verifications
- **Claims Processing**: Handling healthcare claims submissions and responses
- **Member Updates**: Managing payer member data changes

#### Integration Pattern:
```typescript
// Payer Integration - Prior Authorization Producer
import { Kafka } from 'kafkajs';
import { SchemaRegistry } from '@kafkajs/confluent-schema-registry';

// Initialize Kafka producer
const kafka = new Kafka({
  clientId: 'prior-auth-service',
  brokers: ['event-broker.cmm.internal:9092'],
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

### Mobile App Integration

The Event Broker supports integration with patient and provider mobile applications:

#### Key Integration Points:
- **Push Notifications**: Sending real-time notifications to mobile devices
- **Medication Reminders**: Coordinating medication adherence workflows
- **Status Updates**: Providing real-time updates on healthcare processes
- **Care Coordination**: Supporting care team communication and coordination

#### Integration Pattern:
```typescript
// Mobile App Notification Gateway
import { Kafka } from 'kafkajs';
import { FirebaseAdmin } from 'firebase-admin';
import { APNSClient } from './apns-client';

// Initialize Kafka consumer
const kafka = new Kafka({
  clientId: 'mobile-notification-gateway',
  brokers: ['event-broker.cmm.internal:9092'],
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
      'user.notifications.mobile',
      'medication.reminders',
      'priorauth.status.updates',
      'appointment.reminders'
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
        
      } catch (error) {
        console.error('Error sending push notification', error);
        // Implement appropriate error handling strategy
      }
    }
  });
}
```

## Message Transformation Patterns

### Event Normalization

Standardizing events from different sources into a consistent format:

```typescript
// Event Normalization Processor
import { Kafka } from 'kafkajs';
import { SchemaRegistry } from '@kafkajs/confluent-schema-registry';

// Initialize Kafka client for streams processing
const kafka = new Kafka({
  clientId: 'event-normalizer',
  brokers: ['event-broker.cmm.internal:9092'],
  // Auth and SSL configuration
});

const consumer = kafka.consumer({ groupId: 'event-normalizer' });
const producer = kafka.producer();
const registry = new SchemaRegistry({ 
  host: 'https://schema-registry.cmm.internal' 
});

// Start normalization process
async function startNormalization() {
  await consumer.connect();
  await producer.connect();
  
  // Subscribe to source topics
  await consumer.subscribe({ 
    topics: ['external.ehr.medication-orders', 'external.pharmacy.prescriptions'],
    fromBeginning: false 
  });
  
  await consumer.run({
    eachMessage: async ({ topic, partition, message }) => {
      try {
        // Parse incoming event
        const sourceEvent = JSON.parse(message.value.toString());
        const source = topic.split('.')[1]; // Extract source system
        
        // Normalize event based on source
        let normalizedEvent;
        
        if (source === 'ehr') {
          normalizedEvent = normalizeEhrMedicationOrder(sourceEvent);
        } else if (source === 'pharmacy') {
          normalizedEvent = normalizePharmacyPrescription(sourceEvent);
        } else {
          throw new Error(`Unknown source: ${source}`);
        }
        
        // Encode with canonical schema
        const schemaId = await registry.getLatestSchemaId('medication-orders-normalized-value');
        const encodedValue = await registry.encode(schemaId, normalizedEvent);
        
        // Publish to canonical topic
        await producer.send({
          topic: 'canonical.medication-orders',
          messages: [
            {
              key: normalizedEvent.orderId,
              value: encodedValue,
              headers: {
                'source-system': source,
                'event-type': 'medication-order'
              }
            }
          ]
        });
      } catch (error) {
        console.error('Error normalizing event', error);
        // Implement appropriate error handling
      }
    }
  });
}

// Normalization functions for different source systems
function normalizeEhrMedicationOrder(ehrOrder) {
  return {
    orderId: ehrOrder.orderId || ehrOrder.id,
    externalId: ehrOrder.id,
    sourceSystem: 'ehr',
    patientId: mapPatientId(ehrOrder.patientId),
    medication: {
      ndc: ehrOrder.medication.ndc || extractNdcFromCode(ehrOrder.medication.code),
      name: ehrOrder.medication.name || ehrOrder.medication.description,
      strength: ehrOrder.medication.strength,
      form: ehrOrder.medication.form || extractFormFromDescription(ehrOrder.medication.description),
      quantity: ehrOrder.quantity || ehrOrder.medication.quantity,
      daysSupply: ehrOrder.daysSupply || calculateDaysSupply(ehrOrder)
    },
    prescriber: {
      id: ehrOrder.prescriberId || ehrOrder.provider.id,
      npi: ehrOrder.prescriberNpi || ehrOrder.provider.npi,
      name: formatProviderName(ehrOrder.provider)
    },
    pharmacy: ehrOrder.pharmacy ? {
      id: ehrOrder.pharmacy.id,
      ncpdpId: ehrOrder.pharmacy.ncpdpId,
      name: ehrOrder.pharmacy.name
    } : null,
    status: mapOrderStatus(ehrOrder.status),
    createdAt: ehrOrder.createdAt || ehrOrder.orderDate,
    updatedAt: ehrOrder.updatedAt || ehrOrder.lastUpdated
  };
}

function normalizePharmacyPrescription(pharmacyRx) {
  // Similar normalization logic for pharmacy system
  // ...
}
```

### Event Enrichment

Enhancing events with additional data from reference systems:

```typescript
// Event Enrichment Processor
import { Kafka } from 'kafkajs';
import { MongoClient } from 'mongodb';
import { RedisClient } from 'redis';

// Initialize Kafka client
const kafka = new Kafka({
  clientId: 'event-enricher',
  brokers: ['event-broker.cmm.internal:9092'],
  // Auth and SSL configuration
});

const consumer = kafka.consumer({ groupId: 'event-enricher' });
const producer = kafka.producer();

// Initialize data sources for enrichment
const mongoClient = new MongoClient('mongodb://reference-data.cmm.internal:27017');
const redisClient = new RedisClient('redis://cache.cmm.internal:6379');

// Start enrichment process
async function startEnrichment() {
  await consumer.connect();
  await producer.connect();
  await mongoClient.connect();
  
  const referenceData = mongoClient.db('reference').collection('drug_reference');
  
  // Subscribe to source topic
  await consumer.subscribe({ 
    topic: 'canonical.medication-orders',
    fromBeginning: false 
  });
  
  await consumer.run({
    eachMessage: async ({ topic, partition, message }) => {
      try {
        // Parse incoming event
        const event = JSON.parse(message.value.toString());
        const orderId = event.orderId;
        const ndc = event.medication.ndc;
        
        // Try to get drug details from cache first
        const cacheKey = `drug_details:${ndc}`;
        let drugDetails = await getFromCache(redisClient, cacheKey);
        
        // If not in cache, look up in reference database
        if (!drugDetails) {
          drugDetails = await referenceData.findOne({ ndc });
          
          // Cache the results if found
          if (drugDetails) {
            await setInCache(redisClient, cacheKey, drugDetails, 86400); // 24 hour TTL
          }
        }
        
        // Enrich the event with drug details
        const enrichedEvent = {
          ...event,
          medication: {
            ...event.medication,
            // Add reference data details
            gpi: drugDetails?.gpi,
            drugClass: drugDetails?.drugClass,
            genericName: drugDetails?.genericName,
            brandName: drugDetails?.brandName,
            manufacturer: drugDetails?.manufacturer,
            controlled: drugDetails?.controlled,
            schedule: drugDetails?.schedule,
            averageWholesalePrice: drugDetails?.awp,
            formularyStatus: await getFormularyStatus(event),
            alternatives: drugDetails?.alternatives
          }
        };
        
        // Publish enriched event
        await producer.send({
          topic: 'canonical.medication-orders.enriched',
          messages: [
            {
              key: orderId,
              value: JSON.stringify(enrichedEvent),
              headers: {
                'enrichment-source': 'drug-reference',
                'event-type': 'medication-order-enriched'
              }
            }
          ]
        });
      } catch (error) {
        console.error('Error enriching event', error);
        // Implement appropriate error handling
      }
    }
  });
}

// Helper functions for cache operations and formulary lookup
async function getFromCache(redis, key) {
  return new Promise((resolve, reject) => {
    redis.get(key, (err, data) => {
      if (err) return reject(err);
      if (!data) return resolve(null);
      try {
        resolve(JSON.parse(data));
      } catch (e) {
        reject(e);
      }
    });
  });
}

async function setInCache(redis, key, value, ttl) {
  return new Promise((resolve, reject) => {
    redis.set(key, JSON.stringify(value), 'EX', ttl, (err) => {
      if (err) return reject(err);
      resolve();
    });
  });
}

async function getFormularyStatus(event) {
  // Lookup formulary status based on patient's insurance and drug
  // Implementation details omitted
  return 'TIER_2';
}
```

## Related Resources
- [Event Broker Overview](../01-getting-started/overview.md)
- [Event Broker Core APIs](./core-apis.md)
- [Topic Management](./topic-management.md)
- [FHIR Interoperability Platform Integration](../../fhir-interoperability-platform/02-core-functionality/integration-points.md)
- [API Marketplace Webhook Management](../../api-marketplace/02-core-functionality/api-registration.md)
- [Federated Graph API Subscriptions](../../federated-graph-api/02-core-functionality/query-resolution.md)