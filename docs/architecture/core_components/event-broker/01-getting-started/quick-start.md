# Event Broker Quick Start

This guide provides a step-by-step process to help you quickly get started with the Event Broker core component.

## Prerequisites
- Access to the CMM platform environment (development, staging, or production)
- Provisioned credentials for the Event Broker (Kafka username/password or certificates)
- Network access to the Event Broker endpoints
- Familiarity with Apache Kafka concepts (topics, producers, consumers)


## Step 1: Reference Confluent Kafka Quick Start

> **Recommended:** Follow the official Confluent Kafka quick start guide for setup and local development: [Confluent Kafka Quick Start (Official Docs)](https://docs.confluent.io/platform/current/quickstart/ce-docker-quickstart.html)

### Summary of Steps:
1. **Install Docker**: Download and install Docker Desktop from [https://www.docker.com/products/docker-desktop/](https://www.docker.com/products/docker-desktop/).
2. **Download and Start Confluent Platform**: Use the official Docker Compose file provided in the [Confluent quick start](https://docs.confluent.io/platform/current/quickstart/ce-docker-quickstart.html#step-1-download-and-start-cp).
3. **Set Environment Variables**: Configure any required environment variables as described in the vendor documentation.
4. **Start the Platform**: Run `docker-compose up -d` to start all required Kafka services (Zookeeper, Broker, Schema Registry, etc.).
5. **Access the Control Center**: By default, Confluent Control Center is available at [http://localhost:9021](http://localhost:9021).

For troubleshooting, advanced configuration, and more, refer to the [official Confluent quick start guide](https://docs.confluent.io/platform/current/quickstart/ce-docker-quickstart.html).
## Step 2: Connect to the Event Broker

Refer to the [Confluent Kafka quick start guide](https://docs.confluent.io/platform/current/quickstart/ce-docker-quickstart.html#step-3-produce-and-consume-events) for producing and consuming events using the Confluent CLI, REST Proxy, or your preferred client library (Java, Python, Node.js, etc.).

The guide provides step-by-step instructions and code samples for each supported language and tool.
## Step 3: Publish and Consume Events

Below is a TypeScript example using the official KafkaJS client, following Confluent's best practices. For more details and language options, see the [official Confluent Kafka quick start](https://docs.confluent.io/platform/current/quickstart/ce-docker-quickstart.html#step-3-produce-and-consume-events).

### Produce an Event
```typescript
import { Kafka } from 'kafkajs';

const kafka = new Kafka({
  clientId: 'my-app',
  brokers: ['localhost:9092'],
});

const producer = kafka.producer();

async function produce() {
  await producer.connect();
  await producer.send({
    topic: 'test-topic',
    messages: [
      { key: 'key1', value: 'Hello from KafkaJS!' },
    ],
  });
  await producer.disconnect();
}

produce().catch(console.error);
```

### Consume Events
```typescript
import { Kafka } from 'kafkajs';

const kafka = new Kafka({
  clientId: 'my-app',
  brokers: ['localhost:9092'],
});

const consumer = kafka.consumer({ groupId: 'test-group' });

async function consume() {
  await consumer.connect();
  await consumer.subscribe({ topic: 'test-topic', fromBeginning: true });
  await consumer.run({
    eachMessage: async ({ topic, partition, message }) => {
      console.log({
        partition,
        offset: message.offset,
        value: message.value?.toString(),
      });
    },
  });
}

consume().catch(console.error);
```

For CLI, REST Proxy, or other language examples, refer to the [official Confluent Kafka quick start](https://docs.confluent.io/platform/current/quickstart/ce-docker-quickstart.html#step-3-produce-and-consume-events).
## Step 4: Validate Setup
- Ensure you can produce and consume events without errors using your client, the Confluent CLI, or integration tests.
- Access the Confluent Control Center UI at [http://localhost:9021](http://localhost:9021) (or your configured endpoint) and log in with your credentials.
- In the Control Center, navigate to your Kafka cluster and view the "Topics" and "Consumers" sections to verify that your test messages appear and that consumers are active.
- Use the Control Center's monitoring and log features to check for errors or performance issues.
- Troubleshoot connection, authentication, or configuration issues by verifying credentials, network access, and reviewing the [Confluent troubleshooting documentation](https://docs.confluent.io/platform/current/kafka/multi-node.html#troubleshooting).

## Next Steps
- [Explore Schema Registry & Advanced Kafka Features](../03-advanced-topics/schema-registry.md)
- [Integration Guide: FHIR Interoperability Platform](../../fhir-interoperability-platform/01-getting-started/quick-start.md)
- [Integration Guide: Federated Graph API](../../federated-graph-api/01-getting-started/quick-start.md)
- [Integration Guide: API Marketplace](../../api-marketplace/01-getting-started/quick-start.md)
- [Best Practices: Event Schema Design](../03-advanced-topics/event-schema-design.md)
- [Error Handling & Troubleshooting](../03-advanced-topics/error-handling.md)

## Related Resources
- [Confluent Kafka Documentation](https://docs.confluent.io/platform/current/clients/index.html)
- [Event Broker Overview](./overview.md)
- [Event Broker Architecture](./architecture.md)
- [Event Broker Key Concepts](./key-concepts.md)
