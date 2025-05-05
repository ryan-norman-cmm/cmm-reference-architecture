# FHIR Server Monitoring and Alerting

## Introduction

Effective monitoring and alerting are essential for maintaining a reliable FHIR server implementation. This guide explains how to implement comprehensive monitoring for your FHIR server, covering server health metrics, resource utilization, application performance, and alerting strategies. By implementing these monitoring practices, you can ensure high availability, detect issues early, and maintain optimal performance for your healthcare data exchange platform.

### Quick Start

1. Implement basic health checks for your FHIR server
2. Configure resource utilization monitoring (CPU, memory, disk, network)
3. Set up application-level metrics for FHIR operations
4. Establish alerting thresholds and notification channels
5. Create dashboards for operational visibility

### Related Components

- [FHIR Server Setup Guide](fhir-server-setup-guide.md): Configure your FHIR environment
- [FHIR Performance Tuning](fhir-performance-tuning.md) (Coming Soon): Optimize server performance
- [FHIR Version Management](fhir-version-management.md) (Coming Soon): Manage FHIR version upgrades
- [FHIR Backup and Recovery](fhir-backup-recovery.md) (Coming Soon): Implement data protection strategies

## Server Health Monitoring

Server health monitoring ensures that your FHIR server is operational and responding to requests as expected.

### Health Check Endpoints

Implement dedicated health check endpoints to verify server status.

```typescript
import express from 'express';
import { AidboxClient } from '@aidbox/sdk-r4';

const app = express();
const client = new AidboxClient({
  baseUrl: process.env.AIDBOX_URL || 'http://localhost:8888',
  auth: {
    type: 'basic',
    username: process.env.AIDBOX_CLIENT_ID || 'root',
    password: process.env.AIDBOX_CLIENT_SECRET || 'secret'
  }
});

/**
 * Basic health check endpoint
 * Returns 200 OK if the server is running
 */
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'UP' });
});

/**
 * Deep health check endpoint
 * Verifies connectivity to the FHIR server
 */
app.get('/health/deep', async (req, res) => {
  try {
    // Attempt to connect to the FHIR server
    const response = await client.request({
      method: 'GET',
      url: '/health'
    });
    
    // Check if the response indicates the server is healthy
    if (response.status === 200) {
      res.status(200).json({
        status: 'UP',
        components: {
          fhirServer: 'UP'
        }
      });
    } else {
      res.status(503).json({
        status: 'DOWN',
        components: {
          fhirServer: 'DOWN'
        },
        error: 'FHIR server returned non-200 status'
      });
    }
  } catch (error) {
    console.error('Health check failed:', error);
    res.status(503).json({
      status: 'DOWN',
      components: {
        fhirServer: 'DOWN'
      },
      error: error.message
    });
  }
});

/**
 * Readiness check endpoint
 * Verifies that the server is ready to accept requests
 */
app.get('/health/ready', async (req, res) => {
  try {
    // Perform a simple FHIR operation to verify readiness
    await client.search({
      resourceType: 'CapabilityStatement',
      params: {
        '_summary': 'true'
      }
    });
    
    res.status(200).json({ status: 'READY' });
  } catch (error) {
    console.error('Readiness check failed:', error);
    res.status(503).json({
      status: 'NOT_READY',
      error: error.message
    });
  }
});

const port = process.env.PORT || 3000;
app.listen(port, () => {
  console.log(`Health check server listening on port ${port}`);
});
```

### External Health Monitoring

Implement external monitoring to check your FHIR server from outside your network.

| Monitoring Approach | Description | Implementation |
|---------------------|-------------|----------------|
| Synthetic transactions | Periodic execution of common FHIR operations | Scheduled scripts that perform CRUD operations |
| Uptime monitoring | Regular checks of server availability | Services like Pingdom, New Relic, or Datadog |
| Global monitoring | Checks from multiple geographic locations | Distributed monitoring agents |

### Implementing Synthetic Transactions

```typescript
import { AidboxClient } from '@aidbox/sdk-r4';
import { Patient } from '@aidbox/sdk-r4/types';
import * as cron from 'node-cron';

const client = new AidboxClient({
  baseUrl: process.env.AIDBOX_URL || 'http://localhost:8888',
  auth: {
    type: 'basic',
    username: process.env.AIDBOX_CLIENT_ID || 'root',
    password: process.env.AIDBOX_CLIENT_SECRET || 'secret'
  }
});

/**
 * Performs a synthetic transaction to verify FHIR server functionality
 * @returns Results of the synthetic transaction
 */
async function performSyntheticTransaction(): Promise<{
  success: boolean;
  operations: Record<string, { success: boolean; duration: number }>;
  error?: string;
}> {
  const results: Record<string, { success: boolean; duration: number }> = {};
  let patientId: string | undefined;
  
  try {
    // Create a test patient
    const startCreate = Date.now();
    const testPatient: Partial<Patient> = {
      resourceType: 'Patient',
      meta: {
        tag: [
          {
            system: 'http://example.org/fhir/tags',
            code: 'synthetic-transaction',
            display: 'Synthetic Transaction'
          }
        ]
      },
      name: [
        {
          family: 'TestPatient',
          given: ['Synthetic']
        }
      ],
      gender: 'unknown',
      birthDate: '2000-01-01'
    };
    
    const createdPatient = await client.create<Patient>(testPatient);
    patientId = createdPatient.id;
    results.create = {
      success: true,
      duration: Date.now() - startCreate
    };
    
    // Read the patient
    const startRead = Date.now();
    await client.read<Patient>({
      resourceType: 'Patient',
      id: patientId as string
    });
    results.read = {
      success: true,
      duration: Date.now() - startRead
    };
    
    // Search for patients
    const startSearch = Date.now();
    await client.search<Patient>({
      resourceType: 'Patient',
      params: {
        'family': 'TestPatient',
        '_tag': 'http://example.org/fhir/tags|synthetic-transaction'
      }
    });
    results.search = {
      success: true,
      duration: Date.now() - startSearch
    };
    
    // Update the patient
    const startUpdate = Date.now();
    createdPatient.telecom = [
      {
        system: 'phone',
        value: '555-555-5555',
        use: 'work'
      }
    ];
    await client.update<Patient>(createdPatient);
    results.update = {
      success: true,
      duration: Date.now() - startUpdate
    };
    
    // Delete the patient
    const startDelete = Date.now();
    await client.delete({
      resourceType: 'Patient',
      id: patientId as string
    });
    results.delete = {
      success: true,
      duration: Date.now() - startDelete
    };
    
    return {
      success: true,
      operations: results
    };
  } catch (error) {
    console.error('Synthetic transaction failed:', error);
    
    // Clean up if needed
    if (patientId) {
      try {
        await client.delete({
          resourceType: 'Patient',
          id: patientId
        });
      } catch (cleanupError) {
        console.error('Failed to clean up test patient:', cleanupError);
      }
    }
    
    return {
      success: false,
      operations: results,
      error: error.message
    };
  }
}

// Schedule synthetic transactions to run every 5 minutes
cron.schedule('*/5 * * * *', async () => {
  console.log('Running synthetic transaction...');
  const result = await performSyntheticTransaction();
  
  if (result.success) {
    console.log('Synthetic transaction succeeded:', result.operations);
  } else {
    console.error('Synthetic transaction failed:', result.error);
    // Here you would trigger alerts or notifications
  }
});
```

## Resource Utilization Monitoring

Resource utilization monitoring tracks the consumption of system resources by your FHIR server.

### Key Metrics to Monitor

| Resource | Metrics | Warning Signs |
|----------|---------|---------------|
| CPU | Utilization percentage, load average | Sustained high utilization (>80%) |
| Memory | Used memory, available memory, swap usage | High memory usage, frequent swapping |
| Disk | Used space, I/O operations, latency | Low free space (<20%), high I/O wait times |
| Network | Bandwidth usage, connection count, error rate | Bandwidth saturation, connection timeouts |

### Prometheus Configuration

Prometheus is a popular monitoring system that can collect metrics from your FHIR server.

```yaml
# prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'fhir_server'
    static_configs:
      - targets: ['fhir-server:8888']
    metrics_path: '/metrics'

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']
```

### Grafana Dashboard Configuration

Grafana provides visualization for your monitoring metrics.

```json
{
  "dashboard": {
    "id": null,
    "title": "FHIR Server Dashboard",
    "tags": ["fhir", "healthcare"],
    "timezone": "browser",
    "panels": [
      {
        "title": "CPU Usage",
        "type": "graph",
        "datasource": "Prometheus",
        "targets": [
          {
            "expr": "100 - (avg by (instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[1m])) * 100)",
            "legendFormat": "CPU Usage"
          }
        ]
      },
      {
        "title": "Memory Usage",
        "type": "graph",
        "datasource": "Prometheus",
        "targets": [
          {
            "expr": "node_memory_MemTotal_bytes - node_memory_MemFree_bytes - node_memory_Buffers_bytes - node_memory_Cached_bytes",
            "legendFormat": "Memory Used"
          }
        ]
      },
      {
        "title": "Disk Usage",
        "type": "graph",
        "datasource": "Prometheus",
        "targets": [
          {
            "expr": "node_filesystem_size_bytes{mountpoint=\"/\"} - node_filesystem_free_bytes{mountpoint=\"/\"}",
            "legendFormat": "Disk Used"
          }
        ]
      },
      {
        "title": "Network Traffic",
        "type": "graph",
        "datasource": "Prometheus",
        "targets": [
          {
            "expr": "irate(node_network_receive_bytes_total[1m])",
            "legendFormat": "Received"
          },
          {
            "expr": "irate(node_network_transmit_bytes_total[1m])",
            "legendFormat": "Transmitted"
          }
        ]
      }
    ]
  }
}
```

## Application-Level Metrics

Application-level metrics provide insights into the performance and behavior of your FHIR server application.

### FHIR Operation Metrics

Track metrics for each type of FHIR operation to understand usage patterns and performance.

| Metric | Description | Implementation |
|--------|-------------|----------------|
| Request rate | Number of requests per second | Count of incoming HTTP requests |
| Response time | Time to process requests | Duration from request receipt to response |
| Error rate | Percentage of failed requests | Count of 4xx and 5xx responses |
| Resource access patterns | Most frequently accessed resources | Count of requests by resource type |

### Implementing Application Metrics

```typescript
import express from 'express';
import promClient from 'prom-client';
import { AidboxClient } from '@aidbox/sdk-r4';

// Initialize Prometheus metrics
const register = new promClient.Registry();
promClient.collectDefaultMetrics({ register });

// Create custom metrics
const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.1, 0.3, 0.5, 0.7, 1, 3, 5, 7, 10]
});

const fhirOperationCounter = new promClient.Counter({
  name: 'fhir_operations_total',
  help: 'Count of FHIR operations',
  labelNames: ['operation', 'resource_type', 'status']
});

const fhirResourceCounter = new promClient.Counter({
  name: 'fhir_resources_total',
  help: 'Count of FHIR resources',
  labelNames: ['resource_type', 'operation']
});

register.registerMetric(httpRequestDuration);
register.registerMetric(fhirOperationCounter);
register.registerMetric(fhirResourceCounter);

const app = express();

// Middleware to track HTTP request duration
app.use((req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    httpRequestDuration.observe(
      { method: req.method, route: req.path, status_code: res.statusCode },
      duration
    );
  });
  
  next();
});

// FHIR API routes
app.post('/fhir/:resourceType', (req, res) => {
  const { resourceType } = req.params;
  
  // Track FHIR create operation
  fhirOperationCounter.inc({
    operation: 'create',
    resource_type: resourceType,
    status: 'success'
  });
  
  fhirResourceCounter.inc({
    resource_type: resourceType,
    operation: 'create'
  });
  
  // Actual FHIR operation handling would go here
  // ...
  
  res.status(201).json({ /* response */ });
});

// Expose metrics endpoint for Prometheus
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

const port = process.env.PORT || 3000;
app.listen(port, () => {
  console.log(`Metrics server listening on port ${port}`);
});
```

## Alerting Strategies

Effective alerting ensures that the right people are notified when issues occur with your FHIR server.

### Alert Thresholds

Establish appropriate thresholds for triggering alerts based on your system's normal behavior.

| Metric | Warning Threshold | Critical Threshold | Rationale |
|--------|-------------------|--------------------|-----------|
| CPU utilization | 70% | 90% | High CPU can lead to degraded performance |
| Memory utilization | 80% | 95% | Memory exhaustion can cause application crashes |
| Disk space | 80% full | 90% full | Running out of disk space can halt operations |
| Error rate | 5% | 10% | Elevated error rates indicate system issues |
| Response time | 2x baseline | 5x baseline | Slow responses affect user experience |

### Alert Notification Channels

Implement multiple notification channels to ensure alerts reach the appropriate personnel.

| Channel | Use Case | Implementation |
|---------|----------|----------------|
| Email | Non-urgent notifications | SMTP integration with monitoring system |
| SMS | Urgent notifications | SMS gateway integration |
| Chat applications | Team notifications | Slack, Microsoft Teams, or Discord webhooks |
| Incident management | Escalation and tracking | PagerDuty, OpsGenie, or VictorOps integration |

### Implementing Alerting with Prometheus Alertmanager

```yaml
# alertmanager.yml
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname', 'instance']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  receiver: 'team-email'
  routes:
  - match:
      severity: critical
    receiver: 'team-pager'

receivers:
- name: 'team-email'
  email_configs:
  - to: 'team@example.com'
    from: 'alertmanager@example.com'
    smarthost: 'smtp.example.com:587'
    auth_username: 'alertmanager'
    auth_password: 'password'

- name: 'team-pager'
  pagerduty_configs:
  - service_key: '<pagerduty-service-key>'
```

### Alert Rules Configuration

```yaml
# alert_rules.yml
groups:
- name: fhir_server_alerts
  rules:
  - alert: HighCpuUsage
    expr: 100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[1m])) * 100) > 90
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High CPU usage on {{ $labels.instance }}"
      description: "CPU usage is above 90% for 5 minutes."

  - alert: HighMemoryUsage
    expr: (node_memory_MemTotal_bytes - node_memory_MemFree_bytes - node_memory_Buffers_bytes - node_memory_Cached_bytes) / node_memory_MemTotal_bytes * 100 > 95
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "High memory usage on {{ $labels.instance }}"
      description: "Memory usage is above 95% for 5 minutes."

  - alert: DiskSpaceLow
    expr: (node_filesystem_size_bytes{mountpoint="/"} - node_filesystem_free_bytes{mountpoint="/"}) / node_filesystem_size_bytes{mountpoint="/"} * 100 > 90
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "Low disk space on {{ $labels.instance }}"
      description: "Disk usage is above 90% for 5 minutes."

  - alert: HighErrorRate
    expr: sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m])) * 100 > 10
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "High error rate"
      description: "Error rate is above 10% for 5 minutes."
```

## Operational Dashboards

Operational dashboards provide visibility into the health and performance of your FHIR server.

### Dashboard Components

Create comprehensive dashboards that include all relevant metrics for monitoring your FHIR server.

| Dashboard Section | Metrics to Include | Purpose |
|-------------------|-------------------|----------|
| System overview | CPU, memory, disk, network | High-level system health |
| FHIR operations | Request rate, response time, error rate | API performance |
| Resource usage | Counts by resource type, operation type | Understanding usage patterns |
| Database | Query performance, connection pool, locks | Database health |
| Alerting | Active alerts, recent notifications | Current system status |

### Sample Dashboard Layout

```
+---------------------------+---------------------------+
|                           |                           |
|     System Overview       |    FHIR Operations        |
|                           |                           |
+---------------------------+---------------------------+
|                           |                           |
|     Resource Usage        |    Database Metrics       |
|                           |                           |
+---------------------------+---------------------------+
|                                                       |
|                  Active Alerts                        |
|                                                       |
+-------------------------------------------------------+
|                                                       |
|                  Historical Trends                    |
|                                                       |
+-------------------------------------------------------+
```

## Conclusion

Effective monitoring and alerting are essential for maintaining a reliable FHIR server implementation. By implementing comprehensive monitoring for server health, resource utilization, and application performance, you can ensure high availability, detect issues early, and maintain optimal performance for your healthcare data exchange platform.

Key takeaways:

1. Implement health checks to verify server availability and functionality
2. Monitor system resources to prevent performance degradation
3. Track application-level metrics to understand usage patterns and performance
4. Establish appropriate alerting thresholds and notification channels
5. Create operational dashboards for visibility into system health

By following these guidelines, you can create a robust monitoring and alerting system that helps maintain the reliability and performance of your FHIR server implementation.
