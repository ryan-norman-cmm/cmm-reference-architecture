# FHIR Interoperability Platform Monitoring

## Introduction
This document outlines the monitoring strategy and implementation for the FHIR Interoperability Platform. Comprehensive monitoring is essential for ensuring the reliability, performance, security, and compliance of the platform. This document describes the metrics, logging, dashboards, and alerting configurations that support operational visibility and proactive issue detection.

## Metrics & Alerts

### Key Health Metrics

| Category | Metric | Description | Collection Method | Threshold | Alert Severity |
|----------|--------|-------------|-------------------|-----------|----------------|
| **Availability** | API Endpoint Uptime | Percentage of time FHIR API endpoints are available | Synthetic transactions | <99.9% | Critical |
| **Availability** | Service Health | Health check status of all platform components | Health probe endpoints | Any failure | Critical |
| **Performance** | FHIR API Response Time | Time to complete FHIR API requests | Application instrumentation | >500ms p95 | Warning |
| **Performance** | FHIR API Response Time | Time to complete FHIR API requests | Application instrumentation | >1s p95 | Critical |
| **Performance** | Search Query Performance | Time to execute FHIR search operations | Application instrumentation | >1s p95 | Warning |
| **Performance** | Database Query Time | Time to execute database queries | Database monitoring | >200ms p95 | Warning |
| **Performance** | Database Connection Utilization | Percentage of database connections in use | Database monitoring | >80% | Warning |
| **Throughput** | Requests Per Second | Number of API requests processed per second | Application instrumentation | >500 sustained | Warning |
| **Throughput** | Database Transactions | Number of database transactions per second | Database monitoring | >1000 sustained | Warning |
| **Error Rate** | API Error Rate | Percentage of API requests resulting in errors | Application instrumentation | >1% | Warning |
| **Error Rate** | API Error Rate | Percentage of API requests resulting in errors | Application instrumentation | >5% | Critical |
| **Error Rate** | Resource Validation Errors | Number of FHIR resource validation errors | Application instrumentation | >100/min | Warning |
| **Resource Usage** | CPU Utilization | Percentage of CPU in use | Node monitoring | >80% sustained | Warning |
| **Resource Usage** | Memory Utilization | Percentage of memory in use | Node monitoring | >85% sustained | Warning |
| **Resource Usage** | Storage Utilization | Percentage of storage in use | Node monitoring | >80% | Warning |
| **Resource Usage** | Connection Pool Utilization | Percentage of connection pool in use | Application instrumentation | >85% | Warning |
| **Security** | Authentication Failures | Number of failed authentication attempts | Application logs | >10/min from same IP | Critical |
| **Security** | Authorization Failures | Number of authorization policy violations | Application logs | >10/min | Warning |
| **Compliance** | Audit Log Generation | Rate of audit event creation | Application instrumentation | <90% of expected | Critical |
| **Compliance** | PHI Access Rate | Rate of access to PHI resources | Application instrumentation | >500/min | Warning |

### Functional Metrics

#### API Usage Metrics

| Metric | Description | Dimensions |
|--------|-------------|------------|
| `fhir_requests_total` | Total number of FHIR API requests | resource_type, interaction_type, endpoint |
| `fhir_request_duration_seconds` | Histogram of FHIR API request durations | resource_type, interaction_type, endpoint |
| `fhir_request_size_bytes` | Size of FHIR API requests | resource_type, interaction_type |
| `fhir_response_size_bytes` | Size of FHIR API responses | resource_type, interaction_type |
| `fhir_concurrent_requests` | Number of concurrent FHIR requests being processed | endpoint |
| `fhir_requests_by_resource` | Count of requests by FHIR resource type | resource_type |
| `fhir_search_requests` | Count of search requests | resource_type, search_parameter |
| `fhir_subscription_notifications` | Count of subscription notifications sent | subscription_id, channel_type |

#### Database Metrics

| Metric | Description | Dimensions |
|--------|-------------|------------|
| `db_query_duration_seconds` | Histogram of database query durations | query_type, resource_type |
| `db_connection_pool_utilization` | Utilization of database connection pool | pool_name |
| `db_transactions_total` | Count of database transactions | transaction_type |
| `db_deadlocks_total` | Count of database deadlocks | - |
| `db_row_count` | Count of rows in key tables | table_name |
| `db_index_size_bytes` | Size of database indexes | index_name |
| `db_table_size_bytes` | Size of database tables | table_name |
| `db_vacuum_last_run` | Timestamp of last vacuum operation | table_name |
| `db_blocked_queries` | Count of queries blocked by locks | - |

#### Cache Metrics

| Metric | Description | Dimensions |
|--------|-------------|------------|
| `cache_hit_ratio` | Ratio of cache hits to total cache access | cache_name |
| `cache_size_bytes` | Size of cache in bytes | cache_name |
| `cache_items_count` | Count of items in cache | cache_name |
| `cache_evictions_total` | Count of cache evictions | cache_name, reason |
| `cache_get_duration_seconds` | Histogram of cache get operation durations | cache_name |
| `cache_set_duration_seconds` | Histogram of cache set operation durations | cache_name |

#### Security Metrics

| Metric | Description | Dimensions |
|--------|-------------|------------|
| `auth_attempts_total` | Count of authentication attempts | status, method |
| `auth_failures_total` | Count of authentication failures | reason, source_ip |
| `token_validations_total` | Count of token validations | token_type, status |
| `permission_checks_total` | Count of permission checks | resource_type, action, status |
| `break_glass_access_total` | Count of break-glass access events | user_role, resource_type |
| `sensitive_data_access_total` | Count of sensitive data access events | data_category, user_role |

### Alert Rules

#### Critical Alerts

```yaml
# Prometheus AlertManager rules for critical alerts
groups:
- name: fhir-platform-critical
  rules:
  - alert: FHIREndpointDown
    expr: up{job="fhir-api"} == 0
    for: 2m
    labels:
      severity: critical
      team: platform
    annotations:
      summary: "FHIR API endpoint is down"
      description: "The FHIR API endpoint has been down for more than 2 minutes"
      runbook: "https://wiki.covermymeds.com/runbooks/fhir-endpoint-down"
      
  - alert: HighErrorRate
    expr: sum(rate(fhir_requests_total{status_code=~"5.."}[5m])) by (endpoint) / sum(rate(fhir_requests_total[5m])) by (endpoint) > 0.05
    for: 5m
    labels:
      severity: critical
      team: platform
    annotations:
      summary: "High error rate on FHIR API"
      description: "Error rate exceeding 5% for {{ $labels.endpoint }}"
      runbook: "https://wiki.covermymeds.com/runbooks/high-error-rate"
      
  - alert: DatabaseConnectionSaturation
    expr: db_connection_pool_utilization > 0.95
    for: 5m
    labels:
      severity: critical
      team: database
    annotations:
      summary: "Database connection pool nearly exhausted"
      description: "Connection pool utilization at {{ $value | humanizePercentage }}"
      runbook: "https://wiki.covermymeds.com/runbooks/db-connection-saturation"
      
  - alert: AuditLogGenerationFailure
    expr: rate(audit_events_generation_failures_total[5m]) > 0
    for: 5m
    labels:
      severity: critical
      team: security
    annotations:
      summary: "Audit log generation is failing"
      description: "Audit events are failing to generate at a rate of {{ $value }} per second"
      runbook: "https://wiki.covermymeds.com/runbooks/audit-log-failure"
```

#### Warning Alerts

```yaml
# Prometheus AlertManager rules for warning alerts
groups:
- name: fhir-platform-warnings
  rules:
  - alert: SlowFHIRQueries
    expr: histogram_quantile(0.95, sum(rate(fhir_request_duration_seconds_bucket[5m])) by (le, resource_type)) > 1
    for: 10m
    labels:
      severity: warning
      team: platform
    annotations:
      summary: "Slow FHIR queries detected"
      description: "95th percentile of {{ $labels.resource_type }} queries taking more than 1 second"
      runbook: "https://wiki.covermymeds.com/runbooks/slow-fhir-queries"
      
  - alert: HighMemoryUsage
    expr: container_memory_usage_bytes / container_spec_memory_limit_bytes > 0.85
    for: 15m
    labels:
      severity: warning
      team: platform
    annotations:
      summary: "High memory usage"
      description: "Container {{ $labels.container }} is using {{ $value | humanizePercentage }} of its memory limit"
      runbook: "https://wiki.covermymeds.com/runbooks/high-memory-usage"
      
  - alert: StorageSpaceLow
    expr: disk_used_percent > 80
    for: 10m
    labels:
      severity: warning
      team: infrastructure
    annotations:
      summary: "Storage space running low"
      description: "Disk {{ $labels.device }} is {{ $value | humanizePercentage }} full"
      runbook: "https://wiki.covermymeds.com/runbooks/storage-space-low"
      
  - alert: HighAuthFailures
    expr: sum(rate(auth_failures_total[5m])) by (source_ip) > 0.2
    for: 5m
    labels:
      severity: warning
      team: security
    annotations:
      summary: "High authentication failure rate"
      description: "IP {{ $labels.source_ip }} has high auth failure rate"
      runbook: "https://wiki.covermymeds.com/runbooks/high-auth-failures"
```

## Logging

### Log Sources

The FHIR Interoperability Platform produces logs from multiple components:

1. **Application Logs**:
   - FHIR server application logs
   - API gateway logs
   - Authentication service logs
   - Background task logs
   - Integration service logs

2. **Infrastructure Logs**:
   - Kubernetes cluster logs
   - Container logs
   - Node logs
   - Load balancer logs
   - Network flow logs

3. **Database Logs**:
   - PostgreSQL server logs
   - Transaction logs
   - Slow query logs
   - Error logs
   - Connection logs

4. **Security Logs**:
   - Authentication events
   - Authorization decisions
   - Security control changes
   - Certificate management events
   - WAF events

### Log Format

All logs use a standardized JSON format with the following structure:

```json
{
  "timestamp": "2023-04-15T14:30:12.123Z",
  "level": "info",
  "service": "fhir-server",
  "instance": "fhir-server-pod-7d4f88b9c9-2xh4z",
  "traceId": "4fd37a4c0e138cba32c6eb0598da2bff",
  "spanId": "a7d5cf26d3034e6f",
  "userId": "practitioner-456",
  "clientId": "ehr-system",
  "requestId": "8a7d9c2f-123e-45c7-8b9a-0d1e2f3a4b5c",
  "resourceType": "Patient",
  "resourceId": "patient-123",
  "operation": "read",
  "message": "FHIR resource successfully retrieved",
  "details": {
    "path": "/fhir/r4/Patient/patient-123",
    "method": "GET",
    "responseTime": 42,
    "statusCode": 200,
    "userAgent": "Mozilla/5.0",
    "sourceIp": "10.0.0.1"
  }
}
```

### Log Storage

The logging strategy involves multiple storage tiers:

| Log Type | Retention Period | Storage Location | Archival Strategy |
|----------|------------------|------------------|-------------------|
| Application Logs | 30 days | Elasticsearch | Archived to S3 after 30 days |
| Security Logs | 1 year | Elasticsearch | Archived to S3 after 90 days |
| Audit Logs | 7 years | Elasticsearch + S3 | Immutable storage with retention policy |
| Infrastructure Logs | 30 days | Elasticsearch | Archived to S3 after 30 days |
| Database Logs | 30 days | Elasticsearch | Archived to S3 after 30 days |

### Log Collection Architecture

The log collection architecture uses a multi-tier approach:

1. **Collection Tier**:
   - Fluent Bit as node-level log collector
   - Kafka for log streaming and buffering
   - Vector for log enrichment and routing

2. **Processing Tier**:
   - Logstash for advanced log processing
   - Custom processors for PHI detection and masking
   - Anomaly detection for security events

3. **Storage & Analysis Tier**:
   - Elasticsearch for searchable log storage
   - S3 for long-term archival
   - OpenSearch Dashboards for visualization and analysis

4. **Integration Tier**:
   - SIEM integration for security monitoring
   - Compliance reporting tools
   - Incident management system

### Example Logging Configuration

```yaml
# Fluent Bit Configuration
[SERVICE]
    Flush        5
    Log_Level    info
    Parsers_File parsers.conf

[INPUT]
    Name              tail
    Tag               kube.*
    Path              /var/log/containers/fhir-*.log
    Parser            docker
    DB                /var/log/flb_kube.db
    Mem_Buf_Limit     5MB
    Skip_Long_Lines   On
    Refresh_Interval  10

[FILTER]
    Name                kubernetes
    Match               kube.*
    Kube_URL            https://kubernetes.default.svc:443
    Kube_CA_File        /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    Kube_Token_File     /var/run/secrets/kubernetes.io/serviceaccount/token
    Kube_Tag_Prefix     kube.var.log.containers.
    Merge_Log           On
    Merge_Log_Key       log_processed
    K8S-Logging.Parser  On
    K8S-Logging.Exclude Off

[FILTER]
    Name           grep
    Match          kube.*
    Regex          $kubernetes['labels']['app'] ^fhir-

[OUTPUT]
    Name            kafka
    Match           kube.*
    Brokers         kafka-broker-1:9092,kafka-broker-2:9092
    Topics          fhir-logs
    Timestamp_Key   @timestamp
    Retry_Limit     false
    rdkafka.debug   all
    rdkafka.log.connection.close false
    
# Vector Configuration
sources:
  kafka_logs:
    type: kafka
    bootstrap_servers: "kafka-broker-1:9092,kafka-broker-2:9092"
    group_id: "vector-log-consumer"
    topics: ["fhir-logs"]
    auto_offset_reset: "earliest"
    decoding:
      codec: json

transforms:
  parse_json:
    type: remap
    inputs: ["kafka_logs"]
    source: |
      . = parse_json!(.message)
      
  enrich_logs:
    type: remap
    inputs: ["parse_json"]
    source: |
      .environment = get_env_var("ENVIRONMENT")
      .region = get_env_var("REGION")
      .app_version = get_env_var("APP_VERSION")
      
  redact_phi:
    type: remap
    inputs: ["enrich_logs"]
    source: |
      if is_string(.details.responseBody) {
        .details.responseBody = redact(.details.responseBody, "(?i)\\b\\d{3}-\\d{2}-\\d{4}\\b", "[REDACTED SSN]")
        .details.responseBody = redact(.details.responseBody, "(?i)\\b\\d{9}\\b", "[REDACTED MRN]")
      }
      if is_string(.details.requestBody) {
        .details.requestBody = redact(.details.requestBody, "(?i)\\b\\d{3}-\\d{2}-\\d{4}\\b", "[REDACTED SSN]")
        .details.requestBody = redact(.details.requestBody, "(?i)\\b\\d{9}\\b", "[REDACTED MRN]")
      }

sinks:
  elasticsearch:
    type: elasticsearch
    inputs: ["redact_phi"]
    endpoint: "http://elasticsearch:9200"
    index: "fhir-logs-%Y-%m-%d"
    bulk:
      index: "fhir-logs"
      action: "index"
    compression: gzip
    pipeline: "fhir-log-pipeline"
    
  s3_archive:
    type: aws_s3
    inputs: ["redact_phi"]
    bucket: "fhir-platform-logs"
    key_prefix: "logs/%Y/%m/%d/"
    compression: gzip
    encoding:
      codec: json
    region: "us-east-1"
    batch:
      max_size: 10485760  # 10MB
      timeout_secs: 300   # 5 minutes
```

## Dashboards & Visualization

### Operational Dashboards

The FHIR Interoperability Platform includes the following operational dashboards:

1. **Platform Overview Dashboard**:
   - System health status
   - Key performance indicators
   - Resource utilization metrics
   - Error rates and counts
   - Request volume and throughput

2. **API Performance Dashboard**:
   - Request latency by endpoint
   - Request latency by resource type
   - Request throughput
   - Request size distribution
   - Response size distribution
   - Error rate by endpoint

3. **Resource Usage Dashboard**:
   - CPU utilization by pod/node
   - Memory utilization by pod/node
   - Network throughput
   - Disk I/O
   - Storage utilization
   - Connection pool utilization

4. **Database Performance Dashboard**:
   - Query performance by type
   - Transaction throughput
   - Connection utilization
   - Lock statistics
   - Cache hit ratio
   - Index and table sizes
   - Slow queries

5. **Error Tracking Dashboard**:
   - Error count by error type
   - Error count by endpoint
   - Error trends over time
   - Top error sources
   - Client errors vs. server errors
   - Validation errors by resource type

### Security Dashboards

1. **Authentication Dashboard**:
   - Authentication success/failure rates
   - Authentication by method
   - Failed authentication by source IP
   - Token issuance rate
   - Session creation/termination rate
   - MFA usage statistics

2. **Authorization Dashboard**:
   - Authorization decision counts
   - Permission check results
   - Access denied events by reason
   - Resource access by user role
   - Break-glass access events
   - Sensitive data access events

3. **Audit Trail Dashboard**:
   - Audit event generation rate
   - Audit events by type
   - Audit events by user
   - PHI access events
   - Resource modification events
   - Administrative action events

### Business Intelligence Dashboards

1. **API Usage Dashboard**:
   - Request volume by client application
   - Resource access by type
   - Most frequently accessed resources
   - Least frequently accessed resources
   - API usage trends over time
   - API usage by environment

2. **Integration Dashboard**:
   - Incoming integration requests
   - Outgoing integration requests
   - Integration errors
   - Integration latency
   - Integration availability
   - Data synchronization status

### Example Grafana Dashboard

```json
{
  "annotations": {
    "list": [
      {
        "builtIn": 1,
        "datasource": "-- Grafana --",
        "enable": true,
        "hide": true,
        "iconColor": "rgba(0, 211, 255, 1)",
        "name": "Annotations & Alerts",
        "type": "dashboard"
      },
      {
        "datasource": "Prometheus",
        "enable": true,
        "expr": "changes(fhir_server_version[1m]) > 0",
        "iconColor": "rgba(255, 96, 96, 1)",
        "name": "Deployments",
        "titleFormat": "Deployment"
      }
    ]
  },
  "editable": true,
  "gnetId": null,
  "graphTooltip": 0,
  "id": 1,
  "links": [],
  "panels": [
    {
      "collapsed": false,
      "gridPos": {
        "h": 1,
        "w": 24,
        "x": 0,
        "y": 0
      },
      "id": 10,
      "panels": [],
      "title": "Overview",
      "type": "row"
    },
    {
      "datasource": "Prometheus",
      "fieldConfig": {
        "defaults": {
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          },
          "unit": "short"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 4,
        "x": 0,
        "y": 1
      },
      "id": 2,
      "options": {
        "colorMode": "value",
        "graphMode": "area",
        "justifyMode": "auto",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "text": {},
        "textMode": "auto"
      },
      "pluginVersion": "7.5.7",
      "targets": [
        {
          "expr": "sum(rate(fhir_requests_total[5m]))",
          "interval": "",
          "legendFormat": "",
          "refId": "A"
        }
      ],
      "title": "Requests/sec",
      "type": "stat"
    },
    {
      "datasource": "Prometheus",
      "fieldConfig": {
        "defaults": {
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "yellow",
                "value": 500
              },
              {
                "color": "red",
                "value": 1000
              }
            ]
          },
          "unit": "ms"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 4,
        "x": 4,
        "y": 1
      },
      "id": 4,
      "options": {
        "colorMode": "value",
        "graphMode": "area",
        "justifyMode": "auto",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "text": {},
        "textMode": "auto"
      },
      "pluginVersion": "7.5.7",
      "targets": [
        {
          "expr": "histogram_quantile(0.95, sum(rate(fhir_request_duration_seconds_bucket[5m])) by (le)) * 1000",
          "interval": "",
          "legendFormat": "",
          "refId": "A"
        }
      ],
      "title": "p95 Latency",
      "type": "stat"
    },
    {
      "datasource": "Prometheus",
      "fieldConfig": {
        "defaults": {
          "mappings": [],
          "max": 100,
          "min": 0,
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "yellow",
                "value": 1
              },
              {
                "color": "red",
                "value": 5
              }
            ]
          },
          "unit": "percent"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 4,
        "x": 8,
        "y": 1
      },
      "id": 6,
      "options": {
        "colorMode": "value",
        "graphMode": "area",
        "justifyMode": "auto",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "text": {},
        "textMode": "auto"
      },
      "pluginVersion": "7.5.7",
      "targets": [
        {
          "expr": "sum(rate(fhir_requests_total{status_code=~\"5..\"}[5m])) / sum(rate(fhir_requests_total[5m])) * 100",
          "interval": "",
          "legendFormat": "",
          "refId": "A"
        }
      ],
      "title": "Error Rate",
      "type": "stat"
    },
    {
      "datasource": "Prometheus",
      "fieldConfig": {
        "defaults": {
          "mappings": [],
          "max": 100,
          "min": 0,
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "yellow",
                "value": 80
              },
              {
                "color": "red",
                "value": 90
              }
            ]
          },
          "unit": "percent"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 4,
        "x": 12,
        "y": 1
      },
      "id": 8,
      "options": {
        "colorMode": "value",
        "graphMode": "area",
        "justifyMode": "auto",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "text": {},
        "textMode": "auto"
      },
      "pluginVersion": "7.5.7",
      "targets": [
        {
          "expr": "avg(rate(container_cpu_usage_seconds_total{container=\"fhir-server\"}[5m]) / container_spec_cpu_quota{container=\"fhir-server\"} * 100)",
          "interval": "",
          "legendFormat": "",
          "refId": "A"
        }
      ],
      "title": "CPU Usage",
      "type": "stat"
    },
    {
      "datasource": "Prometheus",
      "fieldConfig": {
        "defaults": {
          "mappings": [],
          "max": 100,
          "min": 0,
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "yellow",
                "value": 80
              },
              {
                "color": "red",
                "value": 90
              }
            ]
          },
          "unit": "percent"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 4,
        "x": 16,
        "y": 1
      },
      "id": 12,
      "options": {
        "colorMode": "value",
        "graphMode": "area",
        "justifyMode": "auto",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "text": {},
        "textMode": "auto"
      },
      "pluginVersion": "7.5.7",
      "targets": [
        {
          "expr": "avg(container_memory_usage_bytes{container=\"fhir-server\"} / container_spec_memory_limit_bytes{container=\"fhir-server\"} * 100)",
          "interval": "",
          "legendFormat": "",
          "refId": "A"
        }
      ],
      "title": "Memory Usage",
      "type": "stat"
    },
    {
      "datasource": "Prometheus",
      "fieldConfig": {
        "defaults": {
          "mappings": [],
          "max": 100,
          "min": 0,
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "yellow",
                "value": 80
              },
              {
                "color": "red",
                "value": 90
              }
            ]
          },
          "unit": "percent"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 4,
        "x": 20,
        "y": 1
      },
      "id": 14,
      "options": {
        "colorMode": "value",
        "graphMode": "area",
        "justifyMode": "auto",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "text": {},
        "textMode": "auto"
      },
      "pluginVersion": "7.5.7",
      "targets": [
        {
          "expr": "db_connection_pool_utilization * 100",
          "interval": "",
          "legendFormat": "",
          "refId": "A"
        }
      ],
      "title": "DB Connection Pool",
      "type": "stat"
    },
    {
      "collapsed": false,
      "gridPos": {
        "h": 1,
        "w": 24,
        "x": 0,
        "y": 9
      },
      "id": 16,
      "panels": [],
      "title": "API Performance",
      "type": "row"
    },
    {
      "datasource": "Prometheus",
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "custom": {
            "axisLabel": "",
            "axisPlacement": "auto",
            "barAlignment": 0,
            "drawStyle": "line",
            "fillOpacity": 10,
            "gradientMode": "none",
            "hideFrom": {
              "legend": false,
              "tooltip": false,
              "viz": false
            },
            "lineInterpolation": "linear",
            "lineWidth": 1,
            "pointSize": 5,
            "scaleDistribution": {
              "type": "linear"
            },
            "showPoints": "never",
            "spanNulls": true,
            "stacking": {
              "group": "A",
              "mode": "none"
            },
            "thresholdsStyle": {
              "mode": "off"
            }
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          },
          "unit": "short"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 0,
        "y": 10
      },
      "id": 18,
      "options": {
        "legend": {
          "calcs": [],
          "displayMode": "list",
          "placement": "bottom"
        },
        "tooltip": {
          "mode": "single"
        }
      },
      "pluginVersion": "7.5.7",
      "targets": [
        {
          "expr": "sum(rate(fhir_requests_total[5m])) by (resource_type)",
          "interval": "",
          "legendFormat": "{{resource_type}}",
          "refId": "A"
        }
      ],
      "title": "Request Rate by Resource",
      "type": "timeseries"
    },
    {
      "datasource": "Prometheus",
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "custom": {
            "axisLabel": "",
            "axisPlacement": "auto",
            "barAlignment": 0,
            "drawStyle": "line",
            "fillOpacity": 10,
            "gradientMode": "none",
            "hideFrom": {
              "legend": false,
              "tooltip": false,
              "viz": false
            },
            "lineInterpolation": "linear",
            "lineWidth": 1,
            "pointSize": 5,
            "scaleDistribution": {
              "type": "linear"
            },
            "showPoints": "never",
            "spanNulls": true,
            "stacking": {
              "group": "A",
              "mode": "none"
            },
            "thresholdsStyle": {
              "mode": "off"
            }
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          },
          "unit": "ms"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 12,
        "y": 10
      },
      "id": 20,
      "options": {
        "legend": {
          "calcs": [],
          "displayMode": "list",
          "placement": "bottom"
        },
        "tooltip": {
          "mode": "single"
        }
      },
      "pluginVersion": "7.5.7",
      "targets": [
        {
          "expr": "histogram_quantile(0.95, sum(rate(fhir_request_duration_seconds_bucket[5m])) by (le, resource_type)) * 1000",
          "interval": "",
          "legendFormat": "{{resource_type}}",
          "refId": "A"
        }
      ],
      "title": "p95 Latency by Resource",
      "type": "timeseries"
    }
  ],
  "refresh": "10s",
  "schemaVersion": 27,
  "style": "dark",
  "tags": [
    "fhir",
    "platform"
  ],
  "templating": {
    "list": []
  },
  "time": {
    "from": "now-1h",
    "to": "now"
  },
  "timepicker": {},
  "timezone": "",
  "title": "FHIR Platform Overview",
  "uid": "fhir-overview",
  "version": 1
}
```

## Example Alert Policy

```yaml
# AlertManager Configuration
global:
  resolve_timeout: 5m
  slack_api_url: 'https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX'
  pagerduty_url: 'https://events.pagerduty.com/v2/enqueue'

route:
  group_by: ['alertname', 'job', 'severity']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  receiver: 'slack-notifications'
  routes:
    - receiver: 'pagerduty-critical'
      match:
        severity: critical
      continue: true
    - receiver: 'slack-notifications'
      match_re:
        severity: ^(warning|critical)$

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname']

receivers:
  - name: 'slack-notifications'
    slack_configs:
      - channel: '#fhir-platform-alerts'
        send_resolved: true
        title: '[{{ .Status | toUpper }}] {{ .CommonLabels.alertname }}'
        title_link: 'https://grafana.covermymeds.com/d/fhir-overview'
        text: >-
          {{ range .Alerts }}
          *Alert:* {{ .Annotations.summary }}
          *Description:* {{ .Annotations.description }}
          *Severity:* {{ .Labels.severity }}
          *Duration:* {{ .ActiveAt | since }}
          {{ if .Annotations.runbook }}*Runbook:* {{ .Annotations.runbook }}{{ end }}
          {{ end }}

  - name: 'pagerduty-critical'
    pagerduty_configs:
      - routing_key: 'your-pagerduty-routing-key'
        send_resolved: true
        description: '[{{ .Status | toUpper }}] {{ .CommonLabels.alertname }}'
        details:
          severity: '{{ .CommonLabels.severity }}'
          summary: '{{ .CommonAnnotations.summary }}'
          description: '{{ .CommonAnnotations.description }}'
          runbook: '{{ .CommonAnnotations.runbook }}'
```

## Related Resources
- [FHIR Interoperability Platform Deployment](./deployment.md)
- [FHIR Interoperability Platform Maintenance](./maintenance.md)
- [FHIR Interoperability Platform Troubleshooting](./troubleshooting.md)
- [FHIR Interoperability Platform Audit Compliance](../04-governance-compliance/audit-compliance.md)
- [Aidbox Monitoring Documentation](https://docs.aidbox.app/getting-started/monitoring)