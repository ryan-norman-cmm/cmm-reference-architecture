# FHIR Interoperability Platform Data Model

## Introduction

The FHIR Interoperability Platform implements the HL7 FHIR (Fast Healthcare Interoperability Resources) data model, which defines a comprehensive set of healthcare resources and their relationships. This document outlines the core data model used by the platform, with a focus on our TypeScript implementation and cloud-native storage architecture.

## FHIR Resource Model

### Resource Structure

All FHIR resources share a common base structure, implemented in TypeScript for type safety and consistency.

```typescript
// Base Resource interface
export interface Resource {
  resourceType: string;
  id?: string;
  meta?: Meta;
  implicitRules?: string;
  language?: string;
}

// Meta information for resources
export interface Meta {
  versionId?: string;
  lastUpdated?: string;
  source?: string;
  profile?: string[];
  security?: Coding[];
  tag?: Coding[];
}

// Domain resources add narrative and other common elements
export interface DomainResource extends Resource {
  text?: Narrative;
  contained?: Resource[];
  extension?: Extension[];
  modifierExtension?: Extension[];
}

// Narrative text for human display
export interface Narrative {
  status: 'generated' | 'extensions' | 'additional' | 'empty';
  div: string; // XHTML content
}

// Extension mechanism for additional data
export interface Extension {
  url: string;
  valueString?: string;
  valueInteger?: number;
  valueBoolean?: boolean;
  valueCode?: string;
  valueDateTime?: string;
  // ... other value types
}
```

### Core Resource Types

The platform implements all standard FHIR R4 resource types, with TypeScript interfaces for type safety. Here are some of the most commonly used resources:

#### Patient

```typescript
export interface Patient extends DomainResource {
  resourceType: 'Patient';
  identifier?: Identifier[];
  active?: boolean;
  name?: HumanName[];
  telecom?: ContactPoint[];
  gender?: 'male' | 'female' | 'other' | 'unknown';
  birthDate?: string;
  deceasedBoolean?: boolean;
  deceasedDateTime?: string;
  address?: Address[];
  maritalStatus?: CodeableConcept;
  multipleBirthBoolean?: boolean;
  multipleBirthInteger?: number;
  photo?: Attachment[];
  contact?: PatientContact[];
  communication?: PatientCommunication[];
  generalPractitioner?: Reference[];
  managingOrganization?: Reference;
  link?: PatientLink[];
}
```

#### Encounter

```typescript
export interface Encounter extends DomainResource {
  resourceType: 'Encounter';
  identifier?: Identifier[];
  status: 'planned' | 'arrived' | 'triaged' | 'in-progress' | 'onleave' | 'finished' | 'cancelled' | 'entered-in-error' | 'unknown';
  statusHistory?: EncounterStatusHistory[];
  class: Coding;
  classHistory?: EncounterClassHistory[];
  type?: CodeableConcept[];
  serviceType?: CodeableConcept;
  priority?: CodeableConcept;
  subject?: Reference;
  episodeOfCare?: Reference[];
  basedOn?: Reference[];
  participant?: EncounterParticipant[];
  appointment?: Reference[];
  period?: Period;
  length?: Duration;
  reasonCode?: CodeableConcept[];
  reasonReference?: Reference[];
  diagnosis?: EncounterDiagnosis[];
  account?: Reference[];
  hospitalization?: EncounterHospitalization;
  location?: EncounterLocation[];
  serviceProvider?: Reference;
  partOf?: Reference;
}
```

#### Observation

```typescript
export interface Observation extends DomainResource {
  resourceType: 'Observation';
  identifier?: Identifier[];
  basedOn?: Reference[];
  partOf?: Reference[];
  status: 'registered' | 'preliminary' | 'final' | 'amended' | 'corrected' | 'cancelled' | 'entered-in-error' | 'unknown';
  category?: CodeableConcept[];
  code: CodeableConcept;
  subject?: Reference;
  focus?: Reference[];
  encounter?: Reference;
  effectiveDateTime?: string;
  effectivePeriod?: Period;
  effectiveTiming?: Timing;
  effectiveInstant?: string;
  issued?: string;
  performer?: Reference[];
  valueQuantity?: Quantity;
  valueCodeableConcept?: CodeableConcept;
  valueString?: string;
  valueBoolean?: boolean;
  valueInteger?: number;
  valueRange?: Range;
  valueRatio?: Ratio;
  valueSampledData?: SampledData;
  valueTime?: string;
  valueDateTime?: string;
  valuePeriod?: Period;
  dataAbsentReason?: CodeableConcept;
  interpretation?: CodeableConcept[];
  note?: Annotation[];
  bodySite?: CodeableConcept;
  method?: CodeableConcept;
  specimen?: Reference;
  device?: Reference;
  referenceRange?: ObservationReferenceRange[];
  hasMember?: Reference[];
  derivedFrom?: Reference[];
  component?: ObservationComponent[];
}
```

### Common Data Types

FHIR defines several common data types used across resources:

```typescript
// Identifier (e.g., MRN, SSN)
export interface Identifier {
  use?: 'usual' | 'official' | 'temp' | 'secondary' | 'old';
  type?: CodeableConcept;
  system?: string;
  value?: string;
  period?: Period;
  assigner?: Reference;
}

// Human name
export interface HumanName {
  use?: 'usual' | 'official' | 'temp' | 'nickname' | 'anonymous' | 'old' | 'maiden';
  text?: string;
  family?: string;
  given?: string[];
  prefix?: string[];
  suffix?: string[];
  period?: Period;
}

// Address
export interface Address {
  use?: 'home' | 'work' | 'temp' | 'old' | 'billing';
  type?: 'postal' | 'physical' | 'both';
  text?: string;
  line?: string[];
  city?: string;
  district?: string;
  state?: string;
  postalCode?: string;
  country?: string;
  period?: Period;
}

// Contact point (phone, email, etc.)
export interface ContactPoint {
  system?: 'phone' | 'fax' | 'email' | 'pager' | 'url' | 'sms' | 'other';
  value?: string;
  use?: 'home' | 'work' | 'temp' | 'old' | 'mobile';
  rank?: number;
  period?: Period;
}

// Time period
export interface Period {
  start?: string;
  end?: string;
}

// Reference to another resource
export interface Reference {
  reference?: string;
  type?: string;
  identifier?: Identifier;
  display?: string;
}

// Codeable concept (code with text)
export interface CodeableConcept {
  coding?: Coding[];
  text?: string;
}

// Coding (code from a system)
export interface Coding {
  system?: string;
  version?: string;
  code?: string;
  display?: string;
  userSelected?: boolean;
}
```

## Data Storage Model

The FHIR Interoperability Platform uses a cloud-native storage architecture optimized for healthcare data.

### Document Database

FHIR resources are stored in a document database (MongoDB or CosmosDB) for schema flexibility and scalability.

```typescript
// Example: MongoDB schema for FHIR resources
import mongoose, { Schema, Document } from 'mongoose';
import { Resource } from 'fhir/r4';

// Base schema for all FHIR resources
const resourceSchema = new Schema(
  {
    resourceType: { type: String, required: true, index: true },
    id: { type: String, required: true, index: true },
    meta: {
      versionId: { type: String, index: true },
      lastUpdated: { type: Date, index: true },
      source: String,
      profile: [String],
      security: [{
        system: String,
        code: String,
        display: String
      }],
      tag: [{
        system: String,
        code: String,
        display: String
      }]
    },
    // Store the full FHIR resource as a schemaless object
    resource: Schema.Types.Mixed,
    // Additional fields for efficient querying
    patientReference: { type: String, sparse: true, index: true },
    encounterReference: { type: String, sparse: true, index: true },
    effectiveDate: { type: Date, sparse: true, index: true },
    status: { type: String, sparse: true, index: true },
    // Tenant ID for multi-tenancy
    tenantId: { type: String, required: true, index: true },
    // Soft delete flag
    deleted: { type: Boolean, default: false, index: true },
    // Compartment references for access control and searching
    compartments: {
      patient: { type: [String], index: true, sparse: true },
      encounter: { type: [String], index: true, sparse: true },
      practitioner: { type: [String], index: true, sparse: true },
      relatedPerson: { type: [String], index: true, sparse: true }
    }
  },
  { 
    timestamps: true,
    // Use optimistic concurrency control
    optimisticConcurrency: true,
    // Store full history
    versionKey: 'meta.versionId'
  }
);

// Create indexes for common search parameters
resourceSchema.index({ 'resource.name.family': 'text', 'resource.name.given': 'text' });
resourceSchema.index({ 'resource.identifier.system': 1, 'resource.identifier.value': 1 });
resourceSchema.index({ 'resource.code.coding.system': 1, 'resource.code.coding.code': 1 });

export interface FhirResourceDocument extends Document {
  resourceType: string;
  id: string;
  meta?: {
    versionId?: string;
    lastUpdated?: Date;
    source?: string;
    profile?: string[];
    security?: Array<{ system?: string; code?: string; display?: string }>;
    tag?: Array<{ system?: string; code?: string; display?: string }>;
  };
  resource: Resource;
  patientReference?: string;
  encounterReference?: string;
  effectiveDate?: Date;
  status?: string;
  tenantId: string;
  deleted: boolean;
  compartments?: {
    patient?: string[];
    encounter?: string[];
    practitioner?: string[];
    relatedPerson?: string[];
  };
}

export const FhirResource = mongoose.model<FhirResourceDocument>('FhirResource', resourceSchema);
```

### Search Index

A specialized search index (Elasticsearch) is used for efficient FHIR search operations.

```typescript
// Example: Elasticsearch mapping for FHIR resources
const fhirResourceMapping = {
  mappings: {
    properties: {
      resourceType: { type: 'keyword' },
      id: { type: 'keyword' },
      'meta.versionId': { type: 'keyword' },
      'meta.lastUpdated': { type: 'date' },
      'meta.profile': { type: 'keyword' },
      'meta.security.code': { type: 'keyword' },
      'meta.tag.code': { type: 'keyword' },
      
      // Patient-specific fields
      'identifier.system': { type: 'keyword' },
      'identifier.value': { type: 'keyword' },
      'name.family': { type: 'text', fields: { keyword: { type: 'keyword' } } },
      'name.given': { type: 'text', fields: { keyword: { type: 'keyword' } } },
      'telecom.value': { type: 'keyword' },
      'gender': { type: 'keyword' },
      'birthDate': { type: 'date' },
      'address.city': { type: 'keyword' },
      'address.state': { type: 'keyword' },
      'address.postalCode': { type: 'keyword' },
      'address.country': { type: 'keyword' },
      
      // Observation-specific fields
      'code.coding.system': { type: 'keyword' },
      'code.coding.code': { type: 'keyword' },
      'valueQuantity.value': { type: 'float' },
      'valueQuantity.unit': { type: 'keyword' },
      'valueCodeableConcept.coding.code': { type: 'keyword' },
      'effectiveDateTime': { type: 'date' },
      
      // Common fields
      'subject.reference': { type: 'keyword' },
      'encounter.reference': { type: 'keyword' },
      'status': { type: 'keyword' },
      
      // Access control
      'tenantId': { type: 'keyword' },
      'compartments.patient': { type: 'keyword' },
      'compartments.encounter': { type: 'keyword' },
      'compartments.practitioner': { type: 'keyword' },
      
      // Full-text search
      '_all_text': { type: 'text' }
    }
  }
};
```

### Data Access Layer

A TypeScript-based data access layer provides a consistent interface for FHIR resource operations.

```typescript
// Example: FHIR Resource Repository
import { Resource, Bundle, OperationOutcome } from 'fhir/r4';
import { FhirResource, FhirResourceDocument } from '../models/fhir-resource';
import { SearchParameters } from '../models/search-parameters';
import { ElasticsearchService } from './elasticsearch.service';

export class FhirResourceRepository {
  constructor(
    private elasticsearchService: ElasticsearchService,
    private tenantId: string
  ) {}

  // Create a new resource
  async create(resource: Resource): Promise<Resource> {
    // Generate ID if not provided
    if (!resource.id) {
      resource.id = this.generateId();
    }
    
    // Set metadata
    resource.meta = {
      ...resource.meta,
      lastUpdated: new Date().toISOString(),
      versionId: '1'
    };
    
    // Extract compartment references
    const compartments = this.extractCompartments(resource);
    
    // Create document
    const fhirResource = new FhirResource({
      resourceType: resource.resourceType,
      id: resource.id,
      meta: resource.meta,
      resource,
      tenantId: this.tenantId,
      deleted: false,
      compartments,
      ...this.extractSearchFields(resource)
    });
    
    // Save to database
    await fhirResource.save();
    
    // Index for search
    await this.elasticsearchService.indexResource(resource, this.tenantId, compartments);
    
    return resource;
  }
  
  // Read a resource by ID
  async read(resourceType: string, id: string): Promise<Resource | null> {
    const fhirResource = await FhirResource.findOne({
      resourceType,
      id,
      tenantId: this.tenantId,
      deleted: false
    });
    
    return fhirResource?.resource || null;
  }
  
  // Update a resource
  async update(resource: Resource): Promise<Resource> {
    if (!resource.id) {
      throw new Error('Resource ID is required for updates');
    }
    
    // Find existing resource
    const existingResource = await FhirResource.findOne({
      resourceType: resource.resourceType,
      id: resource.id,
      tenantId: this.tenantId,
      deleted: false
    });
    
    if (!existingResource) {
      throw new Error(`Resource ${resource.resourceType}/${resource.id} not found`);
    }
    
    // Update version
    const currentVersion = parseInt(existingResource.meta?.versionId || '0');
    resource.meta = {
      ...resource.meta,
      lastUpdated: new Date().toISOString(),
      versionId: (currentVersion + 1).toString()
    };
    
    // Extract compartment references
    const compartments = this.extractCompartments(resource);
    
    // Update document
    existingResource.meta = resource.meta;
    existingResource.resource = resource;
    existingResource.compartments = compartments;
    Object.assign(existingResource, this.extractSearchFields(resource));
    
    // Save to database
    await existingResource.save();
    
    // Update search index
    await this.elasticsearchService.updateResource(resource, this.tenantId, compartments);
    
    return resource;
  }
  
  // Delete a resource
  async delete(resourceType: string, id: string): Promise<void> {
    // Soft delete in database
    await FhirResource.updateOne(
      { resourceType, id, tenantId: this.tenantId },
      { deleted: true }
    );
    
    // Remove from search index
    await this.elasticsearchService.deleteResource(resourceType, id, this.tenantId);
  }
  
  // Search for resources
  async search(resourceType: string, params: SearchParameters): Promise<Bundle> {
    // Convert FHIR search parameters to Elasticsearch query
    const query = this.elasticsearchService.buildQuery(resourceType, params, this.tenantId);
    
    // Execute search
    const searchResults = await this.elasticsearchService.search(query);
    
    // Convert to FHIR Bundle
    return this.createSearchBundle(resourceType, searchResults, params);
  }
  
  // Helper methods
  private generateId(): string {
    // Generate a UUID
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
      const r = Math.random() * 16 | 0, v = c === 'x' ? r : (r & 0x3 | 0x8);
      return v.toString(16);
    });
  }
  
  private extractCompartments(resource: Resource): any {
    // Extract compartment references based on resource type
    const compartments: any = {};
    
    // Patient compartment
    if (resource.resourceType === 'Patient') {
      compartments.patient = [resource.id];
    } else if ('subject' in resource && resource.subject?.reference?.startsWith('Patient/')) {
      compartments.patient = [resource.subject.reference.replace('Patient/', '')];
    } else if ('patient' in resource && resource.patient?.reference?.startsWith('Patient/')) {
      compartments.patient = [resource.patient.reference.replace('Patient/', '')];
    }
    
    // Encounter compartment
    if (resource.resourceType === 'Encounter') {
      compartments.encounter = [resource.id];
    } else if ('encounter' in resource && resource.encounter?.reference?.startsWith('Encounter/')) {
      compartments.encounter = [resource.encounter.reference.replace('Encounter/', '')];
    }
    
    // Practitioner compartment
    if (resource.resourceType === 'Practitioner') {
      compartments.practitioner = [resource.id];
    } else if ('performer' in resource && Array.isArray(resource.performer)) {
      compartments.practitioner = resource.performer
        .filter(p => p.reference?.startsWith('Practitioner/'))
        .map(p => p.reference!.replace('Practitioner/', ''));
    }
    
    return compartments;
  }
  
  private extractSearchFields(resource: Resource): any {
    // Extract common search fields based on resource type
    const fields: any = {};
    
    // Extract patient reference
    if ('subject' in resource && resource.subject?.reference?.startsWith('Patient/')) {
      fields.patientReference = resource.subject.reference;
    } else if ('patient' in resource && resource.patient?.reference?.startsWith('Patient/')) {
      fields.patientReference = resource.patient.reference;
    }
    
    // Extract encounter reference
    if ('encounter' in resource && resource.encounter?.reference) {
      fields.encounterReference = resource.encounter.reference;
    }
    
    // Extract effective date
    if ('effectiveDateTime' in resource && resource.effectiveDateTime) {
      fields.effectiveDate = new Date(resource.effectiveDateTime);
    } else if ('effectivePeriod' in resource && resource.effectivePeriod?.start) {
      fields.effectiveDate = new Date(resource.effectivePeriod.start);
    }
    
    // Extract status
    if ('status' in resource) {
      fields.status = resource.status;
    }
    
    return fields;
  }
  
  private createSearchBundle(resourceType: string, searchResults: any, params: SearchParameters): Bundle {
    // Create a FHIR Bundle with search results
    // Include pagination links, total count, etc.
    // ...
  }
}
```

## Multi-Version Support

The platform supports FHIR resource versioning for history tracking and audit purposes.

```typescript
// Example: History repository for FHIR resources
export class FhirHistoryRepository {
  constructor(private tenantId: string) {}

  // Get resource history
  async getHistory(resourceType: string, id: string): Promise<Bundle> {
    const versions = await FhirResource.find(
      {
        resourceType,
        id,
        tenantId: this.tenantId
      },
      null,
      { sort: { 'meta.versionId': -1 } }
    );
    
    // Convert to history bundle
    return this.createHistoryBundle(resourceType, id, versions);
  }
  
  // Get specific version of a resource
  async getVersion(resourceType: string, id: string, versionId: string): Promise<Resource | null> {
    const version = await FhirResource.findOne({
      resourceType,
      id,
      'meta.versionId': versionId,
      tenantId: this.tenantId
    });
    
    return version?.resource || null;
  }
  
  private createHistoryBundle(resourceType: string, id: string, versions: FhirResourceDocument[]): Bundle {
    // Create a FHIR Bundle with resource versions
    // ...
  }
}
```

## Data Validation

The platform implements comprehensive validation for FHIR resources based on the FHIR specification and implementation guides.

```typescript
// Example: FHIR Validation Service
import { Resource, OperationOutcome } from 'fhir/r4';

export class ValidationService {
  // Validate a FHIR resource
  async validateResource(resource: Resource, profile?: string): Promise<OperationOutcome> {
    const outcome: OperationOutcome = {
      resourceType: 'OperationOutcome',
      issue: []
    };
    
    // Basic structural validation
    this.validateStructure(resource, outcome);
    
    // Profile validation if specified
    if (profile) {
      await this.validateAgainstProfile(resource, profile, outcome);
    } else if (resource.meta?.profile?.length) {
      // Validate against profiles declared in the resource
      for (const profileUrl of resource.meta.profile) {
        await this.validateAgainstProfile(resource, profileUrl, outcome);
      }
    }
    
    // Terminology validation
    await this.validateTerminology(resource, outcome);
    
    // Business rules validation
    this.validateBusinessRules(resource, outcome);
    
    return outcome;
  }
  
  private validateStructure(resource: Resource, outcome: OperationOutcome): void {
    // Validate resource structure against FHIR specification
    // ...
  }
  
  private async validateAgainstProfile(resource: Resource, profile: string, outcome: OperationOutcome): Promise<void> {
    // Validate resource against a specific profile
    // ...
  }
  
  private async validateTerminology(resource: Resource, outcome: OperationOutcome): Promise<void> {
    // Validate codes against terminology services
    // ...
  }
  
  private validateBusinessRules(resource: Resource, outcome: OperationOutcome): void {
    // Validate resource against business rules
    // ...
  }
}
```

## Data Security Model

The platform implements a comprehensive security model for FHIR data protection.

```typescript
// Example: FHIR Authorization Service
import { Resource } from 'fhir/r4';

export class AuthorizationService {
  constructor(private tenantId: string, private user: any) {}

  // Check if user has permission to access a resource
  async checkAccess(resource: Resource, operation: 'read' | 'write' | 'delete'): Promise<boolean> {
    // Check tenant access
    if (this.tenantId !== resource.meta?.tag?.find(t => t.system === 'http://terminology.hl7.org/CodeSystem/v3-ActReason' && t.code === 'TENANT')?.display) {
      return false;
    }
    
    // Check resource-level permissions
    if (!this.hasResourcePermission(resource.resourceType, operation)) {
      return false;
    }
    
    // Check compartment-based access
    if (!await this.hasCompartmentAccess(resource)) {
      return false;
    }
    
    // Check sensitivity-based access
    if (!this.hasSensitivityAccess(resource)) {
      return false;
    }
    
    return true;
  }
  
  private hasResourcePermission(resourceType: string, operation: 'read' | 'write' | 'delete'): boolean {
    // Check if user has permission for the resource type and operation
    const permissions = this.user.permissions || [];
    return permissions.some(p => {
      // Check resource type permission
      const resourceMatch = p.resource === '*' || p.resource === resourceType;
      // Check operation permission
      const operationMatch = p.operations === '*' || p.operations.includes(operation);
      return resourceMatch && operationMatch;
    });
  }
  
  private async hasCompartmentAccess(resource: Resource): Promise<boolean> {
    // Check if user has access to the compartments the resource belongs to
    // For example, patient-specific access
    if (this.user.patientAccess) {
      // Get compartments for the resource
      const compartments = await this.getResourceCompartments(resource);
      
      // Check if user has access to any of the patient compartments
      if (compartments.patient && compartments.patient.length > 0) {
        return compartments.patient.some(patientId => 
          this.user.patientAccess.includes(patientId) || this.user.patientAccess.includes('*')
        );
      }
    }
    
    return true;
  }
  
  private hasSensitivityAccess(resource: Resource): boolean {
    // Check if user has access to the sensitivity level of the resource
    const sensitivity = resource.meta?.security?.find(s => 
      s.system === 'http://terminology.hl7.org/CodeSystem/v3-Confidentiality'
    )?.code;
    
    if (sensitivity) {
      const userSensitivityAccess = this.user.sensitivityAccess || [];
      return userSensitivityAccess.includes(sensitivity) || userSensitivityAccess.includes('*');
    }
    
    return true;
  }
  
  private async getResourceCompartments(resource: Resource): Promise<any> {
    // Get compartments for the resource
    // ...
    return {};
  }
}
```

## Conclusion

The FHIR Interoperability Platform implements a comprehensive data model based on the HL7 FHIR standard, with TypeScript interfaces for type safety and a cloud-native storage architecture for scalability. This data model provides a solid foundation for healthcare interoperability, enabling secure and efficient exchange of healthcare information.
