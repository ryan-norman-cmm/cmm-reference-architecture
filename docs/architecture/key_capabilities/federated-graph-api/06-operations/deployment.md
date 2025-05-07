# Federated Graph API Deployment

## Introduction
This document outlines the deployment architecture, strategies, and processes for the Federated Graph API at CoverMyMeds. It provides infrastructure teams and platform engineers with a comprehensive guide to deploying and managing the Federated Graph API infrastructure in a secure, scalable, and compliant manner.

## Deployment Architecture

### Platform Components
The Federated Graph API deployment consists of the following core components:

| Component | Technology | Purpose |
|-----------|------------|---------|
| **Apollo Router** | Apollo Router v1.x | Gateway service that routes GraphQL queries to subgraphs |
| **Schema Registry** | Apollo GraphOS | Schema storage, federation composition, and schema validation |
| **Subgraphs** | Node.js/Apollo Server | Domain-specific GraphQL services that implement parts of the schema |
| **Observability Stack** | Prometheus, Grafana, OpenTelemetry | Monitoring, alerting, and tracing |
| **Secret Management** | Vault | Secure storage and management of credentials and certificates |
| **Service Discovery** | Kubernetes Service/DNS | Dynamic discovery of subgraph services |

### Deployment Environments

| Environment | Purpose | Scale | Notes |
|-------------|---------|-------|-------|
| **Development** | Feature development, testing | 1 router, 1 replica per subgraph | Individual developer environments with schema testing |
| **QA/Test** | Integration testing, performance validation | 2 routers, 2 replicas per subgraph | Shared testing environment with test data |
| **Staging** | Pre-production validation | 3 routers, 3 replicas per subgraph | Production-like with anonymized data |
| **Production** | Business-critical workloads | 5+ routers, 5+ replicas per subgraph | High availability, auto-scaling enabled |
| **DR** | Disaster recovery | Mirrors production | Cross-region deployment with automated failover |

## Infrastructure Provisioning

### Kubernetes-Based Deployment
The Federated Graph API is deployed on Kubernetes using Helm charts and custom operators:

```yaml
# Example Kubernetes manifest for Apollo Router
apiVersion: apps/v1
kind: Deployment
metadata:
  name: apollo-router
  namespace: federated-graph
  labels:
    app: apollo-router
    component: gateway
spec:
  replicas: 5
  selector:
    matchLabels:
      app: apollo-router
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
    type: RollingUpdate
  template:
    metadata:
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9090"
      labels:
        app: apollo-router
    spec:
      containers:
      - name: router
        image: ghcr.io/apollographql/router:v1.20.0
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 4000
          name: http
        - containerPort: 9090
          name: metrics
        env:
        - name: APOLLO_ROUTER_SUPERGRAPH_PATH
          value: /etc/apollo/supergraph.graphql
        - name: APOLLO_ROUTER_CONFIG_PATH
          value: /etc/apollo/router.yaml
        volumeMounts:
        - name: config
          mountPath: /etc/apollo
          readOnly: true
        resources:
          limits:
            cpu: "2"
            memory: "4Gi"
          requests:
            cpu: "1"
            memory: "2Gi"
        livenessProbe:
          httpGet:
            path: /.well-known/apollo/server-health
            port: 4000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /.well-known/apollo/server-health
            port: 4000
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: config
        configMap:
          name: apollo-router-config
```

Example subgraph deployment:

```yaml
# Example Kubernetes manifest for a subgraph service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: patient-subgraph
  namespace: federated-graph
  labels:
    app: patient-subgraph
    domain: patient
spec:
  replicas: 3
  selector:
    matchLabels:
      app: patient-subgraph
  template:
    metadata:
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9090"
      labels:
        app: patient-subgraph
    spec:
      containers:
      - name: server
        image: covermymeds/patient-subgraph:1.5.2
        ports:
        - containerPort: 4001
          name: http
        - containerPort: 9090
          name: metrics
        env:
        - name: NODE_ENV
          value: "production"
        - name: LOG_LEVEL
          value: "info"
        - name: PORT
          value: "4001"
        - name: PATIENT_SERVICE_URL
          valueFrom:
            configMapKeyRef:
              name: subgraph-config
              key: patient_service_url
        - name: AUTH_SECRET
          valueFrom:
            secretKeyRef:
              name: subgraph-secrets
              key: auth_secret
        resources:
          limits:
            cpu: "1"
            memory: "1Gi"
          requests:
            cpu: "0.5"
            memory: "512Mi"
        livenessProbe:
          httpGet:
            path: /.well-known/apollo/server-health
            port: 4001
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /.well-known/apollo/server-health
            port: 4001
          initialDelaySeconds: 5
          periodSeconds: 5
```

### Infrastructure as Code
All infrastructure is provisioned using:
- **Terraform**: Cloud infrastructure (EKS clusters, networking, IAM roles)
- **Helm Charts**: Kubernetes resources for Apollo Router and subgraphs
- **ArgoCD**: GitOps deployment automation
- **Custom CRDs**: Schema registry integration and subgraph management

## Network Architecture

### Network Topology
- **Service Mesh**: Istio for secure service-to-service communication
- **Ingress**: AWS ALB Ingress Controller with WAF integration
- **DNS**: Route53 for service discovery and global routing
- **Load Balancing**: Network Load Balancer for GraphQL API endpoint
- **Private Connectivity**: VPC Peering for cross-account access

### Security Groups and Firewalls
- GraphQL API endpoints: Allow HTTPS (443) from trusted networks
- Subgraph services: Internal service mesh communication only
- Management interfaces: Access restricted to operations VPN
- Metrics endpoints: Access restricted to monitoring systems

### Connectivity Diagram

```
                                       +---------------------+
  ┌─────────────────┐                  |                     |
  │                 │  HTTPS/443       |  AWS Application    |
  │  Web/Mobile     ├─────────────────►|  Load Balancer      |
  │  Clients        │                  |                     |
  │                 │                  +─────────┬───────────+
  └─────────────────┘                            │
                                                 ▼
                                      ┌──────────────────────┐
        ┌────────────────┐           │                      │
        │                │   HTTPS   │                      │
        │  Admin Portal  ├──────────►│   Apollo Router      │──┐
        │                │           │   (Gateway Layer)    │  │
        └────────────────┘           │                      │  │
                                      └──────────┬───────────┘  │
                                                 │              │
                                                 ▼              │
┌───────────────────────────────────────────────────────────────┘
│
│         ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│         │             │     │             │     │             │
▼         │  Patient    │     │  Medication │     │  FHIR       │
┌────────►│  Subgraph   │     │  Subgraph   │     │  Subgraph   │
│         │             │     │             │     │             │
│         └──────┬──────┘     └──────┬──────┘     └──────┬──────┘
│                │                   │                   │
│                ▼                   ▼                   ▼
│         ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│         │             │     │             │     │             │
│         │  Patient    │     │  Medication │     │  FHIR       │
└────────►│  Database   │     │  Database   │     │  Service    │
          │             │     │             │     │             │
          └─────────────┘     └─────────────┘     └─────────────┘
```

## Storage Configuration

### Volume Management
- Router configuration stored on ephemeral volumes with ConfigMap source
- Subgraph services are stateless, no persistent volumes required
- Schema Registry data stored in managed services
- Logs and metrics stored on dedicated persistent volumes

### Backup and Snapshot Strategy
- Daily supergraph schema backups
- Schema Registry data backed up hourly
- Router and subgraph configurations backed up with each deployment
- 30-day retention for configuration backups

## Security Implementation

### Authentication & Authorization
- **JWT Authentication**: API clients authenticate using JWTs issued by identity provider
- **OAuth 2.0**: Authorization framework for client applications
- **GraphQL Directives**: Field-level authorization controls in schema
- **Service Account Strategy**: Kubernetes service accounts with minimal permissions for each service

### Encryption
- TLS 1.3 for all external and internal communications
- TLS certificate management via cert-manager
- Automatic certificate rotation every 90 days
- Vault integration for secrets management

### Security Hardening
- Non-root container execution
- Read-only filesystem where possible
- Pod Security Policies enforcing best practices
- Network policies restricting pod-to-pod communication
- Regular vulnerability scanning

## Configuration Management

### Configuration Hierarchy
1. Default Apollo Router configuration
2. Environment-specific overrides (dev, test, stage, prod)
3. Special handling for sensitive configurations
4. Feature flags for progressive rollout

### Configuration Sources
- Git repository (source of truth)
- ConfigMaps for non-sensitive configuration
- Kubernetes Secrets for sensitive configuration
- Apollo GraphOS for schema registry configuration

Example Apollo Router configuration:

```yaml
# router.yaml
supergraph:
  listen: 0.0.0.0:4000
  
health_check:
  listen: 0.0.0.0:8080
  
telemetry:
  apollo:
    # Apollo Studio reporting
    endpoint: "https://usage-reporting.api.apollographql.com"
    apollo_key: ${env.APOLLO_KEY}
    apollo_graph_ref: ${env.APOLLO_GRAPH_REF}
  
  metrics:
    prometheus:
      enabled: true
      path: /metrics
      listen: 0.0.0.0:9090
      
  tracing:
    opentelemetry:
      enabled: true
      sampler:
        parent_based: true
        root:
          sampling_ratio: 0.1
      otlp:
        endpoint: "http://otel-collector.monitoring:4317"
        timeout: 30s
  
cors:
  allow_any_origin: false
  origins:
    - https://app.covermymeds.com
    - https://portal.covermymeds.com
  
headers:
  all:
    request:
      - insert:
          name: "Apollo-Federation-Include-Trace"
          value: "ftv1"
  
authentication:
    jwt:
      header_name: "Authorization"
      header_value_prefix: "Bearer "
      jwks:
        url: "https://identity.covermymeds.com/.well-known/jwks.json"
  
authorization:
  require_authentication: true
  directives:
    enabled: true
  
plugins:
  experimental.expose_query_plan: true
  
limits:
  max_depth: 15
  max_height: 200
  max_aliases: 30
  
include_subgraph_errors:
  all: true

preview_entities_limit: 10
```

### Configuration Validation
- Schema validation against composition rules
- Router configuration validation before deployment
- Integration tests for configuration changes
- Canary deployments for risky changes

## Multi-Region Deployment

### Active-Active Configuration
- Deployed across multiple AWS regions (us-east-1, us-west-2)
- Global Route53 DNS with health checks for routing
- Cross-region schema registry synchronization
- Configuration synchronized across regions

### Failover Architecture
- Automated health checks and alerting
- DNS-based failover routing
- Regional API endpoints with client-side retry logic
- Regular disaster recovery testing

## Deployment Workflow

### Continuous Deployment Pipeline
1. **Code Change**:
   - Developer commits changes to subgraph or router code
   - Pull request triggers CI pipeline
   - Automated testing and validation
   - Code review and approval

2. **Build & Test**:
   - Container image building with semantic versioning
   - Unit and integration testing
   - Security scanning (SonarQube, Snyk)
   - Schema validation against existing schema

3. **Deployment Stages**:
   - Development: Automatic deployment on PR merge
   - QA/Test: Manual approval, automated deployment
   - Staging: Manual approval, automated deployment
   - Production: Manual approval, automated deployment with canary

4. **Verification**:
   - Health check verification post-deployment
   - Synthetic GraphQL queries to verify functionality
   - Metric verification for performance and error rates
   - Zero-downtime validation

### Deployment Rollout Strategy
- Blue/Green deployments for routers to ensure zero downtime
- Canary deployments for subgraphs to validate changes
- Feature flags for incremental rollout of functionality
- Schema checks against production traffic before deployment

## Initial Deployment Checklist

### Pre-Deployment Requirements
- [ ] Kubernetes cluster provisioned and configured
- [ ] IAM roles and policies established
- [ ] Certificate management solution in place
- [ ] DNS records configured
- [ ] Monitoring infrastructure ready
- [ ] Security scanning integrated
- [ ] Apollo GraphOS account configured
- [ ] JWKS endpoint available from identity provider

### Deployment Steps
1. Deploy Apollo GraphOS connector and configure schema registry
2. Deploy supporting services (monitoring, logging)
3. Deploy first version of subgraphs with basic functionality
4. Validate subgraph composition in registry
5. Deploy Apollo Router with initial configuration
6. Configure load balancer and ingress
7. Run validation queries and fix any issues
8. Enable monitoring and alerting
9. Gradually enable advanced features

## Related Resources
- [Federated Graph API Monitoring](./monitoring.md)
- [Federated Graph API Scaling](./scaling.md)
- [Federated Graph API Maintenance](./maintenance.md)
- [Federated Graph API Schema Governance](../04-governance-compliance/schema-governance.md)