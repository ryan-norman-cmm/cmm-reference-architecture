# Platform Overview

<!-- Architecture Overview Diagram: A high-level visualization showing the four main architectural layers (Infrastructure, Platform Capabilities, Shared Product Capabilities, and Applications) with key components in each layer. Lines between components should show major relationships and data flows. -->

Our modern platform leverages healthcare standards like FHIR to create a unified ecosystem where patients, providers, payers, pharmacies, and pharmaceutical manufacturers can collaborate efficiently. By implementing standardized interfaces and event-driven communication, we accelerate time-to-therapy while maintaining secure, compliant data exchange across the medication access landscape.

| For Developers | For Architects | For Product Managers |
|----------------|----------------|----------------------|
| [Setup Guide →](link) | [Reference Patterns →](link) | [Capability Roadmap →](link) |
| [API Documentation →](link) | [Integration Models →](link) | [Business Value →](link) |
| [Code Examples →](link) | [Security Framework →](link) | [Feature Planning →](link) |

## Key Implementation Decisions

| Decision Point | Options | Considerations | Learn More |
|----------------|---------|----------------|-----------|
| Data Integration Approach | FHIR APIs, Event Streaming, File-Based | Data volume, real-time needs, partner capabilities | [Integration Patterns →](link) |
| Authentication Model | SMART on FHIR, OAuth 2.0, mTLS | Security requirements, partner standards, user types | [Security Framework →](link) |
| Application Strategy | Backend-for-Frontend, Shared Capability, Pipeline Service | User experience, workflow complexity, reusability | [Application Models →](link) |

## Core Platform Components

### API Marketplace
Our API Marketplace provides a comprehensive approach to API management combining F5 Distributed Cloud App Connect for universal ingress, Voltmesh for internal communication, and Mulesoft for API integration and management.

**Key Capabilities:**
- Universal API gateway with multi-cloud support
- Zero Trust API security
- Service mesh for internal service communication
- Healthcare-specific API patterns and transformations
- Comprehensive API lifecycle management


[API Marketplace Documentation →](/architecture/core_components/api-marketplace/01-getting-started/overview/)

### FHIR Interoperability Platform
Our comprehensive FHIR Interoperability Platform serves as the foundation for healthcare data exchange, providing not just a FHIR-compliant data repository but a complete solution for healthcare interoperability. The platform is enabled through Health Samurai's Aidbox product, which includes robust APIs, flexible data persistence options, role-based access control, subscription capabilities, and comprehensive implementation guide support, enabling seamless integration with the broader healthcare ecosystem.

**Key Capabilities:**
- Comprehensive FHIR Server APIs with RESTful and GraphQL endpoints
- Flexible data persistence with optimized storage options
- Role-based access control for healthcare data
- FHIR Subscription Topics and real-time notifications
- Implementation Guide installation and development
- Bulk data operations for population health management


[FHIR Interoperability Platform Documentation →](/architecture/core_components/fhir-interoperability-platform/01-getting-started/overview/)

### Federated Graph API
The unified API layer exposes capabilities across all systems through a coherent GraphQL interface through Apollo Router and GraphOS, enabling product teams to efficiently access data and services while maintaining service boundaries.


[Federated Graph API Documentation →](/architecture/core_components/federated-graph-api/01-getting-started/overview/)

### Design System
Our comprehensive design system ShadCN components with Tailwind CSS, Storybook, and healthcare-specific patterns to create consistent, accessible user interfaces across all applications.

**Key Capabilities:**
- Accessible, WCAG 2.1 AA compliant components
- Healthcare-specific UI patterns
- Consistent design language and tokens
- Comprehensive documentation and examples
- Automated testing and quality assurance


[Design System Documentation →](/architecture/core_components/design-system/01-getting-started/overview/)

### Event Broker
Our platform uses Confluent Kafka to implement a robust event broker, enabling real-time data processing, system decoupling, and comprehensive visibility into the patient journey.

**Key Capabilities:**
- Real-time event processing
- System decoupling
- Comprehensive patient journey visibility
- Event schema standards
- Event-driven architecture

[Event Broker Documentation →](/architecture/core_components/event-broker/01-getting-started/overview/)

## Healthcare Capabilities

### Master Data Services
Our robust platform of master data services includes common data sets like medications, providers, pharmacies, payers, patients, and many others. These services enable consistency and reusability of all data available to our products, providing a foundation for reliable decision-making and analytics.

**Key Capabilities:**
- Deterministic and probabilistic patient matching
- Provider directory and organization hierarchy management
- Medication catalog with therapeutic classification
- Payer policies and formulary information

[Master Data Documentation →](link)

### Forms Management
Structured Data Capture implementation for healthcare forms with Clinical Quality Language integration for auto-population from available patient data.

**Supported Features:**
- Dynamic form rendering from FHIR Questionnaire resources
- Conditional logic and validation
- Auto-population from clinical data
- PDF generation and electronic signatures

[Forms Integration Guide →](link)

### Healthcare Workflows
Implementation of standardized healthcare workflows following established FHIR implementation guides from governing bodies like HL7, Da Vinci, and others. We strive to align with industry standards while delivering value through prior authorization workflows, medication management, and other healthcare processes.

**Supported Implementation Guides:**
- Da Vinci Prior Authorization Support (PAS)
- Da Vinci Coverage Requirements Discovery (CRD)
- HL7 FHIR US Core

[Standards Alignment →](link)

## Common Implementation Scenarios
<!-- Scenario Diagram: A sequence diagram showing interactions between key components for a prior authorization workflow, including data flow between systems, event publishing, and API calls. -->

### Prior Authorization Submission

A common implementation scenario involves connecting an EHR system to our prior authorization workflow. This process leverages our FHIR server, event broker, and business process management capabilities to automate and streamline the authorization process.

1. EHR system sends patient and prescription data via FHIR API
2. Platform translates incoming data to canonical FHIR format
3. Events trigger appropriate workflows based on payer and medication
4. Status updates are published via events and accessible through APIs
5. Determinations are returned to EHR with supporting documentation

[Implementation Guide →](link) | [Code Samples →](link)