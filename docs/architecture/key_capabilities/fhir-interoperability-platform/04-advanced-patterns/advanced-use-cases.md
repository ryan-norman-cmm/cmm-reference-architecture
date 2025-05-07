# FHIR Interoperability Platform Advanced Use Cases

## Introduction
This document describes advanced use cases and patterns for the FHIR Interoperability Platform. These scenarios demonstrate how to leverage the platform's capabilities to solve complex healthcare interoperability challenges, integrate with other core components, and implement sophisticated workflows for CoverMyMeds' specific business needs.

## Use Case 1: Real-Time Prior Authorization Decision Support

### Scenario Description
Providers need real-time decision support during electronic prescription workflows to determine if a medication requires prior authorization and, if so, what clinical documentation is needed and what the likelihood of approval is based on historical data.

### Workflow Steps

1. **Clinical Data Capture**: During the prescription workflow, the EHR captures structured clinical data about the patient, diagnosis, and medication.

2. **FHIR Resource Creation**: The EHR creates and submits a FHIR Bundle containing Patient, Condition, MedicationRequest, and custom PriorAuthorizationCheck resources.

3. **Decision Support Processing**: The FHIR platform processes the request through a custom operation ($check-prior-authorization).

4. **Rules Evaluation**: The platform evaluates the medication against payer formularies, policy rules, and benefit design.

5. **Response Generation**: The platform generates a structured response including PA requirement, supporting documentation requirements, and approval likelihood.

6. **Real-Time Notification**: Results are returned in real-time to the provider workflow and trigger additional PA process if needed.

### Example Code/Configuration

#### Request Bundle Example

```typescript
import { AidboxClient } from '@aidbox/sdk-r4';

const client = new AidboxClient({
  url: 'https://fhir-api.covermymeds.com',
  auth: {
    type: 'bearer',
    token: 'YOUR_ACCESS_TOKEN'
  }
});

async function checkPriorAuthorization(patient, medication, diagnosis, prescriber) {
  // Create a Bundle with the necessary resources
  const bundle = {
    resourceType: 'Bundle',
    type: 'transaction',
    entry: [
      {
        resource: {
          resourceType: 'PriorAuthorizationCheck',
          status: 'active',
          patient: {
            reference: `Patient/${patient.id}`
          },
          medication: {
            reference: `Medication/${medication.id}`
          },
          diagnosis: [
            {
              reference: `Condition/${diagnosis.id}`
            }
          ],
          prescriber: {
            reference: `Practitioner/${prescriber.id}`
          },
          payer: {
            reference: 'Organization/payer-123'
          }
        },
        request: {
          method: 'POST',
          url: 'PriorAuthorizationCheck'
        }
      }
    ]
  };

  // Submit the Bundle
  try {
    const result = await client.request({
      method: 'POST',
      url: '/fhir/r4/$check-prior-authorization',
      body: bundle
    });
    
    console.log('PA Check Result:', result);
    return result;
  } catch (error) {
    console.error('Error checking PA:', error);
    throw error;
  }
}
```

#### Response Example

```json
{
  "resourceType": "PriorAuthorizationCheckResponse",
  "id": "example-pa-check-response",
  "status": "completed",
  "request": {
    "reference": "PriorAuthorizationCheck/example-pa-check"
  },
  "priorAuthorizationRequired": true,
  "approvalLikelihood": "medium",
  "requiresPatientHistoryReview": true,
  "requiredDocumentation": [
    {
      "type": {
        "coding": [
          {
            "system": "http://covermymeds.com/fhir/CodeSystem/documentation-type",
            "code": "previous-therapy",
            "display": "Previous Therapy Documentation"
          }
        ]
      },
      "description": "Documentation of previous step therapy with a first-line agent for at least 4 weeks"
    },
    {
      "type": {
        "coding": [
          {
            "system": "http://covermymeds.com/fhir/CodeSystem/documentation-type",
            "code": "lab-results",
            "display": "Laboratory Results"
          }
        ]
      },
      "description": "Recent laboratory test results including CBC within the last 30 days"
    }
  ],
  "alternativeMedications": [
    {
      "reference": "Medication/alternative-med-1",
      "display": "Preferred formulary alternative that doesn't require PA"
    }
  ],
  "coverage": {
    "reference": "Coverage/example-coverage",
    "display": "Patient's primary insurance coverage"
  },
  "policyReference": "http://payer.example.org/policies/medication-guidelines-2023.html",
  "nextSteps": [
    {
      "code": {
        "coding": [
          {
            "system": "http://covermymeds.com/fhir/CodeSystem/pa-next-steps",
            "code": "initiate-pa",
            "display": "Initiate Prior Authorization"
          }
        ]
      },
      "description": "Initiate a prior authorization for this medication",
      "action": {
        "type": "create-pa",
        "url": "/fhir/r4/PriorAuthorization/$create-from-check?checkId=example-pa-check"
      }
    }
  ]
}
```

## Use Case 2: Multi-Source Patient Data Aggregation

### Scenario Description
Healthcare providers need a comprehensive view of a patient's medical history aggregated from multiple sources, including external EHRs, payer systems, pharmacy networks, and patient-generated data.

### Workflow Steps

1. **Patient Identity Resolution**: A patient is identified across multiple systems using demographic information and identifiers.

2. **Data Source Discovery**: The FHIR platform identifies relevant data sources for the patient.

3. **Parallel Data Queries**: The platform queries multiple FHIR endpoints for patient data using appropriate authentication for each source.

4. **Data Normalization**: The retrieved resources are normalized to consistent FHIR profiles.

5. **Duplicate Detection**: Overlapping or duplicate resources are reconciled.

6. **Comprehensive View Generation**: A unified patient record is assembled and delivered.

### Example Code/Configuration

#### Patient Aggregation Service

```typescript
import { AidboxClient } from '@aidbox/sdk-r4';
import axios from 'axios';

class PatientDataAggregator {
  private fhirClient: any;
  private dataSources: DataSource[];
  
  constructor(fhirClient, dataSources) {
    this.fhirClient = fhirClient;
    this.dataSources = dataSources;
  }
  
  async aggregatePatientData(patientId, demographics) {
    try {
      // Step 1: Resolve patient identity across systems
      const patientMatches = await this.resolvePatientIdentity(demographics);
      
      // Step 2 & 3: Discover sources and query them in parallel
      const resourcePromises = [];
      
      for (const source of this.dataSources) {
        if (patientMatches[source.id]) {
          const sourcePatientId = patientMatches[source.id];
          resourcePromises.push(this.queryDataSource(source, sourcePatientId));
        }
      }
      
      // Wait for all queries to complete
      const allSourceData = await Promise.all(resourcePromises);
      
      // Step 4 & 5: Normalize and deduplicate data
      const normalizedData = this.normalizeData(allSourceData);
      const deduplicatedData = this.deduplicateResources(normalizedData);
      
      // Step 6: Generate comprehensive view
      const patientBundle = this.createPatientBundle(patientId, deduplicatedData);
      
      return patientBundle;
    } catch (error) {
      console.error('Error aggregating patient data:', error);
      throw error;
    }
  }
  
  private async resolvePatientIdentity(demographics) {
    // Implementation of patient matching across systems
    // Uses demographics, identifiers, etc.
    // Returns a map of source IDs to their local patient IDs
    
    // Example implementation
    const patientMatches = {};
    
    for (const source of this.dataSources) {
      try {
        const response = await axios.post(
          `${source.endpoint}/fhir/r4/Patient/$match`,
          {
            resourceType: 'Parameters',
            parameter: [
              {
                name: 'resource',
                resource: {
                  resourceType: 'Patient',
                  name: demographics.name,
                  birthDate: demographics.birthDate,
                  gender: demographics.gender,
                  address: demographics.address
                }
              }
            ]
          },
          {
            headers: {
              Authorization: `Bearer ${source.token}`,
              'Content-Type': 'application/fhir+json'
            }
          }
        );
        
        if (response.data.parameter) {
          const match = response.data.parameter.find(p => p.name === 'match');
          if (match && match.part) {
            const score = match.part.find(p => p.name === 'score');
            const patientId = match.part.find(p => p.name === 'id');
            
            if (score.valueDecimal > 0.9 && patientId) {
              patientMatches[source.id] = patientId.valueString;
            }
          }
        }
      } catch (error) {
        console.error(`Error matching patient in source ${source.id}:`, error);
      }
    }
    
    return patientMatches;
  }
  
  private async queryDataSource(source, patientId) {
    // Queries a data source for patient resources
    // Returns all relevant resources for the patient
    
    const resourceTypes = [
      'AllergyIntolerance',
      'Condition',
      'MedicationStatement',
      'MedicationRequest',
      'Observation',
      'Procedure',
      'Immunization',
      'DocumentReference'
    ];
    
    const resourcePromises = resourceTypes.map(async (resourceType) => {
      try {
        const response = await axios.get(
          `${source.endpoint}/fhir/r4/${resourceType}?patient=${patientId}`,
          {
            headers: {
              Authorization: `Bearer ${source.token}`,
              'Content-Type': 'application/fhir+json'
            }
          }
        );
        
        return {
          resourceType,
          source: source.id,
          data: response.data.entry ? response.data.entry.map(e => e.resource) : []
        };
      } catch (error) {
        console.error(`Error retrieving ${resourceType} from source ${source.id}:`, error);
        return {
          resourceType,
          source: source.id,
          data: []
        };
      }
    });
    
    return Promise.all(resourcePromises);
  }
  
  private normalizeData(allSourceData) {
    // Normalizes data to consistent FHIR profiles
    // Flattens the structure and adds provenance information
    
    const flattenedData = [];
    
    for (const sourceResults of allSourceData) {
      for (const resourceTypeResult of sourceResults) {
        const { resourceType, source, data } = resourceTypeResult;
        
        for (const resource of data) {
          // Add provenance information
          resource.meta = resource.meta || {};
          resource.meta.source = source;
          
          // Normalize to US Core or custom profiles as needed
          if (resourceType === 'Patient') {
            resource.meta.profile = ['http://hl7.org/fhir/us/core/StructureDefinition/us-core-patient'];
          } else if (resourceType === 'Condition') {
            resource.meta.profile = ['http://hl7.org/fhir/us/core/StructureDefinition/us-core-condition'];
          }
          // Add more normalization logic here
          
          flattenedData.push(resource);
        }
      }
    }
    
    return flattenedData;
  }
  
  private deduplicateResources(resources) {
    // Detects and merges duplicate resources
    // Uses various heuristics based on resource type
    
    // Group resources by type
    const resourcesByType = {};
    
    for (const resource of resources) {
      const type = resource.resourceType;
      resourcesByType[type] = resourcesByType[type] || [];
      resourcesByType[type].push(resource);
    }
    
    // Deduplicate each resource type
    const deduplicatedResources = [];
    
    for (const [type, typeResources] of Object.entries(resourcesByType)) {
      // Different deduplication strategies per resource type
      if (type === 'Condition') {
        deduplicatedResources.push(...this.deduplicateConditions(typeResources));
      } else if (type === 'MedicationStatement' || type === 'MedicationRequest') {
        deduplicatedResources.push(...this.deduplicateMedications(typeResources));
      } else {
        // Default strategy
        deduplicatedResources.push(...this.deduplicateByCode(typeResources));
      }
    }
    
    return deduplicatedResources;
  }
  
  private deduplicateConditions(conditions) {
    // Example condition deduplication logic
    const uniqueConditions = new Map();
    
    for (const condition of conditions) {
      // Generate a key based on code and onset date (if available)
      let key = null;
      
      if (condition.code && condition.code.coding && condition.code.coding.length > 0) {
        const coding = condition.code.coding[0];
        key = `${coding.system}|${coding.code}`;
        
        if (condition.onsetDateTime) {
          key += `|${condition.onsetDateTime.substr(0, 10)}`; // Just use the date part
        }
      }
      
      if (key && !uniqueConditions.has(key)) {
        uniqueConditions.set(key, condition);
      } else if (key) {
        // If we already have this condition, merge any additional information
        const existing = uniqueConditions.get(key);
        
        // Keep the more specific version or the more recent one
        if (condition.recordedDate && (!existing.recordedDate || new Date(condition.recordedDate) > new Date(existing.recordedDate))) {
          uniqueConditions.set(key, condition);
        }
      }
    }
    
    return Array.from(uniqueConditions.values());
  }
  
  private deduplicateMedications(medications) {
    // Implement medication-specific deduplication
    // Similar to the condition approach but with medication-specific logic
    return medications; // Placeholder
  }
  
  private deduplicateByCode(resources) {
    // Generic deduplication strategy based on coding
    return resources; // Placeholder
  }
  
  private createPatientBundle(patientId, resources) {
    // Create a Bundle with the patient and all aggregated resources
    return {
      resourceType: 'Bundle',
      type: 'document',
      entry: [
        {
          resource: {
            resourceType: 'Patient',
            id: patientId,
            // Patient data would be here
          }
        },
        ...resources.map(resource => ({
          resource
        }))
      ]
    };
  }
}

// Example usage
const fhirClient = new AidboxClient({
  url: 'https://fhir-api.covermymeds.com',
  auth: {
    type: 'bearer',
    token: 'YOUR_ACCESS_TOKEN'
  }
});

const dataSources = [
  {
    id: 'internal-ehr',
    name: 'Primary EHR',
    endpoint: 'https://ehr-fhir.example.org',
    token: 'EHR_ACCESS_TOKEN'
  },
  {
    id: 'insurance-payer',
    name: 'Insurance Claims',
    endpoint: 'https://payer-fhir.example.org',
    token: 'PAYER_ACCESS_TOKEN'
  },
  {
    id: 'pharmacy-network',
    name: 'Pharmacy Network',
    endpoint: 'https://pharmacy-fhir.example.org',
    token: 'PHARMACY_ACCESS_TOKEN'
  }
];

const aggregator = new PatientDataAggregator(fhirClient, dataSources);

// Get comprehensive patient data
aggregator.aggregatePatientData('patient-123', {
  name: [{ given: ['Jane'], family: 'Smith' }],
  birthDate: '1980-01-01',
  gender: 'female',
  address: [{ city: 'Columbus', state: 'OH' }]
}).then(patientBundle => {
  console.log('Aggregated patient data:', patientBundle);
}).catch(error => {
  console.error('Error:', error);
});
```

## Use Case 3: Real-Time Clinical Decision Support Using FHIR and CQL

### Scenario Description
Clinicians need real-time decision support integrated into the workflow to identify potential medication interactions, gaps in care, and clinical practice guideline recommendations based on patient-specific data.

### Workflow Steps

1. **Clinical Data Collection**: Patient data is gathered in FHIR format, including current medications, conditions, observations, and allergies.

2. **Knowledge Selection**: Relevant Clinical Quality Language (CQL) libraries are selected based on the clinical context.

3. **CQL Execution**: The FHIR platform processes the patient data against the CQL libraries.

4. **Alert Generation**: Clinically relevant alerts and recommendations are generated based on the CQL evaluation.

5. **Context-Aware Presentation**: Alerts are delivered to the clinician with supporting evidence and actions.

6. **Action Documentation**: Clinician responses to alerts are documented in the system.

### Example Code/Configuration

#### CQL Library Example (Medication Interaction Check)

```cql
library MedicationInteractionCheck version '1.0'

using FHIR version '4.0.1'

include FHIRHelpers version '4.0.1' called FHIRHelpers

codesystem "RxNorm": 'http://www.nlm.nih.gov/research/umls/rxnorm'
codesystem "SNOMED": 'http://snomed.info/sct'

// Define Warfarin medications
define "Warfarin Medications":
  [MedicationRequest: "RxNorm" in "2101|11289|73137"] // RxNorm codes for warfarin

// Define NSAIDs
define "NSAID Medications":
  [MedicationRequest: "RxNorm" in "1117|1191|1166|5640|8163|10993"] // RxNorm codes for common NSAIDs

// Check for concurrent use of Warfarin and NSAIDs
define "Warfarin NSAID Interaction Risk":
  exists("Warfarin Medications" W
    where W.status in {'active', 'completed', 'on-hold'}
      and exists("NSAID Medications" N
        where N.status in {'active', 'completed', 'on-hold'}
      )
  )

// Define patients with kidney disease
define "Chronic Kidney Disease":
  [Condition: "SNOMED" in "90688005|709044004|714152005"] // SNOMED codes for CKD

// Check for NSAID use in kidney disease
define "NSAID Kidney Disease Risk":
  exists("NSAID Medications" N
    where N.status in {'active', 'completed', 'on-hold'}
      and exists("Chronic Kidney Disease" C
        where C.clinicalStatus ~ 'active'
      )
  )

// Combined risk assessment
define "Medication Risk Assessment":
  if "Warfarin NSAID Interaction Risk"
    then 'high-risk-interaction'
  else if "NSAID Kidney Disease Risk"
    then 'contraindication'
  else
    'no-risk-detected'
```

#### Implementing CDS in FHIR

```typescript
import { AidboxClient } from '@aidbox/sdk-r4';

class ClinicalDecisionSupport {
  private fhirClient: any;
  
  constructor(fhirClient) {
    this.fhirClient = fhirClient;
  }
  
  async evaluateClinicalRules(patientId, context) {
    try {
      // Execute CQL against patient data
      const result = await this.fhirClient.request({
        method: 'POST',
        url: '/fhir/r4/Library/$evaluate',
        body: {
          resourceType: 'Parameters',
          parameter: [
            {
              name: 'library',
              valueString: 'MedicationInteractionCheck'
            },
            {
              name: 'patientId',
              valueString: patientId
            },
            {
              name: 'context',
              valueString: context
            }
          ]
        }
      });
      
      // Process results to generate alerts
      const alerts = this.generateAlerts(result);
      
      return alerts;
    } catch (error) {
      console.error('Error evaluating clinical rules:', error);
      throw error;
    }
  }
  
  private generateAlerts(cqlResults) {
    // Extract relevant results from CQL evaluation
    const parameters = cqlResults.parameter || [];
    const alerts = [];
    
    // Process each result
    for (const param of parameters) {
      if (param.name === 'Warfarin NSAID Interaction Risk' && param.valueBoolean === true) {
        alerts.push({
          severity: 'high',
          category: 'medication-interaction',
          summary: 'Potential Warfarin-NSAID Interaction',
          detail: 'Concurrent use of Warfarin and NSAIDs increases the risk of bleeding.',
          suggestion: 'Consider alternative pain management or gastric protection.',
          evidence: 'https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3206664/',
          actions: [
            {
              type: 'create',
              description: 'Document risk acknowledgment',
              resource: {
                resourceType: 'Flag',
                status: 'active',
                category: {
                  coding: [
                    {
                      system: 'http://terminology.hl7.org/CodeSystem/flag-category',
                      code: 'medication',
                      display: 'Medication'
                    }
                  ]
                },
                code: {
                  coding: [
                    {
                      system: 'http://covermymeds.com/fhir/CodeSystem/alert-code',
                      code: 'interaction-acknowledged',
                      display: 'Interaction Risk Acknowledged'
                    }
                  ]
                }
              }
            }
          ]
        });
      }
      
      if (param.name === 'NSAID Kidney Disease Risk' && param.valueBoolean === true) {
        alerts.push({
          severity: 'high',
          category: 'contraindication',
          summary: 'NSAID Contraindicated in Kidney Disease',
          detail: 'Use of NSAIDs in patients with kidney disease may worsen renal function.',
          suggestion: 'Consider acetaminophen or consult nephrology.',
          evidence: 'https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5422108/',
          actions: [
            {
              type: 'update',
              description: 'Discontinue NSAID',
              resource: {
                resourceType: 'MedicationRequest',
                status: 'stopped',
                statusReason: {
                  coding: [
                    {
                      system: 'http://terminology.hl7.org/CodeSystem/medicationrequest-status-reason',
                      code: 'contraindicated',
                      display: 'Contraindicated'
                    }
                  ]
                }
              }
            }
          ]
        });
      }
    }
    
    return alerts;
  }
  
  async documentAlertResponse(alertId, response) {
    // Document the clinician's response to an alert
    try {
      const documentationResource = {
        resourceType: 'Provenance',
        recorded: new Date().toISOString(),
        activity: {
          coding: [
            {
              system: 'http://terminology.hl7.org/CodeSystem/v3-DataOperation',
              code: 'RESPMOD',
              display: 'Response Modified'
            }
          ]
        },
        agent: [
          {
            type: {
              coding: [
                {
                  system: 'http://terminology.hl7.org/CodeSystem/provenance-participant-type',
                  code: 'author',
                  display: 'Author'
                }
              ]
            },
            who: {
              reference: response.clinicianReference
            }
          }
        ],
        entity: [
          {
            role: 'source',
            what: {
              reference: `Alert/${alertId}`
            }
          }
        ],
        reason: [
          {
            coding: [
              {
                system: 'http://covermymeds.com/fhir/CodeSystem/alert-response-reason',
                code: response.reasonCode,
                display: response.reasonDisplay
              }
            ],
            text: response.comment
          }
        ]
      };
      
      const result = await this.fhirClient.fhirCreate('Provenance', documentationResource);
      return result;
    } catch (error) {
      console.error('Error documenting alert response:', error);
      throw error;
    }
  }
}

// Example usage
const fhirClient = new AidboxClient({
  url: 'https://fhir-api.covermymeds.com',
  auth: {
    type: 'bearer',
    token: 'YOUR_ACCESS_TOKEN'
  }
});

const cds = new ClinicalDecisionSupport(fhirClient);

// Get alerts for a patient
cds.evaluateClinicalRules('patient-123', 'medication-prescribing').then(alerts => {
  console.log('Clinical alerts:', alerts);
  
  // Example of documenting a response to an alert
  if (alerts.length > 0) {
    cds.documentAlertResponse('alert-1', {
      clinicianReference: 'Practitioner/doctor-456',
      reasonCode: 'benefits-outweigh-risks',
      reasonDisplay: 'Benefits outweigh risks',
      comment: 'Patient has been educated about risks and is monitoring for side effects.'
    }).then(result => {
      console.log('Alert response documented:', result);
    });
  }
}).catch(error => {
  console.error('Error:', error);
});
```

## Use Case 4: SMART on FHIR App Integration for Specialized Care Workflows

### Scenario Description
Clinicians need specialized applications to support complex care workflows, such as pre-visit planning, clinical trial eligibility assessment, and medication adherence monitoring. These apps need to seamlessly integrate with the EHR and leverage the patient's FHIR data.

### Workflow Steps

1. **App Registration**: The SMART app is registered with the FHIR platform's authorization server.

2. **Launch Context Preparation**: The EHR prepares launch context (patient, encounter, practitioner).

3. **App Launch**: The app is launched from the EHR with appropriate context parameters.

4. **Authorization**: OAuth 2.0 flow is completed, and the app receives an access token.

5. **Data Access**: The app uses the FHIR API to read and write relevant clinical data.

6. **Workflow Integration**: App results are sent back to the EHR.

### Example Code/Configuration

#### SMART App Registration Configuration

```json
{
  "resourceType": "SMARTAppConfig",
  "id": "adherence-monitor-app",
  "name": "Medication Adherence Monitor",
  "description": "Tracks and visualizes patient medication adherence patterns",
  "clientId": "adherence-monitor-client",
  "redirectUri": "https://adherence-app.covermymeds.com/redirect",
  "launchUrl": "https://adherence-app.covermymeds.com/launch",
  "scopes": "launch patient/*.read user/*.write",
  "supportedContexts": ["patient", "encounter", "practitioner"],
  "logoUrl": "https://adherence-app.covermymeds.com/logo.png",
  "accessTokenLifetime": 3600,
  "refreshTokenLifetime": 86400,
  "allowOfflineAccess": true,
  "allowPatientSearch": false,
  "jwtSigningAlgorithm": "RS256",
  "jwtSigningKey": "-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAA...\n-----END PUBLIC KEY-----"
}
```

#### SMART App Launch Implementation

```typescript
// Client-side SMART App launch code

// 1. Parse the SMART launch parameters
function parseSmartLaunchParams() {
  const urlParams = new URLSearchParams(window.location.search);
  const launchParam = urlParams.get('launch');
  const issParam = urlParams.get('iss');
  
  if (!launchParam || !issParam) {
    throw new Error('Missing required SMART launch parameters');
  }
  
  return { launch: launchParam, iss: issParam };
}

// 2. Discover FHIR server OAuth2 endpoints
async function discoverAuthEndpoints(issuer) {
  try {
    const response = await fetch(`${issuer}/.well-known/smart-configuration`);
    const config = await response.json();
    
    return {
      authorizationEndpoint: config.authorization_endpoint,
      tokenEndpoint: config.token_endpoint,
      registrationEndpoint: config.registration_endpoint
    };
  } catch (error) {
    console.error('Error discovering auth endpoints:', error);
    throw error;
  }
}

// 3. Initiate the authorization process
function initiateAuthorization(authEndpoint, clientId, redirectUri, launchParam) {
  const state = generateRandomString(32);
  sessionStorage.setItem('smart_state', state);
  
  const authUrl = new URL(authEndpoint);
  authUrl.searchParams.append('response_type', 'code');
  authUrl.searchParams.append('client_id', clientId);
  authUrl.searchParams.append('redirect_uri', redirectUri);
  authUrl.searchParams.append('launch', launchParam);
  authUrl.searchParams.append('scope', 'launch patient/*.read user/*.write');
  authUrl.searchParams.append('state', state);
  authUrl.searchParams.append('aud', issParam);
  
  window.location.href = authUrl.toString();
}

// 4. Handle the redirect and exchange the code for a token
async function handleAuthRedirect(tokenEndpoint, clientId, clientSecret, redirectUri) {
  const urlParams = new URLSearchParams(window.location.search);
  const code = urlParams.get('code');
  const state = urlParams.get('state');
  const storedState = sessionStorage.getItem('smart_state');
  
  if (!code) {
    throw new Error('No authorization code received');
  }
  
  if (state !== storedState) {
    throw new Error('State parameter mismatch');
  }
  
  try {
    const response = await fetch(tokenEndpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      body: new URLSearchParams({
        grant_type: 'authorization_code',
        code: code,
        redirect_uri: redirectUri,
        client_id: clientId,
        client_secret: clientSecret
      })
    });
    
    const tokenData = await response.json();
    
    // Store tokens securely
    sessionStorage.setItem('access_token', tokenData.access_token);
    sessionStorage.setItem('refresh_token', tokenData.refresh_token);
    sessionStorage.setItem('patient', tokenData.patient);
    sessionStorage.setItem('token_expiry', Date.now() + (tokenData.expires_in * 1000));
    
    return tokenData;
  } catch (error) {
    console.error('Error exchanging code for token:', error);
    throw error;
  }
}

// 5. Create a FHIR client using the access token
function createFhirClient(serverUrl, accessToken) {
  return {
    request: async (path, options = {}) => {
      const url = `${serverUrl}${path}`;
      const headers = {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/fhir+json',
        'Accept': 'application/fhir+json',
        ...options.headers
      };
      
      const response = await fetch(url, {
        method: options.method || 'GET',
        headers,
        body: options.body ? JSON.stringify(options.body) : undefined
      });
      
      if (!response.ok) {
        throw new Error(`FHIR API error: ${response.status} ${response.statusText}`);
      }
      
      return response.json();
    },
    getPatient: async () => {
      const patientId = sessionStorage.getItem('patient');
      return this.request(`/Patient/${patientId}`);
    },
    getMedications: async () => {
      const patientId = sessionStorage.getItem('patient');
      return this.request(`/MedicationRequest?patient=${patientId}&status=active`);
    },
    recordAdherence: async (medicationRequestId, adherenceData) => {
      return this.request('/Observation', {
        method: 'POST',
        body: {
          resourceType: 'Observation',
          status: 'final',
          code: {
            coding: [
              {
                system: 'http://covermymeds.com/fhir/CodeSystem/adherence-observation',
                code: 'medication-adherence',
                display: 'Medication Adherence'
              }
            ]
          },
          subject: {
            reference: `Patient/${sessionStorage.getItem('patient')}`
          },
          focus: [
            {
              reference: `MedicationRequest/${medicationRequestId}`
            }
          ],
          effectiveDateTime: new Date().toISOString(),
          valueQuantity: {
            value: adherenceData.adherencePercent,
            unit: '%',
            system: 'http://unitsofmeasure.org',
            code: '%'
          },
          component: [
            {
              code: {
                coding: [
                  {
                    system: 'http://covermymeds.com/fhir/CodeSystem/adherence-component',
                    code: 'missed-doses',
                    display: 'Missed Doses'
                  }
                ]
              },
              valueInteger: adherenceData.missedDoses
            },
            {
              code: {
                coding: [
                  {
                    system: 'http://covermymeds.com/fhir/CodeSystem/adherence-component',
                    code: 'reason',
                    display: 'Non-adherence Reason'
                  }
                ]
              },
              valueCodeableConcept: {
                coding: [
                  {
                    system: 'http://covermymeds.com/fhir/CodeSystem/adherence-reason',
                    code: adherenceData.reasonCode,
                    display: adherenceData.reasonDisplay
                  }
                ]
              }
            }
          ]
        }
      });
    }
  };
}

// Full SMART app initialization
async function initializeSmartApp() {
  try {
    // For SMART app launch flow
    if (window.location.pathname.includes('/launch')) {
      const { launch, iss } = parseSmartLaunchParams();
      const authEndpoints = await discoverAuthEndpoints(iss);
      sessionStorage.setItem('fhir_server_url', iss);
      
      initiateAuthorization(
        authEndpoints.authorizationEndpoint,
        'adherence-monitor-client',
        'https://adherence-app.covermymeds.com/redirect',
        launch
      );
    }
    // For redirect after authorization
    else if (window.location.pathname.includes('/redirect')) {
      const tokenEndpoint = sessionStorage.getItem('token_endpoint');
      const fhirServerUrl = sessionStorage.getItem('fhir_server_url');
      
      const tokenData = await handleAuthRedirect(
        tokenEndpoint,
        'adherence-monitor-client',
        'YOUR_CLIENT_SECRET',
        'https://adherence-app.covermymeds.com/redirect'
      );
      
      const fhirClient = createFhirClient(fhirServerUrl, tokenData.access_token);
      
      // Initialize app with FHIR client
      initializeAdherenceApp(fhirClient);
    }
    // For standalone launch
    else {
      console.log('Standalone launch not supported');
    }
  } catch (error) {
    console.error('Error initializing SMART app:', error);
    displayError(error.message);
  }
}

// Helper function to generate random string for state parameter
function generateRandomString(length) {
  const possible = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  let text = '';
  
  for (let i = 0; i < length; i++) {
    text += possible.charAt(Math.floor(Math.random() * possible.length));
  }
  
  return text;
}
```

## Additional Advanced Patterns

### FHIR Subscription for Real-Time Notifications

The FHIR Interoperability Platform supports real-time notifications through FHIR Subscription resources, allowing systems to be notified when resources change.

```typescript
// Creating a FHIR Subscription for medication changes
async function createMedicationChangeSubscription(patientId, notificationEndpoint) {
  const subscriptionResource = {
    resourceType: 'Subscription',
    status: 'active',
    reason: 'Monitor medication changes for the patient',
    criteria: `MedicationRequest?patient=${patientId}&status=active`,
    channel: {
      type: 'rest-hook',
      endpoint: notificationEndpoint,
      payload: 'application/fhir+json',
      header: ['Authorization: Bearer {token}']
    }
  };
  
  try {
    const result = await fhirClient.fhirCreate('Subscription', subscriptionResource);
    console.log('Subscription created:', result);
    return result;
  } catch (error) {
    console.error('Error creating subscription:', error);
    throw error;
  }
}
```

### FHIR Bulk Data for Population Health Analytics

The FHIR Interoperability Platform supports bulk data operations for population health analytics and reporting.

```typescript
// Initiating a bulk data export for a patient group
async function exportPatientGroupData(groupId) {
  try {
    const response = await fetch(`https://fhir-api.covermymeds.com/fhir/r4/Group/${groupId}/$export`, {
      method: 'GET',
      headers: {
        'Authorization': 'Bearer YOUR_ACCESS_TOKEN',
        'Accept': 'application/fhir+json',
        'Prefer': 'respond-async'
      }
    });
    
    if (response.status === 202) {
      const contentLocation = response.headers.get('Content-Location');
      console.log('Export initiated, status endpoint:', contentLocation);
      return contentLocation;
    } else {
      throw new Error(`Unexpected response: ${response.status}`);
    }
  } catch (error) {
    console.error('Error initiating group export:', error);
    throw error;
  }
}
```

### FHIR Terminology Services for Standardized Coding

The FHIR Interoperability Platform provides terminology services for standardized coding and value set validation.

```typescript
// Expanding a value set for code validation
async function expandValueSet(valueSetUrl) {
  try {
    const result = await fhirClient.request({
      method: 'GET',
      url: `/fhir/r4/ValueSet/$expand?url=${encodeURIComponent(valueSetUrl)}`
    });
    
    console.log('ValueSet expansion:', result);
    return result;
  } catch (error) {
    console.error('Error expanding value set:', error);
    throw error;
  }
}
```

## Related Resources
- [FHIR Interoperability Platform Customization](./customization.md)
- [FHIR Interoperability Platform Extension Points](./extension-points.md)
- [FHIR Interoperability Platform Core APIs](../02-core-functionality/core-apis.md)
- [FHIR Interoperability Platform Data Model](../02-core-functionality/data-model.md)
- [SMART App Launch Implementation Guide](http://hl7.org/fhir/smart-app-launch/)
- [FHIR Bulk Data Access Implementation Guide](https://hl7.org/fhir/uv/bulkdata/)