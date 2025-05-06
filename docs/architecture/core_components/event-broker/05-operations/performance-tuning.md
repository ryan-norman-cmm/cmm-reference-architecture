# Performance Tuning

## Overview

Performance tuning is essential for optimizing the Event Broker to handle high-volume healthcare data efficiently. This document covers key performance tuning strategies for Kafka brokers, producers, consumers, and topics, focusing on configuration parameters, hardware considerations, and monitoring techniques to achieve optimal throughput and latency.

## Broker Performance Tuning

Kafka broker performance can be optimized through careful configuration and resource allocation.

### Hardware Considerations

Optimal hardware configuration significantly impacts Kafka performance:

| Resource | Recommendation | Impact |
|----------|---------------|--------|
| CPU | 16+ cores, high clock speed | Parallel request processing |
| Memory | 32-64 GB | Page cache for active segments |
| Disk | SSD or NVMe, RAID 10 | I/O throughput for logs |
| Network | 10+ Gbps | Message throughput |

### Broker Configuration

Key broker configuration parameters for performance optimization:

```properties
# Broker performance tuning (server.properties)

# Thread pools
num.network.threads=8                 # Network threads for client requests
num.io.threads=16                     # Disk I/O threads
num.replica.fetchers=4                # Threads for replica fetching
background.threads=10                 # Background processing threads

# Socket configuration
socket.send.buffer.bytes=1048576      # Socket send buffer (1MB)
socket.receive.buffer.bytes=1048576   # Socket receive buffer (1MB)
socket.request.max.bytes=104857600    # Max request size (100MB)

# Log configuration
log.flush.interval.messages=10000     # Messages before forced flush
log.flush.interval.ms=1000            # Time before forced flush
log.flush.scheduler.interval.ms=2000  # Log flusher scheduling interval
log.segment.bytes=1073741824          # Log segment size (1GB)
log.retention.hours=168               # Log retention period (7 days)
log.retention.check.interval.ms=300000 # Retention check interval (5 min)

# Replication configuration
num.replica.fetchers=4                # Replica fetcher threads
replica.fetch.max.bytes=1048576       # Max bytes per fetch request
replica.fetch.response.max.bytes=10485760 # Max response size
replica.lag.time.max.ms=10000         # Max replica lag time

# ZooKeeper configuration
zookeeper.session.timeout.ms=18000    # ZooKeeper session timeout
zookeeper.connection.timeout.ms=6000  # ZooKeeper connection timeout

# Topic defaults
num.partitions=12                     # Default partitions per topic
default.replication.factor=3          # Default replication factor
```

### Linux OS Tuning

Optimize the operating system for Kafka performance:

```bash
# File descriptor limits
echo "* soft nofile 100000" >> /etc/security/limits.conf
echo "* hard nofile 100000" >> /etc/security/limits.conf

# Kernel parameters
cat > /etc/sysctl.d/99-kafka.conf << EOF
# Increase the number of allowed memory map areas
vm.max_map_count=262144

# Increase the maximum number of memory segments
vm.max_map_count=262144

# Increase the TCP max buffer size
net.core.rmem_max=16777216
net.core.wmem_max=16777216

# Increase the Linux autotuning TCP buffer limits
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216

# Enable TCP window scaling
net.ipv4.tcp_window_scaling=1

# Increase the TCP congestion window
net.ipv4.tcp_congestion_control=cubic

# Disable TCP slow start after idle
net.ipv4.tcp_slow_start_after_idle=0

# Increase the maximum connections
net.core.somaxconn=4096
net.ipv4.tcp_max_syn_backlog=4096

# Decrease swappiness
vm.swappiness=1
EOF

# Apply sysctl settings
sysctl -p /etc/sysctl.d/99-kafka.conf
```

### JVM Tuning

Optimize the JVM for Kafka performance:

```bash
# Kafka JVM settings (kafka-server-start.sh)
export KAFKA_HEAP_OPTS="-Xms16g -Xmx16g"
export KAFKA_JVM_PERFORMANCE_OPTS="-server -XX:+UseG1GC -XX:MaxGCPauseMillis=20 -XX:InitiatingHeapOccupancyPercent=35 -XX:+ExplicitGCInvokesConcurrent -XX:G1HeapRegionSize=16M -XX:MinMetaspaceFreeRatio=50 -XX:MaxMetaspaceFreeRatio=80 -XX:+DisableExplicitGC"
```

## Producer Performance Tuning

Optimize Kafka producers for high throughput and low latency.

### Producer Configuration

Key producer configuration parameters:

```properties
# Producer performance tuning

# Batching configuration
batch.size=131072                     # Batch size in bytes (128KB)
linger.ms=5                           # Time to wait for batch to fill

# Compression
compression.type=lz4                  # Compression algorithm (none, gzip, snappy, lz4, zstd)

# Buffering
buffer.memory=67108864               # Producer buffer memory (64MB)
max.in.flight.requests.per.connection=5 # Max unacknowledged requests

# Acknowledgments
acks=all                              # Acknowledgment level (0, 1, all)

# Retries
retries=3                             # Number of retries
retry.backoff.ms=100                  # Retry backoff time

# Idempotence
enable.idempotence=true               # Enable exactly-once semantics
```

### Producer Code Optimization

Optimize producer code for better performance:

```java
// Optimized producer configuration
Properties props = new Properties();
props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, "kafka:9092");
props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, JsonSerializer.class.getName());

// Performance tuning
props.put(ProducerConfig.BATCH_SIZE_CONFIG, 131072);  // 128KB batch size
props.put(ProducerConfig.LINGER_MS_CONFIG, 5);        // 5ms linger time
props.put(ProducerConfig.COMPRESSION_TYPE_CONFIG, "lz4");
props.put(ProducerConfig.BUFFER_MEMORY_CONFIG, 67108864);  // 64MB buffer
props.put(ProducerConfig.MAX_IN_FLIGHT_REQUESTS_PER_CONNECTION, 5);

// Reliability settings
props.put(ProducerConfig.ACKS_CONFIG, "all");
props.put(ProducerConfig.ENABLE_IDEMPOTENCE_CONFIG, true);
props.put(ProducerConfig.RETRIES_CONFIG, 3);
props.put(ProducerConfig.RETRY_BACKOFF_MS_CONFIG, 100);

// Create producer
KafkaProducer<String, JsonNode> producer = new KafkaProducer<>(props);

// Efficient sending with batching
public void sendBatch(String topic, List<KeyedMessage<String, JsonNode>> messages) {
    for (KeyedMessage<String, JsonNode> message : messages) {
        ProducerRecord<String, JsonNode> record = 
            new ProducerRecord<>(topic, message.key, message.value);
        
        // Asynchronous sending (no waiting for response)
        producer.send(record, (metadata, exception) -> {
            if (exception != null) {
                // Handle error asynchronously
                handleError(exception, message);
            }
        });
    }
    // No explicit flush - rely on batching
}

// Periodic flush for time-sensitive data
ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(1);
scheduler.scheduleAtFixedRate(() -> {
    producer.flush();
}, 1, 1, TimeUnit.SECONDS);
```

## Consumer Performance Tuning

Optimize Kafka consumers for efficient processing.

### Consumer Configuration

Key consumer configuration parameters:

```properties
# Consumer performance tuning

# Fetching configuration
fetch.min.bytes=1024                  # Minimum data to fetch (1KB)
fetch.max.bytes=52428800              # Maximum data to fetch (50MB)
fetch.max.wait.ms=500                 # Max wait time for fetch
max.partition.fetch.bytes=1048576     # Max data per partition (1MB)

# Processing configuration
max.poll.records=500                  # Max records per poll
receive.buffer.bytes=65536            # Socket receive buffer (64KB)

# Offset management
enable.auto.commit=false              # Disable auto commit
auto.offset.reset=earliest            # Offset reset behavior

# Consumer group configuration
session.timeout.ms=30000              # Consumer session timeout
heartbeat.interval.ms=3000            # Heartbeat interval
max.poll.interval.ms=300000           # Max time between polls (5 min)
```

### Consumer Code Optimization

Optimize consumer code for better performance:

```java
// Optimized consumer configuration
Properties props = new Properties();
props.put(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, "kafka:9092");
props.put(ConsumerConfig.GROUP_ID_CONFIG, "high-throughput-consumer");
props.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class.getName());
props.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, JsonDeserializer.class.getName());

// Performance tuning
props.put(ConsumerConfig.FETCH_MIN_BYTES_CONFIG, 1024);  // 1KB minimum fetch
props.put(ConsumerConfig.FETCH_MAX_BYTES_CONFIG, 52428800);  // 50MB maximum fetch
props.put(ConsumerConfig.FETCH_MAX_WAIT_MS_CONFIG, 500);  // 500ms max wait
props.put(ConsumerConfig.MAX_PARTITION_FETCH_BYTES_CONFIG, 1048576);  // 1MB per partition
props.put(ConsumerConfig.MAX_POLL_RECORDS_CONFIG, 500);  // 500 records per poll

// Reliability settings
props.put(ConsumerConfig.ENABLE_AUTO_COMMIT_CONFIG, false);  // Manual commit
props.put(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, "earliest");

// Create consumer
KafkaConsumer<String, JsonNode> consumer = new KafkaConsumer<>(props);
consumer.subscribe(Arrays.asList("high-volume-topic"));

// Batch processing with manual commit
public void processBatches() {
    try {
        while (running.get()) {
            ConsumerRecords<String, JsonNode> records = consumer.poll(Duration.ofMillis(100));
            
            if (!records.isEmpty()) {
                // Process records in batches by partition
                Map<TopicPartition, List<ConsumerRecord<String, JsonNode>>> partitionRecords = 
                    records.records().stream()
                        .collect(Collectors.groupingBy(
                            record -> new TopicPartition(record.topic(), record.partition())
                        ));
                
                // Process each partition's records in parallel
                CompletableFuture<?>[] futures = partitionRecords.entrySet().stream()
                    .map(entry -> CompletableFuture.runAsync(
                        () -> processPartitionRecords(entry.getValue()),
                        processingExecutor
                    ))
                    .toArray(CompletableFuture[]::new);
                
                // Wait for all processing to complete
                CompletableFuture.allOf(futures).join();
                
                // Commit offsets after successful processing
                consumer.commitSync();
            }
        }
    } finally {
        consumer.close();
    }
}

private void processPartitionRecords(List<ConsumerRecord<String, JsonNode>> records) {
    // Batch process records from a single partition
    // Implementation depends on business logic
}

// Thread pool for parallel processing
ExecutorService processingExecutor = 
    Executors.newFixedThreadPool(Runtime.getRuntime().availableProcessors());
```

## Topic Performance Tuning

Optimize topic configuration for specific workloads.

### Partitioning Strategy

Determine the optimal number of partitions:

```
Number of Partitions = max(T/P, T/C)
```
Where:
- T = Target throughput (messages/sec)
- P = Producer throughput for single partition (messages/sec)
- C = Consumer throughput for single partition (messages/sec)

For healthcare workloads:

| Workload Type | Partition Strategy | Example |
|---------------|-------------------|----------|
| High-volume clinical data | Higher partition count | 24-48 partitions |
| Administrative data | Moderate partition count | 12-24 partitions |
| Reference data | Lower partition count | 6-12 partitions |

### Topic Configuration

Optimize topic configuration for specific use cases:

```bash
# High-throughput clinical data topic
kafka-topics --bootstrap-server kafka:9092 \
  --create --topic clinical.observation.recorded \
  --partitions 32 \
  --replication-factor 3 \
  --config retention.ms=604800000 \
  --config min.insync.replicas=2 \
  --config cleanup.policy=delete \
  --config segment.bytes=1073741824 \
  --config segment.ms=86400000

# Low-latency alerting topic
kafka-topics --bootstrap-server kafka:9092 \
  --create --topic clinical.alert.generated \
  --partitions 16 \
  --replication-factor 3 \
  --config retention.ms=86400000 \
  --config min.insync.replicas=2 \
  --config cleanup.policy=delete \
  --config segment.bytes=536870912 \
  --config segment.ms=43200000

# Reference data topic with compaction
kafka-topics --bootstrap-server kafka:9092 \
  --create --topic reference.medication.catalog \
  --partitions 6 \
  --replication-factor 3 \
  --config cleanup.policy=compact \
  --config min.cleanable.dirty.ratio=0.5 \
  --config delete.retention.ms=86400000 \
  --config segment.bytes=1073741824
```

## Performance Testing

### Kafka Performance Tools

Use built-in performance tools to benchmark and tune:

```bash
# Producer performance test
kafka-producer-perf-test \
  --topic benchmark-topic \
  --num-records 10000000 \
  --record-size 1024 \
  --throughput -1 \
  --producer-props bootstrap.servers=kafka:9092 batch.size=131072 linger.ms=5 compression.type=lz4

# Consumer performance test
kafka-consumer-perf-test \
  --bootstrap-server kafka:9092 \
  --topic benchmark-topic \
  --messages 10000000 \
  --threads 4

# End-to-end latency test
kafka-run-class kafka.tools.EndToEndLatency \
  kafka:9092 benchmark-topic 10000 1 1024
```

### Custom Load Testing

Implement custom load testing for healthcare-specific scenarios:

```java
// Healthcare data load test
public class HealthcareLoadTest {
    
    private final KafkaProducer<String, String> producer;
    private final String topic;
    private final int messageCount;
    private final int messageSize;
    private final int threadCount;
    
    public HealthcareLoadTest(String bootstrapServers, String topic, 
                             int messageCount, int messageSize, int threadCount) {
        Properties props = new Properties();
        props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
        props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
        props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
        props.put(ProducerConfig.BATCH_SIZE_CONFIG, 131072);
        props.put(ProducerConfig.LINGER_MS_CONFIG, 5);
        props.put(ProducerConfig.COMPRESSION_TYPE_CONFIG, "lz4");
        
        this.producer = new KafkaProducer<>(props);
        this.topic = topic;
        this.messageCount = messageCount;
        this.messageSize = messageSize;
        this.threadCount = threadCount;
    }
    
    public void runTest() throws InterruptedException {
        ExecutorService executor = Executors.newFixedThreadPool(threadCount);
        CountDownLatch latch = new CountDownLatch(threadCount);
        long startTime = System.currentTimeMillis();
        
        for (int i = 0; i < threadCount; i++) {
            final int threadId = i;
            executor.submit(() -> {
                try {
                    int messagesPerThread = messageCount / threadCount;
                    for (int j = 0; j < messagesPerThread; j++) {
                        String key = "patient-" + threadId + "-" + j;
                        String value = generateHealthcareMessage(messageSize);
                        
                        producer.send(new ProducerRecord<>(topic, key, value), 
                            (metadata, exception) -> {
                                if (exception != null) {
                                    exception.printStackTrace();
                                }
                            });
                    }
                } finally {
                    latch.countDown();
                }
            });
        }
        
        latch.await();
        long endTime = System.currentTimeMillis();
        producer.close();
        executor.shutdown();
        
        double durationSeconds = (endTime - startTime) / 1000.0;
        double messagesPerSecond = messageCount / durationSeconds;
        double megabytesPerSecond = (messageCount * messageSize) / (1024.0 * 1024.0 * durationSeconds);
        
        System.out.printf("Sent %d messages in %.2f seconds (%.2f messages/sec, %.2f MB/sec)\n",
                         messageCount, durationSeconds, messagesPerSecond, megabytesPerSecond);
    }
    
    private String generateHealthcareMessage(int size) {
        // Generate realistic healthcare message (e.g., HL7, FHIR)
        // Implementation depends on test requirements
        StringBuilder sb = new StringBuilder();
        sb.append("{\"resourceType\":\"Observation\",\"id\":\"example\",");
        sb.append("\"status\":\"final\",\"code\":{\"coding\":[{\"system\":\"http://loinc.org\",");
        sb.append("\"code\":\"8867-4\",\"display\":\"Heart rate\"}]},");
        sb.append("\"subject\":{\"reference\":\"Patient/example\"},");
        sb.append("\"effectiveDateTime\":\"2023-01-01T12:00:00Z\",");
        sb.append("\"valueQuantity\":{\"value\":80,\"unit\":\"beats/minute\",");
        sb.append("\"system\":\"http://unitsofmeasure.org\",\"code\":\"bpm\"},");
        
        // Pad to reach desired message size
        while (sb.length() < size - 2) {
            sb.append("\"padding\":\"x\",");
        }
        sb.append("}");
        
        return sb.toString();
    }
    
    public static void main(String[] args) throws Exception {
        String bootstrapServers = args[0];
        String topic = args[1];
        int messageCount = Integer.parseInt(args[2]);
        int messageSize = Integer.parseInt(args[3]);
        int threadCount = Integer.parseInt(args[4]);
        
        HealthcareLoadTest test = new HealthcareLoadTest(
            bootstrapServers, topic, messageCount, messageSize, threadCount);
        test.runTest();
    }
}
```

## Monitoring Performance

### Key Performance Metrics

Monitor these metrics to identify performance bottlenecks:

| Metric Category | Key Metrics | Target Values |
|-----------------|-------------|---------------|
| Throughput | Messages/sec, bytes/sec | Depends on hardware |
| Latency | Producer latency, end-to-end latency | < 10ms producer, < 100ms e2e |
| Resource Utilization | CPU, memory, disk I/O, network | < 70% sustained |
| Broker Metrics | Under-replicated partitions, request rate | 0 under-replicated, stable request rate |
| Producer Metrics | Batch size avg, record send rate | Near configured batch size, stable send rate |
| Consumer Metrics | Consumer lag, poll rate | Minimal lag, stable poll rate |

### Performance Dashboard

Implement a comprehensive performance dashboard:

```yaml
# Grafana dashboard for Kafka performance
{
  "title": "Kafka Performance Dashboard",
  "panels": [
    {
      "title": "Message Throughput",
      "type": "graph",
      "datasource": "Prometheus",
      "targets": [
        {
          "expr": "sum(rate(kafka_server_brokertopicmetrics_messagesin_total[1m])) by (topic)",
          "legendFormat": "{{topic}}"
        }
      ]
    },
    {
      "title": "Bytes Throughput",
      "type": "graph",
      "datasource": "Prometheus",
      "targets": [
        {
          "expr": "sum(rate(kafka_server_brokertopicmetrics_bytesin_total[1m])) by (topic)",
          "legendFormat": "{{topic}} - in"
        },
        {
          "expr": "sum(rate(kafka_server_brokertopicmetrics_bytesout_total[1m])) by (topic)",
          "legendFormat": "{{topic}} - out"
        }
      ]
    },
    {
      "title": "Producer Request Latency",
      "type": "graph",
      "datasource": "Prometheus",
      "targets": [
        {
          "expr": "kafka_network_requestmetrics_totaltimems{request=\"Produce\",quantile=\"0.99\"}",
          "legendFormat": "{{instance}} - p99"
        }
      ]
    },
    {
      "title": "Consumer Lag",
      "type": "graph",
      "datasource": "Prometheus",
      "targets": [
        {
          "expr": "sum(kafka_consumer_consumer_fetch_manager_metrics_records_lag_max) by (group_id, topic)",
          "legendFormat": "{{group_id}} - {{topic}}"
        }
      ]
    },
    {
      "title": "Under-Replicated Partitions",
      "type": "stat",
      "datasource": "Prometheus",
      "targets": [
        {
          "expr": "sum(kafka_server_replicamanager_underreplicatedpartitions)",
          "legendFormat": ""
        }
      ],
      "options": {
        "colorMode": "value",
        "graphMode": "area",
        "justifyMode": "auto",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": ["lastNotNull"],
          "fields": "",
          "values": false
        },
        "textMode": "auto"
      },
      "fieldConfig": {
        "defaults": {
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              { "color": "green", "value": null },
              { "color": "red", "value": 1 }
            ]
          }
        }
      }
    }
  ]
}
```

## Performance Optimization Strategies

### Throughput Optimization

Strategies to optimize for high throughput:

1. **Increase Partitions**: More partitions enable greater parallelism
2. **Optimize Batch Size**: Larger batches improve throughput at the cost of latency
3. **Enable Compression**: Reduces network and storage requirements
4. **Tune Producer Buffering**: Increase buffer.memory for high-throughput producers
5. **Optimize Consumer Fetch Size**: Increase fetch.min.bytes and max.poll.records

### Latency Optimization

Strategies to optimize for low latency:

1. **Reduce Linger Time**: Lower linger.ms reduces batching delay
2. **Optimize Flush Behavior**: More frequent flushes reduce latency
3. **Use Faster Storage**: SSDs or NVMe drives for log storage
4. **Tune Consumer Polling**: Reduce fetch.max.wait.ms for faster polling
5. **Optimize Topic Placement**: Place high-priority topics on dedicated brokers

### Resource Utilization Optimization

Strategies to optimize resource utilization:

1. **Balance Partitions**: Ensure even distribution across brokers
2. **Monitor and Adjust JVM Heap**: Tune GC parameters for consistent performance
3. **Optimize Page Cache Usage**: Size memory for optimal page cache utilization
4. **Implement Topic Tiering**: Different storage tiers for different data importance
5. **Use Quotas**: Implement client quotas to prevent resource starvation

## Related Documentation

- [Monitoring](monitoring.md): Comprehensive monitoring of the Event Broker
- [Security](security.md): Securing the Event Broker
- [Disaster Recovery](disaster-recovery.md): Ensuring data availability and recovery
- [Scaling](scaling.md): Scaling the Event Broker for high throughput
