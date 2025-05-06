# Event Broker Access Controls

## Introduction
The Event Broker implements a comprehensive access control model to govern who can publish, consume, and administer event streams. This documentation outlines the access control mechanisms that enforce the principle of least privilege while enabling efficient event-driven workflows across CoverMyMeds.

## Role-Based Access Control (RBAC)
The Event Broker uses Confluent's Role-Based Access Control (RBAC) system integrated with our enterprise identity provider.

| Role | Description | Permissions |
|------|-------------|------------|
| **EventBroker.Admin** | Full administrative access | Create/delete/configure topics, modify ACLs, manage schema registry, configure broker settings |
| **EventBroker.TopicAdmin** | Topic administration within assigned domains | Create/configure topics within specific domain namespaces, manage consumer groups |
| **EventBroker.Producer** | Event publishing permissions | Write to specific topics, register/update schemas |
| **EventBroker.Consumer** | Event consumption permissions | Read from specific topics, create/manage consumer groups |
| **EventBroker.Monitor** | Monitoring-only access | View metrics, topic configurations, consumer lag statistics |
| **EventBroker.SchemaAdmin** | Schema Registry administration | Create/update/delete schemas, manage compatibility settings |

## Policy Enforcement
Access controls are enforced at multiple layers:

1. **Kafka ACLs (Access Control Lists)**: Fine-grained permissions at the topic, consumer group, and cluster levels
2. **Schema Registry Authorization**: Controls who can register and evolve schemas
3. **API Gateway Authorization**: Policy enforcement at the REST API gateway layer
4. **Client Authentication**: TLS mutual authentication for client-broker communication

Security policies are defined declaratively through our GitOps workflow and automatically enforced through our control plane.

## Authentication Integration
The Event Broker supports the following authentication mechanisms:

- **OAuth 2.0**: Primary authentication method integrated with Azure AD
- **mTLS (Mutual TLS)**: Certificate-based authentication for service-to-service communication
- **SASL/SCRAM**: Username/password authentication as a fallback mechanism
- **Service Accounts**: For automated processes and CI/CD pipelines

## Example Policy (YAML)

```yaml
# Access control policy for patient-data domain
kind: KafkaAccessPolicy
apiVersion: kafka.covermymeds.com/v1
metadata:
  name: patient-data-access
  namespace: healthcare-events
spec:
  subjects:
    - kind: Group
      name: PatientService.Producers
      provider: AzureAD
    - kind: ServiceAccount
      name: clinical-alerts-service
  resourcePatterns:
    - resourceType: Topic
      name: "patient-data.*"
      patternType: PREFIXED
  permission: WRITE
  
  # Additional settings
  requiredSchemaValidation: true
  auditLoggingEnabled: true
```

## Related Resources
- [Event Broker Audit Compliance](./audit-compliance.md)
- [Event Broker Data Governance](./data-governance.md)
- [Topic Governance](./topic-governance.md)