# Event Broker Key Concepts

This document outlines the fundamental concepts and terminology of the Event Broker core component, which is built on Confluent Kafka.

## Event-Driven Architecture (EDA)

Event-Driven Architecture is a software design pattern where the production, detection, consumption of, and reaction to events drive the system's behavior. In the context of healthcare:

- **Events** represent meaningful changes in state or occurrences within the system (e.g., patient admission, medication order, lab result)
- **Event Producers** generate events when something notable happens
- **Event Consumers** react to events they're interested in
- **Event Broker** (Kafka) serves as the central nervous system connecting producers and consumers

## Apache Kafka Fundamentals

### Topics
Topics are the fundamental organizational unit in Kafka, similar to tables in a database or folders in a file system.

- **Topics** are named channels or feeds of events
- Events in a topic can be read as many times as needed by different consumer groups
- Topics are partitioned for scalability and parallel processing
- Examples: `patient-admissions`, `medication-orders`, `lab-results`

### Partitions
Each topic is divided into partitions, which are the unit of parallelism in Kafka.

- **Partitions** allow horizontal scaling and parallel processing
- Events with the same key go to the same partition (important for ordering)
- Each partition is an ordered, immutable sequence of events
- Partitions are distributed across the Kafka cluster for fault tolerance

### Producers
Producers are applications that publish events to Kafka topics.

- **Producers** determine which topic and partition an event is written to
- Can send events synchronously or asynchronously
- Can specify a key with each event to ensure related events go to the same partition
- Support various serialization formats (JSON, Avro, Protobuf)

### Consumers and Consumer Groups
Consumers read events from topics and process them.

- **Consumers** subscribe to one or more topics
- **Consumer Groups** allow for scalable, fault-tolerant consumption
- Each partition is consumed by only one consumer in a group
- Adding consumers to a group (up to the number of partitions) increases throughput

### Offsets
Offsets are how Kafka tracks which events have been consumed.

- **Offsets** are sequential IDs given to events in a partition
- Consumers commit offsets to track their progress
- Allow consumers to resume from where they left off after a restart
- Enable replay of events from any point in time (within the retention period)

## Schema Registry

The Schema Registry maintains and evolves event schemas, ensuring compatibility.

- **Schemas** define the structure of events (fields, types, etc.)
- Enforces schema compatibility during evolution (backward, forward, or full)
- Supports Avro, JSON Schema, and Protobuf formats
- Prevents breaking changes that could disrupt consumers

## Healthcare Event Patterns

### FHIR-Based Events
The Event Broker standardizes on FHIR for healthcare event payloads.

- Events often contain or reference FHIR resources
- Example: `Patient.create`, `Observation.update`, `MedicationRequest.cancel`
- Enables semantic interoperability across healthcare systems

### Event Sourcing
Event sourcing stores all changes to application state as a sequence of events.

- The event log becomes the authoritative source of truth
- Current state can be reconstructed by replaying events
- Valuable for auditing, compliance, and reconstructing patient journeys

### Command Query Responsibility Segregation (CQRS)
CQRS separates read and write operations for more flexibility and performance.

- **Commands** change state and generate events
- **Queries** read from optimized view models built from events
- Enables specialized data models for different use cases

## Security Concepts

### Authentication and Authorization
Kafka provides robust security mechanisms.

- **Authentication** via SASL (PLAIN, SCRAM, Kerberos) or mTLS
- **Authorization** controls which clients can read/write to which topics
- **ACLs** (Access Control Lists) define fine-grained permissions

### Data Protection
Protecting sensitive healthcare data in transit and at rest.

- **Encryption in Transit** via TLS
- **Encryption at Rest** for stored data
- **Data Masking** for PHI/PII when needed

## Monitoring and Observability

### Metrics
Key metrics to monitor for Kafka health and performance.

- **Broker Metrics**: CPU, memory, disk usage, request rates
- **Producer Metrics**: throughput, error rates, latency
- **Consumer Metrics**: lag, throughput, processing time
- **Topic Metrics**: size, message counts, retention

### Logging and Tracing
Comprehensive logging and distributed tracing.

- **Logs** capture operational events and errors
- **Distributed Tracing** follows events through the system
- **Correlation IDs** link related events across services

## Next Steps
- [Event Broker Overview](./overview.md)
- [Event Broker Quick Start](./quick-start.md)
- [Event Broker Architecture](./architecture.md)
- [Event Schema Design](../03-advanced-topics/event-schema-design.md)
