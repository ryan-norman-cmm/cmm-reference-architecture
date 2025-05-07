# Event Broker Troubleshooting

## Introduction
This document provides a comprehensive guide for diagnosing and resolving common issues with the Event Broker platform at CoverMyMeds. It serves as a reference for operations teams, platform engineers, and application developers to efficiently identify and resolve problems across the event-driven architecture.

## Troubleshooting Approach

### Methodology
Follow this structured approach for effective troubleshooting:

1. **Identify the Symptom**
   - Clearly define the observed behavior
   - Determine the scope of impact
   - Establish a timeline of when the issue started

2. **Gather Information**
   - Collect relevant logs, metrics, and alerts
   - Identify any recent changes or deployments
   - Obtain application and user context

3. **Form Hypotheses**
   - Develop potential explanations for the observed behavior
   - Prioritize hypotheses based on likelihood and impact
   - Determine what evidence would support or refute each

4. **Test and Verify**
   - Systematically test each hypothesis
   - Use minimally invasive diagnostic techniques first
   - Document all findings and results

5. **Implement Solution**
   - Apply the appropriate fix based on diagnosis
   - Verify the resolution resolves the symptom
   - Monitor for any unexpected side effects

6. **Document and Share**
   - Record the issue, diagnosis, and resolution
   - Update runbooks and documentation
   - Share findings with relevant teams

## Common Issues and Resolutions

### Broker Issues

#### High CPU Utilization

**Symptoms:**
- Broker CPU consistently above 80%
- Increased request latency
- Producer/consumer timeouts

**Diagnostic Steps:**
1. Check request metrics to identify hot partitions or topics
2. Analyze thread dumps to identify CPU-intensive operations
3. Review message sizes and throughput patterns
4. Examine Linux `top`/`htop` output for process details

**Potential Causes and Solutions:**

| Cause | Diagnostic Indicators | Resolution |
|-------|----------------------|------------|
| **Message overload** | High message rates, specific topics | Increase partition count, throttle producers |
| **Inefficient message serialization** | Large message sizes, high serialization time | Optimize message format, consider compression |
| **Undersized brokers** | Sustained high CPU across all activities | Vertically scale brokers, add more brokers |
| **JVM GC pressure** | High GC time in JVM metrics | Tune GC parameters, increase heap appropriately |
| **OS-level contention** | High CPU wait time, system processes | Isolate noisy neighbors, adjust resource limits |

**Resolution Example:**
```bash
# Check for high message rates per topic
kafka-run-class kafka.tools.GetOffsetShell --broker-list kafka:9092 --topic high-volume-topic --time -1

# Increase partitions if needed
kafka-topics --bootstrap-server kafka:9092 --alter --topic high-volume-topic --partitions 24

# Apply producer throttling if necessary
kafka-configs --bootstrap-server kafka:9092 --entity-type clients --entity-name heavy-producer --alter --add-config producer_byte_rate=10485760
```

#### Under-Replicated Partitions

**Symptoms:**
- Non-zero `UnderReplicatedPartitions` metric
- Delayed message delivery
- Potential data loss risk

**Diagnostic Steps:**
1. Identify affected topics and partitions
2. Check broker logs for replication errors
3. Verify network connectivity between brokers
4. Examine disk space and I/O performance

**Potential Causes and Solutions:**

| Cause | Diagnostic Indicators | Resolution |
|-------|----------------------|------------|
| **Network issues** | Timeouts in logs, network errors | Resolve network latency or partition issues |
| **Disk space shortage** | High disk utilization alerts | Free disk space, expand volumes, clean log segments |
| **I/O bottlenecks** | High disk wait time, slow I/O | Upgrade storage, optimize I/O scheduler |
| **Broker overload** | High CPU, memory pressure | Scale vertically/horizontally, balance partitions |
| **Broker failure** | Missing heartbeats, broker offline | Replace failed broker, restore from replica |

**Resolution Example:**
```bash
# Check for under-replicated partitions
kafka-topics --bootstrap-server kafka:9092 --describe --under-replicated

# Verify disk space
df -h /kafka/data

# Manually reassign partitions if needed
echo '{"version":1,"partitions":[{"topic":"problematic-topic","partition":5,"replicas":[1,2,3]}]}' > reassign.json
kafka-reassign-partitions --bootstrap-server kafka:9092 --reassignment-json-file reassign.json --execute
```

#### Leader Election Issues

**Symptoms:**
- Frequent leader changes
- Delays in message processing
- Controller logs showing repeated elections

**Diagnostic Steps:**
1. Check ZooKeeper/KRaft logs for session expirations
2. Review broker logs for leadership changes
3. Analyze network latency between brokers
4. Examine controller metrics and logs

**Potential Causes and Solutions:**

| Cause | Diagnostic Indicators | Resolution |
|-------|----------------------|------------|
| **Network instability** | Intermittent connectivity, timeouts | Fix network issues, adjust timeouts |
| **ZooKeeper problems** | ZK session timeouts, high latency | Resolve ZK issues, scale ZK if needed |
| **JVM GC pauses** | Long GC pauses in controller | Tune GC parameters to reduce pause times |
| **Resource contention** | CPU/memory pressure on controllers | Dedicate resources to controller nodes |
| **Misconfigurations** | Inconsistent broker settings | Standardize broker configurations |

### Consumer Issues

#### High Consumer Lag

**Symptoms:**
- Increasing consumer lag metrics
- Delayed processing of events
- Consumer group rebalancing frequently

**Diagnostic Steps:**
1. Monitor consumer lag metrics over time
2. Check consumer log for processing errors
3. Analyze consumer resource utilization
4. Verify topic throughput and partition count

**Potential Causes and Solutions:**

| Cause | Diagnostic Indicators | Resolution |
|-------|----------------------|------------|
| **Slow processing** | High processing time per record | Optimize consumer code, batch processing |
| **Insufficient consumers** | Consumers maxed on resources | Add more consumer instances |
| **Partition imbalance** | Uneven partition assignment | Ensure partition count > consumer count |
| **Producer spike** | Sudden increase in production rate | Implement backpressure mechanisms |
| **External dependency** | Slow downstream system | Circuit breaking, async processing |

**Resolution Example:**
```bash
# Check consumer group lag
kafka-consumer-groups --bootstrap-server kafka:9092 --group slow-consumer-group --describe

# Assess partition distribution
kafka-consumer-groups --bootstrap-server kafka:9092 --group slow-consumer-group --describe

# Increase partition count if needed
kafka-topics --bootstrap-server kafka:9092 --alter --topic high-lag-topic --partitions 24
```

#### Consumer Rebalancing Issues

**Symptoms:**
- Frequent rebalances in consumer logs
- Periods of no processing
- Consumers appearing/disappearing from group

**Diagnostic Steps:**
1. Check consumer logs for join/leave events
2. Monitor consumer heartbeat metrics
3. Examine consumer resource utilization
4. Verify network stability between consumers and brokers

**Potential Causes and Solutions:**

| Cause | Diagnostic Indicators | Resolution |
|-------|----------------------|------------|
| **Insufficient session timeout** | Heartbeats missing deadlines | Increase session.timeout.ms |
| **Consumer crashes** | Error logs, OOM errors | Fix application bugs, increase resources |
| **Network instability** | Intermittent connectivity | Resolve network issues, adjust heartbeat interval |
| **Uneven workload** | Some partitions process slower | Implement custom partition assignment |
| **Too many rebalance listeners** | Long rebalance times | Optimize rebalance listeners, static membership |

**Resolution Example:**
```java
// Consumer configuration to reduce rebalancing issues
Properties props = new Properties();
props.put(ConsumerConfig.GROUP_ID_CONFIG, "stable-consumer-group");
props.put(ConsumerConfig.SESSION_TIMEOUT_MS_CONFIG, "30000"); // Increase timeout
props.put(ConsumerConfig.HEARTBEAT_INTERVAL_MS_CONFIG, "10000"); // More frequent heartbeats
props.put(ConsumerConfig.MAX_POLL_INTERVAL_MS_CONFIG, "300000"); // Longer processing time allowed
props.put(ConsumerConfig.GROUP_INSTANCE_ID_CONFIG, "consumer-" + instanceId); // Static membership
```

### Producer Issues

#### Failed Message Production

**Symptoms:**
- Producer error logs showing failures
- Increasing error rates in metrics
- Application reporting message send failures

**Diagnostic Steps:**
1. Check producer logs for specific error messages
2. Verify broker availability and health
3. Test network connectivity to brokers
4. Examine authorization logs for permission issues

**Potential Causes and Solutions:**

| Cause | Diagnostic Indicators | Resolution |
|-------|----------------------|------------|
| **Broker unavailability** | Connection errors, timeouts | Resolve broker issues, check network |
| **Authorization failures** | Permission denied errors | Fix ACLs, verify client credentials |
| **Network issues** | Connection timeouts, retries | Resolve network problems, adjust timeouts |
| **Message size limits** | Message too large errors | Adjust message.max.bytes, compress messages |
| **Resource exhaustion** | Buffer exhausted errors | Increase buffer memory, implement backpressure |

**Resolution Example:**
```java
// Producer configuration for improved reliability
Properties props = new Properties();
props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, "kafka-1:9092,kafka-2:9092,kafka-3:9092");
props.put(ProducerConfig.ACKS_CONFIG, "all"); // Ensure durability
props.put(ProducerConfig.RETRIES_CONFIG, 10); // Retry on transient failures
props.put(ProducerConfig.RETRY_BACKOFF_MS_CONFIG, 100); // Backoff between retries
props.put(ProducerConfig.MAX_IN_FLIGHT_REQUESTS_PER_CONNECTION, 1); // Preserve ordering with retries
props.put(ProducerConfig.ENABLE_IDEMPOTENCE_CONFIG, true); // Prevent duplicates
```

#### Message Ordering Issues

**Symptoms:**
- Messages processed out of sequence
- Application business logic errors due to ordering
- Duplicate message processing

**Diagnostic Steps:**
1. Verify producer configuration for ordering guarantees
2. Check consumer group partition assignment
3. Examine topic configuration (partitions, keys)
4. Analyze message timestamps and offsets

**Potential Causes and Solutions:**

| Cause | Diagnostic Indicators | Resolution |
|-------|----------------------|------------|
| **Multi-partition without keys** | Messages spread across partitions | Use consistent partition keys |
| **Multiple in-flight requests** | Out of order delivery with retries | Set max.in.flight.requests=1 |
| **Consumer parallelism** | Multiple consumers processing same flow | Ensure key affinity to partitions |
| **Idempotence disabled** | Duplicate messages after retries | Enable idempotent producer |
| **Rebalancing disruption** | Ordering issues after rebalances | Use static group membership |

### Schema Registry Issues

#### Schema Compatibility Failures

**Symptoms:**
- Producer errors when registering schemas
- Schema evolution failures
- Missing or rejected messages

**Diagnostic Steps:**
1. Check Schema Registry logs for compatibility errors
2. Compare failed schema with existing schema versions
3. Verify compatibility settings for the subject
4. Test schema changes with compatibility endpoint

**Potential Causes and Solutions:**

| Cause | Diagnostic Indicators | Resolution |
|-------|----------------------|------------|
| **Breaking changes** | Detailed compatibility errors | Revise schema to maintain compatibility |
| **Wrong compatibility setting** | Unexpected compatibility enforcement | Adjust compatibility setting if appropriate |
| **Schema reference issues** | Reference resolution errors | Fix schema references, ensure dependencies available |
| **Schema Registry unavailability** | Connection errors to registry | Resolve Schema Registry availability issues |
| **Authorization problems** | Permission denied for schema updates | Fix Schema Registry permissions |

**Resolution Example:**
```bash
# Check current compatibility setting
curl -X GET http://schema-registry:8081/config

# Temporarily relax compatibility for migration
curl -X PUT -H "Content-Type: application/json" \
  --data '{"compatibility": "NONE"}' \
  http://schema-registry:8081/config/subject-name

# Register new schema
curl -X POST -H "Content-Type: application/json" \
  --data '{"schema": "{\"type\":\"record\",\"name\":\"Payment\",\"fields\":[...]}"}' \
  http://schema-registry:8081/subjects/payments-value/versions

# Restore stricter compatibility
curl -X PUT -H "Content-Type: application/json" \
  --data '{"compatibility": "BACKWARD"}' \
  http://schema-registry:8081/config/subject-name
```

## Operational Troubleshooting

### Cluster Health Verification

Use these commands to assess overall cluster health:

```bash
# Check broker status
kafka-broker-api-versions --bootstrap-server kafka:9092

# Verify topic health
kafka-topics --bootstrap-server kafka:9092 --describe --under-replicated

# Check controller status
kafka-topics --bootstrap-server kafka:9092 --describe --under-replicated --zookeeper zookeeper:2181

# Validate partition distribution
kafka-topics --bootstrap-server kafka:9092 --describe --topic important-topic
```

### Performance Diagnostics

Commands for diagnosing performance issues:

```bash
# Topic performance metrics
kafka-run-class kafka.tools.GetOffsetShell --broker-list kafka:9092 --time -1 --topic slow-topic

# Consumer group performance
kafka-consumer-groups --bootstrap-server kafka:9092 --group slow-consumer --describe

# Producer performance test
kafka-producer-perf-test --topic test-topic --num-records 1000000 --record-size 1000 --throughput 10000 --producer-props bootstrap.servers=kafka:9092

# Consumer performance test
kafka-consumer-perf-test --bootstrap-server kafka:9092 --topic test-topic --messages 1000000 --group perf-test-group
```

### Log Analysis Techniques

Effective log analysis strategies:

1. **Correlation by Time Window**
   - Gather logs from producers, brokers, and consumers for the same timeframe
   - Look for patterns of errors or warnings that coincide across components

2. **Error Pattern Identification**
   - Search for common error patterns: timeouts, connection issues, authorization failures
   - Group similar errors to identify systemic vs. isolated issues

3. **Request Tracing**
   - Use correlation IDs to trace message flow through the system
   - Follow specific messages from production to consumption

4. **Contextual Analysis**
   - Consider recent changes, deployments, or environment factors
   - Look for patterns related to time of day, load patterns, or external dependencies

### Troubleshooting Decision Tree

Use this decision tree for common Event Broker issues:

```
Event Broker Issue
├── Producer Issues
│   ├── Can't connect to broker
│   │   ├── Network issue → Check network connectivity, DNS resolution
│   │   ├── Authentication → Verify credentials, certificates
│   │   └── Authorization → Check ACLs, client permissions
│   ├── Messages not delivered
│   │   ├── Acks=0/1 → Check broker logs, increase acks
│   │   ├── Topic doesn't exist → Create topic or enable auto-creation
│   │   └── Serialization errors → Verify schema, check compatibility
│   └── Performance problems
│       ├── Batch size → Adjust batch.size and linger.ms
│       ├── Compression → Enable/tune compression settings
│       └── Network → Check network throughput, latency
│
├── Broker Issues
│   ├── High CPU/Memory
│   │   ├── Message overload → Add brokers, partitions
│   │   ├── GC pressure → Tune JVM, adjust heap size
│   │   └── Inefficient requests → Identify hot topics, optimize clients
│   ├── Disk issues
│   │   ├── Space shortage → Clean logs, add storage, adjust retention
│   │   ├── I/O bottleneck → Upgrade storage, distribute load
│   │   └── Corrupted files → Replace failed disks, restore from replicas
│   └── Replication problems
│       ├── Network issues → Fix inter-broker network
│       ├── Broker failure → Replace broker, reassign partitions
│       └── Configuration → Adjust replication settings
│
├── Consumer Issues
│   ├── High lag
│   │   ├── Slow processing → Optimize consumer code
│   │   ├── Too few consumers → Add more consumers
│   │   └── Partition imbalance → Adjust partition assignment strategy
│   ├── Frequent rebalancing
│   │   ├── Timeouts → Adjust session timeout, heartbeat interval
│   │   ├── Consumer crashes → Fix application bugs, add resources
│   │   └── Network issues → Stabilize network, increase timeouts
│   └── Message ordering
│       ├── Multi-partition → Use consistent keys, single partition
│       ├── Rebalancing → Implement static group membership
│       └── Processing order → Implement sequence numbers, timestamps
│
└── Schema Registry Issues
    ├── Compatibility errors
    │   ├── Breaking changes → Revise schema to maintain compatibility
    │   ├── Wrong settings → Adjust compatibility mode temporarily
    │   └── Missing references → Add required schema references
    ├── Registry unavailable
    │   ├── Service down → Restart registry, check infrastructure
    │   ├── Network issues → Verify network connections
    │   └── Resource exhaustion → Add resources, scale registry
    └── Performance issues
        ├── Cache misses → Tune client caching
        ├── Registry overload → Scale registry horizontally
        └── Database bottleneck → Optimize backend database
```

## Environment-Specific Troubleshooting

### Development Environment Issues

Common issues in development environments:

1. **Schema Evolution Testing**
   - Set compatibility mode to NONE for rapid iteration
   - Test compatibility before promoting to higher environments
   - Use schema validation tools during development

2. **Local Environment Setup**
   - Docker Compose configuration for local Kafka stack
   - Development-focused configuration parameters
   - Test data generation utilities

### Production Environment Considerations

Special considerations for production troubleshooting:

1. **Minimizing Impact**
   - Use read-only diagnostic commands when possible
   - Schedule potentially disruptive operations during maintenance windows
   - Implement changes incrementally with validation

2. **Coordinated Troubleshooting**
   - Engage multiple teams for cross-component issues
   - Establish war room procedures for critical issues
   - Document timeline of events and actions taken

3. **Data Integrity Verification**
   - Validate message counts before/after remediation
   - Verify consumer position recovery after failures
   - Ensure no message loss during recovery operations

## Preventive Measures

### Proactive Monitoring

Implement these monitoring practices to catch issues early:

1. **Predictive Alerts**
   - Trend-based anomaly detection
   - Early warning indicators before critical thresholds
   - Pattern recognition for recurring issues

2. **End-to-End Checks**
   - Synthetic transaction monitoring
   - Regular health check probes
   - Business process validation

### Resiliency Testing

Regular testing to improve system robustness:

1. **Chaos Engineering**
   - Controlled broker failure testing
   - Network partition simulations
   - Resource constraint exercises

2. **Load Testing**
   - Peak load simulation
   - Horizontal and vertical scaling validation
   - Recovery time measurement

### Runbook Development

Create and maintain comprehensive runbooks:

1. **Issue-Specific Procedures**
   - Step-by-step resolution guides
   - Decision trees for complex scenarios
   - Verification steps to confirm resolution

2. **Regular Practice**
   - Scheduled runbook drills
   - Post-incident runbook updates
   - Knowledge sharing sessions

## Related Resources
- [Event Broker Monitoring](./monitoring.md)
- [Event Broker Scaling](./scaling.md)
- [Event Broker Maintenance](./maintenance.md)