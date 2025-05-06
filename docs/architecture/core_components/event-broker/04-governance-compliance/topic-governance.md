# Topic Governance

## Overview

Topic governance provides a structured framework for managing the lifecycle, ownership, and quality of Kafka topics within the Event Broker. This document outlines the policies, procedures, and best practices for topic creation, management, and retirement, ensuring that topics remain well-organized, secure, and compliant with organizational standards in healthcare environments.

## Topic Naming Standards

Consistent topic naming is essential for discoverability, governance, and automation. All topics must follow the established naming convention:

```
<domain>.<entity>.<event-type>
```

### Domain Categories

| Domain | Description | Example Topics | Governance Owner |
|--------|-------------|----------------|-----------------|
| clinical | Clinical care events | clinical.patient.admitted | Clinical Data Team |
| administrative | Administrative events | administrative.appointment.scheduled | Operations Team |
| financial | Financial events | financial.claim.submitted | Finance Systems Team |
| pharmacy | Pharmacy events | pharmacy.prescription.filled | Pharmacy Systems Team |
| device | Medical device events | device.reading.recorded | Medical Devices Team |
| reference | Reference data | reference.provider.details | Master Data Team |

### Naming Validation

All topic creation requests must pass automated validation to ensure compliance with naming standards:

```bash
#!/bin/bash
# Topic name validation script

TOPIC_NAME=$1

# Check format compliance
if [[ ! $TOPIC_NAME =~ ^[a-z0-9]+\.[a-z0-9-]+\.[a-z0-9-]+$ ]]; then
  echo "ERROR: Topic name does not follow the required format: domain.entity.event-type"
  exit 1
fi

# Extract domain
DOMAIN=$(echo $TOPIC_NAME | cut -d. -f1)

# Validate domain
VALID_DOMAINS=("clinical" "administrative" "financial" "pharmacy" "device" "reference")
if [[ ! " ${VALID_DOMAINS[@]} " =~ " ${DOMAIN} " ]]; then
  echo "ERROR: Invalid domain. Must be one of: ${VALID_DOMAINS[@]}"
  exit 1
fi

echo "Topic name validation passed"
exit 0
```

## Topic Creation Process

### Approval Workflow

All new topics require approval through the following workflow:

1. **Topic Request**: Developer submits topic request form with:
   - Proposed topic name
   - Business justification
   - Expected message volume
   - Retention requirements
   - Data classification
   - Producer/consumer applications

2. **Domain Owner Review**: Domain owner reviews request for:
   - Alignment with domain data model
   - Compliance with naming conventions
   - Duplication prevention
   - Appropriate data classification

3. **Architecture Review**: Architecture team reviews for:
   - Alignment with event-driven patterns
   - Integration with existing event flows
   - Schema compatibility
   - Performance considerations

4. **Security Review**: Security team reviews for:
   - Data privacy requirements
   - Access control needs
   - Compliance requirements
   - Audit logging requirements

5. **Approval and Creation**: Upon approval, DevOps team creates the topic with appropriate:
   - Partitioning
   - Replication factor
   - Retention policy
   - Access controls

### Topic Request Template

```yaml
# Topic Request Form
topic:
  name: clinical.patient.admitted
  description: Events for patient admissions to facilities
  domain: clinical
  entity: patient
  event_type: admitted
  
data:
  classification: PHI
  retention_period: 90 days
  estimated_volume: 10000 events/day
  average_message_size: 2KB
  
schema:
  type: avro
  registry: true
  evolution_compatibility: BACKWARD
  
producers:
  - application: admission-service
    team: patient-management
    
consumers:
  - application: bed-management-service
    team: facilities
  - application: notification-service
    team: communications
  
compliance:
  hipaa_relevant: true
  audit_trail_required: true
  data_lineage_required: true
```

## Topic Ownership and Stewardship

### Domain Ownership Model

Each topic domain has a designated owner responsible for:

- Approving new topics within their domain
- Ensuring consistent data modeling
- Maintaining domain-specific documentation
- Reviewing schema changes
- Coordinating cross-domain integrations

### Topic Stewardship Responsibilities

Each individual topic has a designated steward responsible for:

- Maintaining topic documentation
- Reviewing and approving schema changes
- Monitoring topic health and performance
- Managing access control
- Coordinating with producers and consumers

## Topic Metadata Management

All topics must be registered in the central Topic Registry with complete metadata:

```json
{
  "topicName": "clinical.patient.admitted",
  "description": "Events for patient admissions to facilities",
  "domain": "clinical",
  "owner": {
    "team": "patient-management",
    "email": "patient-team@example.com",
    "teams": "#patient-management"
  },
  "dataClassification": "PHI",
  "retentionPolicy": {
    "period": "90d",
    "justification": "Required for operational reporting"
  },
  "partitions": 12,
  "replicationFactor": 3,
  "schemas": {
    "key": "PatientAdmittedKey",
    "value": "PatientAdmittedEvent",
    "registry": "https://schema-registry.example.com"
  },
  "producers": [
    {
      "application": "admission-service",
      "team": "patient-management",
      "contact": "admissions@example.com"
    }
  ],
  "consumers": [
    {
      "application": "bed-management-service",
      "team": "facilities",
      "contact": "facilities@example.com"
    },
    {
      "application": "notification-service",
      "team": "communications",
      "contact": "notifications@example.com"
    }
  ],
  "compliance": {
    "hipaaRelevant": true,
    "dataRetentionRequirements": "HIPAA 6-year minimum",
    "auditTrailRequired": true
  },
  "created": "2024-01-15T10:30:00Z",
  "lastUpdated": "2024-03-22T14:15:00Z"
}
```

## Topic Lifecycle Management

### Topic Creation

Topics must be created through the automated provisioning system:

```bash
# Example topic creation with governance metadata
kafka-topics --bootstrap-server kafka:9092 \
  --create \
  --topic clinical.patient.admitted \
  --partitions 12 \
  --replication-factor 3 \
  --config cleanup.policy=delete \
  --config retention.ms=7776000000 \
  --config min.insync.replicas=2

# Add topic metadata to registry
curl -X POST https://topic-registry.example.com/api/topics \
  -H "Content-Type: application/json" \
  -d @topic-metadata.json
```

### Topic Modification

Changes to topic configuration require approval through the change management process:

1. Submit change request with justification
2. Domain owner review and approval
3. Architecture review for impact assessment
4. Implementation during approved change window

```bash
# Example topic modification
kafka-configs --bootstrap-server kafka:9092 \
  --alter --entity-type topics --entity-name clinical.patient.admitted \
  --add-config retention.ms=15552000000

# Update topic metadata in registry
curl -X PATCH https://topic-registry.example.com/api/topics/clinical.patient.admitted \
  -H "Content-Type: application/json" \
  -d '{"retentionPolicy": {"period": "180d", "justification": "Extended for compliance requirements"}}'
```

### Topic Deprecation

Topics must follow a formal deprecation process:

1. **Announcement**: Notify all stakeholders of planned deprecation
2. **Producer Migration**: Move producers to new topic or pattern
3. **Consumer Migration**: Update consumers to read from new topic
4. **Monitoring Period**: Ensure no active producers or consumers
5. **Archiving**: Archive topic data if required for compliance
6. **Decommissioning**: Delete topic and update registry

```bash
# Example topic deprecation
# 1. Mark as deprecated in registry
curl -X PATCH https://topic-registry.example.com/api/topics/clinical.patient.admitted \
  -H "Content-Type: application/json" \
  -d '{"status": "DEPRECATED", "deprecationDate": "2024-06-01T00:00:00Z", "replacementTopic": "clinical.patient.encounter"}'

# 2. Archive topic data if needed
kafka-console-consumer --bootstrap-server kafka:9092 \
  --topic clinical.patient.admitted \
  --from-beginning \
  --property print.key=true \
  --property key.separator="," \
  > clinical.patient.admitted.archive

# 3. Delete topic after deprecation period
kafka-topics --bootstrap-server kafka:9092 \
  --delete --topic clinical.patient.admitted

# 4. Update registry status
curl -X PATCH https://topic-registry.example.com/api/topics/clinical.patient.admitted \
  -H "Content-Type: application/json" \
  -d '{"status": "DELETED", "deletionDate": "2024-09-01T00:00:00Z"}'
```

## Topic Access Control

### Role-Based Access Control

Access to topics is managed through role-based access control:

| Role | Permissions | Example |
|------|-------------|---------|
| Topic Owner | Full management rights | Domain team leads |
| Producer | Write access to specific topics | Application services |
| Consumer | Read access to specific topics | Analytics applications |
| Monitor | Read metadata and metrics | Operations team |
| Auditor | Read access to audit logs | Compliance team |

### Access Control Implementation

Topic access is enforced through Kafka ACLs:

```bash
# Grant producer access
kafka-acls --bootstrap-server kafka:9092 \
  --add --allow-principal User:admission-service \
  --producer --topic clinical.patient.admitted

# Grant consumer access
kafka-acls --bootstrap-server kafka:9092 \
  --add --allow-principal User:bed-management-service \
  --consumer --group bed-management \
  --topic clinical.patient.admitted

# Grant read-only access for auditors
kafka-acls --bootstrap-server kafka:9092 \
  --add --allow-principal User:compliance-auditor \
  --operation Read --topic clinical.patient.admitted
```

## Compliance and Audit

### Topic Audit Requirements

All topic management actions must be logged for audit purposes:

- Topic creation, modification, and deletion
- Access control changes
- Schema changes
- Configuration changes

### Audit Log Format

```json
{
  "timestamp": "2024-03-15T14:22:33Z",
  "action": "TOPIC_CREATE",
  "user": "john.smith@example.com",
  "resource": "clinical.patient.admitted",
  "details": {
    "partitions": 12,
    "replicationFactor": 3,
    "configs": {
      "cleanup.policy": "delete",
      "retention.ms": "7776000000"
    }
  },
  "approvals": [
    {
      "approver": "domain-owner@example.com",
      "timestamp": "2024-03-14T10:15:22Z"
    },
    {
      "approver": "architecture@example.com",
      "timestamp": "2024-03-14T16:45:10Z"
    }
  ]
}
```

### Compliance Reporting

Regular compliance reports must be generated to ensure adherence to governance policies:

- Topic naming compliance report
- Data retention compliance report
- Access control compliance report
- Schema governance compliance report

## Topic Quality Metrics

Topics are monitored for the following quality metrics:

| Metric | Description | Target | Alert Threshold |
|--------|-------------|--------|-----------------|
| Schema Compliance | Percentage of messages conforming to schema | 100% | <99.9% |
| Topic Documentation | Completeness of topic documentation | 100% | <90% |
| Consumer Coverage | Percentage of messages consumed | 100% | <99% |
| Access Control Compliance | Adherence to least privilege principle | 100% | <100% |
| Metadata Accuracy | Accuracy of topic registry metadata | 100% | <95% |

## Related Documentation

- [Schema Registry Management](schema-registry-management.md): Governance of event schemas
- [Access Control Policies](access-control-policies.md): Detailed access control implementation
- [Data Retention & Archiving](data-retention-archiving.md): Data lifecycle management
- [Topic Design](../02-core-functionality/topic-design.md): Technical aspects of topic design
