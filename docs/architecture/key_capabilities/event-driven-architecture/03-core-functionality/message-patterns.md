# Event Broker Message Patterns

## Introduction
This document describes the standard message patterns supported by the Event Broker, providing guidance on when and how to use each pattern. These patterns establish a consistent approach to event-driven communication across the CoverMyMeds Technology Platform, enabling reliable, scalable, and maintainable integrations.

## Core Message Patterns

### Publish-Subscribe Pattern

The foundational pattern in the Event Broker where producers publish events to topics, and multiple independent consumers subscribe to receive those events.

#### When to Use
- Broadcasting notifications to multiple systems
- Decoupling producers from consumers
- Enabling parallel processing pipelines
- Supporting multiple views or projections of the same events

#### Implementation

**Producer Side:**
```typescript
import { Kafka } from 'kafkajs';

const kafka = new Kafka({
  clientId: 'medication-service',
  brokers: ['event-broker.cmm.internal:9092'],
  // Auth configuration
});

const producer = kafka.producer();
await producer.connect();

async function publishMedicationPrescribed(prescription) {
  try {
    await producer.send({
      topic: 'medication.prescription.created',
      messages: [
        {
          key: prescription.id,
          value: JSON.stringify({
            metadata: {
              eventId: uuidv4(),
              eventType: 'medication.prescription.created',
              eventSource: 'medication-service',
              timestamp: Date.now(),
              correlationId: getCorrelationId()
            },
            payload: prescription
          }),
          headers: {
            'content-type': 'application/json',
            'event-source': 'medication-service',
            'event-type': 'medication.prescription.created'
          }
        }
      ]
    });
  } catch (error) {
    console.error('Failed to publish prescription event', error);
    throw error;
  }
}
```

**Consumer Side:**
```typescript
// Multiple independent consumers can subscribe to the same topic
const kafka = new Kafka({
  clientId: 'pharmacy-service',
  brokers: ['event-broker.cmm.internal:9092'],
  // Auth configuration
});

const consumer = kafka.consumer({ groupId: 'pharmacy-prescription-processor' });
await consumer.connect();
await consumer.subscribe({ topic: 'medication.prescription.created', fromBeginning: false });

await consumer.run({
  eachMessage: async ({ topic, partition, message }) => {
    try {
      const event = JSON.parse(message.value.toString());
      const prescription = event.payload;
      
      // Process the prescription
      await processPrescriptionForPharmacy(prescription);
      
    } catch (error) {
      console.error('Error processing prescription event', error);
      // Implement error handling strategy
    }
  }
});
```

### Event Sourcing Pattern

A pattern where all changes to application state are stored as a sequence of events, which can be replayed to reconstruct the state at any point in time.

#### When to Use
- Auditing and compliance requirements
- Building materialized views or projections
- Rebuilding state after system failures
- Implementing time-based analytics or reporting

#### Implementation

**Event Store:**
```typescript
import { Kafka } from 'kafkajs';
import { SchemaRegistry } from '@kafkajs/confluent-schema-registry';

const kafka = new Kafka({
  clientId: 'patient-service',
  brokers: ['event-broker.cmm.internal:9092'],
  // Auth configuration
});

const producer = kafka.producer();
const registry = new SchemaRegistry({ host: 'https://schema-registry.cmm.internal' });

async function appendToEventStream(patientId, event) {
  await producer.connect();
  
  // Get the latest schema ID for this event type
  const schemaId = await registry.getLatestSchemaId(`patient-events-value`);
  
  // Prepare the event with standard envelope
  const eventEnvelope = {
    metadata: {
      eventId: uuidv4(),
      eventType: event.type,
      eventSource: 'patient-service',
      correlationId: getCorrelationId(),
      timestamp: Date.now(),
      version: '1.0.0'
    },
    payload: event.data
  };
  
  // Encode the event with Avro schema
  const encodedValue = await registry.encode(schemaId, eventEnvelope);
  
  // Append to the patient's event stream
  await producer.send({
    topic: 'patient.events',
    messages: [
      {
        key: patientId,                  // Patient ID as the key ensures ordered events
        value: encodedValue,
        headers: {
          'event-type': event.type,
          'aggregate-id': patientId
        }
      }
    ]
  });
}

// Example usage
await appendToEventStream('patient-12345', {
  type: 'patient.profile.created',
  data: {
    firstName: 'John',
    lastName: 'Doe',
    dateOfBirth: '1980-01-01',
    gender: 'male',
    // Other patient data
  }
});

await appendToEventStream('patient-12345', {
  type: 'patient.address.updated',
  data: {
    street: '123 Main St',
    city: 'Columbus',
    state: 'OH',
    postalCode: '43215'
  }
});
```

**Event Stream Processor:**
```typescript
const consumer = kafka.consumer({ groupId: 'patient-view-builder' });
await consumer.connect();
await consumer.subscribe({ topic: 'patient.events', fromBeginning: true });

// In-memory store for patient state (use a database in production)
const patientStore = new Map();

await consumer.run({
  eachMessage: async ({ topic, partition, message }) => {
    try {
      // Decode the Avro message
      const event = await registry.decode(message.value);
      const patientId = message.key.toString();
      const eventType = event.metadata.eventType;
      
      // Get current patient state or initialize if not exists
      let patient = patientStore.get(patientId) || { id: patientId };
      
      // Apply the event to the patient state
      switch (eventType) {
        case 'patient.profile.created':
          patient = {
            ...patient,
            ...event.payload,
            createdAt: event.metadata.timestamp
          };
          break;
          
        case 'patient.address.updated':
          patient = {
            ...patient,
            address: event.payload,
            addressUpdatedAt: event.metadata.timestamp
          };
          break;
          
        // Handle other event types...
      }
      
      // Update the patient store with the new state
      patientStore.set(patientId, patient);
      
      // In a real implementation, you would persist to a database
      await savePatientToDatabase(patient);
      
    } catch (error) {
      console.error('Error processing patient event', error);
    }
  }
});
```

### Command-Query Responsibility Segregation (CQRS)

A pattern that separates read and write operations into different models, allowing for optimized data models and scaling strategies for each.

#### When to Use
- High-performance read requirements
- Complex domain models
- Separate scaling needs for reads and writes
- Need for specialized data views for different use cases

#### Implementation

**Command Side:**
```typescript
import { Kafka } from 'kafkajs';

const kafka = new Kafka({
  clientId: 'medication-command-service',
  brokers: ['event-broker.cmm.internal:9092'],
  // Auth configuration
});

const producer = kafka.producer();
await producer.connect();

// API endpoint handling a command
async function handleCreatePrescriptionCommand(req, res) {
  try {
    const command = req.body;
    
    // Validate the command
    validatePrescriptionCommand(command);
    
    // Generate a unique ID for the prescription
    const prescriptionId = uuidv4();
    
    // Send command to the command topic
    await producer.send({
      topic: 'medication.commands',
      messages: [
        {
          key: prescriptionId,
          value: JSON.stringify({
            commandId: uuidv4(),
            commandType: 'CreatePrescription',
            aggregateId: prescriptionId,
            timestamp: Date.now(),
            payload: command,
            userId: req.user.id
          })
        }
      ]
    });
    
    // Return success to the client
    res.status(202).json({
      message: 'Prescription command accepted',
      prescriptionId: prescriptionId
    });
    
  } catch (error) {
    console.error('Failed to process prescription command', error);
    res.status(400).json({ error: error.message });
  }
}
```

**Command Handler:**
```typescript
const commandConsumer = kafka.consumer({ groupId: 'medication-command-handler' });
await commandConsumer.connect();
await commandConsumer.subscribe({ topic: 'medication.commands', fromBeginning: false });

// Process commands and emit events
await commandConsumer.run({
  eachMessage: async ({ topic, partition, message }) => {
    try {
      const command = JSON.parse(message.value.toString());
      
      // Handle the command based on its type
      if (command.commandType === 'CreatePrescription') {
        // Apply business logic and validation
        const prescription = buildPrescription(command.payload);
        
        // Save to write model database
        await savePrescription(prescription);
        
        // Emit domain event for the read model to consume
        await producer.send({
          topic: 'medication.events',
          messages: [
            {
              key: command.aggregateId,
              value: JSON.stringify({
                eventId: uuidv4(),
                eventType: 'PrescriptionCreated',
                aggregateId: command.aggregateId,
                timestamp: Date.now(),
                payload: prescription,
                commandId: command.commandId
              })
            }
          ]
        });
      }
      
      // Handle other command types...
      
    } catch (error) {
      console.error('Error processing command', error);
      // Implement error handling strategy
    }
  }
});
```

**Query Side:**
```typescript
// Event consumer that builds the read model
const eventConsumer = kafka.consumer({ groupId: 'medication-read-model-builder' });
await eventConsumer.connect();
await eventConsumer.subscribe({ topic: 'medication.events', fromBeginning: true });

await eventConsumer.run({
  eachMessage: async ({ topic, partition, message }) => {
    try {
      const event = JSON.parse(message.value.toString());
      
      // Update read models based on event type
      if (event.eventType === 'PrescriptionCreated') {
        // Transform for read model
        const prescriptionView = transformForReadModel(event.payload);
        
        // Save to read database (optimized for queries)
        await saveToReadModel(prescriptionView);
      }
      
      // Handle other event types...
      
    } catch (error) {
      console.error('Error updating read model', error);
    }
  }
});

// Query API endpoint
async function handleGetPrescriptions(req, res) {
  try {
    // Query from the read model
    const { patientId, status } = req.query;
    const prescriptions = await queryReadModel({ patientId, status });
    
    res.json(prescriptions);
  } catch (error) {
    console.error('Failed to query prescriptions', error);
    res.status(500).json({ error: 'Failed to retrieve prescriptions' });
  }
}
```

### Saga Pattern

A sequence of local transactions coordinated through events, where each participant performs its part and publishes an event to trigger the next step.

#### When to Use
- Implementing distributed transactions
- Coordinating complex workflows across services
- Managing compensation actions for failure recovery
- Ensuring data consistency across microservices

#### Implementation

**Orchestrated Saga:**
```typescript
import { Kafka } from 'kafkajs';

const kafka = new Kafka({
  clientId: 'prior-auth-saga-orchestrator',
  brokers: ['event-broker.cmm.internal:9092'],
  // Auth configuration
});

const producer = kafka.producer();
const consumer = kafka.consumer({ groupId: 'prior-auth-saga-orchestrator' });

// Initialize saga orchestrator
async function initializeSagaOrchestrator() {
  await producer.connect();
  await consumer.connect();
  
  // Subscribe to relevant event topics
  await consumer.subscribe({ topics: [
    'priorauth.saga.started',
    'priorauth.prescription.validated',
    'priorauth.insurance.verified',
    'priorauth.form.generated',
    'priorauth.submission.completed',
    'priorauth.saga.compensation'
  ]});
  
  // Saga state store (use a persistent store in production)
  const sagaStateStore = new Map();
  
  await consumer.run({
    eachMessage: async ({ topic, partition, message }) => {
      try {
        const event = JSON.parse(message.value.toString());
        const sagaId = event.sagaId;
        
        // Retrieve or initialize saga state
        let sagaState = sagaStateStore.get(sagaId) || {
          sagaId,
          status: 'STARTED',
          steps: [],
          compensatingActions: [],
          payload: {}
        };
        
        // Update saga state based on event type
        switch (event.eventType) {
          case 'priorauth.saga.started':
            sagaState = {
              ...sagaState,
              status: 'IN_PROGRESS',
              payload: event.payload,
              startTime: Date.now()
            };
            
            // Initiate first step
            await producer.send({
              topic: 'priorauth.command.validate-prescription',
              messages: [{
                key: sagaId,
                value: JSON.stringify({
                  commandId: uuidv4(),
                  sagaId: sagaId,
                  prescriptionId: event.payload.prescriptionId
                })
              }]
            });
            break;
            
          case 'priorauth.prescription.validated':
            // Record step completion
            sagaState.steps.push({
              step: 'PRESCRIPTION_VALIDATION',
              status: 'COMPLETED',
              timestamp: Date.now()
            });
            
            // Register compensating action
            sagaState.compensatingActions.push({
              step: 'PRESCRIPTION_VALIDATION',
              action: 'UNLOCK_PRESCRIPTION',
              data: { prescriptionId: event.payload.prescriptionId }
            });
            
            // Trigger next step
            await producer.send({
              topic: 'priorauth.command.verify-insurance',
              messages: [{
                key: sagaId,
                value: JSON.stringify({
                  commandId: uuidv4(),
                  sagaId: sagaId,
                  patientId: event.payload.patientId,
                  payerId: event.payload.payerId
                })
              }]
            });
            break;
            
          case 'priorauth.insurance.verified':
            // Record step completion
            sagaState.steps.push({
              step: 'INSURANCE_VERIFICATION',
              status: 'COMPLETED',
              timestamp: Date.now()
            });
            
            // Register compensating action
            sagaState.compensatingActions.push({
              step: 'INSURANCE_VERIFICATION',
              action: 'RELEASE_ELIGIBILITY_CHECK',
              data: { eligibilityCheckId: event.payload.eligibilityCheckId }
            });
            
            // Trigger next step
            await producer.send({
              topic: 'priorauth.command.generate-form',
              messages: [{
                key: sagaId,
                value: JSON.stringify({
                  commandId: uuidv4(),
                  sagaId: sagaId,
                  prescriptionId: event.payload.prescriptionId,
                  payerId: event.payload.payerId,
                  formType: event.payload.formType
                })
              }]
            });
            break;
            
          // Handle additional steps...
            
          case 'priorauth.submission.completed':
            // Complete the saga
            sagaState.steps.push({
              step: 'SUBMISSION',
              status: 'COMPLETED',
              timestamp: Date.now()
            });
            
            sagaState.status = 'COMPLETED';
            sagaState.endTime = Date.now();
            
            // Publish saga completion event
            await producer.send({
              topic: 'priorauth.saga.completed',
              messages: [{
                key: sagaId,
                value: JSON.stringify({
                  sagaId: sagaId,
                  status: 'COMPLETED',
                  result: event.payload
                })
              }]
            });
            break;
            
          case 'priorauth.saga.compensation':
            // Handle saga failure and execute compensation
            sagaState.status = 'COMPENSATING';
            
            // Execute compensating actions in reverse order
            for (const action of [...sagaState.compensatingActions].reverse()) {
              await executeCompensatingAction(action);
            }
            
            sagaState.status = 'COMPENSATED';
            sagaState.endTime = Date.now();
            
            // Publish saga compensation event
            await producer.send({
              topic: 'priorauth.saga.compensated',
              messages: [{
                key: sagaId,
                value: JSON.stringify({
                  sagaId: sagaId,
                  status: 'COMPENSATED',
                  error: event.error
                })
              }]
            });
            break;
        }
        
        // Save updated saga state
        sagaStateStore.set(sagaId, sagaState);
        
      } catch (error) {
        console.error('Error in saga orchestration', error);
        // Implement error handling and compensation
      }
    }
  });
}

// Function to execute compensating actions
async function executeCompensatingAction(action) {
  try {
    switch (action.action) {
      case 'UNLOCK_PRESCRIPTION':
        await producer.send({
          topic: 'priorauth.command.unlock-prescription',
          messages: [{
            key: action.data.prescriptionId,
            value: JSON.stringify({
              commandId: uuidv4(),
              prescriptionId: action.data.prescriptionId
            })
          }]
        });
        break;
        
      // Handle other compensating actions...
    }
  } catch (error) {
    console.error(`Failed to execute compensating action ${action.action}`, error);
  }
}
```

### Dead Letter Queue Pattern

A pattern for handling failed message processing by moving problematic messages to a separate topic for later analysis and reprocessing.

#### When to Use
- Managing unprocessable messages
- Implementing retry mechanisms
- Analyzing message processing failures
- Preventing poison messages from blocking consumer progress

#### Implementation

```typescript
import { Kafka } from 'kafkajs';

const kafka = new Kafka({
  clientId: 'pharmacy-service',
  brokers: ['event-broker.cmm.internal:9092'],
  // Auth configuration
});

const consumer = kafka.consumer({ groupId: 'pharmacy-prescription-processor' });
const producer = kafka.producer();

await consumer.connect();
await producer.connect();
await consumer.subscribe({ topic: 'medication.prescription.created', fromBeginning: false });

// Consumer with DLQ handling
await consumer.run({
  eachMessage: async ({ topic, partition, message }) => {
    try {
      const event = JSON.parse(message.value.toString());
      const prescription = event.payload;
      
      // Process the prescription
      await processPrescriptionForPharmacy(prescription);
      
    } catch (error) {
      console.error('Error processing prescription event', error);
      
      // Send to Dead Letter Queue
      await sendToDLQ({
        topic,
        partition,
        message,
        error
      });
    }
  }
});

// Function to send messages to DLQ
async function sendToDLQ({ topic, partition, message, error }) {
  const dlqTopic = `${topic}.dlq`;
  
  await producer.send({
    topic: dlqTopic,
    messages: [
      {
        key: message.key,
        value: message.value,
        headers: {
          ...message.headers,
          'original-topic': Buffer.from(topic),
          'original-partition': Buffer.from(String(partition)),
          'original-offset': Buffer.from(String(message.offset)),
          'error-message': Buffer.from(error.message),
          'error-stack': Buffer.from(error.stack || ''),
          'timestamp': Buffer.from(String(Date.now()))
        }
      }
    ]
  });
  
  console.log(`Message sent to DLQ: ${dlqTopic}`);
}

// DLQ processor for manual review and reprocessing
const dlqConsumer = kafka.consumer({ groupId: 'dlq-analyzer' });
await dlqConsumer.connect();
await dlqConsumer.subscribe({ topics: [
  'medication.prescription.created.dlq',
  'medication.prescription.updated.dlq'
]});

await dlqConsumer.run({
  eachMessage: async ({ topic, partition, message }) => {
    // Extract original message information
    const originalTopic = message.headers['original-topic']?.toString();
    const errorMessage = message.headers['error-message']?.toString();
    
    // Log DLQ entry for analysis
    console.log(`DLQ Entry: ${originalTopic}, Error: ${errorMessage}`);
    
    // Store in database for manual review
    await storeDLQMessageForReview({
      originalTopic,
      errorMessage,
      messageKey: message.key.toString(),
      messageValue: message.value.toString(),
      timestamp: message.headers['timestamp']?.toString()
    });
  }
});

// Function to reprocess messages from DLQ
async function reprocessDLQMessages(dlqTopic, filter = {}) {
  // Fetch messages from DLQ storage based on filter
  const dlqMessages = await fetchDLQMessagesForReprocessing(dlqTopic, filter);
  
  // Reprocess each message by sending back to original topic
  for (const msg of dlqMessages) {
    const originalTopic = msg.originalTopic;
    
    await producer.send({
      topic: originalTopic,
      messages: [
        {
          key: Buffer.from(msg.messageKey),
          value: Buffer.from(msg.messageValue),
          headers: {
            'reprocessed': Buffer.from('true'),
            'original-error': Buffer.from(msg.errorMessage),
            'reprocess-timestamp': Buffer.from(String(Date.now()))
          }
        }
      ]
    });
    
    // Mark as reprocessed in DLQ storage
    await markDLQMessageAsReprocessed(msg.id);
    
    console.log(`Reprocessed message ${msg.id} to ${originalTopic}`);
  }
}
```

## Healthcare-Specific Message Patterns

### FHIR Resource Change Events

A pattern for publishing standardized events when FHIR resources are created, updated, or deleted.

#### When to Use
- Integrating with the FHIR Interoperability Platform
- Building FHIR resource projections
- Implementing FHIR Subscription functionality
- Maintaining synchronized FHIR data across systems

#### Implementation

```typescript
import { Kafka } from 'kafkajs';
import { SchemaRegistry } from '@kafkajs/confluent-schema-registry';

const kafka = new Kafka({
  clientId: 'fhir-platform',
  brokers: ['event-broker.cmm.internal:9092'],
  // Auth configuration
});

const producer = kafka.producer();
const registry = new SchemaRegistry({ host: 'https://schema-registry.cmm.internal' });

// Function to publish FHIR resource change events
async function publishFhirResourceChange(resourceType, resourceId, operation, resource, request) {
  await producer.connect();
  
  // Get schema ID for this resource type
  const schemaId = await registry.getLatestSchemaId(`fhir-${resourceType.toLowerCase()}-events-value`);
  
  // Determine correlation context
  const correlationId = request.headers['x-correlation-id'] || uuidv4();
  
  // Create event with standard envelope
  const event = {
    metadata: {
      eventId: uuidv4(),
      eventType: `fhir.${resourceType}.${operation}`,
      eventSource: 'fhir-platform',
      correlationId: correlationId,
      causationId: request.requestId,
      timestamp: Date.now(),
      version: '1.0.0',
      security: {
        principal: request.user?.id || 'system',
        claims: {
          scope: request.user?.scope || '',
          tenant: request.tenant || 'default'
        }
      }
    },
    payload: resource
  };
  
  // Encode with Avro schema
  const encodedValue = await registry.encode(schemaId, event);
  
  // Send to appropriate topic
  await producer.send({
    topic: `fhir.${resourceType.toLowerCase()}`,
    messages: [
      {
        key: resourceId,
        value: encodedValue,
        headers: {
          'resource-type': resourceType,
          'operation': operation,
          'correlation-id': correlationId
        }
      }
    ]
  });
  
  console.log(`Published FHIR ${resourceType} ${operation} event for ${resourceId}`);
}

// Example usage in FHIR server hooks
async function onPatientCreate(request, resource) {
  // Process the create operation
  const savedResource = await saveFhirResource('Patient', resource);
  
  // Publish the change event
  await publishFhirResourceChange(
    'Patient',
    savedResource.id,
    'create',
    savedResource,
    request
  );
  
  return savedResource;
}

async function onMedicationRequestUpdate(request, resourceId, resource) {
  // Process the update operation
  const savedResource = await updateFhirResource('MedicationRequest', resourceId, resource);
  
  // Publish the change event
  await publishFhirResourceChange(
    'MedicationRequest',
    resourceId,
    'update',
    savedResource,
    request
  );
  
  return savedResource;
}
```

### Prior Authorization Workflow Events

A pattern for coordinating the complex steps in healthcare prior authorization workflows across multiple services.

#### When to Use
- Implementing prior authorization processes
- Tracking authorization status across systems
- Coordinating between providers, payers, and pharmacies
- Supporting visibility into authorization progress

#### Implementation

```typescript
import { Kafka } from 'kafkajs';
import { SchemaRegistry } from '@kafkajs/confluent-schema-registry';

const kafka = new Kafka({
  clientId: 'prior-auth-service',
  brokers: ['event-broker.cmm.internal:9092'],
  // Auth configuration
});

const producer = kafka.producer();
const registry = new SchemaRegistry({ host: 'https://schema-registry.cmm.internal' });

// Function to publish PA status change events
async function publishPriorAuthStatusChange(priorAuthId, status, details, context) {
  await producer.connect();
  
  // Get schema ID
  const schemaId = await registry.getLatestSchemaId('prior-auth-status-events-value');
  
  // Format the event
  const event = {
    metadata: {
      eventId: uuidv4(),
      eventType: `priorauth.status.${status.toLowerCase()}`,
      eventSource: 'prior-auth-service',
      correlationId: context.correlationId || uuidv4(),
      timestamp: Date.now(),
      version: '1.0.0',
      security: {
        principal: context.userId || 'system',
        tenant: context.tenantId || 'default'
      }
    },
    payload: {
      priorAuthId,
      status,
      previousStatus: details.previousStatus,
      statusReason: details.statusReason,
      statusTimestamp: Date.now(),
      payerId: details.payerId,
      prescriptionId: details.prescriptionId,
      patientId: details.patientId,
      providerId: details.providerId,
      drugInfo: details.drugInfo,
      formId: details.formId,
      notes: details.notes,
      externalReferences: details.externalReferences
    }
  };
  
  // Encode with Avro schema
  const encodedValue = await registry.encode(schemaId, event);
  
  // Send to status topic
  await producer.send({
    topic: 'workflow.priorauth.status',
    messages: [
      {
        key: priorAuthId,
        value: encodedValue,
        headers: {
          'pa-status': status,
          'payer-id': details.payerId,
          'correlation-id': context.correlationId || ''
        }
      }
    ]
  });
  
  console.log(`Published prior auth status change to ${status} for ${priorAuthId}`);
}

// Example usage in a prior auth service
async function submitPriorAuth(priorAuthData, context) {
  try {
    // Generate ID for new prior auth
    const priorAuthId = uuidv4();
    
    // Save initial record
    const priorAuth = await createPriorAuthRecord({
      id: priorAuthId,
      status: 'INITIATED',
      ...priorAuthData
    });
    
    // Publish status change event
    await publishPriorAuthStatusChange(
      priorAuthId,
      'INITIATED',
      {
        previousStatus: null,
        statusReason: 'Initial submission',
        ...priorAuthData
      },
      context
    );
    
    // Start the submission process asynchronously
    startSubmissionProcess(priorAuthId, priorAuthData, context);
    
    return {
      priorAuthId,
      status: 'INITIATED',
      message: 'Prior authorization initiated successfully'
    };
  } catch (error) {
    console.error('Error initiating prior authorization', error);
    throw error;
  }
}

// Consumer for monitoring PA status changes
const consumer = kafka.consumer({ groupId: 'provider-portal-pa-monitor' });
await consumer.connect();
await consumer.subscribe({ topic: 'workflow.priorauth.status', fromBeginning: false });

await consumer.run({
  eachMessage: async ({ topic, partition, message }) => {
    try {
      // Decode the Avro message
      const event = await registry.decode(message.value);
      const priorAuthId = message.key.toString();
      const status = event.payload.status;
      
      console.log(`Processing PA status change to ${status} for ${priorAuthId}`);
      
      // Update provider portal with new status
      await updateProviderPortalPAStatus(
        priorAuthId,
        status,
        event.payload
      );
      
      // Send notifications if needed
      if (['APPROVED', 'DENIED', 'ADDITIONAL_INFO_REQUIRED'].includes(status)) {
        await sendProviderNotification(
          event.payload.providerId,
          `Prior Authorization ${priorAuthId} status: ${status}`,
          event.payload
        );
      }
      
    } catch (error) {
      console.error('Error processing prior auth status event', error);
    }
  }
});
```

### Patient Consent Events

A pattern for tracking and enforcing patient consent preferences across healthcare systems.

#### When to Use
- Managing patient privacy preferences
- Enforcing consent-based access controls
- Implementing GDPR or HIPAA consent requirements
- Enabling patient-directed sharing of health information

#### Implementation

```typescript
import { Kafka } from 'kafkajs';
import { SchemaRegistry } from '@kafkajs/confluent-schema-registry';

const kafka = new Kafka({
  clientId: 'consent-management-service',
  brokers: ['event-broker.cmm.internal:9092'],
  // Auth configuration
});

const producer = kafka.producer();
const registry = new SchemaRegistry({ host: 'https://schema-registry.cmm.internal' });

// Function to publish consent change events
async function publishConsentChange(patientId, consentId, action, consentData, context) {
  await producer.connect();
  
  // Get schema ID
  const schemaId = await registry.getLatestSchemaId('patient-consent-events-value');
  
  // Format the event
  const event = {
    metadata: {
      eventId: uuidv4(),
      eventType: `patient.consent.${action}`,
      eventSource: 'consent-management-service',
      correlationId: context.correlationId || uuidv4(),
      timestamp: Date.now(),
      version: '1.0.0'
    },
    payload: {
      consentId,
      patientId,
      action,
      consentType: consentData.consentType,
      scope: consentData.scope,
      grantedTo: consentData.grantedTo,
      purpose: consentData.purpose,
      effectiveFrom: consentData.effectiveFrom,
      effectiveUntil: consentData.effectiveUntil,
      dataCategories: consentData.dataCategories,
      evidenceDocumentId: consentData.evidenceDocumentId,
      attestedBy: consentData.attestedBy,
      attestedAt: consentData.attestedAt,
      policyReference: consentData.policyReference
    }
  };
  
  // Encode with Avro schema
  const encodedValue = await registry.encode(schemaId, event);
  
  // Send to consent topic
  await producer.send({
    topic: 'patient.consent',
    messages: [
      {
        key: patientId,
        value: encodedValue,
        headers: {
          'consent-id': consentId,
          'consent-action': action,
          'consent-type': consentData.consentType
        }
      }
    ]
  });
  
  console.log(`Published consent ${action} event for patient ${patientId}`);
}

// Example usage in a consent management service
async function recordPatientConsent(patientId, consentData, context) {
  try {
    // Generate ID for new consent record
    const consentId = uuidv4();
    
    // Save consent record
    const consent = await createConsentRecord({
      id: consentId,
      patientId,
      ...consentData,
      recordedAt: new Date(),
      updatedAt: new Date()
    });
    
    // Publish consent granted event
    await publishConsentChange(
      patientId,
      consentId,
      'granted',
      consent,
      context
    );
    
    return {
      consentId,
      status: 'RECORDED',
      message: 'Consent successfully recorded'
    };
  } catch (error) {
    console.error('Error recording patient consent', error);
    throw error;
  }
}

// Consumer for enforcing consent policies
const consumer = kafka.consumer({ groupId: 'data-access-consent-enforcer' });
await consumer.connect();
await consumer.subscribe({ topic: 'patient.consent', fromBeginning: true });

// In-memory consent store (use a database in production)
const consentStore = new Map();

await consumer.run({
  eachMessage: async ({ topic, partition, message }) => {
    try {
      // Decode the Avro message
      const event = await registry.decode(message.value);
      const patientId = message.key.toString();
      const action = event.payload.action;
      const consentId = event.payload.consentId;
      
      // Get current consents for patient or initialize if not exists
      let patientConsents = consentStore.get(patientId) || [];
      
      // Update consent based on action
      switch (action) {
        case 'granted':
          // Add or update consent
          patientConsents = patientConsents.filter(c => c.consentId !== consentId);
          patientConsents.push({
            consentId,
            consentType: event.payload.consentType,
            scope: event.payload.scope,
            grantedTo: event.payload.grantedTo,
            purpose: event.payload.purpose,
            dataCategories: event.payload.dataCategories,
            effectiveFrom: event.payload.effectiveFrom,
            effectiveUntil: event.payload.effectiveUntil,
            active: true
          });
          break;
          
        case 'revoked':
          // Mark consent as inactive
          patientConsents = patientConsents.map(c => {
            if (c.consentId === consentId) {
              return { ...c, active: false };
            }
            return c;
          });
          break;
          
        case 'expired':
          // Mark consent as inactive
          patientConsents = patientConsents.map(c => {
            if (c.consentId === consentId) {
              return { ...c, active: false };
            }
            return c;
          });
          break;
      }
      
      // Update consent store
      consentStore.set(patientId, patientConsents);
      
      // In a real implementation, update a database
      await updateConsentDatabase(patientId, patientConsents);
      
    } catch (error) {
      console.error('Error processing consent event', error);
    }
  }
});

// Function to check if access is allowed based on consent
async function checkConsentForAccess(patientId, requester, purpose, dataCategory) {
  // Get patient's active consents
  const patientConsents = await getActiveConsents(patientId);
  
  // Check if there's a matching consent
  const hasConsent = patientConsents.some(consent => {
    // Check if consent is active and not expired
    const now = new Date();
    const isActive = consent.active &&
                    new Date(consent.effectiveFrom) <= now &&
                    (!consent.effectiveUntil || new Date(consent.effectiveUntil) > now);
    
    if (!isActive) return false;
    
    // Check if requester matches
    const requesterMatches = consent.grantedTo.some(grantee => {
      if (grantee.type === 'organization') {
        return grantee.id === requester.organizationId;
      } else if (grantee.type === 'role') {
        return requester.roles.includes(grantee.id);
      } else if (grantee.type === 'user') {
        return grantee.id === requester.userId;
      }
      return false;
    });
    
    if (!requesterMatches) return false;
    
    // Check if purpose matches
    const purposeMatches = consent.purpose.includes(purpose);
    if (!purposeMatches) return false;
    
    // Check if data category matches
    const dataCategoryMatches = consent.dataCategories.includes(dataCategory);
    
    return dataCategoryMatches;
  });
  
  return hasConsent;
}
```

## Related Resources
- [Event Broker Overview](../01-getting-started/overview.md)
- [Event Broker Key Concepts](../01-getting-started/key-concepts.md)
- [Core APIs](./core-apis.md)
- [Topic Management](./topic-management.md)
- [Schema Registry Management](../04-governance-compliance/schema-registry-management.md)
- [Event-Driven Architecture Patterns](https://www.enterpriseintegrationpatterns.com/)
- [Confluent Kafka Design Patterns](https://www.confluent.io/blog/event-driven-architecture-patterns/)