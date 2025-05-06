# Event Broker Integration Points

## Introduction

This document outlines the integration points between the Event Broker and other components of the CMM Technology Platform. The Event Broker serves as the central nervous system for real-time data exchange, enabling event-driven communication between various healthcare systems and components. Understanding these integration points is essential for building cohesive, interoperable healthcare applications.

## Core Component Integrations

### FHIR Interoperability Platform Integration

The Event Broker integrates with the FHIR Interoperability Platform to enable event-driven FHIR workflows:

#### FHIR Resource Change Events

```mermaid
sequenceDiagram
    participant FHIR as FHIR Server
    participant Connect as Kafka Connect
    participant Broker as Event Broker
    participant Consumer as Event Consumer
    
    FHIR->>Connect: FHIR Resource Change
    Connect->>Broker: Publish Event
    Broker->>Consumer: Consume Event
    Consumer->>FHIR: Query Additional Context
```

- **Event Types**: Resource created, updated, deleted
- **Topic Pattern**: `fhir.<resource-type>.<operation>`
- **Example Topics**:
  - `fhir.patient.created`
  - `fhir.observation.updated`
  - `fhir.medicationrequest.deleted`

#### FHIR Subscription Implementation

The Event Broker powers the FHIR Subscription capability:

```mermaid
sequenceDiagram
    participant Client as FHIR Client
    participant FHIR as FHIR Server
    participant Broker as Event Broker
    participant Processor as Subscription Processor
    participant Endpoint as Subscription Endpoint
    
    Client->>FHIR: Create Subscription
    FHIR->>Broker: Register Subscription
    Note over FHIR,Broker: Topic: fhir.subscriptions
    Client->>FHIR: Update Resource
    FHIR->>Broker: Publish Resource Change
    Note over FHIR,Broker: Topic: fhir.resource.changed
    Broker->>Processor: Consume Change Event
    Processor->>FHIR: Check Subscription Criteria
    Processor->>Endpoint: Deliver Notification
```

- **Subscription Types**: REST Hook, Websocket, Email, SMS
- **Topic Pattern**: `fhir.subscription.<channel-type>`
- **Example Topics**:
  - `fhir.subscription.rest-hook`
  - `fhir.subscription.websocket`

#### FHIR Bulk Data Operations

The Event Broker facilitates FHIR bulk data operations:

```mermaid
sequenceDiagram
    participant Client as FHIR Client
    participant FHIR as FHIR Server
    participant Broker as Event Broker
    participant Processor as Bulk Processor
    participant Storage as Bulk Storage
    
    Client->>FHIR: Request Bulk Export
    FHIR->>Broker: Publish Bulk Request
    Note over FHIR,Broker: Topic: fhir.bulk.requests
    Broker->>Processor: Consume Bulk Request
    Processor->>FHIR: Extract Resources
    Processor->>Storage: Store Bulk Data
    Processor->>Broker: Publish Completion Event
    Note over Processor,Broker: Topic: fhir.bulk.completions
    Broker->>FHIR: Consume Completion Event
    FHIR->>Client: Notify Completion
```

- **Bulk Operation Types**: Export, Import
- **Topic Pattern**: `fhir.bulk.<operation>`
- **Example Topics**:
  - `fhir.bulk.export-requests`
  - `fhir.bulk.export-completions`
  - `fhir.bulk.import-requests`

### Security and Access Framework Integration

The Event Broker integrates with the Security and Access Framework for authentication, authorization, and audit:

#### Authentication Integration

```mermaid
sequenceDiagram
    participant Client as Kafka Client
    participant Security as Security Framework
    participant Broker as Event Broker
    
    Client->>Security: Authentication Request
    Security->>Client: Authentication Token
    Client->>Broker: Request with Token
    Broker->>Security: Validate Token
    Security->>Broker: Token Validation Result
    Broker->>Client: Response
```

- **Authentication Methods**: SASL/PLAIN, SASL/SCRAM, SASL/OAUTHBEARER, mTLS
- **Integration Point**: Kafka client authentication
- **Configuration**: JAAS configuration for Kafka brokers and clients

#### Authorization Integration

```mermaid
sequenceDiagram
    participant Client as Kafka Client
    participant Broker as Event Broker
    participant Authorizer as Kafka Authorizer
    participant Security as Security Framework
    
    Client->>Broker: Operation Request
    Broker->>Authorizer: Check Authorization
    Authorizer->>Security: Query Permissions
    Security->>Authorizer: Permission Result
    Authorizer->>Broker: Authorization Decision
    Broker->>Client: Response
```

- **Authorization Model**: Role-Based Access Control (RBAC)
- **Resource Types**: Topics, Consumer Groups, Transactional IDs
- **Operations**: Read, Write, Create, Delete, Describe, Alter
- **Integration Point**: Custom authorizer plugin

#### Audit Integration

```mermaid
sequenceDiagram
    participant Client as Kafka Client
    participant Broker as Event Broker
    participant Interceptor as Audit Interceptor
    participant Audit as Audit Topic
    participant Security as Security Framework
    
    Client->>Broker: Operation Request
    Broker->>Interceptor: Intercept Operation
    Interceptor->>Audit: Publish Audit Event
    Audit->>Security: Consume Audit Event
    Security->>Security: Store Audit Record
```

- **Audit Event Types**: Authentication, Authorization, Data Access
- **Topic Pattern**: `security.audit.<event-type>`
- **Example Topics**:
  - `security.audit.authentication`
  - `security.audit.authorization`
  - `security.audit.data-access`

### API Marketplace Integration

The Event Broker integrates with the API Marketplace to expose event streams as APIs:

#### Event API Gateway

```mermaid
sequenceDiagram
    participant Client as API Client
    participant Gateway as API Gateway
    participant REST as Kafka REST Proxy
    participant Broker as Event Broker
    
    Client->>Gateway: API Request
    Gateway->>REST: Transformed Request
    REST->>Broker: Kafka Request
    Broker->>REST: Kafka Response
    REST->>Gateway: Transformed Response
    Gateway->>Client: API Response
```

- **API Types**: REST, GraphQL, WebSocket
- **Integration Point**: Kafka REST Proxy behind API Gateway
- **Authentication**: API Gateway handles authentication

#### Event-Driven API Documentation

```mermaid
sequenceDiagram
    participant Developer as API Developer
    participant Portal as API Portal
    participant Registry as Schema Registry
    participant Broker as Event Broker
    
    Developer->>Portal: Browse Event APIs
    Portal->>Registry: Query Schemas
    Registry->>Portal: Schema Definitions
    Portal->>Developer: Display API Documentation
    Developer->>Portal: Subscribe to Event API
    Portal->>Broker: Create ACL Entries
```

- **Documentation Sources**: Schema Registry, Topic Metadata
- **Integration Point**: Schema Registry API
- **Documentation Format**: AsyncAPI, OpenAPI

#### Event API Analytics

```mermaid
sequenceDiagram
    participant Client as API Client
    participant Gateway as API Gateway
    participant Broker as Event Broker
    participant Analytics as Analytics Platform
    
    Client->>Gateway: API Request
    Gateway->>Broker: Event Operation
    Gateway->>Analytics: Usage Metrics
    Analytics->>Analytics: Process Metrics
```

- **Metric Types**: Throughput, Latency, Error Rate
- **Integration Point**: API Gateway metrics collection
- **Reporting**: API Marketplace analytics dashboard

### Workflow Orchestration Engine Integration

The Event Broker integrates with the Workflow Orchestration Engine to enable event-driven workflows:

#### Workflow Triggers

```mermaid
sequenceDiagram
    participant Source as Event Source
    participant Broker as Event Broker
    participant Listener as Event Listener
    participant Workflow as Workflow Engine
    
    Source->>Broker: Publish Event
    Broker->>Listener: Consume Event
    Listener->>Workflow: Trigger Workflow
    Workflow->>Workflow: Execute Workflow
```

- **Trigger Types**: Start Workflow, Resume Workflow, Cancel Workflow
- **Topic Pattern**: `workflow.triggers.<workflow-type>`
- **Example Topics**:
  - `workflow.triggers.admission`
  - `workflow.triggers.discharge`
  - `workflow.triggers.referral`

#### Workflow State Events

```mermaid
sequenceDiagram
    participant Workflow as Workflow Engine
    participant Broker as Event Broker
    participant Subscribers as Event Subscribers
    
    Workflow->>Workflow: State Change
    Workflow->>Broker: Publish State Event
    Broker->>Subscribers: Consume State Event
```

- **State Event Types**: Started, Completed, Failed, Suspended
- **Topic Pattern**: `workflow.states.<workflow-type>`
- **Example Topics**:
  - `workflow.states.admission`
  - `workflow.states.discharge`
  - `workflow.states.referral`

#### Workflow Task Events

```mermaid
sequenceDiagram
    participant Workflow as Workflow Engine
    participant Broker as Event Broker
    participant Worker as Task Worker
    
    Workflow->>Broker: Publish Task Event
    Broker->>Worker: Consume Task Event
    Worker->>Worker: Execute Task
    Worker->>Broker: Publish Result Event
    Broker->>Workflow: Consume Result Event
```

- **Task Event Types**: Created, Assigned, Completed, Failed
- **Topic Pattern**: `workflow.tasks.<task-type>`
- **Example Topics**:
  - `workflow.tasks.approval`
  - `workflow.tasks.notification`
  - `workflow.tasks.data-entry`

## External System Integrations

### Electronic Health Record (EHR) Integration

The Event Broker integrates with EHR systems to exchange clinical data:

#### HL7 v2 Integration

```mermaid
sequenceDiagram
    participant EHR as EHR System
    participant Interface as HL7 Interface
    participant Connect as Kafka Connect
    participant Broker as Event Broker
    
    EHR->>Interface: HL7 v2 Message
    Interface->>Connect: Transformed Message
    Connect->>Broker: Publish Event
    Broker->>Broker: Process Event
```

- **Message Types**: ADT, ORM, ORU, SIU, MDM
- **Topic Pattern**: `hl7.<message-type>.<trigger-event>`
- **Example Topics**:
  - `hl7.adt.a01` (Admission)
  - `hl7.adt.a03` (Discharge)
  - `hl7.oru.r01` (Observation Result)

#### EHR API Integration

```mermaid
sequenceDiagram
    participant EHR as EHR System
    participant API as EHR API
    participant Connect as Kafka Connect
    participant Broker as Event Broker
    
    EHR->>API: API Notification
    API->>Connect: API Webhook
    Connect->>Broker: Publish Event
    Broker->>Broker: Process Event
```

- **API Types**: REST, SOAP, Proprietary
- **Topic Pattern**: `ehr.<vendor>.<resource-type>.<operation>`
- **Example Topics**:
  - `ehr.epic.patient.updated`
  - `ehr.cerner.order.created`
  - `ehr.allscripts.result.available`

### Medical Device Integration

The Event Broker integrates with medical devices to capture real-time data:

#### Device Data Integration

```mermaid
sequenceDiagram
    participant Device as Medical Device
    participant Gateway as Device Gateway
    participant Connect as Kafka Connect
    participant Broker as Event Broker
    
    Device->>Gateway: Device Data
    Gateway->>Connect: Transformed Data
    Connect->>Broker: Publish Event
    Broker->>Broker: Process Event
```

- **Device Types**: Patient Monitors, Infusion Pumps, Ventilators
- **Topic Pattern**: `device.<device-type>.<data-type>`
- **Example Topics**:
  - `device.patient-monitor.vitals`
  - `device.infusion-pump.status`
  - `device.ventilator.settings`

#### Device Alert Integration

```mermaid
sequenceDiagram
    participant Device as Medical Device
    participant Gateway as Device Gateway
    participant Connect as Kafka Connect
    participant Broker as Event Broker
    participant Alert as Alert System
    
    Device->>Gateway: Device Alert
    Gateway->>Connect: Transformed Alert
    Connect->>Broker: Publish Alert Event
    Broker->>Alert: Consume Alert Event
    Alert->>Alert: Process Alert
```

- **Alert Types**: Technical, Physiological, Operational
- **Topic Pattern**: `device.alerts.<alert-type>`
- **Example Topics**:
  - `device.alerts.technical`
  - `device.alerts.physiological`
  - `device.alerts.operational`

### Laboratory Information System (LIS) Integration

The Event Broker integrates with laboratory systems to exchange lab orders and results:

#### Lab Order Integration

```mermaid
sequenceDiagram
    participant EHR as EHR System
    participant Broker as Event Broker
    participant Connect as Kafka Connect
    participant LIS as Lab System
    
    EHR->>Broker: Publish Lab Order
    Broker->>Connect: Consume Order Event
    Connect->>LIS: Create Lab Order
    LIS->>LIS: Process Order
```

- **Order Types**: Laboratory, Pathology, Microbiology
- **Topic Pattern**: `lab.orders.<order-type>`
- **Example Topics**:
  - `lab.orders.chemistry`
  - `lab.orders.hematology`
  - `lab.orders.microbiology`

#### Lab Result Integration

```mermaid
sequenceDiagram
    participant LIS as Lab System
    participant Connect as Kafka Connect
    participant Broker as Event Broker
    participant EHR as EHR System
    
    LIS->>Connect: Lab Result
    Connect->>Broker: Publish Result Event
    Broker->>EHR: Consume Result Event
    EHR->>EHR: Process Result
```

- **Result Types**: Normal, Abnormal, Critical
- **Topic Pattern**: `lab.results.<result-type>`
- **Example Topics**:
  - `lab.results.normal`
  - `lab.results.abnormal`
  - `lab.results.critical`

### Pharmacy System Integration

The Event Broker integrates with pharmacy systems to exchange medication orders and dispensing information:

#### Medication Order Integration

```mermaid
sequenceDiagram
    participant EHR as EHR System
    participant Broker as Event Broker
    participant Connect as Kafka Connect
    participant Pharmacy as Pharmacy System
    
    EHR->>Broker: Publish Medication Order
    Broker->>Connect: Consume Order Event
    Connect->>Pharmacy: Create Medication Order
    Pharmacy->>Pharmacy: Process Order
```

- **Order Types**: Inpatient, Outpatient, Discharge
- **Topic Pattern**: `pharmacy.orders.<order-type>`
- **Example Topics**:
  - `pharmacy.orders.inpatient`
  - `pharmacy.orders.outpatient`
  - `pharmacy.orders.discharge`

#### Medication Dispensing Integration

```mermaid
sequenceDiagram
    participant Pharmacy as Pharmacy System
    participant Connect as Kafka Connect
    participant Broker as Event Broker
    participant EHR as EHR System
    
    Pharmacy->>Connect: Medication Dispensed
    Connect->>Broker: Publish Dispensing Event
    Broker->>EHR: Consume Dispensing Event
    EHR->>EHR: Update Medication Status
```

- **Dispensing Types**: New, Refill, Return
- **Topic Pattern**: `pharmacy.dispensing.<dispensing-type>`
- **Example Topics**:
  - `pharmacy.dispensing.new`
  - `pharmacy.dispensing.refill`
  - `pharmacy.dispensing.return`

## Analytics and Reporting Integrations

### Real-Time Analytics Integration

The Event Broker integrates with analytics platforms for real-time data processing:

#### Streaming Analytics

```mermaid
sequenceDiagram
    participant Source as Event Source
    participant Broker as Event Broker
    participant Streams as Kafka Streams
    participant Dashboard as Real-Time Dashboard
    
    Source->>Broker: Publish Event
    Broker->>Streams: Process Event Stream
    Streams->>Broker: Publish Derived Event
    Broker->>Dashboard: Update Dashboard
```

- **Analytics Types**: KPIs, Metrics, Alerts
- **Topic Pattern**: `analytics.realtime.<metric-type>`
- **Example Topics**:
  - `analytics.realtime.patient-flow`
  - `analytics.realtime.bed-occupancy`
  - `analytics.realtime.wait-times`

#### Clinical Decision Support

```mermaid
sequenceDiagram
    participant Source as Clinical Source
    participant Broker as Event Broker
    participant CDS as CDS Engine
    participant EHR as EHR System
    
    Source->>Broker: Publish Clinical Event
    Broker->>CDS: Consume Clinical Event
    CDS->>CDS: Apply Clinical Rules
    CDS->>Broker: Publish Alert Event
    Broker->>EHR: Consume Alert Event
```

- **CDS Types**: Alerts, Reminders, Order Sets
- **Topic Pattern**: `cds.<alert-type>.<priority>`
- **Example Topics**:
  - `cds.drug-interaction.high`
  - `cds.abnormal-result.critical`
  - `cds.care-gap.medium`

### Data Lake Integration

The Event Broker integrates with data lakes for long-term storage and analysis:

#### Data Lake Ingestion

```mermaid
sequenceDiagram
    participant Source as Event Source
    participant Broker as Event Broker
    participant Connect as Kafka Connect
    participant Lake as Data Lake
    
    Source->>Broker: Publish Event
    Broker->>Connect: Consume Event
    Connect->>Lake: Store Event
    Lake->>Lake: Process Data
```

- **Storage Formats**: Parquet, Avro, JSON
- **Integration Point**: Kafka Connect sink connectors
- **Destination Systems**: HDFS, S3, Azure Data Lake

#### Data Warehouse Integration

```mermaid
sequenceDiagram
    participant Source as Event Source
    participant Broker as Event Broker
    participant Connect as Kafka Connect
    participant DW as Data Warehouse
    
    Source->>Broker: Publish Event
    Broker->>Connect: Consume Event
    Connect->>DW: Load Data
    DW->>DW: Transform Data
```

- **Warehouse Types**: Snowflake, BigQuery, Redshift
- **Integration Point**: Kafka Connect sink connectors
- **Data Models**: Star Schema, Data Vault, Dimensional

## Mobile and Patient Engagement Integrations

### Mobile Application Integration

The Event Broker integrates with mobile applications for real-time updates:

#### Push Notification Integration

```mermaid
sequenceDiagram
    participant Source as Event Source
    participant Broker as Event Broker
    participant Service as Notification Service
    participant Mobile as Mobile App
    
    Source->>Broker: Publish Event
    Broker->>Service: Consume Event
    Service->>Mobile: Send Push Notification
    Mobile->>Mobile: Display Notification
```

- **Notification Types**: Appointment, Result, Medication
- **Topic Pattern**: `notifications.push.<notification-type>`
- **Example Topics**:
  - `notifications.push.appointment`
  - `notifications.push.result`
  - `notifications.push.medication`

#### Real-Time Updates

```mermaid
sequenceDiagram
    participant Source as Event Source
    participant Broker as Event Broker
    participant Gateway as API Gateway
    participant Mobile as Mobile App
    
    Source->>Broker: Publish Event
    Broker->>Gateway: Consume Event
    Gateway->>Mobile: WebSocket Update
    Mobile->>Mobile: Update UI
```

- **Update Types**: Status, Progress, Alert
- **Integration Point**: WebSocket API Gateway
- **Protocol**: WebSocket, Server-Sent Events

### Patient Portal Integration

The Event Broker integrates with patient portals for real-time information:

#### Patient Portal Updates

```mermaid
sequenceDiagram
    participant Source as Event Source
    participant Broker as Event Broker
    participant Portal as Patient Portal
    participant Patient as Patient User
    
    Source->>Broker: Publish Event
    Broker->>Portal: Consume Event
    Portal->>Portal: Update Data
    Patient->>Portal: View Information
```

- **Update Types**: Results, Medications, Appointments
- **Topic Pattern**: `patient.portal.<update-type>`
- **Example Topics**:
  - `patient.portal.results`
  - `patient.portal.medications`
  - `patient.portal.appointments`

## Conclusion

The Event Broker provides extensive integration points with both internal components of the CMM Technology Platform and external healthcare systems. These integration points enable real-time data exchange, event-driven workflows, and seamless interoperability across the healthcare ecosystem. By leveraging these integration capabilities, healthcare organizations can build connected, responsive applications that improve patient care, operational efficiency, and data-driven decision making.

## Related Documentation

- [Event Broker Overview](../01-getting-started/overview.md)
- [Event Broker Architecture](../01-getting-started/architecture.md)
- [Core APIs](./core-apis.md)
- [Event Schemas](./event-schemas.md)
- [Connectors](./connectors.md)
