# Event Broker Audit Compliance

## Introduction
The Event Broker maintains comprehensive audit trails to ensure regulatory compliance, support security investigations, and provide operational visibility. This document outlines the audit framework, controls, and processes implemented to maintain compliance with healthcare industry standards and internal security requirements.

## Audit Framework

### Applicable Standards
- **HIPAA** - Health Insurance Portability and Accountability Act
- **HITRUST CSF** - Health Information Trust Alliance Common Security Framework
- **SOC 2 Type II** - Service Organization Control reporting
- **NIST 800-53** - Security and Privacy Controls
- **PCI DSS** - Payment Card Industry Data Security Standard (where applicable)

### Audit Scope
- Administrative actions on Kafka resources
- Data access patterns (read/write operations)
- Authentication and authorization attempts
- Schema registry operations
- Configuration changes
- Data retention and deletion activities

## Audit Controls

### IT General Controls
- **Change Management**: All configuration changes follow the GitOps approval workflow
- **Access Control**: RBAC with just-in-time access for administrative operations
- **Segregation of Duties**: Separation between development, operations, and security teams
- **Backup and Recovery**: Regular cluster state backups and validated recovery procedures

### Technical Controls
- **Immutable Audit Logs**: Append-only logs that cannot be modified or deleted
- **Tamper Protection**: Digital signatures and checksums on audit records
- **Separation**: Audit logs stored separately from application data
- **Redundancy**: Multiple copies of audit logs maintained across availability zones

### Administrative Controls
- **Audit Policy**: Defined audit logging requirements and retention periods
- **Review Procedures**: Regular and exception-based review processes
- **Escalation Paths**: Clear procedures for security and compliance incidents
- **Compliance Reporting**: Automated compliance dashboard for continuous monitoring

## Audit Data Collection

### Audit Events
The following events are captured in audit logs:

| Event Category | Event Types | Details Logged |
|----------------|-------------|----------------|
| **Authentication** | Login attempts, token issuance | User ID, IP, timestamp, success/failure, auth method |
| **Authorization** | Access attempts | User ID, resource, permission, result |
| **Administrative** | Topic creation/deletion, ACL changes | User ID, action, resource, parameters |
| **Schema Registry** | Schema registration, updates | User ID, schema ID, compatibility changes |
| **Data Access** | Produce/consume operations | ClientID, topic, operation type, timestamp |
| **Configuration** | Broker/topic config changes | User ID, parameter, old value, new value |
| **Resource Management** | Resource allocation, quota changes | User ID, resource type, quota values |

### Log Collection
- **Application Audit Trail**: Captured by Event Broker components directly 
- **Infrastructure Logs**: Collected from the underlying Kubernetes and cloud infrastructure
- **Integration**: All logs are forwarded to our centralized SIEM (Splunk)
- **Enrichment**: Logs are enriched with contextual information from IAM systems

### Storage
- Audit logs are stored in immutable storage for a minimum of 7 years
- Logs are encrypted at rest and in transit
- Log storage meets healthcare data retention requirements

## Audit Trails & Review

### Automated Review
- **Continuous Monitoring**: Real-time alerts for suspicious activities
- **Anomaly Detection**: ML-based detection of unusual access patterns
- **Compliance Checks**: Automated validation against policy requirements

### Manual Review
- **Periodic Reviews**: Security team performs regular audit log reviews
- **Incident Response**: Logs analyzed during security investigations
- **Compliance Audits**: External auditors review logs during assessments

### Response Procedures
1. **Alert Triage**: Security operations reviews automated alerts
2. **Investigation**: Security analysts examine relevant audit trails
3. **Incident Declaration**: Formal process if violations are confirmed
4. **Remediation**: Actions to address any compliance gaps
5. **Reporting**: Documentation of findings and actions taken

## Example Audit Log Entry

```json
{
  "eventId": "evt-9b513a7e-3b4f-42d1-a6c8-e2b71350f2f3",
  "eventType": "authorization",
  "timestamp": "2023-08-15T14:32:17.345Z",
  "sourceIp": "10.0.14.92",
  "principal": {
    "id": "svc-claims-processor",
    "type": "ServiceAccount",
    "authMethod": "mTLS"
  },
  "resource": {
    "type": "Topic",
    "name": "patient.claims.submitted",
    "cluster": "prod-us-east-1"
  },
  "action": "PRODUCE",
  "outcome": "ALLOWED",
  "reason": "AclMatch",
  "metadata": {
    "requestId": "req-67890",
    "correlationId": "c128b5d09ea7",
    "consumerGroup": null,
    "applicationId": "claims-processing-svc"
  }
}
```

## Related Resources
- [Event Broker Access Controls](./access-controls.md)
- [Event Broker Data Governance](./data-governance.md)
- [Regulatory Compliance](./regulatory-compliance.md)