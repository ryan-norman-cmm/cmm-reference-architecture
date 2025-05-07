# Federated Graph API Maintenance

## Introduction
This document outlines the maintenance procedures, schedules, and best practices for the Federated Graph API. It provides operations teams with guidance on performing regular maintenance activities while minimizing disruption to services. Effective maintenance ensures the continued reliability, performance, and security of the Federated Graph API.

## Maintenance Types

### Preventive Maintenance

Proactive maintenance performed to prevent failures:

1. **Schema Health Checks**
   - Regular schema validation and health assessment
   - Identification of deprecated schema elements
   - Schema performance analysis

2. **Resource Optimization**
   - Memory utilization monitoring and tuning
   - Connection pool optimization
   - Cache efficiency analysis

3. **Security Patching**
   - Regular security patch application
   - Dependency vulnerability scanning
   - Certificate rotation and renewal

4. **Configuration Reviews**
   - Policy and configuration audits
   - Resource allocation optimization
   - Performance tuning parameter review

### Corrective Maintenance

Reactive maintenance to address identified issues:

1. **Bug Fixes**
   - Critical bug patching
   - Performance issue remediation
   - Reliability improvement implementation

2. **Error Pattern Resolution**
   - Analysis of error patterns and trends
   - Implementation of fixes for recurring errors
   - Adjustment of error handling strategies

3. **Performance Bottleneck Resolution**
   - Identification and elimination of bottlenecks
   - Query optimization for problematic operations
   - Resource allocation adjustments

### Adaptive Maintenance

Modifications to adapt to changing requirements:

1. **Schema Evolution**
   - Schema extension for new features
   - Deprecation and removal of unused fields
   - Schema reorganization for better organization

2. **Scaling Adjustments**
   - Resource allocation changes for altered load patterns
   - Auto-scaling parameter adjustments
   - Deployment architecture changes

3. **Integration Updates**
   - Updates to external service integrations
   - Authentication and authorization changes
   - New subgraph incorporation

### Perfective Maintenance

Enhancements to improve system qualities:

1. **Performance Optimization**
   - Query execution optimization
   - Caching strategy improvements
   - Connection management enhancements

2. **Usability Improvements**
   - Error message quality improvements
   - Schema documentation enhancements
   - Developer experience improvements

3. **Monitoring Enhancements**
   - Additional metrics collection
   - Dashboard improvements
   - New alerting rules

## Maintenance Procedures

### Schema Maintenance

#### Schema Deployment

1. **Schema Validation**
   ```bash
   # Validate schema composition
   rover subgraph check federated-graph-api@prod \
     --name patient-subgraph \
     --schema ./schema.graphql
   ```

2. **Schema Deployment**
   ```bash
   # Publish subgraph schema
   rover subgraph publish federated-graph-api@prod \
     --name patient-subgraph \
     --schema ./schema.graphql \
     --routing-url https://patient-subgraph.internal:4001/graphql
   ```

3. **Post-Deployment Verification**
   ```bash
   # Verify schema composition
   rover subgraph introspect https://patient-subgraph.internal:4001/graphql > schema.graphql
   
   # Check supergraph composition
   rover supergraph compose --config ./supergraph.yaml
   ```

#### Schema Deprecation Process

1. **Mark Fields for Deprecation**
   ```graphql
   type Patient {
     # Mark field as deprecated with a reason and timeline
     address: String @deprecated(
       reason: "Use structuredAddress instead, will be removed on 2023-10-15"
     )
     
     # New replacement field
     structuredAddress: Address
   }
   ```

2. **Monitor Deprecated Field Usage**
   ```bash
   # Check usage of deprecated fields over time
   apollo client:check --queries="./src/**/*.graphql" --tagName=gql --endpoint="https://federated-graph-api.covermymeds.com/graphql"
   ```

3. **Remove Deprecated Fields**
   ```bash
   # After deprecation period, remove deprecated fields
   # Requires schema migration plan
   ```

### Router Maintenance

#### Router Configuration Updates

1. **Test Configuration Changes**
   ```bash
   # Validate configuration file
   apollo-router config validate --config router.yaml
   
   # Apply to test environment first
   kubectl -n federated-graph-test apply -f router-configmap.yaml
   
   # Restart test router
   kubectl -n federated-graph-test rollout restart deployment apollo-router
   ```

2. **Production Deployment**
   ```bash
   # Apply validated configuration to production
   kubectl -n federated-graph apply -f router-configmap.yaml
   
   # Perform rolling restart
   kubectl -n federated-graph rollout restart deployment apollo-router
   
   # Monitor rollout
   kubectl -n federated-graph rollout status deployment apollo-router
   ```

3. **Verification**
   ```bash
   # Check router health
   curl -s https://federated-graph-api.covermymeds.com/.well-known/apollo/server-health | jq
   
   # Verify configuration through metrics
   # Check key metrics dashboard
   ```

#### Router Version Upgrades

1. **Review Release Notes**
   - Check for breaking changes
   - Identify new features and bug fixes
   - Create upgrade test plan

2. **Test in Non-Production**
   ```bash
   # Update test environment image
   kubectl -n federated-graph-test set image deployment/apollo-router \
     router=ghcr.io/apollographql/router:v1.X.Y
   
   # Monitor for issues
   kubectl -n federated-graph-test logs -l app=apollo-router -f
   ```

3. **Production Upgrade**
   ```bash
   # Update canary instances first
   kubectl -n federated-graph set image deployment/apollo-router-canary \
     router=ghcr.io/apollographql/router:v1.X.Y
   
   # Monitor canary for 24 hours
   
   # Update all production instances
   kubectl -n federated-graph set image deployment/apollo-router \
     router=ghcr.io/apollographql/router:v1.X.Y
   
   # Verify successful upgrade
   kubectl -n federated-graph get pods -l app=apollo-router -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image
   ```

### Subgraph Maintenance

#### Subgraph Deployment

1. **Build and Test**
   ```bash
   # Build subgraph image
   docker build -t covermymeds/patient-subgraph:1.5.3 .
   
   # Run tests
   npm test
   
   # Push to container registry
   docker push covermymeds/patient-subgraph:1.5.3
   ```

2. **Deployment**
   ```bash
   # Update subgraph in staging
   kubectl -n federated-graph-staging set image deployment/patient-subgraph \
     server=covermymeds/patient-subgraph:1.5.3
   
   # Verify in staging
   kubectl -n federated-graph-staging rollout status deployment/patient-subgraph
   
   # Deploy to production
   kubectl -n federated-graph set image deployment/patient-subgraph \
     server=covermymeds/patient-subgraph:1.5.3
   
   # Verify in production
   kubectl -n federated-graph rollout status deployment/patient-subgraph
   ```

3. **Post-Deployment Verification**
   ```bash
   # Check subgraph health
   curl -s https://patient-subgraph.internal:4001/.well-known/apollo/server-health | jq
   
   # Run test queries
   apollo client:run-operation --endpoint="https://federated-graph-api.covermymeds.com/graphql" --operation="GetPatientById"
   ```

#### Subgraph Dependency Updates

1. **Dependency Audit**
   ```bash
   # Check for vulnerabilities
   npm audit
   
   # Update dependencies
   npm update
   
   # Check for breaking changes
   npm test
   ```

2. **Test with Integration Tests**
   ```bash
   # Run integration tests
   npm run test:integration
   
   # Verify with mock federation
   npm run test:federation
   ```

3. **Update Deployment Process**
   - Follow standard subgraph deployment process
   - Additional monitoring for dependency-related issues

### Database Maintenance

#### Database Schema Updates

1. **Schema Migration Planning**
   - Plan backward compatible changes
   - Create migration scripts
   - Develop rollback procedures

2. **Test Migrations**
   ```bash
   # Run migration in test environment
   npm run migrate:test
   
   # Verify application compatibility
   npm run test:integration
   ```

3. **Production Migration**
   ```bash
   # Run migration during maintenance window
   npm run migrate:production
   
   # Verify successful migration
   npm run verify:migration
   ```

#### Database Performance Tuning

1. **Performance Analysis**
   ```bash
   # Analyze slow queries
   psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "SELECT * FROM pg_stat_statements ORDER BY total_exec_time DESC LIMIT 20;"
   
   # Check index usage
   psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "SELECT * FROM pg_stat_user_indexes;"
   ```

2. **Optimization Implementation**
   ```bash
   # Add indexes for common query patterns
   psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "CREATE INDEX idx_patient_mrn ON patients(medical_record_number);"
   
   # Update database statistics
   psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "ANALYZE;"
   ```

3. **Verification**
   ```bash
   # Re-run performance analysis
   psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "SELECT * FROM pg_stat_statements WHERE query LIKE '%patient%' ORDER BY total_exec_time DESC LIMIT 10;"
   
   # Check application performance metrics
   # Verify in monitoring dashboards
   ```

### Security Maintenance

#### Certificate Rotation

1. **Certificate Status Check**
   ```bash
   # Check certificate expiration
   kubectl -n federated-graph get certificate
   
   # Review upcoming expirations
   certbot certificates
   ```

2. **Certificate Renewal**
   ```bash
   # Renew certificates using cert-manager
   kubectl -n federated-graph annotate certificate federated-graph-tls cert-manager.io/renew="true"
   
   # Verify renewal
   kubectl -n federated-graph describe certificate federated-graph-tls
   ```

3. **Post-Renewal Verification**
   ```bash
   # Check new certificate details
   openssl s_client -connect federated-graph-api.covermymeds.com:443 -servername federated-graph-api.covermymeds.com | openssl x509 -text -noout
   
   # Verify TLS handshake
   curl -vI https://federated-graph-api.covermymeds.com/.well-known/apollo/server-health
   ```

#### Security Patching

1. **Vulnerability Assessment**
   ```bash
   # Run security scans
   trivy image covermymeds/apollo-router:latest
   trivy image covermymeds/patient-subgraph:latest
   
   # Check for OS vulnerabilities
   kubectl -n federated-graph exec -it apollo-router-0 -- apt list --upgradable
   ```

2. **Patch Application**
   ```bash
   # Apply security patches
   kubectl -n federated-graph set image deployment/apollo-router \
     router=covermymeds/apollo-router:latest-patched
   
   # Apply OS patches through rolling update
   kubectl -n federated-graph rollout restart deployment apollo-router
   ```

3. **Verification**
   ```bash
   # Re-run security scans
   trivy image covermymeds/apollo-router:latest-patched
   
   # Verify application health
   curl -s https://federated-graph-api.covermymeds.com/.well-known/apollo/server-health | jq
   ```

## Maintenance Schedule

### Regular Maintenance Windows

| Maintenance Type | Frequency | Duration | Timing | Impact |
|------------------|-----------|----------|--------|--------|
| Schema Updates | Weekly | 1 hour | Tuesdays, 2-3 AM ET | Minimal - Rolling deployment |
| Minor Router Updates | Monthly | 2 hours | First Thursday, 2-4 AM ET | Minimal - Rolling deployment |
| Major Router Upgrades | Quarterly | 4 hours | First Sunday of quarter, 12-4 AM ET | Potential brief disruption |
| Security Patching | Monthly | 2 hours | Third Thursday, 2-4 AM ET | Minimal - Rolling deployment |
| Database Maintenance | Quarterly | 3 hours | Second Sunday of quarter, 12-3 AM ET | Read-only period possible |
| Certificate Rotation | Quarterly | 1 hour | Automated, no window needed | None |
| Dependency Updates | Monthly | 2 hours | Second Thursday, 2-4 AM ET | Minimal - Rolling deployment |

### Annual Maintenance Calendar

| Month | Focus Area | Special Activities |
|-------|------------|-------------------|
| January | Security | Annual security review, Penetration testing |
| February | Performance | Performance optimization, Query analysis |
| March | Reliability | Disaster recovery testing |
| April | Scalability | Load testing, Capacity planning review |
| May | Documentation | Documentation updates, Runbook review |
| June | Monitoring | Monitoring system updates, Dashboard improvements |
| July | Security | Mid-year security review |
| August | Architecture | Architecture review and planning |
| September | Compliance | Compliance audit preparation |
| October | Performance | Performance optimization, Query analysis |
| November | Disaster Recovery | DR testing and procedure updates |
| December | Planning | Next year planning and roadmap |

### Maintenance Notification Procedure

1. **Standard Maintenance**
   - Notification sent 7 days in advance
   - Reminder sent 1 day in advance
   - Completion notification sent after maintenance

2. **Emergency Maintenance**
   - Immediate notification with expected duration
   - Status updates every 30 minutes during maintenance
   - Completion notification with incident summary

3. **Notification Channels**
   - Email to federated-graph-api-users@covermymeds.com
   - Status page update at status.covermymeds.com
   - Slack notification in #federated-graph-api channel

## Maintenance Tools

### Schema Management Tools

1. **Apollo Rover CLI**
   ```bash
   # Install Rover
   curl -sSL https://rover.apollo.dev/nix/latest | sh
   
   # Check schema
   rover subgraph check federated-graph-api@prod \
     --name patient-subgraph \
     --schema ./schema.graphql
   ```

2. **GraphQL Linter**
   ```bash
   # Install GraphQL Linter
   npm install -g graphql-schema-linter
   
   # Lint schema
   graphql-schema-linter schema.graphql
   ```

3. **GraphQL Inspector**
   ```bash
   # Install GraphQL Inspector
   npm install -g @graphql-inspector/cli
   
   # Compare schemas for breaking changes
   graphql-inspector diff old-schema.graphql new-schema.graphql
   ```

### Router Management Tools

1. **Apollo Router CLI**
   ```bash
   # Validate router configuration
   apollo-router config validate --config router.yaml
   
   # Check router status
   apollo-router status
   ```

2. **Router Debug Tools**
   ```bash
   # Enable debug logging
   kubectl -n federated-graph set env deployment/apollo-router RUST_LOG=debug
   
   # Collect debug information
   kubectl -n federated-graph exec -it apollo-router-0 -- apollo-router config dump
   ```

3. **Router Performance Analysis**
   ```bash
   # Collect performance profiling data
   curl -X POST https://router-admin.internal:8088/profiling/start
   
   # After collection period
   curl -X POST https://router-admin.internal:8088/profiling/stop
   
   # Analyze with performance tools
   ```

### Monitoring and Diagnostics

1. **Query Exploration Tools**
   ```bash
   # Use Apollo Studio Explorer
   # Available at https://studio.apollographql.com/graph/federated-graph-api
   
   # Use GraphQL Playground for local testing
   docker run -p 4000:4000 graphql/graphql-playground
   ```

2. **Log Analysis Tools**
   ```bash
   # Search logs for specific errors
   kubectl -n federated-graph logs -l app=apollo-router --tail=1000 | grep -i error
   
   # Analyze error patterns
   kubectl -n federated-graph logs -l app=apollo-router --tail=10000 | grep -i error | sort | uniq -c | sort -nr
   ```

3. **Performance Monitoring Tools**
   ```bash
   # Access Grafana dashboard
   open https://grafana.covermymeds.com/dashboards/federated-graph-api
   
   # Export metrics for analysis
   curl -s https://prometheus.covermymeds.com/api/v1/query?query=apollo_router_http_request_duration_seconds | jq
   ```

## Example Maintenance Script

```bash
#!/bin/bash
# Federated Graph API Maintenance Script
# Purpose: Performs routine maintenance on the Federated Graph API

# Exit on error
set -e

# Configuration
NAMESPACE="federated-graph"
ROUTER_DEPLOYMENT="apollo-router"
BACKUP_DIR="/backups/federated-graph-api/$(date +%Y-%m-%d)"
LOG_FILE="/var/log/maintenance/federated-graph-api-$(date +%Y-%m-%d).log"

# Ensure backup directory exists
mkdir -p $BACKUP_DIR
mkdir -p $(dirname $LOG_FILE)

# Start logging
exec > >(tee -a $LOG_FILE) 2>&1
echo "Starting maintenance at $(date)"

# 1. Backup current state
echo "Backing up current state..."
mkdir -p $BACKUP_DIR/configs
kubectl -n $NAMESPACE get configmap apollo-router-config -o yaml > $BACKUP_DIR/configs/apollo-router-config.yaml
kubectl -n $NAMESPACE get deployment $ROUTER_DEPLOYMENT -o yaml > $BACKUP_DIR/configs/router-deployment.yaml

# 2. Backup supergraph schema
echo "Backing up supergraph schema..."
kubectl -n $NAMESPACE exec -it $(kubectl -n $NAMESPACE get pods -l app=apollo-router -o name | head -1) -- \
  cat /etc/apollo/supergraph.graphql > $BACKUP_DIR/supergraph.graphql

# 3. Check for pending updates
echo "Checking for pending updates..."
ROUTER_IMAGE=$(kubectl -n $NAMESPACE get deployment $ROUTER_DEPLOYMENT -o jsonpath='{.spec.template.spec.containers[0].image}')
LATEST_TAG=$(curl -s https://api.github.com/repos/apollographql/router/releases/latest | jq -r '.tag_name')
echo "Current router image: $ROUTER_IMAGE"
echo "Latest router release: $LATEST_TAG"

# 4. Apply security patches to base image
echo "Applying security patches..."
kubectl -n $NAMESPACE rollout restart deployment $ROUTER_DEPLOYMENT
echo "Waiting for rollout to complete..."
kubectl -n $NAMESPACE rollout status deployment $ROUTER_DEPLOYMENT

# 5. Run health checks
echo "Running health checks..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://federated-graph-api.covermymeds.com/.well-known/apollo/server-health)
if [ $HTTP_STATUS -eq 200 ]; then
  echo "Health check passed: HTTP $HTTP_STATUS"
else
  echo "Health check failed: HTTP $HTTP_STATUS"
  echo "Sending alert and exiting..."
  exit 1
fi

# 6. Run performance check
echo "Running performance check..."
# Execute a standard query and measure time
START_TIME=$(date +%s.%N)
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"query":"query { __typename }"}' \
  https://federated-graph-api.covermymeds.com/graphql > /dev/null
END_TIME=$(date +%s.%N)
DURATION=$(echo "$END_TIME - $START_TIME" | bc)
echo "Query execution time: $DURATION seconds"

# 7. Check certificates
echo "Checking certificates..."
EXPIRE_DATE=$(echo | openssl s_client -connect federated-graph-api.covermymeds.com:443 -servername federated-graph-api.covermymeds.com 2>/dev/null | openssl x509 -noout -enddate | cut -d= -f2)
EXPIRE_EPOCH=$(date -d "$EXPIRE_DATE" +%s)
NOW_EPOCH=$(date +%s)
DAYS_REMAINING=$(( ($EXPIRE_EPOCH - $NOW_EPOCH) / 86400 ))
echo "Certificate expires in $DAYS_REMAINING days"

if [ $DAYS_REMAINING -lt 30 ]; then
  echo "Certificate expires soon, triggering renewal..."
  kubectl -n $NAMESPACE annotate certificate federated-graph-tls cert-manager.io/renew="true" --overwrite
fi

# 8. Clean up old logs
echo "Cleaning up old logs..."
find /var/log/maintenance -name "federated-graph-api-*.log" -type f -mtime +90 -delete

# 9. Run database optimizations (if needed)
if [ $(date +%u) -eq 7 ] && [ $(date +%d) -lt 8 ]; then  # First Sunday of the month
  echo "Running monthly database optimizations..."
  # Database optimization commands would go here
  echo "Database optimization completed"
fi

# 10. Finalize maintenance
echo "Maintenance completed successfully at $(date)"

# Send completion notification
echo "Sending maintenance completion notification..."
curl -X POST -H "Content-Type: application/json" \
  -d '{"text":"Federated Graph API maintenance completed successfully"}' \
  https://hooks.slack.com/services/YOUR_SLACK_WEBHOOK_URL

exit 0
```

## Related Resources
- [Federated Graph API Deployment](./deployment.md)
- [Federated Graph API Monitoring](./monitoring.md)
- [Federated Graph API Troubleshooting](./troubleshooting.md)
- [Apollo Router Operations Guide](https://www.apollographql.com/docs/router/configuration/overview)