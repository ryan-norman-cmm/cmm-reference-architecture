# FHIR Subgraph Implementation

## Introduction

Implementing a FHIR subgraph allows you to expose healthcare data stored in FHIR format through a GraphQL API. This guide explains how to map FHIR resources to GraphQL types, handle FHIR search parameters, manage resource references, and implement versioning support. By following these patterns, you can create a powerful GraphQL interface to your FHIR data that leverages the strengths of both standards.

### Quick Start

1. Set up a basic Apollo Server for your FHIR subgraph
2. Define GraphQL types that correspond to your FHIR resources
3. Implement resolvers that connect to your FHIR server
4. Add support for FHIR search parameters as GraphQL arguments
5. Configure proper handling of FHIR resource references

### Related Components

- [Creating Subgraphs](creating-subgraphs.md): Learn the basics of subgraph implementation
- [Schema Federation Patterns](../03-advanced-patterns/schema-federation.md): Advanced federation techniques
- [Query Optimization](../03-advanced-patterns/query-optimization.md): Performance improvements for FHIR queries
- [Authentication](authentication.md): Secure your FHIR subgraph

## Mapping FHIR Resources to GraphQL Types

FHIR resources have a rich, hierarchical structure that needs to be carefully mapped to GraphQL types. This section explains how to create an effective GraphQL schema for FHIR data.

### Resource Type Mapping

Each FHIR resource type should be mapped to a corresponding GraphQL type. Start with the core resource attributes and gradually add more complex elements.

```graphql
# Example: Patient resource mapping
type Patient @key(fields: "id") {
  id: ID!
  resourceType: String!
  meta: Meta
  
  # Identity fields
  identifier: [Identifier!]
  active: Boolean
  
  # Name and demographics
  name: [HumanName!]
  telecom: [ContactPoint!]
  gender: Gender
  birthDate: Date
  deceasedBoolean: Boolean
  deceasedDateTime: DateTime
  
  # Address and contacts
  address: [Address!]
  maritalStatus: CodeableConcept
  contact: [PatientContact!]
  
  # Additional fields
  communication: [PatientCommunication!]
  generalPractitioner: [Reference!]
  managingOrganization: Reference
}

# Supporting types
type Meta {
  versionId: String
  lastUpdated: DateTime
  source: String
  profile: [String!]
  security: [Coding!]
  tag: [Coding!]
}

type Identifier {
  use: IdentifierUse
  type: CodeableConcept
  system: String
  value: String
  period: Period
  assigner: Reference
}

# Additional supporting types...
```

### Handling FHIR Data Types

FHIR defines several data types that need to be mapped to GraphQL types. Here are the most common mappings:

| FHIR Data Type | GraphQL Type | Notes |
|----------------|--------------|-------|
| string | String | Direct mapping |
| integer | Int | Direct mapping |
| boolean | Boolean | Direct mapping |
| decimal | Float | May need custom scalar for precision |
| uri | String | Consider custom URI scalar |
| url | String | Consider custom URL scalar |
| canonical | String | Reference to a resource definition |
| base64Binary | String | Consider custom scalar |
| instant | DateTime | Custom scalar for ISO timestamps |
| date | Date | Custom scalar for YYYY-MM-DD |
| dateTime | DateTime | Custom scalar for partial dates |
| time | Time | Custom scalar for time |
| code | String or Enum | Use enum when possible |
| oid | String | Object identifier |
| id | ID | Resource identifier |
| markdown | String | Consider custom scalar |
| unsignedInt | Int | Non-negative integers |
| positiveInt | Int | Positive integers |

### Custom Scalars for FHIR

Implement custom scalars for FHIR-specific data types to ensure proper validation and formatting.

```typescript
// Example: Custom scalars for FHIR data types
import { GraphQLScalarType, Kind } from 'graphql';

// Date scalar for YYYY-MM-DD format
const DateScalar = new GraphQLScalarType({
  name: 'Date',
  description: 'FHIR date type (YYYY-MM-DD)',
  
  serialize(value) {
    // Convert outgoing Date to string in YYYY-MM-DD format
    if (value instanceof Date) {
      return value.toISOString().split('T')[0];
    }
    return value;
  },
  
  parseValue(value) {
    // Convert incoming string to Date
    if (typeof value === 'string') {
      // Validate format (YYYY-MM-DD)
      if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
        throw new Error('Date must be in YYYY-MM-DD format');
      }
      return new Date(value);
    }
    throw new Error('Date must be a string');
  },
  
  parseLiteral(ast) {
    // Parse date from AST in query
    if (ast.kind === Kind.STRING) {
      // Validate format (YYYY-MM-DD)
      if (!/^\d{4}-\d{2}-\d{2}$/.test(ast.value)) {
        throw new Error('Date must be in YYYY-MM-DD format');
      }
      return new Date(ast.value);
    }
    throw new Error('Date must be a string');
  },
});

// DateTime scalar for FHIR dateTime type
const DateTimeScalar = new GraphQLScalarType({
  name: 'DateTime',
  description: 'FHIR dateTime type (YYYY-MM-DDThh:mm:ss+zz:zz)',
  
  serialize(value) {
    // Convert outgoing DateTime to string
    if (value instanceof Date) {
      return value.toISOString();
    }
    return value;
  },
  
  parseValue(value) {
    // Convert incoming string to DateTime
    if (typeof value === 'string') {
      // Validate format
      const date = new Date(value);
      if (isNaN(date.getTime())) {
        throw new Error('Invalid DateTime format');
      }
      return date;
    }
    throw new Error('DateTime must be a string');
  },
  
  parseLiteral(ast) {
    // Parse dateTime from AST in query
    if (ast.kind === Kind.STRING) {
      const date = new Date(ast.value);
      if (isNaN(date.getTime())) {
        throw new Error('Invalid DateTime format');
      }
      return date;
    }
    throw new Error('DateTime must be a string');
  },
});

export { DateScalar, DateTimeScalar };
```

## Handling FHIR Search Parameters

FHIR defines a comprehensive search API that needs to be mapped to GraphQL query arguments. This section explains how to implement effective search capabilities in your GraphQL API.

### Mapping Search Parameters to Arguments

FHIR search parameters should be mapped to GraphQL query arguments, with appropriate types and documentation.

```graphql
type Query {
  "Search for patients matching the provided criteria"
  searchPatients(
    "Family name of the patient"
    family: String,
    
    "Given name of the patient"
    given: String,
    
    "Patient's date of birth"
    birthDate: Date,
    
    "Patient's gender"
    gender: Gender,
    
    "Patient's identifier"
    identifier: String,
    
    "Name of the patient (searches all name components)"
    name: String,
    
    "Phone number of the patient"
    phone: String,
    
    "Email address of the patient"
    email: String,
    
    "Address of the patient"
    address: String,
    
    "City of the patient's address"
    addressCity: String,
    
    "State of the patient's address"
    addressState: String,
    
    "Postal code of the patient's address"
    addressPostalCode: String,
    
    "Country of the patient's address"
    addressCountry: String,
    
    "Maximum number of results to return"
    _count: Int,
    
    "Sorting criteria"
    _sort: PatientSortInput,
    
    "Pagination token"
    _page: String
  ): PatientConnection!
  
  # Additional search queries for other resource types...
}

"""  
Connection type for paginated Patient results
"""
type PatientConnection {
  "List of patients matching the search criteria"
  edges: [PatientEdge!]!
  
  "Pagination information"
  pageInfo: PageInfo!
  
  "Total count of matching resources"
  totalCount: Int
}

type PatientEdge {
  "The patient resource"
  node: Patient!
  
  "Cursor for pagination"
  cursor: String!
}

type PageInfo {
  "Cursor to the first edge"
  startCursor: String
  
  "Cursor to the last edge"
  endCursor: String
  
  "Whether there are more edges after the end cursor"
  hasNextPage: Boolean!
  
  "Whether there are more edges before the start cursor"
  hasPreviousPage: Boolean!
}

input PatientSortInput {
  "Field to sort by"
  field: PatientSortField!
  
  "Sort direction"
  order: SortOrder!
}

enum PatientSortField {
  FAMILY
  GIVEN
  BIRTHDATE
  NAME
}

enum SortOrder {
  ASC
  DESC
}
```

### Implementing Search Resolvers

Search resolvers need to translate GraphQL arguments into FHIR search parameters and handle pagination.

```typescript
// Example: Patient search resolver
const resolvers = {
  Query: {
    searchPatients: async (_, args, { dataSources }) => {
      try {
        // Convert GraphQL arguments to FHIR search parameters
        const searchParams = new URLSearchParams();
        
        // Add search parameters if provided
        if (args.family) searchParams.append('family', args.family);
        if (args.given) searchParams.append('given', args.given);
        if (args.birthDate) searchParams.append('birthdate', args.birthDate);
        if (args.gender) searchParams.append('gender', args.gender.toLowerCase());
        if (args.identifier) searchParams.append('identifier', args.identifier);
        if (args.name) searchParams.append('name', args.name);
        if (args.phone) searchParams.append('telecom', `phone|${args.phone}`);
        if (args.email) searchParams.append('telecom', `email|${args.email}`);
        if (args.address) searchParams.append('address', args.address);
        if (args.addressCity) searchParams.append('address-city', args.addressCity);
        if (args.addressState) searchParams.append('address-state', args.addressState);
        if (args.addressPostalCode) searchParams.append('address-postalcode', args.addressPostalCode);
        if (args.addressCountry) searchParams.append('address-country', args.addressCountry);
        
        // Add pagination parameters
        if (args._count) searchParams.append('_count', args._count.toString());
        if (args._page) searchParams.append('_page', args._page);
        
        // Add sorting parameters
        if (args._sort) {
          const sortField = args._sort.field.toLowerCase();
          const sortOrder = args._sort.order === 'DESC' ? '-' : '';
          searchParams.append('_sort', `${sortOrder}${sortField}`);
        }
        
        // Add _total=accurate to get total count
        searchParams.append('_total', 'accurate');
        
        // Execute the search against the FHIR server
        const bundle = await dataSources.fhirAPI.searchResources('Patient', searchParams);
        
        // Extract the resources and pagination information
        const patients = bundle.entry?.map(entry => entry.resource) || [];
        const totalCount = bundle.total || 0;
        
        // Create pagination cursors
        const edges = patients.map((patient, index) => ({
          node: patient,
          cursor: Buffer.from(`${index}`).toString('base64'),
        }));
        
        // Extract links for pagination
        const nextLink = bundle.link?.find(link => link.relation === 'next')?.url;
        const previousLink = bundle.link?.find(link => link.relation === 'previous')?.url;
        
        return {
          edges,
          pageInfo: {
            startCursor: edges.length > 0 ? edges[0].cursor : null,
            endCursor: edges.length > 0 ? edges[edges.length - 1].cursor : null,
            hasNextPage: !!nextLink,
            hasPreviousPage: !!previousLink,
          },
          totalCount,
        };
      } catch (error) {
        console.error('Error searching patients:', error);
        throw new Error(`Failed to search patients: ${error.message}`);
      }
    },
    // Additional search resolvers...
  },
};
```

### Supporting Complex Search Parameters

FHIR supports complex search parameters like modifiers and prefixes. These can be mapped to specialized GraphQL input types.

```graphql
# Example: Supporting date range searches
type Query {
  searchObservations(
    "Code of the observation"
    code: String,
    
    "Patient reference"
    patient: String,
    
    "Date range for the observation"
    date: DateRangeInput,
    
    "Value quantity range"
    valueQuantity: QuantityRangeInput,
    
    # Additional parameters...
    _count: Int,
    _sort: ObservationSortInput,
    _page: String
  ): ObservationConnection!
}

input DateRangeInput {
  "Exact date match"
  eq: Date
  
  "Greater than or equal to"
  ge: Date
  
  "Greater than"
  gt: Date
  
  "Less than or equal to"
  le: Date
  
  "Less than"
  lt: Date
}

input QuantityRangeInput {
  "Exact value match"
  eq: Float
  
  "Greater than or equal to"
  ge: Float
  
  "Greater than"
  gt: Float
  
  "Less than or equal to"
  le: Float
  
  "Less than"
  lt: Float
  
  "Unit of measurement"
  unit: String
  
  "System for the unit"
  system: String
  
  "Code for the unit"
  code: String
}
```

## Managing Resource References

FHIR resources often reference other resources. In GraphQL, these references need to be resolved to provide a seamless query experience.

### Defining Reference Types

Create a flexible Reference type that can resolve to different resource types.

```graphql
# Generic Reference type
type Reference {
  "Reference string (e.g., 'Patient/123')"
  reference: String
  
  "Type of the referenced resource"
  type: String
  
  "Display name for the reference"
  display: String
  
  # Resolved resource fields
  "Resolved resource (union of possible types)"
  resource: Resource
}

# Union type for all possible resources
union Resource = Patient | Practitioner | Organization | Location | Observation | Condition | MedicationRequest | Encounter | Procedure | AllergyIntolerance | Immunization | DiagnosticReport | CarePlan | Goal | ServiceRequest
```

### Implementing Reference Resolvers

Reference resolvers need to determine the referenced resource type and fetch the appropriate resource.

```typescript
// Example: Reference resolver
const resolvers = {
  Reference: {
    // Extract the resource type from the reference string
    type: (reference) => {
      if (!reference.reference) return null;
      const parts = reference.reference.split('/');
      return parts.length === 2 ? parts[0] : null;
    },
    
    // Resolve the referenced resource
    resource: async (reference, _, { dataSources }) => {
      try {
        if (!reference.reference) return null;
        
        // Parse the reference to get type and ID
        const parts = reference.reference.split('/');
        if (parts.length !== 2) return null;
        
        const [resourceType, id] = parts;
        
        // Fetch the referenced resource
        return dataSources.fhirAPI.getResource(resourceType, id);
      } catch (error) {
        console.error(`Error resolving reference ${reference.reference}:`, error);
        return null; // Return null instead of throwing to prevent query failure
      }
    },
  },
  
  // Resolver for the Resource union type
  Resource: {
    __resolveType(resource) {
      return resource.resourceType; // Use the FHIR resourceType field
    },
  },
};
```

### Optimizing Reference Resolution

Use DataLoader to batch and cache reference resolution for better performance.

```typescript
// Example: Using DataLoader for reference resolution
import DataLoader from 'dataloader';

class FHIRDataSource extends RESTDataSource {
  constructor() {
    super();
    this.baseURL = 'https://fhir.example.com/fhir/';
    
    // Create a loader for each resource type
    this.loaders = {};
  }
  
  // Get or create a loader for a specific resource type
  getLoader(resourceType) {
    if (!this.loaders[resourceType]) {
      this.loaders[resourceType] = new DataLoader(async (ids) => {
        // Batch fetch resources by ID
        const uniqueIds = [...new Set(ids)];
        
        // Use _id search parameter to fetch multiple resources in one request
        const searchParams = new URLSearchParams();
        searchParams.append('_id', uniqueIds.join(','));
        searchParams.append('_count', uniqueIds.length.toString());
        
        const bundle = await this.searchResources(resourceType, searchParams);
        const resources = bundle.entry?.map(entry => entry.resource) || [];
        
        // Create a map of ID to resource
        const resourceMap = resources.reduce((map, resource) => {
          map[resource.id] = resource;
          return map;
        }, {});
        
        // Return resources in the same order as the requested IDs
        return ids.map(id => resourceMap[id] || null);
      });
    }
    
    return this.loaders[resourceType];
  }
  
  // Resolve a reference string to a resource
  async resolveReference(reference) {
    if (!reference) return null;
    
    const parts = reference.split('/');
    if (parts.length !== 2) return null;
    
    const [resourceType, id] = parts;
    
    // Use the appropriate loader to fetch the resource
    return this.getLoader(resourceType).load(id);
  }
}
```

## Implementing Versioning Support

FHIR resources are versioned, and GraphQL needs to support accessing specific versions of resources.

### Version-Specific Queries

Add support for querying specific versions of resources.

```graphql
type Query {
  "Get a specific patient by ID"
  patient(id: ID!, version: String): Patient
  
  "Get a specific observation by ID"
  observation(id: ID!, version: String): Observation
  
  # Additional resource queries...
}
```

### Version History Queries

Add support for retrieving the version history of a resource.

```graphql
type Query {
  "Get the version history of a patient"
  patientHistory(id: ID!): [Patient!]!
  
  "Get the version history of an observation"
  observationHistory(id: ID!): [Observation!]!
  
  # Additional history queries...
}
```

### Implementing Version Resolvers

```typescript
// Example: Version-specific resolvers
const resolvers = {
  Query: {
    patient: async (_, { id, version }, { dataSources }) => {
      try {
        if (version) {
          // Fetch a specific version of the patient
          return dataSources.fhirAPI.getResourceVersion('Patient', id, version);
        } else {
          // Fetch the current version of the patient
          return dataSources.fhirAPI.getResource('Patient', id);
        }
      } catch (error) {
        console.error(`Error fetching patient ${id}:`, error);
        throw new Error(`Failed to fetch patient: ${error.message}`);
      }
    },
    
    patientHistory: async (_, { id }, { dataSources }) => {
      try {
        // Fetch the version history of the patient
        const bundle = await dataSources.fhirAPI.getResourceHistory('Patient', id);
        return bundle.entry?.map(entry => entry.resource) || [];
      } catch (error) {
        console.error(`Error fetching patient history ${id}:`, error);
        throw new Error(`Failed to fetch patient history: ${error.message}`);
      }
    },
    
    // Additional resolvers...
  },
};
```

## Complete Example Implementation

This section provides a complete example of implementing a FHIR subgraph using Apollo Server.

### Project Setup

```bash
# Create a new directory for your FHIR subgraph
mkdir fhir-subgraph
cd fhir-subgraph

# Initialize a new Node.js project
npm init -y

# Install dependencies
npm install apollo-server graphql @apollo/federation apollo-datasource-rest dataloader dotenv
```

### FHIR Data Source

```typescript
// fhirAPI.js
const { RESTDataSource } = require('apollo-datasource-rest');
const DataLoader = require('dataloader');

class FHIRAPI extends RESTDataSource {
  constructor() {
    super();
    this.baseURL = process.env.FHIR_SERVER_URL || 'http://localhost:8080/fhir/';
    this.loaders = {};
  }

  // Initialize with context
  initialize(config) {
    super.initialize(config);
    // Add auth headers if available in context
    if (config.context.token) {
      this.token = config.context.token;
    }
  }

  // Add auth headers to requests
  willSendRequest(request) {
    if (this.token) {
      request.headers.set('Authorization', `Bearer ${this.token}`);
    }
  }

  // Get a resource by ID
  async getResource(resourceType, id) {
    try {
      return await this.get(`${resourceType}/${id}`);
    } catch (error) {
      console.error(`Error fetching ${resourceType}/${id}:`, error);
      throw error;
    }
  }

  // Get a specific version of a resource
  async getResourceVersion(resourceType, id, version) {
    try {
      return await this.get(`${resourceType}/${id}/_history/${version}`);
    } catch (error) {
      console.error(`Error fetching ${resourceType}/${id}/_history/${version}:`, error);
      throw error;
    }
  }

  // Get the version history of a resource
  async getResourceHistory(resourceType, id) {
    try {
      return await this.get(`${resourceType}/${id}/_history`);
    } catch (error) {
      console.error(`Error fetching history for ${resourceType}/${id}:`, error);
      throw error;
    }
  }

  // Search for resources
  async searchResources(resourceType, searchParams) {
    try {
      const params = searchParams instanceof URLSearchParams 
        ? searchParams.toString() 
        : new URLSearchParams(searchParams).toString();
      
      return await this.get(`${resourceType}?${params}`);
    } catch (error) {
      console.error(`Error searching ${resourceType}:`, error);
      throw error;
    }
  }

  // Get or create a loader for a specific resource type
  getLoader(resourceType) {
    if (!this.loaders[resourceType]) {
      this.loaders[resourceType] = new DataLoader(async (ids) => {
        const uniqueIds = [...new Set(ids)];
        
        const searchParams = new URLSearchParams();
        searchParams.append('_id', uniqueIds.join(','));
        searchParams.append('_count', uniqueIds.length.toString());
        
        const bundle = await this.searchResources(resourceType, searchParams);
        const resources = bundle.entry?.map(entry => entry.resource) || [];
        
        const resourceMap = resources.reduce((map, resource) => {
          map[resource.id] = resource;
          return map;
        }, {});
        
        return ids.map(id => resourceMap[id] || null);
      });
    }
    
    return this.loaders[resourceType];
  }

  // Resolve a reference string to a resource
  async resolveReference(reference) {
    if (!reference) return null;
    
    const parts = reference.split('/');
    if (parts.length !== 2) return null;
    
    const [resourceType, id] = parts;
    
    return this.getLoader(resourceType).load(id);
  }
}

module.exports = FHIRAPI;
```

### Server Setup

```typescript
// index.js
require('dotenv').config();
const { ApolloServer } = require('apollo-server');
const { buildFederatedSchema } = require('@apollo/federation');

const typeDefs = require('./schema');
const resolvers = require('./resolvers');
const FHIRAPI = require('./fhirAPI');

const server = new ApolloServer({
  schema: buildFederatedSchema([{ typeDefs, resolvers }]),
  dataSources: () => ({
    fhirAPI: new FHIRAPI(),
  }),
  context: ({ req }) => {
    // Extract auth token from request headers
    const token = req.headers.authorization || '';
    return { token };
  },
});

server.listen({ port: process.env.PORT || 4002 }).then(({ url }) => {
  console.log(`ud83dude80 FHIR subgraph ready at ${url}`);
});
```

## Conclusion

Implementing a FHIR subgraph allows you to expose your healthcare data through a powerful GraphQL API while maintaining compatibility with FHIR standards. By carefully mapping FHIR resources to GraphQL types, handling search parameters, managing resource references, and supporting versioning, you can create a flexible and performant API that meets the needs of modern healthcare applications.

As you implement your FHIR subgraph, remember to:

1. Create a clear mapping between FHIR resources and GraphQL types
2. Implement custom scalars for FHIR-specific data types
3. Support FHIR search parameters as GraphQL arguments
4. Optimize reference resolution with batching and caching
5. Provide version-specific access to resources

With these principles in mind, your FHIR subgraph will provide a seamless GraphQL interface to your healthcare data.
