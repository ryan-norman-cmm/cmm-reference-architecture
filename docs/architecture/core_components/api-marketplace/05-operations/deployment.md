# API Marketplace Deployment Guide

## Introduction

This document provides comprehensive instructions for deploying the API Marketplace component of the CMM Technology Platform. It covers deployment options, prerequisites, step-by-step deployment procedures, configuration, verification, and troubleshooting guidance. This guide is intended for operations teams, DevOps engineers, and system administrators responsible for deploying and maintaining the API Marketplace in various environments.

## Deployment Options

The API Marketplace supports multiple deployment options to accommodate different organizational needs and infrastructure environments.

### Containerized Deployment

The recommended deployment approach is using containers with Kubernetes orchestration:

- **Docker Containers**: All API Marketplace components are available as Docker containers
- **Kubernetes**: Orchestration for container management, scaling, and resilience
- **Helm Charts**: Simplified deployment and configuration management
- **Istio/Linkerd**: Optional service mesh for advanced networking capabilities

### On-Premises Deployment

For organizations requiring on-premises deployment:

- **Virtual Machines**: Deployment on VMware, Hyper-V, or other virtualization platforms
- **Bare Metal**: Direct deployment on physical servers
- **Private Kubernetes**: On-premises Kubernetes clusters
- **OpenShift**: Red Hat OpenShift Container Platform

### Cloud Deployment

For cloud-based deployments:

- **Managed Kubernetes**: EKS (AWS), AKS (Azure), GKE (Google Cloud)
- **Serverless Components**: Selected components can be deployed as serverless functions
- **Hybrid Deployment**: Combination of cloud and on-premises components

## Prerequisites

### Hardware Requirements

| Resource | Minimum | Recommended | High-Performance |
|----------|---------|-------------|------------------|
| CPU | 4 cores | 8 cores | 16+ cores |
| Memory | 8 GB | 16 GB | 32+ GB |
| Storage | 50 GB SSD | 100 GB SSD | 200+ GB SSD |
| Network | 1 Gbps | 10 Gbps | 10+ Gbps |

### Software Requirements

| Software | Version | Notes |
|----------|---------|-------|
| Kubernetes | 1.24+ | For containerized deployment |
| Docker | 20.10+ | For container management |
| Helm | 3.8+ | For deployment automation |
| MongoDB | 5.0+ | For metadata and catalog storage |
| PostgreSQL | 14.0+ | For relational data storage |
| Redis | 6.2+ | For caching and session management |
| Node.js | 18.0+ | For running non-containerized components |

### Network Requirements

| Port | Protocol | Purpose | Notes |
|------|----------|---------|-------|
| 80 | HTTP | HTTP traffic | Redirects to HTTPS |
| 443 | HTTPS | HTTPS traffic | Primary user interface and API access |
| 8080 | HTTP | Admin interface | Internal access only |
| 27017 | TCP | MongoDB connection | Internal access only |
| 5432 | TCP | PostgreSQL connection | Internal access only |
| 6379 | TCP | Redis connection | Internal access only |

### Security Prerequisites

- TLS certificates for secure communication
- Service accounts with appropriate permissions
- Network security groups or firewall rules
- Secrets management solution (e.g., HashiCorp Vault, Kubernetes Secrets)
- Identity provider integration for authentication

## Deployment Process

### Containerized Deployment with Kubernetes

#### Step 1: Prepare Kubernetes Cluster

Ensure your Kubernetes cluster is properly configured:

```bash
# Verify Kubernetes cluster access
kubectl cluster-info

# Create namespace for API Marketplace
kubectl create namespace api-marketplace

# Create service account
kubectl create serviceaccount api-marketplace -n api-marketplace

# Apply RBAC permissions
kubectl apply -f kubernetes/rbac.yaml
```

#### Step 2: Configure Persistent Storage

Set up persistent storage for stateful components:

```bash
# Create persistent volume claims
kubectl apply -f kubernetes/storage/persistent-volume-claims.yaml -n api-marketplace

# Verify PVCs are created and bound
kubectl get pvc -n api-marketplace
```

#### Step 3: Deploy Dependencies

Deploy required dependencies using Helm:

```bash
# Add Helm repositories
helm repo add bitnami https://charts.bitnami.com/bitnami

# Deploy MongoDB
helm install mongodb bitnami/mongodb \
  --namespace api-marketplace \
  --set auth.rootPassword=rootpassword \
  --set auth.username=apimarketplace \
  --set auth.password=apimarketplacepassword \
  --set auth.database=apimarketplace

# Deploy PostgreSQL
helm install postgresql bitnami/postgresql \
  --namespace api-marketplace \
  --set auth.postgresPassword=postgrespassword \
  --set auth.username=apimarketplace \
  --set auth.password=apimarketplacepassword \
  --set auth.database=apimarketplace

# Deploy Redis
helm install redis bitnami/redis \
  --namespace api-marketplace \
  --set auth.password=redispassword
```

#### Step 4: Configure Secrets and ConfigMaps

Create necessary secrets and configuration maps:

```bash
# Create secrets for database credentials
kubectl create secret generic db-credentials \
  --namespace api-marketplace \
  --from-literal=mongodb-password=apimarketplacepassword \
  --from-literal=postgresql-password=apimarketplacepassword \
  --from-literal=redis-password=redispassword

# Create ConfigMap for application configuration
kubectl apply -f kubernetes/configmaps/api-marketplace-config.yaml -n api-marketplace
```

#### Step 5: Deploy API Marketplace Components

Deploy the API Marketplace components using Helm:

```bash
# Add API Marketplace Helm repository
helm repo add cmm-reference https://charts.cmm-reference.org

# Deploy API Marketplace
helm install api-marketplace cmm-reference/api-marketplace \
  --namespace api-marketplace \
  --values kubernetes/values/api-marketplace-values.yaml
```

Alternatively, deploy using individual Kubernetes manifests:

```bash
# Deploy API Marketplace components
kubectl apply -f kubernetes/deployments/ -n api-marketplace
kubectl apply -f kubernetes/services/ -n api-marketplace
kubectl apply -f kubernetes/ingress/ -n api-marketplace
```

#### Step 6: Configure Ingress and TLS

Set up ingress for external access with TLS:

```bash
# Install NGINX Ingress Controller if not already installed
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace

# Apply TLS certificate secret
kubectl create secret tls api-marketplace-tls \
  --namespace api-marketplace \
  --key /path/to/tls.key \
  --cert /path/to/tls.crt

# Apply ingress configuration
kubectl apply -f kubernetes/ingress/api-marketplace-ingress.yaml -n api-marketplace
```

### On-Premises Deployment

#### Step 1: Prepare Servers

Prepare the server environment:

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install required dependencies
sudo apt install -y curl wget git unzip build-essential

# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# Install Docker
curl -fsSL https://get.docker.com | sudo bash
sudo usermod -aG docker $USER
```

#### Step 2: Install and Configure Databases

Install and configure required databases:

```bash
# Install MongoDB
wget -qO - https://www.mongodb.org/static/pgp/server-5.0.asc | sudo apt-key add -
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/5.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-5.0.list
sudo apt update
sudo apt install -y mongodb-org
sudo systemctl enable mongod
sudo systemctl start mongod

# Install PostgreSQL
sudo apt install -y postgresql postgresql-contrib
sudo systemctl enable postgresql
sudo systemctl start postgresql

# Install Redis
sudo apt install -y redis-server
sudo systemctl enable redis-server
sudo systemctl start redis-server
```

#### Step 3: Configure Databases

Configure the databases for API Marketplace:

```bash
# Configure MongoDB
mongo admin --eval 'db.createUser({user: "apimarketplace", pwd: "apimarketplacepassword", roles: [{role: "readWrite", db: "apimarketplace"}]})'

# Configure PostgreSQL
sudo -u postgres psql -c "CREATE USER apimarketplace WITH PASSWORD 'apimarketplacepassword';"
sudo -u postgres psql -c "CREATE DATABASE apimarketplace OWNER apimarketplace;"

# Configure Redis
sudo sed -i 's/# requirepass foobared/requirepass redispassword/' /etc/redis/redis.conf
sudo systemctl restart redis-server
```

#### Step 4: Deploy API Marketplace

Deploy the API Marketplace components:

```bash
# Clone the repository
git clone https://github.com/cmm-reference-architecture/api-marketplace.git
cd api-marketplace

# Install dependencies
npm install

# Build the application
npm run build

# Configure environment variables
cp .env.example .env
# Edit .env file with appropriate configuration

# Start the application
npm run start:prod
```

### Cloud Deployment (AWS Example)

#### Step 1: Set Up AWS Infrastructure

Prepare the AWS infrastructure using Terraform:

```bash
# Initialize Terraform
cd terraform/aws
terraform init

# Plan the deployment
terraform plan -out=api-marketplace.tfplan

# Apply the configuration
terraform apply "api-marketplace.tfplan"
```

#### Step 2: Configure EKS Cluster

Configure the EKS cluster for deployment:

```bash
# Update kubeconfig for EKS cluster
aws eks update-kubeconfig --name api-marketplace-cluster --region us-east-1

# Verify cluster access
kubectl cluster-info
```

#### Step 3: Deploy API Marketplace

Deploy the API Marketplace to EKS using Helm:

```bash
# Add API Marketplace Helm repository
helm repo add cmm-reference https://charts.cmm-reference.org

# Deploy API Marketplace
helm install api-marketplace cmm-reference/api-marketplace \
  --namespace api-marketplace --create-namespace \
  --values terraform/aws/helm-values/api-marketplace-values.yaml
```

## Configuration

### Configuration Files

The API Marketplace uses the following configuration files:

#### Environment Variables

Environment variables can be set in a `.env` file or through the container environment:

```
# Server Configuration
PORT=3000
NODE_ENV=production
API_BASE_URL=https://api-marketplace.example.com

# Database Configuration
MONGODB_URI=mongodb://apimarketplace:apimarketplacepassword@mongodb:27017/apimarketplace
POSTGRES_URI=postgresql://apimarketplace:apimarketplacepassword@postgresql:5432/apimarketplace
REDIS_URI=redis://:redispassword@redis:6379/0

# Authentication Configuration
JWT_SECRET=your-jwt-secret
JWT_EXPIRATION=3600
OAUTH_ENABLED=true
OAUTH_PROVIDER_URL=https://auth.example.com
OAUTH_CLIENT_ID=your-client-id
OAUTH_CLIENT_SECRET=your-client-secret

# Integration Configuration
EVENT_BROKER_URL=https://event-broker.example.com
SECURITY_FRAMEWORK_URL=https://security-framework.example.com
FHIR_PLATFORM_URL=https://fhir-platform.example.com
```

#### Application Configuration

Application-specific configuration in `config/application.yaml`:

```yaml
# API Configuration
api:
  version: 1
  rateLimit:
    enabled: true
    windowMs: 60000
    max: 100
  cors:
    enabled: true
    origins:
      - https://example.com
      - https://portal.example.com

# Feature Flags
features:
  apiAnalytics: true
  apiVersioning: true
  apiLifecycleManagement: true
  apiMonitoring: true

# Security Configuration
security:
  contentSecurityPolicy: true
  xssProtection: true
  frameguard: true
  hsts: true

# Logging Configuration
logging:
  level: info
  format: json
  destination: stdout
```

### Kubernetes ConfigMaps and Secrets

For Kubernetes deployments, configuration is managed through ConfigMaps and Secrets:

```yaml
# api-marketplace-config.yaml (ConfigMap)
apiVersion: v1
kind: ConfigMap
metadata:
  name: api-marketplace-config
  namespace: api-marketplace
data:
  application.yaml: |
    api:
      version: 1
      rateLimit:
        enabled: true
        windowMs: 60000
        max: 100
      cors:
        enabled: true
        origins:
          - https://example.com
          - https://portal.example.com
    features:
      apiAnalytics: true
      apiVersioning: true
      apiLifecycleManagement: true
      apiMonitoring: true
    security:
      contentSecurityPolicy: true
      xssProtection: true
      frameguard: true
      hsts: true
    logging:
      level: info
      format: json
      destination: stdout
```

```yaml
# api-marketplace-secrets.yaml (Secret)
apiVersion: v1
kind: Secret
metadata:
  name: api-marketplace-secrets
  namespace: api-marketplace
type: Opaque
data:
  JWT_SECRET: eW91ci1qd3Qtc2VjcmV0
  OAUTH_CLIENT_ID: eW91ci1jbGllbnQtaWQ=
  OAUTH_CLIENT_SECRET: eW91ci1jbGllbnQtc2VjcmV0
```

## Deployment Verification

### Health Checks

Verify the deployment using health check endpoints:

```bash
# Check API health
curl -X GET https://api-marketplace.example.com/health

# Check detailed component health
curl -X GET https://api-marketplace.example.com/health/details
```

Expected response:

```json
{
  "status": "UP",
  "timestamp": "2023-05-05T12:34:56.789Z",
  "components": {
    "api": {
      "status": "UP"
    },
    "db": {
      "status": "UP",
      "details": {
        "mongodb": "UP",
        "postgresql": "UP",
        "redis": "UP"
      }
    },
    "integrations": {
      "status": "UP",
      "details": {
        "eventBroker": "UP",
        "securityFramework": "UP"
      }
    }
  }
}
```

### Smoke Tests

Run smoke tests to verify core functionality:

```bash
# Run smoke tests
npm run test:smoke
```

Alternatively, manually test key endpoints:

```bash
# Test API discovery endpoint
curl -X GET https://api-marketplace.example.com/api/v1/apis

# Test API registration (requires authentication)
curl -X POST https://api-marketplace.example.com/api/v1/apis \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"Test API","description":"Test API for verification","version":"1.0.0"}'
```

### Kubernetes Verification

Verify Kubernetes resources:

```bash
# Check pod status
kubectl get pods -n api-marketplace

# Check services
kubectl get services -n api-marketplace

# Check ingress
kubectl get ingress -n api-marketplace

# Check logs
kubectl logs deployment/api-marketplace-api -n api-marketplace
```

## Deployment in Different Environments

### Development Environment

For development environments:

- Use minikube or kind for local Kubernetes
- Enable debug logging
- Use development-specific configuration values
- Enable hot reloading for faster development

```bash
# Deploy to development environment
helm install api-marketplace cmm-reference/api-marketplace \
  --namespace api-marketplace \
  --values kubernetes/values/dev-values.yaml
```

### Testing Environment

For testing environments:

- Use isolated infrastructure
- Configure test data and scenarios
- Enable comprehensive logging
- Configure integration with test instances of other components

```bash
# Deploy to testing environment
helm install api-marketplace cmm-reference/api-marketplace \
  --namespace api-marketplace \
  --values kubernetes/values/test-values.yaml
```

### Production Environment

For production environments:

- Use high-availability configuration
- Enable production security controls
- Configure production-grade monitoring
- Set appropriate resource limits and requests

```bash
# Deploy to production environment
helm install api-marketplace cmm-reference/api-marketplace \
  --namespace api-marketplace \
  --values kubernetes/values/prod-values.yaml
```

## High Availability Deployment

### Clustering

For high availability, deploy multiple replicas of stateless components:

```yaml
# High availability configuration in values.yaml
api:
  replicaCount: 3
  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 10
    targetCPUUtilizationPercentage: 70
    targetMemoryUtilizationPercentage: 80

portal:
  replicaCount: 3
  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 10
    targetCPUUtilizationPercentage: 70
    targetMemoryUtilizationPercentage: 80
```

### Load Balancing

Configure load balancing for distributed traffic:

```yaml
# Load balancing configuration in ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-marketplace
  namespace: api-marketplace
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/use-regex: "true"
    nginx.ingress.kubernetes.io/rewrite-target: /$1
    nginx.ingress.kubernetes.io/proxy-body-size: "10m"
    nginx.ingress.kubernetes.io/proxy-buffer-size: "128k"
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "60"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "60"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "60"
spec:
  tls:
  - hosts:
    - api-marketplace.example.com
    secretName: api-marketplace-tls
  rules:
  - host: api-marketplace.example.com
    http:
      paths:
      - path: /api(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: api-marketplace-api
            port:
              number: 80
      - path: /(.*)$
        pathType: Prefix
        backend:
          service:
            name: api-marketplace-portal
            port:
              number: 80
```

### Database High Availability

Configure database replication for high availability:

```bash
# Deploy MongoDB with replication
helm install mongodb bitnami/mongodb \
  --namespace api-marketplace \
  --set architecture=replicaset \
  --set replicaCount=3 \
  --set auth.rootPassword=rootpassword \
  --set auth.username=apimarketplace \
  --set auth.password=apimarketplacepassword \
  --set auth.database=apimarketplace

# Deploy PostgreSQL with replication
helm install postgresql bitnami/postgresql \
  --namespace api-marketplace \
  --set architecture=replication \
  --set replicaCount=3 \
  --set auth.postgresPassword=postgrespassword \
  --set auth.username=apimarketplace \
  --set auth.password=apimarketplacepassword \
  --set auth.database=apimarketplace
```

## Deployment Automation

### CI/CD Integration

Integrate deployment with CI/CD pipelines:

```yaml
# Example GitHub Actions workflow for deployment
name: Deploy API Marketplace

on:
  push:
    branches: [main]
    paths:
      - 'src/**'
      - 'kubernetes/**'
      - '.github/workflows/deploy.yml'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v2

      - name: Set up Kubernetes tools
        uses: azure/setup-kubectl@v1

      - name: Set up Helm
        uses: azure/setup-helm@v1

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - name: Update kubeconfig
        run: aws eks update-kubeconfig --name api-marketplace-cluster --region us-east-1

      - name: Deploy to Kubernetes
        run: |
          helm repo add cmm-reference https://charts.cmm-reference.org
          helm repo update
          helm upgrade --install api-marketplace cmm-reference/api-marketplace \
            --namespace api-marketplace \
            --values kubernetes/values/prod-values.yaml \
            --set image.tag=${GITHUB_SHA::8}
```

### Infrastructure as Code

Manage infrastructure using Terraform:

```hcl
# Example Terraform configuration for AWS EKS cluster
provider "aws" {
  region = "us-east-1"
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "18.0.0"

  cluster_name    = "api-marketplace-cluster"
  cluster_version = "1.24"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    default = {
      min_size     = 3
      max_size     = 10
      desired_size = 3

      instance_types = ["t3.large"]
      capacity_type  = "ON_DEMAND"
    }
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.0.0"

  name = "api-marketplace-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = false
  one_nat_gateway_per_az = true
}
```

## Troubleshooting

### Common Deployment Issues

#### Issue: Pods Stuck in Pending State

**Symptom**: Kubernetes pods remain in the "Pending" state.

**Solution**:

1. Check for resource constraints:

```bash
kubectl describe pod [pod-name] -n api-marketplace
```

2. Verify that the required PVCs are available:

```bash
kubectl get pvc -n api-marketplace
```

3. Check node capacity and taints:

```bash
kubectl get nodes
kubectl describe node [node-name]
```

#### Issue: Database Connection Failures

**Symptom**: Application logs show database connection errors.

**Solution**:

1. Verify database pods are running:

```bash
kubectl get pods -n api-marketplace | grep mongodb
kubectl get pods -n api-marketplace | grep postgresql
```

2. Check database credentials:

```bash
kubectl get secret db-credentials -n api-marketplace -o yaml
```

3. Test database connectivity from within the cluster:

```bash
kubectl run -it --rm --image=mongo:5.0 mongodb-client -n api-marketplace -- mongo mongodb://apimarketplace:apimarketplacepassword@mongodb:27017/apimarketplace
```

#### Issue: Ingress Not Working

**Symptom**: Unable to access the API Marketplace externally.

**Solution**:

1. Verify ingress controller is running:

```bash
kubectl get pods -n ingress-nginx
```

2. Check ingress configuration:

```bash
kubectl get ingress -n api-marketplace
kubectl describe ingress api-marketplace -n api-marketplace
```

3. Verify TLS certificate:

```bash
kubectl get secret api-marketplace-tls -n api-marketplace
```

4. Check ingress controller logs:

```bash
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
```

### Logging and Debugging

Access logs for troubleshooting:

```bash
# API logs
kubectl logs deployment/api-marketplace-api -n api-marketplace

# Portal logs
kubectl logs deployment/api-marketplace-portal -n api-marketplace

# Database logs
kubectl logs statefulset/mongodb -n api-marketplace
kubectl logs statefulset/postgresql -n api-marketplace
```

Enable debug logging by updating the ConfigMap:

```bash
kubectl edit configmap api-marketplace-config -n api-marketplace
```

Update the logging level to "debug":

```yaml
logging:
  level: debug
  format: json
  destination: stdout
```

Restart the pods to apply the changes:

```bash
kubectl rollout restart deployment/api-marketplace-api -n api-marketplace
kubectl rollout restart deployment/api-marketplace-portal -n api-marketplace
```

## Related Documentation

- [Monitoring Guide](./monitoring.md)
- [Scaling Guide](./scaling.md)
- [Maintenance Guide](./maintenance.md)
- [CI/CD Pipeline](./ci-cd-pipeline.md)
- [Architecture Overview](../01-getting-started/architecture.md)
