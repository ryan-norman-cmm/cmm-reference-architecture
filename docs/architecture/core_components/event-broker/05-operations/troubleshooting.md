# Event Broker Troubleshooting

## Introduction

This document provides guidance for troubleshooting common issues with the Event Broker component in the CMM Technology Platform. It covers problems that operators, developers, and administrators might encounter when working with the Event Broker, along with recommended solutions and best practices for diagnosing and resolving these issues.

## Common Issues and Solutions

### Connectivity Issues

#### Confluent Cloud Connection Failures

**Issue**: Clients cannot connect to Confluent Cloud Kafka.

**Symptoms**:
- Connection timeout errors
- Authentication failures
- SSL/TLS handshake errors
- SASL authentication errors

**Diagnostic Steps**:

1. Verify Confluent Cloud cluster status in the Confluent Cloud Console:
   ```bash
   # Check the Confluent Cloud status page
   curl -s https://status.confluent.cloud/
   ```

2. Test network connectivity to Confluent Cloud bootstrap servers:
   ```bash
   # Test TCP connection to bootstrap server
   nc -zv <bootstrap-server> 9092
   
   # For SSL connections
   openssl s_client -connect <bootstrap-server>:9092 -tls1_2
   ```

3. Validate API keys and credentials:
   ```bash
   # Use Confluent CLI to verify credentials
   confluent login
   confluent environment list
   confluent kafka cluster list
   ```

4. Check client logs for specific authentication errors:
   ```bash
   # Look for SASL authentication failures or SSL errors
   grep -i 'authentication\|sasl\|ssl' application.log
   ```

**Solutions**:

1. Update TypeScript client configuration with correct Confluent Cloud settings:
   ```typescript
   // Configure Kafka client for Confluent Cloud
   const kafkaConfig = {
     clientId: 'healthcare-app',
     brokers: ['<bootstrap-server>'],
     ssl: true,
     sasl: {
       mechanism: 'plain',
       username: '${CONFLUENT_CLOUD_KEY}',
       password: '${CONFLUENT_CLOUD_SECRET}'
     },
     connectionTimeout: 5000,
     authenticationTimeout: 10000,
     retry: {
       initialRetryTime: 300,
       retries: 10
     }
   };
   ```

2. Ensure firewall allows outbound connections to Confluent Cloud:
   ```bash
   # Allow outbound connections to Confluent Cloud
   sudo ufw allow out to <bootstrap-server> port 9092 proto tcp
   ```

3. Verify that API keys have appropriate ACLs in Confluent Cloud Console.

4. Check for network proxy issues that might interfere with Confluent Cloud connections.

#### Confluent Cloud Schema Registry Issues

**Issue**: Clients cannot connect to Confluent Cloud Schema Registry.

**Symptoms**:
- Schema registration failures
- Serialization/deserialization errors
- HTTP 401/403 authentication errors
- Schema compatibility errors

**Diagnostic Steps**:

1. Verify Confluent Cloud Schema Registry status in the Confluent Cloud Console:
   ```bash
   # Check the Confluent Cloud status page
   curl -s https://status.confluent.cloud/
   ```

2. Test Schema Registry connectivity with authentication:
   ```bash
   # Test connectivity with credentials
   curl -s -u ${SCHEMA_REGISTRY_KEY}:${SCHEMA_REGISTRY_SECRET} \
     https://schema-registry.confluent.cloud/subjects
   ```

3. Check for specific Schema Registry errors in application logs:
   ```bash
   # Look for Schema Registry errors
   grep -i 'schema registry\|avro\|serialization' application.log
   ```

4. Validate Schema Registry API keys and permissions:
   ```bash
   # Use Confluent CLI to verify Schema Registry access
   confluent schema-registry subject list
   ```

**Solutions**:

1. Update TypeScript client configuration with correct Confluent Cloud Schema Registry settings:
   ```typescript
   // Configure Schema Registry client for Confluent Cloud
   import { SchemaRegistry } from '@kafkajs/confluent-schema-registry';
   
   const schemaRegistry = new SchemaRegistry({
     host: 'https://schema-registry.confluent.cloud',
     auth: {
       username: '${SCHEMA_REGISTRY_KEY}',
       password: '${SCHEMA_REGISTRY_SECRET}'
     },
     // Optional configurations for reliability
     retry: {
       initialRetryTime: 100,
       retries: 5
     },
     // Advanced configurations
     agent: {
       keepAlive: true,
       keepAliveMsecs: 1000,
       maxSockets: 20
     }
   });
   
   // Example usage with error handling
   async function encodeWithSchemaRegistry(value, schemaType) {
     try {
       // Get latest schema ID or register new schema
       const { id } = await schemaRegistry.getLatestSchemaId(schemaType);
       // Encode message with schema validation
       return await schemaRegistry.encode(id, value);
     } catch (error) {
       if (error.message.includes('401')) {
         console.error('Schema Registry authentication failed:', error);
         // Handle authentication errors
       } else if (error.message.includes('Compatibility')) {
         console.error('Schema compatibility error:', error);
         // Handle compatibility errors
       } else {
         console.error('Schema Registry error:', error);
       }
       throw error;
     }
   }
   ```

2. Ensure Schema Registry API keys have appropriate permissions in Confluent Cloud Console.

3. Verify network connectivity to Schema Registry endpoint:
   ```bash
   # Test HTTPS connection to Schema Registry
   curl -v https://schema-registry.confluent.cloud/
   ```

4. Check for Schema Registry compatibility settings in Confluent Cloud Console and adjust if necessary.

### Performance Issues

#### High Latency in Confluent Cloud

**Issue**: Messages experience high latency from production to consumption in Confluent Cloud.

**Symptoms**:
- Slow message delivery
- Increasing consumer lag metrics in Confluent Cloud
- Client timeout errors
- High p99 latency metrics in Confluent Cloud dashboard

**Diagnostic Steps**:

1. Check Confluent Cloud metrics in the dashboard:
   ```bash
   # Use Confluent Cloud CLI to check metrics
   confluent kafka cluster metrics describe --cluster <cluster-id>
   ```

2. Monitor client-side metrics with OpenTelemetry or Prometheus:
   ```typescript
   // Example of setting up monitoring for latency
   import { metrics } from '@opentelemetry/api';
   
   // Create a histogram for tracking latency
   const produceLatency = metrics.getMeter('kafka').createHistogram('kafka.produce.latency');
   ```

3. Check network latency between your application and Confluent Cloud:
   ```bash
   # Test network latency to Confluent Cloud
   ping <bootstrap-server>
   mtr <bootstrap-server>
   ```

4. Use Confluent Cloud's Data Flow feature to visualize end-to-end latency:
   ```bash
   # Access through Confluent Cloud Console UI
   # Navigate to Data Flow section
   ```

**Solutions**:

1. Optimize TypeScript producer configuration for Confluent Cloud:
   ```typescript
   // Configure producer for optimal performance in Confluent Cloud
   import { Kafka, CompressionTypes, Partitioners } from 'kafkajs';
   
   const kafka = new Kafka({
     clientId: 'healthcare-producer',
     brokers: ['<bootstrap-server>'],
     ssl: true,
     sasl: {
       mechanism: 'plain',
       username: '${CONFLUENT_CLOUD_KEY}',
       password: '${CONFLUENT_CLOUD_SECRET}'
     }
   });
   
   const producer = kafka.producer({
     // Performance optimizations
     createPartitioner: Partitioners.DefaultPartitioner,
     allowAutoTopicCreation: false,
     idempotent: true,                // Prevents duplicates
     maxInFlightRequests: 5,          // Controls concurrency
     compression: CompressionTypes.LZ4, // Efficient compression
     // Batching optimizations
     acks: 1,                        // For non-critical data (use -1 for critical)
     timeout: 30000,                 // 30 seconds timeout
     batchSize: 65536,               // 64KB batch size
     linger: 5                       // Wait 5ms for batching
   });
   ```

2. Optimize TypeScript consumer configuration for Confluent Cloud:
   ```typescript
   // Configure consumer for optimal performance in Confluent Cloud
   const consumer = kafka.consumer({
     groupId: 'healthcare-consumer-group',
     // Performance optimizations
     sessionTimeout: 30000,           // 30 seconds session timeout
     heartbeatInterval: 3000,         // 3 seconds heartbeat interval
     maxBytesPerPartition: 1048576,   // 1MB max bytes per partition
     maxWaitTimeInMs: 500,           // 500ms max wait time
     minBytes: 1024,                 // 1KB minimum fetch size
     maxBytes: 5242880,              // 5MB maximum fetch size
     // Confluent Cloud specific settings
     readUncommitted: false          // Only read committed messages
   });
   ```

3. Consider upgrading your Confluent Cloud cluster to a higher tier for better performance.

4. Implement client-side monitoring to identify bottlenecks:
   ```typescript
   // Track message production time
   const startTime = Date.now();
   await producer.send({...});
   const endTime = Date.now();
   produceLatency.record(endTime - startTime);
   ```

5. Use Confluent Cloud Stream Governance features to optimize data flow and schema management.

#### Consumer Lag in Confluent Cloud

**Issue**: Consumers falling behind producers in Confluent Cloud, creating a backlog of messages.

**Symptoms**:
- Increasing consumer lag metrics in Confluent Cloud dashboard
- Delayed processing of healthcare events
- Consumers constantly catching up
- Alerts from Confluent Cloud monitoring

**Diagnostic Steps**:

1. Check consumer lag using Confluent Cloud Console or CLI:
   ```bash
   # Using Confluent CLI
   confluent kafka consumer-group describe clinical-data-processor \
     --cluster <cluster-id>
   ```

2. Monitor consumer throughput metrics in Confluent Cloud dashboard:
   ```bash
   # Navigate to Consumers section in Confluent Cloud Console
   # Filter by consumer group name
   ```

3. Use Confluent Cloud's Consumer Lag Exporter to track lag metrics:
   ```typescript
   // Example of setting up monitoring for consumer lag
   import { metrics } from '@opentelemetry/api';
   
   // Create a gauge for tracking consumer lag
   const consumerLagGauge = metrics.getMeter('kafka').createObservableGauge('kafka.consumer.lag', {
     description: 'Lag in messages for Kafka consumer group'
   });
   ```

4. Check application logs for consumer processing issues:
   ```bash
   grep -i 'error\|exception\|timeout' consumer-application.log
   ```

**Solutions**:

1. Implement parallel processing with TypeScript and Confluent Cloud:
   ```typescript
   // Configure consumer with concurrency for Confluent Cloud
   import { Kafka } from 'kafkajs';
   
   const kafka = new Kafka({
     clientId: 'healthcare-consumer',
     brokers: ['<bootstrap-server>'],
     ssl: true,
     sasl: {
       mechanism: 'plain',
       username: '${CONFLUENT_CLOUD_KEY}',
       password: '${CONFLUENT_CLOUD_SECRET}'
     }
   });
   
   // Create multiple consumer instances for parallel processing
   async function startParallelConsumers(numConsumers = 3) {
     const consumers = [];
     
     for (let i = 0; i < numConsumers; i++) {
       const consumer = kafka.consumer({
         groupId: 'healthcare-consumer-group',
         // Performance optimizations
         sessionTimeout: 30000,
         maxBytesPerPartition: 1048576,
         maxWaitTimeInMs: 500
       });
       
       await consumer.connect();
       await consumer.subscribe({ topic: 'clinical.events', fromBeginning: false });
       
       // Process messages with batching for better throughput
       await consumer.run({
         partitionsConsumedConcurrently: 3, // Process multiple partitions concurrently
         eachBatchAutoResolve: true,
         eachBatch: async ({ batch, resolveOffset, heartbeat }) => {
           const messages = batch.messages;
           
           // Process messages in parallel with controlled concurrency
           await Promise.all(
             chunk(messages, 100).map(async (messageBatch) => {
               await Promise.all(
                 messageBatch.map(async (message) => {
                   try {
                     // Process message
                     await processMessage(message);
                     resolveOffset(message.offset);
                   } catch (error) {
                     console.error('Error processing message:', error);
                     // Handle error (DLQ, retry, etc.)
                   }
                   
                   // Send heartbeat to prevent rebalancing during long processing
                   await heartbeat();
                 })
               );
             })
           );
         }
       });
       
       consumers.push(consumer);
     }
     
     return consumers;
   }
   
   // Helper function to chunk array into smaller arrays
   function chunk(array, size) {
     return Array.from({ length: Math.ceil(array.length / size) }, (_, i) =>
       array.slice(i * size, i * size + size)
     );
   }
   ```

2. Increase topic partition count in Confluent Cloud Console or CLI:
   ```bash
   # Using Confluent CLI
   confluent kafka topic update clinical.events \
     --cluster <cluster-id> \
     --partitions 16
   ```

3. Optimize consumer processing with batching and parallelization:
   ```typescript
   // Batch processing instead of individual records
   ConsumerRecords<String, String> records = consumer.poll(Duration.ofMillis(100));
   List<Record> batch = new ArrayList<>();
   for (ConsumerRecord<String, String> record : records) {
       batch.add(convertToRecord(record));
   }
   processBatch(batch);
   ```

4. Increase consumer fetch size:
   ```properties
   fetch.min.bytes=1024
   max.partition.fetch.bytes=1048576
   ```

### Data Issues

#### Schema Evolution Problems

**Issue**: Schema compatibility errors when evolving schemas.

**Symptoms**:
- Schema registration failures
- Serialization/deserialization errors
- Producer/consumer compatibility errors

**Diagnostic Steps**:

1. Check Schema Registry for compatibility errors:
   ```bash
   curl -s http://schema-registry:8081/config
   ```

2. Verify schema compatibility manually:
   ```bash
   curl -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" \
     --data '{"schema": "..."}' \
     http://schema-registry:8081/compatibility/subjects/clinical.patient.admitted-value/versions/latest
   ```

**Solutions**:

1. Update schema to maintain compatibility:
   ```json
   // Add fields with defaults or make them optional
   {"name": "newField", "type": ["null", "string"], "default": null}
   ```

2. Adjust compatibility settings if necessary:
   ```bash
   curl -X PUT -H "Content-Type: application/vnd.schemaregistry.v1+json" \
     --data '{"compatibility": "BACKWARD"}' \
     http://schema-registry:8081/config/clinical.patient.admitted-value
   ```

3. Create a new topic version for incompatible changes:
   ```bash
   kafka-topics --create --bootstrap-server kafka-broker:9092 \
     --topic clinical.patient.admitted.v2 --partitions 8 --replication-factor 3
   ```

#### Message Corruption

**Issue**: Messages are corrupted or cannot be deserialized.

**Symptoms**:
- Deserialization exceptions
- Garbled message content
- Schema version mismatches

**Diagnostic Steps**:

1. Inspect raw messages using console consumer:
   ```bash
   kafka-console-consumer --bootstrap-server kafka-broker:9092 \
     --topic clinical.events --from-beginning \
     --property print.key=true --property print.value=true
   ```

2. Check schema versions in Schema Registry:
   ```bash
   curl -s http://schema-registry:8081/subjects/clinical.events-value/versions
   ```

**Solutions**:

1. Ensure producers and consumers use compatible serializers/deserializers:
   ```java
   // Producer
   props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, 
             KafkaAvroSerializer.class.getName());
   
   // Consumer
   props.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, 
             KafkaAvroDeserializer.class.getName());
   ```

2. Verify schema evolution follows compatibility rules.

3. Implement error handling for corrupt messages:
   ```java
   try {
       ConsumerRecords<String, HealthcareEvent> records = consumer.poll(Duration.ofMillis(100));
       for (ConsumerRecord<String, HealthcareEvent> record : records) {
           processRecord(record);
       }
   } catch (SerializationException e) {
       // Log error and skip corrupted message
       log.error("Error deserializing message", e);
       consumer.seek(new TopicPartition(record.topic(), record.partition()), 
                    record.offset() + 1);
   }
   ```

### Security Issues

#### Authentication Failures

**Issue**: Clients fail to authenticate with Kafka brokers.

**Symptoms**:
- Authentication errors in client logs
- Connection failures with security exceptions
- Access denied errors

**Diagnostic Steps**:

1. Check Kafka broker logs for authentication errors:
   ```bash
   grep "authentication failed" /var/log/kafka/server.log
   ```

2. Verify client configuration includes correct authentication settings:
   ```bash
   grep "sasl.jaas.config" client.properties
   ```

3. Test authentication with kafka-console-producer:
   ```bash
   kafka-console-producer --bootstrap-server kafka-broker:9092 \
     --topic test --producer.config client-secure.properties
   ```

**Solutions**:

1. Update client JAAS configuration with correct credentials:
   ```properties
   sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required \
     username="clinical-service" \
     password="correct-password";
   ```

2. Verify broker JAAS configuration includes the client:
   ```properties
   listener.name.sasl_ssl.plain.sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required \
     username="admin" \
     password="admin-password" \
     user_admin="admin-password" \
     user_clinical-service="correct-password";
   ```

3. Check for expired credentials or certificates.

#### Authorization Failures

**Issue**: Clients cannot access topics due to authorization failures.

**Symptoms**:
- Operation not allowed errors
- Access denied errors
- Topic authorization failures

**Diagnostic Steps**:

1. Check Kafka broker logs for authorization errors:
   ```bash
   grep "is not authorized" /var/log/kafka/server.log
   ```

2. List ACLs for the topic:
   ```bash
   kafka-acls --bootstrap-server kafka-broker:9092 \
     --list --topic clinical.events
   ```

**Solutions**:

1. Add necessary ACLs for the client:
   ```bash
   kafka-acls --bootstrap-server kafka-broker:9092 \
     --add --allow-principal User:clinical-service \
     --operation Read --operation Describe \
     --topic clinical.events
   ```

2. Update client configuration with correct principal:
   ```properties
   sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required \
     username="clinical-service" \
     password="correct-password";
   ```

3. Check for role-based access control settings in custom authorizer.

### Operational Issues

#### Broker Failures

**Issue**: Kafka broker nodes failing or becoming unresponsive.

**Symptoms**:
- Broker process termination
- High CPU/memory usage
- Disk space exhaustion
- Network partition events

**Diagnostic Steps**:

1. Check broker status:
   ```bash
   systemctl status kafka
   ```

2. Examine broker logs for errors:
   ```bash
   tail -f /var/log/kafka/server.log
   ```

3. Check system resources:
   ```bash
   df -h
   free -m
   top
   ```

**Solutions**:

1. Restart failed broker:
   ```bash
   systemctl restart kafka
   ```

2. Address resource constraints:
   ```bash
   # Clean up disk space
   # Add more memory/CPU
   # Optimize JVM settings
   ```

3. Adjust broker configuration for stability:
   ```properties
   # Reduce memory pressure
   replica.fetch.max.bytes=1048576
   message.max.bytes=1048576
   
   # Improve recovery
   controlled.shutdown.enable=true
   ```

4. Implement monitoring and alerting for early detection.

#### Topic Rebalancing Issues

**Issue**: Partition reassignment or rebalancing problems.

**Symptoms**:
- Slow partition reassignment
- Uneven partition distribution
- Leader election failures

**Diagnostic Steps**:

1. Check topic partition distribution:
   ```bash
   kafka-topics --bootstrap-server kafka-broker:9092 \
     --describe --topic clinical.events
   ```

2. Monitor reassignment progress:
   ```bash
   kafka-reassign-partitions --bootstrap-server kafka-broker:9092 \
     --verify --reassignment-json-file reassign.json
   ```

**Solutions**:

1. Generate balanced partition assignment:
   ```bash
   kafka-reassign-partitions --bootstrap-server kafka-broker:9092 \
     --generate --topics-to-move-json-file topics.json \
     --broker-list "0,1,2,3"
   ```

2. Execute partition reassignment:
   ```bash
   kafka-reassign-partitions --bootstrap-server kafka-broker:9092 \
     --execute --reassignment-json-file reassign.json
   ```

3. Adjust replica.fetch.max.bytes for faster replication:
   ```properties
   replica.fetch.max.bytes=10485760
   ```

## Healthcare-Specific Issues

### HL7 Integration Issues

**Issue**: Problems with HL7 message integration.

**Symptoms**:
- HL7 parsing errors
- Missing or incomplete HL7 messages
- Incorrect message routing

**Diagnostic Steps**:

1. Check HL7 connector logs:
   ```bash
   tail -f /var/log/kafka-connect/connect.log | grep HL7
   ```

2. Verify HL7 message structure using a test consumer:
   ```bash
   kafka-console-consumer --bootstrap-server kafka-broker:9092 \
     --topic hl7.adt.a01 --from-beginning
   ```

**Solutions**:

1. Update HL7 connector configuration:
   ```json
   {
     "connector.class": "com.healthcare.kafka.connect.hl7.Hl7SourceConnector",
     "hl7.version": "2.5",
     "hl7.validation.enabled": "true",
     "hl7.parser.config.file": "/etc/kafka-connect/hl7-parser-config.xml"
   }
   ```

2. Implement custom HL7 message handler for special cases:
   ```java
   public class CustomHL7MessageHandler implements HL7MessageHandler {
       @Override
       public HL7Message process(String rawMessage) {
           // Custom processing logic
           return processedMessage;
       }
   }
   ```

3. Adjust HL7 validation settings for non-standard messages.

### FHIR Integration Issues

**Issue**: Problems with FHIR resource integration.

**Symptoms**:
- FHIR parsing errors
- Missing or incomplete FHIR resources
- FHIR validation failures

**Diagnostic Steps**:

1. Check FHIR connector logs:
   ```bash
   tail -f /var/log/kafka-connect/connect.log | grep FHIR
   ```

2. Verify FHIR resource structure using a test consumer:
   ```bash
   kafka-console-consumer --bootstrap-server kafka-broker:9092 \
     --topic fhir.patient.created --from-beginning
   ```

**Solutions**:

1. Update FHIR connector configuration:
   ```json
   {
     "connector.class": "com.healthcare.kafka.connect.fhir.FhirSourceConnector",
     "fhir.version": "R4",
     "fhir.validation.enabled": "true",
     "fhir.parser.strict": "false"
   }
   ```

2. Implement custom FHIR resource handler for special cases:
   ```java
   public class CustomFhirResourceHandler implements FhirResourceHandler {
       @Override
       public FhirResource process(String rawResource) {
           // Custom processing logic
           return processedResource;
       }
   }
   ```

3. Adjust FHIR validation settings for non-standard resources.

## Diagnostic Tools

### Kafka Command-Line Tools

#### Topic Management

```bash
# List topics
kafka-topics --bootstrap-server kafka-broker:9092 --list

# Describe topic
kafka-topics --bootstrap-server kafka-broker:9092 \
  --describe --topic clinical.events

# View topic configuration
kafka-configs --bootstrap-server kafka-broker:9092 \
  --entity-type topics --entity-name clinical.events --describe
```

#### Consumer Group Management

```bash
# List consumer groups
kafka-consumer-groups --bootstrap-server kafka-broker:9092 --list

# Describe consumer group
kafka-consumer-groups --bootstrap-server kafka-broker:9092 \
  --describe --group clinical-data-processor

# Reset consumer group offsets
kafka-consumer-groups --bootstrap-server kafka-broker:9092 \
  --group clinical-data-processor --topic clinical.events \
  --reset-offsets --to-earliest --execute
```

#### Message Inspection

```bash
# Consume messages
kafka-console-consumer --bootstrap-server kafka-broker:9092 \
  --topic clinical.events --from-beginning \
  --property print.key=true --property print.value=true

# Produce test messages
kafka-console-producer --bootstrap-server kafka-broker:9092 \
  --topic test-topic --property parse.key=true \
  --property key.separator=:
```

### Monitoring Tools

#### JMX Monitoring

```bash
# Using JConsole
jconsole

# Using JMX exporter for Prometheus
java -javaagent:/opt/jmx_exporter/jmx_prometheus_javaagent.jar=8080:/opt/jmx_exporter/kafka-config.yml \
  -jar /opt/kafka/bin/kafka-server-start.sh /opt/kafka/config/server.properties
```

#### Log Analysis

```bash
# Search for errors in Kafka logs
grep ERROR /var/log/kafka/server.log

# Monitor logs in real-time
tail -f /var/log/kafka/server.log | grep -v DEBUG

# Analyze log patterns
awk '/ERROR/ {print $0}' /var/log/kafka/server.log | sort | uniq -c | sort -nr
```

## Preventive Measures

### Configuration Best Practices

1. **Broker Configuration**:
   - Set appropriate replication factor (at least 3 for production)
   - Configure min.insync.replicas for durability (at least 2)
   - Enable controlled shutdown for clean broker restarts
   - Configure appropriate log retention settings

2. **Producer Configuration**:
   - Set acks=all for critical healthcare data
   - Enable idempotence to prevent duplicates
   - Configure appropriate retry settings
   - Use compression for efficiency

3. **Consumer Configuration**:
   - Disable auto-commit for critical processing
   - Set appropriate session timeout
   - Configure error handling for deserialization issues
   - Implement dead letter queues for failed messages

### Monitoring Best Practices

1. **Key Metrics to Monitor**:
   - Broker CPU, memory, disk usage
   - Under-replicated partitions
   - Request rate and latency
   - Consumer lag
   - Garbage collection metrics

2. **Alerting Thresholds**:
   - Alert on under-replicated partitions > 0
   - Alert on offline partitions > 0
   - Alert on consumer lag > threshold (application-specific)
   - Alert on broker CPU > 80%
   - Alert on disk usage > 80%

### Backup and Recovery

1. **Regular Backups**:
   - Back up broker configurations
   - Back up Schema Registry schemas
   - Back up ACL configurations
   - Consider topic mirroring for critical data

2. **Disaster Recovery Planning**:
   - Document recovery procedures
   - Test recovery procedures regularly
   - Maintain standby environments
   - Implement multi-region replication for critical systems

## Conclusion

Effective troubleshooting of the Event Broker requires a systematic approach to identifying and resolving issues. By following the diagnostic steps and solutions outlined in this document, operators and developers can quickly address common problems and maintain a reliable event-driven healthcare platform. Regular monitoring, preventive maintenance, and adherence to best practices will minimize the occurrence of issues and reduce their impact when they do occur.

## Related Documentation

- [Event Broker Architecture](../01-getting-started/architecture.md)
- [Monitoring](./monitoring.md)
- [Scaling](./scaling.md)
- [Maintenance](./maintenance.md)
