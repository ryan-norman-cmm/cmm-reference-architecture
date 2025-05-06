# Event Broker Advanced Use Cases

## Introduction
This document outlines advanced use cases and patterns for the Event Broker component. These scenarios demonstrate how to leverage the Event Broker for complex healthcare workflows, data processing, and system integration. The examples include detailed workflows and TypeScript code samples that follow best practices for production deployments.

## Use Case 1: Real-time Clinical Alerts Pipeline

### Scenario Description
A real-time alerting system that processes clinical observations from multiple sources to identify critical patient conditions that require immediate attention. The pipeline processes thousands of observations per second, applies complex rules, and delivers time-sensitive alerts to clinical staff.

### Workflow Steps
1. FHIR Platform publishes clinical observations to the Event Broker
2. Stream processor analyzes observations in real-time
3. Alerting conditions are detected based on configurable rules
4. Alerts are enriched with patient context
5. Notifications are delivered to clinicians through multiple channels

### Implementation Example

```typescript
import { Kafka } from 'kafkajs';
import { SchemaRegistry } from '@kafkajs/confluent-schema-registry';
import { KafkaStreams, KStream } from 'kafka-streams';

// Initialize Kafka client
const kafka = new Kafka({
  clientId: 'clinical-alerts-processor',
  brokers: ['event-broker.cmm.internal:9092'],
  ssl: true,
  sasl: {
    mechanism: 'plain',
    username: process.env.KAFKA_USERNAME,
    password: process.env.KAFKA_PASSWORD
  },
});

// Initialize Schema Registry client
const registry = new SchemaRegistry({
  host: 'https://schema-registry.cmm.internal',
  auth: {
    username: process.env.SCHEMA_REGISTRY_USERNAME,
    password: process.env.SCHEMA_REGISTRY_PASSWORD,
  },
});

// Initialize the Kafka Streams client
const kafkaStreams = new KafkaStreams({
  'noptions.metadata.broker.list': 'event-broker.cmm.internal:9092',
  'security.protocol': 'sasl_ssl',
  'sasl.mechanisms': 'PLAIN',
  'sasl.username': process.env.KAFKA_USERNAME,
  'sasl.password': process.env.KAFKA_PASSWORD,
  'ssl.ca.location': process.env.SSL_CA_LOCATION,
  'group.id': 'clinical-alerts-stream-processor',
  'client.id': 'clinical-alerts-stream-processor',
});

// Define alert rules
type AlertRule = {
  code: string;
  system: string;
  comparator: 'gt' | 'lt' | 'eq' | 'ne' | 'ge' | 'le';
  threshold: number;
  severity: 'critical' | 'high' | 'medium' | 'low';
  description: string;
};

const alertRules: AlertRule[] = [
  {
    code: '8867-4', // Heart rate
    system: 'http://loinc.org',
    comparator: 'gt',
    threshold: 120, // HR > 120 bpm
    severity: 'high',
    description: 'Elevated heart rate'
  },
  {
    code: '8480-6', // Systolic BP
    system: 'http://loinc.org',
    comparator: 'gt',
    threshold: 180, // Systolic BP > 180 mmHg
    severity: 'high',
    description: 'Elevated blood pressure'
  },
  {
    code: '2339-0', // Blood Glucose
    system: 'http://loinc.org',
    comparator: 'lt',
    threshold: 70, // Blood Glucose < 70 mg/dL
    severity: 'high',
    description: 'Hypoglycemia'
  }
];

// Helper function to evaluate if an observation matches an alert rule
function evaluateObservation(observation: any, rule: AlertRule): boolean {
  // Ensure observation has the correct code
  const coding = observation.code?.coding?.find(
    (c: any) => c.code === rule.code && c.system === rule.system
  );
  
  if (!coding) return false;
  
  // Extract the value from the observation
  let value: number | null = null;
  
  if (observation.valueQuantity?.value !== undefined) {
    value = observation.valueQuantity.value;
  } else if (observation.valueInteger !== undefined) {
    value = observation.valueInteger;
  } else if (observation.valueDecimal !== undefined) {
    value = observation.valueDecimal;
  }
  
  if (value === null) return false;
  
  // Compare the value to the threshold
  switch (rule.comparator) {
    case 'gt': return value > rule.threshold;
    case 'lt': return value < rule.threshold;
    case 'eq': return value === rule.threshold;
    case 'ne': return value !== rule.threshold;
    case 'ge': return value >= rule.threshold;
    case 'le': return value <= rule.threshold;
    default: return false;
  }
}

// Create streams processor for observations
async function createObservationProcessor() {
  // Create a stream from the FHIR Observation topic
  const observationStream: KStream = kafkaStreams.getKStream('fhir.Observation');
  
  observationStream
    // Parse the observation message
    .map((message) => {
      try {
        const event = JSON.parse(message.value.toString());
        return {
          key: message.key.toString(),
          observation: event.payload,
          metadata: event.metadata
        };
      } catch (error) {
        console.error('Error parsing observation:', error);
        return null;
      }
    })
    // Filter out failed parses
    .filter((data) => data !== null)
    // Check each observation against alert rules
    .flatMap((data) => {
      const { observation, metadata } = data;
      const matchingRules = alertRules.filter(rule => 
        evaluateObservation(observation, rule)
      );
      
      // Map each matching rule to an alert
      return matchingRules.map(rule => ({
        alertId: `${observation.id}-${rule.code}-${Date.now()}`,
        patientId: observation.subject?.reference?.replace('Patient/', ''),
        observationId: observation.id,
        rule: rule.code,
        severity: rule.severity,
        description: rule.description,
        value: observation.valueQuantity?.value || observation.valueInteger || observation.valueDecimal,
        unit: observation.valueQuantity?.unit,
        timestamp: metadata.timestamp,
        correlationId: metadata.correlationId
      }));
    })
    // Filter out empty alert lists
    .filter((alerts) => alerts.length > 0)
    // Enrich alerts with patient data (in a real implementation, this would fetch from a patient service)
    .asyncMap(async (alert) => {
      try {
        // This would be an API call to get patient data
        const patientData = await fetchPatientData(alert.patientId);
        return {
          ...alert,
          patientName: `${patientData.name[0].given.join(' ')} ${patientData.name[0].family}`,
          patientMRN: patientData.identifier?.find(i => i.system === 'http://hospital.org/mrn')?.value,
          careTeam: patientData.careTeam
        };
      } catch (error) {
        console.error(`Error enriching alert with patient data: ${error.message}`);
        // Continue with the alert even if enrichment fails
        return alert;
      }
    })
    // Produce alerts to the alert topic
    .to('clinical.alerts');
  
  // Create a stream for the alerts to handle delivery
  const alertStream: KStream = kafkaStreams.getKStream('clinical.alerts');
  
  alertStream
    .map((message) => JSON.parse(message.value.toString()))
    .tap((alert) => {
      // Log all alerts
      console.log(`Clinical alert: ${alert.description} for patient ${alert.patientId}`);
      
      // Send high and critical alerts to notification systems
      if (['high', 'critical'].includes(alert.severity)) {
        // These would be calls to notification services
        sendMobileNotification(alert);
        sendEmailNotification(alert);
        
        if (alert.severity === 'critical') {
          // For critical alerts, also send SMS
          sendSMSNotification(alert);
        }
      }
    })
    // Produce to notification history topic for auditing and tracking
    .to('clinical.notifications.history');
  
  // Start the processing
  await observationStream.start();
  await alertStream.start();
  
  console.log('Clinical alerts pipeline started');
}

// Mock functions for notification delivery
async function sendMobileNotification(alert: any) {
  console.log(`Sending mobile notification for ${alert.alertId}`);
  // Implementation would call a mobile notification service
}

async function sendEmailNotification(alert: any) {
  console.log(`Sending email notification for ${alert.alertId}`);
  // Implementation would call an email service
}

async function sendSMSNotification(alert: any) {
  console.log(`Sending SMS notification for ${alert.alertId}`);
  // Implementation would call an SMS service
}

// Mock function for patient data fetching
async function fetchPatientData(patientId: string) {
  // In a real implementation, this would call the FHIR server
  return {
    id: patientId,
    name: [{
      given: ['John'],
      family: 'Doe'
    }],
    identifier: [
      {
        system: 'http://hospital.org/mrn',
        value: 'MRN12345'
      }
    ],
    careTeam: [
      {
        id: 'team1',
        name: 'Primary Care Team',
        members: [
          {
            role: 'primary',
            practitionerId: 'pract1',
            name: 'Dr. Smith'
          }
        ]
      }
    ]
  };
}

// Start the processor
createObservationProcessor().catch(console.error);
```

## Use Case 2: Medication Prior Authorization Orchestration

### Scenario Description
A complex workflow that orchestrates the prior authorization process for medications across multiple systems, including EHRs, pharmacy benefit managers, health plans, and pharmacy systems. The solution ensures reliable processing, tracks authorization status, and provides visibility into the entire process.

### Workflow Steps
1. EHR submits a medication prescription requiring prior authorization
2. Event-driven workflow initiates the prior authorization process
3. Required documentation is assembled from multiple sources
4. Submission to health plan occurs via appropriate channels
5. Status updates are tracked through approval or denial
6. Results are communicated to relevant stakeholders (provider, pharmacy, patient)

### Implementation Example

```typescript
import { Kafka, CompressionTypes, Partitioners } from 'kafkajs';
import { v4 as uuidv4 } from 'uuid';

// Initialize Kafka client
const kafka = new Kafka({
  clientId: 'prior-auth-orchestrator',
  brokers: ['event-broker.cmm.internal:9092'],
  ssl: true,
  sasl: {
    mechanism: 'plain',
    username: process.env.KAFKA_USERNAME,
    password: process.env.KAFKA_PASSWORD
  },
});

// Create producer and consumer
const producer = kafka.producer({
  createPartitioner: Partitioners.DefaultPartitioner,
  allowAutoTopicCreation: false,
  transactionTimeout: 30000,
  idempotent: true,
});

const consumer = kafka.consumer({
  groupId: 'prior-auth-orchestrator',
  sessionTimeout: 30000,
  heartbeatInterval: 3000,
});

// Initialize the orchestrator
async function initPriorAuthOrchestrator() {
  await producer.connect();
  await consumer.connect();
  
  // Subscribe to relevant topics
  await consumer.subscribe({ topics: [
    'medication.prescription.new',
    'priorauth.documentation.assembled',
    'priorauth.submission.completed',
    'priorauth.determination.received',
    'priorauth.communication.completed'
  ]});
  
  // Process messages
  await consumer.run({
    eachMessage: async ({ topic, partition, message }) => {
      try {
        const event = JSON.parse(message.value.toString());
        const correlationId = message.headers['correlation-id']?.toString() || uuidv4();
        
        // Handle different events based on topic
        switch (topic) {
          case 'medication.prescription.new':
            await handleNewPrescription(event, correlationId);
            break;
            
          case 'priorauth.documentation.assembled':
            await handleDocumentationAssembled(event, correlationId);
            break;
            
          case 'priorauth.submission.completed':
            await handleSubmissionCompleted(event, correlationId);
            break;
            
          case 'priorauth.determination.received':
            await handleDeterminationReceived(event, correlationId);
            break;
            
          case 'priorauth.communication.completed':
            await handleCommunicationCompleted(event, correlationId);
            break;
        }
      } catch (error) {
        console.error(`Error processing message from topic ${topic}:`, error);
        // In production, implement proper error handling, potentially with DLQ
      }
    }
  });
  
  console.log('Prior Authorization Orchestrator started');
}

// Handler for new prescriptions requiring prior authorization
async function handleNewPrescription(event: any, correlationId: string) {
  console.log(`Processing new prescription requiring PA: ${event.prescriptionId}`);
  
  // Extract prescription details
  const { prescriptionId, patientId, providerId, medication, payerId, pharmacyId } = event.payload;
  
  // Create a new prior auth record
  const priorAuthId = uuidv4();
  
  // Log the new prior auth
  console.log(`Created new prior auth record: ${priorAuthId} for prescription: ${prescriptionId}`);
  
  // Store the prior auth record in database (mock implementation)
  await storePriorAuthRecord({
    id: priorAuthId,
    prescriptionId,
    patientId,
    providerId,
    medication,
    payerId,
    pharmacyId,
    status: 'INITIATED',
    createDate: new Date().toISOString(),
    updateDate: new Date().toISOString(),
    statusHistory: [
      {
        status: 'INITIATED',
        timestamp: new Date().toISOString(),
        actor: 'prior-auth-orchestrator',
        reason: 'New prescription requires prior authorization'
      }
    ]
  });
  
  // Publish event to request documentation assembly
  await producer.send({
    topic: 'priorauth.documentation.requested',
    compression: CompressionTypes.GZIP,
    messages: [
      {
        key: priorAuthId,
        value: JSON.stringify({
          priorAuthId,
          prescriptionId,
          patientId,
          providerId,
          medication,
          payerId,
          requestedDocuments: [
            'patient-demographics',
            'diagnosis-codes',
            'medication-history',
            'lab-results',
            'provider-notes'
          ]
        }),
        headers: {
          'correlation-id': correlationId,
          'event-source': 'prior-auth-orchestrator',
          'event-type': 'priorauth.documentation.requested'
        }
      }
    ]
  });
  
  console.log(`Requested documentation assembly for prior auth: ${priorAuthId}`);
}

// Handler for when documentation has been assembled
async function handleDocumentationAssembled(event: any, correlationId: string) {
  const { priorAuthId, prescriptionId, documents } = event;
  
  console.log(`Documentation assembled for prior auth: ${priorAuthId}`);
  
  // Update the prior auth record
  await updatePriorAuthStatus(priorAuthId, 'DOCUMENTATION_ASSEMBLED', 'Documentation has been assembled');
  
  // Publish event to request submission
  await producer.send({
    topic: 'priorauth.submission.requested',
    compression: CompressionTypes.GZIP,
    messages: [
      {
        key: priorAuthId,
        value: JSON.stringify({
          priorAuthId,
          prescriptionId,
          documents,
          submissionMethod: determineSubmissionMethod(event.payerId),
          payerId: event.payerId,
          urgent: isUrgentMedication(event.medication)
        }),
        headers: {
          'correlation-id': correlationId,
          'event-source': 'prior-auth-orchestrator',
          'event-type': 'priorauth.submission.requested'
        }
      }
    ]
  });
  
  console.log(`Requested submission for prior auth: ${priorAuthId}`);
}

// Handler for when submission has been completed
async function handleSubmissionCompleted(event: any, correlationId: string) {
  const { priorAuthId, submissionId, submissionDate, submissionMethod, payerId } = event;
  
  console.log(`Submission completed for prior auth: ${priorAuthId}`);
  
  // Update the prior auth record
  await updatePriorAuthStatus(
    priorAuthId, 
    'SUBMITTED', 
    `Submitted via ${submissionMethod} with ID ${submissionId}`
  );
  
  // Store submission details
  await updatePriorAuthSubmission(priorAuthId, {
    submissionId,
    submissionDate,
    submissionMethod,
    payerId
  });
  
  // For electronic submissions, we can set up monitoring
  if (submissionMethod === 'ELECTRONIC') {
    // Set up a status check schedule
    await scheduleStatusCheck(priorAuthId, payerId, submissionId);
  }
  
  console.log(`Updated submission details for prior auth: ${priorAuthId}`);
}

// Handler for when a determination has been received
async function handleDeterminationReceived(event: any, correlationId: string) {
  const { priorAuthId, determinationStatus, determinationDate, determinationReason, expirationDate } = event;
  
  console.log(`Determination received for prior auth: ${priorAuthId}, status: ${determinationStatus}`);
  
  // Update the prior auth record
  await updatePriorAuthStatus(
    priorAuthId, 
    determinationStatus, 
    determinationReason || 'Determination received from payer'
  );
  
  // Store determination details
  await updatePriorAuthDetermination(priorAuthId, {
    determinationStatus,
    determinationDate,
    determinationReason,
    expirationDate
  });
  
  // Request communication of the determination
  await producer.send({
    topic: 'priorauth.communication.requested',
    compression: CompressionTypes.GZIP,
    messages: [
      {
        key: priorAuthId,
        value: JSON.stringify({
          priorAuthId,
          determinationStatus,
          recipients: ['PROVIDER', 'PHARMACY', 'PATIENT'],
          channels: ['EHR', 'PORTAL', 'EMAIL']
        }),
        headers: {
          'correlation-id': correlationId,
          'event-source': 'prior-auth-orchestrator',
          'event-type': 'priorauth.communication.requested'
        }
      }
    ]
  });
  
  console.log(`Requested communication of determination for prior auth: ${priorAuthId}`);
}

// Handler for when communication has been completed
async function handleCommunicationCompleted(event: any, correlationId: string) {
  const { priorAuthId, completedChannels } = event;
  
  console.log(`Communication completed for prior auth: ${priorAuthId}, channels: ${completedChannels.join(', ')}`);
  
  // Update the prior auth record
  await updatePriorAuthStatus(
    priorAuthId, 
    'DETERMINATION_COMMUNICATED', 
    `Communication completed via ${completedChannels.join(', ')}`
  );
  
  // Create workflow summary for analytics
  await producer.send({
    topic: 'priorauth.workflow.completed',
    compression: CompressionTypes.GZIP,
    messages: [
      {
        key: priorAuthId,
        value: JSON.stringify({
          priorAuthId,
          workflowSummary: await generateWorkflowSummary(priorAuthId)
        }),
        headers: {
          'correlation-id': correlationId,
          'event-source': 'prior-auth-orchestrator',
          'event-type': 'priorauth.workflow.completed'
        }
      }
    ]
  });
  
  console.log(`Prior auth workflow completed for: ${priorAuthId}`);
}

// Helper functions

// Mock function to store the prior auth record
async function storePriorAuthRecord(record: any) {
  // In a real implementation, this would store to a database
  console.log(`Storing prior auth record: ${record.id}`);
}

// Mock function to update prior auth status
async function updatePriorAuthStatus(priorAuthId: string, status: string, reason: string) {
  // In a real implementation, this would update a database record
  console.log(`Updating prior auth ${priorAuthId} status to ${status}: ${reason}`);
}

// Mock function to update submission details
async function updatePriorAuthSubmission(priorAuthId: string, details: any) {
  // In a real implementation, this would update a database record
  console.log(`Updating submission details for prior auth ${priorAuthId}`);
}

// Mock function to update determination details
async function updatePriorAuthDetermination(priorAuthId: string, details: any) {
  // In a real implementation, this would update a database record
  console.log(`Updating determination details for prior auth ${priorAuthId}`);
}

// Mock function to determine submission method based on payer
function determineSubmissionMethod(payerId: string) {
  // In a real implementation, this would look up the payer's preferred method
  const payerMethods: Record<string, string> = {
    'PAYER001': 'ELECTRONIC',
    'PAYER002': 'ELECTRONIC',
    'PAYER003': 'FAX',
    'PAYER004': 'PORTAL'
  };
  
  return payerMethods[payerId] || 'FAX';
}

// Mock function to check if medication is urgent
function isUrgentMedication(medication: any) {
  // In a real implementation, this would check the medication details
  const urgentCategories = ['antibiotic', 'anticoagulant', 'insulin'];
  return urgentCategories.some(category => 
    medication.category?.toLowerCase().includes(category)
  );
}

// Mock function to schedule status check
async function scheduleStatusCheck(priorAuthId: string, payerId: string, submissionId: string) {
  // In a real implementation, this might create a scheduled task
  console.log(`Scheduling status check for prior auth ${priorAuthId}`);
}

// Mock function to generate workflow summary
async function generateWorkflowSummary(priorAuthId: string) {
  // In a real implementation, this would retrieve all events and create a summary
  return {
    priorAuthId,
    totalDuration: '48 hours',
    steps: [
      { name: 'INITIATED', timestamp: '2023-08-01T10:00:00Z' },
      { name: 'DOCUMENTATION_ASSEMBLED', timestamp: '2023-08-01T11:30:00Z' },
      { name: 'SUBMITTED', timestamp: '2023-08-01T12:15:00Z' },
      { name: 'APPROVED', timestamp: '2023-08-03T09:45:00Z' },
      { name: 'DETERMINATION_COMMUNICATED', timestamp: '2023-08-03T10:30:00Z' }
    ]
  };
}

// Start the orchestrator
initPriorAuthOrchestrator().catch(console.error);
```

## Use Case 3: Healthcare Data Synchronization Pipeline

### Scenario Description
A robust data synchronization system that ensures consistent patient and clinical data across multiple healthcare systems, handling conflicts, ensuring data quality, and providing guaranteed delivery with exactly-once semantics.

### Workflow Steps
1. Source systems publish data change events to the Event Broker
2. Change data capture (CDC) processes transform proprietary formats to canonical models
3. Data quality validation ensures consistency and integrity
4. Conflict detection and resolution handles simultaneous updates
5. Target systems consume validated changes and apply updates
6. Reconciliation processes verify synchronization success

### Implementation Example

```typescript
import { Kafka, CompressionTypes, Partitioners } from 'kafkajs';
import { SchemaRegistry } from '@kafkajs/confluent-schema-registry';
import { v4 as uuidv4 } from 'uuid';

// Initialize Kafka client
const kafka = new Kafka({
  clientId: 'healthcare-data-sync',
  brokers: ['event-broker.cmm.internal:9092'],
  ssl: true,
  sasl: {
    mechanism: 'plain',
    username: process.env.KAFKA_USERNAME,
    password: process.env.KAFKA_PASSWORD
  },
});

// Initialize Schema Registry client
const registry = new SchemaRegistry({
  host: 'https://schema-registry.cmm.internal',
  auth: {
    username: process.env.SCHEMA_REGISTRY_USERNAME,
    password: process.env.SCHEMA_REGISTRY_PASSWORD,
  },
});

// Create producers and consumers
const producer = kafka.producer({
  createPartitioner: Partitioners.DefaultPartitioner,
  allowAutoTopicCreation: false,
  transactionTimeout: 30000,
  idempotent: true,
});

const cdcConsumer = kafka.consumer({
  groupId: 'healthcare-data-sync-cdc',
  sessionTimeout: 30000,
  heartbeatInterval: 3000,
});

const validationConsumer = kafka.consumer({
  groupId: 'healthcare-data-sync-validation',
  sessionTimeout: 30000,
  heartbeatInterval: 3000,
});

const reconciliationConsumer = kafka.consumer({
  groupId: 'healthcare-data-sync-reconciliation',
  sessionTimeout: 30000,
  heartbeatInterval: 3000,
});

// Initialize the data sync pipeline
async function initDataSyncPipeline() {
  await producer.connect();
  await cdcConsumer.connect();
  await validationConsumer.connect();
  await reconciliationConsumer.connect();
  
  // 1. CDC Process - Transform source data to canonical format
  await cdcConsumer.subscribe({ topics: [
    'source.ehr.patient',
    'source.ehr.encounter',
    'source.ehr.observation',
    'source.pharmacy.prescription'
  ]});
  
  await cdcConsumer.run({
    eachMessage: async ({ topic, partition, message }) => {
      try {
        const sourceSystem = topic.split('.')[1]; // e.g., 'ehr', 'pharmacy'
        const entityType = topic.split('.')[2];   // e.g., 'patient', 'prescription'
        const event = JSON.parse(message.value.toString());
        const correlationId = message.headers['correlation-id']?.toString() || uuidv4();
        
        // Transform to canonical format based on entity type
        const canonicalData = await transformToCanonicalFormat(sourceSystem, entityType, event);
        
        // Get the right schema ID for this entity type
        const schemaId = await registry.getLatestSchemaId(`canonical.${entityType}-value`);
        
        // Encode with the schema
        const encodedValue = await registry.encode(schemaId, {
          metadata: {
            eventId: uuidv4(),
            eventType: `canonical.${entityType}.change`,
            eventSource: `cdc-${sourceSystem}`,
            sourceSystem,
            correlationId,
            timestamp: Date.now()
          },
          payload: canonicalData
        });
        
        // Publish to the canonical topic
        await producer.send({
          topic: `canonical.${entityType}.change`,
          compression: CompressionTypes.GZIP,
          messages: [
            {
              key: canonicalData.id,
              value: encodedValue,
              headers: {
                'correlation-id': correlationId,
                'source-system': sourceSystem,
                'entity-type': entityType,
                'operation-type': event.operationType || 'upsert'
              }
            }
          ]
        });
        
        console.log(`Transformed ${sourceSystem}.${entityType} data for ${canonicalData.id} to canonical format`);
      } catch (error) {
        console.error(`Error processing CDC event from topic ${topic}:`, error);
        // Send to error handling topic for investigation
        await sendToErrorTopic('cdc-error', topic, message, error);
      }
    }
  });
  
  // 2. Data Validation Process
  await validationConsumer.subscribe({ topics: [
    'canonical.patient.change',
    'canonical.encounter.change',
    'canonical.observation.change',
    'canonical.prescription.change'
  ]});
  
  await validationConsumer.run({
    eachMessage: async ({ topic, partition, message }) => {
      try {
        const entityType = topic.split('.')[1]; // e.g., 'patient', 'prescription'
        const operationType = message.headers['operation-type']?.toString() || 'upsert';
        const correlationId = message.headers['correlation-id']?.toString() || uuidv4();
        
        // Decode the message
        const event = await registry.decode(message.value);
        const data = event.payload;
        
        // Validate the data
        const validationResult = await validateData(entityType, data);
        
        if (validationResult.valid) {
          // If valid, check for conflicts
          const conflicts = await detectConflicts(entityType, data);
          
          if (conflicts.length > 0) {
            // Resolve conflicts
            const resolvedData = await resolveConflicts(entityType, data, conflicts);
            
            // Encode resolved data
            const schemaId = await registry.getLatestSchemaId(`canonical.${entityType}-value`);
            const encodedValue = await registry.encode(schemaId, {
              metadata: {
                eventId: uuidv4(),
                eventType: `canonical.${entityType}.validated`,
                eventSource: 'data-validation',
                correlationId,
                timestamp: Date.now(),
                conflictResolution: true
              },
              payload: resolvedData
            });
            
            // Publish to validated topic
            await producer.send({
              topic: `canonical.${entityType}.validated`,
              compression: CompressionTypes.GZIP,
              messages: [
                {
                  key: resolvedData.id,
                  value: encodedValue,
                  headers: {
                    'correlation-id': correlationId,
                    'entity-type': entityType,
                    'operation-type': operationType,
                    'conflict-resolved': 'true'
                  }
                }
              ]
            });
            
            console.log(`Resolved conflicts for ${entityType} ${resolvedData.id} and published to validated topic`);
          } else {
            // No conflicts, publish as is
            const schemaId = await registry.getLatestSchemaId(`canonical.${entityType}-value`);
            const encodedValue = await registry.encode(schemaId, {
              metadata: {
                eventId: uuidv4(),
                eventType: `canonical.${entityType}.validated`,
                eventSource: 'data-validation',
                correlationId,
                timestamp: Date.now(),
                conflictResolution: false
              },
              payload: data
            });
            
            // Publish to validated topic
            await producer.send({
              topic: `canonical.${entityType}.validated`,
              compression: CompressionTypes.GZIP,
              messages: [
                {
                  key: data.id,
                  value: encodedValue,
                  headers: {
                    'correlation-id': correlationId,
                    'entity-type': entityType,
                    'operation-type': operationType,
                    'conflict-resolved': 'false'
                  }
                }
              ]
            });
            
            console.log(`Validated ${entityType} ${data.id} and published to validated topic`);
          }
        } else {
          // If invalid, send to error topic
          console.error(`Validation failed for ${entityType} ${data.id}:`, validationResult.errors);
          await sendToErrorTopic('validation-error', topic, message, new Error(`Validation failed: ${validationResult.errors.join(', ')}`));
        }
      } catch (error) {
        console.error(`Error processing validation for topic ${topic}:`, error);
        // Send to error handling topic for investigation
        await sendToErrorTopic('validation-error', topic, message, error);
      }
    }
  });
  
  // 3. Reconciliation Process
  await reconciliationConsumer.subscribe({ topics: [
    'target.ehr.sync.completed',
    'target.pharmacy.sync.completed',
    'target.portal.sync.completed'
  ]});
  
  await reconciliationConsumer.run({
    eachMessage: async ({ topic, partition, message }) => {
      try {
        const targetSystem = topic.split('.')[1]; // e.g., 'ehr', 'pharmacy'
        const event = JSON.parse(message.value.toString());
        const { entityType, entityId, syncTimestamp, syncStatus, syncDetails } = event;
        const correlationId = message.headers['correlation-id']?.toString();
        
        // Record the sync completion
        await recordSyncCompletion(targetSystem, entityType, entityId, syncTimestamp, syncStatus, syncDetails);
        
        // Check reconciliation status across all target systems
        const reconciliationStatus = await checkReconciliationStatus(entityType, entityId);
        
        // If all target systems are in sync, publish reconciliation complete event
        if (reconciliationStatus.allSynced) {
          await producer.send({
            topic: `reconciliation.${entityType}.completed`,
            compression: CompressionTypes.GZIP,
            messages: [
              {
                key: entityId,
                value: JSON.stringify({
                  entityType,
                  entityId,
                  reconciliationTimestamp: Date.now(),
                  targetSystems: reconciliationStatus.systems,
                  syncDuration: reconciliationStatus.duration
                }),
                headers: {
                  'correlation-id': correlationId,
                  'entity-type': entityType
                }
              }
            ]
          });
          
          console.log(`Reconciliation completed for ${entityType} ${entityId} across all target systems`);
        }
      } catch (error) {
        console.error(`Error processing reconciliation for topic ${topic}:`, error);
        // Send to error handling topic for investigation
        await sendToErrorTopic('reconciliation-error', topic, message, error);
      }
    }
  });
  
  console.log('Healthcare Data Synchronization Pipeline started');
}

// Helper function to send errors to an error topic
async function sendToErrorTopic(errorType: string, sourceTopic: string, message: any, error: Error) {
  try {
    await producer.send({
      topic: 'data.sync.errors',
      messages: [
        {
          key: message.key,
          value: JSON.stringify({
            errorType,
            sourceTopic,
            error: {
              message: error.message,
              stack: error.stack
            },
            originalMessage: {
              key: message.key?.toString(),
              headers: Object.entries(message.headers || {}).reduce((acc: any, [key, value]) => {
                acc[key] = value?.toString();
                return acc;
              }, {}),
              offset: message.offset,
              partition: message.partition,
              timestamp: message.timestamp
            },
            timestamp: Date.now()
          })
        }
      ]
    });
  } catch (e) {
    console.error('Failed to send to error topic:', e);
  }
}

// Mock transformation function
async function transformToCanonicalFormat(sourceSystem: string, entityType: string, data: any) {
  // In a real implementation, this would apply complex transformation rules
  console.log(`Transforming ${sourceSystem}.${entityType} data to canonical format`);
  
  // Mock transformation - in reality this would be much more complex
  switch (entityType) {
    case 'patient':
      return {
        id: data.id || data.patientId || uuidv4(),
        sourceId: `${sourceSystem}:${data.id || data.patientId}`,
        firstName: data.firstName || data.name?.given || data.givenName,
        lastName: data.lastName || data.name?.family || data.familyName,
        dateOfBirth: data.dateOfBirth || data.birthDate || data.dob,
        gender: data.gender || data.sex,
        identifiers: [
          ...data.identifiers || [],
          { system: sourceSystem, value: data.id || data.patientId }
        ],
        address: data.address,
        contact: data.contact || data.contactInfo,
        lastUpdated: data.lastUpdated || data.updatedAt || Date.now(),
        version: data.version || data.versionId || 1,
        sourceSystem,
      };
      
    case 'prescription':
      return {
        id: data.id || data.prescriptionId || uuidv4(),
        sourceId: `${sourceSystem}:${data.id || data.prescriptionId}`,
        patientId: data.patientId || data.patient?.id,
        medicationId: data.medicationId || data.medication?.id,
        medicationName: data.medicationName || data.medication?.name,
        dosage: data.dosage || data.dose,
        frequency: data.frequency,
        duration: data.duration,
        prescriberId: data.prescriberId || data.provider?.id,
        status: data.status,
        lastUpdated: data.lastUpdated || data.updatedAt || Date.now(),
        version: data.version || data.versionId || 1,
        sourceSystem,
      };
      
    // Add other entity types as needed
    
    default:
      // Generic transformation
      return {
        id: data.id || uuidv4(),
        sourceId: `${sourceSystem}:${data.id}`,
        ...data,
        lastUpdated: data.lastUpdated || data.updatedAt || Date.now(),
        version: data.version || data.versionId || 1,
        sourceSystem,
      };
  }
}

// Mock validation function
async function validateData(entityType: string, data: any) {
  // In a real implementation, this would apply schema validation, business rules, etc.
  console.log(`Validating ${entityType} data for ${data.id}`);
  
  const errors = [];
  
  // Basic validation - real implementation would be more comprehensive
  switch (entityType) {
    case 'patient':
      if (!data.firstName && !data.lastName) {
        errors.push('Patient must have at least a first or last name');
      }
      if (!data.dateOfBirth) {
        errors.push('Patient must have a date of birth');
      }
      break;
      
    case 'prescription':
      if (!data.patientId) {
        errors.push('Prescription must have a patient ID');
      }
      if (!data.medicationId && !data.medicationName) {
        errors.push('Prescription must have a medication ID or name');
      }
      break;
  }
  
  return {
    valid: errors.length === 0,
    errors
  };
}

// Mock conflict detection function
async function detectConflicts(entityType: string, data: any) {
  // In a real implementation, this would check for concurrent updates, etc.
  console.log(`Detecting conflicts for ${entityType} ${data.id}`);
  
  // Mock conflict detection - real implementation would query a database
  const conflicts = [];
  
  // Simulate occasional conflicts (for demo purposes)
  if (Math.random() < 0.1) { // 10% chance of conflict
    conflicts.push({
      type: 'concurrent-update',
      entity: { 
        id: data.id, 
        version: data.version + 1, 
        lastUpdated: Date.now(), 
        sourceSystem: 'another-system' 
      }
    });
  }
  
  return conflicts;
}

// Mock conflict resolution function
async function resolveConflicts(entityType: string, data: any, conflicts: any[]) {
  // In a real implementation, this would apply resolution strategies
  console.log(`Resolving ${conflicts.length} conflicts for ${entityType} ${data.id}`);
  
  // Simple last-writer-wins strategy for demo
  let resolvedData = { ...data };
  
  for (const conflict of conflicts) {
    if (conflict.type === 'concurrent-update') {
      if (conflict.entity.lastUpdated > data.lastUpdated) {
        // Merge the data, with the newer fields winning
        resolvedData = {
          ...data,
          ...conflict.entity,
          version: Math.max(data.version, conflict.entity.version) + 1,
          lastUpdated: Date.now(),
          conflictResolution: {
            resolvedAt: Date.now(),
            strategy: 'merge-with-last-writer-wins',
            conflictingSystems: [data.sourceSystem, conflict.entity.sourceSystem]
          }
        };
      }
    }
  }
  
  return resolvedData;
}

// Mock function to record sync completion
async function recordSyncCompletion(
  targetSystem: string, 
  entityType: string, 
  entityId: string, 
  syncTimestamp: number, 
  syncStatus: string, 
  syncDetails: any
) {
  // In a real implementation, this would update a database record
  console.log(`Recording sync completion for ${entityType} ${entityId} in ${targetSystem}: ${syncStatus}`);
  // Implementation omitted for brevity
}

// Mock function to check reconciliation status
async function checkReconciliationStatus(entityType: string, entityId: string) {
  // In a real implementation, this would query sync status across systems
  console.log(`Checking reconciliation status for ${entityType} ${entityId}`);
  
  // Mock response - real implementation would query a database
  // Simulate successful sync for demo purposes
  return {
    allSynced: true,
    systems: [
      { name: 'ehr', synced: true, timestamp: Date.now() - 5000 },
      { name: 'pharmacy', synced: true, timestamp: Date.now() - 3000 },
      { name: 'portal', synced: true, timestamp: Date.now() - 1000 }
    ],
    duration: '00:01:23' // 1 minute, 23 seconds
  };
}

// Start the data sync pipeline
initDataSyncPipeline().catch(console.error);
```

## Additional Advanced Patterns

### Exactly-Once Processing with Kafka Transactions
Implementing exactly-once semantics for critical healthcare workflows using Kafka transactions to ensure data consistency across multiple systems.

```typescript
import { Kafka, CompressionTypes, logLevel } from 'kafkajs';

const kafka = new Kafka({
  clientId: 'transactional-processor',
  brokers: ['event-broker.cmm.internal:9092'],
  logLevel: logLevel.INFO,
  // Auth configuration
});

// Create a transactional producer
const producer = kafka.producer({ 
  transactionalId: 'medication-order-processor-tx',
  maxInFlightRequests: 1,
  idempotent: true
});

// Example of exactly-once processing
async function processWithExactlyOnceSemantics() {
  const consumer = kafka.consumer({
    groupId: 'medication-order-processor',
    // Critical for exactly-once: read committed only, not uncommitted messages
    readUncommitted: false
  });
  
  await producer.connect();
  await consumer.connect();
  
  await consumer.subscribe({ 
    topics: ['medication.order.submitted'],
    fromBeginning: false
  });
  
  await consumer.run({
    eachBatchAutoResolve: false,
    eachBatch: async ({ batch, resolveOffset, heartbeat, isRunning, isStale }) => {
      // Begin a transaction
      const transaction = await producer.transaction();
      
      try {
        for (const message of batch.messages) {
          if (!isRunning() || isStale()) break;
          
          const order = JSON.parse(message.value.toString());
          
          // Process the order
          const processedOrder = await processOrder(order);
          
          // Produce the result as part of the transaction
          await transaction.send({
            topic: 'medication.order.processed',
            messages: [
              {
                key: message.key,
                value: JSON.stringify(processedOrder),
                headers: {
                  'correlation-id': message.headers['correlation-id']
                }
              }
            ],
            compression: CompressionTypes.GZIP
          });
          
          // Resolve the offset - this doesn't commit yet
          resolveOffset(message.offset);
          await heartbeat();
        }
        
        // Commit the transaction - this atomically commits both the consumer offsets 
        // and the produced messages
        await transaction.commit();
        console.log('Transaction committed successfully');
      } catch (error) {
        // If anything failed, abort the transaction
        await transaction.abort();
        console.error('Transaction aborted due to error:', error);
      }
    }
  });
}

// Mock order processing function
async function processOrder(order: any) {
  // Simulate processing
  return {
    ...order,
    status: 'PROCESSED',
    processedAt: new Date().toISOString()
  };
}

processWithExactlyOnceSemantics().catch(console.error);
```

### Dynamic Topic Creation with Schema Management
Automating topic creation with appropriate configurations and schema registration to support evolving healthcare data requirements.

```typescript
import { Kafka } from 'kafkajs';
import { SchemaRegistry } from '@kafkajs/confluent-schema-registry';

const kafka = new Kafka({
  clientId: 'schema-topic-manager',
  brokers: ['event-broker.cmm.internal:9092'],
  // Auth configuration
});

const registry = new SchemaRegistry({
  host: 'https://schema-registry.cmm.internal',
  // Auth configuration
});

const admin = kafka.admin();

async function setupTopicWithSchema(topicName: string, schema: any, topicConfig: any) {
  await admin.connect();
  
  // Check if topic exists
  const existingTopics = await admin.listTopics();
  
  if (!existingTopics.includes(topicName)) {
    console.log(`Creating topic: ${topicName}`);
    
    // Create the topic
    await admin.createTopics({
      topics: [{
        topic: topicName,
        numPartitions: topicConfig.partitions || 6,
        replicationFactor: topicConfig.replicationFactor || 3,
        configEntries: Object.entries(topicConfig.configs || {}).map(([key, value]) => ({
          name: key,
          value: String(value)
        }))
      }],
      waitForLeaders: true
    });
    
    console.log(`Topic ${topicName} created successfully`);
  } else {
    console.log(`Topic ${topicName} already exists`);
  }
  
  // Register schema for the topic
  const subjectName = `${topicName}-value`;
  
  // Check if schema already exists
  try {
    const existingSchema = await registry.getLatestSchemaId(subjectName);
    console.log(`Schema for ${subjectName} already exists with ID: ${existingSchema}`);
  } catch (error) {
    console.log(`Registering schema for ${subjectName}`);
    
    // Register new schema
    const { id } = await registry.register(schema, { subject: subjectName });
    console.log(`Schema registered for ${subjectName} with ID: ${id}`);
  }
  
  await admin.disconnect();
}

// Example usage
const medicationOrderSchema = {
  type: 'record',
  name: 'MedicationOrder',
  namespace: 'com.healthcare.medication',
  fields: [
    { name: 'id', type: 'string' },
    { name: 'patientId', type: 'string' },
    { name: 'medicationId', type: 'string' },
    { name: 'prescriberId', type: 'string' },
    { name: 'dosage', type: ['null', 'string'], default: null },
    { name: 'route', type: ['null', 'string'], default: null },
    { name: 'frequency', type: ['null', 'string'], default: null },
    { name: 'startDate', type: 'long', logicalType: 'timestamp-millis' },
    { name: 'endDate', type: ['null', 'long'], logicalType: 'timestamp-millis', default: null },
    { name: 'status', type: 'string' },
    { name: 'createdAt', type: 'long', logicalType: 'timestamp-millis' },
    { name: 'updatedAt', type: 'long', logicalType: 'timestamp-millis' }
  ]
};

const topicConfig = {
  partitions: 12,
  replicationFactor: 3,
  configs: {
    'cleanup.policy': 'delete',
    'retention.ms': 7 * 24 * 60 * 60 * 1000, // 7 days
    'min.insync.replicas': 2,
    'compression.type': 'lz4',
    'max.message.bytes': 1000000 // 1MB
  }
};

setupTopicWithSchema('medication.order.events', medicationOrderSchema, topicConfig)
  .then(() => console.log('Topic and schema setup complete'))
  .catch(error => console.error('Failed to setup topic and schema:', error));
```

### Event Sourcing with CQRS for Patient Records
Implementing event sourcing pattern with Command Query Responsibility Segregation (CQRS) to maintain complete patient history while optimizing read and write operations.

```typescript
// CQRS implementation example omitted for brevity as it is covered in the Message Patterns documentation
// See the message-patterns.md file for a detailed example of CQRS implementation
```

## Related Resources
- [Event Broker Message Patterns](./message-patterns.md)
- [Event Broker Core APIs](../02-core-functionality/core-apis.md)
- [Event Broker Topic Management](../02-core-functionality/topic-management.md)
- [Event Broker Customization](./customization.md)
- [Confluent Kafka Documentation](https://docs.confluent.io/platform/current/overview.html)
- [KafkaJS Documentation](https://kafka.js.org/docs/getting-started)
- [Avro Schema Registry Documentation](https://docs.confluent.io/platform/current/schema-registry/index.html)