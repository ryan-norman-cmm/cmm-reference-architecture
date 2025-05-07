# FHIR Interoperability Platform Overview

## Introduction
The FHIR Interoperability Platform enables secure, standards-based exchange of healthcare data using the HL7 FHIR specification and Health Samurai's Aidbox. It serves as the foundation for healthcare data interoperability across the platform, ensuring consistent, compliant, and efficient data exchange between internal and external systems.

## Key Features
- Comprehensive FHIR server APIs (REST, GraphQL)
- Flexible data persistence and storage
- Role-based access control
- FHIR Subscription Topics and real-time notifications
- Bulk data operations for population health
- SMART on FHIR application support

## Architecture Overview
- The FHIR Interoperability Platform serves as the central data standard implementation for healthcare information exchange.
- It provides a FHIR-compliant server with multiple API access patterns (REST, GraphQL) built on Aidbox.
- The platform includes validation, security, and transformation capabilities to ensure data quality and compliance.

## Integration Points
- Integrates with the Event-Driven Architecture for real-time FHIR resource change notifications
- Connects with the Federated Graph API to expose FHIR data through GraphQL
- Provides standardized APIs for the API Marketplace
- Enables healthcare data exchange with external EHRs, payers, and partners

## Use Cases
- Patient data exchange between healthcare organizations
- Clinical data integration for care coordination
- Population health data aggregation and analysis
- Claims and administrative data exchange
- Patient access to health information via SMART apps

## Learn More
- [HL7 FHIR Documentation](https://hl7.org/fhir/) — Official FHIR specification and implementation guides
- [Aidbox Platform Overview](https://docs.aidbox.app/overview) — Comprehensive guide to the Aidbox FHIR platform
- [SMART on FHIR Introduction](https://docs.smarthealthit.org/) — Framework for healthcare apps that run across platforms

## Next Steps
- [FHIR Interoperability Platform Architecture](./architecture.md)
- [FHIR Interoperability Platform Quick Start](./quick-start.md)
- [FHIR Interoperability Platform Core APIs](../02-core-functionality/core-apis.md)
