# Federated Graph API Monitoring

## Introduction
This document outlines the comprehensive monitoring strategy for the Federated Graph API. It details the metrics, logging, alerting, and visualization approaches that ensure the availability, performance, and security of the Federated Graph API. This monitoring framework enables operations teams to proactively identify issues, troubleshoot problems efficiently, and maintain a high-quality service.

## Metrics & Alerts

### Core Metrics

#### Gateway Level Metrics

| Metric | Description | Threshold | Severity |
|--------|-------------|-----------|----------|
| `apollo_router_http_requests_total` | Total HTTP requests to the router | - | - |
| `apollo_router_http_request_duration_seconds` | HTTP request duration histogram | p95 > 1.5s | Warning |
| `apollo_router_http_request_duration_seconds` | HTTP request duration histogram | p95 > 3s | Critical |
| `apollo_router_operations_total` | Total operations (queries/mutations) | - | - |
| `apollo_router_operation_errors_total` | Total operation errors | Error rate > 1% | Warning |
| `apollo_router_operation_errors_total` | Total operation errors | Error rate > 5% | Critical |
| `apollo_router_query_planning_duration_seconds` | Query planning time histogram | p95 > 100ms | Warning |
| `apollo_router_cache_hit_count` | Cache hit count | Hit rate < 60% | Warning |
| `apollo_router_active_requests` | Currently active requests | > 80% capacity | Warning |
| `apollo_router_active_requests` | Currently active requests | > 95% capacity | Critical |

#### Subgraph Level Metrics

| Metric | Description | Threshold | Severity |
|--------|-------------|-----------|----------|
| `apollo_subgraph_fetches_total` | Total subgraph fetches | - | - |
| `apollo_subgraph_fetch_duration_seconds` | Subgraph fetch duration histogram | p95 > 1s | Warning |
| `apollo_subgraph_fetch_duration_seconds` | Subgraph fetch duration histogram | p95 > 2s | Critical |
| `apollo_subgraph_fetch_errors_total` | Total subgraph fetch errors | Error rate > 1% | Warning |
| `apollo_subgraph_fetch_errors_total` | Total subgraph fetch errors | Error rate > 5% | Critical |
| `apollo_subgraph_fetch_size_bytes` | Subgraph response size histogram | p95 > 1MB | Warning |

#### Operation-Specific Metrics

| Metric | Description | Threshold | Severity |
|--------|-------------|-----------|----------|
| `apollo_operation_complexity` | GraphQL operation complexity score | > 1000 | Warning |
| `apollo_operation_depth` | GraphQL operation depth | > 10 | Warning |
| `apollo_operation_execution_time` | Operation execution time | p95 > 2s | Warning |
| `apollo_operation_error_rate` | Error rate by operation | > 1% | Warning |

#### System Resource Metrics

| Metric | Description | Threshold | Severity |
|--------|-------------|-----------|----------|
| `process_cpu_seconds_total` | CPU usage | > 80% for 5m | Warning |
| `process_cpu_seconds_total` | CPU usage | > 90% for 5m | Critical |
| `process_resident_memory_bytes` | Memory usage | > 80% of limit | Warning |
| `process_resident_memory_bytes` | Memory usage | > 90% of limit | Critical |
| `process_open_fds` | Open file descriptors | > 80% of limit | Warning |
| `kube_pod_container_status_ready` | Container readiness | Not ready for 1m | Warning |
| `kube_pod_container_status_ready` | Container readiness | Not ready for 5m | Critical |

### Alert Rules

Example Prometheus alert rules:

```yaml
groups:
- name: federated-graph-api
  rules:
  - alert: HighErrorRate
    expr: sum(rate(apollo_router_operation_errors_total[5m])) by (service) / sum(rate(apollo_router_operations_total[5m])) by (service) > 0.05
    for: 5m
    labels:
      severity: critical
      service: federated-graph-api
    annotations:
      summary: "High error rate on Federated Graph API"
      description: "Error rate exceeds 5% for service {{ $labels.service }} over the last 5 minutes"
      
  - alert: HighLatency
    expr: histogram_quantile(0.95, sum(rate(apollo_router_http_request_duration_seconds_bucket[5m])) by (service, le)) > 3
    for: 5m
    labels:
      severity: critical
      service: federated-graph-api
    annotations:
      summary: "High latency on Federated Graph API"
      description: "P95 latency exceeds 3 seconds for service {{ $labels.service }}"
      
  - alert: SubgraphDown
    expr: sum(apollo_subgraph_fetches_total) by (subgraph) == 0
    for: 5m
    labels:
      severity: critical
      service: federated-graph-api
    annotations:
      summary: "Subgraph is down"
      description: "Subgraph {{ $labels.subgraph }} appears to be down - no fetches recorded in the last 5 minutes"
      
  - alert: HighMemoryUsage
    expr: process_resident_memory_bytes / 1024 / 1024 > 3500
    for: 10m
    labels:
      severity: warning
      service: federated-graph-api
    annotations:
      summary: "High memory usage on Federated Graph API"
      description: "Memory usage exceeds 3.5GB for service {{ $labels.service }}"
```

### Business-Level Metrics

In addition to technical metrics, the Federated Graph API also tracks business-level metrics:

| Metric | Description | Threshold | Severity |
|--------|-------------|-----------|----------|
| `healthcare_patient_queries_total` | Patient data queries | Sudden drop > 30% | Warning |
| `healthcare_prescriptions_total` | Prescription operations | Sudden drop > 20% | Warning |
| `healthcare_prior_auth_success_rate` | Prior authorization success rate | < 90% | Warning |
| `healthcare_prior_auth_timeout_rate` | Prior authorization timeout rate | > 5% | Critical |
| `healthcare_critical_workflow_completion` | End-to-end completion of critical workflows | < 95% | Warning |

## Logging

### Log Sources

| Component | Log Format | Storage Location | Retention |
|-----------|------------|------------------|-----------|
| Apollo Router | JSON | CloudWatch Logs | 90 days |
| Subgraphs | JSON | CloudWatch Logs | 90 days |
| Schema Registry | JSON | CloudWatch Logs | 90 days |
| Kubernetes Events | JSON | CloudWatch Logs | 30 days |
| Load Balancer | Text | S3 | 1 year |
| WAF | JSON | S3 | 1 year |

### Log Levels

| Level | Usage | Example |
|-------|-------|---------|
| ERROR | System failures, data loss | Subgraph unreachable, schema composition failure |
| WARN | Operational issues, degraded service | Slow queries, cache misses, deprecated field usage |
| INFO | Normal operations, significant events | Requests, responses, schema updates |
| DEBUG | Detailed troubleshooting | Query plans, resolver execution, variable values (sanitized) |
| TRACE | Fine-grained diagnostics | Full execution context (only in development) |

### Log Structure

The Federated Graph API uses structured logging in JSON format:

```json
{
  "timestamp": "2023-04-12T15:38:22.123Z",
  "level": "INFO",
  "service": "apollo-router",
  "instance": "router-5d4f89c456-2xvbn",
  "message": "Processed GraphQL operation",
  "operation_name": "GetPatientData",
  "operation_type": "query",
  "client_name": "web-portal",
  "client_version": "2.5.1",
  "user_id": "user123",
  "organization_id": "org456",
  "trace_id": "ab12cd34ef56gh78",
  "duration_ms": 142,
  "status": "success",
  "subgraph_count": 3,
  "cache_hit_count": 2,
  "error_count": 0,
  "query_complexity": 15,
  "query_depth": 5
}
```

### Log Forwarding and Aggregation

1. **Collection**: Logs collected via Fluent Bit DaemonSet
2. **Processing**: Structured parsing, enrichment with Kubernetes metadata
3. **Storage**: Forwarded to CloudWatch Logs and OpenSearch
4. **Retention**: Tiered retention based on log importance

### Audit Logging

Special audit logging is implemented for security and compliance:

1. **Authentication events**: Success/failure, token details
2. **Authorization decisions**: Permissions evaluated, allowed/denied
3. **PHI access**: Fields containing PHI, access context
4. **Schema changes**: Who changed what, when, approval details
5. **Configuration changes**: Changes to router or subgraph configurations

## Dashboards & Visualization

### Operational Dashboards

#### Main Operations Dashboard

![Federated Graph API Operations Dashboard](https://via.placeholder.com/800x400?text=Federated+Graph+API+Operations+Dashboard)

Key panels:
- Request rate and error rate
- Latency percentiles (p50, p95, p99)
- Active requests and connections
- Error breakdown by type and subgraph
- Resource utilization (CPU, memory)
- Cache hit rate
- Health status by subgraph

#### Subgraph Performance Dashboard

![Subgraph Performance Dashboard](https://via.placeholder.com/800x400?text=Subgraph+Performance+Dashboard)

Key panels:
- Fetch count by subgraph
- Fetch duration by subgraph
- Error rate by subgraph
- Entity resolution performance
- Field usage heatmap
- Resolver timing breakdown
- Success rate by operation type

#### Client Usage Dashboard

![Client Usage Dashboard](https://via.placeholder.com/800x400?text=Client+Usage+Dashboard)

Key panels:
- Operations by client
- Error rate by client
- Cache utilization by client
- Operation complexity distribution
- Client version distribution
- Top operations by frequency
- Top operations by duration

### Technical Dashboards

1. **Schema Registry Dashboard**
   - Schema composition success/failure
   - Schema change frequency
   - Schema validation errors
   - Composition time

2. **Network Dashboard**
   - Connection rate
   - Connection duration
   - TLS handshake timing
   - Network errors
   - Bandwidth utilization

3. **Resource Utilization Dashboard**
   - CPU/Memory by pod
   - Pod restarts
   - Node status
   - Scaling events
   - Resource quotas

### Business Dashboards

1. **Healthcare Operations Dashboard**
   - Patient query volume
   - Medication operations
   - Prior authorization workflow performance
   - Critical path monitoring
   - Business SLA compliance

2. **Developer Experience Dashboard**
   - Schema stability metrics
   - Deprecation usage
   - Client adoption of new features
   - Error rates during development
   - Documentation usage

## Health Checking

### Health Check Endpoints

| Endpoint | Type | Purpose |
|----------|------|---------|
| `/.well-known/apollo/server-health` | HTTP 200/500 | Basic server liveness |
| `/health/live` | HTTP JSON | Liveness with component status |
| `/health/ready` | HTTP JSON | Readiness for serving traffic |
| `/health/startup` | HTTP JSON | Initialization status |

Example response from `/health/ready`:

```json
{
  "status": "ready",
  "timestamp": "2023-04-12T15:45:33Z",
  "components": {
    "router": {
      "status": "healthy"
    },
    "subgraphs": {
      "patient": "healthy",
      "medication": "healthy",
      "appointment": "healthy",
      "auth": "healthy",
      "fhir": "degraded"
    },
    "cache": {
      "status": "healthy"
    },
    "schema": {
      "status": "healthy",
      "lastUpdated": "2023-04-12T10:15:22Z"
    }
  },
  "details": {
    "fhir": {
      "status": "degraded",
      "message": "High latency detected",
      "metrics": {
        "p95_latency_ms": 850,
        "error_rate": 0.02
      }
    }
  }
}
```

### Synthetic Monitoring

Scheduled probes that execute predefined GraphQL operations:

1. **Basic Health Query**: Simple introspection query every 30 seconds
2. **Core Operations**: Essential business operations every 5 minutes
3. **End-to-End Workflows**: Complete business workflows every hour
4. **Performance Benchmarks**: Standard performance tests daily

Example synthetic monitoring configuration:

```yaml
schedules:
  - name: basic-health
    interval: 30s
    timeout: 5s
    operation: |
      query HealthCheck {
        __typename
      }
    assertion:
      - type: status
        expect: 200
      - type: responseTime
        expect: < 500ms

  - name: patient-lookup
    interval: 5m
    timeout: 10s
    operation: |
      query PatientLookup($mrn: String!) {
        patientByMRN(mrn: $mrn) {
          id
          name {
            given
            family
          }
          birthDate
        }
      }
    variables:
      mrn: "TEST12345"
    assertion:
      - type: status
        expect: 200
      - type: responseTime
        expect: < 1000ms
      - type: data
        path: "patientByMRN.id"
        expect: exists
```

## Tracing and Profiling

### Distributed Tracing

The Federated Graph API implements OpenTelemetry for distributed tracing:

1. **Trace Context**: Propagation across subgraphs and services
2. **Span Collection**: Detailed spans for each resolver and operation
3. **Sampling Strategy**: Variable sampling based on operation complexity and errors
4. **Storage**: Jaeger for storage and visualization

Example trace for a complex query:

```
[Router] Process request
  ├─ [Router] Parse query
  ├─ [Router] Plan query execution
  ├─ [Router] Execute query plan
  │   ├─ [Patient Subgraph] Fetch patient
  │   │   └─ [Patient Service] Get patient by ID
  │   │
  │   ├─ [Medication Subgraph] Fetch medications
  │   │   ├─ [Medication Service] Get medications by patient
  │   │   └─ [Formulary Service] Get medication coverage
  │   │
  │   └─ [Appointment Subgraph] Fetch appointments
  │       └─ [Scheduling Service] Get appointments by patient
  │
  └─ [Router] Assemble response
```

### Performance Profiling

Regular performance profiling to identify optimization opportunities:

1. **CPU Profiling**: Identify hotspots in router and subgraph code
2. **Memory Profiling**: Track memory allocation patterns
3. **Query Analysis**: Identify expensive queries and operations
4. **Resolver Timing**: Measure resolver performance across subgraphs

## Example Alert Policy

Example PagerDuty integration for critical alerts:

```yaml
# PagerDuty Alert Policy
apiVersion: monitoring.pagerduty.com/v1
kind: AlertPolicy
metadata:
  name: federated-graph-api-critical
spec:
  service: "P123ABC"  # PagerDuty service ID
  escalationPolicy: "EP123ABC"  # PagerDuty escalation policy ID
  severityMapping:
    critical: P1
    warning: P3
  alerts:
    - name: "High Error Rate"
      source: "prometheus"
      query: 'sum(rate(apollo_router_operation_errors_total[5m])) by (service) / sum(rate(apollo_router_operations_total[5m])) by (service) > 0.05'
      forDuration: "5m"
      severity: "critical"
      description: "Error rate exceeds 5% for service {{ $labels.service }}"
      runbook: "https://docs.covermymeds.com/runbooks/federated-graph-high-error-rate"
      
    - name: "Subgraph Unavailable"
      source: "prometheus"
      query: 'sum(apollo_subgraph_fetches_total) by (subgraph) == 0'
      forDuration: "5m"
      severity: "critical"
      description: "Subgraph {{ $labels.subgraph }} appears to be down"
      runbook: "https://docs.covermymeds.com/runbooks/federated-graph-subgraph-down"
      
    - name: "High Latency"
      source: "prometheus"
      query: 'histogram_quantile(0.95, sum(rate(apollo_router_http_request_duration_seconds_bucket[5m])) by (service, le)) > 3'
      forDuration: "5m"
      severity: "critical"
      description: "P95 latency exceeds 3 seconds for service {{ $labels.service }}"
      runbook: "https://docs.covermymeds.com/runbooks/federated-graph-high-latency"
```

## Related Resources
- [Federated Graph API Troubleshooting](./troubleshooting.md)
- [Federated Graph API Scaling](./scaling.md)
- [Federated Graph API Deployment](./deployment.md)
- [Apollo Router Metrics Documentation](https://www.apollographql.com/docs/router/observability/metrics)