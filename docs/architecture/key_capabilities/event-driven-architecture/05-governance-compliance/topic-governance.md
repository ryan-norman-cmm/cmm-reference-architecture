# Event Broker Topic Governance

## Introduction
This document outlines the governance framework for managing Kafka topics within the Event Broker platform. Effective topic governance ensures data quality, operational efficiency, and regulatory compliance while enabling business agility through event-driven architecture.

## Topic Lifecycle Management

### Topic Creation
1. **Planning**
   - Business justification and use case documentation
   - Data classification and sensitivity assessment
   - Producer/consumer identification and coordination
   - Capacity planning and resource allocation

2. **Approval Process**
   - Standard topics: Team lead and domain owner approval
   - Sensitive data topics: Additional security review
   - Cross-domain topics: Architecture governance board review

3. **Provisioning**
   - GitOps-based topic creation (Infrastructure as Code)
   - Automated validation of configuration standards
   - Pre-creation schema registration requirement
   - CI/CD pipeline for topic deployment

### Topic Modification
1. **Change Request**
   - Formal change request for configuration modifications
   - Impact analysis on existing consumers/producers
   - Backward compatibility assessment

2. **Approval Workflow**
   - Risk assessment based on change type
   - Approval requirements scaled to impact level
   - Emergency change process for critical issues

3. **Implementation**
   - Controlled rollout of configuration changes
   - Validation of changes in test environment first
   - Monitoring for performance impact

### Topic Deprecation & Retirement
1. **Deprecation Planning**
   - Minimum 90-day notification period
   - Migration path documentation
   - Consumer usage tracking and notification

2. **Graceful Transition**
   - Dual-write period to new replacement topic
   - Read-only mode before final decommissioning
   - Archive capability for regulatory requirements

3. **Decommissioning**
   - Final data export for long-term storage if required
   - Resource reclamation process
   - Documentation update and catalog cleanup

## Topic Naming Convention

### Naming Structure
Format: `<domain>.<entity>.<event-type>`

| Component | Description | Examples |
|-----------|-------------|----------|
| `domain` | Business domain or bounded context | `patient`, `claim`, `pharmacy` |
| `entity` | The primary business entity | `profile`, `prescription`, `prior-auth` |
| `event-type` | The event or action that occurred | `created`, `updated`, `requested`, `expired` |

Examples:
- `patient.profile.updated`
- `claim.prior-auth.approved`
- `pharmacy.prescription.filled`

### Special Topic Types

| Type | Naming Pattern | Purpose |
|------|----------------|---------|
| **Internal Processing** | `_<domain>.processing.<description>` | Internal processing streams |
| **Dead Letter Queue** | `<domain>.dlq.<source-topic>` | Failed message handling |
| **Aggregations** | `<domain>.<entity>.aggregated.<window>` | Aggregated/derived data |
| **Commands** | `<domain>.<entity>.command.<action>` | Command topics (request-response) |

## Topic Configuration Standards

### Partition Strategy

| Topic Classification | Partition Strategy | Considerations |
|---------------------|-------------------|----------------|
| **High Volume** | 24+ partitions | Based on throughput requirements |
| **Standard** | 12 partitions | Default for most business events |
| **Low Volume** | 6 partitions | Infrequent events, small payloads |
| **Singleton** | 1 partition | When strict ordering is required |

Partition count calculations must consider:
- Expected peak message throughput
- Consumer parallelism requirements
- Message ordering needs
- Retention period and storage impact

### Replication Configuration

| Environment | Replication Factor | Min In-Sync Replicas |
|-------------|-------------------|----------------------|
| **Development** | 2 | 1 |
| **Test** | 3 | 2 |
| **Production** | 3 | 2 |
| **Critical Production** | 5 | 3 |

### Retention Settings

| Data Classification | Default Retention | Max Retention |
|--------------------|-------------------|---------------|
| **Level 1 (Public)** | 30 days | 90 days |
| **Level 2 (Internal)** | 15 days | 60 days |
| **Level 3 (Confidential)** | 7 days | 30 days |
| **Level 4 (Restricted)** | 3 days | 7 days |

Retention exceptions require:
- Business justification documentation
- Security review and approval
- Compliance officer sign-off
- Quarterly retention review

## Topic Ownership Model

### Ownership Roles

| Role | Responsibilities |
|------|------------------|
| **Topic Owner** | Overall accountability for topic lifecycle, quality, and governance |
| **Producer Owner** | Responsible for data quality, schema evolution, and production SLAs |
| **Consumer Owners** | Responsible for timely and proper event consumption |
| **Platform Team** | Infrastructure, monitoring, and platform-level support |

### Ownership Documentation
- Topic ownership documented in central metadata registry
- Linked to on-call rotations and incident response
- Regular ownership reviews (quarterly)
- Ownership transfer process for team changes

## Monitoring and Health

### Health Metrics

| Metric Category | Key Metrics | Thresholds |
|-----------------|-------------|------------|
| **Throughput** | Messages/sec, bytes/sec | Topic-specific baselines |
| **Latency** | Producer latency, end-to-end latency | <100ms producer, <500ms e2e |
| **Errors** | Failed productions, consumer errors | <0.1% error rate |
| **Consumer Lag** | Messages behind, time behind | Topic-specific SLAs |

### Alerting Strategy
- Tiered alerting based on topic criticality
- Custom SLAs for mission-critical topics
- Trend-based anomaly detection
- Integration with incident management system

## Topic Catalog and Documentation

### Required Metadata
- Topic name and full description
- Classification and sensitivity level
- SLAs and performance expectations
- Ownership information and contacts
- Schema references and examples
- Retention and disaster recovery policies

### Documentation Requirements
- Consumer/producer onboarding guide
- Schema evolution guidelines
- Sample code for production/consumption
- Error handling patterns
- Known operational concerns

## Compliance and Auditing

### Audit Requirements
- Configuration change history
- Access control modifications
- Retention policy adherence
- Data classification accuracy

### Compliance Checks
- Automated policy validation
- Regular configuration drift detection
- Security posture assessment
- Encryption verification for sensitive topics

## Related Resources
- [Event Broker Data Governance](./data-governance.md)
- [Schema Registry Management](./schema-registry-management.md)
- [Data Retention and Archiving](./data-retention-archiving.md)
- [Access Controls](./access-controls.md)