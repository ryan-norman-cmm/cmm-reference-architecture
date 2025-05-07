# FHIR Interoperability Platform Extension Points

## Introduction
This document outlines the extension points provided by the FHIR Interoperability Platform. These extension points enable developers to extend and integrate the platform's functionality to meet specific business needs, adapt to different environments, and implement custom behaviors. Unlike basic customization options, extension points represent deeper integration possibilities that involve writing custom code, implementing interfaces, or modifying the platform's behavior through well-defined hooks and plugins.

## Available Extension Points

### Server Extensions

#### Custom Resource Validation

The FHIR Interoperability Platform allows you to implement custom validation logic for FHIR resources to enforce business rules beyond standard FHIR validation.

**When to Use**:
- Enforcing organization-specific constraints
- Implementing complex conditional validation rules
- Validating relationships between resources
- Ensuring data quality for specific workflows

**Implementation Example**:

```typescript
import { AidboxClient, ResourceValidationHook } from '@aidbox/sdk-r4';

// Custom resource validator implementation
export class MedicationRequestValidator implements ResourceValidationHook {
  private readonly requireDiagnosis: boolean;
  private readonly maxActivePerPatient: number;
  private readonly fhirClient: AidboxClient;
  
  constructor(config: {requireDiagnosis?: boolean, maxActivePerPatient?: number}, fhirClient: AidboxClient) {
    // Initialize properties with defaults if not provided
    this.requireDiagnosis = config.requireDiagnosis ?? true;
    this.maxActivePerPatient = config.maxActivePerPatient ?? 20;
    this.fhirClient = fhirClient;
  }
  
  // Implementation of required interface method
  async validate(resource: any): Promise<ValidationResult> {
    if (resource.resourceType !== 'MedicationRequest') {
      // Only validate MedicationRequest resources
      return { valid: true };
    }
    
    const issues = [];
    
    // Check for required diagnosis if configured
    if (this.requireDiagnosis && !resource.reasonReference && !resource.reasonCode) {
      issues.push({
        severity: 'error',
        code: 'business-rule',
        diagnostics: 'MedicationRequest must include a diagnosis via reasonReference or reasonCode',
        expression: ['MedicationRequest.reasonReference', 'MedicationRequest.reasonCode']
      });
    }
    
    // Check for maximum active medications per patient
    if (resource.status === 'active' && resource.subject && resource.subject.reference) {
      try {
        const patientId = resource.subject.reference.split('/')[1];
        const existingMeds = await this.fhirClient.fhirSearch('MedicationRequest', {
          patient: patientId,
          status: 'active'
        });
        
        if (existingMeds.total >= this.maxActivePerPatient) {
          issues.push({
            severity: 'warning',
            code: 'business-rule',
            diagnostics: `Patient has ${existingMeds.total} active medications, which exceeds the recommended maximum of ${this.maxActivePerPatient}`,
            expression: ['MedicationRequest.status']
          });
        }
      } catch (error) {
        console.error('Error checking active medications:', error);
      }
    }
    
    return {
      valid: issues.length === 0,
      issues: issues
    };
  }
}

// Usage example
const fhirClient = new AidboxClient({
  url: 'https://fhir-api.covermymeds.com',
  auth: {
    type: 'bearer',
    token: 'YOUR_ACCESS_TOKEN'
  }
});

const medicationValidator = new MedicationRequestValidator({
  requireDiagnosis: true,
  maxActivePerPatient: 15
}, fhirClient);

// Register the validator with the Aidbox server
export function registerValidators(app) {
  app.resourceValidator('MedicationRequest', medicationValidator.validate.bind(medicationValidator));
}
```

#### Custom Search Parameter Processing

The FHIR Interoperability Platform allows you to implement custom search parameter processors to support advanced search capabilities.

**When to Use**:
- Implementing complex search logic
- Supporting non-standard search parameters
- Optimizing search performance for specific queries
- Implementing domain-specific search features

**Implementation Example**:

```typescript
import { SearchParameterProcessor } from '@aidbox/sdk-r4';

/**
 * Custom search parameter processor for advanced medication searches
 */
class MedicationSearchProcessor implements SearchParameterProcessor {
  // Properties and configuration
  private readonly terminologyService: any;
  private readonly useHierarchicalSearch: boolean;
  
  constructor(config: {useHierarchicalSearch?: boolean, terminologyService: any}) {
    this.terminologyService = config.terminologyService;
    this.useHierarchicalSearch = config.useHierarchicalSearch ?? true;
  }
  
  // Implementation of required interface method
  async process(searchParam: string, value: string, resourceType: string): Promise<any> {
    // Only process specific search parameters on appropriate resource types
    if (resourceType !== 'MedicationRequest' && resourceType !== 'MedicationStatement') {
      return null; // Default processing
    }
    
    if (searchParam === 'ingredient') {
      return this.processIngredientSearch(value);
    } else if (searchParam === 'therapeutic-class') {
      return this.processTherapeuticClassSearch(value);
    } else if (searchParam === 'brand-name') {
      return this.processBrandNameSearch(value);
    }
    
    return null; // Default processing for other parameters
  }
  
  // Helper methods
  private async processIngredientSearch(ingredientCode: string): Promise<any> {
    // Custom logic to expand search to include all medications with the ingredient
    try {
      // Query the terminology service for all medication codes containing the ingredient
      const medicationCodes = await this.terminologyService.findMedicationsWithIngredient(ingredientCode);
      
      // Format the query for Aidbox
      return {
        $or: medicationCodes.map(code => ({
          'medicationCodeableConcept.coding': {
            $elemMatch: {
              system: code.system,
              code: code.code
            }
          }
        }))
      };
    } catch (error) {
      console.error('Error in ingredient search:', error);
      // Return a simple query if expansion fails
      return {
        'medicationCodeableConcept.coding': {
          $elemMatch: {
            code: ingredientCode
          }
        }
      };
    }
  }
  
  private async processTherapeuticClassSearch(classCode: string): Promise<any> {
    // Custom logic to search by therapeutic class
    try {
      // If hierarchical search is enabled, expand to include child classes
      let classCodes = [classCode];
      
      if (this.useHierarchicalSearch) {
        const childClasses = await this.terminologyService.findChildrenClasses(classCode);
        classCodes = [...classCodes, ...childClasses.map(c => c.code)];
      }
      
      // Format the query for Aidbox
      return {
        $or: classCodes.map(code => ({
          'medicationCodeableConcept.coding': {
            $elemMatch: {
              system: 'http://www.ama-assn.org/go/cpt',
              code: code
            }
          }
        }))
      };
    } catch (error) {
      console.error('Error in therapeutic class search:', error);
      // Return a simple query if expansion fails
      return {
        'medicationCodeableConcept.coding': {
          $elemMatch: {
            system: 'http://www.ama-assn.org/go/cpt',
            code: classCode
          }
        }
      };
    }
  }
  
  private async processBrandNameSearch(brandName: string): Promise<any> {
    // Custom logic to search by brand name with fuzzy matching
    return {
      'medicationCodeableConcept.text': {
        $ilike: `%${brandName}%`
      }
    };
  }
}

// Usage example
const terminologyService = new TerminologyService('https://terminology-service.covermymeds.com');

const searchProcessor = new MedicationSearchProcessor({
  useHierarchicalSearch: true,
  terminologyService: terminologyService
});

// Register the search processor with the Aidbox server
export function registerSearchProcessors(app) {
  app.searchProcessor(searchProcessor);
}
```

### Healthcare Integration Extensions

#### Custom FHIR Resource Transformation

The FHIR Interoperability Platform allows you to implement custom transformation logic for converting between FHIR and other healthcare formats.

**When to Use**:
- Converting HL7 v2 messages to FHIR resources
- Transforming CCDA documents to FHIR resources
- Converting proprietary formats to FHIR
- Implementing specialized FHIR resource mappings

**Implementation Example**:

```typescript
import { TransformationService } from '@aidbox/sdk-r4';

/**
 * Custom transformation service for converting HL7 v2 to FHIR
 */
class HL7v2ToFHIRTransformer implements TransformationService {
  // Properties and configuration
  private readonly mappingDefinitions: any;
  private readonly defaultPatientIdentifierSystem: string;
  
  constructor(config: {mappingDefinitions?: any, defaultPatientIdentifierSystem?: string}) {
    this.mappingDefinitions = config.mappingDefinitions || require('./default-mappings.json');
    this.defaultPatientIdentifierSystem = config.defaultPatientIdentifierSystem || 'http://covermymeds.com/fhir/identifier/mrn';
  }
  
  /**
   * Transform HL7 v2 message to FHIR Bundle
   */
  async transform(source: string, options?: any): Promise<any> {
    try {
      // Parse the HL7 v2 message
      const parsedHL7 = this.parseHL7Message(source);
      
      // Identify the message type
      const messageType = this.getMessageType(parsedHL7);
      
      // Apply appropriate transformation based on message type
      switch (messageType) {
        case 'ADT^A01': // Admission
          return this.transformADT_A01(parsedHL7, options);
        case 'ADT^A08': // Update patient information
          return this.transformADT_A08(parsedHL7, options);
        case 'ORM^O01': // Order message
          return this.transformORM_O01(parsedHL7, options);
        case 'ORU^R01': // Observation result
          return this.transformORU_R01(parsedHL7, options);
        default:
          throw new Error(`Unsupported message type: ${messageType}`);
      }
    } catch (error) {
      console.error('Error transforming HL7v2 to FHIR:', error);
      throw error;
    }
  }
  
  // Helper methods
  private parseHL7Message(message: string): any {
    // Parse the HL7 message into a structured object
    // Implementation details would go here
    return {}; // Placeholder
  }
  
  private getMessageType(parsedHL7: any): string {
    // Extract the message type from the MSH segment
    // Implementation details would go here
    return 'ADT^A01'; // Placeholder
  }
  
  private transformADT_A01(parsedHL7: any, options?: any): any {
    // Transform an ADT^A01 (admission) message to FHIR
    
    // Create a Bundle to hold the resources
    const bundle = {
      resourceType: 'Bundle',
      type: 'transaction',
      entry: []
    };
    
    // Extract and transform patient information
    const patient = this.createPatientFromPID(parsedHL7.PID, options);
    bundle.entry.push({
      resource: patient,
      request: {
        method: 'PUT',
        url: `Patient/${patient.id}`
      }
    });
    
    // Extract and transform encounter information
    const encounter = this.createEncounterFromPV1(parsedHL7.PV1, patient.id, options);
    bundle.entry.push({
      resource: encounter,
      request: {
        method: 'POST',
        url: 'Encounter'
      }
    });
    
    // Handle additional segments as needed
    // ...
    
    return bundle;
  }
  
  private transformADT_A08(parsedHL7: any, options?: any): any {
    // Implement transformation for A08 (update patient information)
    return {}; // Placeholder
  }
  
  private transformORM_O01(parsedHL7: any, options?: any): any {
    // Implement transformation for O01 (order message)
    return {}; // Placeholder
  }
  
  private transformORU_R01(parsedHL7: any, options?: any): any {
    // Implement transformation for R01 (observation result)
    return {}; // Placeholder
  }
  
  private createPatientFromPID(pidSegment: any, options?: any): any {
    // Transform PID segment to FHIR Patient resource
    // Implementation details would go here
    return {
      resourceType: 'Patient',
      id: 'example-id',
      // Other patient details
    };
  }
  
  private createEncounterFromPV1(pv1Segment: any, patientId: string, options?: any): any {
    // Transform PV1 segment to FHIR Encounter resource
    // Implementation details would go here
    return {
      resourceType: 'Encounter',
      status: 'in-progress',
      subject: {
        reference: `Patient/${patientId}`
      }
      // Other encounter details
    };
  }
}

// Usage example
const transformer = new HL7v2ToFHIRTransformer({
  defaultPatientIdentifierSystem: 'http://hospital.example.org/patients'
});

// Example of using the transformer
async function convertHL7MessageToFHIR(hl7Message: string) {
  try {
    const fhirBundle = await transformer.transform(hl7Message, {
      defaultSystem: 'http://hospital.example.org'
    });
    
    console.log('Transformed FHIR Bundle:', fhirBundle);
    return fhirBundle;
  } catch (error) {
    console.error('Error converting HL7 to FHIR:', error);
    throw error;
  }
}

// Register the transformer with the Aidbox server
export function registerTransformers(app) {
  app.transformer('hl7v2', transformer);
}
```

#### Custom Terminology Service Integration

The FHIR Interoperability Platform allows you to implement custom terminology service integrations for specialized code systems and value sets.

**When to Use**:
- Integrating with proprietary or specialized terminology systems
- Implementing custom code validation logic
- Supporting complex code system mappings
- Extending standard terminology with organization-specific codes

**Implementation Example**:

```typescript
import { TerminologyServiceHook } from '@aidbox/sdk-r4';
import axios from 'axios';

/**
 * Custom terminology service integration for RxNav
 */
class RxNavTerminologyService implements TerminologyServiceHook {
  // Properties and configuration
  private readonly rxnavBaseUrl: string;
  private readonly includeRelationships: boolean;
  private readonly cacheEnabled: boolean;
  private readonly cache: Map<string, any>;
  
  constructor(config: {rxnavBaseUrl?: string, includeRelationships?: boolean, cacheEnabled?: boolean}) {
    this.rxnavBaseUrl = config.rxnavBaseUrl || 'https://rxnav.nlm.nih.gov/REST';
    this.includeRelationships = config.includeRelationships ?? true;
    this.cacheEnabled = config.cacheEnabled ?? true;
    this.cache = new Map();
  }
  
  // Implementation of hook methods
  async lookup(system: string, code: string): Promise<any> {
    // Only handle RxNorm lookups
    if (system !== 'http://www.nlm.nih.gov/research/umls/rxnorm') {
      return null; // Let the default handler process it
    }
    
    const cacheKey = `lookup:${system}:${code}`;
    
    // Check cache if enabled
    if (this.cacheEnabled && this.cache.has(cacheKey)) {
      return this.cache.get(cacheKey);
    }
    
    try {
      const response = await axios.get(`${this.rxnavBaseUrl}/rxcui/${code}/allProperties.json?prop=all`);
      
      if (!response.data || !response.data.propConceptGroup || !response.data.propConceptGroup.propConcept) {
        return null;
      }
      
      const properties = response.data.propConceptGroup.propConcept;
      
      // Map RxNav properties to FHIR Parameters
      const result = {
        resourceType: 'Parameters',
        parameter: [
          {
            name: 'code',
            valueString: code
          },
          {
            name: 'system',
            valueUri: system
          },
          {
            name: 'display',
            valueString: properties.find(p => p.propName === 'RxNorm Name')?.propValue || ''
          }
        ]
      };
      
      // Add additional properties
      for (const prop of properties) {
        if (prop.propName !== 'RxNorm Name') {
          result.parameter.push({
            name: 'property',
            part: [
              {
                name: 'code',
                valueString: prop.propName.replace(/\s+/g, '')
              },
              {
                name: 'value',
                valueString: prop.propValue
              }
            ]
          });
        }
      }
      
      // Get relationships if configured
      if (this.includeRelationships) {
        const relationships = await this.getRelationships(code);
        if (relationships && relationships.length > 0) {
          for (const rel of relationships) {
            result.parameter.push({
              name: 'property',
              part: [
                {
                  name: 'code',
                  valueString: 'relationship'
                },
                {
                  name: 'valueCodeableConcept',
                  valueCodeableConcept: {
                    coding: [
                      {
                        system: 'http://www.nlm.nih.gov/research/umls/rxnorm',
                        code: rel.relatedCode,
                        display: rel.relatedName
                      }
                    ],
                    text: `${rel.relationshipName}: ${rel.relatedName}`
                  }
                }
              ]
            });
          }
        }
      }
      
      // Cache the result if caching is enabled
      if (this.cacheEnabled) {
        this.cache.set(cacheKey, result);
      }
      
      return result;
    } catch (error) {
      console.error(`Error looking up RxNorm code ${code}:`, error);
      return null;
    }
  }
  
  async translate(code: string, fromSystem: string, toSystem: string): Promise<any> {
    // Only handle RxNorm translations
    if (fromSystem !== 'http://www.nlm.nih.gov/research/umls/rxnorm' && 
        toSystem !== 'http://www.nlm.nih.gov/research/umls/rxnorm') {
      return null; // Let the default handler process it
    }
    
    const cacheKey = `translate:${fromSystem}:${code}:${toSystem}`;
    
    // Check cache if enabled
    if (this.cacheEnabled && this.cache.has(cacheKey)) {
      return this.cache.get(cacheKey);
    }
    
    try {
      let endpoint;
      
      // Determine the appropriate RxNav API endpoint based on the source system
      if (fromSystem === 'http://www.nlm.nih.gov/research/umls/rxnorm') {
        if (toSystem === 'http://hl7.org/fhir/sid/ndc') {
          endpoint = `${this.rxnavBaseUrl}/rxcui/${code}/ndcs.json`;
        } else if (toSystem === 'http://www.ama-assn.org/go/cpt') {
          endpoint = `${this.rxnavBaseUrl}/rxcui/${code}/property.json?propName=SNOMEDCT`;
        }
      } else if (toSystem === 'http://www.nlm.nih.gov/research/umls/rxnorm') {
        if (fromSystem === 'http://hl7.org/fhir/sid/ndc') {
          endpoint = `${this.rxnavBaseUrl}/ndcstatus/ndc/${code}`;
        }
      }
      
      if (!endpoint) {
        return null;
      }
      
      const response = await axios.get(endpoint);
      
      // Process response based on target system
      let mappedCodes = [];
      
      if (toSystem === 'http://hl7.org/fhir/sid/ndc' && response.data.ndcGroup?.ndcList) {
        mappedCodes = response.data.ndcGroup.ndcList.ndc.map(ndc => ({
          system: 'http://hl7.org/fhir/sid/ndc',
          code: ndc
        }));
      } else if (toSystem === 'http://www.ama-assn.org/go/cpt' && response.data.propConceptGroup?.propConcept) {
        const snomedCodes = response.data.propConceptGroup.propConcept
          .filter(prop => prop.propName === 'SNOMEDCT')
          .map(prop => ({
            system: 'http://snomed.info/sct',
            code: prop.propValue
          }));
        mappedCodes = snomedCodes;
      } else if (fromSystem === 'http://hl7.org/fhir/sid/ndc' && response.data?.ndcStatus?.rxcui) {
        mappedCodes = [{
          system: 'http://www.nlm.nih.gov/research/umls/rxnorm',
          code: response.data.ndcStatus.rxcui
        }];
      }
      
      // Create FHIR Parameters response
      const result = {
        resourceType: 'Parameters',
        parameter: [
          {
            name: 'result',
            valueBoolean: mappedCodes.length > 0
          },
          {
            name: 'match',
            valueString: mappedCodes.length > 0 ? 'equivalent' : 'none'
          }
        ]
      };
      
      // Add mapped codes
      for (const mapped of mappedCodes) {
        result.parameter.push({
          name: 'target',
          valueCodeableConcept: {
            coding: [mapped]
          }
        });
      }
      
      // Cache the result if caching is enabled
      if (this.cacheEnabled) {
        this.cache.set(cacheKey, result);
      }
      
      return result;
    } catch (error) {
      console.error(`Error translating code ${code} from ${fromSystem} to ${toSystem}:`, error);
      return null;
    }
  }
  
  async validateCode(system: string, code: string, valueSet?: string): Promise<any> {
    // Only validate RxNorm codes
    if (system !== 'http://www.nlm.nih.gov/research/umls/rxnorm') {
      return null; // Let the default handler process it
    }
    
    // Simple case: validate a single code in RxNorm
    if (!valueSet) {
      try {
        const lookupResult = await this.lookup(system, code);
        const isValid = lookupResult && lookupResult.parameter.some(p => p.name === 'code' && p.valueString === code);
        
        return {
          resourceType: 'Parameters',
          parameter: [
            {
              name: 'result',
              valueBoolean: isValid
            }
          ]
        };
      } catch (error) {
        console.error(`Error validating RxNorm code ${code}:`, error);
        return null;
      }
    }
    
    // ValueSet validation would go here
    // This is a placeholder and would require additional implementation
    return null;
  }
  
  // Helper methods
  private async getRelationships(rxcui: string): Promise<any[]> {
    try {
      const response = await axios.get(`${this.rxnavBaseUrl}/rxcui/${rxcui}/allrelated.json`);
      
      if (!response.data || !response.data.allRelatedGroup || !response.data.allRelatedGroup.conceptGroup) {
        return [];
      }
      
      const relationships = [];
      
      for (const group of response.data.allRelatedGroup.conceptGroup) {
        if (group.conceptProperties) {
          for (const prop of group.conceptProperties) {
            relationships.push({
              relationshipName: group.tty,
              relatedCode: prop.rxcui,
              relatedName: prop.name
            });
          }
        }
      }
      
      return relationships;
    } catch (error) {
      console.error(`Error getting relationships for RxNorm code ${rxcui}:`, error);
      return [];
    }
  }
}

// Usage example
const rxnavTerminologyService = new RxNavTerminologyService({
  includeRelationships: true,
  cacheEnabled: true
});

// Register with the Aidbox server
export function registerTerminologyServices(app) {
  app.terminologyService('rxnav', rxnavTerminologyService);
}
```

### Security Extensions

#### Custom Authentication Mechanism

The FHIR Interoperability Platform allows you to implement custom authentication mechanisms for specialized security requirements.

**When to Use**:
- Integrating with legacy authentication systems
- Implementing custom token validation
- Supporting specialized authentication workflows
- Adding multi-factor authentication

**Implementation Example**:

```typescript
import { AuthenticationHook } from '@aidbox/sdk-r4';
import jwt from 'jsonwebtoken';
import axios from 'axios';

/**
 * Custom authentication provider for enterprise directory integration
 */
class EnterpriseDirectoryAuthProvider implements AuthenticationHook {
  // Properties and configuration
  private readonly directoryServiceUrl: string;
  private readonly jwtSecret: string;
  private readonly tokenTtl: number;
  private readonly cacheTtl: number;
  private readonly userCache: Map<string, {expiry: number, user: any}>;
  
  constructor(config: {directoryServiceUrl: string, jwtSecret: string, tokenTtl?: number, cacheTtl?: number}) {
    this.directoryServiceUrl = config.directoryServiceUrl;
    this.jwtSecret = config.jwtSecret;
    this.tokenTtl = config.tokenTtl || 3600; // 1 hour default
    this.cacheTtl = config.cacheTtl || 300; // 5 minutes default
    this.userCache = new Map();
  }
  
  // Implementation of authentication hook
  async authenticate(credentials: any): Promise<any> {
    // Check for supported authentication types
    if (credentials.type === 'basic') {
      return this.authenticateBasic(credentials.username, credentials.password);
    } else if (credentials.type === 'token') {
      return this.authenticateToken(credentials.token);
    } else if (credentials.type === 'saml') {
      return this.authenticateSaml(credentials.assertion);
    }
    
    // Return null to allow other authentication providers to handle the request
    return null;
  }
  
  // Helper methods for different authentication types
  private async authenticateBasic(username: string, password: string): Promise<any> {
    try {
      // Check if we have a cached user
      const cacheKey = `basic:${username}`;
      const now = Date.now();
      
      if (this.userCache.has(cacheKey)) {
        const cached = this.userCache.get(cacheKey);
        if (cached && cached.expiry > now) {
          // Return cached user information
          return this.generateAuthResponse(cached.user);
        }
      }
      
      // Validate credentials against directory service
      const response = await axios.post(`${this.directoryServiceUrl}/auth/basic`, {
        username,
        password
      }, {
        headers: {
          'Content-Type': 'application/json'
        }
      });
      
      if (response.status !== 200 || !response.data.authenticated) {
        return {
          authenticated: false,
          error: 'Invalid credentials'
        };
      }
      
      // Get user information
      const user = response.data.user;
      
      // Cache user information
      this.userCache.set(cacheKey, {
        expiry: now + (this.cacheTtl * 1000),
        user
      });
      
      // Return authentication response
      return this.generateAuthResponse(user);
    } catch (error) {
      console.error('Error during basic authentication:', error);
      return {
        authenticated: false,
        error: 'Authentication service error'
      };
    }
  }
  
  private async authenticateToken(token: string): Promise<any> {
    try {
      // Verify JWT token
      const decoded = jwt.verify(token, this.jwtSecret);
      
      // Check if token is expired
      if (typeof decoded === 'object' && decoded.exp && decoded.exp < Math.floor(Date.now() / 1000)) {
        return {
          authenticated: false,
          error: 'Token expired'
        };
      }
      
      // Get user information if not already in token
      let user = decoded;
      
      if (typeof decoded === 'object' && decoded.sub && !decoded.name) {
        // Check if we have a cached user
        const cacheKey = `token:${decoded.sub}`;
        const now = Date.now();
        
        if (this.userCache.has(cacheKey)) {
          const cached = this.userCache.get(cacheKey);
          if (cached && cached.expiry > now) {
            // Use cached user information
            user = cached.user;
          } else {
            // Get user information from directory service
            const response = await axios.get(`${this.directoryServiceUrl}/users/${decoded.sub}`, {
              headers: {
                'Authorization': `Bearer ${token}`
              }
            });
            
            if (response.status === 200) {
              user = response.data;
              
              // Cache user information
              this.userCache.set(cacheKey, {
                expiry: now + (this.cacheTtl * 1000),
                user
              });
            }
          }
        }
      }
      
      // Return authentication response
      return this.generateAuthResponse(user);
    } catch (error) {
      console.error('Error during token authentication:', error);
      return {
        authenticated: false,
        error: 'Invalid token'
      };
    }
  }
  
  private async authenticateSaml(assertion: string): Promise<any> {
    try {
      // Validate SAML assertion against directory service
      const response = await axios.post(`${this.directoryServiceUrl}/auth/saml`, {
        assertion
      }, {
        headers: {
          'Content-Type': 'application/json'
        }
      });
      
      if (response.status !== 200 || !response.data.authenticated) {
        return {
          authenticated: false,
          error: 'Invalid SAML assertion'
        };
      }
      
      // Get user information
      const user = response.data.user;
      
      // Cache user information
      const cacheKey = `saml:${user.id}`;
      this.userCache.set(cacheKey, {
        expiry: Date.now() + (this.cacheTtl * 1000),
        user
      });
      
      // Return authentication response
      return this.generateAuthResponse(user);
    } catch (error) {
      console.error('Error during SAML authentication:', error);
      return {
        authenticated: false,
        error: 'Authentication service error'
      };
    }
  }
  
  private generateAuthResponse(user: any): any {
    // Create JWT token with user information
    const now = Math.floor(Date.now() / 1000);
    
    const token = jwt.sign({
      sub: user.id,
      name: user.name,
      email: user.email,
      roles: user.roles,
      iat: now,
      exp: now + this.tokenTtl
    }, this.jwtSecret, { algorithm: 'HS256' });
    
    // Map user roles to FHIR platform roles
    const fhirRoles = this.mapRolesToFhirRoles(user.roles);
    
    // Return authentication response
    return {
      authenticated: true,
      token,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        roles: fhirRoles
      }
    };
  }
  
  private mapRolesToFhirRoles(roles: string[]): string[] {
    // Map enterprise directory roles to FHIR platform roles
    const roleMap = {
      'CLINICAL_STAFF': 'practitioner',
      'PROVIDER': 'physician',
      'ADMIN': 'system-admin',
      'PHARMACIST': 'pharmacist',
      'PATIENT': 'patient'
    };
    
    return roles.map(role => roleMap[role] || role.toLowerCase());
  }
}

// Usage example
const directoryAuthProvider = new EnterpriseDirectoryAuthProvider({
  directoryServiceUrl: 'https://directory.covermymeds.com/api',
  jwtSecret: process.env.JWT_SECRET || 'your-secret-key',
  tokenTtl: 3600,
  cacheTtl: 300
});

// Register with the Aidbox server
export function registerAuthProviders(app) {
  app.authProvider('directory', directoryAuthProvider);
}
```

#### Custom Authorization Policy Engine

The FHIR Interoperability Platform allows you to implement custom authorization policy engines for fine-grained access control.

**When to Use**:
- Implementing complex access control rules
- Supporting organization-specific security policies
- Enforcing data segmentation for privacy
- Implementing consent-based access control

**Implementation Example**:

```typescript
import { AuthorizationHook } from '@aidbox/sdk-r4';

/**
 * Custom authorization policy engine for HIPAA-compliant access control
 */
class HIPAAAuthorizationPolicy implements AuthorizationHook {
  // Properties and configuration
  private readonly strictMode: boolean;
  private readonly dataCategories: Map<string, string>;
  private readonly consentService: any;
  private readonly auditLogger: any;
  
  constructor(config: {strictMode?: boolean, consentService: any, auditLogger: any}) {
    this.strictMode = config.strictMode ?? true;
    this.consentService = config.consentService;
    this.auditLogger = config.auditLogger;
    
    // Define data sensitivity categories for different resource types/elements
    this.dataCategories = new Map([
      ['Patient.address', 'PHI'],
      ['Patient.telecom', 'PHI'],
      ['Patient.identifier', 'PHI'],
      ['Patient.name', 'PHI'],
      ['Patient.birthDate', 'PHI'],
      ['Condition', 'clinical'],
      ['Condition:mental-health', 'sensitive'],
      ['Condition:hiv', 'restricted'],
      ['Condition:substance-abuse', 'restricted'],
      ['MedicationRequest', 'clinical'],
      ['MedicationRequest:controlled-substance', 'sensitive'],
      ['Observation', 'clinical'],
      ['Observation:labs', 'clinical'],
      ['Observation:vital-signs', 'clinical'],
      ['Observation:substance-abuse', 'restricted'],
      ['Observation:hiv', 'restricted'],
      ['DocumentReference', 'clinical'],
      ['DocumentReference:mental-health', 'sensitive'],
      ['DocumentReference:hiv', 'restricted']
    ]);
  }
  
  // Implementation of authorization hook
  async authorize(request: any, context: any): Promise<any> {
    try {
      // Get user information from context
      const user = context.user;
      
      if (!user) {
        return this.denyAccess('No user information available');
      }
      
      // Check if user has system admin role (bypass most checks)
      const isSystemAdmin = user.roles.includes('system-admin');
      
      if (isSystemAdmin && request.action !== 'delete') {
        return this.allowAccess(true);
      }
      
      // Get patient context if available
      const patientId = this.getPatientContextFromRequest(request);
      
      // Check for Break-the-Glass scenario
      const isBreakGlass = request.headers && request.headers['x-break-glass'] === 'true';
      let breakGlassReason = null;
      
      if (isBreakGlass) {
        breakGlassReason = request.headers['x-break-glass-reason'] || 'No reason provided';
        
        // Log the break-glass access attempt
        await this.auditLogger.logBreakGlass({
          user: user,
          action: request.action,
          resource: request.resourceType,
          resourceId: request.resourceId,
          patientId: patientId,
          reason: breakGlassReason
        });
      }
      
      // Determine access level based on user roles
      const accessLevel = this.determineAccessLevel(user.roles);
      
      // Check resource-specific access control
      const resourceCheck = await this.checkResourceAccess(
        request.resourceType,
        request.resourceId,
        request.action,
        accessLevel,
        user,
        patientId,
        isBreakGlass
      );
      
      if (!resourceCheck.allowed) {
        return this.denyAccess(resourceCheck.reason);
      }
      
      // For read operations, apply data filtering based on access level
      if (request.action === 'read' || request.action === 'search') {
        const filters = await this.buildDataFilters(
          request.resourceType,
          accessLevel,
          user,
          patientId,
          isBreakGlass
        );
        
        // Log access for audit purposes
        await this.auditLogger.logAccess({
          user: user,
          action: request.action,
          resource: request.resourceType,
          resourceId: request.resourceId,
          patientId: patientId,
          accessLevel: accessLevel,
          filters: filters,
          breakGlass: isBreakGlass,
          breakGlassReason: breakGlassReason
        });
        
        return this.allowAccess(false, filters);
      }
      
      // Log access for audit purposes
      await this.auditLogger.logAccess({
        user: user,
        action: request.action,
        resource: request.resourceType,
        resourceId: request.resourceId,
        patientId: patientId,
        accessLevel: accessLevel,
        breakGlass: isBreakGlass,
        breakGlassReason: breakGlassReason
      });
      
      // Allow access with no filters for non-read operations
      return this.allowAccess(false);
    } catch (error) {
      console.error('Error during authorization:', error);
      
      // In strict mode, deny access on errors
      if (this.strictMode) {
        return this.denyAccess('Authorization service error');
      }
      
      // In non-strict mode, allow access but log the error
      return this.allowAccess(false);
    }
  }
  
  // Helper methods
  private getPatientContextFromRequest(request: any): string | null {
    // Extract patient context from request
    // Check resource is patient-specific
    if (request.resourceType === 'Patient' && request.resourceId) {
      return request.resourceId;
    }
    
    // Check if resource has patient reference
    if (request.resourceId && request.reference && request.reference.patient) {
      return request.reference.patient;
    }
    
    // Check for patient search parameter
    if (request.parameters && request.parameters.patient) {
      return request.parameters.patient;
    }
    
    // Check for patient in context
    if (request.parameters && request.parameters._context && request.parameters._context.patient) {
      return request.parameters._context.patient;
    }
    
    return null;
  }
  
  private determineAccessLevel(roles: string[]): string {
    // Determine access level based on user roles
    if (roles.includes('system-admin')) {
      return 'admin';
    } else if (roles.includes('physician') || roles.includes('provider')) {
      return 'clinical';
    } else if (roles.includes('nurse') || roles.includes('clinical-staff')) {
      return 'clinical-limited';
    } else if (roles.includes('researcher')) {
      return 'de-identified';
    } else if (roles.includes('patient')) {
      return 'patient';
    } else {
      return 'minimal';
    }
  }
  
  private async checkResourceAccess(
    resourceType: string,
    resourceId: string,
    action: string,
    accessLevel: string,
    user: any,
    patientId: string | null,
    isBreakGlass: boolean
  ): Promise<{allowed: boolean, reason?: string}> {
    // Check if user has access to the specific resource
    
    // Break-the-glass allows emergency access
    if (isBreakGlass && (accessLevel === 'clinical' || accessLevel === 'clinical-limited')) {
      return { allowed: true };
    }
    
    // Check patient-specific access
    if (patientId) {
      // If user is the patient, check patient access policy
      if (accessLevel === 'patient') {
        if (user.id === patientId) {
          // Patients can read their own data but not modify sensitive data
          if (action === 'read' || action === 'search') {
            return { allowed: true };
          } else {
            return { allowed: false, reason: 'Patients cannot modify their own medical records' };
          }
        } else {
          return { allowed: false, reason: 'Patients can only access their own records' };
        }
      }
      
      // Check if user has consent to access patient data
      const hasConsent = await this.consentService.checkConsent(patientId, user.id, resourceType);
      
      if (!hasConsent && !isBreakGlass) {
        return { allowed: false, reason: 'No consent to access patient data' };
      }
    }
    
    // Resource-specific access rules
    switch (resourceType) {
      case 'Patient':
        // Everyone can read basic patient info
        if (action === 'read' || action === 'search') {
          return { allowed: true };
        }
        // Only clinical staff can modify patient records
        else if ((action === 'create' || action === 'update') && 
                (accessLevel === 'clinical' || accessLevel === 'admin')) {
          return { allowed: true };
        }
        // Only admins can delete patient records
        else if (action === 'delete' && accessLevel === 'admin') {
          return { allowed: true };
        }
        break;
        
      case 'Condition':
        // Clinical staff can read and write conditions
        if ((action === 'read' || action === 'search') && 
            (accessLevel === 'clinical' || accessLevel === 'clinical-limited' || accessLevel === 'admin')) {
          return { allowed: true };
        }
        // Only physicians and admins can create/modify conditions
        else if ((action === 'create' || action === 'update') && 
                (accessLevel === 'clinical' || accessLevel === 'admin')) {
          return { allowed: true };
        }
        // Only admins can delete conditions
        else if (action === 'delete' && accessLevel === 'admin') {
          return { allowed: true };
        }
        break;
        
      case 'MedicationRequest':
        // Clinical staff can read medication requests
        if ((action === 'read' || action === 'search') && 
            (accessLevel === 'clinical' || accessLevel === 'clinical-limited' || accessLevel === 'admin')) {
          return { allowed: true };
        }
        // Only physicians can create medication requests
        else if (action === 'create' && (accessLevel === 'clinical' || accessLevel === 'admin')) {
          return { allowed: true };
        }
        // Only prescribing physician or admin can modify/delete
        else if ((action === 'update' || action === 'delete') && accessLevel === 'admin') {
          return { allowed: true };
        }
        // Check if user is the prescriber for update/delete
        else if ((action === 'update' || action === 'delete') && accessLevel === 'clinical') {
          // Would need to fetch the resource to check prescriber
          // This is a simplification
          return { allowed: true };
        }
        break;
        
      // Add rules for other resource types...
        
      default:
        // Default access policy
        if ((action === 'read' || action === 'search') && 
            (accessLevel === 'clinical' || accessLevel === 'admin')) {
          return { allowed: true };
        } else if ((action === 'create' || action === 'update' || action === 'delete') && 
                  accessLevel === 'admin') {
          return { allowed: true };
        }
        break;
    }
    
    // Deny by default
    return { allowed: false, reason: 'Insufficient permissions for this operation' };
  }
  
  private async buildDataFilters(
    resourceType: string,
    accessLevel: string,
    user: any,
    patientId: string | null,
    isBreakGlass: boolean
  ): Promise<any[]> {
    // Build data filters based on access level and resource type
    const filters = [];
    
    // Admins and break-glass scenarios get unfiltered access
    if (accessLevel === 'admin' || isBreakGlass) {
      return filters;
    }
    
    // Patient access - filter out sensitive information depending on resource
    if (accessLevel === 'patient') {
      // Patients can see basic health information but not all clinical notes
      switch (resourceType) {
        case 'DocumentReference':
          filters.push({
            path: 'category',
            op: 'not-in',
            value: ['sensitive', 'restricted']
          });
          break;
        case 'Condition':
          filters.push({
            path: 'category',
            op: 'not-in',
            value: ['restricted']
          });
          break;
        // Add filters for other resource types
      }
    }
    
    // Clinical limited access (nurses, medical assistants)
    else if (accessLevel === 'clinical-limited') {
      // Can see most clinical data except for restricted categories
      filters.push({
        path: 'category',
        op: 'not-in',
        value: ['restricted']
      });
    }
    
    // Research access - de-identified data only
    else if (accessLevel === 'de-identified') {
      // Add filters to remove all PHI
      filters.push({
        path: 'identifier',
        op: 'redact'
      });
      filters.push({
        path: 'name',
        op: 'redact'
      });
      filters.push({
        path: 'address',
        op: 'redact'
      });
      filters.push({
        path: 'telecom',
        op: 'redact'
      });
      filters.push({
        path: 'birthDate',
        op: 'generalize',
        value: 'year'
      });
      // Add other de-identification filters
    }
    
    return filters;
  }
  
  private allowAccess(fullAccess: boolean, filters: any[] = []): any {
    return {
      decision: 'allow',
      fullAccess: fullAccess,
      filters: filters
    };
  }
  
  private denyAccess(reason: string): any {
    return {
      decision: 'deny',
      reason: reason
    };
  }
}

// Example consent service
class ConsentService {
  async checkConsent(patientId: string, userId: string, resourceType: string): Promise<boolean> {
    // Implementation of consent checking logic
    // This would query Consent resources to determine if access is allowed
    return true; // Placeholder
  }
}

// Example audit logger
class AuditLogger {
  async logAccess(details: any): Promise<void> {
    // Implementation of audit logging
    console.log('Access audit:', details);
  }
  
  async logBreakGlass(details: any): Promise<void> {
    // Implementation of break-glass audit logging
    console.log('BREAK GLASS:', details);
  }
}

// Usage example
const consentService = new ConsentService();
const auditLogger = new AuditLogger();

const authPolicy = new HIPAAAuthorizationPolicy({
  strictMode: true,
  consentService: consentService,
  auditLogger: auditLogger
});

// Register with the Aidbox server
export function registerAuthorizationPolicies(app) {
  app.authorizationPolicy('hipaa', authPolicy);
}
```

## Best Practices for Extension Development

### Architecture Guidelines

1. **Follow Single Responsibility Principle**
   - Each extension should have a clear, focused purpose
   - Avoid creating monolithic extensions that try to do too much
   - Design extensions to work together through composition

2. **Use Standardized Interfaces**
   - Follow the existing interface patterns in the FHIR Interoperability Platform
   - Document the interfaces your extension implements or provides
   - Maintain backward compatibility when updating extensions

3. **Ensure Testability**
   - Design extensions to be easily testable in isolation
   - Include comprehensive unit and integration tests
   - Consider using dependency injection for better testability

4. **Consider Performance Impact**
   - Evaluate the performance implications of your extensions
   - Optimize for the common case
   - Implement caching where appropriate
   - Add metrics to monitor extension performance

### Development Best Practices

1. **Error Handling**
   - Implement robust error handling in all extensions
   - Fail gracefully and provide meaningful error messages
   - Consider the impact of errors on the overall system
   - Include recovery mechanisms where possible

2. **Configuration Management**
   - Make extensions configurable through external configuration
   - Use sensible defaults for all configuration options
   - Validate configuration at startup
   - Document all configuration options

3. **Logging and Monitoring**
   - Include comprehensive logging in all extensions
   - Add metrics for key operations
   - Ensure extensions integrate with the FHIR Interoperability Platform's monitoring system
   - Make logs and metrics consistent with the broader system

4. **Security Considerations**
   - Follow the principle of least privilege
   - Avoid handling sensitive data unless necessary
   - Implement appropriate authentication and authorization checks
   - Document security implications of your extensions

5. **Documentation**
   - Provide clear documentation on how to install, configure, and use the extension
   - Include examples of common usage patterns
   - Document any assumptions or limitations
   - Keep documentation up to date as the extension evolves

### Healthcare-Specific Extension Guidelines

1. **HIPAA Compliance**
   - Ensure extensions comply with HIPAA requirements for PHI
   - Implement appropriate data protection mechanisms
   - Document compliance considerations for extension users
   - Include audit logging for all PHI access

2. **Data Validation**
   - Validate healthcare data against industry standards (e.g., FHIR)
   - Implement data quality checks appropriate for healthcare data
   - Consider implementing validation against terminology services
   - Document validation requirements and limitations

3. **Interoperability**
   - Design extensions to work with healthcare interoperability standards
   - Consider integration with common healthcare systems
   - Support mapping between different healthcare data formats
   - Document interoperability capabilities and requirements

4. **Clinical Safety**
   - Consider the clinical safety implications of extensions
   - Implement appropriate checks for critical healthcare workflows
   - Document any safety-critical aspects of the extension
   - Provide clear guidance on safe usage patterns

## Related Resources
- [FHIR Interoperability Platform Advanced Use Cases](./advanced-use-cases.md)
- [FHIR Interoperability Platform Core APIs](../02-core-functionality/core-apis.md)
- [FHIR Interoperability Platform Customization](./customization.md)
- [HL7 FHIR Implementation Guide](https://hl7.org/fhir/R4/implementationguide.html)
- [Aidbox Plugin Development](https://docs.aidbox.app/plugins-1/plugins)