# Event Broker Maintenance

## Introduction

This document outlines the maintenance procedures and best practices for the Event Broker component of the CMM Technology Platform. Regular maintenance is essential to ensure the reliability, performance, and security of the event streaming platform. This guide covers routine maintenance tasks, upgrade procedures, and operational best practices for maintaining a healthy Event Broker environment.

## Routine Maintenance

### Daily Maintenance Tasks

#### Monitoring Health Checks

Perform daily health checks to ensure the Event Broker is functioning properly:

```bash
# Check broker status
systemctl status kafka

# Check ZooKeeper status
systemctl status zookeeper

# Check Schema Registry status
systemctl status schema-registry

# Check Kafka Connect status
systemctl status kafka-connect
```

#### Log Review

Review logs for errors and warnings:

```bash
# Check Kafka broker logs
grep -E "ERROR|WARN" /var/log/kafka/server.log

# Check ZooKeeper logs
grep -E "ERROR|WARN" /var/log/zookeeper/zookeeper.log

# Check Schema Registry logs
grep -E "ERROR|WARN" /var/log/schema-registry/schema-registry.log

# Check Kafka Connect logs
grep -E "ERROR|WARN" /var/log/kafka-connect/connect.log
```

#### Metric Review

Review key performance metrics:

```bash
# Using Prometheus query or monitoring dashboard

# Check for under-replicated partitions
kafka_server_replicamanager_underreplicatedpartitions

# Check for offline partitions
kafka_controller_offlinepartitionscount

# Check broker CPU and memory usage
rate(process_cpu_seconds_total{job="kafka"}[5m])
process_resident_memory_bytes{job="kafka"}

# Check consumer lag
kafka_consumergroup_lag
```

### Weekly Maintenance Tasks

#### Topic Cleanup

Review and clean up unnecessary topics:

```bash
# List all topics
kafka-topics --bootstrap-server kafka-broker:9092 --list

# Identify unused topics (custom script or manual review)

# Delete unused topics
kafka-topics --bootstrap-server kafka-broker:9092 \
  --delete --topic unused-topic
```

#### Consumer Group Cleanup

Review and clean up inactive consumer groups:

```bash
# List all consumer groups
kafka-consumer-groups --bootstrap-server kafka-broker:9092 --list

# Describe consumer groups to identify inactive ones
kafka-consumer-groups --bootstrap-server kafka-broker:9092 \
  --describe --all-groups | grep "Consumer group"

# Delete inactive consumer groups
kafka-consumer-groups --bootstrap-server kafka-broker:9092 \
  --delete --group inactive-group
```

#### Schema Review

Review and clean up unused schemas:

```bash
# List all subjects in Schema Registry
curl -s http://schema-registry:8081/subjects

# Check for unused subjects (custom script or manual review)

# Delete unused subjects
curl -X DELETE http://schema-registry:8081/subjects/unused-subject
```

### Monthly Maintenance Tasks

#### Disk Space Management

Review and manage disk space usage:

```bash
# Check disk usage
df -h

# Check Kafka log directory size
du -sh /var/lib/kafka/data

# Check largest topics
find /var/lib/kafka/data -type d -name "*-*" | xargs du -sh | sort -hr | head -10

# Adjust log retention if necessary
kafka-configs --bootstrap-server kafka-broker:9092 \
  --entity-type topics --entity-name large-topic \
  --alter --add-config retention.ms=604800000
```

#### Security Review

Review and update security configurations:

```bash
# List ACLs
kafka-acls --bootstrap-server kafka-broker:9092 --list

# Review SSL certificate expiration
openssl x509 -enddate -noout -in /etc/kafka/ssl/kafka.crt

# Update passwords if needed
# Update SSL certificates if nearing expiration
```

#### Performance Tuning

Review and optimize performance configurations:

```bash
# Review broker performance metrics

# Adjust broker configuration if needed
vi /etc/kafka/server.properties

# Restart broker with new configuration
systemctl restart kafka
```

### Quarterly Maintenance Tasks

#### Capacity Planning

Review and plan for capacity needs:

```bash
# Analyze growth trends
# Project future capacity requirements
# Plan for hardware/infrastructure upgrades
```

#### Disaster Recovery Testing

Test disaster recovery procedures:

```bash
# Simulate broker failure
systemctl stop kafka

# Verify automatic leader election
kafka-topics --bootstrap-server kafka-broker-2:9092 \
  --describe --topic critical-topic

# Restart broker
systemctl start kafka

# Verify recovery
kafka-topics --bootstrap-server kafka-broker:9092 \
  --describe --topic critical-topic
```

#### Documentation Update

Review and update documentation:

```bash
# Update runbooks
# Update architecture diagrams
# Update configuration documentation
```

## Upgrade Procedures

### Preparation

#### Pre-Upgrade Assessment

Before upgrading, assess the current environment:

```bash
# Document current versions
kafka-topics --version
echo "$(curl -s http://schema-registry:8081/config | jq -r '.compatibilityLevel')" \
  > schema_compatibility.txt

# Review release notes for target version
# Identify breaking changes
# Test upgrade in non-production environment
```

#### Backup Configuration

Back up current configuration:

```bash
# Back up broker configuration
cp /etc/kafka/server.properties /etc/kafka/server.properties.bak

# Back up ZooKeeper configuration
cp /etc/kafka/zookeeper.properties /etc/kafka/zookeeper.properties.bak

# Back up Schema Registry configuration
cp /etc/schema-registry/schema-registry.properties \
  /etc/schema-registry/schema-registry.properties.bak

# Back up Connect configuration
cp /etc/kafka-connect/connect-distributed.properties \
  /etc/kafka-connect/connect-distributed.properties.bak
```

#### Create Upgrade Plan

Create a detailed upgrade plan:

```
1. Communicate upgrade window to stakeholders
2. Stop dependent applications
3. Back up configurations
4. Upgrade components in specific order
5. Verify functionality
6. Resume dependent applications
7. Monitor for issues
```

### Rolling Upgrade Process

#### ZooKeeper Upgrade

Upgrade ZooKeeper nodes one at a time:

```bash
# For each ZooKeeper node

# Stop ZooKeeper
systemctl stop zookeeper

# Update ZooKeeper package
yum update confluent-zookeeper

# Start ZooKeeper
systemctl start zookeeper

# Verify ZooKeeper status
echo "ruok" | nc localhost 2181
```

#### Kafka Broker Upgrade

Upgrade Kafka brokers one at a time:

```bash
# For each broker

# Stop Kafka broker
systemctl stop kafka

# Update Kafka package
yum update confluent-server

# Update configuration if needed
vi /etc/kafka/server.properties

# Start Kafka broker
systemctl start kafka

# Verify broker status
kafka-broker-api-versions --bootstrap-server kafka-broker:9092
```

#### Schema Registry Upgrade

Upgrade Schema Registry:

```bash
# Stop Schema Registry
systemctl stop schema-registry

# Update Schema Registry package
yum update confluent-schema-registry

# Update configuration if needed
vi /etc/schema-registry/schema-registry.properties

# Start Schema Registry
systemctl start schema-registry

# Verify Schema Registry status
curl -s http://schema-registry:8081/subjects
```

#### Kafka Connect Upgrade

Upgrade Kafka Connect:

```bash
# Stop Kafka Connect
systemctl stop kafka-connect

# Update Kafka Connect package
yum update confluent-kafka-connect

# Update configuration if needed
vi /etc/kafka-connect/connect-distributed.properties

# Start Kafka Connect
systemctl start kafka-connect

# Verify Kafka Connect status
curl -s http://connect:8083/connectors
```

### Post-Upgrade Verification

#### Functionality Testing

Verify core functionality after upgrade:

```bash
# Verify topic creation
kafka-topics --bootstrap-server kafka-broker:9092 \
  --create --topic upgrade-test --partitions 1 --replication-factor 3

# Verify producer functionality
echo "test message" | kafka-console-producer --bootstrap-server kafka-broker:9092 \
  --topic upgrade-test

# Verify consumer functionality
kafka-console-consumer --bootstrap-server kafka-broker:9092 \
  --topic upgrade-test --from-beginning --max-messages 1

# Verify Schema Registry functionality
curl -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  --data '{"schema": "{\"type\": \"string\"}"}' \
  http://schema-registry:8081/subjects/upgrade-test-value/versions

# Verify Connect functionality
curl -s http://connect:8083/connector-plugins
```

#### Performance Testing

Verify performance after upgrade:

```bash
# Run performance tests
kafka-producer-perf-test --topic upgrade-test \
  --num-records 1000000 --record-size 1000 --throughput -1 \
  --producer-props bootstrap.servers=kafka-broker:9092

# Compare with pre-upgrade performance
```

#### Monitoring Review

Review monitoring metrics after upgrade:

```bash
# Check for errors in logs
grep -E "ERROR|WARN" /var/log/kafka/server.log

# Review performance metrics
# Verify no under-replicated partitions
# Verify no offline partitions
```

## Configuration Management

### Configuration Best Practices

#### Version Control

Store configurations in version control:

```bash
# Initialize Git repository for configurations
git init /etc/kafka-configs

# Add configuration files
cp /etc/kafka/server.properties /etc/kafka-configs/
cp /etc/kafka/zookeeper.properties /etc/kafka-configs/
cp /etc/schema-registry/schema-registry.properties /etc/kafka-configs/
cp /etc/kafka-connect/connect-distributed.properties /etc/kafka-configs/

# Commit configurations
cd /etc/kafka-configs
git add .
git commit -m "Initial configuration"
```

#### Configuration Templates

Use templates for consistent configuration:

```bash
# Create template for broker configuration
cp /etc/kafka/server.properties /etc/kafka-configs/templates/server.properties.template

# Use environment-specific variables
sed -i 's/broker.id=0/broker.id=${BROKER_ID}/g' \
  /etc/kafka-configs/templates/server.properties.template
```

#### Configuration Validation

Validate configuration changes before applying:

```bash
# Create validation script
cat > validate-config.sh << 'EOF'
#!/bin/bash

# Validate broker configuration
kafka-configs --bootstrap-server kafka-broker:9092 \
  --entity-type brokers --entity-default --describe > /dev/null
if [ $? -ne 0 ]; then
  echo "Invalid broker configuration"
  exit 1
fi

echo "Configuration validation passed"
EOF

chmod +x validate-config.sh
```

### Configuration Auditing

#### Audit Logging

Implement audit logging for configuration changes:

```bash
# Create audit log directory
mkdir -p /var/log/kafka-audit

# Create audit logging script
cat > config-audit.sh << 'EOF'
#!/bin/bash

# Log configuration change
echo "$(date) - $USER - $1" >> /var/log/kafka-audit/config-changes.log

# Save configuration snapshot
cp $2 /var/log/kafka-audit/snapshots/$(basename $2).$(date +%Y%m%d%H%M%S)
EOF

chmod +x config-audit.sh
```

#### Regular Audits

Perform regular configuration audits:

```bash
# Compare current configuration with baseline
diff /etc/kafka/server.properties /etc/kafka-configs/baselines/server.properties

# Review configuration audit logs
cat /var/log/kafka-audit/config-changes.log
```

## Backup and Recovery

### Backup Procedures

#### Configuration Backup

Regularly back up configurations:

```bash
# Create backup script
cat > backup-configs.sh << 'EOF'
#!/bin/bash

BACKUP_DIR=/var/backups/kafka/$(date +%Y%m%d)
mkdir -p $BACKUP_DIR

# Back up configurations
cp -r /etc/kafka $BACKUP_DIR/
cp -r /etc/schema-registry $BACKUP_DIR/
cp -r /etc/kafka-connect $BACKUP_DIR/

# Back up ZooKeeper data
zkCli.sh -server localhost:2181 get / > $BACKUP_DIR/zk-root.txt

# Back up ACLs
kafka-acls --bootstrap-server kafka-broker:9092 --list > $BACKUP_DIR/acls.txt

# Back up topic configurations
kafka-topics --bootstrap-server kafka-broker:9092 --describe > $BACKUP_DIR/topics.txt

# Back up Schema Registry schemas
curl -s http://schema-registry:8081/subjects | jq -r '.[]' | \
while read subject; do
  mkdir -p $BACKUP_DIR/schemas
  curl -s http://schema-registry:8081/subjects/$subject/versions/latest | \
    jq '.schema' > $BACKUP_DIR/schemas/$subject.json
done

# Back up Connect configurations
curl -s http://connect:8083/connectors | jq -r '.[]' | \
while read connector; do
  mkdir -p $BACKUP_DIR/connectors
  curl -s http://connect:8083/connectors/$connector/config | \
    jq '.' > $BACKUP_DIR/connectors/$connector.json
done
EOF

chmod +x backup-configs.sh
```

#### Data Backup

Implement data backup for critical topics:

```bash
# Create data backup script
cat > backup-data.sh << 'EOF'
#!/bin/bash

BACKUP_DIR=/var/backups/kafka/data/$(date +%Y%m%d)
mkdir -p $BACKUP_DIR

# List of critical topics to back up
CRITICAL_TOPICS="topic1 topic2 topic3"

for topic in $CRITICAL_TOPICS; do
  # Create backup directory for topic
  mkdir -p $BACKUP_DIR/$topic
  
  # Consume and save messages
  kafka-console-consumer --bootstrap-server kafka-broker:9092 \
    --topic $topic --from-beginning --max-messages 1000000 \
    --property print.key=true --property key.separator=: \
    > $BACKUP_DIR/$topic/messages.txt
done
EOF

chmod +x backup-data.sh
```

### Recovery Procedures

#### Configuration Recovery

Restore configurations from backup:

```bash
# Create recovery script
cat > recover-configs.sh << 'EOF'
#!/bin/bash

BACKUP_DIR=$1

if [ ! -d "$BACKUP_DIR" ]; then
  echo "Backup directory not found: $BACKUP_DIR"
  exit 1
fi

# Stop services
systemctl stop kafka kafka-connect schema-registry

# Restore configurations
cp -r $BACKUP_DIR/kafka /etc/
cp -r $BACKUP_DIR/schema-registry /etc/
cp -r $BACKUP_DIR/kafka-connect /etc/

# Start services
systemctl start kafka schema-registry kafka-connect

# Verify services
systemctl status kafka schema-registry kafka-connect
EOF

chmod +x recover-configs.sh
```

#### Data Recovery

Restore data for critical topics:

```bash
# Create data recovery script
cat > recover-data.sh << 'EOF'
#!/bin/bash

BACKUP_DIR=$1
TOPIC=$2

if [ ! -d "$BACKUP_DIR/$TOPIC" ]; then
  echo "Backup not found for topic: $TOPIC"
  exit 1
fi

# Create topic if it doesn't exist
kafka-topics --bootstrap-server kafka-broker:9092 \
  --create --topic $TOPIC --partitions 3 --replication-factor 3 \
  --if-not-exists

# Produce messages from backup
cat $BACKUP_DIR/$TOPIC/messages.txt | \
kafka-console-producer --bootstrap-server kafka-broker:9092 \
  --topic $TOPIC --property parse.key=true \
  --property key.separator=:
EOF

chmod +x recover-data.sh
```

## Healthcare-Specific Maintenance

### PHI Data Management

#### PHI Audit Procedures

Implement regular PHI access auditing:

```bash
# Create PHI audit script
cat > phi-audit.sh << 'EOF'
#!/bin/bash

# List of topics containing PHI
PHI_TOPICS="clinical.patient.* patient.demographics.*"

# Get ACLs for PHI topics
for pattern in $PHI_TOPICS; do
  echo "ACLs for $pattern:"
  kafka-acls --bootstrap-server kafka-broker:9092 \
    --list --topic $pattern
done

# Check consumer groups accessing PHI topics
kafka-consumer-groups --bootstrap-server kafka-broker:9092 --list | \
while read group; do
  kafka-consumer-groups --bootstrap-server kafka-broker:9092 \
    --describe --group $group | grep -E "$(echo $PHI_TOPICS | tr ' ' '|')"
  if [ $? -eq 0 ]; then
    echo "Consumer group accessing PHI: $group"
  fi
done
EOF

chmod +x phi-audit.sh
```

#### PHI Retention Management

Manage PHI data retention according to policies:

```bash
# Create PHI retention management script
cat > phi-retention.sh << 'EOF'
#!/bin/bash

# List of topics containing PHI with retention policies
declare -A PHI_TOPICS
PHI_TOPICS["clinical.patient.admitted"]="2592000000"  # 30 days
PHI_TOPICS["clinical.patient.discharged"]="2592000000"  # 30 days
PHI_TOPICS["patient.demographics.updated"]="7776000000"  # 90 days

# Set retention policies
for topic in "${!PHI_TOPICS[@]}"; do
  retention=${PHI_TOPICS[$topic]}
  echo "Setting retention for $topic to $retention ms"
  kafka-configs --bootstrap-server kafka-broker:9092 \
    --entity-type topics --entity-name $topic \
    --alter --add-config retention.ms=$retention
done
EOF

chmod +x phi-retention.sh
```

### Regulatory Compliance

#### Compliance Audit Preparation

Prepare for regulatory compliance audits:

```bash
# Create compliance documentation script
cat > compliance-docs.sh << 'EOF'
#!/bin/bash

DOC_DIR=/var/compliance/kafka/$(date +%Y%m%d)
mkdir -p $DOC_DIR

# Document data flows
echo "Documenting Kafka data flows..."
kafka-topics --bootstrap-server kafka-broker:9092 --list > $DOC_DIR/topics.txt

# Document access controls
echo "Documenting access controls..."
kafka-acls --bootstrap-server kafka-broker:9092 --list > $DOC_DIR/acls.txt

# Document data retention policies
echo "Documenting retention policies..."
kafka-topics --bootstrap-server kafka-broker:9092 --list | \
while read topic; do
  kafka-configs --bootstrap-server kafka-broker:9092 \
    --entity-type topics --entity-name $topic --describe >> $DOC_DIR/retention-policies.txt
done

# Document encryption settings
echo "Documenting encryption settings..."
grep -E "ssl\." /etc/kafka/server.properties > $DOC_DIR/encryption-settings.txt

# Document audit logging
echo "Documenting audit logging..."
grep -E "audit" /etc/kafka/server.properties > $DOC_DIR/audit-settings.txt

echo "Compliance documentation generated in $DOC_DIR"
EOF

chmod +x compliance-docs.sh
```

#### Compliance Monitoring

Implement compliance monitoring:

```bash
# Create compliance monitoring script
cat > compliance-monitor.sh << 'EOF'
#!/bin/bash

# Check encryption
if ! grep -q "ssl.enabled.protocols" /etc/kafka/server.properties; then
  echo "COMPLIANCE ISSUE: SSL not enabled"
fi

# Check authentication
if ! grep -q "sasl.enabled.mechanisms" /etc/kafka/server.properties; then
  echo "COMPLIANCE ISSUE: SASL authentication not enabled"
fi

# Check authorization
if ! grep -q "authorizer.class.name" /etc/kafka/server.properties; then
  echo "COMPLIANCE ISSUE: Authorization not enabled"
fi

# Check audit logging
if ! grep -q "audit" /etc/kafka/server.properties; then
  echo "COMPLIANCE ISSUE: Audit logging not enabled"
fi

# Check PHI topic retention
kafka-topics --bootstrap-server kafka-broker:9092 --list | grep -E "clinical\.patient\.|\.phi\." | \
while read topic; do
  retention=$(kafka-configs --bootstrap-server kafka-broker:9092 \
    --entity-type topics --entity-name $topic --describe | \
    grep "retention.ms" | awk '{print $4}')
  
  if [ -z "$retention" ] || [ "$retention" -gt 7776000000 ]; then
    echo "COMPLIANCE ISSUE: Topic $topic has no retention policy or exceeds 90 days"
  fi
done
EOF

chmod +x compliance-monitor.sh
```

## Conclusion

Regular and systematic maintenance of the Event Broker is essential for ensuring its reliability, performance, and security. By following the procedures outlined in this document, operators can maintain a healthy event streaming platform that meets the demanding requirements of healthcare applications. Proper maintenance not only prevents issues but also ensures compliance with regulatory requirements and enables the platform to scale as needs evolve.

## Related Documentation

- [Event Broker Architecture](../01-getting-started/architecture.md)
- [Monitoring](./monitoring.md)
- [Scaling](./scaling.md)
- [Troubleshooting](./troubleshooting.md)
