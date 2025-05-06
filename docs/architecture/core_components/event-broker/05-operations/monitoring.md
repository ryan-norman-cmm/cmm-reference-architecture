# Event Broker Monitoring

## Introduction
This document outlines the monitoring architecture, metrics, and alerting strategies for the Event Broker platform at CoverMyMeds. Effective monitoring is essential for maintaining high availability, performance, and reliability of the event-driven architecture that powers critical healthcare processes.

## Monitoring Architecture

### Monitoring Components
The Event Broker monitoring stack consists of the following components:

| Component | Technology | Purpose |
|-----------|------------|---------|
| **Metrics Collection** | Prometheus | Collection and storage of time-series metrics |
| **Metrics Visualization** | Grafana | Dashboards and visual analysis |
| **Distributed Tracing** | OpenTelemetry + Jaeger | End-to-end transaction tracing |
| **Log Management** | Elasticsearch + Kibana | Centralized log storage and analysis |
| **Alerting** | AlertManager + PagerDuty | Alert notification and routing |
| **Synthetic Monitoring** | Synthetic Producer/Consumer | Proactive testing of event flows |
| **Health Checking** | Health Check Service | Component and endpoint availability |

### Monitoring Architecture Diagram

```
┌─────────────────────────┐     ┌───────────────────────┐     ┌───────────────────────┐
│                         │     │                       │     │                       │
│    Kafka Brokers        │────▶│    Prometheus         │────▶│     Grafana           │
│                         │     │                       │     │                       │
└─────────────────────────┘     └───────────────────────┘     └───────────────────────┘
          │                                                              ▲
          │                                                              │
          ▼                                                              │
┌─────────────────────────┐     ┌───────────────────────┐               │
│                         │     │                       │               │
│    JMX Exporters        │────▶│    AlertManager       │──────────────┘
│                         │     │                       │
└─────────────────────────┘     └───────────────────────┘
                                            │
┌─────────────────────────┐                 │
│                         │                 ▼
│    Confluent            │     ┌───────────────────────┐     ┌───────────────────────┐
│    Control Center       │     │                       │     │                       │
│                         │     │    PagerDuty          │────▶│     On-Call Team      │
└─────────────────────────┘     │                       │     │                       │
          │                     └───────────────────────┘     └───────────────────────┘
          │
          ▼
┌─────────────────────────┐     ┌───────────────────────┐     ┌───────────────────────┐
│                         │     │                       │     │                       │
│    Application Logs     │────▶│    Elasticsearch      │────▶│     Kibana            │
│                         │     │                       │     │                       │
└─────────────────────────┘     └───────────────────────┘     └───────────────────────┘
```

## Key Metrics and Dimensions

### Broker Metrics

| Metric Name | Description | Warning Threshold | Critical Threshold |
|-------------|-------------|-------------------|-------------------|
| `kafka_server_brokertopicmetrics_messagesin_total` | Message rate per topic | Varies by topic | Varies by topic |
| `kafka_server_replicamanager_underreplicatedpartitions` | Under-replicated partitions | > 0 for > 5 min | > 0 for > 15 min |
| `kafka_controller_activecontrollercount` | Active controller count | != 1 | != 1 for > 5 min |
| `kafka_server_replicamanager_isrshrinks_total` | Rate of ISR shrinks | > 0 | > 5 / min |
| `kafka_network_requestmetrics_requestqueuetimems` | Time in request queue | > 100ms p95 | > 500ms p95 |
| `kafka_server_replicafetchermanager_maxlag` | Max lag in messages | Topic specific | Topic specific |
| `jvm_memory_bytes_used` | JVM memory usage | > 80% | > 90% |
| `kafka_network_processor_idlepercent` | Network thread idle % | < 20% | < 10% |
| `system_cpu_usage` | CPU usage | > 70% | > 85% |
| `system_disk_usage` | Disk usage | > 75% | > 85% |

### Consumer Metrics

| Metric Name | Description | Warning Threshold | Critical Threshold |
|-------------|-------------|-------------------|-------------------|
| `kafka_consumer_consumer_fetch_manager_metrics_records_lag_max` | Maximum lag in records | > 10000 | > 50000 |
| `kafka_consumer_consumer_fetch_manager_metrics_records_lag_avg` | Average lag in records | > 5000 | > 25000 |
| `kafka_consumer_consumer_coordinator_metrics_commit_latency_avg` | Avg commit latency | > 200ms | > 500ms |
| `kafka_consumer_consumer_fetch_manager_metrics_fetch_rate` | Records consumed per second | < expected minimum | < critical minimum |
| `kafka_consumer_consumer_fetch_manager_metrics_fetch_throttle_time_avg` | Average fetch throttle time | > 100ms | > 500ms |

### Producer Metrics

| Metric Name | Description | Warning Threshold | Critical Threshold |
|-------------|-------------|-------------------|-------------------|
| `kafka_producer_producer_metrics_record_send_rate` | Record send rate | < expected minimum | < critical minimum |
| `kafka_producer_producer_metrics_request_latency_avg` | Average request latency | > 100ms | > 250ms |
| `kafka_producer_producer_metrics_record_error_rate` | Record error rate | > 0.1% | > 1% |
| `kafka_producer_producer_metrics_record_retry_rate` | Record retry rate | > 0.5% | > 5% |
| `kafka_producer_producer_metrics_buffer_available_bytes` | Producer buffer bytes available | < 20% of max | < 10% of max |

### Topic-Level Metrics

| Metric Name | Description | Warning Threshold | Critical Threshold |
|-------------|-------------|-------------------|-------------------|
| `kafka_server_brokertopicmetrics_bytesin_total{topic="..."}` | Bytes in rate per topic | Varies by topic | Varies by topic |
| `kafka_server_brokertopicmetrics_bytesout_total{topic="..."}` | Bytes out rate per topic | Varies by topic | Varies by topic |
| `kafka_topic_partition_size` | Partition size in bytes | > 80% of limit | > 90% of limit |
| `kafka_topic_partition_highwatermark` | Partition high watermark | N/A (monitoring) | N/A (monitoring) |
| `kafka_topic_partition_lowwatermark` | Partition low watermark | N/A (monitoring) | N/A (monitoring) |

### Schema Registry Metrics

| Metric Name | Description | Warning Threshold | Critical Threshold |
|-------------|-------------|-------------------|-------------------|
| `schema_registry_master_slave_role` | Registry role (0=slave, 1=master) | N/A (monitoring) | != 1 for master nodes |
| `schema_registry_jersey_metrics_request_time` | Request processing time | > 200ms p95 | > 500ms p95 |
| `schema_registry_jersey_metrics_request_rate` | Request rate | N/A (trending) | N/A (trending) |
| `schema_registry_schema_validation_failure` | Schema validation failures | > 0 | > 0 for > 15 min |

## Monitoring by Service Tier

### Critical Business Event Streams
Topics that support critical healthcare workflows require enhanced monitoring:

- Higher frequency of metric collection (15s intervals)
- Shorter alerting windows (3-5 minutes)
- Dedicated dashboards with business context
- Lower thresholds for alerting
- Priority routing in alert management
- Synthetic transaction monitoring

### Standard Business Event Streams
Regular business topics receive standard monitoring:

- Normal metric collection frequency (30s intervals)
- Standard alerting windows (5-10 minutes)
- Grouped dashboards by domain
- Regular alert thresholds
- Standard alert routing

### System Topics
Internal system topics receive operational monitoring:

- Regular metric collection frequency
- Longer alerting windows for transient issues
- Technical operations dashboards
- Operational focus on alerts
- Routed to platform team

## Alerting Strategy

### Alert Severity Levels

| Level | Description | Response Time | Notification | Example Scenario |
|-------|-------------|---------------|--------------|------------------|
| **P1 - Critical** | Service outage, data loss risk | Immediate (24/7) | PagerDuty, SMS, Call | Broker cluster failure, data replication stopped |
| **P2 - High** | Severe degradation, no data loss | 30 min (24/7) | PagerDuty, SMS | Significant lag, 1+ broker down, performance degradation |
| **P3 - Medium** | Minor service impact | 2 hours (business hours) | Email, Slack | Increased latency, warning thresholds crossed |
| **P4 - Low** | No immediate impact | Next business day | Email, Ticket | Capacity threshold approaching, minor anomalies |

### Alert Grouping and Routing
- Alerts grouped by component and domain
- Routing based on topic ownership
- Escalation paths based on severity
- Auto-resolution for transient issues
- Silencing with mandatory notes
- Maintenance mode integration

### Alert Content
Standard alert content includes:
- Concise, actionable subject line
- Metric name and current value
- Threshold and percentage of deviation
- Topic/consumer group affected
- Link to relevant dashboard
- Potential impact assessment
- Runbook link for remediation steps

### Alert Suppression and Correlation
- Correlation across related metrics to reduce alert storms
- Alert suppression during maintenance windows
- Rate limiting for flapping alerts
- Intelligent grouping of similar alerts
- Tiered escalation based on duration

## Dashboards and Visualization

### Standard Dashboard Suite

| Dashboard | Purpose | Primary Audience |
|-----------|---------|------------------|
| **Cluster Overview** | High-level health and performance | Platform team, leadership |
| **Broker Performance** | Detailed broker metrics | Platform engineers |
| **Topic Metrics** | Per-topic performance metrics | Application teams, platform team |
| **Consumer Group Health** | Consumer lag and performance | Application teams |
| **Producer Metrics** | Producer performance and errors | Application teams |
| **Schema Registry** | Schema management and performance | Data governance, platform team |
| **Capacity Planning** | Growth trends and capacity analysis | Platform team, architecture |
| **SLA Compliance** | SLA metrics and compliance tracking | Leadership, platform team |

### Dashboard Organization
- Hierarchical organization from overview to detail
- Consistent layout and color schemes
- Standard time ranges and refresh intervals
- Drill-down capability from high-level to details
- Business context alongside technical metrics
- Documentation links for interpretation

## Logging Strategy

### Log Collection
- Broker logs collected via Filebeat
- Application client logs collected via application agents
- Structured logging in JSON format
- Standardized log levels across components
- Log enrichment with trace IDs and metadata

### Log Retention
- Hot storage: 7 days in Elasticsearch
- Warm storage: 30 days in Elasticsearch
- Cold storage: 1 year in S3
- Compliance-driven retention for audit logs

### Log Correlation
- Correlation IDs across producer/broker/consumer chains
- Integration with distributed tracing
- Business context enrichment
- Topic and consumer group tagging

## End-to-End Monitoring

### Synthetic Transactions
- Continuous producer-consumer testing for critical topics
- End-to-end latency measurements
- Schema compatibility verification
- Data integrity validation
- Circuit breaker testing

### Business Process Monitoring
- Cross-service transaction tracking
- Business event completion verification
- SLA monitoring for business processes
- Event sequence validation
- Event-to-business outcome correlation

## Health Checks and Probes

### Liveness Probes
- TCP socket checks for broker availability
- REST endpoint checks for Schema Registry and REST Proxy
- Controller election status verification
- JVM health verification

### Readiness Probes
- Topic metadata availability
- Producer/consumer API availability
- Authorization system functionality
- Schema Registry query capability

## Monitoring Implementation

### Metric Collection Configuration

```yaml
# Example Prometheus scrape configuration
scrape_configs:
  - job_name: 'kafka_brokers'
    kubernetes_sd_configs:
      - role: pod
        namespaces:
          names: ['event-broker']
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_label_app]
        regex: kafka
        action: keep
    scrape_interval: 15s
    scrape_timeout: 10s
    metrics_path: /metrics
    scheme: https
    tls_config:
      insecure_skip_verify: false
      ca_file: /etc/prometheus/certs/ca.crt
    basic_auth:
      username: prometheus
      password_file: /etc/prometheus/secrets/monitoring-auth

  - job_name: 'schema_registry'
    kubernetes_sd_configs:
      - role: pod
        namespaces:
          names: ['event-broker']
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_label_app]
        regex: schema-registry
        action: keep
    scrape_interval: 15s
    metrics_path: /metrics
```

### Alert Rule Example

```yaml
# Example alert rules for Kafka
groups:
- name: kafka_broker_alerts
  rules:
  - alert: KafkaBrokerDown
    expr: sum(up{job="kafka_brokers"}) < count(up{job="kafka_brokers"})
    for: 5m
    labels:
      severity: high
      service: kafka
      team: platform
    annotations:
      summary: "Kafka broker down"
      description: "{{ $value }} of {{ count(up{job='kafka_brokers'}) }} Kafka brokers are down"
      runbook_url: "https://wiki.covermymeds.com/event-broker/runbooks/broker-recovery"

  - alert: KafkaUnderReplicatedPartitions
    expr: sum(kafka_server_replicamanager_underreplicatedpartitions) > 0
    for: 10m
    labels:
      severity: medium
      service: kafka
      team: platform
    annotations:
      summary: "Kafka under-replicated partitions"
      description: "{{ $value }} partitions are under-replicated"
      runbook_url: "https://wiki.covermymeds.com/event-broker/runbooks/replication-issues"
```

## Related Resources
- [Event Broker Deployment](./deployment.md)
- [Event Broker Scaling](./scaling.md)
- [Event Broker Troubleshooting](./troubleshooting.md)