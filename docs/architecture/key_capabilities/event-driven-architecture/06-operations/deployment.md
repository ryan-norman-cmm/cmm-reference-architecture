# Event Broker Deployment

## Introduction
This document outlines the deployment architecture, strategies, and processes for the Event Broker platform at CoverMyMeds. It provides infrastructure teams and platform engineers with a comprehensive guide to deploying and managing the Event Broker infrastructure in a secure, scalable, and compliant manner.

## Deployment Architecture

### Platform Components
The Event Broker deployment consists of the following core components:

| Component | Technology | Purpose |
|-----------|------------|---------|
| **Kafka Brokers** | Confluent Server 7.3+ | Event message storage and distribution |
| **ZooKeeper** | Apache ZooKeeper 3.8+ | Cluster coordination (being phased out for KRaft) |
| **Schema Registry** | Confluent Schema Registry | Schema management and validation |
| **REST Proxy** | Confluent REST Proxy | HTTP-based Kafka interface |
| **Connect Workers** | Kafka Connect | Integration with external systems |
| **ksqlDB** | Confluent ksqlDB | Stream processing capabilities |
| **Control Center** | Confluent Control Center | Management and monitoring interface |
| **MirrorMaker 2** | Apache Kafka | Cross-cluster replication |

### Deployment Environments

| Environment | Purpose | Scale | Notes |
|-------------|---------|-------|-------|
| **Development** | Feature development, testing | 3 brokers, 1 zone | Non-critical, reduced redundancy |
| **QA/Test** | Integration testing, performance validation | 3-6 brokers, 2 zones | Production-like with reduced scale |
| **Staging** | Pre-production validation | 9 brokers, 3 zones | Production mirror with full redundancy |
| **Production** | Business-critical workloads | 12+ brokers, 3 zones | Fully scaled, highly available |
| **DR** | Disaster recovery | 9+ brokers, 3 zones | Geo-replicated standby |

## Infrastructure Provisioning

### Kubernetes-Based Deployment
The Event Broker platform is deployed on Kubernetes using the Confluent Operator:

```yaml
# Example Kafka cluster definition
apiVersion: platform.confluent.io/v1beta1
kind: Kafka
metadata:
  name: kafka-prod
  namespace: event-broker
spec:
  replicas: 12
  image:
    application: confluentinc/cp-server:7.3.1
    init: confluentinc/confluent-init-container:2.5.1
  dataVolumeCapacity: 1Ti
  metricReporter:
    enabled: true
  listeners:
    internal:
      port: 9092
      tls:
        enabled: true
    external:
      port: 9093
      tls:
        enabled: true
      authentication:
        type: plain
  authorization:
    type: rbac
  configOverrides:
    server:
      - "num.partitions=12"
      - "default.replication.factor=3"
      - "min.insync.replicas=2"
    jvm:
      - "-Xms8g"
      - "-Xmx12g"
      - "-XX:+ExitOnOutOfMemoryError"
  rack:
    topology:
      key: topology.kubernetes.io/zone
    labelSelector:
      matchLabels:
        app: kafka
```

### Infrastructure as Code
All infrastructure is provisioned using:
- **Terraform**: Cloud infrastructure (EKS, networking, security)
- **Helm Charts**: Kubernetes resources and Confluent Operator
- **GitOps**: ArgoCD for deployment automation
- **Custom CRDs**: Extensions for CMM-specific configurations

## Network Architecture

### Network Topology
- **Service Mesh**: Istio for secure service-to-service communication
- **Ingress**: NGINX Ingress Controller with WAF integration
- **DNS**: Route53 for service discovery
- **Load Balancing**: NLB for Kafka listener endpoints
- **Private Link**: AWS PrivateLink for cross-account access

### Security Groups and Firewalls
- Kafka brokers: Internal only (VPC)
- Schema Registry: Internal only (VPC)
- REST Proxy: Internal with API Gateway
- Control Center: Internal with SSO gateway

### Connectivity Diagram

```
┌───────────────────────────────────┐                  ┌──────────────────────┐
│      Consumer Applications        │                  │  Producer Applications│
└───────────────┬───────────────────┘                  └──────────┬───────────┘
                │                                                  │
                ▼                                                  ▼
┌───────────────────────────────────┐                  ┌──────────────────────┐
│       API Gateway / Istio         │◄─────────────────▶       Istio Mesh     │
└───────────────┬───────────────────┘                  └──────────┬───────────┘
                │                                                  │
                ▼                                                  ▼
┌───────────────────────────────────────────────────────────────────────────────┐
│                                  Kubernetes Cluster                            │
│                                                                               │
│   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    │
│   │ REST Proxy  │    │Schema Registry   │ Kafka Connect│    │  Control    │    │
│   │             │    │                 │             │    │  Center     │    │
│   └──────┬──────┘    └────────┬───────┘    └─────────────┘    └─────────────┘    │
│          │                    │                                                │
│          ▼                    ▼                                                │
│   ┌───────────────────────────────────────────────────────────────────────┐   │
│   │                           Kafka Brokers                               │   │
│   │                                                                       │   │
│   │   ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐   │
│   │   │ Broker 1│    │ Broker 2│    │ Broker 3│    │ Broker .│    │ Broker n│   │
│   │   │(Zone A) │    │(Zone B) │    │(Zone C) │    │         │    │         │   │
│   │   └─────────┘    └─────────┘    └─────────┘    └─────────┘    └─────────┘   │
│   └───────────────────────────────────────────────────────────────────────┘   │
│                                                                               │
└───────────────────────────────────────────────────────────────────────────────┘
```

## Storage Configuration

### Volume Management
- Broker data stored on dedicated EBS volumes (gp3)
- Separate volumes for logs and data
- Volume sizing based on retention policy and throughput needs
- Automatic volume expansion triggers

### Backup and Snapshot Strategy
- Daily EBS snapshots for volume recovery
- Topic-based backup with Kafka Connect S3 sink
- Configuration backups in Git repository
- Full cluster state backups for disaster recovery

## Security Implementation

### Authentication & Authorization
- **mTLS**: Service-to-service authentication
- **SASL/OAUTHBEARER**: Application authentication
- **RBAC**: Fine-grained authorization control
- **Service Accounts**: Machine-to-machine authentication

### Encryption
- TLS 1.3 for all in-transit encryption
- At-rest encryption with AWS KMS
- Certificate management via cert-manager
- Automated certificate rotation

### Security Hardening
- Minimal base image with security patches
- Non-root container execution
- Network policy enforcement
- Pod security policies
- Regular vulnerability scanning

## Configuration Management

### Configuration Hierarchy
1. Default Confluent configurations
2. Environment-specific overrides
3. Cluster-level settings
4. Pod/broker level fine-tuning

### Configuration Sources
- Git repository (source of truth)
- ConfigMaps for non-sensitive configuration
- Secrets for sensitive configuration
- Dynamic configuration for runtime adjustments

### Configuration Validation
- Pre-deployment validation hooks
- Configuration linting
- Integration tests for configuration changes
- Canary deployments for risky changes

## Multi-Region Deployment

### Active-Active Configuration
- Independent Kafka clusters per region
- MirrorMaker 2 for cross-region replication
- Topic configuration maintained across regions
- Schema Registry replication between regions

### Failover Architecture
- Regional health monitoring
- Automated topic failover
- DNS-based client redirection
- DR testing framework

## Deployment Workflow

### Continuous Deployment Pipeline
1. **Code Change**:
   - Infrastructure changes committed to Git
   - PR process with approvals
   - Automated validation tests

2. **Build & Test**:
   - Infrastructure validation
   - Configuration testing
   - Security scanning
   - Artifact generation

3. **Deployment Stages**:
   - Deploy to Development (automatic)
   - Deploy to QA/Test (automatic with tests)
   - Deploy to Staging (manual approval)
   - Deploy to Production (manual approval)

4. **Verification**:
   - Post-deployment tests
   - Synthetic transactions
   - Metric verification
   - Rollback capability

### Deployment Rollout Strategy
- Rolling updates for broker configuration
- Blue-green for supporting services
- Canary deployments for high-risk changes
- Controlled client migration for major upgrades

## Initial Deployment Checklist

### Pre-Deployment Requirements
- [ ] Network configuration verified
- [ ] IAM roles and policies established
- [ ] Certificate management solution in place
- [ ] Storage classes defined and tested
- [ ] Monitoring infrastructure ready
- [ ] Security scanning integrated

### Deployment Steps
1. Deploy Kubernetes infrastructure
2. Deploy Confluent Operator
3. Deploy ZooKeeper/KRaft controllers
4. Deploy Kafka brokers
5. Deploy Schema Registry
6. Deploy supporting services
7. Configure security policies
8. Verify monitoring and alerting
9. Run validation tests
10. Onboard initial topics

## Related Resources
- [Event Broker Monitoring](./monitoring.md)
- [Event Broker Scaling](./scaling.md)
- [Event Broker CI/CD Pipeline](./ci-cd-pipeline.md)