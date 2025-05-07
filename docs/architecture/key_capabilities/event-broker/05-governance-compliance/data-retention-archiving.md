# Event Broker Data Retention and Archiving

## Introduction
This document outlines the data retention and archiving strategies for the Event Broker platform at CoverMyMeds. Proper management of event data throughout its lifecycle is essential for regulatory compliance, operational efficiency, and cost management while ensuring data is available when needed.

## Data Retention Framework

### Retention Policy Principles
1. **Risk-Based Approach**: Retention periods based on data sensitivity and business value
2. **Regulatory Compliance**: Alignment with healthcare regulations and privacy laws
3. **Storage Optimization**: Balancing accessibility with cost efficiency
4. **Functional Requirements**: Supporting replay, reprocessing, and disaster recovery needs

### Data Classification Matrix

| Classification Level | Description | Default Retention | Extended Retention |
|----------------------|-------------|-------------------|-------------------|
| **Level 1 (Public)** | Non-sensitive business events | 30 days | Up to 90 days |
| **Level 2 (Internal)** | Internal operational data | 14 days | Up to 60 days |
| **Level 3 (Confidential)** | Business sensitive data | 7 days | Up to 30 days |
| **Level 4 (Restricted)** | PHI, PII, payment data | 3 days | Up to 7 days |

### Retention Configuration Controls
- **Topic-Level Settings**: Retention time and size limits configured per topic
- **Policy Enforcement**: Automated validation of retention settings against data classification
- **Exception Process**: Formal review and approval for retention exceptions
- **Monitoring**: Continuous verification of retention policy implementation

## Retention Implementation Strategies

### Time-Based Retention
- Primary retention strategy for most topics
- Default retention periods tied to data classification
- Configurable at topic creation time through GitOps workflow
- Automated enforcement through broker configurations

### Size-Based Retention
- Secondary constraint to manage storage growth
- Appropriate for high-volume, variable load topics
- Configured as a safeguard alongside time-based retention
- Size limits determined by data classification and operational requirements

### Compacted Topics
- Used for current-state topics (latest value per key)
- Applied to reference data and state-tracking topics
- Retention based on cleanup policy settings
- Minimum compaction lag time configured for operational safety

## Archiving Mechanisms

### Archiving Triggers
- Approaching retention limit
- Business-defined archiving schedule
- Regulatory retention requirements
- Capacity management needs

### Archiving Methods

#### Near-Line Archiving
- **Implementation**: Kafka Connect S3 Sink Connector
- **Format**: Optimized Parquet files with partitioning
- **Retention**: 1 year in S3 Standard storage
- **Access Pattern**: Query through Athena/Redshift

#### Cold Storage Archiving
- **Implementation**: S3 Lifecycle Policies
- **Format**: Parquet with compression
- **Retention**: 7+ years in Glacier Deep Archive
- **Access Pattern**: Batch retrieval process

### Archiving Configuration

```yaml
# Sample archiving configuration
apiVersion: kafka.covermymeds.com/v1
kind: TopicArchivePolicy
metadata:
  name: patient-data-archive-policy
  namespace: healthcare-events
spec:
  topic: 'patient.profile.updated'
  dataClassification: 'Level4'
  nearLineArchive:
    enabled: true
    format: 'PARQUET'
    compression: 'SNAPPY'
    partitioning:
      - type: 'TIME'
        granularity: 'DAY'
      - type: 'FIELD'
        field: 'patientId'
    retention: '365d'
    storageClass: 'STANDARD'
  coldStorage:
    enabled: true
    retentionPeriod: '7y'
    storageClass: 'GLACIER_DEEP_ARCHIVE'
  encryption:
    enabled: true
    kmsKeyId: 'arn:aws:kms:us-east-1:12345:key/6789'
```

## Data Lifecycle Automation

### Automated Lifecycle Management
- Event stream data automatically moves through lifecycle stages
- Tiered storage approach: hot → near-line → cold
- Policy-driven transitions between storage tiers
- Lifecycle automation integrated with GitOps workflow

### Archiving Workflows
1. **Topic Registration**: Classification and retention policies defined
2. **Active Monitoring**: Continuous tracking of data volume and age
3. **Pre-Archive Notification**: Alert to data owners before archiving
4. **Archive Process**: Automated extraction and storage
5. **Verification**: Integrity checks on archived data
6. **Metadata Update**: Archive location recorded in data catalog

## Retrieval and Access Controls

### Archive Access Methods
- **Self-Service Portal**: Business users can query archived data
- **Analyst Access**: Data scientists can access archives through analytics tools
- **Data API**: Application-level access to archived event data
- **Batch Extraction**: Bulk retrieval for specific use cases

### Access Control Policies
- RBAC controls applied to archive access
- Access logs maintained for all archive retrievals
- Time-limited access tokens for archive data
- Approval workflow for sensitive data access

### Retrieval Performance SLAs

| Archive Tier | Access Method | Performance SLA |
|--------------|---------------|-----------------|
| **Near-Line (S3)** | Direct Query | < 1 minute |
| **Cold Storage (Glacier)** | Retrieval Request | < 24 hours |
| **Long-Term Archive** | Formal Request | < 72 hours |

## Compliance and Audit

### Retention Compliance
- Automated verification of retention settings against policy
- Regular compliance scans across all topics
- Alerts for retention policy violations
- Documentation of retention exceptions

### Archiving Audit Trail
- Full audit log of all archiving activities
- Chain of custody for archived data
- Immutable archive logs for compliance evidence
- Quarterly archive integrity validation

### Documentation Requirements
- Retention policy documentation in data catalog
- Archive location and access procedures
- Data mapping to regulatory requirements
- Evidence of policy enforcement

## Special Case Handling

### Legal Hold Process
1. **Hold Notification**: Legal team initiates hold request
2. **Hold Configuration**: Override of normal retention for affected topics
3. **Hold Tracking**: Documentation of all active legal holds
4. **Hold Release**: Formal process to resume normal retention

### Data Subject Requests
1. **Request Identification**: GDPR, CCPA, or other privacy requests
2. **Data Location**: Identification of relevant topics and archives
3. **Data Extraction/Deletion**: Processes to fulfill requests
4. **Documentation**: Audit trail of request fulfillment

### Disaster Recovery Considerations
- Archive data included in disaster recovery planning
- Cross-region replication for critical archives
- Archive restoration testing as part of DR drills
- RTO/RPO definitions for archived data

## Related Resources
- [Event Broker Data Governance](./data-governance.md)
- [Regulatory Compliance](./regulatory-compliance.md)
- [Topic Governance](./topic-governance.md)