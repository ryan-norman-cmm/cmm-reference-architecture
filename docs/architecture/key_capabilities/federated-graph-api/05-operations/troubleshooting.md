# Federated Graph API Troubleshooting

## Introduction
This document provides a comprehensive guide for troubleshooting issues with the Federated Graph API. It includes common problem scenarios, diagnostic approaches, and resolution steps to help operations teams efficiently identify and resolve issues. This guide is intended to minimize service disruption and enable rapid problem resolution.

## Diagnostic Approach

### General Troubleshooting Framework

1. **Identify the Issue**
   - Understand the symptoms and impact
   - Determine affected components
   - Establish the timeline of events

2. **Gather Information**
   - Collect relevant logs and metrics
   - Review recent changes or deployments
   - Identify affected operations or clients

3. **Analyze Root Cause**
   - Establish problem patterns
   - Correlate events and symptoms
   - Isolate affected components

4. **Implement Solution**
   - Apply short-term mitigation
   - Develop and implement long-term fix
   - Validate resolution effectiveness

5. **Document and Share**
   - Record issue details and resolution
   - Update runbooks with new findings
   - Share knowledge with team members

### First Response Checklist

When a problem is reported, follow this initial checklist:

1. **Verify Service Health**
   ```bash
   # Check router health endpoint
   curl -s https://federated-graph-api.covermymeds.com/.well-known/apollo/server-health | jq
   
   # Check subgraph health endpoints
   for subgraph in patient medication appointment; do
     echo "Checking $subgraph health..."
     curl -s https://$subgraph-subgraph.internal:4001/.well-known/apollo/server-health | jq
   done
   ```

2. **Check Basic Metrics**
   ```bash
   # Check error rate
   curl -s "https://prometheus.covermymeds.com/api/v1/query?query=sum(rate(apollo_router_operation_errors_total[5m]))%20/%20sum(rate(apollo_router_operations_total[5m]))" | jq
   
   # Check latency
   curl -s "https://prometheus.covermymeds.com/api/v1/query?query=histogram_quantile(0.95,%20sum(rate(apollo_router_http_request_duration_seconds_bucket[5m]))%20by%20(le))" | jq
   ```

3. **Check for Recent Changes**
   ```bash
   # Check recent deployments
   kubectl -n federated-graph get events --sort-by='.lastTimestamp'
   
   # Check recent schema changes
   rover subgraph list federated-graph-api@prod
   ```

4. **Check Resource Utilization**
   ```bash
   # Check pod resource usage
   kubectl -n federated-graph top pods
   
   # Check node resource usage
   kubectl -n federated-graph top nodes
   ```

5. **Verify Connectivity**
   ```bash
   # Check subgraph connectivity from router
   kubectl -n federated-graph exec -it $(kubectl -n federated-graph get pods -l app=apollo-router -o name | head -1) -- \
     curl -s http://patient-subgraph.federated-graph.svc:4001/.well-known/apollo/server-health
   ```

## Common Issues and Solutions

### Schema Composition Errors

#### Symptoms
- Failed schema composition in Apollo GraphOS
- Schema validation errors during deployment
- Error messages about incompatible types or missing fields

#### Diagnostic Steps
1. **Check Schema Validation**
   ```bash
   # Validate subgraph schema
   rover subgraph check federated-graph-api@prod \
     --name patient-subgraph \
     --schema ./schema.graphql
   ```

2. **Compare Schema Versions**
   ```bash
   # Get current schema from subgraph
   rover subgraph introspect https://patient-subgraph.internal:4001/graphql > current-schema.graphql
   
   # Compare with previous version
   graphql-inspector diff previous-schema.graphql current-schema.graphql
   ```

3. **Examine Entity References**
   ```bash
   # Extract entity definitions
   grep -n "@key" current-schema.graphql
   ```

#### Resolution Steps
1. **Fix Schema Incompatibilities**
   - Ensure all `@key` directives are consistent across subgraphs
   - Verify type definitions match across subgraphs
   - Resolve any field type mismatches

2. **Test Composition Locally**
   ```bash
   # Compose supergraph locally
   rover supergraph compose --config ./supergraph.yaml
   ```

3. **Deploy Corrected Schema**
   ```bash
   # Publish corrected schema
   rover subgraph publish federated-graph-api@prod \
     --name patient-subgraph \
     --schema ./corrected-schema.graphql \
     --routing-url https://patient-subgraph.internal:4001/graphql
   ```

4. **Verify Composition**
   ```bash
   # Check composition status
   rover graph fetch federated-graph-api@prod
   ```

### High Latency Issues

#### Symptoms
- Increased p95/p99 request latency
- Timeout errors reported by clients
- Slow responses across multiple operations
- Client-side timeouts

#### Diagnostic Steps
1. **Analyze Latency Metrics**
   ```bash
   # Check overall latency
   curl -s "https://prometheus.covermymeds.com/api/v1/query?query=histogram_quantile(0.95,%20sum(rate(apollo_router_http_request_duration_seconds_bucket[5m]))%20by%20(le))" | jq
   
   # Check subgraph latency
   curl -s "https://prometheus.covermymeds.com/api/v1/query?query=histogram_quantile(0.95,%20sum(rate(apollo_subgraph_fetch_duration_seconds_bucket[5m]))%20by%20(subgraph,%20le))" | jq
   ```

2. **Identify Slow Operations**
   ```bash
   # Find slow operations
   curl -s "https://prometheus.covermymeds.com/api/v1/query?query=topk(10,%20max(apollo_operation_execution_time)%20by%20(operation_name))" | jq
   ```

3. **Check Resource Utilization**
   ```bash
   # Check CPU and memory usage
   kubectl -n federated-graph top pods --sort-by=cpu
   kubectl -n federated-graph top pods --sort-by=memory
   ```

4. **Examine Database Performance**
   ```bash
   # Check slow queries (if PostgreSQL)
   psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "SELECT query, calls, total_exec_time, mean_exec_time FROM pg_stat_statements ORDER BY mean_exec_time DESC LIMIT 20;"
   ```

#### Resolution Steps
1. **Optimize Slow Queries**
   - Identify and optimize complex GraphQL queries
   - Add appropriate database indexes
   - Implement query-specific optimizations

2. **Adjust Resource Allocation**
   ```bash
   # Scale up affected components
   kubectl -n federated-graph scale deployment patient-subgraph --replicas=8
   ```

3. **Enhance Caching**
   ```bash
   # Update router configuration for better caching
   kubectl -n federated-graph edit configmap apollo-router-config
   # Increase cache TTL and size
   ```

4. **Implement Query Limiting**
   ```bash
   # Update router configuration to limit complex queries
   kubectl -n federated-graph edit configmap apollo-router-config
   # Add query complexity limits
   ```

5. **Verify Improvements**
   ```bash
   # Re-check latency metrics
   curl -s "https://prometheus.covermymeds.com/api/v1/query?query=histogram_quantile(0.95,%20sum(rate(apollo_router_http_request_duration_seconds_bucket[5m]))%20by%20(le))" | jq
   ```

### High Error Rate

#### Symptoms
- Increased API error responses
- Error spikes in monitoring
- Client reports of failed operations
- Gateway-level or subgraph-level errors

#### Diagnostic Steps
1. **Analyze Error Metrics**
   ```bash
   # Check overall error rate
   curl -s "https://prometheus.covermymeds.com/api/v1/query?query=sum(rate(apollo_router_operation_errors_total[5m]))%20/%20sum(rate(apollo_router_operations_total[5m]))" | jq
   
   # Check error rate by subgraph
   curl -s "https://prometheus.covermymeds.com/api/v1/query?query=sum(rate(apollo_subgraph_fetch_errors_total[5m]))%20by%20(subgraph)%20/%20sum(rate(apollo_subgraph_fetches_total[5m]))%20by%20(subgraph)" | jq
   ```

2. **Examine Error Logs**
   ```bash
   # Check router error logs
   kubectl -n federated-graph logs -l app=apollo-router --tail=200 | grep -i error
   
   # Check subgraph error logs
   kubectl -n federated-graph logs -l app=patient-subgraph --tail=200 | grep -i error
   ```

3. **Identify Affected Operations**
   ```bash
   # Find operations with high error rates
   curl -s "https://prometheus.covermymeds.com/api/v1/query?query=topk(10,%20apollo_operation_error_count%20/%20apollo_operation_count)" | jq
   ```

4. **Check Dependent Services**
   ```bash
   # Check status of dependent services
   curl -s https://patient-service.internal:3000/health | jq
   curl -s https://medication-service.internal:3000/health | jq
   ```

#### Resolution Steps
1. **Fix Errors at Source**
   - Address database connection issues
   - Resolve dependent service failures
   - Fix schema or resolver implementation bugs

2. **Implement Circuit Breaking**
   ```bash
   # Update router configuration to add circuit breaking
   kubectl -n federated-graph edit configmap apollo-router-config
   # Add circuit breaker configuration for problematic subgraphs
   ```

3. **Apply Schema Fixes**
   ```bash
   # Publish corrected schema
   rover subgraph publish federated-graph-api@prod \
     --name patient-subgraph \
     --schema ./corrected-schema.graphql \
     --routing-url https://patient-subgraph.internal:4001/graphql
   ```

4. **Adjust Resource Allocation**
   ```bash
   # Scale if resource constraints are causing errors
   kubectl -n federated-graph scale deployment patient-subgraph --replicas=10
   ```

5. **Verify Error Resolution**
   ```bash
   # Re-check error rate
   curl -s "https://prometheus.covermymeds.com/api/v1/query?query=sum(rate(apollo_router_operation_errors_total[5m]))%20/%20sum(rate(apollo_router_operations_total[5m]))" | jq
   ```

### Gateway Availability Issues

#### Symptoms
- Service unavailable errors
- Connection timeouts
- Health check failures
- Operational alerts for gateway

#### Diagnostic Steps
1. **Check Pod Status**
   ```bash
   # Check router pod status
   kubectl -n federated-graph get pods -l app=apollo-router
   
   # Check for pod restart issues
   kubectl -n federated-graph describe pods -l app=apollo-router
   ```

2. **Examine Node Issues**
   ```bash
   # Check node status
   kubectl get nodes
   
   # Look for node issues
   kubectl describe nodes | grep -A5 Conditions
   ```

3. **Check Load Balancer Status**
   ```bash
   # Check load balancer service
   kubectl -n federated-graph get svc apollo-router-lb
   
   # Describe service for details
   kubectl -n federated-graph describe svc apollo-router-lb
   ```

4. **Verify Network Connectivity**
   ```bash
   # Test network connectivity
   kubectl -n federated-graph exec -it $(kubectl -n federated-graph get pods -l app=debug-tools -o name | head -1) -- \
     curl -v https://federated-graph-api.covermymeds.com/.well-known/apollo/server-health
   ```

#### Resolution Steps
1. **Restart Unhealthy Pods**
   ```bash
   # Delete unhealthy pods to trigger replacement
   kubectl -n federated-graph delete pod apollo-router-789f5d54bd-2xvbn
   ```

2. **Scale Up Router Deployment**
   ```bash
   # Increase replica count
   kubectl -n federated-graph scale deployment apollo-router --replicas=10
   ```

3. **Check for Resource Constraints**
   ```bash
   # Adjust resource limits if needed
   kubectl -n federated-graph edit deployment apollo-router
   # Update resource requests and limits
   ```

4. **Verify Load Balancer Configuration**
   ```bash
   # Check load balancer configuration
   kubectl -n federated-graph edit svc apollo-router-lb
   # Verify correct port and selector configuration
   ```

5. **Verify Health Check Recovery**
   ```bash
   # Check if health endpoints are responding
   curl -s https://federated-graph-api.covermymeds.com/.well-known/apollo/server-health | jq
   ```

### Subgraph Unavailability

#### Symptoms
- Partial schema functionality unavailable
- Errors for specific entity types or operations
- Specific subgraph reporting errors or downtime
- Gateway reporting failure to reach subgraph

#### Diagnostic Steps
1. **Check Subgraph Pod Status**
   ```bash
   # Check specific subgraph pod status
   kubectl -n federated-graph get pods -l app=patient-subgraph
   
   # Check for pod restart issues
   kubectl -n federated-graph describe pods -l app=patient-subgraph
   ```

2. **Examine Subgraph Logs**
   ```bash
   # Check logs for errors
   kubectl -n federated-graph logs -l app=patient-subgraph --tail=200 | grep -i error
   
   # Check for connection issues
   kubectl -n federated-graph logs -l app=patient-subgraph --tail=200 | grep -i "connection\|database\|timeout"
   ```

3. **Verify Backend Service Connectivity**
   ```bash
   # Check if subgraph can reach backend services
   kubectl -n federated-graph exec -it $(kubectl -n federated-graph get pods -l app=patient-subgraph -o name | head -1) -- \
     curl -s http://patient-service.internal:3000/health | jq
   ```

4. **Check Resource Constraints**
   ```bash
   # Check CPU and memory usage
   kubectl -n federated-graph top pods -l app=patient-subgraph
   ```

#### Resolution Steps
1. **Restart Subgraph Pods**
   ```bash
   # Restart deployment
   kubectl -n federated-graph rollout restart deployment patient-subgraph
   ```

2. **Fix Dependent Service Issues**
   - Resolve backend service problems
   - Restore database connectivity
   - Address API dependencies

3. **Scale Up Subgraph**
   ```bash
   # Increase replica count
   kubectl -n federated-graph scale deployment patient-subgraph --replicas=5
   ```

4. **Adjust Resource Allocation**
   ```bash
   # Update resource requests and limits
   kubectl -n federated-graph edit deployment patient-subgraph
   # Modify resource specifications
   ```

5. **Check Router Configuration**
   ```bash
   # Verify router subgraph configuration
   kubectl -n federated-graph exec -it $(kubectl -n federated-graph get pods -l app=apollo-router -o name | head -1) -- \
     cat /etc/apollo/router.yaml | grep -A10 patient-subgraph
   ```

6. **Verify Recovery**
   ```bash
   # Check subgraph health
   curl -s https://patient-subgraph.internal:4001/.well-known/apollo/server-health | jq
   
   # Verify router can reach subgraph
   kubectl -n federated-graph exec -it $(kubectl -n federated-graph get pods -l app=apollo-router -o name | head -1) -- \
     curl -s http://patient-subgraph.federated-graph.svc:4001/.well-known/apollo/server-health
   ```

### Authentication and Authorization Issues

#### Symptoms
- Unauthorized or forbidden errors
- Authentication failures
- Permission denied errors for specific operations
- JWT validation errors

#### Diagnostic Steps
1. **Check Auth Configuration**
   ```bash
   # Check router auth configuration
   kubectl -n federated-graph exec -it $(kubectl -n federated-graph get pods -l app=apollo-router -o name | head -1) -- \
     cat /etc/apollo/router.yaml | grep -A20 authentication
   ```

2. **Examine Auth Logs**
   ```bash
   # Check for auth-related errors
   kubectl -n federated-graph logs -l app=apollo-router --tail=200 | grep -i "auth\|jwt\|permission\|forbidden"
   ```

3. **Verify Identity Provider**
   ```bash
   # Check identity provider health
   curl -s https://identity.covermymeds.com/.well-known/health | jq
   
   # Verify JWKS endpoint
   curl -s https://identity.covermymeds.com/.well-known/jwks.json | jq
   ```

4. **Test Authentication**
   ```bash
   # Test with valid token
   curl -s -X POST -H "Authorization: Bearer $TEST_TOKEN" -H "Content-Type: application/json" \
     -d '{"query":"query { __typename }"}' \
     https://federated-graph-api.covermymeds.com/graphql | jq
   ```

#### Resolution Steps
1. **Fix Auth Configuration**
   ```bash
   # Update router auth configuration
   kubectl -n federated-graph edit configmap apollo-router-config
   # Correct authentication settings
   ```

2. **Rotate or Update Secrets**
   ```bash
   # Update auth secrets if compromised
   kubectl -n federated-graph create secret generic auth-secrets --from-literal=jwk-secret=$NEW_SECRET --dry-run=client -o yaml | kubectl apply -f -
   ```

3. **Verify JWT Settings**
   ```bash
   # Check JWT verification settings
   kubectl -n federated-graph exec -it $(kubectl -n federated-graph get pods -l app=apollo-router -o name | head -1) -- \
     cat /etc/apollo/router.yaml | grep -A10 jwt
   ```

4. **Update JWKS Configuration**
   ```bash
   # Update JWKS URL configuration
   kubectl -n federated-graph edit configmap apollo-router-config
   # Update jwks.url
   ```

5. **Verify Fix**
   ```bash
   # Test authentication again
   curl -s -X POST -H "Authorization: Bearer $TEST_TOKEN" -H "Content-Type: application/json" \
     -d '{"query":"query { __typename }"}' \
     https://federated-graph-api.covermymeds.com/graphql | jq
   ```

### Memory Leaks or OOM Issues

#### Symptoms
- Increasing memory usage over time
- OOMKilled pod terminations
- Degraded performance before crashes
- Frequent pod restarts

#### Diagnostic Steps
1. **Monitor Memory Usage**
   ```bash
   # Check memory usage trend
   curl -s "https://prometheus.covermymeds.com/api/v1/query_range?query=container_memory_usage_bytes{namespace='federated-graph',container='router'}&start=$(date -d '3 hours ago' +'%Y-%m-%dT%H:%M:%SZ')&end=$(date +'%Y-%m-%dT%H:%M:%SZ')&step=5m" | jq
   ```

2. **Check Pod Restarts**
   ```bash
   # Check for OOMKilled restarts
   kubectl -n federated-graph get pods -l app=apollo-router -o custom-columns=NAME:.metadata.name,RESTARTS:.status.containerStatuses[0].restartCount,STATUS:.status.phase
   
   # Check previous termination logs
   kubectl -n federated-graph describe pods -l app=apollo-router | grep -A10 "Last State"
   ```

3. **Examine Memory Profiles**
   ```bash
   # Capture memory profile if router supports it
   curl -s https://router-admin.internal:8088/profiling/heap > heap-profile.json
   ```

4. **Check Resource Limits**
   ```bash
   # Check configured memory limits
   kubectl -n federated-graph get deployment apollo-router -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}'
   ```

#### Resolution Steps
1. **Increase Memory Limits**
   ```bash
   # Update memory limits
   kubectl -n federated-graph set resources deployment apollo-router -c router --limits=memory=4Gi
   ```

2. **Optimize Memory Usage**
   ```bash
   # Update router configuration for memory optimization
   kubectl -n federated-graph edit configmap apollo-router-config
   # Adjust cache sizes and query limits
   ```

3. **Implement Memory Controls**
   ```bash
   # Set JVM options for Node.js-based subgraphs
   kubectl -n federated-graph set env deployment/patient-subgraph NODE_OPTIONS="--max-old-space-size=2048"
   ```

4. **Configure Pod Disruption Budget**
   ```yaml
   # Apply PDB to prevent all pods restarting simultaneously
   apiVersion: policy/v1
   kind: PodDisruptionBudget
   metadata:
     name: apollo-router-pdb
     namespace: federated-graph
   spec:
     minAvailable: 70%
     selector:
       matchLabels:
         app: apollo-router
   ```

5. **Restart Pods Gradually**
   ```bash
   # Restart pods one at a time
   kubectl -n federated-graph get pods -l app=apollo-router -o name | xargs -I{} kubectl -n federated-graph delete {}
   ```

6. **Verify Resolution**
   ```bash
   # Monitor memory usage after changes
   kubectl -n federated-graph top pods -l app=apollo-router
   ```

## Advanced Diagnostics

### Tracing and Profiling

#### Distributed Tracing

1. **Enable Detailed Tracing**
   ```bash
   # Update router configuration for increased trace sampling
   kubectl -n federated-graph edit configmap apollo-router-config
   # Set sampling ratio to 1.0 temporarily
   ```

2. **Analyze Trace Data**
   ```bash
   # Open Jaeger UI to analyze traces
   open https://jaeger.covermymeds.com/search?service=federated-graph-api
   
   # Find slow traces
   curl -s "https://jaeger-query.covermymeds.com/api/traces?service=federated-graph-api&operation=query&limit=10&lookback=1h&minDuration=1s" | jq
   ```

3. **Correlate Trace Data**
   ```bash
   # Get trace by ID
   curl -s "https://jaeger-query.covermymeds.com/api/traces/$TRACE_ID" | jq
   
   # Get spans for specific operation
   curl -s "https://jaeger-query.covermymeds.com/api/traces?service=federated-graph-api&operation=GetPatientData&limit=5" | jq
   ```

#### Performance Profiling

1. **CPU Profiling**
   ```bash
   # Start CPU profiling
   curl -s -X POST https://router-admin.internal:8088/profiling/cpu/start
   
   # Generate load during profiling
   # ... run test traffic ...
   
   # Stop and download profile
   curl -s -X POST https://router-admin.internal:8088/profiling/cpu/stop > cpu-profile.json
   ```

2. **Memory Profiling**
   ```bash
   # Get heap profile
   curl -s https://router-admin.internal:8088/profiling/heap > heap-profile.json
   ```

3. **Query Performance Analysis**
   ```bash
   # Enable query plan visualization
   kubectl -n federated-graph edit configmap apollo-router-config
   # Set experimental.expose_query_plan: true
   
   # Get query plan for specific query
   curl -s -X POST -H "Content-Type: application/json" \
     -d '{"query":"query { patient(id: \"patient-1\") { id name { given family } } }","variables":{}}' \
     https://federated-graph-api.covermymeds.com/graphql?query_plan=true | jq
   ```

### Schema Analysis

#### Schema Composition Analysis

1. **Extract Current Schema**
   ```bash
   # Get current supergraph schema
   rover graph fetch federated-graph-api@prod > supergraph.graphql
   
   # Get subgraph schemas
   rover subgraph introspect https://patient-subgraph.internal:4001/graphql > patient-schema.graphql
   rover subgraph introspect https://medication-subgraph.internal:4001/graphql > medication-schema.graphql
   ```

2. **Analyze Schema Size and Complexity**
   ```bash
   # Count types and fields
   grep -c "type " supergraph.graphql
   grep -c "^\s*\w\+:" supergraph.graphql
   
   # Find large types
   grep -A50 "type " supergraph.graphql | grep -B1 "}" | wc -l
   ```

3. **Check Schema References**
   ```bash
   # Find entities and references
   grep -A1 "@key" *-schema.graphql
   
   # Check interface implementations
   grep -A1 "implements" *-schema.graphql
   ```

4. **Validate Schema Design**
   ```bash
   # Run schema linting tools
   graphql-schema-linter supergraph.graphql
   ```

#### Query Analysis

1. **Extract Common Queries**
   ```bash
   # Find frequent operations
   curl -s "https://prometheus.covermymeds.com/api/v1/query?query=topk(20,%20sum(apollo_operation_count)%20by%20(operation_name))" | jq
   ```

2. **Analyze Query Complexity**
   ```bash
   # Measure query complexity
   curl -s "https://prometheus.covermymeds.com/api/v1/query?query=topk(10,%20apollo_operation_complexity)" | jq
   ```

3. **Identify Slow Queries**
   ```bash
   # Find slowest queries
   curl -s "https://prometheus.covermymeds.com/api/v1/query?query=topk(10,%20apollo_operation_duration_avg)" | jq
   ```

4. **Check Query Plans**
   ```bash
   # Enable query plan logging
   kubectl -n federated-graph edit configmap apollo-router-config
   # Enable verbose query planning logs
   
   # Extract query plans from logs
   kubectl -n federated-graph logs -l app=apollo-router | grep -A50 "query_plan" | head -500
   ```

## Runbook for Common Scenarios

### Complete Router Outage Recovery

1. **Assess Outage Scope**
   ```bash
   # Check pod status
   kubectl -n federated-graph get pods -l app=apollo-router
   
   # Check events
   kubectl -n federated-graph get events --sort-by='.lastTimestamp' | grep apollo-router
   ```

2. **Verify Configuration**
   ```bash
   # Check router config
   kubectl -n federated-graph get configmap apollo-router-config -o yaml
   
   # Check for recent changes
   kubectl -n federated-graph describe configmap apollo-router-config
   ```

3. **Check Supergraph Schema**
   ```bash
   # Check supergraph schema
   kubectl -n federated-graph exec -it $(kubectl -n federated-graph get pods -l app=debug-tools -o name | head -1) -- \
     curl -s http://router-admin.internal:8088/config/schema | head -20
   ```

4. **Recovery Steps**
   ```bash
   # Restore from backup if needed
   kubectl -n federated-graph apply -f $BACKUP_DIR/configs/apollo-router-config.yaml
   
   # Restart deployment
   kubectl -n federated-graph rollout restart deployment apollo-router
   
   # Monitor recovery
   kubectl -n federated-graph rollout status deployment apollo-router
   ```

5. **Verify Service Restoration**
   ```bash
   # Check health endpoint
   curl -s https://federated-graph-api.covermymeds.com/.well-known/apollo/server-health | jq
   
   # Run test query
   curl -s -X POST -H "Content-Type: application/json" \
     -d '{"query":"query { __typename }"}' \
     https://federated-graph-api.covermymeds.com/graphql | jq
   ```

### Schema Deployment Failure Recovery

1. **Identify Failed Deployment**
   ```bash
   # Check schema registry status
   rover subgraph list federated-graph-api@prod
   
   # Check for composition errors
   rover subgraph check federated-graph-api@prod \
     --name patient-subgraph \
     --schema ./schema.graphql
   ```

2. **Diagnose Schema Issues**
   ```bash
   # Compare with previous schema
   rover subgraph introspect https://patient-subgraph.internal:4001/graphql > current-schema.graphql
   
   diff previous-schema.graphql current-schema.graphql
   ```

3. **Recovery Steps**
   ```bash
   # Rollback to previous schema version
   rover subgraph publish federated-graph-api@prod \
     --name patient-subgraph \
     --schema ./previous-schema.graphql \
     --routing-url https://patient-subgraph.internal:4001/graphql
   
   # Deploy corrected subgraph if needed
   kubectl -n federated-graph rollout undo deployment patient-subgraph
   ```

4. **Verify Recovery**
   ```bash
   # Check composition status
   rover graph fetch federated-graph-api@prod
   
   # Test affected operations
   curl -s -X POST -H "Content-Type: application/json" \
     -d '{"query":"query { patient(id: \"patient-1\") { id name { given family } } }"}' \
     https://federated-graph-api.covermymeds.com/graphql | jq
   ```

### Rate Limiting and Traffic Overload Recovery

1. **Identify Overload**
   ```bash
   # Check request rate
   curl -s "https://prometheus.covermymeds.com/api/v1/query?query=sum(rate(apollo_router_http_requests_total[1m]))" | jq
   
   # Check resource utilization
   kubectl -n federated-graph top pods -l app=apollo-router
   ```

2. **Apply Rate Limits**
   ```bash
   # Update rate limiting configuration
   kubectl -n federated-graph edit configmap apollo-router-config
   # Add or adjust rate limiting settings
   ```

3. **Scale Up Resources**
   ```bash
   # Increase router replicas
   kubectl -n federated-graph scale deployment apollo-router --replicas=15
   
   # Scale affected subgraphs
   kubectl -n federated-graph scale deployment patient-subgraph --replicas=10
   ```

4. **Implement Circuit Breaking**
   ```bash
   # Add circuit breaker configuration
   kubectl -n federated-graph edit configmap apollo-router-config
   # Configure circuit breakers for overloaded services
   ```

5. **Verify Recovery**
   ```bash
   # Check error rate
   curl -s "https://prometheus.covermymeds.com/api/v1/query?query=sum(rate(apollo_router_operation_errors_total[5m]))%20/%20sum(rate(apollo_router_operations_total[5m]))" | jq
   
   # Check resource utilization
   kubectl -n federated-graph top pods
   ```

## Support and Escalation

### Support Levels

| Level | Responsibility | Response Time | Escalation Time |
|-------|----------------|---------------|-----------------|
| L1 | Initial triage, basic troubleshooting | 15 minutes | 30 minutes |
| L2 | Advanced troubleshooting, common issues | 30 minutes | 2 hours |
| L3 | Complex issues, component specialists | 1 hour | 4 hours |
| L4 | Vendor support, architectural issues | 4 hours | 24 hours |

### Escalation Process

1. **L1 to L2 Escalation**
   - Issue persists after basic troubleshooting
   - Problem affects multiple components
   - Unknown root cause after initial analysis

2. **L2 to L3 Escalation**
   - Complex issue requiring specialist knowledge
   - Potential architectural problem
   - Service impact exceeding 30 minutes

3. **L3 to L4 Escalation**
   - Suspected vendor bug or limitation
   - Architectural design issue
   - Critical service impact exceeding 2 hours

### Contact Information

| Role | Contact | Hours | Escalation Method |
|------|---------|-------|-------------------|
| On-call Engineer | on-call@covermymeds.com | 24/7 | PagerDuty |
| GraphQL Specialist | graphql-team@covermymeds.com | Business hours | Slack: #graphql-support |
| Infrastructure Lead | infra-lead@covermymeds.com | Business hours | Slack: #infrastructure |
| Apollo Support | support@apollographql.com | Business hours | Apollo Support Portal |

## Related Resources
- [Federated Graph API Monitoring](./monitoring.md)
- [Federated Graph API Maintenance](./maintenance.md)
- [Federated Graph API Deployment](./deployment.md)
- [Apollo Router Troubleshooting Guide](https://www.apollographql.com/docs/router/configuration/overview)