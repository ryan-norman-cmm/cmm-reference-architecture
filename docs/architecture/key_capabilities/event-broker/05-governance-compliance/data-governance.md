# Event Broker Data Governance

## Introduction
This document outlines the data governance framework for the Event Broker platform at CoverMyMeds. Data governance for event streams ensures data quality, integrity, and compliance throughout the lifecycle of events flowing through our systems. It establishes clear ownership, classification, and handling procedures for all event data.

## Governance Principles

1. **Data Quality**
   - All events must conform to their registered schema
   - Events should contain accurate, complete, and timely information
   - Events should include standardized metadata (origin, timestamp, correlationId)

2. **Data Stewardship**
   - Every event stream has a designated owner team responsible for its lifecycle
   - Domain teams are accountable for the quality and correctness of their events
   - Central governance team provides oversight and cross-domain coordination

3. **Data Compliance**
   - PHI/PII must be handled according to healthcare data regulations
   - Data lineage must be tracked for all sensitive data flows
   - Data access must follow the principle of least privilege

4. **Data Classification**
   - All event streams must be classified according to sensitivity level
   - Classification determines retention, encryption, and access control requirements

## Roles & Responsibilities

| Role | Responsibilities |
|------|-----------------|
| **Domain Data Owner** | Defines domain event schemas, ensures business alignment, approves schema changes |
| **Event Stream Custodian** | Manages topic configuration, retention settings, and performance tuning |
| **Data Governance Council** | Reviews and approves cross-domain data flows, resolves governance conflicts |
| **Compliance Officer** | Ensures event handling complies with regulatory requirements |
| **Security Engineer** | Implements and reviews access controls and encryption measures |
| **Data Consumer** | Adheres to event contracts, reports data quality issues |

## Data Lifecycle & Policies

### Creation
- New event types must be registered in the central event catalog
- Event schemas must be reviewed and approved before production use
- Events must include required metadata fields and conform to naming conventions

### Storage
- Data classification determines encryption requirements:
  - Level 1 (Public): No encryption required
  - Level 2 (Internal): Encryption in transit
  - Level 3 (Confidential): Encryption in transit and at rest
  - Level 4 (Restricted): End-to-end encryption with key rotation

### Retention
- Default retention periods by classification:
  - Level 1: 90 days
  - Level 2: 60 days
  - Level 3: 30 days
  - Level 4: 7 days or as required by regulations
- Extended retention requires explicit approval and justification
- Critical business events may be archived to long-term storage

### Deletion
- Automatic topic compaction based on retention policies
- Explicit purge commands require dual approval
- Data removal requests (e.g., GDPR) follow established workflows

## Schema Governance

### Schema Standards
- All schemas must use Apache Avro format
- Schemas should be backward compatible where possible
- Breaking changes require version increments and migration plan

### Naming Conventions
- Topic names: `<domain>.<entity>.<event-type>`
  - Example: `patient.profile.updated`
- Field names: camelCase with descriptive names
- Enums: UPPER_SNAKE_CASE with clear semantic meaning

### Schema Registry Requirements
- All production topics must have registered schemas
- Schema compatibility modes by default:
  - Development: NONE (permissive)
  - Testing: BACKWARD (allows consumer upgrades first)
  - Production: FULL (requires full compatibility)
- Schema evolution requests follow GitOps workflow

## Related Resources
- [Event Broker Audit Compliance](./audit-compliance.md)
- [Schema Registry Management](./schema-registry-management.md)
- [Data Retention and Archiving](./data-retention-archiving.md)
- [Topic Governance](./topic-governance.md)