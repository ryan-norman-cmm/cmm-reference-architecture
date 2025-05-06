# FHIR Interoperability Platform Extension Points

## Introduction

The FHIR Interoperability Platform is designed with extensibility in mind, allowing organizations to customize and extend its functionality without modifying the core codebase. This document outlines the key extension points available in the platform, along with implementation examples using TypeScript.

## Resource Extension Framework

### FHIR Resource Extensions

The platform supports the standard FHIR extension mechanism for adding custom data elements to resources.

**Key Capabilities:**
- Define custom extensions with formal definitions
- Apply extensions to any FHIR resource
- Validate extensions against profiles
- Search by extension values

```typescript
// Example: Defining and using a custom extension
import { Patient } from 'fhir/r4';
import { FhirClient } from '../services/fhir-client';

// Define extension URL constants
const EXTENSION_URLS = {
  patientPreferredContactMethod: 'https://cmm-platform.org/fhir/StructureDefinition/patient-preferred-contact-method',
  patientLanguageProficiency: 'https://cmm-platform.org/fhir/StructureDefinition/patient-language-proficiency'
};

// Function to add extensions to a patient
function addPatientExtensions(patient: Patient): Patient {
  if (!patient.extension) {
    patient.extension = [];
  }
  
  // Add preferred contact method extension
  patient.extension.push({
    url: EXTENSION_URLS.patientPreferredContactMethod,
    valueCode: 'sms'
  });
  
  // Add language proficiency extension (complex extension with nested extensions)
  patient.extension.push({
    url: EXTENSION_URLS.patientLanguageProficiency,
    extension: [
      {
        url: 'language',
        valueCodeableConcept: {
          coding: [{
            system: 'urn:ietf:bcp:47',
            code: 'en-US',
            display: 'English (United States)'
          }]
        }
      },
      {
        url: 'proficiency',
        valueCodeableConcept: {
          coding: [{
            system: 'https://cmm-platform.org/fhir/CodeSystem/language-proficiency',
            code: 'fluent',
            display: 'Fluent'
          }]
        }
      }
    ]
  });
  
  return patient;
}

// Function to search patients by extension value
async function searchPatientsByExtension(fhirClient: FhirClient): Promise<any> {
  // Search for patients with preferred contact method = 'sms'
  return await fhirClient.search('Patient', {
    [`extension-${EXTENSION_URLS.patientPreferredContactMethod}`]: 'sms'
  });
}
```

## Validation Extension Points

### Custom Validation Rules

The platform allows for custom validation rules to be added to the standard FHIR validation process.

**Key Capabilities:**
- Define organization-specific validation rules
- Implement complex cross-field validations
- Create domain-specific validation logic

```typescript
// Example: Custom validator implementation
import { Resource } from 'fhir/r4';

// Validator interface
interface ResourceValidator {
  validate(resource: Resource): ValidationResult;
}

// Validation result interface
interface ValidationResult {
  valid: boolean;
  issues?: ValidationIssue[];
}

interface ValidationIssue {
  severity: 'error' | 'warning' | 'information';
  code: string;
  details: string;
  expression?: string[];
}

// Custom validator for medication prescriptions
class MedicationRequestValidator implements ResourceValidator {
  validate(resource: Resource): ValidationResult {
    if (resource.resourceType !== 'MedicationRequest') {
      return { valid: true };
    }
    
    const medicationRequest = resource as any;
    const issues: ValidationIssue[] = [];
    
    // Check for pediatric dosing rules
    if (this.isPediatricPatient(medicationRequest) && medicationRequest.dosageInstruction) {
      for (const dosage of medicationRequest.dosageInstruction) {
        if (dosage.doseAndRate && dosage.doseAndRate[0]?.doseQuantity) {
          const dose = dosage.doseAndRate[0].doseQuantity;
          const medication = this.getMedicationDetails(medicationRequest);
          
          if (medication && !this.isValidPediatricDose(medication, dose)) {
            issues.push({
              severity: 'error',
              code: 'custom-pediatric-dose',
              details: `Pediatric dose exceeds maximum recommended dose for ${medication.name}`,
              expression: ['MedicationRequest.dosageInstruction[0].doseAndRate[0].doseQuantity']
            });
          }
        }
      }
    }
    
    // Check for drug-drug interactions
    const interactionIssues = this.checkDrugInteractions(medicationRequest);
    issues.push(...interactionIssues);
    
    return {
      valid: issues.length === 0,
      issues: issues.length > 0 ? issues : undefined
    };
  }
  
  private isPediatricPatient(medicationRequest: any): boolean {
    // Implementation details
    return true;
  }
  
  private getMedicationDetails(medicationRequest: any): any {
    // Implementation details
    return { name: 'Example Medication' };
  }
  
  private isValidPediatricDose(medication: any, dose: any): boolean {
    // Implementation details
    return true;
  }
  
  private checkDrugInteractions(medicationRequest: any): ValidationIssue[] {
    // Implementation details
    return [];
  }
}

// Register custom validators with the validation service
class ValidationService {
  private validators: ResourceValidator[] = [];
  
  registerValidator(validator: ResourceValidator): void {
    this.validators.push(validator);
  }
  
  async validateResource(resource: Resource): Promise<ValidationResult> {
    // First run standard FHIR validation
    const standardValidation = await this.runStandardValidation(resource);
    if (!standardValidation.valid) {
      return standardValidation;
    }
    
    // Then run custom validators
    const issues: ValidationIssue[] = [];
    for (const validator of this.validators) {
      const result = validator.validate(resource);
      if (!result.valid && result.issues) {
        issues.push(...result.issues);
      }
    }
    
    return {
      valid: issues.length === 0,
      issues: issues.length > 0 ? issues : undefined
    };
  }
  
  private async runStandardValidation(resource: Resource): Promise<ValidationResult> {
    // Implementation details
    return { valid: true };
  }
}
```

## Search Extension Points

### Custom Search Parameters

The platform allows for defining custom search parameters beyond the standard FHIR search parameters.

**Key Capabilities:**
- Define custom search parameters for any resource type
- Implement complex search logic
- Optimize search performance for specific use cases

```typescript
// Example: Defining and implementing custom search parameters
import { SearchParameter } from 'fhir/r4';

// Define a custom search parameter
const labResultAbnormalParameter: SearchParameter = {
  resourceType: 'SearchParameter',
  id: 'observation-abnormal',
  url: 'https://cmm-platform.org/fhir/SearchParameter/observation-abnormal',
  name: 'abnormal',
  status: 'active',
  description: 'Search for abnormal lab results',
  code: 'abnormal',
  base: ['Observation'],
  type: 'token',
  expression: 'Observation.interpretation.where(coding.code in ("A" | "AA" | "HH" | "LL" | "H" | "L"))'
};

// Register the search parameter with the FHIR server
async function registerCustomSearchParameter(fhirClient: any, parameter: SearchParameter) {
  await fhirClient.create('SearchParameter', parameter);
  
  // Trigger the server to rebuild search indexes
  await fhirClient.operation({
    name: '$refresh-search-parameters',
    resourceType: null,
    id: null,
    parameters: {}
  });
}

// Use the custom search parameter
async function findAbnormalLabResults(fhirClient: any, patientId: string) {
  return await fhirClient.search('Observation', {
    patient: `Patient/${patientId}`,
    category: 'laboratory',
    abnormal: 'true',
    _sort: '-date'
  });
}
```

## Operation Extension Points

### Custom Operations

The platform supports defining custom FHIR operations for specialized functionality.

**Key Capabilities:**
- Define custom operations at the system, resource type, or instance level
- Implement complex business logic
- Expose specialized functionality through the FHIR API

```typescript
// Example: Implementing a custom operation for risk assessment
import express from 'express';
import { FhirClient } from '../services/fhir-client';

const app = express();
app.use(express.json());

// Custom operation endpoint for calculating cardiovascular risk
app.post('/fhir/Patient/:id/$cardiovascular-risk', async (req, res) => {
  try {
    const patientId = req.params.id;
    const parameters = req.body;
    
    // Extract operation parameters
    const includeLabs = getParameterValue(parameters, 'includeLabs', 'boolean') || false;
    const riskModel = getParameterValue(parameters, 'riskModel', 'string') || 'framingham';
    
    // Fetch patient data
    const fhirClient = new FhirClient(process.env.FHIR_SERVER_URL, req.headers.authorization);
    const patient = await fhirClient.read('Patient', patientId);
    
    // Fetch relevant observations
    const observations = await fetchRelevantObservations(fhirClient, patientId, includeLabs);
    
    // Calculate risk score
    const riskScore = calculateRiskScore(patient, observations, riskModel);
    
    // Create response parameters
    const response = {
      resourceType: 'Parameters',
      parameter: [
        {
          name: 'riskScore',
          valueDecimal: riskScore.score
        },
        {
          name: 'riskLevel',
          valueString: riskScore.level
        },
        {
          name: 'riskFactors',
          valueString: riskScore.factors.join(', ')
        },
        {
          name: 'recommendedActions',
          part: riskScore.recommendations.map(rec => ({
            name: 'action',
            valueString: rec
          }))
        }
      ]
    };
    
    res.status(200).json(response);
  } catch (error) {
    console.error('Error in cardiovascular risk operation:', error);
    res.status(500).json({
      resourceType: 'OperationOutcome',
      issue: [{
        severity: 'error',
        code: 'processing',
        diagnostics: error.message
      }]
    });
  }
});

// Helper functions
function getParameterValue(parameters: any, name: string, type: string): any {
  const param = parameters.parameter?.find((p: any) => p.name === name);
  if (!param) return null;
  
  switch (type) {
    case 'boolean':
      return param.valueBoolean;
    case 'string':
      return param.valueString;
    case 'decimal':
      return param.valueDecimal;
    default:
      return null;
  }
}

async function fetchRelevantObservations(fhirClient: FhirClient, patientId: string, includeLabs: boolean) {
  // Implementation details
  return [];
}

function calculateRiskScore(patient: any, observations: any[], model: string) {
  // Implementation details
  return {
    score: 0.15,
    level: 'moderate',
    factors: ['hypertension', 'age', 'smoking'],
    recommendations: [
      'Consider statin therapy',
      'Lifestyle modifications',
      'Follow-up in 3 months'
    ]
  };
}
```

## Terminology Extension Points

### Custom Terminology Services

The platform allows for integration with custom terminology services and value sets.

**Key Capabilities:**
- Define custom code systems and value sets
- Implement specialized terminology validation
- Integrate with external terminology services

```typescript
// Example: Custom terminology service integration
import axios from 'axios';

class TerminologyService {
  constructor(private baseUrl: string, private apiKey: string) {}
  
  // Validate if a code is in a value set
  async validateCode(code: string, system: string, valueSetUrl: string): Promise<boolean> {
    try {
      const response = await axios.get(
        `${this.baseUrl}/ValueSet/$validate-code`,
        {
          params: {
            code,
            system,
            url: valueSetUrl
          },
          headers: {
            'Authorization': `Bearer ${this.apiKey}`,
            'Accept': 'application/fhir+json'
          }
        }
      );
      
      return response.data.parameter.find((p: any) => p.name === 'result')?.valueBoolean || false;
    } catch (error) {
      console.error('Error validating code:', error);
      return false;
    }
  }
  
  // Expand a value set
  async expandValueSet(valueSetUrl: string, filter?: string): Promise<any[]> {
    try {
      const response = await axios.get(
        `${this.baseUrl}/ValueSet/$expand`,
        {
          params: {
            url: valueSetUrl,
            filter
          },
          headers: {
            'Authorization': `Bearer ${this.apiKey}`,
            'Accept': 'application/fhir+json'
          }
        }
      );
      
      return response.data.expansion?.contains || [];
    } catch (error) {
      console.error('Error expanding value set:', error);
      return [];
    }
  }
  
  // Translate a code from one system to another
  async translateCode(code: string, sourceSystem: string, targetSystem: string): Promise<string | null> {
    try {
      const response = await axios.post(
        `${this.baseUrl}/ConceptMap/$translate`,
        {
          resourceType: 'Parameters',
          parameter: [
            {
              name: 'code',
              valueString: code
            },
            {
              name: 'system',
              valueUri: sourceSystem
            },
            {
              name: 'targetsystem',
              valueUri: targetSystem
            }
          ]
        },
        {
          headers: {
            'Authorization': `Bearer ${this.apiKey}`,
            'Content-Type': 'application/fhir+json',
            'Accept': 'application/fhir+json'
          }
        }
      );
      
      const match = response.data.parameter.find((p: any) => 
        p.name === 'match' && p.part.some((part: any) => part.name === 'equivalence' && part.valueCode === 'equivalent')
      );
      
      if (match) {
        const codePart = match.part.find((part: any) => part.name === 'code');
        return codePart?.valueString || null;
      }
      
      return null;
    } catch (error) {
      console.error('Error translating code:', error);
      return null;
    }
  }
}
```

## Related Resources

- [FHIR Interoperability Platform Overview](../01-getting-started/overview.md)
- [Core APIs](../02-core-functionality/core-apis.md)
- [Data Model](../02-core-functionality/data-model.md)
- [Integration Points](../02-core-functionality/integration-points.md)
- [Advanced Use Cases](advanced-use-cases.md)
- [Customization](customization.md)
