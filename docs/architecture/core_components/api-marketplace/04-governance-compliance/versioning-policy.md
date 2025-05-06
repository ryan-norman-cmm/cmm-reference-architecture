# API Marketplace Versioning Policy

## Introduction

This document outlines the versioning policy for the API Marketplace component of the CMM Technology Platform. It provides detailed guidelines on how versioning is implemented, how backward compatibility is maintained, and how breaking changes are managed. Following this policy ensures a consistent and predictable evolution of the API Marketplace, minimizing disruption for consumers while enabling innovation and improvement.

## Semantic Versioning

The API Marketplace follows semantic versioning (MAJOR.MINOR.PATCH) to provide clear communication about the nature of changes in each release.

### Version Increment Rules

- **MAJOR version (X.0.0)**: Incremented when making incompatible API changes that require consumers to modify their integration. Major version changes may include:
  - Removing or renaming API endpoints
  - Changing required request parameters
  - Modifying response structures in a non-backward compatible way
  - Changing authentication or authorization mechanisms
  - Significant architectural changes affecting API behavior

- **MINOR version (X.Y.0)**: Incremented when adding functionality in a backward-compatible manner. Minor version changes may include:
  - Adding new API endpoints
  - Adding optional request parameters
  - Adding new fields to response structures
  - Adding new features that don't affect existing functionality
  - Performance improvements that don't affect API behavior

- **PATCH version (X.Y.Z)**: Incremented when making backward-compatible bug fixes or minor improvements. Patch version changes may include:
  - Bug fixes that don't affect API behavior
  - Documentation improvements
  - Internal code refactoring without API changes
  - Security patches that maintain compatibility
  - Minor performance optimizations

### Version Format

The version format follows the pattern `X.Y.Z[-PRERELEASE][+BUILD]` where:

- `X`, `Y`, and `Z` are non-negative integers
- `PRERELEASE` is an optional prerelease identifier (e.g., alpha.1, beta.2, rc.1)
- `BUILD` is an optional build metadata identifier

Examples:
- `1.0.0`: Initial major release
- `1.1.0`: Minor release with new features
- `1.1.1`: Patch release with bug fixes
- `2.0.0-beta.1`: Beta prerelease of a major version
- `1.2.0+20230615`: Minor release with build metadata

## API Versioning

The API Marketplace implements API versioning to ensure backward compatibility while allowing for evolution and improvement.

### API Version Identification

API versions are identified through the following mechanisms:

#### URI Path Versioning

The primary versioning mechanism is URI path versioning, where the major version is included in the API path:

```
https://api-marketplace.example.com/api/v1/apis
https://api-marketplace.example.com/api/v2/apis
```

This approach provides clear visibility of the API version and ensures that different major versions can coexist.

#### Header Versioning

For minor and patch versions within a major version, the `API-Version` header can be used:

```http
GET /api/v1/apis
API-Version: 1.2.0
Authorization: Bearer {token}
```

If the `API-Version` header is not specified, the latest minor/patch version of the specified major version is used.

#### Content Type Versioning

For specialized content types, version information may be included in the `Accept` header:

```http
GET /api/v1/apis
Accept: application/vnd.cmm.api-marketplace.v1+json
Authorization: Bearer {token}
```

### API Deprecation Process

The API Marketplace follows a structured process for deprecating APIs:

1. **Announcement**: Deprecation is announced at least 6 months before the end-of-life date for major versions, and at least 3 months for minor versions.

2. **Documentation**: Deprecated APIs are clearly marked in documentation with alternatives and migration guidance.

3. **Runtime Warnings**: Deprecated APIs return deprecation warnings in response headers:

   ```http
   HTTP/1.1 200 OK
   Content-Type: application/json
   Deprecation: true
   Sunset: Sat, 31 Dec 2023 23:59:59 GMT
   Link: <https://api-marketplace.example.com/api/v2/apis>; rel="successor-version"
   ```

4. **Monitoring Period**: During the deprecation period, usage is monitored to identify consumers who need to migrate.

5. **End-of-Life**: At the announced end-of-life date, the deprecated API is decommissioned.

### API Versioning Lifecycle

Each API version follows a defined lifecycle:

1. **Development**: Initial development phase, available in test environments.

2. **Preview/Beta**: Available for early adopters to test and provide feedback.

3. **General Availability (GA)**: Officially released and fully supported.

4. **Deprecated**: Still available but scheduled for removal.

5. **End-of-Life**: No longer available or supported.

## Schema Versioning

The API Marketplace implements schema versioning to manage the evolution of data structures.

### Schema Compatibility Rules

The following compatibility rules govern schema evolution:

#### Backward Compatibility

Changes must be backward compatible within the same major version:

- New fields can be added but not removed
- Field types cannot be changed in incompatible ways
- Required fields cannot be added in minor/patch versions
- Enum values can be added but not removed or renamed

#### Forward Compatibility

To support forward compatibility:

- Consumers must ignore unknown fields
- Default values should be provided for new fields
- Extensible enums should use the "other" pattern
- Versioned media types should be used for content negotiation

### Schema Migration

For schema changes that require migration:

1. **Data Migration**: Backend data is migrated to support the new schema.

2. **Dual Support**: Both old and new schemas are supported during the transition period.

3. **Client Migration**: Clients are updated to use the new schema.

4. **Deprecation**: The old schema is deprecated after sufficient transition time.

## Dependency Management

The API Marketplace implements a structured approach to dependency management.

### Dependency Version Constraints

Dependencies are specified with appropriate version constraints:

- **Direct Dependencies**: Specified with caret ranges (`^1.2.3`) to allow compatible updates.

- **Peer Dependencies**: Specified with broader ranges to allow flexibility.

- **Development Dependencies**: May use more precise constraints for reproducibility.

Example package.json:

```json
{
  "dependencies": {
    "@cmm/security-framework": "^2.3.0",
    "@cmm/event-broker-client": "^1.5.0",
    "express": "^4.18.0",
    "mongoose": "^7.0.0"
  },
  "peerDependencies": {
    "react": "^17.0.0 || ^18.0.0",
    "react-dom": "^17.0.0 || ^18.0.0"
  },
  "devDependencies": {
    "typescript": "4.9.5",
    "jest": "29.5.0"
  }
}
```

### Dependency Update Process

Dependencies are updated following a structured process:

1. **Regular Scanning**: Dependencies are regularly scanned for updates and security vulnerabilities.

2. **Update Evaluation**: Updates are evaluated for compatibility, performance, and security implications.

3. **Testing**: Updates are tested in development and staging environments before production deployment.

4. **Staged Rollout**: Major dependency updates are rolled out gradually to minimize risk.

5. **Documentation**: Dependency changes are documented in release notes.

## Breaking Changes

The API Marketplace implements a structured approach to managing breaking changes.

### Breaking Change Identification

Potential breaking changes are identified through:

- **API Contract Analysis**: Comparing API specifications for compatibility.

- **Automated Testing**: Running integration tests with both old and new versions.

- **Dependency Impact Analysis**: Assessing the impact of dependency updates.

- **Consumer Usage Analysis**: Analyzing how consumers use the API to identify impact.

### Breaking Change Approval

Breaking changes require explicit approval:

1. **Impact Assessment**: Detailed assessment of the impact on consumers.

2. **Justification**: Clear justification for why the breaking change is necessary.

3. **Migration Plan**: Comprehensive plan for how consumers will migrate.

4. **Governance Review**: Review and approval by the API governance board.

### Breaking Change Communication

Breaking changes are communicated through multiple channels:

- **Advance Notice**: At least 6 months notice before the breaking change.

- **Documentation**: Detailed documentation of the changes and migration steps.

- **Direct Communication**: Direct outreach to affected consumers.

- **Deprecation Warnings**: Runtime warnings in API responses.

- **Migration Tools**: Tools to help consumers migrate to the new version.

## Version Lifecycle

The API Marketplace implements a structured version lifecycle.

### Version Support Periods

Each version type has a defined support period:

- **Major Versions**: Supported for at least 18 months after the release of the next major version.

- **Minor Versions**: Supported for at least 6 months after the release of the next minor version.

- **Patch Versions**: No formal support period; consumers should upgrade to the latest patch version.

### End-of-Life Process

The end-of-life process for a version includes:

1. **Announcement**: Clear communication of the end-of-life date.

2. **Migration Support**: Resources to help consumers migrate to supported versions.

3. **Limited Support Phase**: Reduced support focused on critical issues only.

4. **Decommissioning**: Removal of the version from production environments.

5. **Archiving**: Archiving of code, documentation, and support materials.

## Implementation Examples

### API Version Header Processing

```typescript
// Example: Processing API version headers in middleware
import { Request, Response, NextFunction } from 'express';
import semver from 'semver';

interface VersionedRequest extends Request {
  apiVersion: {
    major: number;
    minor: number;
    patch: number;
    raw: string;
  };
}

const API_VERSIONS = {
  '1': {
    latest: '1.2.3',
    supported: ['1.0.0', '1.1.0', '1.2.0', '1.2.3'],
    deprecated: ['1.0.0', '1.1.0']
  },
  '2': {
    latest: '2.0.1',
    supported: ['2.0.0', '2.0.1'],
    deprecated: []
  }
};

export function versionMiddleware(req: VersionedRequest, res: Response, next: NextFunction) {
  // Extract major version from URL path
  const urlMatch = req.path.match(/\/api\/v(\d+)\//i);
  const majorVersion = urlMatch ? urlMatch[1] : '1'; // Default to v1 if not specified
  
  // Extract full version from header
  const headerVersion = req.header('API-Version');
  
  // Determine the effective version
  let effectiveVersion: string;
  
  if (headerVersion && semver.valid(headerVersion)) {
    // If header version is provided and valid
    const headerMajor = semver.major(headerVersion).toString();
    
    // Ensure header major matches URL major
    if (headerMajor !== majorVersion) {
      return res.status(400).json({
        error: 'Version mismatch',
        message: `URL path specifies v${majorVersion} but header specifies v${headerMajor}`,
        details: 'Major version in URL path must match major version in API-Version header'
      });
    }
    
    // Check if version is supported
    if (!API_VERSIONS[majorVersion].supported.includes(headerVersion)) {
      return res.status(400).json({
        error: 'Unsupported version',
        message: `API version ${headerVersion} is not supported`,
        supportedVersions: API_VERSIONS[majorVersion].supported,
        latestVersion: API_VERSIONS[majorVersion].latest
      });
    }
    
    effectiveVersion = headerVersion;
  } else {
    // Use latest version for the specified major version
    effectiveVersion = API_VERSIONS[majorVersion].latest;
  }
  
  // Parse version components
  const parsedVersion = semver.parse(effectiveVersion);
  if (!parsedVersion) {
    return res.status(500).json({
      error: 'Invalid version format',
      message: `Could not parse version ${effectiveVersion}`
    });
  }
  
  // Add version info to request object
  req.apiVersion = {
    major: parsedVersion.major,
    minor: parsedVersion.minor,
    patch: parsedVersion.patch,
    raw: effectiveVersion
  };
  
  // Add deprecation header if applicable
  if (API_VERSIONS[majorVersion].deprecated.includes(effectiveVersion)) {
    const nextMajor = (parseInt(majorVersion) + 1).toString();
    res.set('Deprecation', 'true');
    res.set('Sunset', 'Sat, 31 Dec 2023 23:59:59 GMT'); // Example date
    res.set(
      'Link',
      `<https://api-marketplace.example.com/api/v${nextMajor}/>; rel="successor-version"`
    );
  }
  
  next();
}
```

### Schema Version Handling

```typescript
// Example: Schema version handling
import { Schema, model, Document } from 'mongoose';

// Define schema versions
const apiMetadataSchemaV1 = new Schema({
  name: { type: String, required: true },
  description: { type: String, required: true },
  version: { type: String, required: true },
  owner: { type: String, required: true },
  status: { type: String, enum: ['draft', 'active', 'deprecated', 'retired'], required: true },
  tags: [String],
  schemaVersion: { type: Number, default: 1 }
});

const apiMetadataSchemaV2 = new Schema({
  name: { type: String, required: true },
  description: { type: String, required: true },
  version: { type: String, required: true },
  owner: { type: String, required: true },
  status: { type: String, enum: ['draft', 'active', 'deprecated', 'retired'], required: true },
  tags: [String],
  categories: [String], // New in v2
  visibility: { type: String, enum: ['public', 'private', 'restricted'], default: 'private' }, // New in v2
  contactEmail: String, // New in v2
  schemaVersion: { type: Number, default: 2 }
});

// Create models for each version
const ApiMetadataV1 = model('ApiMetadata', apiMetadataSchemaV1);
const ApiMetadataV2 = model('ApiMetadata', apiMetadataSchemaV2);

// Service to handle schema versioning
class ApiMetadataService {
  async findById(id: string): Promise<Document> {
    // Find the document regardless of schema version
    const doc = await ApiMetadataV1.findById(id);
    if (!doc) {
      throw new Error(`API metadata with ID ${id} not found`);
    }
    
    // Determine which schema version to use
    const schemaVersion = doc.get('schemaVersion') || 1;
    
    if (schemaVersion === 1) {
      return doc;
    } else if (schemaVersion === 2) {
      // Re-hydrate with V2 schema to get proper methods and validations
      return ApiMetadataV2.hydrate(doc.toObject());
    } else {
      throw new Error(`Unknown schema version: ${schemaVersion}`);
    }
  }
  
  async create(data: any): Promise<Document> {
    // Always use the latest schema version for new documents
    return ApiMetadataV2.create({
      ...data,
      schemaVersion: 2
    });
  }
  
  async update(id: string, data: any): Promise<Document> {
    // Find the existing document to determine its schema version
    const existingDoc = await this.findById(id);
    const schemaVersion = existingDoc.get('schemaVersion') || 1;
    
    if (schemaVersion === 1) {
      // For v1 schema, only update v1 fields
      const v1Fields = ['name', 'description', 'version', 'owner', 'status', 'tags'];
      const v1Data = Object.fromEntries(
        Object.entries(data).filter(([key]) => v1Fields.includes(key))
      );
      
      return ApiMetadataV1.findByIdAndUpdate(id, v1Data, { new: true });
    } else if (schemaVersion === 2) {
      // For v2 schema, update all applicable fields
      return ApiMetadataV2.findByIdAndUpdate(id, data, { new: true });
    } else {
      throw new Error(`Unknown schema version: ${schemaVersion}`);
    }
  }
  
  async migrateToV2(id: string): Promise<Document> {
    // Migrate a v1 document to v2 schema
    const doc = await ApiMetadataV1.findById(id);
    if (!doc) {
      throw new Error(`API metadata with ID ${id} not found`);
    }
    
    const schemaVersion = doc.get('schemaVersion') || 1;
    if (schemaVersion !== 1) {
      throw new Error(`Document is not schema version 1: ${schemaVersion}`);
    }
    
    // Create a new v2 document with v1 data plus default v2 fields
    const v2Doc = new ApiMetadataV2({
      ...doc.toObject(),
      categories: [], // Default empty array for new field
      visibility: 'private', // Default value for new field
      schemaVersion: 2
    });
    
    // Save the new v2 document
    await v2Doc.save();
    
    // Delete the old v1 document
    await doc.delete();
    
    return v2Doc;
  }
}
```

## Healthcare-Specific Considerations

### FHIR Version Compatibility

For FHIR APIs in the API Marketplace, additional versioning considerations apply:

- **FHIR Version**: The FHIR standard version (e.g., DSTU2, STU3, R4) is tracked separately from the API version.

- **Implementation Guide Versions**: Versions of implementation guides (e.g., US Core) are tracked and validated.

- **Resource Version Compatibility**: FHIR resource version compatibility is managed according to FHIR specifications.

### Regulatory Impact Assessment

Version changes are assessed for regulatory impact:

- **HIPAA Compliance**: Changes are evaluated for impact on HIPAA compliance.

- **21 CFR Part 11**: Changes are evaluated for impact on electronic records and signatures.

- **GDPR**: Changes are evaluated for impact on data protection and privacy.

- **Documentation Updates**: Regulatory documentation is updated to reflect version changes.

## Related Documentation

- [Release Lifecycle](../01-getting-started/release-lifecycle.md)
- [API Registration](../02-core-functionality/api-registration.md)
- [API Discovery](../02-core-functionality/api-discovery.md)
- [Lifecycle Management](./lifecycle-management.md)
