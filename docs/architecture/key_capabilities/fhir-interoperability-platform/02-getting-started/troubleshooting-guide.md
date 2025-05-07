# FHIR Interoperability Platform Troubleshooting Guide

## Introduction

This troubleshooting guide helps you diagnose and resolve common issues when working with the **FHIR Interoperability Platform**. Each section addresses a specific problem category with symptoms, causes, and step-by-step solutions for healthcare-specific integrations.

## How to Use This Guide

1. Identify your issue category in the table of contents
2. Review the symptoms to find the closest match to your problem
3. Follow the troubleshooting steps in order
4. If the issue persists, use the escalation process outlined at the end of this document

## Authentication Issues

### Issue: "Unauthorized" (401) Error

**Symptoms:**
- API returns 401 status code
- Error message: "Invalid credentials" or "Token expired"
- Authentication fails despite correct credentials
- SMART on FHIR launch fails

**Possible Causes:**
- Expired access token
- Incorrectly formatted credentials
- Missing required scopes
- Account lacks necessary permissions
- Invalid SMART launch context

**Solution:**

1. **Verify token expiration**
   ```typescript
   // Check token expiration before making requests
   if (isTokenExpired(token)) {
     token = await refreshToken();
   }
   ```

2. **Check credential format**
   - Ensure Bearer token is prefixed correctly: `Authorization: Bearer eyJ0eX...`
   - Verify API key format: `x-api-key: cmm_fhir_xxxxxxxxxxxx`
   - Confirm SMART on FHIR token includes all requested scopes

3. **Verify required SMART scopes**
   - Required scopes for patient access: `patient/*.read`
   - Required scopes for writing data: `patient/*.write`
   - Required scopes for launching within EHR: `launch/patient`
   - Request these scopes during authentication:
   ```typescript
   const authRequest = {
     scope: 'launch/patient patient/*.read patient/Medication.write'
   };
   ```

4. **Confirm user permissions**
   - Ask your administrator to check FHIR resource permissions
   - Minimum required role: `fhir-interop:Reader`
   - For write access, need: `fhir-interop:Contributor`

5. **Troubleshoot SMART on FHIR launch**
   - Verify redirect URI exactly matches the registered URI
   - Ensure the application is registered in Aidbox
   - Check that launch context contains required parameters
   ```typescript
   // Verify launch parameters
   console.log('Launch context:', JSON.parse(atob(launchParameter)));
   ```

### Issue: "Forbidden" (403) Error

**Symptoms:**
- API returns 403 status code
- Error message: "Insufficient permissions" or "Access denied"
- Authentication succeeds but operation fails
- Unable to access specific patient data

**Possible Causes:**
- User has authenticated successfully but lacks authorization for specific resource
- Patient compartment restrictions prevent access
- Resource belongs to different organization/tenant
- IP address is not in the allowed list
- SMART launch scope restricts access to specific patients

**Solution:**

1. **Verify patient compartment access**
   - When using patient-scoped tokens, you can only access resources in that patient's compartment
   - Check if you're trying to access data outside the authorized patient context
   ```typescript
   // For patient-scoped access, always include the patient reference
   const observations = await client.resources.Observation.search({
     patient: launchContext.patient
   });
   ```

2. **Review IP allow lists**
   - If using IP restrictions, verify your client IP is in the allow list
   - For cloud environments, check for NAT gateway or proxy IP changes
   - Healthcare environments often have strict network security

3. **Check tenant configuration**
   - Ensure your tenant is configured for multi-tenant access if needed
   - Review organization settings for access restrictions
   - Verify you have the correct organizational context set:
   ```typescript
   // Set organizational context in headers
   const patient = await client.resources.Patient.get('123', {
     headers: {
       'x-organization': 'Organization/healthcare-system-123'
     }
   });
   ```

4. **Verify cross-tenant permissions**
   - Healthcare data often has strict cross-organization sharing controls
   - Check if the resource has a different owner than your current context
   - Review consent directives that may restrict access

## Performance Issues

### Issue: Slow API Response Times

**Symptoms:**
- API calls take more than 2 seconds to complete
- Consistent latency across multiple requests
- Performance degrades with complex FHIR searches
- Bulk FHIR operations time out

**Possible Causes:**
- Connection pooling not configured properly
- Large FHIR resource payloads
- Inefficient FHIR search parameters
- Missing database indexes for common search patterns
- Geographic distance to service endpoint

**Solution:**

1. **Implement connection pooling**
   ```typescript
   // Create a reusable HTTP client with connection pooling
   const httpClient = new HttpClient({
     keepAlive: true,
     maxSockets: 25,
     timeout: 30000
   });
   ```

2. **Optimize FHIR search parameters**
   - Use specific search parameters instead of broad ones
   - Implement _include and _revinclude judiciously
   - Limit returned resources with _count parameter
   - Use _elements parameter to request only needed fields
   ```typescript
   // Optimized search example
   const patients = await client.resources.Patient.search({
     family: 'Smith',
     _elements: 'id,name,gender,birthDate',
     _count: 50
   });
   ```

3. **Use the closest regional endpoint**
   - Current endpoints by region:
     - East US: `https://eastus.fhir-interop.cmm.azure.com`
     - Central US: `https://centralus.fhir-interop.cmm.azure.com`
     - West US: `https://westus.fhir-interop.cmm.azure.com`

4. **Implement caching**
   - Cache responses with appropriate TTL
   - Use ETags for conditional requests
   ```typescript
   // Example using conditional request with ETag
   const response = await httpClient.get('/fhir/Patient/123', {
     headers: {
       'If-None-Match': previousEtag
     }
   });
   ```

5. **Use asynchronous bulk operations**
   - For large datasets, use FHIR Bulk Data Access API
   - Create an export job and poll for completion
   ```typescript
   // Start a patient-level export
   const exportResponse = await client.resources.Patient.operation('$export', {
     _type: 'Observation,MedicationRequest',
     _since: '2023-01-01T00:00:00Z'
   });
   
   // Get export status URL from Content-Location header
   const statusUrl = exportResponse.headers['content-location'];
   
   // Poll for completion
   let exportComplete = false;
   while (!exportComplete) {
     const statusResponse = await axios.get(statusUrl, {
       headers: { Authorization: `Bearer ${token}` }
     });
     
     if (statusResponse.status === 200) {
       exportComplete = true;
       // Download the exported files
       for (const file of statusResponse.data.output) {
         const fileData = await axios.get(file.url);
         // Process file data
       }
     } else {
       // Wait before polling again
       await new Promise(resolve => setTimeout(resolve, 5000));
     }
   }
   ```

### Issue: Rate Limiting

**Symptoms:**
- API returns 429 status code
- Error message: "Rate limit exceeded"
- Burst of traffic rejected
- Bulk data operations fail

**Possible Causes:**
- Too many requests in a short time period
- Inefficient FHIR request patterns
- Lack of client-side rate limiting
- Resource-intensive operations

**Solution:**

1. **Implement exponential backoff**
   ```typescript
   async function requestWithBackoff(url, options, maxRetries = 5) {
     let retries = 0;
     while (retries < maxRetries) {
       try {
         return await httpClient.fetch(url, options);
       } catch (error) {
         if (error.status === 429) {
           const delay = Math.pow(2, retries) * 1000 + Math.random() * 1000;
           console.log(`Rate limited. Retrying in ${delay}ms`);
           await new Promise(resolve => setTimeout(resolve, delay));
           retries++;
         } else {
           throw error;
         }
       }
     }
     throw new Error('Max retries exceeded');
   }
   ```

2. **Check rate limit headers**
   - Monitor these response headers:
     - `X-RateLimit-Limit`: Maximum requests per time window
     - `X-RateLimit-Remaining`: Remaining requests in current window
     - `X-RateLimit-Reset`: Seconds until window resets

3. **Optimize FHIR search strategies**
   - Use chained parameters instead of multiple requests
   - Combine multiple resource queries with FHIR batch operations
   - Implement client-side caching of reference resources
   
   ```typescript
   // Instead of multiple requests
   // BAD: Multiple separate requests
   const patient = await client.resources.Patient.get('123');
   const conditions = await client.resources.Condition.search({ patient: '123' });
   const medications = await client.resources.MedicationRequest.search({ patient: '123' });
   
   // GOOD: Use batch request
   const batchRequest = {
     resourceType: 'Bundle',
     type: 'batch',
     entry: [
       {
         request: { method: 'GET', url: 'Patient/123' }
       },
       {
         request: { method: 'GET', url: 'Condition?patient=123' }
       },
       {
         request: { method: 'GET', url: 'MedicationRequest?patient=123' }
       }
     ]
   };
   
   const batchResponse = await client.batch(batchRequest);
   ```

4. **Request rate limit increase**
   - If you consistently hit limits, request an increase via support
   - Be prepared to justify business need and expected traffic patterns
   - Consider enterprise tier for high-volume healthcare applications

## Data Issues

### Issue: Invalid FHIR Resource Format

**Symptoms:**
- API returns 400 status code
- Error message describes validation failures
- OperationOutcome details specific FHIR validation errors
- Data rejected despite appearing valid

**Possible Causes:**
- Incorrect FHIR resource structure
- Missing required fields by FHIR specification
- Invalid CodeSystem or ValueSet references
- Using deprecated FHIR elements
- Violating FHIR profiles or implementation guides

**Solution:**

1. **Validate against FHIR profiles**
   - Use the $validate operation to check resources before submitting
   - Check against US Core or other relevant implementation guides
   ```typescript
   // Validate a patient resource against US Core profile
   try {
     const validationResult = await client.resources.Patient.operation('$validate', {
       resource: patientData,
       profile: 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-patient'
     });
     console.log('Resource is valid');
   } catch (error) {
     console.error('Validation failed:', error.outcome);
     // Analyze OperationOutcome for specific issues
     error.outcome.issue.forEach(issue => {
       console.error(`${issue.severity} at ${issue.location}: ${issue.diagnostics}`);
     });
   }
   ```

2. **Check for common FHIR format issues**
   - Dates must be in ISO 8601 format: `YYYY-MM-DDTHH:MM:SSZ`
   - References must use the format: `ResourceType/id`
   - CodeableConcepts need valid system and code values
   - Ensure all required elements are present

3. **Common FHIR validation errors and fixes**
   
   | Error | Solution |
   |-------|----------|
   | "Element Patient.name: minimum required = 1" | Add at least one name element to the Patient resource |
   | "Value is not a valid date/time" | Ensure date format is YYYY-MM-DDTHH:MM:SS+ZZ:ZZ |
   | "Unknown code in system http://loinc.org" | Verify the code exists in the specified code system |
   | "Unable to resolve resource" | Ensure referenced resources exist in the system |
   | "Value doesn't match any pattern for type Identifier.system" | Use a valid URI format for identifier system |

4. **Use development tools**
   - Use the FHIR Validator (https://validator.fhir.org/)
   - Leverage client library validation features
   - Test in sandbox environment first
   - Use available FHIR testing tools like Inferno

### Issue: Missing or Unexpected Data

**Symptoms:**
- Response contains null or incomplete FHIR resources
- Expected extensions or profiles are missing
- Searches return fewer results than expected
- Data exists in one system but not in FHIR API

**Possible Causes:**
- Incorrect resource identifier
- Missing permissions for specific FHIR compartments
- FHIR API versioning mismatch
- Data processing lag
- Search parameters not matching expected patterns

**Solution:**

1. **Verify resource identifiers and references**
   - Confirm you're using the correct ID format and value
   - Remember that FHIR uses both logical and resource IDs
   - Check for namespace prefixes if required
   ```typescript
   // Check if resource exists with specific ID
   try {
     const exists = await client.resources.Patient.exists('patient123');
     console.log('Resource exists:', exists);
   } catch (error) {
     console.error('Error checking resource:', error);
   }
   ```

2. **Examine FHIR resource permissions**
   - Some resources may have restricted access based on sensitivity
   - Check if user has the required permissions for patient compartment
   - Some resources require elevated privileges (e.g., Provenance, AuditEvent)

3. **Verify FHIR version compatibility**
   - Specify the expected FHIR version explicitly
   ```typescript
   const response = await httpClient.get('/fhir/Patient/123', {
     headers: {
       'Accept': 'application/fhir+json; fhirVersion=4.0'
     }
   });
   ```

4. **Understand FHIR search limitations**
   - FHIR search has specific behaviors that differ from SQL
   - String searches are often prefix-based, not contains
   - Date searches require specific formats and precision
   - Token searches need exact system and code matches
   
   ```typescript
   // Common search parameter patterns
   
   // String search (prefix match)
   const nameSearch = await client.resources.Patient.search({
     name: 'Jon' // Will match "Jon", "Jonathan", etc.
   });
   
   // Token search (exact match)
   const identifierSearch = await client.resources.Patient.search({
     identifier: 'http://hospital.example.org|MRN123' // System|Code format
   });
   
   // Date search
   const observationSearch = await client.resources.Observation.search({
     date: 'ge2023-01-01' // Comparison operators: eq, ne, gt, lt, ge, le
   });
   
   // Reference search
   const conditionSearch = await client.resources.Condition.search({
     patient: 'Patient/123' // Full reference format
   });
   
   // Chained search
   const patientObservations = await client.resources.Observation.search({
     'patient.name': 'Smith' // Chained parameter
   });
   ```

## Integration Issues

### Issue: SMART on FHIR Launch Failures

**Symptoms:**
- Unable to launch SMART app from EHR
- Redirect errors during SMART authentication
- Missing patient context after successful launch
- Invalid scope errors

**Possible Causes:**
- Incorrect redirect URI configuration
- Missing or invalid scopes
- Launch context not properly passed
- EHR integration configuration issues
- PKCE implementation problems

**Solution:**

1. **Verify SMART app registration**
   - Ensure app is registered in Aidbox with correct redirect URIs
   - Check that all required scopes are registered
   - Verify client ID and secret are correct
   ```typescript
   // Example SMART app registration in Aidbox
   const smartApp = {
     resourceType: 'Client',
     id: 'my-smart-app',
     secret: 'app-secret',
     grant_types: ['authorization_code'],
     auth: {
       authorization_code: {
         redirect_uri: ['https://my-smart-app.example.org/callback']
       }
     },
     smart: {
       launch_uri: 'https://my-smart-app.example.org/launch'
     }
   };
   ```

2. **Check SMART launch sequence**
   - Ensure proper SMART launch flow implementation
   - Verify launch parameter is included in authorization request
   - Confirm state parameter usage for security
   
   ```typescript
   // Proper SMART on FHIR launch sequence
   async function handleSMARTLaunch() {
     // 1. Extract launch and iss parameters
     const urlParams = new URLSearchParams(window.location.search);
     const launch = urlParams.get('launch');
     const iss = urlParams.get('iss');
     
     if (!launch || !iss) {
       console.error('Missing launch or iss parameters');
       return;
     }
     
     // 2. Discover FHIR authorization endpoints
     const wellKnown = await fetch(`${iss}/.well-known/smart-configuration`).then(r => r.json());
     
     // 3. Generate PKCE code verifier and challenge
     const codeVerifier = generateRandomString(64);
     const codeChallenge = await generateCodeChallenge(codeVerifier);
     
     // 4. Store state in session storage
     const state = generateRandomString(32);
     sessionStorage.setItem('pkce_code_verifier', codeVerifier);
     sessionStorage.setItem('pkce_state', state);
     
     // 5. Redirect to authorization endpoint
     const authUrl = new URL(wellKnown.authorization_endpoint);
     authUrl.searchParams.append('response_type', 'code');
     authUrl.searchParams.append('client_id', 'my-smart-app');
     authUrl.searchParams.append('redirect_uri', 'https://my-smart-app.example.org/callback');
     authUrl.searchParams.append('scope', 'launch/patient patient/*.read');
     authUrl.searchParams.append('state', state);
     authUrl.searchParams.append('aud', iss);
     authUrl.searchParams.append('code_challenge', codeChallenge);
     authUrl.searchParams.append('code_challenge_method', 'S256');
     authUrl.searchParams.append('launch', launch);
     
     window.location.assign(authUrl.toString());
   }
   ```

3. **Implement proper PKCE flow**
   ```typescript
   // Generate PKCE code verifier and challenge
   function generateRandomString(length) {
     const array = new Uint8Array(length);
     window.crypto.getRandomValues(array);
     return Array.from(array, byte => 
       ('0' + (byte & 0xFF).toString(16)).slice(-2)
     ).join('');
   }
   
   async function generateCodeChallenge(verifier) {
     const encoder = new TextEncoder();
     const data = encoder.encode(verifier);
     const digest = await window.crypto.subtle.digest('SHA-256', data);
     return btoa(String.fromCharCode(...new Uint8Array(digest)))
       .replace(/\+/g, '-')
       .replace(/\//g, '_')
       .replace(/=/g, '');
   }
   ```

4. **Debug patient context issues**
   - After successful launch, verify patient context
   - Check for fhirUser claim in ID token
   - Ensure proper patient ID extraction
   
   ```typescript
   // Extract patient context from FHIR token
   function getPatientContextFromToken(idToken) {
     // Decode JWT token
     const tokenParts = idToken.split('.');
     const payload = JSON.parse(atob(tokenParts[1]));
     
     // Extract patient ID from token
     let patientId = null;
     
     if (payload.patient) {
       // Direct patient reference
       patientId = payload.patient;
     } else if (payload.fhirUser && payload.fhirUser.startsWith('Patient/')) {
       // Extract from fhirUser claim
       patientId = payload.fhirUser.replace('Patient/', '');
     }
     
     return patientId;
   }
   ```

### Issue: FHIR Subscription Integration Problems

**Symptoms:**
- Subscriptions are not triggering on resource changes
- Webhook endpoints are not receiving notifications
- Duplicate or missing event notifications
- Invalid payload format in received webhooks

**Possible Causes:**
- Webhook endpoint not responding properly
- Subscription criteria not matching resources
- Network connectivity issues
- Misconfigured REST hook authentication
- Event filtering too restrictive

**Solution:**

1. **Verify subscription configuration**
   - Check that subscription resource is active and properly configured
   - Ensure criteria matches the resources you want to monitor
   - Verify channel configuration is correct
   
   ```typescript
   // Example of a proper FHIR Subscription
   const subscription = {
     resourceType: 'Subscription',
     status: 'active',
     reason: 'Monitor patient updates',
     criteria: 'Patient?_format=application/fhir+json',
     channel: {
       type: 'rest-hook',
       endpoint: 'https://your-webhook-endpoint.example.org/fhir-events',
       payload: 'application/fhir+json',
       header: ['Authorization: Bearer ${token}']
     }
   };
   
   await client.resources.Subscription.create(subscription);
   ```

2. **Implement proper webhook endpoint**
   - Ensure your webhook endpoint returns 2xx status within 5 seconds
   - Handle payload validation and processing
   - Implement idempotent processing for possible duplicate events
   
   ```typescript
   // Example Express.js webhook endpoint
   app.post('/fhir-events', async (req, res) => {
     try {
       // Verify webhook signature if applicable
       const signature = req.headers['x-signature'];
       if (!verifySignature(req.body, signature, SECRET)) {
         return res.status(403).send('Invalid signature');
       }
       
       // Extract resource and process
       const resource = req.body;
       console.log(`Received ${resource.resourceType} update, id: ${resource.id}`);
       
       // Store event ID to prevent duplicate processing
       const eventId = req.headers['x-event-id'];
       if (await isEventProcessed(eventId)) {
         console.log(`Event ${eventId} already processed`);
         return res.status(200).send('OK');
       }
       
       // Process the resource update
       await processResourceUpdate(resource);
       
       // Mark event as processed
       await markEventProcessed(eventId);
       
       // Always return 200 OK quickly
       res.status(200).send('OK');
     } catch (error) {
       console.error('Error processing webhook:', error);
       // Still return 200 to acknowledge receipt
       res.status(200).send('Processed with errors');
     }
   });
   ```

3. **Use Topic-based subscriptions for R5**
   - If using FHIR R5 or Aidbox's R5 backport, use Topic-based subscriptions
   - More reliable and standardized approach
   
   ```typescript
   // R5-style topic-based subscription
   const subscription = {
     resourceType: 'Subscription',
     status: 'active',
     reason: 'Monitor medication prescriptions',
     topic: 'https://hl7.org/fhir/SubscriptionTopic/medication-prescribe',
     filterBy: [
       {
         resourceType: 'MedicationRequest',
         filterParameter: 'status',
         comparator: 'eq',
         value: 'active'
       }
     ],
     channel: {
       type: 'rest-hook',
       endpoint: 'https://your-webhook-endpoint.example.org/fhir-events',
       payload: 'application/fhir+json',
       header: ['Authorization: Bearer ${token}']
     }
   };
   ```

4. **Use Kafka integration for high-volume events**
   - For high-reliability event processing, use Kafka integration
   - Configure the event-integration service provided with the platform
   - Set up consumer applications to process events from Kafka
   
   ```typescript
   // Kafka consumer example
   const { Kafka } = require('kafkajs');
   
   const kafka = new Kafka({
     clientId: 'fhir-event-consumer',
     brokers: ['kafka-broker:9092']
   });
   
   const consumer = kafka.consumer({ groupId: 'medication-processors' });
   
   async function run() {
     await consumer.connect();
     await consumer.subscribe({ topic: 'fhir.MedicationRequest', fromBeginning: false });
     
     await consumer.run({
       eachMessage: async ({ topic, partition, message }) => {
         const fhirResource = JSON.parse(message.value.toString());
         console.log(`Processing ${fhirResource.resourceType}/${fhirResource.id}`);
         await processMedicationRequest(fhirResource);
       }
     });
   }
   
   run().catch(console.error);
   ```

## Deployment Issues

### Issue: Environment Configuration Problems

**Symptoms:**
- Application works in sandbox but fails in production
- Inconsistent behavior between environments
- Configuration-related error messages
- Authentication works in one environment but not another

**Possible Causes:**
- Environment-specific settings not configured
- Different FHIR server versions or capabilities
- Different implementation guide profiles enabled
- Resource limits or throttling differences
- Different authentication mechanisms 

**Solution:**

1. **Compare environment configurations**
   - Use the environment comparison tool in the portal
   - Check for environment-specific variables and settings
   - Verify FHIR Implementation Guide conformance
   ```typescript
   // Check server metadata and capabilities
   async function checkServerCapabilities() {
     try {
       const metadata = await client.capabilities();
       console.log('FHIR version:', metadata.fhirVersion);
       console.log('Supported formats:', metadata.format);
       console.log('Supported resources:');
       metadata.rest[0].resource.forEach(resource => {
         console.log(`- ${resource.type} (${resource.interaction.map(i => i.code).join(', ')})`);
       });
       return metadata;
     } catch (error) {
       console.error('Error checking capabilities:', error);
       throw error;
     }
   }
   ```

2. **Verify service principal permissions**
   - Ensure service principals have consistent role assignments
   - Check for conditional access policies that might affect authentication
   - Verify SMART app registrations in each environment

3. **Check profile and terminology settings**
   - Production environments often have stricter validation
   - Ensure resources conform to required implementation guides
   - Verify terminology bindings are valid
   ```typescript
   // Validate resource against specific profile
   async function validateResource(resource, profile) {
     try {
       await client.resources[resource.resourceType].operation('$validate', {
         resource,
         profile
       });
       return true;
     } catch (error) {
       console.error('Validation errors:', error.outcome);
       return false;
     }
   }
   ```

4. **Monitor resource utilization**
   - Different environments may have different quotas
   - Use metrics dashboard to monitor usage against limits
   - Consider implementing circuit breakers for production

5. **Test with environment-specific data**
   - Some validation rules may only trigger with real data
   - Use synthetic data generators to create realistic test data
   - Implement a test suite that runs against each environment

## FHIR-Specific Issues

### Issue: Integration with External FHIR Systems

**Symptoms:**
- Unable to connect to external FHIR endpoints
- Resource compatibility issues between systems
- Failed validation when importing external resources
- Different search behavior between systems

**Possible Causes:**
- FHIR version mismatches (R2, R3, R4, R5)
- Different implementation guides and profiles
- Proprietary extensions or constraints
- System-specific authentication requirements
- Different search parameter implementations

**Solution:**

1. **Implement FHIR version translation**
   - Use built-in translation services for cross-version support
   - Map between different FHIR versions when needed
   ```typescript
   // Convert from R2 to R4
   const r4Resource = await client.convert({
     resourceType: 'Parameters',
     parameter: [
       {
         name: 'resource',
         resource: r2Resource
       },
       {
         name: 'targetVersion',
         valueString: '4.0.1'
       }
     ]
   });
   ```

2. **Validate against target system profiles**
   - Different systems may have different validation rules
   - Check resources against target system profiles
   - Strip proprietary extensions when needed

3. **Implement search parameter mapping**
   - Create mappings between different system search parameters
   - Account for system-specific search behaviors
   ```typescript
   // Example search parameter mapping function
   function mapSearchParams(params, sourceSystem, targetSystem) {
     const mappings = {
       'epic': {
         'mrn': 'identifier=http://epic.com/MRN|',
         'har': 'identifier=http://epic.com/HAR|'
       },
       'cerner': {
         'mrn': 'identifier=http://cerner.com/mrn|',
         'fin': 'identifier=http://cerner.com/fin|'
       },
       'aidbox': {
         'mrn': 'identifier=http://aidbox.io/identifier/mrn|',
         'record-id': 'identifier=http://aidbox.io/identifier/record|'
       }
     };
     
     // Copy original params
     const targetParams = {...params};
     
     // Apply parameter mappings
     for (const [key, value] of Object.entries(params)) {
       if (mappings[sourceSystem][key]) {
         // Get the source param mapping pattern
         const sourcePattern = mappings[sourceSystem][key].split('=')[0];
         
         // Find equivalent in target system
         for (const [targetKey, targetValue] of Object.entries(mappings[targetSystem])) {
           if (targetValue.split('=')[0] === sourcePattern) {
             // Replace the key and value prefix if needed
             delete targetParams[key];
             const targetPrefix = targetValue.split('=')[1] || '';
             targetParams[targetKey] = targetPrefix + value;
           }
         }
       }
     }
     
     return targetParams;
   }
   ```

4. **Handle system-specific authentication**
   - Implement OAuth client credentials flow for system-to-system communication
   - Support SMART backend services authentication
   - Manage token lifecycle appropriately
   ```typescript
   // SMART backend services authentication
   async function getBackendServicesToken(audience) {
     const now = Math.floor(Date.now() / 1000);
     const claims = {
       iss: CLIENT_ID,
       sub: CLIENT_ID,
       aud: audience,
       exp: now + 300, // 5 minutes
       jti: uuidv4()
     };
     
     const privateKey = fs.readFileSync('private.key', 'utf8');
     const token = jwt.sign(claims, privateKey, { algorithm: 'RS384' });
     
     const response = await axios.post(TOKEN_URL, 
       new URLSearchParams({
         scope: 'system/*.read',
         grant_type: 'client_credentials',
         client_assertion_type: 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer',
         client_assertion: token
       }).toString(),
       {
         headers: {
           'Content-Type': 'application/x-www-form-urlencoded'
         }
       }
     );
     
     return response.data.access_token;
   }
   ```

### Issue: Terminology Validation Failures

**Symptoms:**
- Resources fail validation with terminology errors
- CodeableConcept fields rejected as invalid
- Cannot find expected codes in value sets
- Terminology services return unexpected results

**Possible Causes:**
- Invalid code system or value set references
- Missing terminology resources in the target environment
- Expired or outdated terminology resources
- Version mismatches between terminology resources
- System-specific terminology bindings

**Solution:**

1. **Verify code system and value set validity**
   - Ensure code systems are properly registered in the environment
   - Check that value sets contain expected codes
   - Use terminology validation operations
   ```typescript
   // Validate a code
   async function validateCode(system, code, display) {
     try {
       const result = await client.operation('ValueSet', '$validate-code', {
         url: 'http://hl7.org/fhir/ValueSet/condition-clinical',
         system: system,
         code: code,
         display: display
       });
       
       console.log('Code validation result:', result.result);
       console.log('Display is correct:', result.display);
       return result.result;
     } catch (error) {
       console.error('Code validation error:', error);
       return false;
     }
   }
   ```

2. **Use terminology expansion services**
   - Expand value sets to check available codes
   - Use filter parameters to find specific codes
   ```typescript
   // Expand a value set
   async function expandValueSet(valueSetUrl, filter) {
     try {
       const result = await client.operation('ValueSet', '$expand', {
         url: valueSetUrl,
         filter: filter,
         count: 100
       });
       
       console.log(`Found ${result.expansion.total} matching codes`);
       result.expansion.contains.forEach(code => {
         console.log(`- ${code.system}|${code.code}: ${code.display}`);
       });
       
       return result.expansion;
     } catch (error) {
       console.error('Value set expansion error:', error);
       throw error;
     }
   }
   ```

3. **Implement code system mapping**
   - Create mappings between different code systems
   - Handle proprietary to standard code translations
   ```typescript
   // Map between code systems
   async function mapCode(code, sourceSystem, targetSystem) {
     try {
       const result = await client.operation('ConceptMap', '$translate', {
         url: 'http://example.org/fhir/ConceptMap/mapping-systems',
         code: code,
         system: sourceSystem,
         target: targetSystem
       });
       
       if (result.result) {
         return result.match.map(match => ({
           code: match.code,
           system: match.system,
           equivalence: match.equivalence
         }));
       }
       return null;
     } catch (error) {
       console.error('Code mapping error:', error);
       return null;
     }
   }
   ```

4. **Use local terminology resources**
   - For critical systems, maintain local copies of terminology
   - Implement regular terminology updates
   - Validate resources against local terminology services

## Support and Escalation

If you've followed the troubleshooting steps and still face issues:

### Support Channels

- **Teams Channel**: `#fhir-interop-support`
- **Email Support**: [fhir-support@covermymeds.com](mailto:fhir-support@covermymeds.com)
- **Support Portal**: [https://support.covermymeds.com/fhir-interop](https://support.covermymeds.com/fhir-interop)

### Information to Provide

When seeking support, include the following information:

1. **Request Details**
   - Timestamp of the request
   - Request ID or correlation ID (from `x-request-id` header)
   - HTTP method and full URL path (excluding sensitive data)
   - Request headers and payload (redacted as needed)
   - Response status code and any error messages
   - OperationOutcome resource if available

2. **Environment Information**
   - Environment (dev, test, prod)
   - Client library name and version
   - Authentication method used
   - Region/endpoint accessed
   - Any recent changes to your integration

3. **Troubleshooting Steps**
   - Steps already attempted from this guide
   - Results of those troubleshooting steps
   - Any relevant error logs or screenshots
   - Browser console logs for SMART app issues

### Escalation Process

If your issue requires urgent attention:

1. **Severity Levels**
   
   | Severity | Description | Response Time |
   |----------|-------------|---------------|
   | Critical | Production outage, patient care impacted | 30 minutes |
   | High | Major functionality impacted, workaround exists | 2 hours |
   | Medium | Minor functionality impacted | 1 business day |
   | Low | Question or enhancement request | 3 business days |

2. **Escalation Contacts**
   - Level 1: FHIR Support Team - [fhir-support@covermymeds.com](mailto:fhir-support@covermymeds.com)
   - Level 2: FHIR Engineering Lead - [fhir-engineering-lead@covermymeds.com](mailto:fhir-engineering-lead@covermymeds.com)
   - Level 3: Healthcare Platform Director - [healthcare-platform-director@covermymeds.com](mailto:healthcare-platform-director@covermymeds.com)

## Related Resources

- [FHIR Interoperability Platform Overview](../01-overview/overview.md)
- [Local Development Setup](./local-setup.md)
- [Client Libraries Documentation](./client-libraries.md)
- [Core APIs Documentation](../03-core-functionality/core-apis.md)
- [FHIR Data Model](../03-core-functionality/data-model.md)
- [System Status Dashboard](https://status.covermymeds.com)
- [Aidbox Documentation](https://docs.aidbox.app/troubleshooting)
- [HL7 FHIR Specification](https://hl7.org/fhir/)