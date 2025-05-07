# FHIR Interoperability Platform Deployment

## Introduction
This document outlines the deployment architecture, strategies, and processes for the FHIR Interoperability Platform at CoverMyMeds. It provides infrastructure teams and platform engineers with a comprehensive guide to deploying and managing the FHIR Interoperability Platform infrastructure in a secure, scalable, and compliant manner.

## Deployment Architecture

### Platform Components
The FHIR Interoperability Platform deployment consists of the following core components:

| Component | Technology | Purpose |
|-----------|------------|---------|
| **FHIR Server** | Aidbox (Health Samurai) | Core FHIR API implementation, resource storage, validation, and processing |
| **PostgreSQL Database** | PostgreSQL 13+ | Primary data storage for FHIR resources and operational data |
| **Search Engine** | PostgreSQL/Elasticsearch | Optimized FHIR search capabilities |
| **Terminology Service** | Aidbox Terminology Module | Terminology management, validation, and lookup services |
| **API Gateway** | MuleSoft | API management, request routing, and policy enforcement |
| **Authentication Service** | OAuth 2.0/OpenID Connect | User and service authentication |
| **Kafka Cluster** | Apache Kafka | Event streaming for subscriptions and integrations |
| **Object Storage** | S3-compatible | Storage for large binary attachments and documents |
| **Cache** | Redis | Performance optimization for frequent lookups |
| **Service Mesh** | Istio | Secure service-to-service communication |

### Deployment Environments

| Environment | Purpose | Scale | Notes |
|-------------|---------|-------|-------|
| **Development** | Feature development, testing | 1 replica, reduced resources | Shared instance, refreshed weekly |
| **QA/Test** | Integration testing, performance validation | 2 replicas, moderate resources | Test data, integration test suite |
| **Staging** | Pre-production validation | 3 replicas, production-like | Production data subset, pre-release verification |
| **Production** | Business-critical workloads | 5+ replicas, full resources | High availability, auto-scaling |
| **DR** | Disaster recovery | Production mirror | Standby mode, regular sync |

## Infrastructure Provisioning

### Kubernetes-Based Deployment
The FHIR Interoperability Platform is deployed on Kubernetes using Helm charts and GitOps principles:

```yaml
# Example Kubernetes manifest for FHIR Server
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fhir-server
  namespace: fhir-interoperability
  labels:
    app: fhir-server
    component: api
spec:
  replicas: 5
  selector:
    matchLabels:
      app: fhir-server
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: fhir-server
        component: api
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
    spec:
      containers:
      - name: fhir-server
        image: healthsamurai/aidboxone:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 8080
          name: http
        env:
        - name: AIDBOX_PORT
          value: "8080"
        - name: AIDBOX_FHIR_VERSION
          value: "4.0.1"
        - name: AIDBOX_DB_HOST
          valueFrom:
            configMapKeyRef:
              name: fhir-server-config
              key: db.host
        - name: AIDBOX_DB_PORT
          valueFrom:
            configMapKeyRef:
              name: fhir-server-config
              key: db.port
        - name: AIDBOX_DB_NAME
          valueFrom:
            configMapKeyRef:
              name: fhir-server-config
              key: db.name
        - name: AIDBOX_DB_USER
          valueFrom:
            secretKeyRef:
              name: fhir-server-secrets
              key: db.user
        - name: AIDBOX_DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: fhir-server-secrets
              key: db.password
        - name: AIDBOX_LICENSE
          valueFrom:
            secretKeyRef:
              name: fhir-server-secrets
              key: license
        resources:
          requests:
            memory: "2Gi"
            cpu: "1"
          limits:
            memory: "4Gi"
            cpu: "2"
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 60
          periodSeconds: 20
        volumeMounts:
        - name: config
          mountPath: /app/config
        - name: temp-storage
          mountPath: /app/tmp
      volumes:
      - name: config
        configMap:
          name: fhir-server-config
      - name: temp-storage
        emptyDir: {}
```

### Infrastructure as Code
All infrastructure is provisioned using:
- **Terraform**: Cloud infrastructure (VPC, subnets, security groups, etc.)
- **Helm Charts**: Kubernetes resources and operators
- **ArgoCD**: GitOps-based deployment automation
- **Ansible**: Configuration management for non-container workloads
- **Kustomize**: Environment-specific configuration overlays

### Example Terraform Infrastructure

```hcl
# Example Terraform for FHIR Platform VPC and networking
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "3.14.0"

  name = "fhir-platform-vpc-${var.environment}"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  database_subnets = ["10.0.201.0/24", "10.0.202.0/24", "10.0.203.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = var.environment != "production"
  
  enable_vpn_gateway = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  create_database_subnet_group = true
  
  tags = {
    Environment = var.environment
    ManagedBy = "terraform"
    Component = "fhir-interoperability-platform"
  }
}

# RDS PostgreSQL database
module "fhir_db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "4.2.0"

  identifier = "fhir-db-${var.environment}"

  engine               = "postgres"
  engine_version       = "13.7"
  family               = "postgres13"
  major_engine_version = "13"
  instance_class       = var.environment == "production" ? "db.r6g.2xlarge" : "db.r6g.large"

  allocated_storage     = var.environment == "production" ? 1000 : 100
  max_allocated_storage = var.environment == "production" ? 5000 : 1000

  db_name  = "fhir_db"
  username = "fhir_app"
  port     = 5432

  multi_az               = var.environment == "production"
  db_subnet_group_name   = module.vpc.database_subnet_group_name
  vpc_security_group_ids = [module.db_security_group.security_group_id]

  maintenance_window      = "Mon:00:00-Mon:03:00"
  backup_window           = "03:00-06:00"
  backup_retention_period = var.environment == "production" ? 30 : 7

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  
  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  create_monitoring_role                = true
  monitoring_interval                   = 60

  deletion_protection = var.environment == "production"
  
  tags = {
    Environment = var.environment
    ManagedBy = "terraform"
    Component = "fhir-interoperability-platform"
  }
}

# Redis cache
module "redis" {
  source = "terraform-aws-modules/elasticache/aws"
  version = "2.0.0"

  name = "fhir-cache-${var.environment}"
  
  engine         = "redis"
  engine_version = "6.x"
  port           = 6379
  
  cluster_size = var.environment == "production" ? 3 : 1
  
  instance_type = var.environment == "production" ? "cache.r6g.large" : "cache.t3.medium"
  
  subnet_group_name = module.vpc.elasticache_subnet_group_name
  security_group_ids = [module.redis_security_group.security_group_id]
  
  apply_immediately = true
  auto_minor_version_upgrade = true
  
  tags = {
    Environment = var.environment
    ManagedBy = "terraform"
    Component = "fhir-interoperability-platform"
  }
}
```

## Network Architecture

### Network Topology
- **Service Mesh**: Istio for secure service-to-service communication
- **Ingress**: NGINX Ingress Controller with WAF integration
- **DNS**: Route53 for service discovery
- **Load Balancing**: ALB for endpoint access
- **Private Connectivity**: AWS PrivateLink for cross-account access

### Security Groups and Firewalls
- **FHIR API endpoints**: HTTPS (443) from authorized networks
- **Management interfaces**: Restricted to internal networks
- **Database access**: Restricted to application subnets
- **Monitoring interfaces**: Restricted to monitoring subnets

### Connectivity Diagram

```
                     ┌───────────────────┐
                     │                   │
                     │  API Consumers    │
                     │                   │
                     └─────────┬─────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────┐
│                                                     │
│                    WAF / Shield                     │
│                                                     │
└─────────────────────────┬───────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────┐
│                                                     │
│                  Load Balancer (ALB)                │
│                                                     │
└─────────────────────────┬───────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────┐
│                                                     │
│                 API Gateway / Ingress               │
│                                                     │
└──┬───────────────────┬────────────────┬────────────┘
   │                   │                │
   ▼                   ▼                ▼
┌──────────┐     ┌──────────┐     ┌──────────┐
│          │     │          │     │          │
│  FHIR    │     │  Auth    │     │  Admin   │
│  Server  │     │  Service │     │  API     │
│          │     │          │     │          │
└──┬───────┘     └──────────┘     └──────────┘
   │
   ▼
┌──────────┐     ┌──────────┐     ┌──────────┐
│          │     │          │     │          │
│ Database │     │  Redis   │     │  Kafka   │
│          │     │  Cache   │     │          │
│          │     │          │     │          │
└──────────┘     └──────────┘     └──────────┘
```

## Storage Configuration

### Volume Management
- FHIR database: PostgreSQL on dedicated storage optimized for IOPS
- Binary attachments: S3-compatible object storage for large files
- Temporary storage: Ephemeral volumes for processing
- Configuration: ConfigMaps and Secrets mounted as volumes

### Backup and Snapshot Strategy
- Daily automated database backups
- Point-in-time recovery enabled (5-minute RPO)
- Database snapshot before major upgrades
- Weekly full backup for long-term retention
- Geo-replicated backups for disaster recovery

## Security Implementation

### Authentication & Authorization
- **OAuth 2.0/OpenID Connect**: Standard authentication for users and applications
- **SMART on FHIR**: Healthcare-specific authentication profiles
- **Mutual TLS**: Certificate-based authentication for system-to-system integration
- **Service Accounts**: Kubernetes-managed identities for internal services

### Encryption
- TLS 1.3 for all external and internal communications
- TLS termination at load balancer with re-encryption to backends
- Database encryption at rest using AWS KMS
- Object storage encryption with customer-managed keys
- Secret encryption using Kubernetes secrets management

### Security Hardening
- Container image scanning and signing
- Pod security policies enforcing non-root execution
- Network policies restricting pod-to-pod communication
- Regular vulnerability scanning
- CIS-hardened node images

## Configuration Management

### Configuration Hierarchy
1. Default vendor configurations
2. CoverMyMeds base configurations
3. Environment-specific configurations (dev/test/staging/prod)
4. Instance-specific configurations (when needed)

### Configuration Sources
- Git repository (source of truth)
- ConfigMaps for non-sensitive configuration
- Secrets for sensitive configuration
- Environment variables for runtime settings

### Example Configuration

```yaml
# Aidbox Configuration
fhir:
  version: 4.0.1
  validation:
    enabled: true
    level: warning
    terminology-validation: true
  uscore:
    enabled: true
    version: 5.0.1
  custom-profiles:
    enabled: true
    source: /config/profiles
  extensions:
    validate: true

auth:
  providers:
    - type: oauth2
      name: enterprise-idp
      issuerUrl: https://auth.covermymeds.com
      clientId: fhir-platform-client
    - type: smart-on-fhir
      name: smart-apps
      issuerUrl: https://fhir-api.covermymeds.com

storage:
  transaction-log:
    enabled: true
    retention: 7d
  binary-storage:
    type: s3
    bucket: fhir-binaries
    region: us-east-1
  audit-storage:
    type: s3
    bucket: fhir-audit-logs
    region: us-east-1

search:
  engine: postgresql
  enable-fuzzy-search: true
  max-results: 1000
  default-count: 100

terminology:
  service:
    enabled: true
    cache:
      enabled: true
      ttl: 86400
  value-set-expansion:
    max-size: 1000

subscriptions:
  enabled: true
  backend: kafka
  kafka:
    bootstrap-servers: kafka:9092
    topic-prefix: fhir-subscription
    group-id: fhir-server

logging:
  level: info
  format: json
  output: stdout
  request-logging: true
  access-logging: true
  error-logging: true
```

## Multi-Region Deployment

### Active-Active Configuration
- Primary region: US East (N. Virginia)
- Secondary region: US West (Oregon)
- Cross-region database replication with RDS Multi-AZ
- Global load balancing with Route53 health checks
- Synchronized configuration through GitOps

### Failover Architecture
- Automated health monitoring of regional endpoints
- DNS-based failover for regional outages
- Database replica promotion in disaster scenarios
- Regional data synchronization after recovery
- Regular failover testing

## Deployment Workflow

### Continuous Deployment Pipeline

1. **Code Change**:
   - Pull request against main branch
   - Automated PR validation
   - Code review process
   - Merge to main branch

2. **Build & Test**:
   - Automated build triggered on merge
   - Unit and integration tests
   - Security scanning (SAST, SCA)
   - Container image building and signing

3. **Deployment Stages**:
   - Dev deployment (automated)
   - Test deployment (automated with approval)
   - Staging deployment (automated with approval)
   - Production deployment (scheduled with approval)

4. **Verification**:
   - Automated smoke tests
   - Synthetic transactions
   - Metric verification
   - Manual validation for critical changes

### Example Jenkins Pipeline

```groovy
pipeline {
    agent any
    
    environment {
        IMAGE_NAME = 'fhir-interoperability-platform'
        IMAGE_TAG = "${BUILD_NUMBER}"
        DOCKER_REGISTRY = 'docker-registry.covermymeds.com'
    }
    
    stages {
        stage('Build') {
            steps {
                sh 'docker build -t ${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} .'
            }
        }
        
        stage('Test') {
            steps {
                sh 'docker run --rm ${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} npm test'
                sh 'docker run --rm ${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} npm run lint'
            }
        }
        
        stage('Security Scan') {
            steps {
                sh 'trivy image ${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}'
            }
        }
        
        stage('Push Image') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'docker-registry', passwordVariable: 'DOCKER_PASSWORD', usernameVariable: 'DOCKER_USERNAME')]) {
                    sh 'echo $DOCKER_PASSWORD | docker login ${DOCKER_REGISTRY} -u $DOCKER_USERNAME --password-stdin'
                    sh 'docker push ${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}'
                }
            }
        }
        
        stage('Deploy to Dev') {
            steps {
                sh 'helm upgrade --install fhir-platform ./helm/fhir-platform --namespace fhir-dev --set image.tag=${IMAGE_TAG} --values ./helm/values/dev.yaml'
            }
        }
        
        stage('Integration Tests') {
            steps {
                sh 'npm run integration-test -- --url https://fhir-dev.covermymeds.com'
            }
        }
        
        stage('Deploy to Test') {
            when {
                branch 'main'
            }
            steps {
                input message: 'Deploy to Test environment?'
                sh 'helm upgrade --install fhir-platform ./helm/fhir-platform --namespace fhir-test --set image.tag=${IMAGE_TAG} --values ./helm/values/test.yaml'
            }
        }
        
        stage('Deploy to Staging') {
            when {
                branch 'main'
            }
            steps {
                input message: 'Deploy to Staging environment?'
                sh 'helm upgrade --install fhir-platform ./helm/fhir-platform --namespace fhir-staging --set image.tag=${IMAGE_TAG} --values ./helm/values/staging.yaml'
            }
        }
        
        stage('Production Approval') {
            when {
                branch 'main'
            }
            steps {
                input message: 'Deploy to Production environment?'
            }
        }
        
        stage('Deploy to Production') {
            when {
                branch 'main'
            }
            steps {
                sh 'helm upgrade --install fhir-platform ./helm/fhir-platform --namespace fhir-production --set image.tag=${IMAGE_TAG} --values ./helm/values/production.yaml'
            }
        }
    }
    
    post {
        always {
            cleanWs()
        }
    }
}
```

### Deployment Rollout Strategy
- Blue-green deployments for zero-downtime updates
- Canary releases for high-risk changes (10% → 50% → 100%)
- Feature flags for conditional feature enablement
- Automated rollback on health check failures
- Scheduled maintenance windows for major upgrades

## Initial Deployment Checklist

### Pre-Deployment Requirements
- [ ] Network configuration verified
- [ ] IAM roles and policies established
- [ ] Certificate management solution in place
- [ ] Storage classes defined and tested
- [ ] Monitoring infrastructure ready
- [ ] Security scanning integrated
- [ ] Backup solutions configured and tested
- [ ] DR strategy documented and tested

### Deployment Steps
1. Deploy infrastructure components using Terraform
2. Create Kubernetes namespaces and RBAC configuration
3. Deploy database and setup initial schema
4. Deploy Redis cache clusters
5. Deploy Kafka if using FHIR subscriptions
6. Deploy FHIR server instances
7. Configure API gateway and ingress
8. Setup monitoring and alerting
9. Perform initial data loading (if needed)
10. Execute verification tests
11. Update DNS and enable traffic

## Related Resources
- [FHIR Interoperability Platform Monitoring](./monitoring.md)
- [FHIR Interoperability Platform Maintenance](./maintenance.md)
- [FHIR Interoperability Platform Troubleshooting](./troubleshooting.md)
- [FHIR Interoperability Platform Architecture](../01-getting-started/architecture.md)
- [Aidbox Deployment Documentation](https://docs.aidbox.app/getting-started/installation)