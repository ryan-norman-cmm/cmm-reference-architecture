# Event Broker Topic Management

## Introduction
This document describes the topic management capabilities of the Event Broker component, including topic creation, configuration, monitoring, and governance. Topics are the fundamental organizational unit in Kafka, serving as named feeds or channels for events. Proper topic management is essential for ensuring performance, reliability, and security of the event streaming platform.

## Topic Naming Conventions

All topics in the Event Broker follow a standardized naming convention to ensure consistency, discoverability, and proper governance:

### Naming Pattern
```
<domain>.<entity>.<action>
```

- **Domain**: Business or technical domain (e.g., `patient`, `provider`, `medication`, `fhir`, `workflow`)
- **Entity**: The primary entity or resource represented (e.g., `profile`, `order`, `claim`, `appointment`)
- **Action**: Optional qualifier for the event type (e.g., `created`, `updated`, `status`, `notification`)

### Examples
- `medication.order.created` - New medication orders
- `patient.profile.updated` - Patient profile updates
- `fhir.observation` - FHIR observation resources
- `workflow.priorauth.status` - Prior authorization status changes
- `audit.user.login` - User login audit events

### Special Purpose Topics
- **Dead Letter Topics**: Named with `.dlq` suffix (e.g., `medication.order.created.dlq`)
- **Retry Topics**: Named with `.retry` suffix (e.g., `notification.email.retry`)
- **Compacted Topics**: Named with `.compacted` suffix for log-compacted reference data
- **Internal Topics**: Prefixed with `_internal.` for platform-managed topics

## Topic Creation and Configuration

### Topic Creation API

The Event Broker provides RESTful and programmatic interfaces for topic creation:

```typescript
// Topic creation using Admin API
import { Kafka } from 'kafkajs';

// Initialize Kafka admin client
const kafka = new Kafka({
  clientId: 'topic-management-service',
  brokers: ['event-broker.cmm.internal:9092'],
  ssl: true,
  sasl: {
    mechanism: 'plain',
    username: process.env.KAFKA_ADMIN_USERNAME,
    password: process.env.KAFKA_ADMIN_PASSWORD
  },
});

const admin = kafka.admin();
await admin.connect();

// Create a new topic
async function createTopic(topicSpec) {
  try {
    const { topicName, partitions, replicationFactor, configs } = topicSpec;
    
    // Validate topic name against naming convention
    if (!validateTopicName(topicName)) {
      throw new Error(`Topic name '${topicName}' does not conform to naming convention`);
    }
    
    // Check if topic already exists
    const existingTopics = await admin.listTopics();
    if (existingTopics.includes(topicName)) {
      throw new Error(`Topic '${topicName}' already exists`);
    }
    
    // Create the topic
    await admin.createTopics({
      topics: [{
        topic: topicName,
        numPartitions: partitions || 6,  // Default to 6 partitions
        replicationFactor: replicationFactor || 3,  // Default to 3x replication
        configEntries: Object.entries(configs || {}).map(([key, value]) => ({
          name: key,
          value: String(value)
        }))
      }],
      timeout: 30000,  // 30 second timeout
      validateOnly: false
    });
    
    console.log(`Topic '${topicName}' created successfully`);
    return { success: true, topicName };
  } catch (error) {
    console.error(`Failed to create topic: ${error.message}`);
    throw error;
  }
}

// Example topic creation
const topicSpec = {
  topicName: 'medication.order.created',
  partitions: 12,
  replicationFactor: 3,
  configs: {
    'cleanup.policy': 'delete',
    'retention.ms': 7 * 24 * 60 * 60 * 1000,  // 7 days retention
    'min.insync.replicas': 2,
    'compression.type': 'lz4',
    'max.message.bytes': 1000000  // 1MB max message size
  }
};

await createTopic(topicSpec);
await admin.disconnect();
```

### Standard Topic Configurations

The Event Broker defines standard configuration profiles for different topic types:

#### Regular Event Topics
```json
{
  "cleanup.policy": "delete",
  "retention.ms": 604800000,  // 7 days
  "min.insync.replicas": 2,
  "compression.type": "lz4",
  "max.message.bytes": 1000000  // 1MB
}
```

#### High Volume Event Topics
```json
{
  "cleanup.policy": "delete",
  "retention.ms": 259200000,  // 3 days
  "min.insync.replicas": 2,
  "compression.type": "lz4",
  "max.message.bytes": 1000000,  // 1MB
  "segment.bytes": 536870912,  // 512MB
  "segment.ms": 21600000  // 6 hours
}
```

#### Reference Data Topics
```json
{
  "cleanup.policy": "compact",
  "min.cleanable.dirty.ratio": 0.5,
  "segment.bytes": 134217728,  // 128MB
  "min.insync.replicas": 2,
  "compression.type": "lz4",
  "max.message.bytes": 5000000  // 5MB
}
```

#### Audit Log Topics
```json
{
  "cleanup.policy": "delete",
  "retention.ms": 2592000000,  // 30 days
  "min.insync.replicas": 2,
  "compression.type": "lz4",
  "max.message.bytes": 1000000  // 1MB
}
```

### Partitioning Strategies

The Event Broker supports several partitioning strategies for optimal performance:

#### Key-Based Partitioning
- Used when event order matters for specific keys
- Events with the same key go to the same partition
- Ensures ordered processing within a key's event stream

```typescript
// Producer with key-based partitioning
const producer = kafka.producer();
await producer.connect();

// Send events with keys for deterministic partitioning
await producer.send({
  topic: 'patient.profile.updated',
  messages: [
    { key: 'patient-12345', value: JSON.stringify(patientData) }
  ]
});
```

#### Round Robin Partitioning
- Used when event order doesn't matter
- Distributes events evenly across all partitions
- Maximizes throughput and load balancing

```typescript
// Producer with round-robin partitioning (null keys)
await producer.send({
  topic: 'system.metrics',
  messages: [
    { value: JSON.stringify(metricsData) }  // No key specified
  ]
});
```

#### Custom Partitioning
- Used for specific requirements like geographical or tenant-based partitioning
- Implemented through custom partitioner functions

```typescript
// Producer with custom partitioner
const producer = kafka.producer({
  createPartitioner: () => {
    // Geography-based partitioner
    return ({ topic, partitionMetadata, key, value }) => {
      // Parse event to extract geography
      const event = JSON.parse(value.toString());
      const region = event.patientLocation?.region || 'UNKNOWN';
      
      // Map region to partition number
      const regionPartitionMap = {
        'NORTHEAST': 0,
        'SOUTHEAST': 1,
        'MIDWEST': 2,
        'SOUTHWEST': 3,
        'WEST': 4,
        'UNKNOWN': 5
      };
      
      // Use the region mapping or fallback to hashing the key
      return regionPartitionMap[region] !== undefined 
        ? regionPartitionMap[region] 
        : defaultPartitioner({ topic, partitionMetadata, key });
    };
  }
});
```

## Topic Monitoring and Management

### Topic Health Metrics

The Event Broker collects and exposes the following key metrics for topic health:

#### Production Metrics
- **Messages per second**: Rate of incoming messages
- **Bytes per second**: Throughput of incoming data
- **Producer request rate**: Number of producer requests
- **Average request latency**: Time for produced messages to be acknowledged
- **Error rate**: Percentage of failed produce requests

#### Consumption Metrics
- **Consumer lag**: Difference between latest produced offset and consumer position
- **Consumption rate**: Messages consumed per second
- **Processing time**: Time spent processing each message
- **Rebalance rate**: Frequency of consumer group rebalances
- **Error rate**: Percentage of failed consume requests

#### Storage Metrics
- **Disk usage**: Storage space used by topic partitions
- **Growth rate**: Change in storage usage over time
- **Segment creation rate**: Frequency of new segment creation
- **Retention deletions**: Rate of messages deleted due to retention policy
- **Compaction efficiency**: For compacted topics, reduction in size after compaction

### Topic Management Operations

#### Listing Topics
```typescript
// List all topics
const topicList = await admin.listTopics();
console.log(`Available topics: ${topicList.join(', ')}`);

// Get detailed topic metadata
const topicMetadata = await admin.fetchTopicMetadata({
  topics: ['medication.order.created']
});

console.log(JSON.stringify(topicMetadata, null, 2));
```

#### Updating Topic Configurations
```typescript
// Update topic configuration
await admin.alterConfigs({
  resources: [{
    type: ConfigResourceTypes.TOPIC,
    name: 'medication.order.created',
    configEntries: [
      {
        name: 'retention.ms',
        value: '1209600000'  // Increase retention to 14 days
      },
      {
        name: 'min.insync.replicas',
        value: '2'
      }
    ]
  }]
});
```

#### Adding Partitions
```typescript
// Increase topic partitions
await admin.createPartitions({
  topicPartitions: [{
    topic: 'medication.order.created',
    count: 24  // New total partition count
  }]
});
```

#### Deleting Topics
```typescript
// Delete a topic
await admin.deleteTopics({
  topics: ['deprecated.topic.name'],
  timeout: 30000
});
```

### Topic Monitoring Dashboard

The Event Broker provides a monitoring dashboard with the following views:

#### Overview Dashboard
- Topics with highest throughput
- Topics with highest consumer lag
- Producer and consumer error rates
- Disk usage by topic
- Request latency trends

#### Topic Detail View
- Message rate and volume over time
- Partition distribution
- Consumer groups and their lag
- Error and warning events
- Configuration settings

#### Consumer Group View
- Active consumer instances
- Partition assignments
- Processing rates
- Lag by partition
- Rebalance history

## Topic Data Management

### Data Retention Policies

The Event Broker supports several retention strategies:

#### Time-Based Retention
```json
{
  "cleanup.policy": "delete",
  "retention.ms": 604800000  // 7 days
}
```

#### Size-Based Retention
```json
{
  "cleanup.policy": "delete",
  "retention.bytes": 1073741824  // 1GB per partition
}
```

#### Log Compaction
```json
{
  "cleanup.policy": "compact",
  "min.cleanable.dirty.ratio": 0.5,
  "min.compaction.lag.ms": 3600000  // 1 hour
}
```

#### Mixed Retention
```json
{
  "cleanup.policy": "delete,compact",
  "retention.ms": 604800000,  // 7 days
  "min.cleanable.dirty.ratio": 0.5
}
```

### Data Archiving

The Event Broker supports archiving topic data for long-term storage and compliance:

#### S3 Connector for Archiving
```json
{
  "name": "s3-sink-medication-orders",
  "config": {
    "connector.class": "io.confluent.connect.s3.S3SinkConnector",
    "tasks.max": "3",
    "topics": "medication.order.created",
    "s3.region": "us-east-1",
    "s3.bucket.name": "cmm-event-archives",
    "s3.part.size": "5242880",
    "flush.size": "1000",
    "rotate.schedule.interval.ms": "3600000",
    "storage.class": "io.confluent.connect.s3.storage.S3Storage",
    "format.class": "io.confluent.connect.s3.format.avro.AvroFormat",
    "schema.compatibility": "FULL",
    "partitioner.class": "io.confluent.connect.storage.partitioner.TimeBasedPartitioner",
    "path.format": "'year'=YYYY/'month'=MM/'day'=dd/'hour'=HH",
    "locale": "en-US",
    "timezone": "UTC"
  }
}
```

### Data Replications

The Event Broker supports replicating data across different environments and regions:

#### MirrorMaker 2 Configuration
```json
{
  "name": "mm2-to-dr-region",
  "config": {
    "connector.class": "org.apache.kafka.connect.mirror.MirrorSourceConnector",
    "tasks.max": "10",
    "source.cluster.alias": "primary",
    "target.cluster.alias": "dr",
    "source.cluster.bootstrap.servers": "kafka-primary.cmm.internal:9092",
    "target.cluster.bootstrap.servers": "kafka-dr.cmm.internal:9092",
    "topics": "medication\\..*,patient\\..*",
    "topics.exclude": ".*\\.dlq,.*\\.retry",
    "sync.topic.configs.enabled": "true",
    "sync.topic.acls.enabled": "true",
    "replication.factor": "3",
    "offset-syncs.topic.replication.factor": "3",
    "refresh.topics.interval.seconds": "60",
    "refresh.groups.interval.seconds": "300",
    "source->target.emit.heartbeats.enabled": "true",
    "source->target.emit.checkpoints.enabled": "true"
  }
}
```

## Related Resources
- [Event Broker Overview](../01-getting-started/overview.md)
- [Event Broker Key Concepts](../01-getting-started/key-concepts.md)
- [Core APIs](./core-apis.md)
- [Data Model](./data-model.md)
- [Topic Governance](../04-governance-compliance/topic-governance.md)
- [Schema Registry Management](../04-governance-compliance/schema-registry-management.md)
- [Confluent Topic Management Documentation](https://docs.confluent.io/platform/current/kafka/topics.html)