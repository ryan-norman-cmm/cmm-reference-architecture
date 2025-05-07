# FHIR Interoperability Platform Troubleshooting

## Introduction
This document provides guidance for diagnosing and resolving common issues with the FHIR Interoperability Platform. It outlines diagnostic approaches, common issues, solutions, and provides detailed troubleshooting procedures for operators and support personnel. The goal is to minimize downtime and ensure rapid resolution of issues affecting the platform.

## Diagnostic Approaches

### System Health Check

The first step in troubleshooting is to assess the overall health of the FHIR Interoperability Platform:

```bash
# Check FHIR server health endpoint
curl -s https://fhir-api.covermymeds.com/.well-known/health-check | jq

# Check Kubernetes pod status
kubectl get pods -n fhir-interoperability

# Check pod details for any pods not in Running state
kubectl describe pod [pod-name] -n fhir-interoperability

# Check recent logs for errors
kubectl logs -l app=fhir-server -n fhir-interoperability --tail=100 | grep ERROR

# Check database connection
kubectl exec -it [fhir-server-pod] -n fhir-interoperability -- psql -h $DB_HOST -U $DB_USER -d fhir_db -c "SELECT 1"

# Check recent deployments
kubectl rollout history deployment/fhir-server -n fhir-interoperability
```

### Log Analysis

Logs are the primary source of diagnostic information for the FHIR Interoperability Platform:

#### FHIR Server Logs

```bash
# View real-time logs
kubectl logs -f -l app=fhir-server -n fhir-interoperability

# View logs with timestamps
kubectl logs -l app=fhir-server -n fhir-interoperability --timestamps=true

# Search for specific error types
kubectl logs -l app=fhir-server -n fhir-interoperability | grep -i "exception"

# View logs around a specific time
kubectl logs -l app=fhir-server -n fhir-interoperability --since="30m"
```

#### Database Logs

```bash
# Connect to database and check logs
kubectl exec -it [db-pod] -n fhir-interoperability -- psql -U postgres -c "SELECT * FROM pg_stat_activity WHERE state = 'active';"

# Check for slow queries
kubectl exec -it [db-pod] -n fhir-interoperability -- psql -U postgres -c "SELECT * FROM pg_stat_activity WHERE state = 'active' AND now() - query_start > interval '30 seconds';"
```

#### System Logs

```bash
# Check node issues
kubectl describe node [node-name]

# Check service issues
kubectl describe service fhir-server -n fhir-interoperability

# Check ingress issues
kubectl describe ingress fhir-api -n fhir-interoperability
```

### Performance Analysis

When troubleshooting performance issues, focus on these key metrics:

#### API Performance

```bash
# Check API latency metrics
curl -s https://metrics.covermymeds.com/api/v1/query?query=histogram_quantile\(0.95,\ sum\(rate\(fhir_request_duration_seconds_bucket\[5m\]\)\)\ by\ \(le,\ resource_type\)\) | jq

# Check API error rate
curl -s https://metrics.covermymeds.com/api/v1/query?query=sum\(rate\(fhir_requests_total\{status_code%3D~%225..%22\}\[5m\]\)\)\ /\ sum\(rate\(fhir_requests_total\[5m\]\)\) | jq
```

#### Resource Utilization

```bash
# Check CPU usage
kubectl top pods -n fhir-interoperability

# Check memory usage
kubectl top pods -n fhir-interoperability --sort-by=memory

# Check persistent volume usage
kubectl get pv | grep fhir
```

#### Database Performance

```bash
# Check database connection pool utilization
curl -s https://metrics.covermymeds.com/api/v1/query?query=db_connection_pool_utilization | jq

# Check index usage
kubectl exec -it [db-pod] -n fhir-interoperability -- psql -U postgres -c "SELECT * FROM pg_stat_user_indexes ORDER BY idx_scan DESC LIMIT 10;"

# Check table bloat
kubectl exec -it [db-pod] -n fhir-interoperability -- psql -U postgres -c "SELECT schemaname, relname, n_dead_tup, n_live_tup, round(n_dead_tup*100.0/n_live_tup,2) AS dead_percentage FROM pg_stat_user_tables WHERE n_live_tup > 0 ORDER BY dead_percentage DESC LIMIT 10;"
```

### Network Diagnostics

Network issues can affect connectivity and performance:

```bash
# Check DNS resolution
kubectl exec -it [fhir-server-pod] -n fhir-interoperability -- nslookup fhir-db.internal

# Check connectivity to database
kubectl exec -it [fhir-server-pod] -n fhir-interoperability -- nc -zv fhir-db.internal 5432

# Check connectivity to external services
kubectl exec -it [fhir-server-pod] -n fhir-interoperability -- curl -v https://auth.covermymeds.com/.well-known/openid-configuration

# Test network latency
kubectl exec -it [fhir-server-pod] -n fhir-interoperability -- ping -c 5 fhir-db.internal
```

## Common Issues and Solutions

### Authentication and Authorization Issues

#### Issue: OAuth2 Token Acquisition Failures

**Symptoms:**
- Clients receive 401 Unauthorized responses
- Authentication service logs show token issuance failures
- Increased error rate for authentication endpoints

**Potential Causes:**
- Identity provider is unavailable
- Client credentials are incorrect or expired
- Token signing keys have rotated
- Network connectivity issues to identity provider

**Solutions:**

1. Check identity provider status:
   ```bash
   curl -v https://auth.covermymeds.com/health
   ```

2. Verify client credentials:
   ```bash
   # Test client credentials grant
   curl -X POST https://auth.covermymeds.com/oauth2/token \
     -d "grant_type=client_credentials&client_id=YOUR_CLIENT_ID&client_secret=YOUR_CLIENT_SECRET"
   ```

3. Check for token signing key rotation:
   ```bash
   # Get current JWT signing keys
   curl https://auth.covermymeds.com/.well-known/jwks.json
   
   # Compare with configured keys
   kubectl get configmap auth-config -n fhir-interoperability -o yaml
   ```

4. Restart authentication services if needed:
   ```bash
   kubectl rollout restart deployment/auth-service -n fhir-interoperability
   ```

#### Issue: SMART on FHIR Launch Context Problems

**Symptoms:**
- SMART apps fail to launch
- Apps receive incorrect or missing context (patient, encounter)
- Launch sequence breaks at authorization step

**Potential Causes:**
- Misconfigured SMART app registration
- Missing launch context parameters
- Incorrect scopes requested
- Malformed launch token

**Solutions:**

1. Verify app registration configuration:
   ```bash
   # Check app registration in database
   kubectl exec -it [fhir-server-pod] -n fhir-interoperability -- \
     psql -U postgres -d fhir_db -c "SELECT * FROM smart_app_registrations WHERE client_id = 'PROBLEM_APP_ID';"
   ```

2. Check launch context parameters in logs:
   ```bash
   kubectl logs -l app=fhir-server -n fhir-interoperability | grep "launch="
   ```

3. Update app registration if needed:
   ```bash
   curl -X PUT https://fhir-api.covermymeds.com/fhir/r4/SMARTAppRegistration/problem-app-id \
     -H "Authorization: Bearer YOUR_ADMIN_TOKEN" \
     -H "Content-Type: application/fhir+json" \
     -d '{
       "resourceType": "SMARTAppRegistration",
       "id": "problem-app-id",
       "name": "Problem App",
       "redirectUri": "https://app.example.com/redirect",
       "launchUri": "https://app.example.com/launch",
       "scopes": "launch patient/*.read user/*.write",
       "allowOfflineAccess": true
     }'
   ```

4. Clear browser cache on client systems for SMART app redirects

### API Performance Issues

#### Issue: Slow FHIR Search Queries

**Symptoms:**
- Search operations take significantly longer than expected
- Timeouts on complex queries
- High database CPU utilization
- Increased 504 Gateway Timeout responses

**Potential Causes:**
- Missing or inefficient database indexes
- Complex search parameters without optimization
- Large result sets without pagination
- Database resource constraints
- Inefficient search implementation

**Solutions:**

1. Identify slow search queries:
   ```bash
   kubectl logs -l app=fhir-server -n fhir-interoperability | grep -i "slow query"
   
   # Check database for slow queries
   kubectl exec -it [db-pod] -n fhir-interoperability -- \
     psql -U postgres -d fhir_db -c "SELECT * FROM pg_stat_activity WHERE state = 'active' AND now() - query_start > interval '30 seconds';"
   ```

2. Check index usage for problematic resource types:
   ```bash
   kubectl exec -it [db-pod] -n fhir-interoperability -- \
     psql -U postgres -d fhir_db -c "SELECT * FROM pg_stat_user_indexes WHERE relname = 'patient' ORDER BY idx_scan DESC;"
   ```

3. Add missing indexes for common search parameters:
   ```sql
   -- Example: Add index for Patient name search
   CREATE INDEX IF NOT EXISTS idx_patient_name ON patient USING gin ((resource -> 'name'));
   
   -- Example: Add index for Observation date search
   CREATE INDEX IF NOT EXISTS idx_observation_date ON observation ((resource -> 'effectiveDateTime'));
   ```

4. Update search parameter definitions for better performance:
   ```bash
   # Update search parameter to use efficient indexing
   curl -X PUT https://fhir-api.covermymeds.com/fhir/r4/SearchParameter/patient-name \
     -H "Authorization: Bearer YOUR_ADMIN_TOKEN" \
     -H "Content-Type: application/fhir+json" \
     -d '{
       "resourceType": "SearchParameter",
       "id": "patient-name",
       "url": "http://hl7.org/fhir/SearchParameter/Patient-name",
       "name": "name",
       "status": "active",
       "description": "A portion of either family or given name of the patient",
       "code": "name",
       "base": ["Patient"],
       "type": "string",
       "expression": "Patient.name"
     }'
   ```

5. Scale database resources if necessary:
   ```bash
   # Example: Update database instance size in AWS
   aws rds modify-db-instance --db-instance-identifier fhir-db --db-instance-class db.r5.2xlarge
   ```

#### Issue: High API Error Rate

**Symptoms:**
- Elevated 4xx or 5xx HTTP response codes
- Error logs showing specific failures
- Increased latency before errors
- Client applications reporting failures

**Potential Causes:**
- Resource validation failures
- Database connectivity issues
- Memory or CPU constraints
- Configuration errors
- Application bugs

**Solutions:**

1. Analyze error distribution by type:
   ```bash
   # Check error rate by HTTP status code
   curl -s https://metrics.covermymeds.com/api/v1/query?query=sum\(rate\(fhir_requests_total\[5m\]\)\)\ by\ \(status_code\) | jq
   ```

2. Check for specific error patterns in logs:
   ```bash
   kubectl logs -l app=fhir-server -n fhir-interoperability | grep -i "error" | sort | uniq -c | sort -nr | head -20
   ```

3. Analyze resource validation errors:
   ```bash
   # Extract validation errors from logs
   kubectl logs -l app=fhir-server -n fhir-interoperability | grep -i "validation error" | head -20
   
   # Check a specific resource for validation issues
   curl -X POST https://fhir-api.covermymeds.com/fhir/r4/Patient/\$validate \
     -H "Authorization: Bearer YOUR_TOKEN" \
     -H "Content-Type: application/fhir+json" \
     -d @problem-resource.json
   ```

4. Check resource constraints and scale if needed:
   ```bash
   kubectl top pods -n fhir-interoperability
   
   # Scale up deployment if needed
   kubectl scale deployment fhir-server -n fhir-interoperability --replicas=5
   ```

5. Review recent configuration changes:
   ```bash
   kubectl get configmap fhir-server-config -n fhir-interoperability -o yaml > current-config.yaml
   git diff last-known-good-config.yaml current-config.yaml
   ```

### Database Issues

#### Issue: Database Connection Pool Exhaustion

**Symptoms:**
- "Too many connections" errors in logs
- Increasing request latency before failures
- Connection timeout errors
- Application unable to serve requests

**Potential Causes:**
- Connection leaks in application code
- Insufficient connection pool size
- Database instance under-provisioned
- Long-running transactions holding connections
- Inefficient connection management

**Solutions:**

1. Check current connection utilization:
   ```bash
   # Check connection pool metrics
   curl -s https://metrics.covermymeds.com/api/v1/query?query=db_connection_pool_utilization | jq
   
   # Check active database connections
   kubectl exec -it [db-pod] -n fhir-interoperability -- \
     psql -U postgres -c "SELECT count(*) FROM pg_stat_activity WHERE state = 'active';"
   ```

2. Identify long-running transactions:
   ```bash
   kubectl exec -it [db-pod] -n fhir-interoperability -- \
     psql -U postgres -c "SELECT pid, now() - xact_start AS duration, query FROM pg_stat_activity WHERE state = 'active' AND xact_start < now() - interval '5 minutes' ORDER BY duration DESC;"
   ```

3. Terminate stuck connections if necessary:
   ```bash
   kubectl exec -it [db-pod] -n fhir-interoperability -- \
     psql -U postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE state = 'active' AND xact_start < now() - interval '30 minutes';"
   ```

4. Adjust connection pool settings:
   ```bash
   # Update database connection pool configuration
   kubectl edit configmap fhir-server-config -n fhir-interoperability
   
   # Example configuration change:
   # database:
   #   pool:
   #     maxPoolSize: 50
   #     minPoolSize: 10
   #     idleTimeout: 30000
   #     connectionTimeout: 5000
   ```

5. Restart application to apply connection pool changes:
   ```bash
   kubectl rollout restart deployment/fhir-server -n fhir-interoperability
   ```

#### Issue: Database Performance Degradation

**Symptoms:**
- Increasing query latency
- High CPU utilization on database
- Growing table or index size
- Increasing I/O wait time
- Slowing overall application performance

**Potential Causes:**
- Table bloat due to updates/deletes
- Missing or outdated statistics
- Index fragmentation
- Poorly optimized queries
- Resource contention

**Solutions:**

1. Check for table bloat:
   ```bash
   kubectl exec -it [db-pod] -n fhir-interoperability -- \
     psql -U postgres -d fhir_db -c "SELECT schemaname, relname, n_dead_tup, n_live_tup, round(n_dead_tup*100.0/n_live_tup,2) AS dead_percentage FROM pg_stat_user_tables WHERE n_live_tup > 0 ORDER BY dead_percentage DESC LIMIT 10;"
   ```

2. Analyze database statistics:
   ```bash
   kubectl exec -it [db-pod] -n fhir-interoperability -- \
     psql -U postgres -d fhir_db -c "ANALYZE VERBOSE;"
   ```

3. Check for unused or duplicate indexes:
   ```bash
   kubectl exec -it [db-pod] -n fhir-interoperability -- \
     psql -U postgres -d fhir_db -c "SELECT indexrelid::regclass AS index_name, relid::regclass AS table_name, idx_scan, idx_tup_read, idx_tup_fetch FROM pg_stat_user_indexes ORDER BY idx_scan ASC LIMIT 10;"
   ```

4. Perform VACUUM ANALYZE on bloated tables:
   ```bash
   kubectl exec -it [db-pod] -n fhir-interoperability -- \
     psql -U postgres -d fhir_db -c "VACUUM ANALYZE patient;"
   ```

5. Adjust database resource allocation:
   ```bash
   # Example AWS RDS parameter group update
   aws rds modify-db-parameter-group \
     --db-parameter-group-name fhir-db-params \
     --parameters "ParameterName=shared_buffers,ParameterValue=4096MB,ApplyMethod=pending-reboot"
   ```

### Authentication and Authorization Issues

#### Issue: JWT Validation Failures

**Symptoms:**
- 401 Unauthorized responses for valid tokens
- "Invalid token" or "Token validation failed" errors
- Authentication issues after system maintenance

**Potential Causes:**
- JWT signing key mismatch
- Clock skew between systems
- Expired certificates
- Incorrect audience validation
- Algorithm mismatch

**Solutions:**

1. Check JWT token claims and validation:
   ```bash
   # Decode a sample JWT (replace YOUR_TOKEN with an actual token)
   echo "YOUR_TOKEN" | cut -d. -f2 | base64 -d 2>/dev/null | jq
   ```

2. Verify signing key configuration:
   ```bash
   # Check current JWKS endpoint
   curl https://auth.covermymeds.com/.well-known/jwks.json | jq
   
   # Check configured keys in application
   kubectl get configmap auth-config -n fhir-interoperability -o yaml | grep -A 20 "jwks"
   ```

3. Check for clock skew between systems:
   ```bash
   # Check server time
   kubectl exec -it [fhir-server-pod] -n fhir-interoperability -- date
   
   # Check database time
   kubectl exec -it [db-pod] -n fhir-interoperability -- date
   
   # Check local time
   date
   ```

4. Update JWT validation configuration:
   ```bash
   # Update JWKS URL in configuration
   kubectl edit configmap fhir-server-config -n fhir-interoperability
   
   # Example configuration:
   # auth:
   #   jwt:
   #     jwksUrl: "https://auth.covermymeds.com/.well-known/jwks.json"
   #     issuer: "https://auth.covermymeds.com"
   #     audience: "https://fhir-api.covermymeds.com/fhir/r4"
   #     clockSkewSeconds: 60
   ```

5. Restart services to apply changes:
   ```bash
   kubectl rollout restart deployment/fhir-server -n fhir-interoperability
   ```

#### Issue: RBAC Permission Denied

**Symptoms:**
- 403 Forbidden responses
- "Permission denied" or "Unauthorized" errors in logs
- Users unable to access resources they should have access to

**Potential Causes:**
- Incorrect role assignments
- Missing role mappings from identity provider
- Permission configuration errors
- Resource-specific access control issues

**Solutions:**

1. Check user roles and permissions:
   ```bash
   # Decode JWT to see roles (replace YOUR_TOKEN with an actual token)
   echo "YOUR_TOKEN" | cut -d. -f2 | base64 -d 2>/dev/null | jq '.roles'
   
   # Check FHIR access control logs
   kubectl logs -l app=fhir-server -n fhir-interoperability | grep -i "access denied" | tail -20
   ```

2. Verify role mappings:
   ```bash
   # Check role mapping configuration
   kubectl get configmap rbac-config -n fhir-interoperability -o yaml
   ```

3. Test access with elevated privileges:
   ```bash
   # Get admin token
   ADMIN_TOKEN=$(kubectl get secret admin-token -n fhir-interoperability -o jsonpath='{.data.token}' | base64 -d)
   
   # Test access with admin token
   curl -H "Authorization: Bearer $ADMIN_TOKEN" https://fhir-api.covermymeds.com/fhir/r4/Patient
   ```

4. Update role configuration if needed:
   ```bash
   # Update role configuration
   kubectl edit configmap rbac-config -n fhir-interoperability
   
   # Example configuration update:
   # roles:
   #   clinician:
   #     resources:
   #       Patient: ['read', 'search']
   #       Observation: ['read', 'search', 'create']
   ```

5. Restart services to apply changes:
   ```bash
   kubectl rollout restart deployment/fhir-server -n fhir-interoperability
   ```

### Resource Validation Issues

#### Issue: FHIR Profile Validation Failures

**Symptoms:**
- 422 Unprocessable Entity responses
- Validation error messages in logs
- Client applications unable to create or update resources

**Potential Causes:**
- Resources don't conform to required profiles
- Missing required elements
- Invalid element values
- Profile constraint violations
- Terminology binding issues

**Solutions:**

1. Analyze validation errors:
   ```bash
   # Extract validation errors from logs
   kubectl logs -l app=fhir-server -n fhir-interoperability | grep -i "validation error" | head -20
   ```

2. Validate a specific resource:
   ```bash
   # Validate a resource against a profile
   curl -X POST https://fhir-api.covermymeds.com/fhir/r4/Patient/\$validate \
     -H "Authorization: Bearer YOUR_TOKEN" \
     -H "Content-Type: application/fhir+json" \
     -d @problem-resource.json
   ```

3. Check profile definitions:
   ```bash
   # Get the profile definition
   curl -H "Authorization: Bearer YOUR_TOKEN" https://fhir-api.covermymeds.com/fhir/r4/StructureDefinition/us-core-patient
   ```

4. Update validation settings if needed:
   ```bash
   # Update validation configuration
   kubectl edit configmap fhir-server-config -n fhir-interoperability
   
   # Example configuration adjustment:
   # validation:
   #   mode: "permissive"  # Options: strict, permissive, disabled
   #   failFast: false
   #   terminologyValidation: true
   ```

5. Test with simplified resource:
   ```bash
   # Create a minimal valid resource
   curl -X POST https://fhir-api.covermymeds.com/fhir/r4/Patient \
     -H "Authorization: Bearer YOUR_TOKEN" \
     -H "Content-Type: application/fhir+json" \
     -d '{
       "resourceType": "Patient",
       "name": [
         {
           "family": "Smith",
           "given": ["John"]
         }
       ],
       "gender": "male"
     }'
   ```

#### Issue: Terminology Validation Failures

**Symptoms:**
- Validation errors related to coded values
- "Unknown code" or "Code not found in value set" errors
- Issues creating resources with coded elements

**Potential Causes:**
- Invalid or outdated code values
- Missing terminology resources (CodeSystem, ValueSet)
- Terminology service connectivity issues
- Strict validation settings

**Solutions:**

1. Check specific code validation errors:
   ```bash
   kubectl logs -l app=fhir-server -n fhir-interoperability | grep -i "code.*not found" | head -20
   ```

2. Verify CodeSystem and ValueSet resources:
   ```bash
   # Check if CodeSystem exists
   curl -H "Authorization: Bearer YOUR_TOKEN" https://fhir-api.covermymeds.com/fhir/r4/CodeSystem/problem-code-system
   
   # Check if ValueSet exists
   curl -H "Authorization: Bearer YOUR_TOKEN" https://fhir-api.covermymeds.com/fhir/r4/ValueSet/problem-value-set
   ```

3. Test ValueSet expansion:
   ```bash
   # Expand a ValueSet to check for specific codes
   curl -X GET "https://fhir-api.covermymeds.com/fhir/r4/ValueSet/problem-value-set/\$expand" \
     -H "Authorization: Bearer YOUR_TOKEN"
   ```

4. Test code validation directly:
   ```bash
   # Validate a code against a ValueSet
   curl -X POST "https://fhir-api.covermymeds.com/fhir/r4/ValueSet/problem-value-set/\$validate-code" \
     -H "Authorization: Bearer YOUR_TOKEN" \
     -H "Content-Type: application/fhir+json" \
     -d '{
       "resourceType": "Parameters",
       "parameter": [
         {
           "name": "code",
           "valueString": "M54.5"
         },
         {
           "name": "system",
           "valueString": "http://hl7.org/fhir/sid/icd-10"
         }
       ]
     }'
   ```

5. Add missing terminology resources:
   ```bash
   # Create a missing CodeSystem
   curl -X POST https://fhir-api.covermymeds.com/fhir/r4/CodeSystem \
     -H "Authorization: Bearer YOUR_TOKEN" \
     -H "Content-Type: application/fhir+json" \
     -d '{
       "resourceType": "CodeSystem",
       "id": "missing-code-system",
       "url": "http://covermymeds.com/fhir/CodeSystem/missing-code-system",
       "name": "MissingCodeSystem",
       "status": "active",
       "content": "complete",
       "concept": [
         {
           "code": "example-code",
           "display": "Example Code"
         }
       ]
     }'
   ```

## Troubleshooting Procedures

### API Gateway Issues

#### Procedure: Diagnose API Gateway Connectivity Problems

1. Verify API gateway service is running:
   ```bash
   kubectl get pods -l app=api-gateway -n fhir-interoperability
   ```

2. Check gateway logs for errors:
   ```bash
   kubectl logs -l app=api-gateway -n fhir-interoperability | grep -i error
   ```

3. Test connectivity from gateway to backend:
   ```bash
   kubectl exec -it $(kubectl get pods -l app=api-gateway -n fhir-interoperability -o jsonpath='{.items[0].metadata.name}') -n fhir-interoperability -- curl -v http://fhir-server:8080/health
   ```

4. Check gateway configuration:
   ```bash
   kubectl get configmap api-gateway-config -n fhir-interoperability -o yaml
   ```

5. Check for certificate issues:
   ```bash
   kubectl exec -it $(kubectl get pods -l app=api-gateway -n fhir-interoperability -o jsonpath='{.items[0].metadata.name}') -n fhir-interoperability -- openssl s_client -connect fhir-api.covermymeds.com:443
   ```

6. Restart gateway if needed:
   ```bash
   kubectl rollout restart deployment/api-gateway -n fhir-interoperability
   ```

### FHIR Server Issues

#### Procedure: Diagnose and Address Out-of-Memory Errors

1. Identify pods experiencing OOM issues:
   ```bash
   kubectl get pods -n fhir-interoperability | grep -i error
   kubectl describe pod [problem-pod] -n fhir-interoperability | grep -i "OOMKilled"
   ```

2. Check memory usage and limits:
   ```bash
   kubectl top pods -n fhir-interoperability
   kubectl get pod [problem-pod] -n fhir-interoperability -o jsonpath='{.spec.containers[0].resources}'
   ```

3. Analyze memory usage patterns:
   ```bash
   # Get memory usage metrics over time
   curl -s https://metrics.covermymeds.com/api/v1/query_range?query=container_memory_usage_bytes{pod=~"fhir-server.*"}&start=$(date -d "1 hour ago" +%s)&end=$(date +%s)&step=60 | jq
   ```

4. Check for memory leaks in logs:
   ```bash
   kubectl logs [problem-pod] -n fhir-interoperability | grep -i "memory" | grep -i "leak"
   ```

5. Adjust memory limits and requests:
   ```bash
   kubectl edit deployment fhir-server -n fhir-interoperability
   
   # Example resource section:
   # resources:
   #   limits:
   #     memory: "4Gi"
   #   requests:
   #     memory: "2Gi"
   ```

6. Restart with adjusted settings:
   ```bash
   kubectl rollout restart deployment/fhir-server -n fhir-interoperability
   ```

7. Monitor memory usage after changes:
   ```bash
   watch kubectl top pods -n fhir-interoperability
   ```

### Database Issues

#### Procedure: Recover from Database Connection Issues

1. Verify database is running:
   ```bash
   kubectl get pods -l app=fhir-db -n fhir-interoperability
   ```

2. Check database connection from FHIR server:
   ```bash
   kubectl exec -it $(kubectl get pods -l app=fhir-server -n fhir-interoperability -o jsonpath='{.items[0].metadata.name}') -n fhir-interoperability -- nc -zv fhir-db.internal 5432
   ```

3. Check database logs for connection issues:
   ```bash
   kubectl logs -l app=fhir-db -n fhir-interoperability | grep -i "connection"
   ```

4. Check DB connection configuration:
   ```bash
   kubectl get configmap fhir-server-config -n fhir-interoperability -o yaml | grep -A 10 database
   ```

5. Verify database credentials:
   ```bash
   kubectl get secret fhir-db-credentials -n fhir-interoperability -o yaml
   ```

6. Check database connection count:
   ```bash
   kubectl exec -it $(kubectl get pods -l app=fhir-db -n fhir-interoperability -o jsonpath='{.items[0].metadata.name}') -n fhir-interoperability -- psql -U postgres -c "SELECT count(*) FROM pg_stat_activity;"
   ```

7. Restart FHIR server pods with connection issues:
   ```bash
   kubectl rollout restart deployment/fhir-server -n fhir-interoperability
   ```

8. If database is unresponsive, restart database:
   ```bash
   # For managed database in AWS
   aws rds reboot-db-instance --db-instance-identifier fhir-db
   
   # For self-managed database in Kubernetes
   kubectl rollout restart statefulset/fhir-db -n fhir-interoperability
   ```

### Security Issues

#### Procedure: Respond to Authentication Service Failures

1. Check authentication service status:
   ```bash
   kubectl get pods -l app=auth-service -n fhir-interoperability
   ```

2. View auth service logs:
   ```bash
   kubectl logs -l app=auth-service -n fhir-interoperability | grep -i error
   ```

3. Check identity provider connectivity:
   ```bash
   kubectl exec -it $(kubectl get pods -l app=auth-service -n fhir-interoperability -o jsonpath='{.items[0].metadata.name}') -n fhir-interoperability -- curl -v https://auth.covermymeds.com/.well-known/openid-configuration
   ```

4. Verify secret configuration:
   ```bash
   kubectl get secret oauth-client-credentials -n fhir-interoperability -o yaml
   ```

5. Check for certificate expiration:
   ```bash
   kubectl exec -it $(kubectl get pods -l app=auth-service -n fhir-interoperability -o jsonpath='{.items[0].metadata.name}') -n fhir-interoperability -- openssl x509 -in /etc/certs/tls.crt -noout -dates
   ```

6. Restart authentication service:
   ```bash
   kubectl rollout restart deployment/auth-service -n fhir-interoperability
   ```

7. If identity provider is unavailable, enable fallback authentication:
   ```bash
   # Update configuration to enable local authentication
   kubectl edit configmap auth-config -n fhir-interoperability
   
   # Example config change:
   # auth:
   #   enableFallback: true
   #   fallbackMode: "api-key"
   
   # Apply changes
   kubectl rollout restart deployment/auth-service -n fhir-interoperability
   ```

## Example Alert Response Playbooks

### Playbook: High Error Rate Alert

**Alert:** FHIR API High Error Rate (>5%)

**Initial Triage:**

1. Check error rate metrics to confirm alert:
   ```bash
   curl -s https://metrics.covermymeds.com/api/v1/query?query=sum\(rate\(fhir_requests_total\{status_code=~%225..%22\}\[5m\]\)\)\ /\ sum\(rate\(fhir_requests_total\[5m\]\)\) | jq
   ```

2. Determine which status codes are most common:
   ```bash
   curl -s https://metrics.covermymeds.com/api/v1/query?query=sum\(rate\(fhir_requests_total\[5m\]\)\)\ by\ \(status_code\) | jq
   ```

3. Check recent deployment or configuration changes:
   ```bash
   kubectl rollout history deployment/fhir-server -n fhir-interoperability
   ```

4. Check pod status and logs:
   ```bash
   kubectl get pods -n fhir-interoperability
   kubectl logs -l app=fhir-server -n fhir-interoperability --tail=100 | grep -i error
   ```

**If errors are 5xx (Server Errors):**

1. Check system resources:
   ```bash
   kubectl top pods -n fhir-interoperability
   ```

2. Check database connection:
   ```bash
   kubectl exec -it $(kubectl get pods -l app=fhir-server -n fhir-interoperability -o jsonpath='{.items[0].metadata.name}') -n fhir-interoperability -- psql -h $DB_HOST -U $DB_USER -d fhir_db -c "SELECT 1"
   ```

3. Look for application errors:
   ```bash
   kubectl logs -l app=fhir-server -n fhir-interoperability | grep -i "exception" | tail -30
   ```

4. Mitigation options:
   - If specific deployment is problematic, roll back:
     ```bash
     kubectl rollout undo deployment/fhir-server -n fhir-interoperability
     ```
   - If resource constraints, scale up:
     ```bash
     kubectl scale deployment fhir-server -n fhir-interoperability --replicas=5
     ```
   - If database issues, follow database recovery procedure

**If errors are 4xx (Client Errors):**

1. Check if errors are concentrated on specific endpoints:
   ```bash
   curl -s https://metrics.covermymeds.com/api/v1/query?query=sum\(rate\(fhir_requests_total\{status_code=~%224..%22\}\[5m\]\)\)\ by\ \(path\) | jq
   ```

2. Check for validation errors:
   ```bash
   kubectl logs -l app=fhir-server -n fhir-interoperability | grep -i "validation" | tail -30
   ```

3. Check authentication issues:
   ```bash
   kubectl logs -l app=auth-service -n fhir-interoperability | grep -i "token" | grep -i "invalid" | tail -30
   ```

4. Mitigation options:
   - If validation errors, check profile configuration
   - If authentication errors, verify identity provider
   - If client misuse, implement rate limiting

**Resolution and Follow-up:**

1. Document incident and resolution
2. Update runbooks if new troubleshooting steps were discovered
3. Consider implementing preventive measures
4. Review alert thresholds if necessary

### Playbook: Database Connection Pool Exhaustion

**Alert:** Database Connection Pool Near Capacity (>90%)

**Initial Triage:**

1. Confirm connection pool status:
   ```bash
   curl -s https://metrics.covermymeds.com/api/v1/query?query=db_connection_pool_utilization | jq
   ```

2. Check active database connections:
   ```bash
   kubectl exec -it $(kubectl get pods -l app=fhir-db -n fhir-interoperability -o jsonpath='{.items[0].metadata.name}') -n fhir-interoperability -- psql -U postgres -c "SELECT count(*) FROM pg_stat_activity WHERE state = 'active';"
   ```

3. Check for long-running queries:
   ```bash
   kubectl exec -it $(kubectl get pods -l app=fhir-db -n fhir-interoperability -o jsonpath='{.items[0].metadata.name}') -n fhir-interoperability -- psql -U postgres -c "SELECT pid, now() - query_start AS duration, query FROM pg_stat_activity WHERE state = 'active' AND now() - query_start > interval '5 minutes' ORDER BY duration DESC;"
   ```

4. Check recent traffic increase:
   ```bash
   curl -s https://metrics.covermymeds.com/api/v1/query_range?query=sum\(rate\(fhir_requests_total\[5m\]\)\)&start=$(date -d "1 hour ago" +%s)&end=$(date +%s)&step=60 | jq
   ```

**Immediate Actions:**

1. If very close to exhaustion (>95%), temporarily increase pool size:
   ```bash
   kubectl edit configmap fhir-server-config -n fhir-interoperability
   
   # Update connection pool config:
   # database:
   #   pool:
   #     maxPoolSize: 100  # Increase from default
   
   kubectl rollout restart deployment/fhir-server -n fhir-interoperability
   ```

2. Terminate stuck queries if present:
   ```bash
   kubectl exec -it $(kubectl get pods -l app=fhir-db -n fhir-interoperability -o jsonpath='{.items[0].metadata.name}') -n fhir-interoperability -- psql -U postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE state = 'active' AND now() - query_start > interval '30 minutes';"
   ```

3. If issue persists, check for connection leaks:
   ```bash
   kubectl logs -l app=fhir-server -n fhir-interoperability | grep -i "connection" | grep -i "leak"
   ```

**Root Cause Analysis:**

1. Analyze connection usage patterns:
   ```bash
   # Check connection usage over time
   curl -s https://metrics.covermymeds.com/api/v1/query_range?query=db_connection_pool_utilization&start=$(date -d "6 hours ago" +%s)&end=$(date +%s)&step=300 | jq
   ```

2. Determine if related to traffic patterns:
   ```bash
   # Compare with traffic
   curl -s https://metrics.covermymeds.com/api/v1/query_range?query=sum\(rate\(fhir_requests_total\[5m\]\)\)&start=$(date -d "6 hours ago" +%s)&end=$(date +%s)&step=300 | jq
   ```

3. Check for code changes that might affect connection handling

**Long-Term Solutions:**

1. Adjust pool configuration based on observed patterns:
   ```bash
   kubectl edit configmap fhir-server-config -n fhir-interoperability
   
   # Balanced connection pool settings:
   # database:
   #   pool:
   #     maxPoolSize: 50
   #     minPoolSize: 10
   #     idleTimeout: 60000
   #     connectionTimeout: 5000
   #     maxLifetime: 1800000
   ```

2. Implement connection usage monitoring
3. Consider read-replica for read-heavy operations
4. Add circuit breaker for database protection

**Resolution and Follow-up:**

1. Document incident and resolution
2. Update connection pool sizing recommendations
3. Implement improved monitoring if needed
4. Schedule review of connection handling in application code

## Related Resources
- [FHIR Interoperability Platform Deployment](./deployment.md)
- [FHIR Interoperability Platform Monitoring](./monitoring.md)
- [FHIR Interoperability Platform Maintenance](./maintenance.md)
- [FHIR Interoperability Platform Architecture](../01-getting-started/architecture.md)
- [Aidbox Troubleshooting Documentation](https://docs.aidbox.app/getting-started/troubleshooting)