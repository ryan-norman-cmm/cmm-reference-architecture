# GraphQL vs. REST Comparison

## Introduction

When building modern healthcare APIs, organizations must choose between different architectural approaches. This guide compares GraphQL and REST, the two dominant API paradigms, highlighting their differences in architecture, performance, developer experience, and implementation complexity. Understanding these differences helps teams make informed decisions about which approach best suits their specific healthcare integration needs.

### Quick Start

1. Review the architectural differences between GraphQL and REST
2. Understand the performance considerations for each approach
3. Evaluate the developer experience benefits of GraphQL vs. REST
4. Consider the implementation complexity trade-offs
5. Determine which approach aligns best with your organization's needs

### Related Components

- [Federated GraphQL Benefits Overview](benefits-overview.md): Explore the advantages of GraphQL
- [Federated Graph API Setup Guide](setup-guide.md): Configure your GraphQL environment
- [Creating Subgraphs](../02-core-functionality/creating-subgraphs.md): Implement domain-specific GraphQL services
- [FHIR Subgraph Implementation](../02-core-functionality/fhir-subgraph.md): Expose FHIR resources through GraphQL

## Architectural Differences

GraphQL and REST represent fundamentally different approaches to API design, each with distinct architectural characteristics.

### Resource vs. Query-Based

The most fundamental difference between REST and GraphQL is their approach to data access.

| Aspect | REST | GraphQL | Healthcare Implication |
|--------|------|---------|------------------------|
| Primary abstraction | Resources with fixed endpoints | Queries with flexible data selection | GraphQL allows precise selection of patient data fields |
| Endpoint structure | Multiple endpoints per domain | Single endpoint for all operations | REST requires multiple calls to assemble a complete patient record |
| Data fetching | Server determines response shape | Client specifies exact data needed | GraphQL reduces overfetching in bandwidth-constrained settings |
| Versioning | Explicit versioning (v1, v2) | Schema evolution without versions | GraphQL simplifies API maintenance in rapidly evolving healthcare systems |

### Request/Response Model

```http
# REST: Multiple requests needed to get patient and related data
# Request 1: Get patient
GET /patients/123 HTTP/1.1
Host: api.healthcare.example.com
Authorization: Bearer token123

# Request 2: Get patient's medications
GET /patients/123/medications HTTP/1.1
Host: api.healthcare.example.com
Authorization: Bearer token123

# Request 3: Get patient's recent lab results
GET /patients/123/observations?category=laboratory&_count=10 HTTP/1.1
Host: api.healthcare.example.com
Authorization: Bearer token123
```

```graphql
# GraphQL: Single request gets exactly what's needed
POST /graphql HTTP/1.1
Host: api.healthcare.example.com
Authorization: Bearer token123
Content-Type: application/json

{
  "query": "
    query GetPatientWithMedsAndLabs($id: ID!) {
      patient(id: $id) {
        id
        name { given family }
        birthDate
        medications {
          medicationReference { display }
          dosageInstruction { text }
          status
        }
        recentLabResults: observations(category: \"laboratory\", count: 10) {
          code { coding { display } }
          valueQuantity { value unit }
          effectiveDateTime
          status
        }
      }
    }
  ",
  "variables": {
    "id": "123"
  }
}
```

## Performance Considerations

Performance characteristics differ significantly between GraphQL and REST, with important implications for healthcare applications.

### Network Efficiency

| Aspect | REST | GraphQL | Healthcare Implication |
|--------|------|---------|------------------------|
| Number of requests | Multiple requests for related data | Single request for all needed data | GraphQL reduces latency for complex healthcare workflows |
| Data transfer | Potential overfetching or underfetching | Precise data selection | GraphQL optimizes bandwidth for mobile health applications |
| Caching | HTTP-level caching (simple) | Application-level caching (complex) | REST's simpler caching may benefit public health resources |

### Query Complexity

GraphQL provides flexibility but introduces potential performance challenges with complex queries.

```graphql
# Example: A complex GraphQL query that could impact performance
query ComplexPatientQuery($patientId: ID!) {
  patient(id: $patientId) {
    id
    name { given family }
    # First level of nesting
    careTeam {
      id
      status
      # Second level of nesting
      participants {
        role { coding { display } }
        member {
          ... on Practitioner {
            id
            name { given family }
            # Third level of nesting
            qualifications {
              code { coding { display } }
              period { start end }
              issuer { display }
            }
          }
        }
      }
    }
    # Another branch with deep nesting
    encounters {
      id
      status
      class { display }
      # Nested data
      diagnoses {
        condition {
          id
          code { coding { display } }
          # More nesting
          evidence {
            code { coding { display } }
            detail { reference display }
          }
        }
      }
    }
  }
}
```

### Performance Optimization Strategies

| Strategy | REST Approach | GraphQL Approach | Healthcare Example |
|----------|--------------|------------------|--------------------|
| Limiting data | `_elements` parameter in FHIR | Field selection in query | Retrieving only vital signs from patient record |
| Pagination | `_count` and `_offset` parameters | `first`/`after` or `limit`/`offset` arguments | Paging through medication history |
| Caching | HTTP cache headers | Apollo Cache or Relay Store | Caching reference data like code systems |
| Rate limiting | Per endpoint limits | Query complexity analysis | Preventing overload from clinical systems |

## Developer Experience

The developer experience differs significantly between GraphQL and REST, affecting productivity and code quality.

### Type Safety and Tooling

GraphQL provides superior type safety and developer tooling compared to REST.

```typescript
// REST: No built-in type safety
interface Patient {
  id: string;
  name?: Array<{
    given?: string[];
    family?: string;
  }>;
  birthDate?: string;
  // Types must be manually maintained
}

async function getPatient(id: string): Promise<Patient> {
  const response = await fetch(`/patients/${id}`);
  if (!response.ok) throw new Error('Failed to fetch patient');
  return response.json();
}

// No guarantee that the returned data matches the interface
```

```typescript
// GraphQL: Automatic type generation from schema
import { gql, useQuery } from '@apollo/client';
import { GetPatient, GetPatientVariables } from './__generated__/GetPatient';

const GET_PATIENT = gql`
  query GetPatient($id: ID!) {
    patient(id: $id) {
      id
      name {
        given
        family
      }
      birthDate
    }
  }
`;

function PatientComponent({ patientId }: { patientId: string }) {
  // Types are automatically generated and guaranteed to match the schema
  const { loading, error, data } = useQuery<GetPatient, GetPatientVariables>(
    GET_PATIENT,
    { variables: { id: patientId } }
  );
  
  // Type-safe access to data
  return <div>{data?.patient?.name?.[0]?.family}</div>;
}
```

### Documentation and Discoverability

| Aspect | REST | GraphQL | Healthcare Implication |
|--------|------|---------|------------------------|
| API documentation | Separate documentation (Swagger/OpenAPI) | Introspection and built-in documentation | GraphQL simplifies onboarding for healthcare integrators |
| Schema validation | Custom validation logic | Built-in schema validation | GraphQL ensures data integrity for clinical information |
| Discoverability | Limited without documentation | Interactive exploration (GraphiQL/Playground) | GraphQL facilitates exploration of complex healthcare data models |

### Frontend Development

GraphQL significantly improves the frontend development experience, especially for healthcare applications with complex data requirements.

```jsx
// REST: Multiple requests and data transformation
function PatientDashboard({ patientId }) {
  const [patient, setPatient] = useState(null);
  const [medications, setMedications] = useState([]);
  const [allergies, setAllergies] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  
  useEffect(() => {
    setLoading(true);
    // Multiple fetch requests
    Promise.all([
      fetch(`/patients/${patientId}`).then(res => res.json()),
      fetch(`/patients/${patientId}/medications`).then(res => res.json()),
      fetch(`/patients/${patientId}/allergies`).then(res => res.json())
    ])
    .then(([patientData, medicationsData, allergiesData]) => {
      setPatient(patientData);
      setMedications(medicationsData.entry?.map(e => e.resource) || []);
      setAllergies(allergiesData.entry?.map(e => e.resource) || []);
      setLoading(false);
    })
    .catch(err => {
      setError(err);
      setLoading(false);
    });
  }, [patientId]);
  
  // Component rendering with multiple data sources
}
```

```jsx
// GraphQL: Single request with precise data selection
function PatientDashboard({ patientId }) {
  const { loading, error, data } = useQuery(gql`
    query PatientDashboard($id: ID!) {
      patient(id: $id) {
        id
        name { given family }
        birthDate
        medications {
          medicationReference { display }
          dosageInstruction { text }
          status
        }
        allergies {
          substance { coding { display } }
          manifestation { coding { display } }
          severity
        }
      }
    }
  `, { variables: { id: patientId } });
  
  // Single data source with exactly the needed structure
}
```

## Implementation Complexity

Implementing and maintaining GraphQL and REST APIs involve different complexity trade-offs.

### Server Implementation

| Aspect | REST | GraphQL | Healthcare Implication |
|--------|------|---------|------------------------|
| Initial setup | Simpler, well-established patterns | More complex, newer paradigm | REST may be faster to implement for simple healthcare interfaces |
| Backend complexity | Multiple endpoints with fixed responses | Single endpoint with flexible resolvers | GraphQL requires more initial design for complex healthcare domains |
| Error handling | Standard HTTP status codes | Custom error handling in payload | REST's standard error codes align with healthcare system expectations |
| Authorization | Resource-level permissions | Field-level permissions | GraphQL enables more granular privacy controls for health data |

### Scaling and Maintenance

Long-term maintenance considerations differ significantly between the two approaches.

| Aspect | REST | GraphQL | Healthcare Implication |
|--------|------|---------|------------------------|
| API evolution | Versioning or breaking changes | Non-breaking schema evolution | GraphQL reduces disruption when adding new healthcare data elements |
| Team scaling | Clear ownership by resource | Potential schema conflicts | REST may be simpler for organizations with strict regulatory boundaries |
| Performance monitoring | Standard HTTP metrics | Custom resolver timing | GraphQL requires more sophisticated monitoring for healthcare SLAs |
| Infrastructure | Standard web servers and caching | Specialized GraphQL servers | REST leverages existing healthcare infrastructure investments |

## Decision Framework

When deciding between GraphQL and REST for healthcare applications, consider these factors:

### Choose REST When:

- You have simple, resource-oriented data requirements
- HTTP caching is critical for performance
- You need maximum compatibility with legacy systems
- Your team has limited experience with newer technologies
- You have clear resource boundaries that align with REST principles

### Choose GraphQL When:

- You need to aggregate data from multiple sources
- Clients have diverse and evolving data requirements
- Network efficiency is critical (mobile applications, rural healthcare)
- You want to enable rapid frontend development
- You need a unified API across multiple healthcare domains
- You're implementing a federated architecture with domain-specific teams

## Hybrid Approaches

Many healthcare organizations implement hybrid approaches that leverage the strengths of both paradigms.

### REST for FHIR, GraphQL for Applications

A common pattern is to maintain FHIR-compliant REST APIs for interoperability while adding a GraphQL layer for application development.

```typescript
// Example: GraphQL resolver that wraps a FHIR REST API
const resolvers = {
  Query: {
    patient: async (_, { id }, { dataSources }) => {
      // Use RESTDataSource to call FHIR API
      return dataSources.fhirApi.getResource('Patient', id);
    },
    searchPatients: async (_, { name, birthDate }, { dataSources }) => {
      // Construct FHIR search parameters
      const params = new URLSearchParams();
      if (name) params.append('name', name);
      if (birthDate) params.append('birthdate', birthDate);
      
      // Call FHIR search API
      const bundle = await dataSources.fhirApi.searchResources('Patient', params);
      return bundle.entry?.map(e => e.resource) || [];
    }
  },
  Patient: {
    // Resolve related resources
    medications: async (patient, _, { dataSources }) => {
      const bundle = await dataSources.fhirApi.searchResources('MedicationRequest', 
        new URLSearchParams({ 'subject': `Patient/${patient.id}` }));
      return bundle.entry?.map(e => e.resource) || [];
    },
    // Additional resolvers for other related data
  }
};
```

## Conclusion

Both GraphQL and REST have their place in modern healthcare architectures. REST excels in standardization and simplicity, while GraphQL offers flexibility and efficiency. Many organizations find that a thoughtful combination of both approaches provides the best solution for complex healthcare environments.

When evaluating these technologies for your organization, consider your specific use cases, team expertise, and long-term maintenance requirements. The right choice depends on your particular context and constraints.
