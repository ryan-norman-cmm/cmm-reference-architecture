# Event Broker Scaling

## Introduction
This document outlines the scaling strategies, methodologies, and best practices for the Event Broker platform at CoverMyMeds. Effective scaling is essential to accommodate growing data volumes, increasing message throughput, and expanding user bases while maintaining performance, reliability, and cost-effectiveness.

## Scaling Dimensions

The Event Broker platform can be scaled across multiple dimensions:

### Vertical Scaling
- **Broker Resources**: CPU, memory, and disk resources per broker
- **JVM Settings**: Heap size, garbage collection tuning
- **Network Capacity**: Network interface bandwidth and throughput

### Horizontal Scaling
- **Broker Count**: Number of broker nodes in the cluster
- **Partition Count**: Number of partitions per topic
- **Consumer Parallelism**: Consumer group members per topic

### Functional Scaling
- **Connect Workers**: Scaling integration connectors
- **Schema Registry**: Registry instances for schema validation
- **REST Proxy**: Instances for HTTP-based access
- **Stream Processing**: ksqlDB nodes for stream processing

## Capacity Planning

### Metrics for Capacity Planning

| Metric | Description | Measurement | Scaling Trigger |
|--------|-------------|-------------|----------------|
| **CPU Utilization** | Broker CPU usage | Average and peak percentage | > 70% sustained average |
| **Memory Usage** | Broker memory consumption | Percentage, GC patterns | > 80% or increasing GC pauses |
| **Disk Utilization** | Storage usage patterns | Percentage, growth rate | > 70% or growth rate indicators |
| **Disk IOPS** | I/O operations per second | Read/write operations | Near provisioned IOPS limit |
| **Network Throughput** | Network in/out | MB/s, packets/s | > 70% of interface capacity |
| **Message Rate** | Messages processed | Messages per second | Approaching tested limits |
| **Partition Count** | Total active partitions | Count per broker | > 2000 partitions per broker |
| **Request Queue Time** | Request processing delays | p95/p99 latencies | Increasing queue times |
| **Consumer Lag** | Message processing backlog | Messages, time behind | Persistent or growing lag |

### Growth Forecasting
Capacity planning uses the following methodologies:

1. **Historical Trend Analysis**
   - Collection of 12+ months of historical data
   - Seasonal pattern identification
   - Growth rate calculations per domain

2. **Business Driver Correlation**
   - Mapping of business metrics to platform metrics
   - Correlation of user growth to message volume
   - New product/feature impact modeling

3. **Scenario Planning**
   - Best/worst case modeling
   - Peak season preparation
   - Disaster recovery capacity requirements

## Broker Scaling Strategies

### Vertical Scaling Guidelines

| Resource | Starting Size | Scaling Increment | Maximum Size | Notes |
|----------|---------------|-------------------|--------------|-------|
| **CPU** | 8 cores | 4 cores | 32 cores | Monitor CPU idle % for scaling decisions |
| **Memory** | 32 GB | 16 GB | 128 GB | Keep heap at 50-70% of container memory |
| **JVM Heap** | 16 GB | 8 GB | 64 GB | Monitor GC patterns when scaling |
| **Disk** | 1 TB | 500 GB | 5 TB | Scale based on retention + 30% headroom |
| **IOPS** | 3000 | 1000 | 10000 | Critical for performance, especially for producers |
| **Network** | 10 Gbps | 10 Gbps | 40 Gbps | Ensure sufficient bandwidth for replication |

#### Scaling Decision Matrix

```
                  CPU Utilization
                  Low (<50%)    Medium (50-70%)    High (>70%)
Network    Low    No Change     No Change          Scale CPU
Util.      Med    No Change     Scale Network      Scale Both
           High   Scale Network Scale Network      Scale Both

                  Memory Utilization
                  Low (<60%)    Medium (60-80%)    High (>80%)
GC         Low    No Change     No Change          Scale Memory
Pressure   Med    No Change     Scale Memory       Scale Memory
           High   Scale Memory  Scale Memory       Scale Memory
```

### Horizontal Scaling Guidelines

#### Broker Scaling Thresholds

| Metric | Warning Threshold | Scaling Threshold | Emergency Threshold |
|--------|-------------------|-------------------|---------------------|
| **Message Rate** | > 70% of tested max | > 80% of tested max | > 90% of tested max |
| **Partition Count** | > 1500/broker | > 2000/broker | > 2500/broker |
| **Request Latency** | > 10ms p95 | > 20ms p95 | > 50ms p95 |
| **Resource Utilization** | > 70% sustained | > 80% sustained | > 90% sustained |

#### Broker Addition Process
1. **Pre-scaling Assessment**
   - Validate current performance metrics
   - Verify scaling is the appropriate solution
   - Determine optimal timing for scaling operation

2. **Infrastructure Provisioning**
   - Deploy new broker nodes through infrastructure as code
   - Apply standardized configuration
   - Integrate with monitoring systems

3. **Controlled Integration**
   - Add brokers to the cluster one at a time
   - Monitor rebalancing impact
   - Verify cluster stability between additions

4. **Post-scaling Validation**
   - Validate even distribution of partitions
   - Verify replication is healthy
   - Confirm performance improvements

## Topic and Partition Scaling

### Partition Count Calculation
The optimal partition count is determined by the formula:

```
Optimal Partition Count = MAX(
  Throughput_Requirements_Factor,
  Consumer_Parallelism_Factor,
  Minimum_Partitions
)

Where:
- Throughput_Requirements_Factor = Expected_Peak_Throughput_MB_per_Sec / Single_Partition_Throughput_MB_per_Sec
- Consumer_Parallelism_Factor = Target_Consumer_Parallelism * Consumer_Replication_Factor
- Minimum_Partitions = 6 (default)
```

### Partition Scaling Guidelines

| Message Volume | Starting Partitions | Max Partitions | Scaling Increment |
|----------------|---------------------|----------------|-------------------|
| Low (<10 MB/s) | 6 | 12 | 3 |
| Medium (10-50 MB/s) | 12 | 24 | 6 |
| High (50-100 MB/s) | 24 | 48 | 12 |
| Very High (>100 MB/s) | 48 | 96+ | 24 |

### Partition Scaling Process
1. **Impact Assessment**
   - Calculate expected rebalancing impact
   - Identify dependent consumer groups
   - Plan for transient performance impact

2. **Repartitioning Strategy**
   - For new topics: Create with target partition count
   - For existing topics:
     - Option 1: Create new topic with desired partitions and migrate data
     - Option 2: Increase partitions (if key distribution allows)

3. **Implementation Approach**
   - Low-risk: Scheduled maintenance window
   - Zero-downtime: Consumer group aware migration

## Consumer Group Scaling

### Consumer Scaling Guidelines

| Lag Metric | Warning Threshold | Scaling Threshold | Max Consumers |
|------------|-------------------|-------------------|---------------|
| **Consumer Lag (records)** | > 10,000 records sustained | > 50,000 records sustained | Partition count |
| **Consumer Lag (time)** | > 30 seconds behind | > 2 minutes behind | Partition count |
| **Consumer CPU** | > 70% sustained | > 80% sustained | Application dependent |
| **Throughput per Consumer** | > 70% of benchmark | > 80% of benchmark | Application dependent |

### Consumer Scaling Strategies
1. **Static Consumer Scaling**
   - Predetermined consumer count based on expected load
   - Deployed through infrastructure as code
   - Adjusted manually based on monitoring

2. **Dynamic Consumer Scaling**
   - Kubernetes HPA (Horizontal Pod Autoscaler) based on metrics
   - Auto-scaling based on consumer lag metrics
   - Automatic scaling within defined boundaries

3. **Consumer Tuning**
   - Batch size optimization
   - Poll interval tuning
   - Processing pipeline optimization

## Schema Registry Scaling

### Schema Registry Sizing Guidelines

| Active Schemas | Recommended Instances | Memory per Instance | CPU per Instance |
|----------------|----------------------|---------------------|------------------|
| <1,000 | 3 | 2 GB | 2 cores |
| 1,000-5,000 | 5 | 4 GB | 4 cores |
| 5,000-10,000 | 7 | 8 GB | 4 cores |
| >10,000 | 9+ | 16 GB | 8 cores |

### Registry Scaling Considerations
- Read-heavy workload optimization
- Cache size tuning
- Database backend scaling
- Connection pooling configuration

## Regional Scaling

### Multi-Region Deployment Models

| Model | Description | Use Case | Scaling Considerations |
|-------|-------------|----------|------------------------|
| **Active-Passive** | Primary region with standby | Basic disaster recovery | Capacity for full failover |
| **Active-Active** | Multiple active regions | Global distribution, regional data residency | Cross-region replication capacity |
| **Hub and Spoke** | Central hub with regional spokes | Edge processing with centralized aggregation | Hub designed for aggregate capacity |
| **Mesh** | Peer-to-peer regional connectivity | Complex data sharing patterns | N-way replication capacity |

### Multi-Region Data Flow Optimization
- Topic prioritization for replication
- Intelligent routing for regional affinity
- Replication factor tuning for cross-region topics
- Bandwidth allocation and throttling

## Scaling for Special Use Cases

### High Throughput Event Streams
- Dedicated broker groups for high-volume topics
- Tuned Linux kernel parameters for network performance
- Optimized disk I/O configuration
- Specialized consumer configurations

### Low Latency Requirements
- Network optimization for reduced latency
- Partition placement strategy for co-location
- Producer acks and batching tuning
- JVM tuning for consistent performance

### Compliance-Driven Workloads
- Encryption overhead considerations
- Audit logging capacity planning
- Additional resource allocation for security features
- Separated workloads for regulated/non-regulated data

## Implementation Examples

### Broker Sizing Example

```yaml
# Kafka broker resource configuration example
apiVersion: platform.confluent.io/v1beta1
kind: Kafka
metadata:
  name: kafka-prod
  namespace: event-broker
spec:
  replicas: 12  # Horizontal scaling
  image:
    application: confluentinc/cp-server:7.3.1
  resources:     # Vertical scaling
    requests:
      cpu: "8"
      memory: "32Gi"
    limits:
      cpu: "12"
      memory: "48Gi"
  dataVolumeCapacity: "2Ti"  # Storage scaling
  configOverrides:
    server:
      # Performance tuning
      - "num.io.threads=16"
      - "num.network.threads=8"
      - "socket.receive.buffer.bytes=1048576"
      - "socket.send.buffer.bytes=1048576"
      - "replica.fetch.max.bytes=10485760"
    jvm:
      - "-Xms24g"         # Heap tuning
      - "-Xmx24g"
      - "-XX:+UseG1GC"
      - "-XX:MaxGCPauseMillis=20"
```

### Topic Scaling Example

```bash
# Script excerpt for calculating and scaling topic partitions
#!/bin/bash

# Input parameters
TOPIC_NAME=$1
PEAK_THROUGHPUT_MB=$2  # Expected peak throughput in MB/s
CONSUMER_PARALLELISM=$3  # Desired consumer parallelism

# Constants
SINGLE_PARTITION_THROUGHPUT=10  # MB/s per partition (benchmark derived)
REPLICATION_FACTOR=3
MIN_PARTITIONS=6

# Calculate optimal partition count
THROUGHPUT_FACTOR=$((PEAK_THROUGHPUT_MB / SINGLE_PARTITION_THROUGHPUT))
CONSUMER_FACTOR=$((CONSUMER_PARALLELISM * 2))  # 2x for growth

# Get the maximum value
if [ $THROUGHPUT_FACTOR -gt $CONSUMER_FACTOR ]; then
  OPTIMAL_PARTITIONS=$THROUGHPUT_FACTOR
else
  OPTIMAL_PARTITIONS=$CONSUMER_FACTOR
fi

if [ $OPTIMAL_PARTITIONS -lt $MIN_PARTITIONS ]; then
  OPTIMAL_PARTITIONS=$MIN_PARTITIONS
fi

# Round to nearest multiple of 6
OPTIMAL_PARTITIONS=$(( (OPTIMAL_PARTITIONS + 5) / 6 * 6 ))

echo "Calculated optimal partitions for $TOPIC_NAME: $OPTIMAL_PARTITIONS"

# Check current partition count
CURRENT_PARTITIONS=$(kafka-topics --bootstrap-server kafka:9092 --describe --topic $TOPIC_NAME | grep "PartitionCount" | awk '{print $2}')

if [ -z "$CURRENT_PARTITIONS" ]; then
  # New topic
  echo "Creating new topic with $OPTIMAL_PARTITIONS partitions"
  kafka-topics --bootstrap-server kafka:9092 --create --topic $TOPIC_NAME \
    --partitions $OPTIMAL_PARTITIONS --replication-factor $REPLICATION_FACTOR
else
  if [ $CURRENT_PARTITIONS -lt $OPTIMAL_PARTITIONS ]; then
    echo "Scaling topic from $CURRENT_PARTITIONS to $OPTIMAL_PARTITIONS partitions"
    kafka-topics --bootstrap-server kafka:9092 --alter --topic $TOPIC_NAME \
      --partitions $OPTIMAL_PARTITIONS
  else
    echo "Current partition count ($CURRENT_PARTITIONS) is sufficient"
  fi
fi
```

## Related Resources
- [Event Broker Deployment](./deployment.md)
- [Event Broker Monitoring](./monitoring.md)
- [Event Broker Troubleshooting](./troubleshooting.md)