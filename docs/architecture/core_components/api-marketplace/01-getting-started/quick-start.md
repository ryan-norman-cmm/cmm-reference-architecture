# API Marketplace Quick Start Guide

## Introduction

This guide walks you through the essential steps to set up the API Marketplace for the CMM Technology Platform. The API Marketplace combines F5 Distributed Cloud App Connect for universal ingress, a service mesh for internal communication, and Mulesoft for API integration. This setup guide focuses on the basic installation and configuration needed to get these components up and running in your environment.

## Prerequisites

Before beginning the API Marketplace setup process, ensure you have:

- Administrative access to your cloud environments (AWS, Azure, GCP, or on-premises)
- F5 Distributed Cloud account with appropriate subscription level
- Mulesoft Anypoint Platform account with appropriate licensing
- Kubernetes cluster(s) for service mesh deployment (v1.21+)
- DNS domains for API endpoints and ingress configuration
- TLS certificates for secure communication
- Network connectivity between all environments

## Setup Process

### 1. F5 Distributed Cloud App Connect Setup

F5 Distributed Cloud App Connect provides universal ingress capabilities for the API Marketplace.

#### Basic Installation

1. **Access F5 Distributed Cloud Console**
   ```bash
   # Log in to F5 Distributed Cloud using the CLI
   f5 login --api-token "your-api-token"
   
   # Create and select your tenant
   f5 tenant create --name "healthcare-org" --description "Healthcare Organization"
   f5 tenant select healthcare-org
   ```

2. **Set Up TLS Certificates**
   ```bash
   # Upload your TLS certificate
   f5 certificate create --name "api-cert" \
     --certificate-file /path/to/certificate.pem \
     --private-key-file /path/to/private-key.pem
   ```

#### Configure API Gateway

1. **Create HTTP Load Balancer**
   ```yaml
   # api-gateway.yaml - Apply with: f5 apply -f api-gateway.yaml
   apiVersion: api.volterra.io/v1
   kind: HttpLoadBalancer
   metadata:
     name: healthcare-api-gateway
     namespace: default
   spec:
     domains:
     - "api.healthcare-org.com"
     https_auto_cert:
       add_hsts: true
       http_redirect: true
       no_mtls: {}
     default_route_pools:
     - pool:
         name: backend-pool
         namespace: default
       weight: 1
     routes:
     - match:
         path:
           prefix: /api/v1
       route:
         cors_policy:
           allow_origins:
             - origin: "*"
           allow_methods: ["GET", "POST", "PUT", "DELETE"]
     waf:
       enable: true
       use_default_waf_config: true
   ```

2. **Create Origin Pool**
   ```yaml
   # backend-pool.yaml - Apply with: f5 apply -f backend-pool.yaml
   apiVersion: api.volterra.io/v1
   kind: OriginPool
   metadata:
     name: backend-pool
     namespace: default
   spec:
     origin_servers:
     - k8s_service:
         service_name: backend-service
         site_locator:
           site:
             namespace: system
             name: your-k8s-site
         outside_network: false
     use_tls:
       no_mtls: {}
       skip_server_verification: false
     port: 8080
     healthcheck:
       path: /health
       use_origin_server_name: true
   ```

3. **Verify Configuration**
   ```bash
   # List HTTP load balancers
   f5 get http-loadbalancers
   
   # List origin pools
   f5 get origin-pools
   ```

### 2. Service Mesh Setup

The service mesh provides secure service-to-service communication within the API Marketplace.

#### Basic Installation

1. **Install Istio Service Mesh**
   ```bash
   # Download Istio
   curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.16.1 sh -
   cd istio-1.16.1
   
   # Add istioctl to your path
   export PATH=$PWD/bin:$PATH
   
   # Create namespace for Istio
   kubectl create namespace istio-system
   
   # Install Istio with default profile
   istioctl install --set profile=default -y
   
   # Enable automatic sidecar injection in default namespace
   kubectl label namespace default istio-injection=enabled
   ```

2. **Verify Installation**
   ```bash
   # Check that all Istio components are running
   kubectl get pods -n istio-system
   
   # Verify Istio CRDs are installed
   kubectl get crds | grep istio
   ```

#### Basic Configuration

1. **Create Gateway for External Access**
   ```yaml
   # gateway.yaml - Apply with: kubectl apply -f gateway.yaml
   apiVersion: networking.istio.io/v1alpha3
   kind: Gateway
   metadata:
     name: api-gateway
     namespace: default
   spec:
     selector:
       istio: ingressgateway
     servers:
     - port:
         number: 80
         name: http
         protocol: HTTP
       hosts:
       - "*"
     - port:
         number: 443
         name: https
         protocol: HTTPS
       hosts:
       - "*"
       tls:
         mode: SIMPLE
         credentialName: api-cert # Reference to Kubernetes secret
   ```

2. **Create a Basic Virtual Service**
   ```yaml
   # virtual-service.yaml - Apply with: kubectl apply -f virtual-service.yaml
   apiVersion: networking.istio.io/v1alpha3
   kind: VirtualService
   metadata:
     name: api-routes
     namespace: default
   spec:
     hosts:
     - "*"
     gateways:
     - api-gateway
     http:
     - match:
       - uri:
           prefix: /api/v1/patients
       route:
       - destination:
           host: patient-service
           port:
             number: 8080
     - match:
       - uri:
           prefix: /api/v1/medications
       route:
       - destination:
           host: medication-service
           port:
             number: 8080
   ```

3. **Enable mTLS for Service Communication**
   ```yaml
   # mtls.yaml - Apply with: kubectl apply -f mtls.yaml
   apiVersion: security.istio.io/v1beta1
   kind: PeerAuthentication
   metadata:
     name: default
     namespace: default
   spec:
     mtls:
       mode: STRICT
   ```

4. **Install Basic Monitoring**
   ```bash
   # Install Prometheus, Grafana, and Kiali
   kubectl apply -f istio-1.16.1/samples/addons/prometheus.yaml
   kubectl apply -f istio-1.16.1/samples/addons/grafana.yaml
   kubectl apply -f istio-1.16.1/samples/addons/kiali.yaml
   
   # Access the Kiali dashboard
   istioctl dashboard kiali
   ```

### 3. Mulesoft Anypoint Platform Setup

Mulesoft Anypoint Platform provides API integration capabilities for the API Marketplace.

#### Basic Installation

1. **Access Anypoint Platform**
   ```bash
   # Install Anypoint CLI
   npm install -g anypoint-cli
   
   # Log in to Anypoint Platform
   anypoint-cli login --username your-username --password your-password
   
   # Verify organization access
   anypoint-cli account:organization:list
   ```

2. **Set Up Environments**
   ```bash
   # Create environments
   anypoint-cli account:environment:create "Development" --org "your-org-id"
   anypoint-cli account:environment:create "Production" --org "your-org-id"
   
   # List environments
   anypoint-cli account:environment:list --org "your-org-id"
   ```

#### API Manager Configuration

1. **Create API Project**
   ```bash
   # Create a new Mule project
   anypoint-cli runtime:project:new --artifactId healthcare-api --groupId com.healthcare
   
   # Navigate to the project directory
   cd healthcare-api
   ```

2. **Configure a Basic API**
   ```xml
   <!-- config.xml -->
   <mule xmlns="http://www.mulesoft.org/schema/mule/core"
         xmlns:http="http://www.mulesoft.org/schema/mule/http"
         xmlns:ee="http://www.mulesoft.org/schema/mule/ee/core"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://www.mulesoft.org/schema/mule/core http://www.mulesoft.org/schema/mule/core/current/mule.xsd
                          http://www.mulesoft.org/schema/mule/http http://www.mulesoft.org/schema/mule/http/current/mule-http.xsd
                          http://www.mulesoft.org/schema/mule/ee/core http://www.mulesoft.org/schema/mule/ee/core/current/mule-ee.xsd">
     
     <http:listener-config name="HTTP_Listener_config">
       <http:listener-connection host="0.0.0.0" port="8081" />
     </http:listener-config>
     
     <flow name="patient-api">
       <http:listener config-ref="HTTP_Listener_config" path="/api/patients"/>
       <ee:transform>
         <ee:message>
           <ee:set-payload><![CDATA[
             %dw 2.0
             output application/json
             ---
             [
               {
                 "id": "1",
                 "name": "John Smith",
                 "dateOfBirth": "1980-01-01"
               },
               {
                 "id": "2",
                 "name": "Jane Doe",
                 "dateOfBirth": "1985-05-15"
               }
             ]
           ]]></ee:set-payload>
         </ee:message>
       </ee:transform>
     </flow>
     
   </mule>
   ```

3. **Deploy the API**
   ```bash
   # Package the application
   mvn clean package
   
   # Deploy to CloudHub (Mulesoft's managed runtime)
   anypoint-cli runtime:deploy --artifact target/healthcare-api-1.0.0-SNAPSHOT-mule-application.jar \
     --applicationName healthcare-api \
     --environment Development \
     --runtime 4.4.0 \
     --workers 1 \
     --workerType MICRO
   ```

4. **Register API in API Manager**
   ```bash
   # Create API in API Manager
   anypoint-cli api-mgr:api:create \
     --name "Healthcare API" \
     --version "v1" \
     --asset-id healthcare-api \
     --runtime-version 4.4.0 \
     --implementation-type mule4 \
     --endpoint-uri https://healthcare-api.us-e2.cloudhub.io
   
   # Apply a basic security policy
   anypoint-cli api-mgr:policy:apply \
     --policy-id "client-id-enforcement" \
     --api-id "your-api-id" \
     --config '{"credentialsOrigin":"httpHeader","clientIdExpression":"#[attributes.headers[\"client_id\"]]"}' 
   ```

### 4. Basic Integration Testing

Verify that all components are working together properly.

1. **Test F5 Distributed Cloud Connectivity**
   ```bash
   # Test the API gateway endpoint
   curl -v https://api.healthcare-org.com/api/v1/health
   ```

2. **Test Service Mesh Routing**
   ```bash
   # Deploy a test service
   kubectl apply -f - <<EOF
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: test-service
     labels:
       app: test-service
   spec:
     replicas: 1
     selector:
       matchLabels:
         app: test-service
     template:
       metadata:
         labels:
           app: test-service
       spec:
         containers:
         - name: test-service
           image: hashicorp/http-echo
           args:
             - "-text=hello from test service"
           ports:
             - containerPort: 5678
   ---
   apiVersion: v1
   kind: Service
   metadata:
     name: test-service
   spec:
     selector:
       app: test-service
     ports:
     - port: 8080
       targetPort: 5678
   EOF
   
   # Create a virtual service for the test service
   kubectl apply -f - <<EOF
   apiVersion: networking.istio.io/v1alpha3
   kind: VirtualService
   metadata:
     name: test-service-route
   spec:
     hosts:
     - "*"
     gateways:
     - api-gateway
     http:
     - match:
       - uri:
           prefix: /test
       route:
       - destination:
           host: test-service
           port:
             number: 8080
   EOF
   
   # Test the route
   curl -v https://api.healthcare-org.com/test
   ```

3. **Test Mulesoft API**
   ```bash
   # Test the Mulesoft API
   curl -v https://healthcare-api.us-e2.cloudhub.io/api/patients
   ```

## Troubleshooting

### Common Issues and Solutions

1. **F5 Distributed Cloud Connectivity Issues**
   ```bash
   # Check F5 Distributed Cloud status
   f5 status
   
   # Verify HTTP Load Balancer configuration
   f5 get http-loadbalancers healthcare-api-gateway -o yaml
   
   # Test endpoint connectivity
   curl -v https://api.healthcare-org.com/health
   ```

2. **Service Mesh Issues**
   ```bash
   # Check Istio components
   kubectl get pods -n istio-system
   
   # Verify virtual service configuration
   kubectl get virtualservices -o yaml
   
   # Check service mesh proxy logs
   kubectl logs deployment/your-service -c istio-proxy
   ```

3. **Mulesoft Connectivity Issues**
   ```bash
   # Check Mulesoft application status
   anypoint-cli runtime:application:describe healthcare-api
   
   # View application logs
   anypoint-cli runtime:application:logs healthcare-api
   
   # Test API connectivity
   curl -v https://healthcare-api.us-e2.cloudhub.io/api/patients
   ```

## Next Steps

Now that you have completed the basic setup of the API Marketplace, you can:

1. Configure additional API endpoints and services
2. Implement advanced security policies
3. Set up monitoring and alerting
4. Integrate with the Security and Access Framework
5. Explore advanced service mesh patterns

Refer to the following documentation for more detailed information:

- [F5 Distributed Cloud Configuration](../02-core-functionality/f5-distributed-cloud-configuration.md)
- [Service Mesh Implementation](../02-core-functionality/service-mesh-implementation.md)
- [Mulesoft Integration Patterns](../02-core-functionality/mulesoft-integration-patterns.md)
- [API Governance Framework](../03-advanced-patterns/api-governance-framework.md)

## Resources

- [F5 Distributed Cloud Documentation](https://docs.cloud.f5.com/docs/)
- [Istio Service Mesh Documentation](https://istio.io/latest/docs/)
- [Mulesoft Anypoint Platform Documentation](https://docs.mulesoft.com/)
- [Healthcare API Best Practices](https://www.hl7.org/fhir/implementationguide.html)
- [OWASP API Security Top 10](https://owasp.org/www-project-api-security/)
