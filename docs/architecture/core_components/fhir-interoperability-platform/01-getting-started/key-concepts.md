# FHIR Interoperability Platform Key Concepts

## Introduction
This document outlines the fundamental concepts and terminology of the FHIR Interoperability Platform core component, which is built on Health Samurai's Aidbox FHIR server. It serves as a reference for developers, architects, and stakeholders working with healthcare data exchange.

## Core Terminology

- **FHIR**: Fast Healthcare Interoperability Resources; a standard for healthcare data exchange developed by HL7.

- **Resource**: The fundamental unit of data exchange in FHIR, representing a discrete healthcare concept (e.g., Patient, Observation, MedicationRequest).

- **Profile**: A set of constraints on a resource that describes how it is used for a particular purpose or in a particular context.

- **Implementation Guide**: A collection of profiles, extensions, value sets, and other artifacts that define how FHIR is used to solve a particular problem.

- **Capability Statement**: A formal declaration of the functionality a FHIR server supports, including which resources, operations, and search parameters it implements.

- **Bundle**: A collection of resources that can be exchanged as a single unit, often used for transactions or query responses.

- **Extension**: A mechanism to add new elements to FHIR resources without changing the base definition.

- **Reference**: A link from one resource to another, similar to a foreign key in a relational database.

- **CodeSystem**: A set of codes and their meanings, used for consistent terminology (e.g., SNOMED CT, LOINC, RxNorm).

- **ValueSet**: A defined set of coded values that can be used to restrict the allowed values for a particular element.

## Fundamental Concepts

### FHIR REST API

The FHIR REST API follows RESTful principles and provides standard operations for working with resources:

- **CRUD Operations**: Create, Read, Update, Delete operations on resources
- **Search**: Querying resources based on various parameters
- **Transactions**: Atomic operations involving multiple resources
- **Operations**: Named procedures that extend beyond basic CRUD functionality
- **Compartments**: Logical groupings of resources related to a single resource (e.g., all resources for a patient)
- **History**: Tracking changes to resources over time
- **Versioning**: Managing multiple versions of resources

### FHIR Resource Structure

All FHIR resources share a common structure:

- **Resource Type**: The type of the resource (e.g., Patient, Observation)
- **Metadata**: Standard elements like id, versionId, lastUpdated
- **Narrative**: Human-readable representation of the resource
- **Extensions**: Additional elements not defined in the base resource
- **Resource-Specific Data**: Elements specific to the resource type

### FHIR Data Types

FHIR defines several data types that are used across resources:

- **Primitive Types**: String, boolean, integer, decimal, etc.
- **Complex Types**: CodeableConcept, Identifier, Reference, etc.
- **Metadata Types**: Meta, Extension, Narrative, etc.
- **Special Types**: Resource, DomainResource, BackboneElement, etc.

### FHIR Security Model

The FHIR Interoperability Platform implements a comprehensive security model:

- **Authentication**: Verifying the identity of users and systems
- **Authorization**: Determining what resources a user or system can access
- **Consent**: Managing patient consent for data access
- **Provenance**: Tracking the origin and history of resources
- **AuditEvent**: Recording security-relevant actions
- **Secure Communications**: Encrypting data in transit (TLS)

### SMART on FHIR

SMART on FHIR is a framework for healthcare application integration:

- **OAuth 2.0/OpenID Connect**: Standard protocols for authentication and authorization
- **Launch Context**: Providing context information (patient, encounter) to applications
- **Scopes**: Defining access privileges for applications
- **App Launch**: Standardized flow for launching applications from EHRs
- **Backend Services**: Server-to-server authentication and authorization

### FHIR Subscriptions

The subscription mechanism allows clients to be notified when resources change:

- **Subscription Resources**: Defining what changes to monitor
- **Notification Channels**: Methods for delivering notifications (REST hooks, WebSockets, etc.)
- **Filtering Criteria**: Specifying which resources or events trigger notifications
- **Subscription Status**: Tracking the state of subscriptions

## Glossary

| Term | Definition |
|------|------------|
| HL7 | Health Level Seven International; the organization that develops healthcare standards including FHIR |
| FHIR R4 | Release 4 of the FHIR standard; the primary version supported by the platform |
| US Core | A US-specific implementation guide that defines profiles for FHIR resources |
| USCDI | United States Core Data for Interoperability; a standardized set of health data classes and elements |
| CQL | Clinical Quality Language; a high-level language for expressing clinical quality measures |
| SDC | Structured Data Capture; a FHIR implementation guide for forms |
| LOINC | Logical Observation Identifiers Names and Codes; a terminology for laboratory tests and measurements |
| SNOMED CT | Systematized Nomenclature of Medicine Clinical Terms; a comprehensive clinical terminology |
| RxNorm | A standardized nomenclature for clinical drugs |
| IPS | International Patient Summary; a FHIR implementation guide for patient summaries |

## Related Resources
- [FHIR Interoperability Platform Overview](./overview.md)
- [FHIR Interoperability Platform Architecture](./architecture.md)
- [FHIR Interoperability Platform Quick Start](./quick-start.md)
- [HL7 FHIR Documentation](https://hl7.org/fhir/)
- [Aidbox Documentation](https://docs.aidbox.app/)