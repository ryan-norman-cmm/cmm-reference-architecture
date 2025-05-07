# Federated Graph API Core APIs

## Introduction
The Federated Graph API provides a unified GraphQL interface for interacting with all platform services. This document details the core APIs and endpoints that developers can use to query and mutate data across the federated graph.

## API Endpoints

| Endpoint | Description |
|----------|-------------|
| `/graphql` | Primary GraphQL endpoint for queries and mutations |
| `/graphql/health` | Health check endpoint for monitoring |
| `/graphql/metrics` | Prometheus metrics endpoint |
| `/graphql/schema` | SDL representation of the current supergraph schema |
| `/graphql/subscriptions` | WebSocket endpoint for real-time subscriptions |

## Authentication & Authorization

The Federated Graph API implements multiple authentication methods:

- **OAuth 2.0**: JWT-based authentication with the identity provider
- **API Keys**: For service-to-service communication
- **Session Cookies**: For web application authentication

Authorization is enforced at multiple levels:

1. **Gateway-level authorization**: Validates access to the GraphQL API itself
2. **Operation-level authorization**: Controls access to specific queries, mutations, and subscriptions
3. **Field-level authorization**: Granular control over specific data fields
4. **Entity-level authorization**: Access control for specific entities based on user context

Example authorization configuration:

```yaml
# Apollo Router Authorization Configuration
authz:
  directives:
    enabled: true
    requires:
      types:
        PatientRecord:
          __default: PATIENT_READ
          medications: MEDICATION_READ
          appointments: APPOINTMENT_READ
        Medication:
          __default: MEDICATION_READ
        Appointment:
          __default: APPOINTMENT_READ
```

## Example Requests & Responses

### Basic Query Example

```typescript
// Client-side query
import { gql, useQuery } from '@apollo/client';

const GET_PATIENT = gql`
  query GetPatient($patientId: ID!) {
    patient(id: $patientId) {
      id
      name {
        given
        family
      }
      birthDate
      gender
      activeConditions {
        id
        code {
          coding {
            system
            code
            display
          }
        }
        onsetDateTime
      }
    }
  }
`;

function PatientSummary({ patientId }) {
  const { loading, error, data } = useQuery(GET_PATIENT, {
    variables: { patientId },
  });

  if (loading) return <p>Loading...</p>;
  if (error) return <p>Error: {error.message}</p>;

  return (
    <div>
      <h2>{data.patient.name.given} {data.patient.name.family}</h2>
      <p>Birth Date: {data.patient.birthDate}</p>
      <p>Gender: {data.patient.gender}</p>
      <h3>Active Conditions</h3>
      <ul>
        {data.patient.activeConditions.map(condition => (
          <li key={condition.id}>
            {condition.code.coding[0].display} (since {condition.onsetDateTime})
          </li>
        ))}
      </ul>
    </div>
  );
}
```

### Mutation Example

```typescript
// Client-side mutation
import { gql, useMutation } from '@apollo/client';

const CREATE_APPOINTMENT = gql`
  mutation CreateAppointment($appointment: AppointmentInput!) {
    createAppointment(appointment: $appointment) {
      id
      status
      start
      end
      patientId
      practitionerId
      serviceType {
        coding {
          system
          code
          display
        }
      }
    }
  }
`;

function AppointmentForm() {
  const [createAppointment, { data, loading, error }] = useMutation(CREATE_APPOINTMENT);

  const handleSubmit = (formData) => {
    createAppointment({
      variables: {
        appointment: {
          patientId: formData.patientId,
          practitionerId: formData.practitionerId,
          start: formData.startTime,
          end: formData.endTime,
          serviceType: {
            coding: [{
              system: "http://terminology.hl7.org/CodeSystem/service-type",
              code: formData.serviceTypeCode,
              display: formData.serviceTypeDisplay
            }]
          }
        }
      }
    });
  };

  // Form implementation...
}
```

### Subscription Example

```typescript
// Client-side subscription
import { gql, useSubscription } from '@apollo/client';

const MEDICATION_UPDATES = gql`
  subscription MedicationUpdates($patientId: ID!) {
    medicationUpdates(patientId: $patientId) {
      type # CREATED, UPDATED, DELETED
      medication {
        id
        status
        medicationCodeableConcept {
          coding {
            system
            code
            display
          }
        }
        dosage {
          text
          timing {
            code {
              text
            }
          }
          doseAndRate {
            doseQuantity {
              value
              unit
            }
          }
        }
      }
    }
  }
`;

function MedicationUpdatesComponent({ patientId }) {
  const { data, loading, error } = useSubscription(MEDICATION_UPDATES, {
    variables: { patientId },
  });

  // Implementation to handle real-time updates...
}
```

## Error Handling

The Federated Graph API follows standard GraphQL error handling patterns, returning errors in the `errors` array of the response.

### Common Error Codes

| Error Code | Description | Troubleshooting |
|------------|-------------|-----------------|
| `UNAUTHENTICATED` | Invalid or missing authentication credentials | Check that valid authentication is provided in the request headers |
| `FORBIDDEN` | User doesn't have permission to access the requested resource | Verify that the user has the required roles/permissions |
| `BAD_USER_INPUT` | Invalid input provided in the request | Check the input variables against the schema requirements |
| `SUBGRAPH_UNAVAILABLE` | One or more subgraphs are unavailable | Check the status of the relevant subgraph services |
| `INTERNAL_SERVER_ERROR` | Unexpected server error | Check server logs for details and contact platform support |
| `OPERATION_COMPLEXITY_TOO_HIGH` | Query is too complex to execute | Simplify the query or request pagination/filtering |

Example error response:

```json
{
  "errors": [
    {
      "message": "Not authorized to access field 'medications' on type 'Patient'",
      "locations": [
        {
          "line": 5,
          "column": 5
        }
      ],
      "path": ["patient", "medications"],
      "extensions": {
        "code": "FORBIDDEN",
        "requiredPermission": "MEDICATION_READ"
      }
    }
  ],
  "data": {
    "patient": {
      "id": "patient-123",
      "name": {
        "given": "John",
        "family": "Doe"
      },
      "birthDate": "1970-01-01",
      "gender": "male",
      "medications": null
    }
  }
}
```

### Error Handling Best Practices

1. **Partial Results**: The Federated Graph API may return partial results with errors when some parts of a query fail but others succeed.
2. **Error Extensions**: Use the `extensions` field in errors to provide additional context.
3. **Client-Side Error Handling**: Implement proper error handling on the client side to gracefully handle errors.
4. **Retry Logic**: Implement retry logic for transient errors like network issues or service unavailability.

## Related Resources
- [Federated Graph API Key Concepts](../01-getting-started/key-concepts.md)
- [Federated Graph API Data Model](./data-model.md)
- [Advanced Use Cases](../03-advanced-patterns/advanced-use-cases.md)