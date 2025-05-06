# Event Broker Quick Start Guide

## Introduction

This guide walks you through the process of setting up the Event Broker for the CMM Technology Platform. It covers the installation and configuration of Confluent Kafka, the implementation of healthcare-specific event schemas, and the integration with other core components. By following these steps, you'll establish a robust foundation for event-driven healthcare applications that enable real-time data exchange and workflow automation.

The setup process is organized into logical sections that progress from basic infrastructure setup to advanced configuration. Each section builds upon the previous ones, allowing for incremental implementation and testing. While this guide provides a comprehensive approach, you can adapt it to your specific environment and requirements.

## Prerequisites

Before beginning the Event Broker setup process, ensure you have:

### Hardware Requirements

- **Development Environment**:
  - Minimum: 3 servers (16GB RAM, 4 vCPUs, 100GB SSD each)
  - Recommended: 5 servers (32GB RAM, 8 vCPUs, 250GB SSD each)

- **Production Environment**:
  - Minimum: 5 servers (32GB RAM, 8 vCPUs, 500GB SSD each)
  - Recommended: 9+ servers (64GB RAM, 16 vCPUs, 1TB SSD each)
  - Network: 10 Gbps between broker nodes

### Software Requirements

- **Operating System**: Linux (RHEL 8+, Ubuntu 20.04+, or similar)
- **Java**: OpenJDK 11 or later
- **Confluent Platform**: Version 7.0 or later
- **Docker**: Version 20.10 or later (for containerized deployment)
- **Kubernetes**: Version 1.21 or later (for cloud-native deployment)

## Quick Setup with Docker Compose

For a quick development setup, use Docker Compose:

1. **Create Docker Compose File**
   
   Create `docker-compose.yml`:
   ```yaml
   ---
   version: '3'
   services:
     zookeeper:
       image: confluentinc/cp-zookeeper:7.0.1
       hostname: zookeeper
       container_name: zookeeper
       ports:
         - "2181:2181"
       environment:
         ZOOKEEPER_CLIENT_PORT: 2181
         ZOOKEEPER_TICK_TIME: 2000
       volumes:
         - ./data/zookeeper/data:/var/lib/zookeeper/data
         - ./data/zookeeper/log:/var/lib/zookeeper/log
       healthcheck:
         test: ["CMD", "bash", "-c", "echo ruok | nc localhost 2181 | grep imok"]
         interval: 10s
         timeout: 5s
         retries: 5
   
     broker1:
       image: confluentinc/cp-server:7.0.1
       hostname: broker1
       container_name: broker1
       depends_on:
         - zookeeper
       ports:
         - "9092:9092"
         - "9101:9101"
       environment:
         KAFKA_BROKER_ID: 1
         KAFKA_ZOOKEEPER_CONNECT: 'zookeeper:2181'
         KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT
         KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://broker1:29092,PLAINTEXT_HOST://localhost:9092
         KAFKA_METRIC_REPORTERS: io.confluent.metrics.reporter.ConfluentMetricsReporter
         KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
         KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS: 0
         KAFKA_CONFLUENT_LICENSE_TOPIC_REPLICATION_FACTOR: 1
         KAFKA_CONFLUENT_BALANCER_TOPIC_REPLICATION_FACTOR: 1
         KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: 1
         KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: 1
         KAFKA_JMX_PORT: 9101
         KAFKA_JMX_HOSTNAME: localhost
         CONFLUENT_METRICS_REPORTER_BOOTSTRAP_SERVERS: broker1:29092
         CONFLUENT_METRICS_REPORTER_TOPIC_REPLICAS: 1
         CONFLUENT_METRICS_ENABLE: 'true'
         CONFLUENT_SUPPORT_CUSTOMER_ID: 'anonymous'
       volumes:
         - ./data/broker1/data:/var/lib/kafka/data
   
     schema-registry:
       image: confluentinc/cp-schema-registry:7.0.1
       hostname: schema-registry
       container_name: schema-registry
       depends_on:
         - broker1
       ports:
         - "8081:8081"
       environment:
         SCHEMA_REGISTRY_HOST_NAME: schema-registry
         SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS: 'broker1:29092'
         SCHEMA_REGISTRY_LISTENERS: http://0.0.0.0:8081
   
     control-center:
       image: confluentinc/cp-enterprise-control-center:7.0.1
       hostname: control-center
       container_name: control-center
       depends_on:
         - broker1
         - schema-registry
       ports:
         - "9021:9021"
       environment:
         CONTROL_CENTER_BOOTSTRAP_SERVERS: 'broker1:29092'
         CONTROL_CENTER_SCHEMA_REGISTRY_URL: "http://schema-registry:8081"
         CONTROL_CENTER_REPLICATION_FACTOR: 1
         CONTROL_CENTER_INTERNAL_TOPICS_PARTITIONS: 1
         CONTROL_CENTER_MONITORING_INTERCEPTOR_TOPIC_PARTITIONS: 1
         CONFLUENT_METRICS_TOPIC_REPLICATION: 1
         PORT: 9021
   ```

2. **Start the Environment**
   ```bash
   # Create data directories
   mkdir -p data/zookeeper/data data/zookeeper/log data/broker1/data
   
   # Start the containers
   docker-compose up -d
   ```

3. **Verify the Setup**
   ```bash
   # Check container status
   docker-compose ps
   
   # Access Control Center UI
   # Open http://localhost:9021 in your browser
   ```

## Create Basic Healthcare Topics

1. **Create Healthcare Domain Topics**
   ```bash
   # Create a shell in the broker container
   docker-compose exec broker1 bash
   
   # Create clinical events topic
   kafka-topics --create --topic clinical-events \
     --bootstrap-server localhost:9092 \
     --partitions 8 --replication-factor 1 \
     --config retention.ms=604800000
   
   # Create patient demographics topic
   kafka-topics --create --topic patient-demographics \
     --bootstrap-server localhost:9092 \
     --partitions 4 --replication-factor 1 \
     --config retention.ms=1209600000 \
     --config cleanup.policy=compact
   ```

2. **Verify Topic Creation**
   ```bash
   # List all topics
   kafka-topics --list --bootstrap-server localhost:9092
   
   # Describe a specific topic
   kafka-topics --describe --topic clinical-events \
     --bootstrap-server localhost:9092
   ```

## Register a Sample Schema

1. **Create a Sample AVRO Schema**
   ```bash
   # Create a file called patient-schema.json
   cat > patient-schema.json << 'EOF'
   {
     "type": "record",
     "name": "Patient",
     "namespace": "com.healthcare.events",
     "fields": [
       {"name": "patientId", "type": "string"},
       {"name": "firstName", "type": "string"},
       {"name": "lastName", "type": "string"},
       {"name": "dateOfBirth", "type": "string"},
       {"name": "gender", "type": ["null", "string"], "default": null},
       {"name": "mrn", "type": "string"},
       {"name": "timestamp", "type": "long"}
     ]
   }
   EOF
   ```

2. **Register the Schema**
   ```bash
   # Register the schema with the Schema Registry
   curl -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" \
     --data @patient-schema.json \
     http://localhost:8081/subjects/patient-demographics-value/versions
   ```

## Next Steps

Now that you have completed the basic setup of your Event Broker, you can:

1. Review the [Event Schemas](../02-core-functionality/event-schemas.md) documentation for healthcare data modeling
2. Explore [Stream Processing](../03-advanced-patterns/stream-processing.md) for real-time data transformation
3. Learn about [Connectors](../02-core-functionality/connectors.md) for integrating with healthcare systems

## Troubleshooting

### Common Issues

1. **Connection Problems**
   - Verify network connectivity between clients and brokers
   - Check firewall rules for required ports (9092, 2181, 8081)
   - Ensure DNS resolution is working correctly

2. **Authentication Failures**
   - Verify credentials in client configuration
   - Check that JAAS configuration is correct
   - Ensure SSL certificates are valid and trusted

### Diagnostic Commands

```bash
# Check container logs
docker-compose logs broker1

# Test producer functionality
docker-compose exec broker1 kafka-console-producer \
  --bootstrap-server localhost:9092 \
  --topic test-topic

# Test consumer functionality
docker-compose exec broker1 kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic test-topic --from-beginning
```

## Resources

- [Confluent Kafka Documentation](https://docs.confluent.io/)
- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [Kafka Monitoring Tools](https://docs.confluent.io/platform/current/control-center/index.html)
