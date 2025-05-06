# Event Broker Extension Points

## Introduction
This document outlines the extension points provided by the Event Broker component. These extension points enable developers to extend and integrate the Event Broker's functionality to meet specific business needs, adapt to different environments, and implement custom behaviors. Unlike basic customization options, extension points represent deeper integration possibilities that involve writing custom code, implementing interfaces, or modifying the Event Broker's behavior through well-defined hooks and plugins.

## Available Extension Points

### Client Extensions

#### Custom Serializers and Deserializers

The Event Broker allows you to implement custom serializers and deserializers to handle specialized data formats or add additional processing during serialization/deserialization.

**When to Use**:
- Working with healthcare-specific data formats not natively supported
- Adding encryption/decryption during serialization
- Implementing data transformation during serialization/deserialization
- Supporting custom compression algorithms

**Implementation Example**:

```typescript
import { Serializer, Deserializer } from 'kafkajs';
import { encryptField, decryptField } from './encryption-service';

// Custom serializer that automatically encrypts PHI fields
export class PHIProtectingSerializer implements Serializer {
  private readonly phiFields: string[] = [
    'patientId', 'mrn', 'ssn', 'dateOfBirth', 'fullName'
  ];
  
  async serialize(data: any): Promise<Buffer> {
    if (typeof data === 'object' && data !== null) {
      // Create a deep copy to avoid modifying the original
      const dataCopy = JSON.parse(JSON.stringify(data));
      
      // Encrypt PHI fields
      this.processObject(dataCopy);
      
      // Convert to JSON and then to Buffer
      return Buffer.from(JSON.stringify(dataCopy));
    }
    
    // Fallback for non-object data
    return Buffer.from(String(data));
  }
  
  private processObject(obj: any) {
    if (typeof obj !== 'object' || obj === null) return;
    
    // Process each key in the object
    for (const key of Object.keys(obj)) {
      const value = obj[key];
      
      if (this.phiFields.includes(key) && typeof value === 'string') {
        // Encrypt the PHI field
        obj[key] = encryptField(value);
      } else if (typeof value === 'object' && value !== null) {
        // Recursively process nested objects and arrays
        this.processObject(value);
      }
    }
  }
}

// Matching deserializer that decrypts PHI fields
export class PHIProtectingDeserializer implements Deserializer {
  private readonly phiFields: string[] = [
    'patientId', 'mrn', 'ssn', 'dateOfBirth', 'fullName'
  ];
  
  async deserialize(data: Buffer): Promise<any> {
    if (!data || data.length === 0) return null;
    
    try {
      // Parse JSON from buffer
      const obj = JSON.parse(data.toString());
      
      // Decrypt PHI fields
      this.processObject(obj);
      
      return obj;
    } catch (error) {
      console.error('Error deserializing data:', error);
      throw error;
    }
  }
  
  private processObject(obj: any) {
    if (typeof obj !== 'object' || obj === null) return;
    
    // Process each key in the object
    for (const key of Object.keys(obj)) {
      const value = obj[key];
      
      if (this.phiFields.includes(key) && typeof value === 'string') {
        // Decrypt the PHI field
        obj[key] = decryptField(value);
      } else if (typeof value === 'object' && value !== null) {
        // Recursively process nested objects and arrays
        this.processObject(value);
      }
    }
  }
}

// Usage in a Kafka producer
const producer = kafka.producer({
  createPartitioner: Partitioners.DefaultPartitioner
});

// Create serializer and deserializer instances
const phiSerializer = new PHIProtectingSerializer();
const phiDeserializer = new PHIProtectingDeserializer();

// Example of sending a message with PHI protection
async function sendProtectedPatientData(patientData: any) {
  // Connect to Kafka
  await producer.connect();
  
  // Serialize with PHI protection
  const serializedData = await phiSerializer.serialize(patientData);
  
  // Send to Kafka
  await producer.send({
    topic: 'patient.data',
    messages: [
      {
        key: patientData.id,
        value: serializedData
      }
    ]
  });
  
  await producer.disconnect();
}
```

#### Custom Partitioners

The Event Broker allows you to implement custom partitioning strategies to control how messages are distributed across partitions.

**When to Use**:
- Implementing geography-based partitioning for data locality
- Partitioning based on tenant ID for multi-tenant applications
- Creating custom workload distribution patterns
- Ensuring related healthcare events go to the same partition

**Implementation Example**:

```typescript
import { Partitioner, PartitionerArgs } from 'kafkajs';
import { createHash } from 'crypto';

// Custom partitioner for healthcare events
export class HealthcarePartitioner implements Partitioner {
  // Partition by patient ID for patient-related topics
  // Partition by provider ID for provider-related topics
  // Fall back to default partitioning for other topics
  partition(args: PartitionerArgs): number {
    const { topic, partitionMetadata, message } = args;
    const numPartitions = partitionMetadata.length;
    
    // If no key, use random partition
    if (!message.key) {
      return Math.floor(Math.random() * numPartitions);
    }
    
    // Try to extract message content
    let messageContent: any = {};
    if (message.value) {
      try {
        messageContent = JSON.parse(message.value.toString());
      } catch (e) {
        // Not valid JSON, use standard key-based partitioning
      }
    }
    
    // For patient-related topics, partition by patient ID if available
    if (topic.includes('patient')) {
      const patientId = messageContent.patientId || 
                        messageContent.patient?.id || 
                        message.key.toString();
      
      return this.hashToPartition(patientId, numPartitions);
    }
    
    // For provider-related topics, partition by provider ID if available
    if (topic.includes('provider') || topic.includes('prescriber')) {
      const providerId = messageContent.providerId || 
                         messageContent.provider?.id || 
                         message.key.toString();
                         
      return this.hashToPartition(providerId, numPartitions);
    }
    
    // For medication-related topics, partition by medication ID if available
    if (topic.includes('medication')) {
      const medicationId = messageContent.medicationId || 
                          messageContent.medication?.id || 
                          message.key.toString();
                          
      return this.hashToPartition(medicationId, numPartitions);
    }
    
    // Default to key-based partitioning
    return this.hashToPartition(message.key.toString(), numPartitions);
  }
  
  // Helper to consistently hash a string to a partition number
  private hashToPartition(str: string, numPartitions: number): number {
    const hash = createHash('md5').update(str).digest('hex');
    const hashValue = parseInt(hash.substring(0, 8), 16);
    return Math.abs(hashValue) % numPartitions;
  }
}

// Usage with a Kafka producer
const producer = kafka.producer({
  createPartitioner: () => new HealthcarePartitioner()
});

// Example of sending messages with custom partitioning
async function sendPatientEvents(patientEvents: any[]) {
  await producer.connect();
  
  // Group events by patient for efficicient batching
  const eventsByPatient: Record<string, any[]> = {};
  
  for (const event of patientEvents) {
    const patientId = event.patientId;
    if (!eventsByPatient[patientId]) {
      eventsByPatient[patientId] = [];
    }
    eventsByPatient[patientId].push(event);
  }
  
  // Send events for each patient
  for (const [patientId, events] of Object.entries(eventsByPatient)) {
    await producer.send({
      topic: 'patient.events',
      messages: events.map(event => ({
        key: patientId,
        value: JSON.stringify(event)
      }))
    });
  }
  
  await producer.disconnect();
}
```

#### Middleware Extensions

The Event Broker supports middleware extensions for producers and consumers, enabling the addition of cross-cutting concerns like logging, metrics, and validation.

**When to Use**:
- Adding security checks to messages
- Implementing cross-cutting logging or metrics
- Validating messages before sending or after receiving
- Adding correlation IDs or tracing information
- Implementing compliance checks or data governance rules

**Implementation Example**:

```typescript
import { Kafka, Message, RecordMetadata, CompressionTypes } from 'kafkajs';
import { v4 as uuidv4 } from 'uuid';
import { logger } from './logging-service';
import { validateMessage } from './validation-service';
import { collectMetrics } from './metrics-service';

// Initialize Kafka client
const kafka = new Kafka({
  clientId: 'healthcare-client',
  brokers: ['event-broker.cmm.internal:9092'],
  // Auth configuration
});

// Create producer with middleware
const producer = kafka.producer();

// Add producer middleware

// 1. Logging middleware
producer.logger().info('Registering producer middleware: logging');
producer.on('producer.connect', async () => {
  producer.logger().info('Adding logging middleware');
  
  producer.addMiddleware({
    name: 'logging',
    wrap: (sendBatch) => {
      return async (payload) => {
        const correlationId = uuidv4();
        
        // Log before sending
        logger.info(`Sending ${payload.topicMessages.length} messages to topics`, {
          correlationId,
          topics: payload.topicMessages.map(tm => tm.topic).join(', '),
          messageCount: payload.topicMessages.reduce(
            (acc, tm) => acc + tm.messages.length, 0
          )
        });
        
        // Track start time for performance monitoring
        const startTime = Date.now();
        
        try {
          // Send the messages
          const result = await sendBatch(payload);
          
          // Log success
          const duration = Date.now() - startTime;
          logger.info(`Successfully sent messages in ${duration}ms`, {
            correlationId,
            duration,
            topics: payload.topicMessages.map(tm => tm.topic).join(', ')
          });
          
          return result;
        } catch (error) {
          // Log error
          const duration = Date.now() - startTime;
          logger.error(`Failed to send messages after ${duration}ms`, {
            correlationId,
            duration,
            error: error.message,
            stack: error.stack,
            topics: payload.topicMessages.map(tm => tm.topic).join(', ')
          });
          
          throw error;
        }
      };
    }
  });
});

// 2. Metrics middleware
producer.logger().info('Registering producer middleware: metrics');
producer.on('producer.connect', async () => {
  producer.logger().info('Adding metrics middleware');
  
  producer.addMiddleware({
    name: 'metrics',
    wrap: (sendBatch) => {
      return async (payload) => {
        // Track metrics before sending
        const topicMessageCounts = payload.topicMessages.reduce((acc, tm) => {
          acc[tm.topic] = (acc[tm.topic] || 0) + tm.messages.length;
          return acc;
        }, {} as Record<string, number>);
        
        // Record message counts by topic
        for (const [topic, count] of Object.entries(topicMessageCounts)) {
          collectMetrics('kafka_outgoing_messages', { topic, status: 'sending' }, count);
        }
        
        const startTime = Date.now();
        
        try {
          // Send the messages
          const result = await sendBatch(payload);
          
          // Record success metrics
          const duration = Date.now() - startTime;
          collectMetrics('kafka_producer_latency_ms', { status: 'success' }, duration);
          
          for (const [topic, count] of Object.entries(topicMessageCounts)) {
            collectMetrics('kafka_outgoing_messages', { topic, status: 'success' }, count);
          }
          
          return result;
        } catch (error) {
          // Record failure metrics
          const duration = Date.now() - startTime;
          collectMetrics('kafka_producer_latency_ms', { status: 'error' }, duration);
          
          for (const [topic, count] of Object.entries(topicMessageCounts)) {
            collectMetrics('kafka_outgoing_messages', { topic, status: 'error' }, count);
          }
          
          throw error;
        }
      };
    }
  });
});

// 3. Validation middleware
producer.logger().info('Registering producer middleware: validation');
producer.on('producer.connect', async () => {
  producer.logger().info('Adding validation middleware');
  
  producer.addMiddleware({
    name: 'validation',
    wrap: (sendBatch) => {
      return async (payload) => {
        // Validate messages before sending
        for (const { topic, messages } of payload.topicMessages) {
          for (const message of messages) {
            if (message.value) {
              try {
                const value = JSON.parse(message.value.toString());
                const validationResult = validateMessage(topic, value);
                
                if (!validationResult.valid) {
                  const errorMsg = `Validation failed for message to ${topic}: ${validationResult.errors.join(', ')}`;
                  logger.error(errorMsg, { messageKey: message.key?.toString() });
                  throw new Error(errorMsg);
                }
              } catch (error) {
                if (error.message.includes('Validation failed')) {
                  throw error;
                }
                
                logger.warn(`Could not validate message to ${topic}: ${error.message}`, {
                  messageKey: message.key?.toString()
                });
                // Continue without validation for non-JSON messages
              }
            }
          }
        }
        
        // Send the messages
        return await sendBatch(payload);
      };
    }
  });
});

// 4. Correlation ID middleware
producer.logger().info('Registering producer middleware: correlation-id');
producer.on('producer.connect', async () => {
  producer.logger().info('Adding correlation ID middleware');
  
  producer.addMiddleware({
    name: 'correlation-id',
    wrap: (sendBatch) => {
      return async (payload) => {
        // Add correlation IDs to messages that don't have them
        for (const { messages } of payload.topicMessages) {
          for (const message of messages) {
            if (!message.headers?.['correlation-id']) {
              message.headers = {
                ...message.headers,
                'correlation-id': Buffer.from(uuidv4())
              };
            }
          }
        }
        
        // Send the messages
        return await sendBatch(payload);
      };
    }
  });
});

// Example usage
async function sendHealthcareEvents(events: any[]) {
  await producer.connect();
  
  for (const event of events) {
    await producer.send({
      topic: event.topic,
      messages: [{
        key: event.key,
        value: JSON.stringify(event.value),
        headers: event.headers
      }]
    });
  }
}
```

### Stream Processing Extensions

#### Custom Stream Processors

The Event Broker allows you to implement custom stream processors using the Kafka Streams API or similar libraries to transform, enrich, or analyze event streams.

**When to Use**:
- Implementing real-time data transformations
- Building specialized healthcare analytics
- Creating derived data streams from raw events
- Implementing complex event processing for clinical alerts

**Implementation Example**:

```typescript
import { KafkaStreams, KStream } from 'kafka-streams';
import { Kafka } from 'kafkajs';
import { SchemaRegistry } from '@kafkajs/confluent-schema-registry';

// Initialize clients
const kafka = new Kafka({
  clientId: 'healthcare-streaming',
  brokers: ['event-broker.cmm.internal:9092'],
  // Auth configuration
});

const registry = new SchemaRegistry({
  host: 'https://schema-registry.cmm.internal',
  // Auth configuration
});

// Configure Kafka Streams
const kafkaStreamsConfig = {
  'noptions.metadata.broker.list': 'event-broker.cmm.internal:9092',
  'security.protocol': 'sasl_ssl',
  'sasl.mechanisms': 'PLAIN',
  'sasl.username': process.env.KAFKA_USERNAME,
  'sasl.password': process.env.KAFKA_PASSWORD,
  'ssl.ca.location': process.env.SSL_CA_LOCATION,
  'group.id': 'healthcare-stream-processor',
  'client.id': 'healthcare-stream-processor'
};

const kafkaStreams = new KafkaStreams(kafkaStreamsConfig);

/**
 * Custom stream processor to detect abnormal vital signs and generate alerts
 */
async function createVitalSignsAlertProcessor() {
  // Create a stream from the vital signs topic
  const vitalSignsStream: KStream = kafkaStreams.getKStream('patient.vitalsigns');
  
  // Define the normal ranges for vital signs
  const normalRanges = {
    heartRate: { min: 60, max: 100 }, // bpm
    systolicBP: { min: 90, max: 140 }, // mmHg
    diastolicBP: { min: 60, max: 90 }, // mmHg
    temperature: { min: 36.1, max: 37.5 }, // Celsius
    respiratoryRate: { min: 12, max: 20 }, // breaths per minute
    oxygenSaturation: { min: 95, max: 100 } // percent
  };
  
  // Process the stream
  vitalSignsStream
    // Parse the message
    .map(message => {
      try {
        const data = JSON.parse(message.value.toString());
        return {
          key: message.key.toString(),
          reading: data
        };
      } catch (error) {
        console.error('Error parsing vital sign message:', error);
        return null;
      }
    })
    // Filter out parsing errors
    .filter(data => data !== null)
    // Detect abnormal readings
    .flatMap(data => {
      const { reading } = data;
      const abnormalities = [];
      
      // Check each vital sign against normal ranges
      if (reading.heartRate && 
          (reading.heartRate < normalRanges.heartRate.min || 
           reading.heartRate > normalRanges.heartRate.max)) {
        abnormalities.push({
          patientId: reading.patientId,
          timestamp: reading.timestamp,
          vitalSign: 'heartRate',
          value: reading.heartRate,
          normalRange: normalRanges.heartRate,
          severity: getSeverity('heartRate', reading.heartRate, normalRanges.heartRate)
        });
      }
      
      if (reading.systolicBP && 
          (reading.systolicBP < normalRanges.systolicBP.min || 
           reading.systolicBP > normalRanges.systolicBP.max)) {
        abnormalities.push({
          patientId: reading.patientId,
          timestamp: reading.timestamp,
          vitalSign: 'systolicBP',
          value: reading.systolicBP,
          normalRange: normalRanges.systolicBP,
          severity: getSeverity('systolicBP', reading.systolicBP, normalRanges.systolicBP)
        });
      }
      
      // Check other vital signs...
      
      return abnormalities;
    })
    // Filter out empty abnormality lists
    .filter(abnormality => abnormality !== null)
    // Group alerts by patient
    .groupBy((abnormality) => abnormality.patientId)
    // Window operations - group alerts within a 5-minute window
    .window('tumbling', 5 * 60 * 1000)
    // Collect all abnormalities for a patient in the window
    .reduce((alerts, abnormality) => {
      alerts.push(abnormality);
      return alerts;
    }, [])
    // Filter out windows with no alerts
    .filter(alerts => alerts.length > 0)
    // Create an alert for each window
    .map(alerts => {
      // Find the highest severity
      const maxSeverity = Math.max(...alerts.map(a => a.severity));
      
      // Group by vital sign
      const vitalSignGroups = alerts.reduce((groups, alert) => {
        if (!groups[alert.vitalSign]) {
          groups[alert.vitalSign] = [];
        }
        groups[alert.vitalSign].push(alert);
        return groups;
      }, {});
      
      // Create a summary alert
      return {
        patientId: alerts[0].patientId,
        timestamp: Date.now(),
        alertId: `${alerts[0].patientId}-${Date.now()}`,
        severity: maxSeverity,
        abnormalities: vitalSignGroups,
        alertCount: alerts.length,
        message: createAlertMessage(alerts, maxSeverity)
      };
    })
    // Send alerts to the alerts topic
    .to('patient.vitalsigns.alerts');
  
  // Start the stream processing
  await vitalSignsStream.start();
  
  console.log('Vital signs alert processor started');
  
  return vitalSignsStream;
}

// Helper functions

// Determine severity level based on how far the value is from normal range
function getSeverity(vitalSign: string, value: number, range: { min: number, max: number }): number {
  // 1 = minor deviation, 2 = moderate, 3 = severe
  
  // Calculate how far outside the range the value is
  let percentDeviation = 0;
  
  if (value < range.min) {
    percentDeviation = (range.min - value) / range.min;
  } else if (value > range.max) {
    percentDeviation = (value - range.max) / range.max;
  }
  
  // Determine severity based on percent deviation
  if (percentDeviation > 0.5) {
    return 3; // severe
  } else if (percentDeviation > 0.2) {
    return 2; // moderate
  } else {
    return 1; // minor
  }
}

// Create a human-readable alert message
function createAlertMessage(alerts: any[], severity: number): string {
  const severityText = severity === 3 ? 'Critical' : 
                      severity === 2 ? 'Moderate' : 'Minor';
  
  // Count unique vital signs
  const vitalSigns = new Set(alerts.map(a => a.vitalSign));
  
  return `${severityText} alert: Abnormal readings detected for ${Array.from(vitalSigns).join(', ')}`;
}

// Start the processor
createVitalSignsAlertProcessor()
  .then(stream => {
    console.log('Vital signs alert processor is running');
    
    // Handle graceful shutdown
    process.on('SIGTERM', async () => {
      console.log('Shutting down vital signs alert processor');
      await stream.close();
      process.exit(0);
    });
  })
  .catch(error => {
    console.error('Failed to start vital signs alert processor:', error);
    process.exit(1);
  });
```

#### Custom State Stores

The Event Broker enables the creation of custom state stores for stateful stream processing applications, allowing for efficient local state management.

**When to Use**:
- Implementing sophisticated data aggregations
- Building custom windowing operations
- Creating specialized indexes for healthcare data
- Implementing complex event correlation across multiple streams

**Implementation Example**:

```typescript
import { Kafka } from 'kafkajs';
import { KafkaStreams, KStream } from 'kafka-streams';
import * as fs from 'fs';
import * as path from 'path';
import * as levelup from 'levelup';
import * as leveldown from 'leveldown';
import { v4 as uuidv4 } from 'uuid';

/**
 * Custom state store for patient risk scores
 * Maintains a persistent store of patient risk scores calculated from various events
 */
class PatientRiskStore {
  private db: any;
  private changelogProducer: any;
  private changelogTopic: string;
  
  constructor(storeName: string, kafkaConfig: any) {
    // Create LevelDB store
    const dbPath = path.join(process.env.STATE_STORE_PATH || './state', 
                           `patient-risk-${storeName}`);
    
    // Ensure directory exists
    if (!fs.existsSync(path.dirname(dbPath))) {
      fs.mkdirSync(path.dirname(dbPath), { recursive: true });
    }
    
    // Initialize LevelDB
    this.db = levelup(leveldown(dbPath));
    
    // Initialize Kafka for the changelog
    const kafka = new Kafka(kafkaConfig);
    this.changelogProducer = kafka.producer();
    this.changelogTopic = `patient-risk-${storeName}-changelog`;
  }
  
  async init() {
    await this.changelogProducer.connect();
    return this;
  }
  
  async close() {
    await this.db.close();
    await this.changelogProducer.disconnect();
  }
  
  // Get patient risk score
  async getRiskScore(patientId: string): Promise<any> {
    try {
      const data = await this.db.get(patientId);
      return JSON.parse(data.toString());
    } catch (error) {
      if (error.type === 'NotFoundError') {
        return null;
      }
      throw error;
    }
  }
  
  // Update patient risk score
  async updateRiskScore(patientId: string, riskFactors: any): Promise<void> {
    // Get current risk score data
    const currentData = await this.getRiskScore(patientId) || {
      patientId,
      riskFactors: {},
      overallScore: 0,
      lastUpdated: 0
    };
    
    // Update with new risk factors
    const updatedData = {
      ...currentData,
      riskFactors: {
        ...currentData.riskFactors,
        ...riskFactors
      },
      lastUpdated: Date.now()
    };
    
    // Calculate new overall score
    updatedData.overallScore = this.calculateOverallScore(updatedData.riskFactors);
    
    // Store updated data
    await this.db.put(patientId, JSON.stringify(updatedData));
    
    // Write to changelog
    await this.changelogProducer.send({
      topic: this.changelogTopic,
      messages: [
        {
          key: patientId,
          value: JSON.stringify({
            operation: 'update',
            data: updatedData,
            timestamp: Date.now()
          })
        }
      ]
    });
  }
  
  // Delete patient risk score
  async deleteRiskScore(patientId: string): Promise<void> {
    await this.db.del(patientId);
    
    // Write to changelog
    await this.changelogProducer.send({
      topic: this.changelogTopic,
      messages: [
        {
          key: patientId,
          value: JSON.stringify({
            operation: 'delete',
            patientId,
            timestamp: Date.now()
          })
        }
      ]
    });
  }
  
  // Batch get risk scores for multiple patients
  async batchGetRiskScores(patientIds: string[]): Promise<Record<string, any>> {
    const result: Record<string, any> = {};
    
    // Using a simple loop for clarity, but could be optimized
    for (const patientId of patientIds) {
      result[patientId] = await this.getRiskScore(patientId);
    }
    
    return result;
  }
  
  // Calculate overall risk score from individual factors
  private calculateOverallScore(riskFactors: Record<string, number>): number {
    // Weight factors
    const weights: Record<string, number> = {
      'age': 0.1,
      'smokingStatus': 0.2,
      'bmi': 0.15,
      'bloodPressure': 0.2,
      'cholesterol': 0.15,
      'diabetes': 0.2,
      // Add other factors as needed
    };
    
    let weightedSum = 0;
    let totalWeight = 0;
    
    // Calculate weighted sum of available factors
    for (const [factor, value] of Object.entries(riskFactors)) {
      if (weights[factor]) {
        weightedSum += value * weights[factor];
        totalWeight += weights[factor];
      }
    }
    
    // Normalize by available weights
    return totalWeight > 0 ? weightedSum / totalWeight : 0;
  }
}

/**
 * Stream processor that uses the custom state store
 */
async function createPatientRiskProcessor() {
  // Create state store
  const riskStore = await new PatientRiskStore('processor', {
    clientId: 'risk-processor',
    brokers: ['event-broker.cmm.internal:9092'],
    // Auth configuration
  }).init();
  
  // Kafka Streams configuration
  const kafkaStreamsConfig = {
    'noptions.metadata.broker.list': 'event-broker.cmm.internal:9092',
    'security.protocol': 'sasl_ssl',
    'sasl.mechanisms': 'PLAIN',
    'sasl.username': process.env.KAFKA_USERNAME,
    'sasl.password': process.env.KAFKA_PASSWORD,
    'group.id': 'patient-risk-processor',
    'client.id': 'patient-risk-processor'
  };
  
  const kafkaStreams = new KafkaStreams(kafkaStreamsConfig);
  
  // Create streams for different event types
  const vitalSignsStream = kafkaStreams.getKStream('patient.vitalsigns');
  const labResultsStream = kafkaStreams.getKStream('patient.labresults');
  const diagnosisStream = kafkaStreams.getKStream('patient.diagnosis');
  
  // Process vital signs
  vitalSignsStream
    .map(message => {
      try {
        return JSON.parse(message.value.toString());
      } catch (error) {
        console.error('Error parsing vital signs message:', error);
        return null;
      }
    })
    .filter(data => data !== null)
    .forEach(async (data) => {
      const { patientId } = data;
      
      // Extract risk factors from vital signs
      const riskFactors: Record<string, number> = {};
      
      // Blood pressure risk
      if (data.systolicBP && data.diastolicBP) {
        // Calculate blood pressure risk (simplified example)
        let bpRisk = 0;
        
        if (data.systolicBP >= 140 || data.diastolicBP >= 90) {
          bpRisk = 0.8; // High BP risk
        } else if (data.systolicBP >= 130 || data.diastolicBP >= 80) {
          bpRisk = 0.4; // Elevated BP risk
        } else if (data.systolicBP >= 120) {
          bpRisk = 0.2; // Borderline BP risk
        }
        
        riskFactors.bloodPressure = bpRisk;
      }
      
      // BMI risk
      if (data.height && data.weight) {
        const heightInMeters = data.height / 100;
        const bmi = data.weight / (heightInMeters * heightInMeters);
        
        let bmiRisk = 0;
        if (bmi >= 30) {
          bmiRisk = 0.7; // Obese
        } else if (bmi >= 25) {
          bmiRisk = 0.3; // Overweight
        } else if (bmi < 18.5) {
          bmiRisk = 0.2; // Underweight
        }
        
        riskFactors.bmi = bmiRisk;
      }
      
      // Update the risk store
      await riskStore.updateRiskScore(patientId, riskFactors);
    });
  
  // Process lab results
  labResultsStream
    .map(message => {
      try {
        return JSON.parse(message.value.toString());
      } catch (error) {
        console.error('Error parsing lab results message:', error);
        return null;
      }
    })
    .filter(data => data !== null)
    .forEach(async (data) => {
      const { patientId } = data;
      
      // Extract risk factors from lab results
      const riskFactors: Record<string, number> = {};
      
      // Cholesterol risk
      if (data.testName === 'LIPID_PANEL') {
        // Calculate cholesterol risk (simplified example)
        let cholesterolRisk = 0;
        
        if (data.ldl > 160) {
          cholesterolRisk = 0.8; // High risk
        } else if (data.ldl > 130) {
          cholesterolRisk = 0.4; // Moderate risk
        } else if (data.ldl > 100) {
          cholesterolRisk = 0.2; // Borderline risk
        }
        
        riskFactors.cholesterol = cholesterolRisk;
      }
      
      // Diabetes risk
      if (data.testName === 'GLUCOSE' || data.testName === 'HBA1C') {
        let diabetesRisk = 0;
        
        if (data.testName === 'GLUCOSE' && data.value > 126) {
          diabetesRisk = 0.8; // High risk
        } else if (data.testName === 'HBA1C' && data.value > 6.5) {
          diabetesRisk = 0.9; // High risk
        }
        
        riskFactors.diabetes = diabetesRisk;
      }
      
      // Update the risk store
      await riskStore.updateRiskScore(patientId, riskFactors);
    });
  
  // Process diagnosis
  diagnosisStream
    .map(message => {
      try {
        return JSON.parse(message.value.toString());
      } catch (error) {
        console.error('Error parsing diagnosis message:', error);
        return null;
      }
    })
    .filter(data => data !== null)
    .forEach(async (data) => {
      const { patientId } = data;
      
      // Extract risk factors from diagnosis
      const riskFactors: Record<string, number> = {};
      
      // Smoking status
      if (data.code === 'SMOKING_STATUS') {
        let smokingRisk = 0;
        
        if (data.value === 'CURRENT') {
          smokingRisk = 0.9; // High risk
        } else if (data.value === 'FORMER') {
          smokingRisk = 0.3; // Moderate risk
        }
        
        riskFactors.smokingStatus = smokingRisk;
      }
      
      // Other diagnosis-based risks can be added here
      
      // Update the risk store
      await riskStore.updateRiskScore(patientId, riskFactors);
    });
  
  // Start the streams
  await vitalSignsStream.start();
  await labResultsStream.start();
  await diagnosisStream.start();
  
  // Create a stream for risk score queries
  const queryStream = kafkaStreams.getKStream('patient.risk.query');
  
  queryStream
    .map(message => {
      try {
        return JSON.parse(message.value.toString());
      } catch (error) {
        console.error('Error parsing risk query message:', error);
        return null;
      }
    })
    .filter(query => query !== null)
    .forEach(async (query) => {
      const { requestId, patientIds } = query;
      
      try {
        // Get risk scores for requested patients
        const riskScores = await riskStore.batchGetRiskScores(patientIds);
        
        // Produce response
        const kafka = new Kafka({
          clientId: 'risk-query-responder',
          brokers: ['event-broker.cmm.internal:9092'],
          // Auth configuration
        });
        
        const producer = kafka.producer();
        await producer.connect();
        
        await producer.send({
          topic: 'patient.risk.response',
          messages: [
            {
              key: requestId,
              value: JSON.stringify({
                requestId,
                riskScores,
                timestamp: Date.now()
              })
            }
          ]
        });
        
        await producer.disconnect();
      } catch (error) {
        console.error(`Error processing risk query: ${error.message}`);
      }
    });
  
  await queryStream.start();
  
  console.log('Patient risk processor started');
  
  // Return the streams for cleanup
  return {
    streams: [vitalSignsStream, labResultsStream, diagnosisStream, queryStream],
    store: riskStore
  };
}

// Start the processor
createPatientRiskProcessor()
  .then(({ streams, store }) => {
    console.log('Patient risk processor is running');
    
    // Handle graceful shutdown
    process.on('SIGTERM', async () => {
      console.log('Shutting down patient risk processor');
      
      // Stop all streams
      await Promise.all(streams.map(stream => stream.close()));
      
      // Close the state store
      await store.close();
      
      process.exit(0);
    });
  })
  .catch(error => {
    console.error('Failed to start patient risk processor:', error);
    process.exit(1);
  });
```

### Integration Extensions

#### Custom Connectors

The Event Broker supports the development of custom Kafka Connect connectors to integrate with external systems and data sources.

**When to Use**:
- Integrating with proprietary healthcare systems
- Building specialized connectors for medical devices or sensors
- Implementing data pipelines for specific healthcare workflows
- Creating connectors for legacy healthcare systems

**Implementation Example**:

```typescript
import { Readable } from 'stream';
import axios from 'axios';
import { Kafka, CompressionTypes } from 'kafkajs';
import { v4 as uuidv4 } from 'uuid';

/**
 * Custom connector for integrating with a proprietary EHR system
 * This example shows a polling-based source connector that retrieves
 * patient data changes from an EHR API and publishes them to Kafka
 */
class EhrSourceConnector {
  private readonly kafka: Kafka;
  private readonly producer: any;
  private readonly ehrApiConfig: {
    baseUrl: string;
    apiKey: string;
    username: string;
    password: string;
  };
  private readonly targetTopic: string;
  private readonly pollIntervalMs: number;
  private readonly batchSize: number;
  private lastSyncTimestamp: number;
  private isRunning: boolean = false;
  private pollInterval: NodeJS.Timeout | null = null;
  
  constructor(config: {
    kafka: {
      clientId: string;
      brokers: string[];
      ssl?: boolean;
      sasl?: {
        mechanism: string;
        username: string;
        password: string;
      };
    };
    ehr: {
      baseUrl: string;
      apiKey: string;
      username: string;
      password: string;
    };
    connector: {
      topic: string;
      pollIntervalMs: number;
      batchSize: number;
      initialTimestamp?: number;
    };
  }) {
    // Initialize Kafka
    this.kafka = new Kafka(config.kafka);
    this.producer = this.kafka.producer({
      idempotent: true,
      maxInFlightRequests: 1,
      transactionTimeout: 30000
    });
    
    // Store configuration
    this.ehrApiConfig = config.ehr;
    this.targetTopic = config.connector.topic;
    this.pollIntervalMs = config.connector.pollIntervalMs;
    this.batchSize = config.connector.batchSize;
    
    // Set initial timestamp to 24 hours ago if not specified
    this.lastSyncTimestamp = config.connector.initialTimestamp || 
                          Date.now() - (24 * 60 * 60 * 1000);
  }
  
  async start(): Promise<void> {
    if (this.isRunning) {
      return;
    }
    
    console.log(`Starting EHR Source Connector, polling every ${this.pollIntervalMs}ms`);
    
    await this.producer.connect();
    this.isRunning = true;
    
    // Start polling
    this.pollEhrApi();
    this.pollInterval = setInterval(() => this.pollEhrApi(), this.pollIntervalMs);
  }
  
  async stop(): Promise<void> {
    if (!this.isRunning) {
      return;
    }
    
    console.log('Stopping EHR Source Connector');
    
    if (this.pollInterval) {
      clearInterval(this.pollInterval);
      this.pollInterval = null;
    }
    
    this.isRunning = false;
    await this.producer.disconnect();
  }
  
  private async pollEhrApi(): Promise<void> {
    if (!this.isRunning) {
      return;
    }
    
    // Format timestamp for API
    const timestampStr = new Date(this.lastSyncTimestamp).toISOString();
    console.log(`Polling EHR API for changes since ${timestampStr}`);
    
    try {
      // Fetch patient changes
      const patientChanges = await this.fetchPatientChanges(timestampStr);
      
      if (patientChanges.length > 0) {
        console.log(`Retrieved ${patientChanges.length} patient changes`);
        
        // Process changes in batches
        for (let i = 0; i < patientChanges.length; i += this.batchSize) {
          const batch = patientChanges.slice(i, i + this.batchSize);
          await this.processPatientBatch(batch);
        }
        
        // Update last sync timestamp to latest change
        const latestTimestamp = Math.max(
          ...patientChanges.map(change => new Date(change.lastUpdated).getTime())
        );
        
        this.lastSyncTimestamp = latestTimestamp;
        console.log(`Updated last sync timestamp to ${new Date(latestTimestamp).toISOString()}`);
      } else {
        console.log('No patient changes found');
      }
      
      // Fetch encounter changes
      const encounterChanges = await this.fetchEncounterChanges(timestampStr);
      
      if (encounterChanges.length > 0) {
        console.log(`Retrieved ${encounterChanges.length} encounter changes`);
        
        // Process changes in batches
        for (let i = 0; i < encounterChanges.length; i += this.batchSize) {
          const batch = encounterChanges.slice(i, i + this.batchSize);
          await this.processEncounterBatch(batch);
        }
        
        // Update last sync timestamp if newer than patient changes
        const latestTimestamp = Math.max(
          ...encounterChanges.map(change => new Date(change.lastUpdated).getTime())
        );
        
        if (latestTimestamp > this.lastSyncTimestamp) {
          this.lastSyncTimestamp = latestTimestamp;
          console.log(`Updated last sync timestamp to ${new Date(latestTimestamp).toISOString()}`);
        }
      } else {
        console.log('No encounter changes found');
      }
    } catch (error) {
      console.error('Error polling EHR API:', error);
    }
  }
  
  private async fetchPatientChanges(since: string): Promise<any[]> {
    try {
      const response = await axios({
        method: 'get',
        url: `${this.ehrApiConfig.baseUrl}/api/patients/changes`,
        params: {
          since,
          limit: this.batchSize * 5 // Fetch multiple batches at once
        },
        headers: {
          'X-API-Key': this.ehrApiConfig.apiKey,
          'Content-Type': 'application/json'
        },
        auth: {
          username: this.ehrApiConfig.username,
          password: this.ehrApiConfig.password
        }
      });
      
      return response.data.changes || [];
    } catch (error) {
      console.error('Failed to fetch patient changes:', error.message);
      return [];
    }
  }
  
  private async fetchEncounterChanges(since: string): Promise<any[]> {
    try {
      const response = await axios({
        method: 'get',
        url: `${this.ehrApiConfig.baseUrl}/api/encounters/changes`,
        params: {
          since,
          limit: this.batchSize * 5 // Fetch multiple batches at once
        },
        headers: {
          'X-API-Key': this.ehrApiConfig.apiKey,
          'Content-Type': 'application/json'
        },
        auth: {
          username: this.ehrApiConfig.username,
          password: this.ehrApiConfig.password
        }
      });
      
      return response.data.changes || [];
    } catch (error) {
      console.error('Failed to fetch encounter changes:', error.message);
      return [];
    }
  }
  
  private async processPatientBatch(batch: any[]): Promise<void> {
    // Map the EHR patient format to the canonical format
    const messages = batch.map(patient => ({
      key: patient.id,
      value: JSON.stringify({
        id: patient.id,
        resourceType: 'Patient',
        name: [
          {
            family: patient.lastName,
            given: [patient.firstName, patient.middleName].filter(Boolean)
          }
        ],
        gender: patient.gender,
        birthDate: patient.dateOfBirth,
        identifier: [
          {
            system: 'http://hospital.org/mrn',
            value: patient.mrn
          }
        ],
        telecom: [
          ...patient.phoneNumbers.map((phone: any) => ({
            system: 'phone',
            value: phone.number,
            use: phone.type.toLowerCase()
          })),
          ...patient.emailAddresses.map((email: any) => ({
            system: 'email',
            value: email
          }))
        ],
        address: patient.addresses.map((address: any) => ({
          line: [address.streetAddress],
          city: address.city,
          state: address.state,
          postalCode: address.zipCode,
          country: address.country
        })),
        active: patient.active,
        meta: {
          lastUpdated: patient.lastUpdated,
          source: 'EHR',
          versionId: patient.version
        }
      }),
      headers: {
        'source-system': 'ehr',
        'resource-type': 'Patient',
        'operation-type': patient.changeType.toLowerCase(),
        'correlation-id': uuidv4(),
        'timestamp': Buffer.from(Date.now().toString())
      }
    }));
    
    // Send to Kafka
    await this.producer.send({
      topic: `${this.targetTopic}.patient`,
      compression: CompressionTypes.GZIP,
      messages
    });
    
    console.log(`Published ${messages.length} patient changes to Kafka`);
  }
  
  private async processEncounterBatch(batch: any[]): Promise<void> {
    // Map the EHR encounter format to the canonical format
    const messages = batch.map(encounter => ({
      key: encounter.id,
      value: JSON.stringify({
        id: encounter.id,
        resourceType: 'Encounter',
        status: encounter.status,
        class: {
          system: 'http://terminology.hl7.org/CodeSystem/v3-ActCode',
          code: encounter.type,
          display: encounter.typeDisplay
        },
        subject: {
          reference: `Patient/${encounter.patientId}`
        },
        participant: encounter.providers.map((provider: any) => ({
          individual: {
            reference: `Practitioner/${provider.id}`
          },
          role: [
            {
              coding: [
                {
                  system: 'http://terminology.hl7.org/CodeSystem/v3-ParticipationType',
                  code: provider.role,
                  display: provider.roleDisplay
                }
              ]
            }
          ]
        })),
        period: {
          start: encounter.startDate,
          end: encounter.endDate
        },
        location: encounter.locations.map((location: any) => ({
          location: {
            reference: `Location/${location.id}`
          },
          status: 'completed'
        })),
        meta: {
          lastUpdated: encounter.lastUpdated,
          source: 'EHR',
          versionId: encounter.version
        }
      }),
      headers: {
        'source-system': 'ehr',
        'resource-type': 'Encounter',
        'operation-type': encounter.changeType.toLowerCase(),
        'correlation-id': uuidv4(),
        'timestamp': Buffer.from(Date.now().toString())
      }
    }));
    
    // Send to Kafka
    await this.producer.send({
      topic: `${this.targetTopic}.encounter`,
      compression: CompressionTypes.GZIP,
      messages
    });
    
    console.log(`Published ${messages.length} encounter changes to Kafka`);
  }
}

// Example usage
async function startEhrConnector() {
  const connector = new EhrSourceConnector({
    kafka: {
      clientId: 'ehr-source-connector',
      brokers: ['event-broker.cmm.internal:9092'],
      ssl: true,
      sasl: {
        mechanism: 'plain',
        username: process.env.KAFKA_USERNAME || '',
        password: process.env.KAFKA_PASSWORD || ''
      }
    },
    ehr: {
      baseUrl: process.env.EHR_API_URL || 'https://ehr-api.hospital.org',
      apiKey: process.env.EHR_API_KEY || '',
      username: process.env.EHR_API_USERNAME || '',
      password: process.env.EHR_API_PASSWORD || ''
    },
    connector: {
      topic: 'ehr.source',
      pollIntervalMs: 60000, // 1 minute
      batchSize: 100
      // initialTimestamp is optional, defaults to 24 hours ago
    }
  });
  
  await connector.start();
  
  // Handle shutdown
  process.on('SIGTERM', async () => {
    console.log('Shutting down EHR connector');
    await connector.stop();
    process.exit(0);
  });
  
  console.log('EHR connector started');
}

startEhrConnector().catch(error => {
  console.error('Failed to start EHR connector:', error);
  process.exit(1);
});
```

#### Schema Extensions

The Event Broker allows you to create custom schema extensions and validation rules specific to healthcare data.

**When to Use**:
- Implementing healthcare-specific data validation
- Extending schemas with additional metadata
- Adding domain-specific constraints to data schemas
- Implementing FHIR-compatible schemas

**Implementation Example**:

```typescript
import { SchemaRegistry, SchemaType } from '@kafkajs/confluent-schema-registry';
import * as avsc from 'avsc';
import axios from 'axios';

/**
 * Custom FHIR schema extension for Avro schemas in the Schema Registry
 */
class FhirSchemaExtension {
  private readonly schemaRegistry: SchemaRegistry;
  private readonly fhirServerUrl: string;
  
  constructor(registryConfig: any, fhirServerUrl: string) {
    this.schemaRegistry = new SchemaRegistry(registryConfig);
    this.fhirServerUrl = fhirServerUrl;
  }
  
  /**
   * Register a FHIR-compatible Avro schema
   */
  async registerFhirSchema(
    resourceType: string,
    schemaDefinition: any,
    subject: string,
    fhirMetadata: {
      profile?: string;
      implementationGuide?: string;
      version?: string;
      mappings?: Record<string, string>;
    }
  ) {
    // Add FHIR metadata to schema
    const schemaWithFhirMetadata = {
      ...schemaDefinition,
      fhirMetadata: {
        resourceType,
        profile: fhirMetadata.profile,
        implementationGuide: fhirMetadata.implementationGuide,
        version: fhirMetadata.version || 'R4',
        mappings: fhirMetadata.mappings || {}
      }
    };
    
    // Validate against FHIR specification if resource type is standard
    if (this.isStandardFhirResource(resourceType)) {
      await this.validateAgainstFhirSpec(resourceType, schemaWithFhirMetadata);
    }
    
    // Register schema
    const { id } = await this.schemaRegistry.register(
      schemaWithFhirMetadata,
      { subject, type: SchemaType.AVRO }
    );
    
    return {
      id,
      subject,
      resourceType,
      schema: schemaWithFhirMetadata
    };
  }
  
  /**
   * Create a converter between FHIR JSON and Avro
   */
  createFhirAvroConverter(schema: any) {
    // Parse the Avro schema
    const avroType = avsc.Type.forSchema(schema);
    
    // Create mapping functions based on schema metadata
    const fhirToAvro = this.buildFhirToAvroConverter(schema, avroType);
    const avroToFhir = this.buildAvroToFhirConverter(schema, avroType);
    
    return { fhirToAvro, avroToFhir };
  }
  
  /**
   * Validate a message against FHIR and Avro schemas
   */
  async validateFhirMessage(subject: string, message: any) {
    // Get the schema
    const { schema } = await this.schemaRegistry.getLatestSchemaId(subject);
    const parsedSchema = JSON.parse(schema);
    
    // Check if it's a FHIR schema
    if (!parsedSchema.fhirMetadata) {
      throw new Error('Not a FHIR schema');
    }
    
    const resourceType = parsedSchema.fhirMetadata.resourceType;
    
    // Validate against Avro schema
    const avroType = avsc.Type.forSchema(parsedSchema);
    const isValidAvro = avroType.isValid(message);
    
    // Validate against FHIR
    let fhirValidation = { valid: true, issues: [] };
    if (this.isStandardFhirResource(resourceType)) {
      fhirValidation = await this.validateFhirResource(resourceType, message);
    }
    
    return {
      valid: isValidAvro && fhirValidation.valid,
      avroValid: isValidAvro,
      fhirValid: fhirValidation.valid,
      issues: fhirValidation.issues
    };
  }
  
  /**
   * Create a new FHIR profile based on a base resource type
   */
  async createFhirProfile(
    baseResourceType: string,
    profileName: string,
    constraints: any[]
  ) {
    // Create a StructureDefinition resource for the profile
    const profile = {
      resourceType: 'StructureDefinition',
      url: `http://cmm.healthcare/fhir/StructureDefinition/${profileName}`,
      name: profileName,
      status: 'active',
      kind: 'resource',
      abstract: false,
      type: baseResourceType,
      baseDefinition: `http://hl7.org/fhir/StructureDefinition/${baseResourceType}`,
      derivation: 'constraint',
      differential: {
        element: constraints
      }
    };
    
    // In a real implementation, you would post this to a FHIR server
    console.log(`Created FHIR profile: ${profileName}`);
    
    return profile;
  }
  
  // Private helper methods
  
  private isStandardFhirResource(resourceType: string): boolean {
    // List of standard FHIR resource types
    const standardResources = [
      'Patient', 'Practitioner', 'Organization', 'Location',
      'Observation', 'Condition', 'Procedure', 'MedicationRequest',
      'Encounter', 'AllergyIntolerance', 'Immunization',
      // Add more as needed
    ];
    
    return standardResources.includes(resourceType);
  }
  
  private async validateAgainstFhirSpec(resourceType: string, schema: any): Promise<void> {
    try {
      // In a real implementation, you would validate the schema against 
      // the FHIR specification, perhaps using a FHIR validation service
      console.log(`Validating schema against FHIR spec for ${resourceType}`);
      
      // Example: check required fields for Patient
      if (resourceType === 'Patient') {
        const requiredFields = ['id', 'meta', 'resourceType'];
        
        for (const field of requiredFields) {
          if (!this.hasField(schema, field)) {
            throw new Error(`Schema missing required FHIR field: ${field}`);
          }
        }
      }
      
      // Additional validation logic would go here
    } catch (error) {
      console.error(`FHIR schema validation error: ${error.message}`);
      throw error;
    }
  }
  
  private async validateFhirResource(resourceType: string, resource: any): Promise<any> {
    try {
      // In a real implementation, you would call a FHIR validation service
      // This is just a simplified example
      
      if (resource.resourceType !== resourceType) {
        return {
          valid: false,
          issues: [{ severity: 'error', code: 'structure', diagnostics: 'Resource type mismatch' }]
        };
      }
      
      // For a real implementation, call a FHIR server's $validate endpoint
      /*
      const response = await axios.post(
        `${this.fhirServerUrl}/${resourceType}/$validate`,
        resource,
        {
          headers: {
            'Content-Type': 'application/fhir+json'
          }
        }
      );
      
      const operationOutcome = response.data;
      const hasErrors = operationOutcome.issue?.some(
        (issue: any) => issue.severity === 'error'
      );
      
      return {
        valid: !hasErrors,
        issues: operationOutcome.issue || []
      };
      */
      
      // Simplified validation for example
      return { valid: true, issues: [] };
    } catch (error) {
      console.error(`FHIR validation error: ${error.message}`);
      return {
        valid: false,
        issues: [{ 
          severity: 'error', 
          code: 'unknown', 
          diagnostics: `Validation error: ${error.message}` 
        }]
      };
    }
  }
  
  private hasField(schema: any, fieldName: string): boolean {
    if (!schema.fields) return false;
    
    return schema.fields.some((field: any) => field.name === fieldName);
  }
  
  private buildFhirToAvroConverter(schema: any, avroType: any) {
    // In a real implementation, you would build a converter based on the schema
    // This is a simplified example
    return (fhirResource: any) => {
      // Basic conversion for demonstration
      const result: any = {
        resourceType: fhirResource.resourceType
      };
      
      // Copy over fields based on mapping
      if (schema.fhirMetadata?.mappings) {
        for (const [avroField, fhirPath] of Object.entries(schema.fhirMetadata.mappings)) {
          const value = this.extractValueByPath(fhirResource, fhirPath as string);
          if (value !== undefined) {
            result[avroField] = value;
          }
        }
      }
      
      return result;
    };
  }
  
  private buildAvroToFhirConverter(schema: any, avroType: any) {
    // In a real implementation, you would build a converter based on the schema
    // This is a simplified example
    return (avroData: any) => {
      // Basic conversion for demonstration
      const result: any = {
        resourceType: schema.fhirMetadata.resourceType
      };
      
      // Copy over fields based on mapping
      if (schema.fhirMetadata?.mappings) {
        for (const [avroField, fhirPath] of Object.entries(schema.fhirMetadata.mappings)) {
          if (avroData[avroField] !== undefined) {
            this.setValueByPath(result, fhirPath as string, avroData[avroField]);
          }
        }
      }
      
      return result;
    };
  }
  
  private extractValueByPath(obj: any, path: string): any {
    const parts = path.split('.');
    let current = obj;
    
    for (const part of parts) {
      if (current === null || current === undefined) {
        return undefined;
      }
      
      current = current[part];
    }
    
    return current;
  }
  
  private setValueByPath(obj: any, path: string, value: any): void {
    const parts = path.split('.');
    let current = obj;
    
    for (let i = 0; i < parts.length - 1; i++) {
      const part = parts[i];
      
      if (current[part] === undefined) {
        current[part] = {};
      }
      
      current = current[part];
    }
    
    current[parts[parts.length - 1]] = value;
  }
}

// Example usage
async function exampleFhirSchemaUsage() {
  const fhirExtension = new FhirSchemaExtension(
    {
      host: 'https://schema-registry.cmm.internal',
      auth: {
        username: process.env.SCHEMA_REGISTRY_USERNAME,
        password: process.env.SCHEMA_REGISTRY_PASSWORD
      }
    },
    'https://fhir.cmm.healthcare/R4'
  );
  
  // Define a FHIR-compatible Avro schema for Patient
  const patientSchema = {
    type: 'record',
    name: 'Patient',
    namespace: 'com.healthcare.fhir',
    fields: [
      { name: 'id', type: 'string' },
      { name: 'resourceType', type: { type: 'enum', name: 'ResourceType', symbols: ['Patient'] } },
      { name: 'active', type: 'boolean', default: true },
      { 
        name: 'name', 
        type: { 
          type: 'array', 
          items: {
            type: 'record',
            name: 'HumanName',
            fields: [
              { name: 'family', type: ['null', 'string'], default: null },
              { 
                name: 'given', 
                type: { type: 'array', items: 'string' },
                default: []
              },
              { 
                name: 'use', 
                type: ['null', { 
                  type: 'enum', 
                  name: 'NameUse', 
                  symbols: ['usual', 'official', 'temp', 'nickname', 'anonymous', 'old', 'maiden'] 
                }],
                default: null
              }
            ]
          }
        },
        default: []
      },
      { name: 'gender', type: ['null', { type: 'enum', name: 'Gender', symbols: ['male', 'female', 'other', 'unknown'] }], default: null },
      { name: 'birthDate', type: ['null', 'string'], default: null },
      {
        name: 'meta',
        type: {
          type: 'record',
          name: 'Meta',
          fields: [
            { name: 'versionId', type: ['null', 'string'], default: null },
            { name: 'lastUpdated', type: ['null', 'string'], default: null }
          ]
        },
        default: { versionId: null, lastUpdated: null }
      }
    ]
  };
  
  // Register the schema
  const registeredSchema = await fhirExtension.registerFhirSchema(
    'Patient',
    patientSchema,
    'healthcare.patient-value',
    {
      profile: 'http://hl7.org/fhir/StructureDefinition/Patient',
      implementationGuide: 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-patient',
      version: 'R4',
      mappings: {
        'id': 'id',
        'active': 'active',
        'name[0].family': 'name.0.family',
        'name[0].given': 'name.0.given',
        'gender': 'gender',
        'birthDate': 'birthDate'
      }
    }
  );
  
  console.log(`Registered FHIR schema with ID: ${registeredSchema.id}`);
  
  // Create converters
  const { fhirToAvro, avroToFhir } = fhirExtension.createFhirAvroConverter(patientSchema);
  
  // Example FHIR Patient
  const fhirPatient = {
    resourceType: 'Patient',
    id: '12345',
    active: true,
    name: [
      {
        family: 'Smith',
        given: ['John', 'Jacob']
      }
    ],
    gender: 'male',
    birthDate: '1970-01-01'
  };
  
  // Convert FHIR to Avro format
  const avroPatient = fhirToAvro(fhirPatient);
  console.log('Converted to Avro format:', JSON.stringify(avroPatient, null, 2));
  
  // Convert back to FHIR
  const roundtripPatient = avroToFhir(avroPatient);
  console.log('Converted back to FHIR:', JSON.stringify(roundtripPatient, null, 2));
  
  // Validate FHIR message
  const validation = await fhirExtension.validateFhirMessage(
    'healthcare.patient-value',
    avroPatient
  );
  
  console.log('Validation result:', validation);
  
  // Create a custom FHIR profile
  const customProfile = await fhirExtension.createFhirProfile(
    'Patient',
    'CMM-Patient',
    [
      {
        id: 'Patient.cmm-1',
        path: 'Patient.identifier',
        min: 1,
        max: '*'
      },
      {
        id: 'Patient.cmm-2',
        path: 'Patient.name',
        min: 1,
        max: '*'
      }
    ]
  );
  
  console.log('Created custom FHIR profile');
}

exampleFhirSchemaUsage().catch(console.error);
```

## Best Practices for Extension Development

### Architecture Guidelines

1. **Follow Single Responsibility Principle**
   - Each extension should have a clear, focused purpose
   - Avoid creating monolithic extensions that try to do too much
   - Design extensions to work together through composition

2. **Use Standardized Interfaces**
   - Follow the existing interface patterns in the Event Broker
   - Document the interfaces your extension implements or provides
   - Maintain backward compatibility when updating extensions

3. **Ensure Testability**
   - Design extensions to be easily testable in isolation
   - Include comprehensive unit and integration tests
   - Consider using dependency injection for better testability

4. **Consider Performance Impact**
   - Evaluate the performance implications of your extensions
   - Optimize for the common case
   - Implement caching where appropriate
   - Add metrics to monitor extension performance

### Development Best Practices

1. **Error Handling**
   - Implement robust error handling in all extensions
   - Fail gracefully and provide meaningful error messages
   - Consider the impact of errors on the overall system
   - Include recovery mechanisms where possible

2. **Configuration Management**
   - Make extensions configurable through external configuration
   - Use sensible defaults for all configuration options
   - Validate configuration at startup
   - Document all configuration options

3. **Logging and Monitoring**
   - Include comprehensive logging in all extensions
   - Add metrics for key operations
   - Ensure extensions integrate with the Event Broker's monitoring system
   - Make logs and metrics consistent with the broader system

4. **Security Considerations**
   - Follow the principle of least privilege
   - Avoid handling sensitive data unless necessary
   - Implement appropriate authentication and authorization checks
   - Document security implications of your extensions

5. **Documentation**
   - Provide clear documentation on how to install, configure, and use the extension
   - Include examples of common usage patterns
   - Document any assumptions or limitations
   - Keep documentation up to date as the extension evolves

### Healthcare-Specific Extension Guidelines

1. **HIPAA Compliance**
   - Ensure extensions comply with HIPAA requirements for PHI
   - Implement appropriate data protection mechanisms
   - Document compliance considerations for extension users
   - Include audit logging for all PHI access

2. **Data Validation**
   - Validate healthcare data against industry standards (e.g., FHIR)
   - Implement data quality checks appropriate for healthcare data
   - Consider implementing validation against terminology services
   - Document validation requirements and limitations

3. **Interoperability**
   - Design extensions to work with healthcare interoperability standards
   - Consider integration with common healthcare systems
   - Support mapping between different healthcare data formats
   - Document interoperability capabilities and requirements

4. **Clinical Safety**
   - Consider the clinical safety implications of extensions
   - Implement appropriate checks for critical healthcare workflows
   - Document any safety-critical aspects of the extension
   - Provide clear guidance on safe usage patterns

## Related Resources
- [Event Broker Advanced Use Cases](./advanced-use-cases.md)
- [Event Broker Core APIs](../02-core-functionality/core-apis.md)
- [Event Broker Customization](./customization.md)
- [Topic Management](../02-core-functionality/topic-management.md)
- [Message Patterns](../02-core-functionality/message-patterns.md)
- [Confluent Kafka Connect Documentation](https://docs.confluent.io/platform/current/connect/index.html)
- [Kafka Streams Documentation](https://kafka.apache.org/documentation/streams/)