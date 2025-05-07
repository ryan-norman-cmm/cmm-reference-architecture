# Event Broker Customization

## Introduction
The Event Broker component offers extensive customization options to adapt to specific healthcare workflows, data volumes, performance requirements, and integration needs. This document outlines the key areas where the Event Broker can be customized, configuration options, and best practices for implementing these customizations in a production environment.

## Customizable Elements

### Topic Configuration
- **Partitioning Strategy**: Configure the number of partitions and partitioning approach based on data distribution needs
- **Replication Factor**: Adjust replication for each topic based on data criticality and durability requirements
- **Retention Policy**: Customize retention periods (time or size-based) for different data types
- **Cleanup Policy**: Configure deletion or compaction for different use cases
- **Compression**: Select compression algorithms based on performance and storage tradeoffs

### Schema Management
- **Schema Evolution Rules**: Configure compatibility settings (backward, forward, full compatibility)
- **Custom Serializers**: Implement specialized serializers for healthcare-specific data formats
- **Schema Validation Rules**: Define custom validation rules for healthcare data schemas
- **Schema Registry Configuration**: Customize schema registry settings for your environment

### Message Processing
- **Consumer Group Configuration**: Customize consumer groups for specific processing needs
- **Processing Guarantees**: Configure at-least-once, at-most-once, or exactly-once semantics
- **Error Handling Strategies**: Implement custom error handling and retry logic
- **Dead Letter Queue Patterns**: Customize DLQ processing for specific failure modes

### Monitoring and Alerting
- **Custom Metrics**: Define domain-specific metrics for healthcare workflows
- **Alert Thresholds**: Configure alerting thresholds tailored to SLAs and operational requirements
- **Dashboard Templates**: Create specialized dashboards for different user roles and use cases
- **Log Processing**: Customize log processing and aggregation for event flows

### Security Controls
- **Authentication Mechanisms**: Configure authentication for different client types
- **Authorization Rules**: Define fine-grained access controls for topics and consumer groups
- **Encryption Settings**: Configure encryption options for sensitive healthcare data
- **Audit Logging**: Customize audit logging for compliance requirements

## Configuration Options

### Broker Configuration Options

Key broker configuration parameters that can be customized:

```properties
# Broker performance settings
num.network.threads=8
num.io.threads=16
socket.send.buffer.bytes=102400
socket.receive.buffer.bytes=102400
socket.request.max.bytes=104857600

# Log settings
num.partitions=12
log.retention.hours=168
log.segment.bytes=1073741824
log.retention.check.interval.ms=300000

# Topic defaults
default.replication.factor=3
min.insync.replicas=2

# Security settings
ssl.client.auth=required
sasl.enabled.mechanisms=PLAIN,SCRAM-SHA-256
authorizer.class.name=kafka.security.authorizer.AclAuthorizer
```

### Client Configuration Options

```typescript
// Producer configuration options
const producerConfig = {
  clientId: 'healthcare-event-producer',
  brokers: ['kafka-1:9092', 'kafka-2:9092', 'kafka-3:9092'],
  
  // Reliability settings
  acks: -1, // all brokers acknowledge (strongest guarantee)
  idempotent: true, // ensure exactly-once delivery
  maxInFlightRequests: 5,
  retries: 10,
  retry: {
    initialRetryTime: 100,
    retries: 10,
    factor: 2,
    multiplier: 1.5,
    maxRetryTime: 30000,
  },
  
  // Performance settings
  compression: CompressionTypes.GZIP,
  batchSize: 16384,
  linger: 10, // ms to wait for batch to fill
  
  // Security settings
  ssl: true,
  sasl: {
    mechanism: 'plain',
    username: process.env.KAFKA_USERNAME,
    password: process.env.KAFKA_PASSWORD
  },
};

// Consumer configuration options
const consumerConfig = {
  groupId: 'healthcare-event-consumer',
  clientId: 'healthcare-event-consumer-1',
  brokers: ['kafka-1:9092', 'kafka-2:9092', 'kafka-3:9092'],
  
  // Consumption behavior
  autoCommit: true,
  autoCommitInterval: 5000,
  autoCommitThreshold: 100,
  readUncommitted: false, // Read only committed messages
  allowAutoTopicCreation: false,
  maxBytes: 10485760, // 10MB maximum fetch size
  maxWaitTimeInMs: 1000,
  
  // Performance settings
  heartbeatInterval: 3000,
  sessionTimeout: 30000,
  rebalanceTimeout: 60000,
  
  // Security settings
  ssl: true,
  sasl: {
    mechanism: 'plain',
    username: process.env.KAFKA_USERNAME,
    password: process.env.KAFKA_PASSWORD
  },
};
```

### Schema Registry Configuration Options

```properties
# Schema Registry performance settings
schema.registry.connection.pool.size=20
schema.registry.connection.pool.timeout.ms=1000
schema.registry.connection.timeout.ms=30000
schema.registry.read.timeout.ms=30000

# Schema compatibility settings
avro.compatibility.level=BACKWARD

# Authentication settings
authentication.method=BASIC
authentication.roles=ADMIN,DEVELOPER,READONLY
authentication.realm=SchemaRegistry

# CORS settings
access.control.allow.methods=GET,POST,PUT,DELETE
access.control.allow.origin=*
```

### Topic-Specific Configurations

Example of topic configuration for different healthcare data types:

```typescript
// High throughput, short retention for monitoring data
const monitoringTopicConfig = {
  topic: 'healthcare.monitoring.events',
  numPartitions: 24,
  replicationFactor: 3,
  configEntries: [
    { name: 'retention.ms', value: '86400000' }, // 1 day
    { name: 'cleanup.policy', value: 'delete' },
    { name: 'compression.type', value: 'lz4' },
    { name: 'min.insync.replicas', value: '2' },
    { name: 'max.message.bytes', value: '1000000' }
  ]
};

// Long-term retention for patient events
const patientTopicConfig = {
  topic: 'healthcare.patient.events',
  numPartitions: 12,
  replicationFactor: 3,
  configEntries: [
    { name: 'retention.ms', value: '7776000000' }, // 90 days
    { name: 'cleanup.policy', value: 'delete' },
    { name: 'compression.type', value: 'zstd' },
    { name: 'min.insync.replicas', value: '2' },
    { name: 'max.message.bytes', value: '2000000' }
  ]
};

// Compacted topic for reference data
const referenceDataTopicConfig = {
  topic: 'healthcare.reference.data',
  numPartitions: 6,
  replicationFactor: 3,
  configEntries: [
    { name: 'cleanup.policy', value: 'compact' },
    { name: 'min.cleanable.dirty.ratio', value: '0.5' },
    { name: 'delete.retention.ms', value: '86400000' }, // 1 day tombstone retention
    { name: 'segment.ms', value: '86400000' }, // New segment daily
    { name: 'min.insync.replicas', value: '2' }
  ]
};
```

## Example Customizations

### Custom Dead Letter Queue Handler

```typescript
import { Kafka, CompressionTypes } from 'kafkajs';

// Initialize Kafka client
const kafka = new Kafka({
  clientId: 'dlq-handler',
  brokers: ['event-broker.cmm.internal:9092'],
  ssl: true,
  sasl: {
    mechanism: 'plain',
    username: process.env.KAFKA_USERNAME,
    password: process.env.KAFKA_PASSWORD
  },
});

// Create producer and consumer
const producer = kafka.producer();
const consumer = kafka.consumer({ groupId: 'dlq-handler' });

// Initialize DLQ handler
async function initDLQHandler() {
  await producer.connect();
  await consumer.connect();
  
  // Subscribe to all DLQ topics
  await consumer.subscribe({ 
    topics: [/.*\.dlq$/], // Regex for all topics ending with .dlq
    fromBeginning: true 
  });
  
  // Create error categories and handlers
  const errorHandlers = {
    'schema-validation': handleSchemaValidationError,
    'business-rule': handleBusinessRuleError,
    'system-error': handleSystemError,
    'transient-error': handleTransientError,
    'default': handleDefaultError
  };
  
  // Process DLQ messages
  await consumer.run({
    eachMessage: async ({ topic, partition, message }) => {
      try {
        console.log(`Processing DLQ message from ${topic} [${partition}] at offset ${message.offset}`);
        
        // Parse original message and error details
        const originalTopic = topic.replace(/\.dlq$/, '');
        const errorType = message.headers['error-type']?.toString() || 'default';
        const errorMessage = message.headers['error-message']?.toString();
        const attemptCount = parseInt(message.headers['attempt-count']?.toString() || '0', 10);
        
        console.log(`Error type: ${errorType}, Message: ${errorMessage}, Attempts: ${attemptCount}`);
        
        // Use the appropriate handler based on error type
        if (errorHandlers[errorType]) {
          await errorHandlers[errorType](originalTopic, message, attemptCount);
        } else {
          await errorHandlers['default'](originalTopic, message, attemptCount);
        }
      } catch (error) {
        console.error('Error processing DLQ message:', error);
      }
    }
  });
}

// Error handlers for different error types
async function handleSchemaValidationError(originalTopic: string, message: any, attemptCount: number) {
  // Log the schema validation error for manual correction
  console.log(`Schema validation error in message for ${originalTopic}`);
  
  // Store in error database for analysis
  await storeErrorForAnalysis({
    errorType: 'schema-validation',
    originalTopic,
    key: message.key?.toString(),
    value: message.value?.toString(),
    headers: message.headers,
    errorDetails: message.headers['error-message']?.toString(),
    timestamp: Date.now(),
    attemptCount
  });
  
  // Notify data governance team
  await sendNotification('data-governance', {
    subject: `Schema validation error in ${originalTopic}`,
    body: `Message failed schema validation: ${message.headers['error-message']?.toString()}`,
    severity: 'warning'
  });
}

async function handleBusinessRuleError(originalTopic: string, message: any, attemptCount: number) {
  console.log(`Business rule violation in message for ${originalTopic}`);
  
  // Store for manual review
  await storeErrorForAnalysis({
    errorType: 'business-rule',
    originalTopic,
    key: message.key?.toString(),
    value: message.value?.toString(),
    headers: message.headers,
    errorDetails: message.headers['error-message']?.toString(),
    timestamp: Date.now(),
    attemptCount
  });
  
  // Create incident for business analyst review
  await createBusinessRuleIncident(originalTopic, message);
}

async function handleTransientError(originalTopic: string, message: any, attemptCount: number) {
  console.log(`Transient error in message for ${originalTopic}, attempt ${attemptCount}`);
  
  // Implement retry with exponential backoff
  if (attemptCount < 5) {
    // Calculate backoff time
    const backoffMs = Math.min(1000 * Math.pow(2, attemptCount), 60000); // Max 1 minute
    
    // Wait for backoff period
    await new Promise(resolve => setTimeout(resolve, backoffMs));
    
    // Retry by republishing to original topic
    await producer.send({
      topic: originalTopic,
      messages: [
        {
          key: message.key,
          value: message.value,
          headers: {
            ...message.headers,
            'attempt-count': Buffer.from(String(attemptCount + 1)),
            'retry-timestamp': Buffer.from(String(Date.now()))
          }
        }
      ]
    });
    
    console.log(`Retried message to ${originalTopic}, attempt ${attemptCount + 1}`);
  } else {
    // Max retries exceeded, handle as permanent failure
    await handleSystemError(originalTopic, message, attemptCount);
  }
}

async function handleSystemError(originalTopic: string, message: any, attemptCount: number) {
  console.log(`System error in message for ${originalTopic}`);
  
  // Store for analysis
  await storeErrorForAnalysis({
    errorType: 'system-error',
    originalTopic,
    key: message.key?.toString(),
    value: message.value?.toString(),
    headers: message.headers,
    errorDetails: message.headers['error-message']?.toString(),
    timestamp: Date.now(),
    attemptCount
  });
  
  // Create incident ticket for engineering
  await createSystemErrorIncident(originalTopic, message);
  
  // Send alert
  await sendNotification('engineering', {
    subject: `System error in ${originalTopic}`,
    body: `Message processing failed: ${message.headers['error-message']?.toString()}`,
    severity: 'error'
  });
}

async function handleDefaultError(originalTopic: string, message: any, attemptCount: number) {
  console.log(`Unclassified error in message for ${originalTopic}`);
  
  // Store for analysis
  await storeErrorForAnalysis({
    errorType: 'unclassified',
    originalTopic,
    key: message.key?.toString(),
    value: message.value?.toString(),
    headers: message.headers,
    errorDetails: message.headers['error-message']?.toString(),
    timestamp: Date.now(),
    attemptCount
  });
  
  // Send notification for review
  await sendNotification('operations', {
    subject: `Unclassified error in ${originalTopic}`,
    body: `Message processing failed with unclassified error: ${message.headers['error-message']?.toString()}`,
    severity: 'warning'
  });
}

// Mock implementation of helper functions
async function storeErrorForAnalysis(errorData: any) {
  // In a real implementation, this would store to a database
  console.log('Storing error for analysis:', JSON.stringify(errorData, null, 2));
}

async function createBusinessRuleIncident(topic: string, message: any) {
  // In a real implementation, this would create a ticket in a system like JIRA
  console.log(`Creating business rule incident for ${topic}`);
}

async function createSystemErrorIncident(topic: string, message: any) {
  // In a real implementation, this would create a ticket in a system like JIRA
  console.log(`Creating system error incident for ${topic}`);
}

async function sendNotification(team: string, notification: any) {
  // In a real implementation, this would send to a notification system
  console.log(`Sending notification to ${team}:`, JSON.stringify(notification, null, 2));
}

// Start the DLQ handler
initDLQHandler().catch(console.error);
```

### Custom Schema Registry Client

```typescript
import axios from 'axios';
import { SchemaType } from '@kafkajs/confluent-schema-registry';

/**
 * Extended Schema Registry Client with healthcare-specific functionality
 */
class HealthcareSchemaRegistry {
  private baseUrl: string;
  private auth: { username: string; password: string };
  
  constructor(options: {
    host: string;
    auth: { username: string; password: string };
  }) {
    this.baseUrl = options.host;
    this.auth = options.auth;
  }
  
  /**
   * Register a schema with healthcare-specific metadata
   */
  async registerHealthcareSchema(
    schema: object,
    subject: string,
    schemaType: SchemaType,
    metadata: {
      dataClassification: 'PHI' | 'PII' | 'SENSITIVE' | 'PUBLIC';
      owner: string;
      businessDomain: string;
      retentionPolicy: string;
      regulatoryImplications: string[];
    }
  ) {
    try {
      // Add healthcare metadata to schema
      const schemaWithMetadata = {
        ...schema,
        metadata: {
          healthcareMetadata: metadata
        }
      };
      
      // Register schema with registry
      const response = await axios({
        method: 'post',
        url: `${this.baseUrl}/subjects/${subject}/versions`,
        auth: {
          username: this.auth.username,
          password: this.auth.password
        },
        data: {
          schemaType: schemaType.toString(),
          schema: JSON.stringify(schemaWithMetadata)
        }
      });
      
      // Log healthcare schema registration
      console.log(`Registered healthcare schema for ${subject} with ID ${response.data.id}`);
      console.log(`Data classification: ${metadata.dataClassification}`);
      console.log(`Regulatory implications: ${metadata.regulatoryImplications.join(', ')}`);
      
      // Store additional metadata in registry metadata API if available
      try {
        await axios({
          method: 'post',
          url: `${this.baseUrl}/subjects/${subject}/meta`,
          auth: {
            username: this.auth.username,
            password: this.auth.password
          },
          data: {
            healthcareMetadata: metadata
          }
        });
      } catch (metaError) {
        console.warn('Could not store additional metadata in registry:', metaError.message);
      }
      
      return response.data;
    } catch (error) {
      console.error('Error registering healthcare schema:', error);
      throw error;
    }
  }
  
  /**
   * Validate that a message conforms to healthcare standards
   */
  async validateHealthcareMessage(subject: string, message: any) {
    try {
      // Get the latest schema
      const response = await axios({
        method: 'get',
        url: `${this.baseUrl}/subjects/${subject}/versions/latest`,
        auth: {
          username: this.auth.username,
          password: this.auth.password
        }
      });
      
      const schema = JSON.parse(response.data.schema);
      
      // Perform basic Avro validation
      // In a real implementation, use a proper Avro validation library
      const validationResult = this.validateAgainstAvroSchema(schema, message);
      
      // Perform healthcare-specific validation
      const healthcareValidation = this.validateHealthcareRules(schema, message);
      
      return {
        isValid: validationResult.isValid && healthcareValidation.isValid,
        errors: [...validationResult.errors, ...healthcareValidation.errors]
      };
    } catch (error) {
      console.error('Error validating healthcare message:', error);
      throw error;
    }
  }
  
  /**
   * Healthcare-specific validation rules
   */
  private validateHealthcareRules(schema: any, message: any) {
    const errors = [];
    
    // Check if schema has healthcare metadata
    if (!schema.metadata?.healthcareMetadata) {
      errors.push('Schema does not contain healthcare metadata');
      return { isValid: errors.length === 0, errors };
    }
    
    const metadata = schema.metadata.healthcareMetadata;
    
    // PHI validation rules
    if (metadata.dataClassification === 'PHI') {
      // Check for patient identifiers
      if (message.patientId && !this.isProperlyEncrypted(message.patientId)) {
        errors.push('Patient identifier must be encrypted or tokenized');
      }
      
      // Check for appropriate consent flags
      if (message.consentVerified !== true) {
        errors.push('PHI data requires verified consent flag');
      }
    }
    
    // PII validation rules
    if (metadata.dataClassification === 'PII') {
      // Check for PII masking
      ['ssn', 'dob', 'address'].forEach(field => {
        if (message[field] && !this.isProperlyMasked(message[field], field)) {
          errors.push(`PII field '${field}' must be properly masked`);
        }
      });
    }
    
    return {
      isValid: errors.length === 0,
      errors
    };
  }
  
  // Mock implementations of helper methods
  
  private validateAgainstAvroSchema(schema: any, message: any) {
    // In a real implementation, use a proper Avro validation library
    console.log('Validating message against Avro schema');
    return { isValid: true, errors: [] };
  }
  
  private isProperlyEncrypted(value: any) {
    // In a real implementation, check for encryption pattern
    return typeof value === 'string' && value.startsWith('ENC:');
  }
  
  private isProperlyMasked(value: any, fieldType: string) {
    // In a real implementation, check for appropriate masking pattern
    if (fieldType === 'ssn') {
      return typeof value === 'string' && /^\*{5}\d{4}$/.test(value);
    }
    return true;
  }
}

// Example usage
async function exampleUsage() {
  const healthcareRegistry = new HealthcareSchemaRegistry({
    host: 'https://schema-registry.cmm.internal',
    auth: {
      username: process.env.SCHEMA_REGISTRY_USERNAME || '',
      password: process.env.SCHEMA_REGISTRY_PASSWORD || ''
    }
  });
  
  // Register a healthcare schema
  const patientSchema = {
    type: 'record',
    name: 'Patient',
    namespace: 'com.healthcare.patient',
    fields: [
      { name: 'id', type: 'string' },
      { name: 'patientId', type: 'string' },
      { name: 'firstName', type: 'string' },
      { name: 'lastName', type: 'string' },
      { name: 'dob', type: 'string' },
      { name: 'ssn', type: ['null', 'string'], default: null },
      { name: 'consentVerified', type: 'boolean' }
    ]
  };
  
  await healthcareRegistry.registerHealthcareSchema(
    patientSchema,
    'patient-records-value',
    SchemaType.AVRO,
    {
      dataClassification: 'PHI',
      owner: 'patient-services-team',
      businessDomain: 'patient-management',
      retentionPolicy: '7-years',
      regulatoryImplications: ['HIPAA', 'HITECH']
    }
  );
  
  // Validate a message
  const validationResult = await healthcareRegistry.validateHealthcareMessage(
    'patient-records-value',
    {
      id: '12345',
      patientId: 'ENC:AES256:12345',
      firstName: 'John',
      lastName: 'Doe',
      dob: '1980-01-01',
      ssn: '*****1234',
      consentVerified: true
    }
  );
  
  console.log('Validation result:', validationResult);
}

exampleUsage().catch(console.error);
```

### Custom Monitoring Dashboard Configuration

```typescript
import { Kafka } from 'kafkajs';
import { client as PrometheusClient, Counter, Gauge, register } from 'prom-client';
import express from 'express';

// Initialize Kafka client
const kafka = new Kafka({
  clientId: 'kafka-monitoring',
  brokers: ['event-broker.cmm.internal:9092'],
  // Auth configuration
});

// Create metrics
const messageCounter = new Counter({
  name: 'kafka_messages_total',
  help: 'Total number of Kafka messages',
  labelNames: ['topic', 'status', 'business_domain']
});

const messageSizeGauge = new Gauge({
  name: 'kafka_message_size_bytes',
  help: 'Size of Kafka messages in bytes',
  labelNames: ['topic']
});

const processingTimeHistogram = register.createHistogram({
  name: 'kafka_message_processing_duration_seconds',
  help: 'Time taken to process Kafka messages',
  labelNames: ['topic', 'consumer_group'],
  buckets: [0.1, 0.5, 1, 2, 5, 10, 20, 30, 60]
});

const consumerLagGauge = new Gauge({
  name: 'kafka_consumer_lag',
  help: 'Lag of consumer groups by topic-partition',
  labelNames: ['topic', 'partition', 'consumer_group']
});

// Configure business domain mapping
const topicToDomainMap: Record<string, string> = {
  'patient.events': 'patient-management',
  'medication.order.events': 'medication-management',
  'authorization.events': 'auth-management',
  'claim.events': 'financial'
};

function getBusinessDomain(topic: string): string {
  // Look for exact match
  if (topicToDomainMap[topic]) {
    return topicToDomainMap[topic];
  }
  
  // Look for pattern match
  for (const [pattern, domain] of Object.entries(topicToDomainMap)) {
    if (topic.includes(pattern.split('.')[0])) {
      return domain;
    }
  }
  
  return 'unknown';
}

// Hook up a consumer to collect metrics
async function monitorKafkaTopics() {
  const admin = kafka.admin();
  await admin.connect();
  
  // Setup consumer lag monitoring
  setInterval(async () => {
    try {
      // Get all consumer groups
      const consumerGroups = await admin.listGroups();
      
      for (const group of consumerGroups.groups) {
        // Skip internal groups
        if (group.groupId.startsWith('_')) continue;
        
        // Get offset information for this group
        const offsetInfo = await admin.fetchOffsetsByGroup(group.groupId);
        
        // Get latest offsets for each topic-partition
        for (const { topic, partitions } of offsetInfo.topics) {
          const latestOffsets = await admin.fetchTopicOffsets(topic);
          
          // Calculate and record lag for each partition
          for (const partition of partitions) {
            const latestOffset = latestOffsets.find(o => 
              o.partition === partition.partition
            )?.offset || '0';
            
            const committedOffset = partition.offset;
            const lag = parseInt(latestOffset, 10) - parseInt(committedOffset, 10);
            
            consumerLagGauge.set(
              { topic, partition: partition.partition, consumer_group: group.groupId },
              lag
            );
          }
        }
      }
    } catch (error) {
      console.error('Error collecting consumer lag metrics:', error);
    }
  }, 60000); // Check every minute
  
  // Producer middleware for collecting metrics
  const producerMiddleware = {
    async beforeSend({ topic, messages, ...rest }: any) {
      messages.forEach((message: any) => {
        // Increment message counter
        messageCounter.inc({
          topic,
          status: 'produced',
          business_domain: getBusinessDomain(topic)
        });
        
        // Record message size
        const messageSize = 
          (message.key ? message.key.length : 0) +
          (message.value ? message.value.length : 0);
        
        messageSizeGauge.set({ topic }, messageSize);
      });
      
      return { topic, messages, ...rest };
    }
  };
  
  // Consumer middleware for collecting metrics
  const consumerMiddleware = {
    async beforeEachMessage({ topic, partition, message, heartbeat, ...rest }: any) {
      const startTime = Date.now();
      
      // Pass to next middleware
      const result = await heartbeat({ topic, partition, message, heartbeat, ...rest });
      
      // Record processing time
      const processingTime = (Date.now() - startTime) / 1000; // Convert to seconds
      processingTimeHistogram.observe(
        { topic, consumer_group: this.groupId },
        processingTime
      );
      
      // Increment message counter
      messageCounter.inc({
        topic,
        status: 'consumed',
        business_domain: getBusinessDomain(topic)
      });
      
      return result;
    }
  };
  
  // Expose metrics endpoint
  const app = express();
  app.get('/metrics', async (req, res) => {
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
  });
  
  app.listen(9090, () => {
    console.log('Metrics server listening on port 9090');
  });
  
  console.log('Kafka monitoring setup complete');
  
  // Return middleware that can be applied to producers and consumers
  return {
    producerMiddleware,
    consumerMiddleware
  };
}

// Example of using the monitoring setup
async function setupMonitoredProducer() {
  const { producerMiddleware } = await monitorKafkaTopics();
  
  const producer = kafka.producer();
  
  // Apply monitoring middleware
  producer.on('producer.connect', () => {
    producer.appendMiddleware(producerMiddleware);
  });
  
  await producer.connect();
  
  // Use producer as normal
  // ...
}

setupMonitoredProducer().catch(console.error);
```

## Best Practices

### Topic Configuration Best Practices

1. **Right-Size Partitions**
   - Base partition count on throughput requirements and consumer parallelism
   - Start with fewer partitions (6-12) and increase when needed
   - Consider one partition per 10-30 MB/sec throughput
   - Factor in consumer scaling plans

2. **Topic Naming Conventions**
   - Use consistent, hierarchical naming patterns (e.g., `domain.entity.action`)
   - Include version in topic name for breaking schema changes
   - Use lowercase letters, periods for hierarchy, and hyphens within segments
   - Document naming standards and enforce through automation

3. **Optimal Retention Settings**
   - Set retention based on data usage patterns, not just storage constraints
   - Consider different retention policies for different data types
   - For reference data, prefer compact topics over delete
   - Monitor and adjust retention settings based on actual usage

4. **Replication Guidelines**
   - Use replication factor 3 for production topics with important data
   - Balance durability with performance and storage requirements
   - Consider lower replication (RF=2) for high-volume, transient data
   - Ensure min.insync.replicas is set appropriately (usually RF-1)

### Schema Management Best Practices

1. **Schema Evolution Strategy**
   - Start with BACKWARD compatibility for most topics
   - Use schema versioning for breaking changes
   - Make additive changes (new optional fields) rather than modifying existing fields
   - Include clear documentation in schema definitions

2. **Healthcare Data Schemas**
   - Include standardized metadata fields (sourceSystem, timestamp, correlationId)
   - Define explicit validation rules for healthcare-specific fields
   - Document mapping to healthcare standards (FHIR, HL7, etc.)
   - Include security classification in schema metadata

3. **Performance Considerations**
   - Balance schema validation with performance requirements
   - Consider using simpler schemas for high-volume data
   - Optimize serialization/deserialization for critical paths
   - Use schema caching to reduce registry calls

### Security Best Practices

1. **Authentication and Authorization**
   - Use strong authentication mechanisms (SASL/SCRAM or mTLS)
   - Implement fine-grained ACLs for topic-level access control
   - Rotate credentials regularly
   - Use service accounts with minimal permissions

2. **Network Security**
   - Enforce TLS for all client connections
   - Use private networking for broker-to-broker communication
   - Implement network segmentation between environments
   - Consider using proxies for external access

3. **Data Protection**
   - Encrypt sensitive data within messages
   - Use field-level encryption for PHI/PII
   - Implement data masking for sensitive fields
   - Audit access to sensitive topics

4. **Monitoring and Auditing**
   - Enable comprehensive audit logging
   - Monitor for unusual access patterns
   - Set up alerts for security-related events
   - Regularly review security configurations

### Operational Best Practices

1. **Monitoring and Alerting**
   - Monitor both broker and client-side metrics
   - Set up alerts for consumer lag exceeding thresholds
   - Track error rates and performance metrics
   - Create domain-specific dashboards for different user roles

2. **Error Handling**
   - Implement consistent error handling patterns
   - Use dead letter queues for failed messages
   - Categorize errors for appropriate handling (retry vs. alert)
   - Log sufficient context for debugging

3. **Capacity Planning**
   - Monitor growth trends in volume and throughput
   - Plan for peak traffic plus headroom (at least 30%)
   - Consider throughput, storage, and consumer capacity
   - Test performance under various load conditions

4. **Disaster Recovery**
   - Implement multi-region replication for critical topics
   - Define and test recovery procedures
   - Document RTO/RPO objectives for different data types
   - Regularly test backup and restore processes

## Related Resources
- [Event Broker Advanced Use Cases](./advanced-use-cases.md)
- [Event Broker Core APIs](../02-core-functionality/core-apis.md)
- [Topic Management](../02-core-functionality/topic-management.md)
- [Message Patterns](../02-core-functionality/message-patterns.md)
- [Schema Registry Management](../04-governance-compliance/schema-registry-management.md)
- [Confluent Kafka Configuration](https://docs.confluent.io/platform/current/installation/configuration/index.html)
- [KafkaJS Configuration](https://kafka.js.org/docs/configuration)