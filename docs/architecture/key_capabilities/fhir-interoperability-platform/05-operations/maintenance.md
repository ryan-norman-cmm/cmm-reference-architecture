# FHIR Interoperability Platform Maintenance

## Introduction
This document outlines the maintenance strategy and procedures for the FHIR Interoperability Platform. Regular maintenance is essential for ensuring the platform's reliability, performance, security, and compliance with evolving healthcare standards. This document provides guidance on routine maintenance tasks, upgrade procedures, backup strategies, and other essential operational activities.

## Maintenance Types

The FHIR Interoperability Platform requires several types of maintenance activities:

### Preventive Maintenance

Preventive maintenance activities are performed on a regular schedule to prevent problems before they occur:

| Maintenance Type | Purpose | Frequency | Responsible Team |
|------------------|---------|-----------|------------------|
| Database Optimization | Maintain optimal database performance | Weekly | Database Team |
| Log Rotation | Prevent log file overflow | Daily (Automated) | Platform Team |
| Certificate Renewal | Prevent certificate expiration | 30 days before expiry | Security Team |
| Storage Cleanup | Prevent storage exhaustion | Weekly | Platform Team |
| Backup Verification | Ensure backup integrity | Weekly | Infrastructure Team |
| Security Patch Application | Address security vulnerabilities | Monthly | Security Team |
| Configuration Review | Ensure configuration correctness | Monthly | Platform Team |
| Monitoring Review | Verify monitoring effectiveness | Monthly | Operations Team |

### Corrective Maintenance

Corrective maintenance activities are performed in response to identified issues:

| Maintenance Type | Purpose | Trigger | Responsible Team |
|------------------|---------|---------|------------------|
| Bug Fixes | Address software defects | Bug report or detection | Development Team |
| Performance Tuning | Address performance degradation | Performance alerts | Platform Team |
| Error Resolution | Address recurring errors | Error rate alerts | Platform Team |
| Resource Scaling | Address resource constraints | Resource utilization alerts | Infrastructure Team |
| Data Correction | Fix data integrity issues | Data validation errors | Data Team |
| Service Recovery | Restore service after failure | Service outage | On-call Team |

### Adaptive Maintenance

Adaptive maintenance activities are performed to adapt to changing requirements:

| Maintenance Type | Purpose | Trigger | Responsible Team |
|------------------|---------|---------|------------------|
| Version Upgrades | Update to newer software versions | Release of new versions | Platform Team |
| FHIR Version Updates | Support newer FHIR versions | Release of new FHIR versions | Development Team |
| Scaling | Adapt to increased demand | Capacity planning | Infrastructure Team |
| Regulatory Compliance | Meet new regulatory requirements | Regulatory changes | Compliance Team |
| Terminology Updates | Implement new terminology | Release of terminology updates | Development Team |
| Implementation Guide Updates | Support new implementation guides | Release of new IGs | Development Team |

### Perfective Maintenance

Perfective maintenance activities are performed to improve the system without changing its functionality:

| Maintenance Type | Purpose | Trigger | Responsible Team |
|------------------|---------|---------|------------------|
| Code Refactoring | Improve code quality | Technical debt assessment | Development Team |
| Documentation Updates | Improve documentation | User feedback | Documentation Team |
| UI/UX Improvements | Enhance user experience | User feedback | Design Team |
| Monitoring Enhancements | Improve observability | Operational review | Operations Team |
| Performance Optimization | Enhance system performance | Performance analysis | Platform Team |
| Security Hardening | Strengthen security posture | Security assessment | Security Team |

## Maintenance Procedures

### Database Maintenance

#### Database Optimization

```bash
#!/bin/bash
# Database Optimization Script
# Purpose: Performs routine maintenance on the FHIR database

# Set environment variables
export PGHOST="fhir-db.internal"
export PGUSER="postgres"
export PGDATABASE="fhir_db"
export PGPASSWORD="$(kubectl get secret fhir-db-credentials -o jsonpath='{.data.password}' | base64 -d)"

echo "Starting database maintenance at $(date)"

# Vacuum analyze all tables
echo "Running VACUUM ANALYZE..."
psql -c "VACUUM ANALYZE;"

# Reindex all tables
echo "Reindexing all tables..."
psql -c "REINDEX DATABASE ${PGDATABASE};"

# Update statistics
echo "Updating statistics..."
psql -c "ANALYZE;"

# Check for bloated tables and vacuum them
echo "Checking for bloated tables..."
psql -c "
SELECT schemaname, relname, n_dead_tup, n_live_tup,
       round(n_dead_tup * 100.0 / (n_live_tup + n_dead_tup), 2) AS dead_percentage
FROM pg_stat_user_tables
WHERE n_dead_tup > 10000
ORDER BY dead_percentage DESC;
" | while read -r line; do
  if [[ $line =~ [0-9]+\.[0-9]+ ]]; then
    schema=$(echo $line | awk '{print $1}')
    table=$(echo $line | awk '{print $2}')
    echo "Vacuuming bloated table: $schema.$table"
    psql -c "VACUUM FULL ANALYZE $schema.$table;"
  fi
done

# Identify and kill long-running queries
echo "Checking for long-running queries..."
psql -c "
SELECT pid, now() - query_start AS duration, query
FROM pg_stat_activity
WHERE state = 'active' AND now() - query_start > interval '30 minutes'
AND query NOT LIKE '%pg_stat_activity%'
ORDER BY duration DESC;
" | while read -r line; do
  if [[ $line =~ ^[0-9]+ ]]; then
    pid=$(echo $line | awk '{print $1}')
    echo "Terminating long-running query (PID: $pid)"
    psql -c "SELECT pg_terminate_backend($pid);"
  fi
done

# Check for invalid indexes
echo "Checking for invalid indexes..."
psql -c "
SELECT
    t.schemaname,
    t.tablename,
    i.indexname,
    i.indexdef
FROM pg_indexes i
JOIN pg_tables t ON i.tablename = t.tablename AND i.schemaname = t.schemaname
LEFT JOIN pg_class c ON c.relname = i.indexname
LEFT JOIN pg_index idx ON idx.indexrelid = c.oid
WHERE idx.indisvalid IS FALSE OR idx.indisvalid IS NULL
ORDER BY t.schemaname, t.tablename;
" | while read -r line; do
  if [[ $line =~ indexname ]]; then
    schema=$(echo $line | awk '{print $1}')
    table=$(echo $line | awk '{print $2}')
    index=$(echo $line | awk '{print $3}')
    echo "Rebuilding invalid index: $schema.$index"
    psql -c "REINDEX INDEX $schema.$index;"
  fi
done

echo "Database maintenance completed at $(date)"
```

#### Backup and Recovery

```bash
#!/bin/bash
# FHIR Database Backup Script
# Purpose: Creates a comprehensive backup of the FHIR database

# Set environment variables
export PGHOST="fhir-db.internal"
export PGUSER="postgres"
export PGDATABASE="fhir_db"
export PGPASSWORD="$(kubectl get secret fhir-db-credentials -o jsonpath='{.data.password}' | base64 -d)"
export BACKUP_DIR="/backup/fhir-db"
export S3_BUCKET="cmm-fhir-backups"
export RETENTION_DAYS="30"

# Create timestamped backup directory
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="${BACKUP_DIR}/${TIMESTAMP}"
mkdir -p ${BACKUP_PATH}

echo "Starting FHIR database backup at $(date)"

# Perform full database dump
echo "Creating full database dump..."
pg_dump -Fc -v -f "${BACKUP_PATH}/fhir_db_full.dump"

# Backup specific critical tables with data
echo "Backing up critical tables..."
for TABLE in "Patient" "Practitioner" "Organization" "Encounter" "Observation" "MedicationRequest"; do
    echo "Backing up table: ${TABLE}..."
    pg_dump -Fc -v -t "${TABLE}" -f "${BACKUP_PATH}/${TABLE}.dump"
done

# Create database schema only backup
echo "Creating schema-only backup..."
pg_dump -Fc -v --schema-only -f "${BACKUP_PATH}/fhir_db_schema.dump"

# Compress the backup directory
echo "Compressing backup..."
tar -czf "${BACKUP_DIR}/fhir_db_${TIMESTAMP}.tar.gz" -C "${BACKUP_DIR}" "${TIMESTAMP}"

# Upload to S3
echo "Uploading backup to S3..."
aws s3 cp "${BACKUP_DIR}/fhir_db_${TIMESTAMP}.tar.gz" "s3://${S3_BUCKET}/daily/"

# Keep monthly backup
DAY_OF_MONTH=$(date +%d)
if [ "${DAY_OF_MONTH}" == "01" ]; then
    echo "Creating monthly backup..."
    aws s3 cp "${BACKUP_DIR}/fhir_db_${TIMESTAMP}.tar.gz" "s3://${S3_BUCKET}/monthly/fhir_db_$(date +%Y%m)_01.tar.gz"
fi

# Clean up old backups
echo "Cleaning up old backups..."
find "${BACKUP_DIR}" -name "fhir_db_*.tar.gz" -type f -mtime +${RETENTION_DAYS} -delete
rm -rf "${BACKUP_PATH}"

# List backups older than retention period in S3 and delete them
echo "Cleaning up old S3 backups..."
aws s3 ls "s3://${S3_BUCKET}/daily/" | grep "fhir_db_" | awk '{print $4}' | while read -r backup; do
    backup_date=$(echo $backup | sed -E 's/fhir_db_([0-9]{8})_.*/\1/')
    backup_timestamp=$(date -d "${backup_date}" +%s)
    current_timestamp=$(date +%s)
    days_old=$(( (current_timestamp - backup_timestamp) / 86400 ))
    
    if [ ${days_old} -gt ${RETENTION_DAYS} ]; then
        echo "Deleting old S3 backup: $backup"
        aws s3 rm "s3://${S3_BUCKET}/daily/${backup}"
    fi
done

echo "Backup completed at $(date)"
```

### FHIR Server Maintenance

#### Configuration Update Procedure

```bash
#!/bin/bash
# FHIR Server Configuration Update Procedure
# Purpose: Updates the FHIR server configuration with zero downtime

# Set environment variables
export NAMESPACE="fhir-interoperability"
export CONFIG_MAP="fhir-server-config"
export DEPLOYMENT="fhir-server"

echo "Starting FHIR server configuration update at $(date)"

# Backup current configuration
echo "Backing up current configuration..."
kubectl get configmap ${CONFIG_MAP} -n ${NAMESPACE} -o yaml > ${CONFIG_MAP}_backup_$(date +%Y%m%d_%H%M%S).yaml

# Apply updated configuration
echo "Applying updated configuration..."
kubectl apply -f updated_${CONFIG_MAP}.yaml -n ${NAMESPACE}

# Perform rolling restart of pods to pick up new configuration
echo "Performing rolling restart of pods..."
kubectl rollout restart deployment/${DEPLOYMENT} -n ${NAMESPACE}

# Watch rollout status
echo "Watching rollout status..."
kubectl rollout status deployment/${DEPLOYMENT} -n ${NAMESPACE}

# Verify new configuration is active
echo "Verifying new configuration..."
kubectl exec -it $(kubectl get pods -n ${NAMESPACE} -l app=${DEPLOYMENT} -o jsonpath='{.items[0].metadata.name}') -n ${NAMESPACE} -- curl -s localhost:8080/health | jq '.config_version'

echo "Configuration update completed at $(date)"
```

#### Upgrade Procedure

```bash
#!/bin/bash
# FHIR Server Upgrade Procedure
# Purpose: Upgrades the FHIR server to a new version with zero downtime

# Set environment variables
export NAMESPACE="fhir-interoperability"
export DEPLOYMENT="fhir-server"
export NEW_VERSION="$1"
export HELM_RELEASE="fhir-platform"
export VALUES_FILE="helm/values/production.yaml"

if [ -z "$NEW_VERSION" ]; then
    echo "Error: Version number required"
    echo "Usage: $0 <version>"
    exit 1
fi

echo "Starting FHIR server upgrade to version ${NEW_VERSION} at $(date)"

# Verify deployment exists
echo "Verifying deployment exists..."
kubectl get deployment ${DEPLOYMENT} -n ${NAMESPACE} || { echo "Deployment not found"; exit 1; }

# Get current version for rollback
CURRENT_VERSION=$(kubectl get deployment ${DEPLOYMENT} -n ${NAMESPACE} -o jsonpath='{.spec.template.spec.containers[0].image}' | cut -d: -f2)
echo "Current version: ${CURRENT_VERSION}"

# Back up current state
echo "Backing up current state..."
kubectl get deployment ${DEPLOYMENT} -n ${NAMESPACE} -o yaml > ${DEPLOYMENT}_backup_${CURRENT_VERSION}.yaml

# Update Helm values with new version
echo "Updating Helm values with new version..."
sed -i "s/tag: \".*\"/tag: \"${NEW_VERSION}\"/" ${VALUES_FILE}

# Perform the upgrade
echo "Performing the upgrade..."
helm upgrade ${HELM_RELEASE} ./helm/fhir-platform --namespace ${NAMESPACE} --values ${VALUES_FILE}

# Watch rollout status
echo "Watching rollout status..."
kubectl rollout status deployment/${DEPLOYMENT} -n ${NAMESPACE}

# Verify new version is running
echo "Verifying new version..."
NEW_RUNNING_VERSION=$(kubectl get deployment ${DEPLOYMENT} -n ${NAMESPACE} -o jsonpath='{.spec.template.spec.containers[0].image}' | cut -d: -f2)
echo "New running version: ${NEW_RUNNING_VERSION}"

if [ "${NEW_RUNNING_VERSION}" != "${NEW_VERSION}" ]; then
    echo "ERROR: Version mismatch! Expected ${NEW_VERSION}, got ${NEW_RUNNING_VERSION}"
    echo "Rolling back..."
    helm rollback ${HELM_RELEASE} 0 --namespace ${NAMESPACE}
    exit 1
fi

# Test the new version
echo "Testing the new version..."
kubectl exec -it $(kubectl get pods -n ${NAMESPACE} -l app=${DEPLOYMENT} -o jsonpath='{.items[0].metadata.name}') -n ${NAMESPACE} -- curl -s localhost:8080/health | jq

# Monitor for any issues
echo "Monitoring for any issues for 10 minutes..."
start_time=$(date +%s)
end_time=$((start_time + 600))
no_errors=true

while [ $(date +%s) -lt $end_time ]; do
    error_count=$(kubectl logs --since=1m -l app=${DEPLOYMENT} -n ${NAMESPACE} | grep -c "ERROR")
    if [ $error_count -gt 0 ]; then
        echo "WARNING: Errors detected in logs!"
        no_errors=false
        break
    fi
    echo -n "."
    sleep 30
done
echo ""

if $no_errors; then
    echo "Upgrade successful and stable."
else
    echo "Upgrade completed with warnings. Please check logs."
fi

echo "Upgrade completed at $(date)"
```

### Terminology Maintenance

#### Terminology Update Procedure

```bash
#!/bin/bash
# Terminology Update Procedure
# Purpose: Updates FHIR terminology resources (CodeSystems and ValueSets)

# Set environment variables
export FHIR_SERVER="https://fhir-api.covermymeds.com/fhir/r4"
export AUTH_TOKEN="$(kubectl get secret fhir-api-token -o jsonpath='{.data.token}' | base64 -d)"
export TERMINOLOGY_DIR="./terminology"

echo "Starting terminology update at $(date)"

# Function to create or update a CodeSystem
update_code_system() {
    local file=$1
    local id=$(jq -r '.id' $file)
    local version=$(jq -r '.version' $file)
    
    echo "Processing CodeSystem: $id (version $version)"
    
    # Check if CodeSystem exists
    status_code=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $AUTH_TOKEN" "$FHIR_SERVER/CodeSystem/$id")
    
    if [ "$status_code" == "200" ]; then
        echo "CodeSystem exists, updating..."
        curl -X PUT -H "Content-Type: application/fhir+json" -H "Authorization: Bearer $AUTH_TOKEN" -d @$file "$FHIR_SERVER/CodeSystem/$id"
    else
        echo "CodeSystem does not exist, creating..."
        curl -X POST -H "Content-Type: application/fhir+json" -H "Authorization: Bearer $AUTH_TOKEN" -d @$file "$FHIR_SERVER/CodeSystem"
    fi
    
    echo ""
}

# Function to create or update a ValueSet
update_value_set() {
    local file=$1
    local id=$(jq -r '.id' $file)
    local version=$(jq -r '.version' $file)
    
    echo "Processing ValueSet: $id (version $version)"
    
    # Check if ValueSet exists
    status_code=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $AUTH_TOKEN" "$FHIR_SERVER/ValueSet/$id")
    
    if [ "$status_code" == "200" ]; then
        echo "ValueSet exists, updating..."
        curl -X PUT -H "Content-Type: application/fhir+json" -H "Authorization: Bearer $AUTH_TOKEN" -d @$file "$FHIR_SERVER/ValueSet/$id"
    else
        echo "ValueSet does not exist, creating..."
        curl -X POST -H "Content-Type: application/fhir+json" -H "Authorization: Bearer $AUTH_TOKEN" -d @$file "$FHIR_SERVER/ValueSet"
    fi
    
    # If ValueSet is expansible, trigger expansion
    if jq -e '.compose' $file > /dev/null; then
        echo "Triggering ValueSet expansion..."
        curl -X GET -H "Authorization: Bearer $AUTH_TOKEN" "$FHIR_SERVER/ValueSet/$id/\$expand"
    fi
    
    echo ""
}

# Update CodeSystems first
echo "Updating CodeSystems..."
find $TERMINOLOGY_DIR -name "CodeSystem-*.json" | while read -r file; do
    update_code_system "$file"
done

# Then update ValueSets
echo "Updating ValueSets..."
find $TERMINOLOGY_DIR -name "ValueSet-*.json" | while read -r file; do
    update_value_set "$file"
done

echo "Terminology update completed at $(date)"
```

#### FHIR Implementation Guide Installation

```bash
#!/bin/bash
# FHIR Implementation Guide Installation
# Purpose: Installs a new FHIR Implementation Guide into the FHIR server

# Set environment variables
export FHIR_SERVER="https://fhir-api.covermymeds.com/fhir/r4"
export AUTH_TOKEN="$(kubectl get secret fhir-api-token -o jsonpath='{.data.token}' | base64 -d)"
export IG_PACKAGE_URL="$1"
export IG_ID="$2"

if [ -z "$IG_PACKAGE_URL" ] || [ -z "$IG_ID" ]; then
    echo "Error: Implementation Guide package URL and ID required"
    echo "Usage: $0 <package_url> <ig_id>"
    exit 1
fi

echo "Starting Implementation Guide installation at $(date)"
echo "Implementation Guide: $IG_ID"
echo "Package URL: $IG_PACKAGE_URL"

# Create a temporary directory
TEMP_DIR=$(mktemp -d)
cd $TEMP_DIR

# Download the IG package
echo "Downloading implementation guide package..."
curl -L -o ig_package.tgz $IG_PACKAGE_URL

# Extract the package
echo "Extracting package..."
tar -xf ig_package.tgz

# Process the package
echo "Processing package..."

# Install ImplementationGuide resource
if [ -f "package/ImplementationGuide-$IG_ID.json" ]; then
    echo "Installing ImplementationGuide resource..."
    curl -X PUT -H "Content-Type: application/fhir+json" -H "Authorization: Bearer $AUTH_TOKEN" -d @"package/ImplementationGuide-$IG_ID.json" "$FHIR_SERVER/ImplementationGuide/$IG_ID"
fi

# Install StructureDefinition resources
echo "Installing StructureDefinition resources..."
find package -name "StructureDefinition-*.json" | while read -r file; do
    id=$(jq -r '.id' "$file")
    echo "Installing StructureDefinition: $id"
    curl -X PUT -H "Content-Type: application/fhir+json" -H "Authorization: Bearer $AUTH_TOKEN" -d @"$file" "$FHIR_SERVER/StructureDefinition/$id"
done

# Install CodeSystem resources
echo "Installing CodeSystem resources..."
find package -name "CodeSystem-*.json" | while read -r file; do
    id=$(jq -r '.id' "$file")
    echo "Installing CodeSystem: $id"
    curl -X PUT -H "Content-Type: application/fhir+json" -H "Authorization: Bearer $AUTH_TOKEN" -d @"$file" "$FHIR_SERVER/CodeSystem/$id"
done

# Install ValueSet resources
echo "Installing ValueSet resources..."
find package -name "ValueSet-*.json" | while read -r file; do
    id=$(jq -r '.id' "$file")
    echo "Installing ValueSet: $id"
    curl -X PUT -H "Content-Type: application/fhir+json" -H "Authorization: Bearer $AUTH_TOKEN" -d @"$file" "$FHIR_SERVER/ValueSet/$id"
done

# Install SearchParameter resources
echo "Installing SearchParameter resources..."
find package -name "SearchParameter-*.json" | while read -r file; do
    id=$(jq -r '.id' "$file")
    echo "Installing SearchParameter: $id"
    curl -X PUT -H "Content-Type: application/fhir+json" -H "Authorization: Bearer $AUTH_TOKEN" -d @"$file" "$FHIR_SERVER/SearchParameter/$id"
done

# Install CapabilityStatement resources
echo "Installing CapabilityStatement resources..."
find package -name "CapabilityStatement-*.json" | while read -r file; do
    id=$(jq -r '.id' "$file")
    echo "Installing CapabilityStatement: $id"
    curl -X PUT -H "Content-Type: application/fhir+json" -H "Authorization: Bearer $AUTH_TOKEN" -d @"$file" "$FHIR_SERVER/CapabilityStatement/$id"
done

# Install OperationDefinition resources
echo "Installing OperationDefinition resources..."
find package -name "OperationDefinition-*.json" | while read -r file; do
    id=$(jq -r '.id' "$file")
    echo "Installing OperationDefinition: $id"
    curl -X PUT -H "Content-Type: application/fhir+json" -H "Authorization: Bearer $AUTH_TOKEN" -d @"$file" "$FHIR_SERVER/OperationDefinition/$id"
done

# Clean up
echo "Cleaning up temporary files..."
cd - > /dev/null
rm -rf $TEMP_DIR

echo "Implementation Guide installation completed at $(date)"
```

### System Security Maintenance

#### Security Patch Application

```bash
#!/bin/bash
# Security Patch Application
# Purpose: Applies security patches to the FHIR server infrastructure

# Set environment variables
export NAMESPACE="fhir-interoperability"
export AWS_REGION="us-east-1"

echo "Starting security patch application at $(date)"

# Update base images for all deployments
echo "Updating base images..."
kubectl get deployments -n ${NAMESPACE} -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | while read -r deployment; do
    echo "Updating deployment: $deployment"
    kubectl set image deployment/${deployment} ${deployment}=${deployment}:latest -n ${NAMESPACE}
done

# Update EKS nodes
echo "Updating EKS worker nodes..."
cluster_name=$(aws eks list-clusters --region ${AWS_REGION} | jq -r '.clusters[0]')
nodegroup_name=$(aws eks list-nodegroups --cluster-name ${cluster_name} --region ${AWS_REGION} | jq -r '.nodegroups[0]')

echo "Upgrading nodegroup ${nodegroup_name} in cluster ${cluster_name}..."
aws eks update-nodegroup-version --cluster-name ${cluster_name} --nodegroup-name ${nodegroup_name} --region ${AWS_REGION}

# Wait for nodes to be updated
echo "Waiting for nodes to be updated..."
while true; do
    status=$(aws eks describe-nodegroup --cluster-name ${cluster_name} --nodegroup-name ${nodegroup_name} --region ${AWS_REGION} | jq -r '.nodegroup.status')
    if [ "$status" == "ACTIVE" ]; then
        break
    fi
    echo "Current status: $status"
    sleep 60
done

# Update FHIR server dependencies
echo "Updating FHIR server dependencies..."
kubectl exec -it $(kubectl get pods -n ${NAMESPACE} -l app=fhir-server -o jsonpath='{.items[0].metadata.name}') -n ${NAMESPACE} -- bash -c "apt-get update && apt-get upgrade -y"

# Update security groups
echo "Updating security groups..."
security_group_id=$(aws ec2 describe-security-groups --filters "Name=tag:Name,Values=fhir-platform-sg" --region ${AWS_REGION} | jq -r '.SecurityGroups[0].GroupId')

# Remove any overly permissive rules
echo "Removing overly permissive rules..."
aws ec2 describe-security-group-rules --filter "Name=group-id,Values=${security_group_id}" --region ${AWS_REGION} | jq -r '.SecurityGroupRules[] | select(.IpProtocol == "-1") | .SecurityGroupRuleId' | while read -r rule_id; do
    echo "Removing overly permissive rule: $rule_id"
    aws ec2 revoke-security-group-ingress --group-id ${security_group_id} --security-group-rule-ids ${rule_id} --region ${AWS_REGION}
done

echo "Security patch application completed at $(date)"
```

#### Certificate Rotation

```bash
#!/bin/bash
# Certificate Rotation Procedure
# Purpose: Rotates TLS certificates for the FHIR Interoperability Platform

# Set environment variables
export NAMESPACE="fhir-interoperability"
export SECRET_NAME="fhir-api-tls"
export CERT_DIR="./certs"
export DOMAIN="fhir-api.covermymeds.com"

echo "Starting certificate rotation at $(date)"

# Create a new certificate
echo "Creating new certificate..."
mkdir -p ${CERT_DIR}

# Using Let's Encrypt/certbot
certbot certonly --dns-route53 -d ${DOMAIN} --config-dir ${CERT_DIR} --work-dir ${CERT_DIR} --logs-dir ${CERT_DIR}

# Convert certificate to the right format
echo "Converting certificate to the right format..."
openssl pkcs12 -export -out ${CERT_DIR}/${DOMAIN}.p12 -inkey ${CERT_DIR}/live/${DOMAIN}/privkey.pem -in ${CERT_DIR}/live/${DOMAIN}/cert.pem -certfile ${CERT_DIR}/live/${DOMAIN}/chain.pem -passout pass:

# Create base64-encoded versions for Kubernetes secret
echo "Creating base64-encoded versions for Kubernetes secret..."
CERT_BASE64=$(cat ${CERT_DIR}/live/${DOMAIN}/cert.pem | base64 -w 0)
KEY_BASE64=$(cat ${CERT_DIR}/live/${DOMAIN}/privkey.pem | base64 -w 0)
CHAIN_BASE64=$(cat ${CERT_DIR}/live/${DOMAIN}/chain.pem | base64 -w 0)

# Create new secret
echo "Creating new TLS secret..."
cat <<EOF > ${CERT_DIR}/new-tls-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: ${SECRET_NAME}
  namespace: ${NAMESPACE}
type: kubernetes.io/tls
data:
  tls.crt: ${CERT_BASE64}
  tls.key: ${KEY_BASE64}
  ca.crt: ${CHAIN_BASE64}
EOF

# Apply the new secret
echo "Applying the new secret..."
kubectl apply -f ${CERT_DIR}/new-tls-secret.yaml

# Update ingress annotations to force reload
echo "Updating ingress to use new certificate..."
kubectl get ingress -n ${NAMESPACE} -o name | while read -r ingress; do
    echo "Updating $ingress"
    kubectl annotate $ingress -n ${NAMESPACE} cert-manager.io/last-renewal="$(date +%s)" --overwrite
done

# Clean up
echo "Cleaning up temporary files..."
rm -rf ${CERT_DIR}/new-tls-secret.yaml

echo "Certificate rotation completed at $(date)"
```

## Maintenance Schedule

### Routine Maintenance Schedule

| Day | Time (UTC) | Maintenance Activity | Duration | Impact |
|-----|------------|----------------------|----------|--------|
| Daily | 01:00-01:30 | Log rotation and archival | 30 min | None |
| Daily | 02:00-03:00 | Database backups | 1 hour | None |
| Weekly (Sunday) | 01:00-03:00 | Database optimization | 2 hours | Possible brief slowdowns |
| Weekly (Sunday) | 03:00-04:00 | Storage cleanup | 1 hour | None |
| Monthly (1st Sunday) | 01:00-04:00 | Security patches | 3 hours | Possible brief downtime |
| Monthly (2nd Sunday) | 01:00-03:00 | Configuration review | 2 hours | None |
| Quarterly | 01:00-05:00 | Version upgrades | 4 hours | Possible brief downtime |
| Yearly | As scheduled | Major version upgrades | 8 hours | Scheduled downtime |

### Release Schedule

The FHIR Interoperability Platform follows a predictable release schedule:

| Release Type | Frequency | Notice Period | Scope |
|--------------|-----------|---------------|-------|
| Patch Releases | Bi-weekly | 48 hours | Bug fixes, minor improvements |
| Minor Releases | Quarterly | 2 weeks | New features, non-breaking changes |
| Major Releases | Yearly | 2 months | Breaking changes, architecture updates |

### Maintenance Windows

Standard maintenance windows have been established to minimize disruption:

| Environment | Day | Time (Local) | Duration | Notes |
|-------------|-----|--------------|----------|-------|
| Development | Any day | Any time | As needed | No notice required |
| Test | Monday-Friday | 9:00-17:00 | As needed | 24 hours notice |
| Staging | Tuesday, Thursday | 19:00-23:00 | 4 hours | 48 hours notice |
| Production | Sunday | 01:00-05:00 | 4 hours | 1 week notice |

### Notification Procedures

Maintenance notifications follow this procedure:

1. **Planned Maintenance**:
   - Notification sent to stakeholders via email and Slack
   - Entry added to maintenance calendar
   - Reminder sent 24 hours before maintenance
   - Notification posted on system status page

2. **Emergency Maintenance**:
   - Immediate notification to on-call team
   - Notification to stakeholders as soon as possible
   - Post-maintenance report within 24 hours

## Example Maintenance Script

```bash
#!/bin/bash
# FHIR Interoperability Platform Maintenance Script
# Purpose: Performs routine maintenance on the FHIR Interoperability Platform

# Exit on error
set -e

# Set environment variables
export NAMESPACE="fhir-interoperability"
export FHIR_SERVER="https://fhir-api.covermymeds.com/fhir/r4"
export AUTH_TOKEN="$(kubectl get secret fhir-api-token -o jsonpath='{.data.token}' | base64 -d)"
export LOG_FILE="/var/log/fhir-maintenance/$(date +%Y%m%d)_maintenance.log"

# Ensure log directory exists
mkdir -p $(dirname $LOG_FILE)

# Log function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

# Start maintenance
log "Starting FHIR Interoperability Platform maintenance"

# Check system health before maintenance
log "Checking system health before maintenance"
health_check=$(curl -s -H "Authorization: Bearer $AUTH_TOKEN" $FHIR_SERVER/health)
if [[ $health_check == *"\"status\":\"pass\""* ]]; then
    log "System health check: PASS"
else
    log "System health check: FAIL"
    log "Aborting maintenance due to system health issues"
    exit 1
fi

# Perform database maintenance
log "Performing database maintenance"
if [ $(date +%u) -eq 7 ]; then  # Sunday
    log "Running weekly database optimization"
    ./db_optimize.sh >> $LOG_FILE 2>&1
    if [ $? -ne 0 ]; then
        log "WARNING: Database optimization failed"
    else
        log "Database optimization completed successfully"
    fi
fi

# Always run database backup
log "Running database backup"
./db_backup.sh >> $LOG_FILE 2>&1
if [ $? -ne 0 ]; then
    log "ERROR: Database backup failed"
    # Send alert
    curl -X POST "https://alerts.covermymeds.com/api/v1/alerts" \
         -H "Content-Type: application/json" \
         -d '{"title":"FHIR Platform Database Backup Failed","severity":"critical","message":"The scheduled database backup for the FHIR Interoperability Platform has failed. Please investigate immediately."}'
else
    log "Database backup completed successfully"
fi

# Log cleanup
log "Performing log cleanup"
./log_cleanup.sh >> $LOG_FILE 2>&1
if [ $? -ne 0 ]; then
    log "WARNING: Log cleanup failed"
else
    log "Log cleanup completed successfully"
fi

# Check for expired certificates
log "Checking for expiring certificates"
./cert_check.sh >> $LOG_FILE 2>&1
cert_status=$?
if [ $cert_status -eq 1 ]; then
    log "WARNING: Certificates expiring within 30 days"
    # Send alert
    curl -X POST "https://alerts.covermymeds.com/api/v1/alerts" \
         -H "Content-Type: application/json" \
         -d '{"title":"FHIR Platform Certificate Expiring Soon","severity":"warning","message":"One or more TLS certificates for the FHIR Interoperability Platform will expire within 30 days. Please schedule certificate rotation."}'
elif [ $cert_status -eq 2 ]; then
    log "CRITICAL: Certificates expiring within 7 days"
    # Send alert
    curl -X POST "https://alerts.covermymeds.com/api/v1/alerts" \
         -H "Content-Type: application/json" \
         -d '{"title":"FHIR Platform Certificate Critically Expiring","severity":"critical","message":"One or more TLS certificates for the FHIR Interoperability Platform will expire within 7 days. Immediate action required."}'
else
    log "Certificate check: All certificates valid for at least 30 days"
fi

# Perform security checks
log "Performing security checks"
./security_scan.sh >> $LOG_FILE 2>&1
if [ $? -ne 0 ]; then
    log "WARNING: Security scan found issues"
    # Send alert
    curl -X POST "https://alerts.covermymeds.com/api/v1/alerts" \
         -H "Content-Type: application/json" \
         -d '{"title":"FHIR Platform Security Issues Detected","severity":"warning","message":"Security scan has detected potential issues with the FHIR Interoperability Platform. Please review the security scan report."}'
else
    log "Security scan completed: No issues found"
fi

# Apply monthly patches on first Sunday of the month
if [ $(date +%u) -eq 7 ] && [ $(date +%d) -le 7 ]; then
    log "Running monthly security patches"
    ./apply_security_patches.sh >> $LOG_FILE 2>&1
    if [ $? -ne 0 ]; then
        log "ERROR: Security patch application failed"
        # Send alert
        curl -X POST "https://alerts.covermymeds.com/api/v1/alerts" \
             -H "Content-Type: application/json" \
             -d '{"title":"FHIR Platform Security Patch Failed","severity":"critical","message":"Application of security patches to the FHIR Interoperability Platform has failed. Manual intervention required."}'
    else
        log "Security patch application completed successfully"
    fi
fi

# Check resource utilization
log "Checking resource utilization"
./check_resources.sh >> $LOG_FILE 2>&1
resource_status=$?
if [ $resource_status -eq 1 ]; then
    log "WARNING: High resource utilization detected"
    # Send alert
    curl -X POST "https://alerts.covermymeds.com/api/v1/alerts" \
         -H "Content-Type: application/json" \
         -d '{"title":"FHIR Platform High Resource Usage","severity":"warning","message":"High resource utilization detected on the FHIR Interoperability Platform. Consider scaling resources."}'
elif [ $resource_status -eq 2 ]; then
    log "CRITICAL: Critical resource shortage detected"
    # Send alert
    curl -X POST "https://alerts.covermymeds.com/api/v1/alerts" \
         -H "Content-Type: application/json" \
         -d '{"title":"FHIR Platform Critical Resource Shortage","severity":"critical","message":"Critical resource shortage detected on the FHIR Interoperability Platform. Immediate action required to prevent service disruption."}'
else
    log "Resource check: All resources within acceptable limits"
fi

# Check system health after maintenance
log "Checking system health after maintenance"
health_check=$(curl -s -H "Authorization: Bearer $AUTH_TOKEN" $FHIR_SERVER/health)
if [[ $health_check == *"\"status\":\"pass\""* ]]; then
    log "System health check: PASS"
else
    log "System health check: FAIL"
    # Send alert
    curl -X POST "https://alerts.covermymeds.com/api/v1/alerts" \
         -H "Content-Type: application/json" \
         -d '{"title":"FHIR Platform Health Check Failed After Maintenance","severity":"critical","message":"The FHIR Interoperability Platform is reporting unhealthy status after routine maintenance. Immediate investigation required."}'
fi

# Complete maintenance
log "FHIR Interoperability Platform maintenance completed"

# Send maintenance completion notification
curl -X POST "https://alerts.covermymeds.com/api/v1/notifications" \
     -H "Content-Type: application/json" \
     -d "{\"title\":\"FHIR Platform Maintenance Completed\",\"severity\":\"info\",\"message\":\"Routine maintenance of the FHIR Interoperability Platform has been completed successfully on $(date +%Y-%m-%d).\"}"

exit 0
```

## Related Resources
- [FHIR Interoperability Platform Deployment](./deployment.md)
- [FHIR Interoperability Platform Monitoring](./monitoring.md)
- [FHIR Interoperability Platform Troubleshooting](./troubleshooting.md)
- [FHIR Interoperability Platform Architecture](../01-getting-started/architecture.md)
- [Aidbox Maintenance Documentation](https://docs.aidbox.app/getting-started/upgrading)