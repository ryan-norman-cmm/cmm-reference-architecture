# Event Broker Extension Points

## Introduction

This document outlines the extension points available in the Event Broker component of the CMM Technology Platform. These extension points enable customization and enhancement of the Event Broker's capabilities to meet specific healthcare requirements. By leveraging these extension mechanisms, developers can extend functionality without modifying the core system.

## Custom Serializers and Deserializers with Confluent Cloud

### Overview

Custom serializers and deserializers enable support for healthcare-specific data formats and optimized serialization when working with Confluent Cloud.

### Implementation with TypeScript

```typescript
// Example: Custom FHIR Resource Serializer with Schema Registry integration
import { SchemaRegistry } from '@kafkajs/confluent-schema-registry';
import { FhirResource } from 'fhir/r4';

/**
 * A custom serializer for FHIR resources that integrates with Confluent Cloud Schema Registry
 */
export class FhirResourceSerializer {
  private schemaRegistry: SchemaRegistry;
  private schemaId: number;
  
  /**
   * Create a new FHIR resource serializer
   * @param options Configuration options
   */
  constructor(options: { 
    schemaRegistry: SchemaRegistry; 
    schemaId?: number;
    schemaSubject?: string;
  }) {
    this.schemaRegistry = options.schemaRegistry;
    this.schemaId = options.schemaId || 0;
    
    // If schema ID is not provided but subject is, fetch the latest schema ID
    if (!this.schemaId && options.schemaSubject) {
      this.initializeFromSubject(options.schemaSubject);
    }
  }
  
  /**
   * Initialize the serializer with the latest schema ID for a subject
   */
  private async initializeFromSubject(subject: string): Promise<void> {
    try {
      const { id } = await this.schemaRegistry.getLatestSchemaId(subject);
      this.schemaId = id;
    } catch (error) {
      console.error(`Failed to get schema ID for subject ${subject}:`, error);
      throw new Error(`Schema initialization failed: ${error.message}`);
    }
  }
  
  /**
   * Serialize a FHIR resource to a buffer using Schema Registry
   */
  async serialize(topic: string, resource: FhirResource): Promise<Buffer> {
    if (!resource) {
      return null;
    }
    
    try {
      // Ensure we have a schema ID
      if (!this.schemaId) {
        throw new Error('Schema ID not initialized');
      }
      
      // Encode using Schema Registry
      return await this.schemaRegistry.encode(this.schemaId, resource);
    } catch (error) {
      console.error('Error serializing FHIR resource:', error);
      throw new Error(`Serialization failed: ${error.message}`);
    }
  }
}

/**
 * A custom deserializer for FHIR resources that integrates with Confluent Cloud Schema Registry
 */
export class FhirResourceDeserializer {
  private schemaRegistry: SchemaRegistry;
  
  /**
   * Create a new FHIR resource deserializer
   * @param options Configuration options
   */
  constructor(options: { schemaRegistry: SchemaRegistry }) {
    this.schemaRegistry = options.schemaRegistry;
  }
  
  /**
   * Deserialize a buffer to a FHIR resource using Schema Registry
   */
  async deserialize(message: { value: Buffer }): Promise<FhirResource> {
    if (!message || !message.value) {
      return null;
    }
    
    try {
      // Decode using Schema Registry - it automatically detects the schema ID
      return await this.schemaRegistry.decode(message.value) as FhirResource;
    } catch (error) {
      console.error('Error deserializing FHIR resource:', error);
      throw new Error(`Deserialization failed: ${error.message}`);
    }
  }
}
```

### Usage with Confluent Cloud

```typescript
import { Kafka } from 'kafkajs';
import { SchemaRegistry } from '@kafkajs/confluent-schema-registry';
import { FhirResourceSerializer, FhirResourceDeserializer } from './fhir-serializers';
import { FhirResource } from 'fhir/r4';

// Configure Confluent Cloud connection
const kafka = new Kafka({
  clientId: 'fhir-processor',
  brokers: ['${CONFLUENT_BOOTSTRAP_SERVERS}'],
  ssl: true,
  sasl: {
    mechanism: 'plain',
    username: '${CONFLUENT_CLOUD_KEY}',
    password: '${CONFLUENT_CLOUD_SECRET}'
  }
});

// Configure Schema Registry connection
const schemaRegistry = new SchemaRegistry({
  host: 'https://schema-registry.confluent.cloud',
  auth: {
    username: '${SCHEMA_REGISTRY_KEY}',
    password: '${SCHEMA_REGISTRY_SECRET}'
  }
});

// Create producer with custom serializer
async function createFhirProducer() {
  // Create the serializer with Schema Registry
  const serializer = new FhirResourceSerializer({
    schemaRegistry,
    schemaSubject: 'clinical.fhir.patient-value'
  });
  
  // Create the producer
  const producer = kafka.producer({
    allowAutoTopicCreation: false,
    idempotent: true, // Enable exactly-once semantics
    transactionalId: 'fhir-producer-tx' // Enable transactions
  });
  
  await producer.connect();
  
  // Function to send FHIR resources
  return {
    send: async (topic: string, key: string, resource: FhirResource) => {
      const value = await serializer.serialize(topic, resource);
      
      return producer.send({
        topic,
        messages: [{ key, value }]
      });
    },
    disconnect: async () => producer.disconnect()
  };
}

// Create consumer with custom deserializer
async function createFhirConsumer(groupId: string) {
  // Create the deserializer with Schema Registry
  const deserializer = new FhirResourceDeserializer({ schemaRegistry });
  
  // Create the consumer
  const consumer = kafka.consumer({
    groupId,
    sessionTimeout: 30000,
    maxWaitTimeInMs: 1000
  });
  
  await consumer.connect();
  
  return {
    subscribe: async (topics: string[]) => {
      await Promise.all(
        topics.map(topic => consumer.subscribe({ topic }))
      );
    },
    run: async (handler: (resource: FhirResource, topic: string, partition: number) => Promise<void>) => {
      await consumer.run({
        eachMessage: async ({ topic, partition, message }) => {
          const resource = await deserializer.deserialize(message);
          if (resource) {
            await handler(resource, topic, partition);
          }
        }
      });
    },
    disconnect: async () => consumer.disconnect()
  };
}

// Example usage
async function main() {
  // Create producer and consumer
  const producer = await createFhirProducer();
  const consumer = await createFhirConsumer('fhir-processor-group');
  
  // Subscribe to topics
  await consumer.subscribe(['clinical.fhir.patient']);
  
  // Process FHIR resources
  await consumer.run(async (resource, topic, partition) => {
    console.log(`Received FHIR resource from ${topic}-${partition}:`, resource.resourceType);
    
    // Process the resource...
    
    // Maybe produce a derived resource
    if (resource.resourceType === 'Patient') {
      // Create a derived resource
      const derivedResource: FhirResource = {
        resourceType: 'Patient',
        id: resource.id,
        // Add derived data...
      };
      
      await producer.send('clinical.fhir.processed', resource.id, derivedResource);
    }
  });
}
```

## Custom Partitioners with Confluent Cloud

### Overview

Custom partitioners enable healthcare-specific partitioning strategies for optimal data distribution and processing in Confluent Cloud.

### Implementation with TypeScript

```typescript
// Example: Patient-Encounter Partitioner for healthcare events
import { PartitionerArgs } from 'kafkajs';

/**
 * Custom partitioner for healthcare events that ensures related events
 * for the same patient or encounter are routed to the same partition
 */
export class PatientEncounterPartitioner {
  /**
   * Determine the partition for a message
   * @param args Partitioner arguments from KafkaJS
   */
  partition(args: PartitionerArgs): number {
    const { topic, partitionMetadata, message } = args;
    const numPartitions = partitionMetadata.length;
    
    // Handle case with no key
    if (!message.key) {
      // For messages without keys, distribute randomly but consistently based on value
      return this.hashBuffer(message.value) % numPartitions;
    }
    
    // Extract key as string
    const keyStr = message.key.toString();
    
    // Check if this is a healthcare event with our expected format
    if (this.isHealthcareEvent(keyStr)) {
      // Extract patient ID and/or encounter ID from the key
      const { patientId, encounterId } = this.extractIds(keyStr);
      
      // Use patient ID for partitioning to ensure all events for the same patient
      // go to the same partition for consistent processing
      if (patientId) {
        return this.hashString(patientId) % numPartitions;
      }
      
      // Fall back to encounter ID if patient ID is not available
      if (encounterId) {
        return this.hashString(encounterId) % numPartitions;
      }
    }
    
    // Default to standard key-based partitioning
    return this.hashBuffer(message.key) % numPartitions;
  }
  
  /**
   * Check if the key represents a healthcare event
   */
  private isHealthcareEvent(key: string): boolean {
    // Implement logic to determine if this is a healthcare event
    // For example, check if it follows a specific format or contains expected prefixes
    return key.includes(':') || key.match(/^(patient|encounter|visit|admission|p|e)\d+$/i) !== null;
  }
  
  /**
   * Extract patient ID and encounter ID from the key
   */
  private extractIds(key: string): { patientId?: string; encounterId?: string } {
    // Handle different key formats
    
    // Format: "patientId:encounterId"
    if (key.includes(':')) {
      const [patientId, encounterId] = key.split(':', 2);
      return { patientId, encounterId };
    }
    
    // Format: "patientId" or "p12345"
    if (key.match(/^(patient|p)\d+$/i)) {
      const patientId = key.replace(/^(patient|p)/i, '');
      return { patientId };
    }
    
    // Format: "encounterId" or "e12345"
    if (key.match(/^(encounter|visit|admission|e)\d+$/i)) {
      const encounterId = key.replace(/^(encounter|visit|admission|e)/i, '');
      return { encounterId };
    }
    
    // Default: treat the whole key as patient ID
    return { patientId: key };
  }
  
  /**
   * Create a hash from a string
   */
  private hashString(str: string): number {
    return this.hashBuffer(Buffer.from(str, 'utf8'));
  }
  
  /**
   * Create a hash from a buffer (using murmur2 algorithm)
   */
  private hashBuffer(buffer: Buffer): number {
    let hash = 0;
    for (let i = 0; i < buffer.length; i++) {
      hash = ((hash * 31) + buffer[i]) & 0x7fffffff;
    }
    return hash;
  }
}
```

### Usage with Confluent Cloud

```typescript
import { Kafka, Partitioners } from 'kafkajs';
import { PatientEncounterPartitioner } from './patient-encounter-partitioner';
import { FhirResourceSerializer } from './fhir-serializers';
import { SchemaRegistry } from '@kafkajs/confluent-schema-registry';

// Configure Confluent Cloud connection
const kafka = new Kafka({
  clientId: 'healthcare-producer',
  brokers: ['${CONFLUENT_BOOTSTRAP_SERVERS}'],
  ssl: true,
  sasl: {
    mechanism: 'plain',
    username: '${CONFLUENT_CLOUD_KEY}',
    password: '${CONFLUENT_CLOUD_SECRET}'
  }
});

// Configure Schema Registry connection
const schemaRegistry = new SchemaRegistry({
  host: 'https://schema-registry.confluent.cloud',
  auth: {
    username: '${SCHEMA_REGISTRY_KEY}',
    password: '${SCHEMA_REGISTRY_SECRET}'
  }
});

// Create serializer with Schema Registry
const serializer = new FhirResourceSerializer({
  schemaRegistry,
  schemaSubject: 'clinical.fhir.patient-value'
});

// Create custom partitioner
const patientPartitioner = new PatientEncounterPartitioner();

// Create producer with custom partitioner
async function createProducer() {
  const producer = kafka.producer({
    allowAutoTopicCreation: false,
    createPartitioner: () => patientPartitioner.partition.bind(patientPartitioner)
  });
  
  await producer.connect();
  
  return {
    sendPatientEvent: async (patientId: string, encounterId: string, resource: any) => {
      // Create composite key for consistent partitioning
      const key = `${patientId}:${encounterId || 'unknown'}`;
      
      // Serialize the resource
      const value = await serializer.serialize('clinical.fhir.patient', resource);
      
      // Send with the custom partitioner
      return producer.send({
        topic: 'clinical.fhir.patient',
        messages: [{
          key,
          value,
          headers: {
            'source': 'healthcare-app',
            'resource-type': resource.resourceType,
            'patient-id': patientId,
            'encounter-id': encounterId || ''
          }
        }]
      });
    },
    disconnect: async () => producer.disconnect()
  };
}

// Example usage
async function main() {
  const producer = await createProducer();
  
  // Send patient events - all events for the same patient will go to the same partition
  await producer.sendPatientEvent('P12345', 'E6789', {
    resourceType: 'Patient',
    id: 'P12345',
    // ... other patient data
  });
  
  await producer.disconnect();
}
```

### Confluent Cloud Partitioning Best Practices

1. **Balanced Partitioning**: Ensure your partitioning strategy distributes data evenly across partitions to avoid hotspots
2. **Co-partitioning**: Use the same partitioning key for related events to ensure they're processed together
3. **Partition Count**: Configure topics with appropriate partition counts in Confluent Cloud based on throughput requirements
4. **Monitoring**: Use Confluent Cloud metrics to monitor partition distribution and consumer lag
5. **Scaling**: Adjust partition count as your workload grows using Confluent Cloud's scaling capabilities

## Custom Interceptors with Confluent Cloud

### Overview

Custom interceptors enable monitoring, transformation, and filtering of events before they are produced or after they are consumed in Confluent Cloud environments.

### Implementation with TypeScript

```typescript
// Example: PHI Auditing Producer Interceptor for healthcare data
import { Producer, ProducerRecord, RecordMetadata, Message } from 'kafkajs';
import { v4 as uuidv4 } from 'uuid';
import { Logger } from 'winston';

/**
 * Interface for audit events generated when PHI data is accessed
 */
interface PhiAuditEvent {
  eventId: string;
  timestamp: number;
  clientId: string;
  topic: string;
  operation: 'PRODUCE' | 'CONSUME';
  key?: string;
  resourceType?: string;
  userId?: string;
  applicationId?: string;
  accessReason?: string;
  dataClassification: 'PHI' | 'PII' | 'SENSITIVE' | 'PUBLIC';
}

/**
 * Configuration options for the PHI auditing interceptor
 */
interface PhiAuditingInterceptorConfig {
  clientId: string;
  auditTopic: string;
  auditProducer: Producer;
  logger: Logger;
  phiTopicPatterns: RegExp[];
  userId?: string;
  applicationId?: string;
  accessReason?: string;
}

/**
 * A producer interceptor that audits access to PHI (Protected Health Information)
 * for compliance with healthcare regulations like HIPAA
 */
export class PhiAuditingProducerInterceptor {
  private config: PhiAuditingInterceptorConfig;
  
  /**
   * Create a new PHI auditing interceptor
   */
  constructor(config: PhiAuditingInterceptorConfig) {
    this.config = config;
  }
  
  /**
   * Intercept and audit messages before they are sent
   */
  async onSend(record: ProducerRecord): Promise<ProducerRecord> {
    // Check if the topic contains PHI data
    if (this.containsPhi(record.topic)) {
      // Create audit event
      const auditEvent: PhiAuditEvent = {
        eventId: uuidv4(),
        timestamp: Date.now(),
        clientId: this.config.clientId,
        topic: record.topic,
        operation: 'PRODUCE',
        dataClassification: 'PHI'
      };
      
      // Add additional context if available
      if (this.config.userId) auditEvent.userId = this.config.userId;
      if (this.config.applicationId) auditEvent.applicationId = this.config.applicationId;
      if (this.config.accessReason) auditEvent.accessReason = this.config.accessReason;
      
      // Extract message details
      if (record.messages && record.messages.length > 0) {
        const message = record.messages[0];
        
        // Add key if present
        if (message.key) {
          auditEvent.key = message.key.toString();
        }
        
        // Extract resource type from headers if available
        if (message.headers && message.headers['resource-type']) {
          auditEvent.resourceType = message.headers['resource-type'].toString();
        }
      }
      
      // Log the audit event
      this.config.logger.info('PHI access audit', { auditEvent });
      
      // Send audit event to audit topic asynchronously
      this.sendAuditEvent(auditEvent).catch(error => {
        this.config.logger.error('Failed to send audit event', { error, auditEvent });
      });
    }
    
    // Return the record unchanged
    return record;
  }
  
  /**
   * Handle acknowledgement of sent messages
   */
  onAcknowledgement(metadata: RecordMetadata, error?: Error): void {
    // No action needed for acknowledgements in this implementation
    // Could be extended to track failed PHI transmissions
  }
  
  /**
   * Check if a topic contains PHI data
   */
  private containsPhi(topic: string): boolean {
    // Check if topic matches any PHI patterns
    return this.config.phiTopicPatterns.some(pattern => pattern.test(topic));
  }
  
  /**
   * Send an audit event to the audit topic
   */
  private async sendAuditEvent(event: PhiAuditEvent): Promise<void> {
    try {
      await this.config.auditProducer.send({
        topic: this.config.auditTopic,
        messages: [{
          key: event.eventId,
          value: JSON.stringify(event),
          headers: {
            'event-type': 'phi-audit',
            'timestamp': event.timestamp.toString()
          }
        }]
      });
    } catch (error) {
      this.config.logger.error('Failed to send audit event', { error, event });
      throw error;
    }
  }
}
```

### Usage with Confluent Cloud

```typescript
// Configure producer with custom interceptor
Properties props = new Properties();
props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, "kafka-broker:9092");
props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, PatientEventSerializer.class.getName());
props.put(ProducerConfig.INTERCEPTOR_CLASSES_CONFIG, PhiAuditingProducerInterceptor.class.getName());

Producer<String, PatientEvent> producer = new KafkaProducer<>(props);
```

## Custom Connect Connectors

### Overview

Custom connectors enable integration with healthcare-specific systems and data sources.

### Implementation

```java
// Example: HL7 Source Connector
public class Hl7SourceConnector extends SourceConnector {
    
    private static final Logger logger = LoggerFactory.getLogger(Hl7SourceConnector.class);
    
    private Hl7SourceConnectorConfig config;
    
    @Override
    public void start(Map<String, String> props) {
        config = new Hl7SourceConnectorConfig(props);
        // Initialize HL7 connection
    }
    
    @Override
    public Class<? extends Task> taskClass() {
        return Hl7SourceTask.class;
    }
    
    @Override
    public List<Map<String, String>> taskConfigs(int maxTasks) {
        // Create task configurations
        List<Map<String, String>> taskConfigs = new ArrayList<>();
        
        // For HL7, we typically use one task per port/channel
        for (int i = 0; i < Math.min(maxTasks, config.getChannels().size()); i++) {
            Map<String, String> taskConfig = new HashMap<>(config.originalsStrings());
            taskConfig.put("channel.index", Integer.toString(i));
            taskConfigs.add(taskConfig);
        }
        
        return taskConfigs;
    }
    
    @Override
    public void stop() {
        // Clean up resources
    }
    
    @Override
    public ConfigDef config() {
        return Hl7SourceConnectorConfig.CONFIG_DEF;
    }
    
    @Override
    public String version() {
        return VersionUtil.getVersion();
    }
}

// Example: HL7 Source Task
public class Hl7SourceTask extends SourceTask {
    
    private static final Logger logger = LoggerFactory.getLogger(Hl7SourceTask.class);
    
    private Hl7SourceConnectorConfig config;
    private Hl7Receiver receiver;
    private BlockingQueue<SourceRecord> recordQueue;
    private int channelIndex;
    
    @Override
    public void start(Map<String, String> props) {
        config = new Hl7SourceConnectorConfig(props);
        channelIndex = Integer.parseInt(props.get("channel.index"));
        recordQueue = new LinkedBlockingQueue<>(config.getQueueCapacity());
        
        // Initialize and start HL7 receiver
        receiver = new Hl7Receiver(
            config.getChannels().get(channelIndex),
            config.getPort() + channelIndex,
            message -> handleHl7Message(message)
        );
        
        receiver.start();
    }
    
    @Override
    public List<SourceRecord> poll() throws InterruptedException {
        List<SourceRecord> records = new ArrayList<>();
        SourceRecord record = recordQueue.poll(100, TimeUnit.MILLISECONDS);
        
        if (record != null) {
            records.add(record);
            recordQueue.drainTo(records, config.getBatchSize() - 1);
        }
        
        return records;
    }
    
    private void handleHl7Message(String message) {
        try {
            // Parse HL7 message
            Hl7Message hl7 = Hl7Parser.parse(message);
            
            // Determine topic based on message type
            String topic = determineTopicForMessage(hl7);
            
            // Create source record
            SourceRecord record = new SourceRecord(
                sourcePartition(),
                sourceOffset(hl7),
                topic,
                null,  // partition will be determined by producer
                Schema.STRING_SCHEMA,
                hl7.getMessageControlId(),
                hl7SchemaFor(hl7),
                hl7
            );
            
            // Add to queue
            if (!recordQueue.offer(record, 30, TimeUnit.SECONDS)) {
                logger.warn("Failed to enqueue HL7 message - queue full");
            }
        } catch (Exception e) {
            logger.error("Error processing HL7 message", e);
        }
    }
    
    private Map<String, String> sourcePartition() {
        Map<String, String> partition = new HashMap<>();
        partition.put("channel", config.getChannels().get(channelIndex));
        return partition;
    }
    
    private Map<String, Object> sourceOffset(Hl7Message message) {
        Map<String, Object> offset = new HashMap<>();
        offset.put("message_control_id", message.getMessageControlId());
        offset.put("timestamp", message.getTimestamp());
        return offset;
    }
    
    private String determineTopicForMessage(Hl7Message message) {
        String messageType = message.getMessageType();
        String triggerEvent = message.getTriggerEvent();
        
        return String.format("hl7.%s.%s", 
            messageType.toLowerCase(), 
            triggerEvent.toLowerCase());
    }
    
    private Schema hl7SchemaFor(Hl7Message message) {
        // Return appropriate schema based on message type
        return Hl7Schemas.schemaFor(message.getMessageType(), message.getTriggerEvent());
    }
    
    @Override
    public void stop() {
        if (receiver != null) {
            receiver.stop();
        }
    }
    
    @Override
    public String version() {
        return VersionUtil.getVersion();
    }
}
```

### Usage

```json
// Connector configuration
{
  "name": "hl7-source",
  "config": {
    "connector.class": "com.healthcare.kafka.connect.hl7.Hl7SourceConnector",
    "tasks.max": "3",
    "channels": "ADT,ORM,ORU",
    "port": "2575",
    "batch.size": "100",
    "queue.capacity": "1000",
    "topic.prefix": "hl7."
  }
}
```

## Custom Stream Processors

### Overview

Custom stream processors enable complex event processing for healthcare-specific use cases.

### Implementation

```java
// Example: Clinical Alert Processor
public class ClinicalAlertProcessor implements Processor<String, VitalSign, String, ClinicalAlert> {
    
    private ProcessorContext<String, ClinicalAlert> context;
    private KeyValueStore<String, PatientState> stateStore;
    
    @Override
    public void init(ProcessorContext<String, ClinicalAlert> context) {
        this.context = context;
        this.stateStore = context.getStateStore("patient-state-store");
    }
    
    @Override
    public void process(Record<String, VitalSign> record) {
        String patientId = record.key();
        VitalSign vitalSign = record.value();
        
        // Get patient state
        PatientState state = stateStore.get(patientId);
        if (state == null) {
            state = new PatientState(patientId);
        }
        
        // Update patient state with new vital sign
        state.addVitalSign(vitalSign);
        stateStore.put(patientId, state);
        
        // Check for clinical alerts
        List<ClinicalAlert> alerts = checkForAlerts(patientId, vitalSign, state);
        
        // Forward alerts
        for (ClinicalAlert alert : alerts) {
            context.forward(
                new Record<>(patientId, alert, record.timestamp())
            );
        }
    }
    
    private List<ClinicalAlert> checkForAlerts(String patientId, 
                                             VitalSign vitalSign, 
                                             PatientState state) {
        List<ClinicalAlert> alerts = new ArrayList<>();
        
        // Check vital sign against normal ranges
        switch (vitalSign.getType()) {
            case "heart_rate":
                if (vitalSign.getValue() < 60 || vitalSign.getValue() > 100) {
                    alerts.add(new ClinicalAlert(
                        UUID.randomUUID().toString(),
                        patientId,
                        vitalSign.getValue() < 50 || vitalSign.getValue() > 120 ?
                            AlertSeverity.CRITICAL : AlertSeverity.WARNING,
                        String.format("Abnormal heart rate: %.1f bpm", vitalSign.getValue()),
                        vitalSign.getType(),
                        vitalSign.getValue(),
                        vitalSign.getUnit(),
                        System.currentTimeMillis()
                    ));
                }
                break;
                
            // Similar checks for other vital types
            // ...
        }
        
        // Check for trends and patterns
        if (state.hasVitalSignHistory(vitalSign.getType())) {
            List<VitalSign> history = state.getVitalSignHistory(vitalSign.getType());
            
            // Check for rapidly changing vitals
            if (history.size() >= 3) {
                VitalSign previous = history.get(history.size() - 1);
                VitalSign beforePrevious = history.get(history.size() - 2);
                
                double currentChange = Math.abs(vitalSign.getValue() - previous.getValue());
                double previousChange = Math.abs(previous.getValue() - beforePrevious.getValue());
                
                if (currentChange > 0.2 * previous.getValue() && 
                    previousChange > 0.2 * beforePrevious.getValue()) {
                    alerts.add(new ClinicalAlert(
                        UUID.randomUUID().toString(),
                        patientId,
                        AlertSeverity.WARNING,
                        String.format("Rapidly changing %s: %.1f %s", 
                            vitalSign.getType(), vitalSign.getValue(), vitalSign.getUnit()),
                        vitalSign.getType(),
                        vitalSign.getValue(),
                        vitalSign.getUnit(),
                        System.currentTimeMillis()
                    ));
                }
            }
        }
        
        return alerts;
    }
    
    @Override
    public void close() {
        // No resources to close
    }
}
```

### Usage

```java
// Define the streams topology
StreamsBuilder builder = new StreamsBuilder();

// Create a patient state store
StoreBuilder<KeyValueStore<String, PatientState>> storeBuilder =
    Stores.keyValueStoreBuilder(
        Stores.persistentKeyValueStore("patient-state-store"),
        Serdes.String(),
        patientStateSerde
    );
builder.addStateStore(storeBuilder);

// Define the processor topology
builder.stream("clinical.vitals.recorded", 
        Consumed.with(Serdes.String(), vitalSignSerde))
    .process(() -> new ClinicalAlertProcessor(), "patient-state-store")
    .to("clinical.alerts", 
        Produced.with(Serdes.String(), clinicalAlertSerde));
```

## Schema Registry Extensions

### Overview

Schema Registry extensions enable customization of schema validation, evolution, and compatibility rules.

### Implementation

```java
// Example: Healthcare Schema Validator
public class HealthcareSchemaValidator implements SchemaValidator {
    
    @Override
    public void validate(Schema schema, SchemaType schemaType) throws SchemaValidationException {
        // Perform basic schema validation
        if (schema == null) {
            throw new SchemaValidationException("Schema cannot be null");
        }
        
        // Healthcare-specific validation
        if (schemaType == SchemaType.AVRO) {
            validateAvroSchema((org.apache.avro.Schema) schema);
        } else if (schemaType == SchemaType.JSON) {
            validateJsonSchema((JsonSchema) schema);
        }
    }
    
    private void validateAvroSchema(org.apache.avro.Schema schema) throws SchemaValidationException {
        // Check for required healthcare fields in patient schemas
        if (schema.getName().equals("Patient")) {
            validateRequiredField(schema, "patientId");
            validateRequiredField(schema, "dateOfBirth");
            validateRequiredField(schema, "gender");
        }
        
        // Check for required fields in clinical event schemas
        if (schema.getName().endsWith("Event")) {
            validateRequiredField(schema, "eventId");
            validateRequiredField(schema, "timestamp");
            validateRequiredField(schema, "source");
        }
    }
    
    private void validateRequiredField(org.apache.avro.Schema schema, String fieldName) 
            throws SchemaValidationException {
        if (schema.getField(fieldName) == null) {
            throw new SchemaValidationException(
                String.format("Required field '%s' missing in schema '%s'", 
                    fieldName, schema.getName())
            );
        }
    }
    
    private void validateJsonSchema(JsonSchema schema) throws SchemaValidationException {
        // Implementation for JSON Schema validation
    }
}
```

### Usage

```java
// Register custom schema validator with Schema Registry
SchemaRegistry registry = new SchemaRegistry(config);
registry.registerSchemaValidator(new HealthcareSchemaValidator());
```

## Custom Security Extensions

### Overview

Security extensions enable customized authentication, authorization, and audit mechanisms for healthcare compliance.

### Implementation

```java
// Example: Healthcare Authorizer
public class HealthcareAuthorizer implements Authorizer {
    
    private static final Logger logger = LoggerFactory.getLogger(HealthcareAuthorizer.class);
    
    private SecurityService securityService;
    
    @Override
    public void configure(Map<String, ?> configs) {
        // Initialize security service
        securityService = new SecurityService(configs);
    }
    
    @Override
    public List<AuthorizationResult> authorize(AuthorizableRequestContext requestContext, 
                                              List<Action> actions) {
        // Get principal (user) from request context
        String principal = requestContext.principal().getName();
        
        // Authorize each action
        return actions.stream()
            .map(action -> authorizeAction(principal, action))
            .collect(Collectors.toList());
    }
    
    private AuthorizationResult authorizeAction(String principal, Action action) {
        try {
            // Get resource type and name
            ResourceType resourceType = action.resourcePattern().resourceType();
            String resourceName = action.resourcePattern().name();
            PatternType patternType = action.resourcePattern().patternType();
            AclOperation operation = action.operation();
            
            // Check if topic contains PHI
            boolean containsPhi = resourceType == ResourceType.TOPIC && 
                                 (resourceName.startsWith("clinical.") || 
                                  resourceName.startsWith("patient.") || 
                                  resourceName.startsWith("phi."));
            
            // Apply stricter rules for PHI topics
            if (containsPhi) {
                // Check if user has PHI access permission
                boolean hasPhiAccess = securityService.hasPermission(principal, "PHI_ACCESS");
                
                if (!hasPhiAccess) {
                    logger.warn("PHI access denied: principal={}, resource={}, operation={}", 
                        principal, resourceName, operation);
                    return AuthorizationResult.DENIED;
                }
                
                // For PHI topics, require explicit permissions
                boolean hasPermission = securityService.hasResourcePermission(
                    principal, resourceType.name(), resourceName, operation.name());
                
                if (!hasPermission) {
                    logger.warn("Resource access denied: principal={}, resource={}, operation={}", 
                        principal, resourceName, operation);
                    return AuthorizationResult.DENIED;
                }
                
                // Log PHI access for audit purposes
                securityService.logPhiAccess(principal, resourceType.name(), 
                    resourceName, operation.name());
            } else {
                // For non-PHI topics, use standard permission check
                boolean hasPermission = securityService.hasResourcePermission(
                    principal, resourceType.name(), resourceName, operation.name());
                
                if (!hasPermission) {
                    logger.warn("Resource access denied: principal={}, resource={}, operation={}", 
                        principal, resourceName, operation);
                    return AuthorizationResult.DENIED;
                }
            }
            
            return AuthorizationResult.ALLOWED;
        } catch (Exception e) {
            logger.error("Error during authorization", e);
            return AuthorizationResult.DENIED;
        }
    }
    
    @Override
    public void close() {
        if (securityService != null) {
            securityService.close();
        }
    }
}
```

### Usage

```properties
# Kafka broker configuration
authorizer.class.name=com.healthcare.kafka.security.HealthcareAuthorizer
security.protocol=SASL_SSL
ssl.keystore.location=/etc/kafka/secrets/kafka.keystore.jks
ssl.keystore.password=${file:/etc/kafka/secrets/kafka_keystore_credentials:password}
ssl.key.password=${file:/etc/kafka/secrets/kafka_sslkey_credentials:password}
ssl.truststore.location=/etc/kafka/secrets/kafka.truststore.jks
ssl.truststore.password=${file:/etc/kafka/secrets/kafka_truststore_credentials:password}
sasl.enabled.mechanisms=PLAIN
sasl.mechanism.inter.broker.protocol=PLAIN
listener.name.sasl_ssl.plain.sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required \
  username="admin" \
  password="${file:/etc/kafka/secrets/kafka_admin_credentials:password}" \
  user_admin="${file:/etc/kafka/secrets/kafka_admin_credentials:password}" \
  user_clinical="${file:/etc/kafka/secrets/kafka_clinical_credentials:password}" \
  user_analytics="${file:/etc/kafka/secrets/kafka_analytics_credentials:password}";
```

## Conclusion

The Event Broker provides numerous extension points that enable customization and enhancement to meet specific healthcare requirements. By leveraging these extension mechanisms, developers can extend functionality without modifying the core system, ensuring maintainability and compatibility with future updates. These extension points support healthcare-specific data formats, security requirements, integration patterns, and processing logic.

## Related Documentation

- [Event Broker Architecture](../01-getting-started/architecture.md)
- [Core APIs](../02-core-functionality/core-apis.md)
- [Advanced Use Cases](./advanced-use-cases.md)
- [Customization](./customization.md)
