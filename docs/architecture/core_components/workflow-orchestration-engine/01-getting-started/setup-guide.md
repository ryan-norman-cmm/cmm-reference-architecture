# Workflow Orchestration Engine Setup Guide

## Introduction

This guide will walk you through setting up the Workflow Orchestration Engine with TypeScript and cloud-native technologies. By following these steps, you'll have a fully functional development environment for creating, testing, and deploying healthcare workflows.

## Prerequisites

Before you begin, ensure you have the following installed:

- **Node.js** (v16 or later)
- **npm** (v7 or later)
- **Docker** and **Docker Compose**
- **Kubernetes CLI** (kubectl)
- **TypeScript** (v4.5 or later)
- **Git**

## Development Environment Setup

### 1. Clone the Repository

```bash
git clone https://github.com/cmm-technology-platform/workflow-orchestration-engine.git
cd workflow-orchestration-engine
```

### 2. Install Dependencies

```bash
npm install
```

This will install all required dependencies, including:

- `@temporalio/client`: Temporal.io client library
- `@temporalio/worker`: Temporal.io worker library
- `@temporalio/workflow`: Temporal.io workflow library
- `@nestjs/core`: NestJS core library for the rules engine
- `@cmm/event-broker`: CMM Event Broker TypeScript SDK
- `@cmm/fhir-client`: CMM FHIR Client TypeScript SDK
- `opentelemetry`: OpenTelemetry instrumentation libraries

### 3. Configure Environment Variables

Create a `.env` file in the root directory with the following variables:

```
# Temporal.io Configuration
TEMPORAL_ADDRESS=localhost:7233
TEMPORAL_NAMESPACE=default

# Event Broker Configuration
EVENT_BROKER_BOOTSTRAP_SERVERS=localhost:9092
EVENT_BROKER_SCHEMA_REGISTRY_URL=http://localhost:8081

# FHIR Server Configuration
FHIR_SERVER_BASE_URL=http://localhost:8080/fhir/r4

# Rules Engine Configuration
RULES_ENGINE_PORT=3001

# Observability Configuration
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
```

### 4. Start Local Development Services

Use Docker Compose to start the required services for local development:

```bash
docker-compose -f docker-compose.dev.yml up -d
```

This will start:

- Temporal.io server
- Confluent Kafka and Schema Registry
- FHIR server
- OpenTelemetry collector

### 5. Build the TypeScript Project

```bash
npm run build
```

## Project Structure

The project follows a modular structure optimized for TypeScript development:

```
workflow-orchestration-engine/
├── src/
│   ├── workflows/           # Temporal workflow definitions
│   │   ├── healthcare/      # Healthcare-specific workflows
│   │   └── common/          # Common workflow patterns
│   ├── activities/          # Activity implementations
│   │   ├── fhir/            # FHIR-related activities
│   │   ├── events/          # Event broker activities
│   │   └── services/        # External service activities
│   ├── rules/               # NestJS rules engine
│   │   ├── modules/         # Rule modules
│   │   ├── providers/       # Rule providers
│   │   └── controllers/     # Rule API controllers
│   ├── models/              # TypeScript type definitions
│   │   ├── fhir/            # FHIR resource types
│   │   ├── events/          # Event schemas
│   │   └── workflows/       # Workflow input/output types
│   ├── services/            # Shared services
│   │   ├── fhir/            # FHIR integration services
│   │   ├── events/          # Event broker services
│   │   └── telemetry/       # Observability services
│   ├── workers/             # Temporal worker definitions
│   └── clients/             # Client applications
├── kubernetes/              # Kubernetes manifests
├── docker/                  # Docker configurations
├── tests/                   # Test suite
│   ├── unit/                # Unit tests
│   ├── integration/         # Integration tests
│   └── e2e/                 # End-to-end tests
└── examples/                # Example implementations
    ├── prior-auth/          # Prior authorization workflow
    └── care-management/     # Care management workflow
```

## Running the Workflow Worker

Start the Temporal worker to process workflows:

```bash
npm run worker
```

This will start a worker that connects to the Temporal server and executes workflow and activity code.

## Running the Rules Engine

Start the NestJS rules engine:

```bash
npm run rules-engine
```

This will start the rules engine service on the configured port (default: 3001).

## Executing a Workflow

You can execute a workflow using the provided client application:

```bash
npm run workflow:execute -- --workflow PriorAuthorizationWorkflow --id test-workflow-1 --input '{"patientId":"123","providerId":"456","serviceType":"MRI"}'
```

Or programmatically from your TypeScript code:

```typescript
import { Client } from '@temporalio/client';
import { PriorAuthorizationWorkflow } from './src/workflows/healthcare/prior-authorization';
import { PriorAuthRequest } from './src/models/workflows/prior-auth-types';

async function runWorkflow() {
  const client = new Client();
  
  const request: PriorAuthRequest = {
    id: 'request-123',
    patientId: '123',
    providerId: '456',
    serviceType: 'MRI',
    insuranceInfo: {
      payerId: 'BCBS',
      memberId: 'MEM123',
      groupNumber: 'GRP456'
    }
  };
  
  const result = await client.workflow.execute(PriorAuthorizationWorkflow, {
    args: [request],
    taskQueue: 'healthcare-workflows',
    workflowId: `prior-auth-${request.id}`,
  });
  
  console.log('Workflow result:', result);
}

runWorkflow().catch(err => {
  console.error('Workflow execution failed:', err);
  process.exit(1);
});
```

## Monitoring Workflows

### Temporal Web UI

Access the Temporal Web UI at http://localhost:8088 to monitor and debug workflows.

### OpenTelemetry Dashboards

Access the OpenTelemetry-based dashboards at http://localhost:3000 to view metrics, traces, and logs.

## Deployment to Kubernetes

### 1. Build and Push Docker Images

```bash
# Build the images
docker build -t cmm/workflow-worker:latest -f docker/worker.Dockerfile .
docker build -t cmm/rules-engine:latest -f docker/rules-engine.Dockerfile .

# Push to your container registry
docker tag cmm/workflow-worker:latest your-registry/cmm/workflow-worker:latest
docker tag cmm/rules-engine:latest your-registry/cmm/rules-engine:latest
docker push your-registry/cmm/workflow-worker:latest
docker push your-registry/cmm/rules-engine:latest
```

### 2. Deploy to Kubernetes

```bash
# Apply Kubernetes manifests
kubectl apply -f kubernetes/namespace.yaml
kubectl apply -f kubernetes/configmap.yaml
kubectl apply -f kubernetes/secrets.yaml
kubectl apply -f kubernetes/workflow-worker.yaml
kubectl apply -f kubernetes/rules-engine.yaml
kubectl apply -f kubernetes/service.yaml
```

## Configuration Options

### Temporal.io Configuration

You can configure Temporal.io settings in `config/temporal.ts`:

```typescript
export const temporalConfig = {
  address: process.env.TEMPORAL_ADDRESS || 'localhost:7233',
  namespace: process.env.TEMPORAL_NAMESPACE || 'default',
  taskQueue: process.env.TEMPORAL_TASK_QUEUE || 'healthcare-workflows',
  workflowRetentionDays: parseInt(process.env.WORKFLOW_RETENTION_DAYS || '30'),
  connectionOptions: {
    tls: process.env.TEMPORAL_TLS_ENABLED === 'true' ? {
      clientCertPair: {
        crt: process.env.TEMPORAL_CLIENT_CERT || '',
        key: process.env.TEMPORAL_CLIENT_KEY || '',
      },
      serverNameOverride: process.env.TEMPORAL_SERVER_NAME_OVERRIDE,
      serverRootCACertificate: process.env.TEMPORAL_SERVER_ROOT_CA_CERT || '',
    } : undefined,
  },
};
```

### Event Broker Configuration

Configure Event Broker settings in `config/event-broker.ts`:

```typescript
export const eventBrokerConfig = {
  bootstrapServers: (process.env.EVENT_BROKER_BOOTSTRAP_SERVERS || 'localhost:9092').split(','),
  schemaRegistryUrl: process.env.EVENT_BROKER_SCHEMA_REGISTRY_URL || 'http://localhost:8081',
  clientId: process.env.EVENT_BROKER_CLIENT_ID || 'workflow-orchestration-engine',
  consumerGroupId: process.env.EVENT_BROKER_CONSUMER_GROUP_ID || 'workflow-orchestration-consumers',
  securityProtocol: process.env.EVENT_BROKER_SECURITY_PROTOCOL as 'PLAINTEXT' | 'SSL' | 'SASL_PLAINTEXT' | 'SASL_SSL' || 'PLAINTEXT',
  saslMechanism: process.env.EVENT_BROKER_SASL_MECHANISM as 'PLAIN' | 'SCRAM-SHA-256' | 'SCRAM-SHA-512' || 'PLAIN',
  saslUsername: process.env.EVENT_BROKER_SASL_USERNAME,
  saslPassword: process.env.EVENT_BROKER_SASL_PASSWORD,
};
```

## Troubleshooting

### Common Issues

#### Temporal Connection Issues

If you're having trouble connecting to the Temporal server:

```bash
# Check if Temporal server is running
docker ps | grep temporal

# Check Temporal server logs
docker logs temporal

# Ensure your TEMPORAL_ADDRESS environment variable is correct
echo $TEMPORAL_ADDRESS
```

#### TypeScript Compilation Errors

If you encounter TypeScript compilation errors:

```bash
# Clean the build directory
npm run clean

# Check TypeScript version
npx tsc --version

# Run TypeScript compiler with verbose output
npx tsc --verbose
```

#### Workflow Execution Failures

If workflows are failing to execute:

1. Check the Temporal Web UI for workflow execution details
2. Examine worker logs for activity failures
3. Verify that all required services (FHIR server, Event Broker) are accessible

## Next Steps

Now that you have set up the Workflow Orchestration Engine, you can:

1. Explore the [Temporal Workflow Orchestration](../02-core-functionality/temporal-workflow-orchestration.md) documentation
2. Learn about the [NestJS Rules Engine](../02-core-functionality/nestjs-rules-engine.md)
3. Understand [Event Integration](../02-core-functionality/event-integration.md) patterns
4. Review the [Prior Authorization](../04-healthcare-integration/prior-authorization.md) example workflow

## Support and Resources

- **GitHub Repository**: [cmm-technology-platform/workflow-orchestration-engine](https://github.com/cmm-technology-platform/workflow-orchestration-engine)
- **Documentation**: [CMM Technology Platform Documentation](https://docs.cmm-technology-platform.org)
- **Temporal.io Documentation**: [Temporal.io Docs](https://docs.temporal.io)
- **NestJS Documentation**: [NestJS Docs](https://docs.nestjs.com)
