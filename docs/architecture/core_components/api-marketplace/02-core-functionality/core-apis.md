# API Marketplace Core APIs

## Introduction

This document describes the core APIs provided by the API Marketplace component of the CMM Technology Platform. These APIs enable the registration, discovery, management, and governance of APIs across the healthcare organization. This document focuses on the API interfaces and their usage, rather than implementation details.

## API Overview

The API Marketplace exposes the following core APIs:

| API Group | Description | Primary Consumers |
|-----------|-------------|-------------------|
| Catalog API | APIs for searching and browsing the API catalog | API consumers, developers, architects |
| Registration API | APIs for registering and managing APIs | API providers, development teams |
| Governance API | APIs for managing API governance policies | Governance teams, compliance officers |
| Analytics API | APIs for accessing API usage analytics | API providers, operations teams |
| Administration API | APIs for administering the API Marketplace | Platform administrators |

## Authentication and Authorization

All API Marketplace APIs require authentication and authorization:

- **Authentication**: OAuth 2.0 / OpenID Connect with JWT tokens
- **Authorization**: Role-based access control (RBAC) with fine-grained permissions

### Authentication Example

```http
POST /api/v1/auth/token
Content-Type: application/x-www-form-urlencoded

grant_type=client_credentials&client_id=your-client-id&client_secret=your-client-secret&scope=api:read
```

Response:

```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "expires_in": 3600,
  "scope": "api:read"
}
```

Using the token:

```http
GET /api/v1/apis
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
```

## Catalog API

The Catalog API enables discovery and exploration of APIs in the marketplace.

### List APIs

Retrieve a paginated list of APIs with optional filtering and sorting.

```http
GET /api/v1/apis?query=patient&category=Clinical&status=active&page=1&limit=10&sort=name
Authorization: Bearer {token}
```

Response:

```json
{
  "items": [
    {
      "id": "api-123",
      "name": "Patient Demographics API",
      "description": "Provides access to patient demographic information",
      "version": "1.2.3",
      "owner": "Clinical Data Team",
      "status": "active",
      "tags": ["patient", "demographics", "clinical"],
      "categories": ["Clinical", "Patient"],
      "createdAt": "2023-01-15T12:30:45Z",
      "updatedAt": "2023-03-20T09:15:30Z"
    },
    // Additional APIs...
  ],
  "pagination": {
    "page": 1,
    "limit": 10,
    "totalItems": 42,
    "totalPages": 5
  }
}
```

### Get API Details

Retrieve detailed information about a specific API.

```http
GET /api/v1/apis/{apiId}
Authorization: Bearer {token}
```

Response:

```json
{
  "id": "api-123",
  "name": "Patient Demographics API",
  "description": "Provides access to patient demographic information",
  "version": "1.2.3",
  "owner": "Clinical Data Team",
  "contactEmail": "api-support@example.com",
  "status": "active",
  "tags": ["patient", "demographics", "clinical"],
  "categories": ["Clinical", "Patient"],
  "documentationUrl": "https://docs.example.com/patient-api",
  "termsOfServiceUrl": "https://terms.example.com/api-terms",
  "license": "Apache 2.0",
  "specificationFormat": "openapi",
  "createdAt": "2023-01-15T12:30:45Z",
  "updatedAt": "2023-03-20T09:15:30Z",
  "metrics": {
    "callVolume30Days": 15420,
    "averageResponseTimeMs": 125,
    "errorRate30Days": 0.5,
    "consumers": 8
  },
  "healthStatus": "healthy"
}
```

### Get API Specification

Retrieve the API specification (OpenAPI, GraphQL Schema, etc.).

```http
GET /api/v1/apis/{apiId}/specification
Authorization: Bearer {token}
Accept: application/json
```

Response:

```json
{
  "format": "openapi",
  "version": "3.0.0",
  "content": {
    "openapi": "3.0.0",
    "info": {
      "title": "Patient Demographics API",
      "version": "1.2.3",
      "description": "Provides access to patient demographic information"
    },
    "paths": {
      "/patients": {
        "get": {
          "summary": "Search for patients",
          "parameters": [
            {
              "name": "name",
              "in": "query",
              "schema": { "type": "string" }
            }
          ],
          "responses": {
            "200": {
              "description": "Successful response",
              "content": {
                "application/json": {
                  "schema": { "$ref": "#/components/schemas/PatientList" }
                }
              }
            }
          }
        }
      }
    },
    "components": {
      "schemas": {
        "PatientList": {
          "type": "object",
          "properties": {
            "items": {
              "type": "array",
              "items": { "$ref": "#/components/schemas/Patient" }
            }
          }
        },
        "Patient": {
          "type": "object",
          "properties": {
            "id": { "type": "string" },
            "name": { "type": "string" },
            "birthDate": { "type": "string", "format": "date" }
          }
        }
      }
    }
  }
}
```

## Registration API

The Registration API enables API providers to register and manage their APIs.

### Register API

Register a new API in the marketplace.

```http
POST /api/v1/apis
Content-Type: application/json
Authorization: Bearer {token}

{
  "name": "Patient Demographics API",
  "description": "Provides access to patient demographic information",
  "version": "1.2.3",
  "owner": "Clinical Data Team",
  "contactEmail": "api-support@example.com",
  "tags": ["patient", "demographics", "clinical"],
  "categories": ["Clinical", "Patient"],
  "documentationUrl": "https://docs.example.com/patient-api",
  "termsOfServiceUrl": "https://terms.example.com/api-terms",
  "license": "Apache 2.0",
  "specification": {
    "format": "openapi",
    "content": "...OpenAPI specification content..."
  }
}
```

Response:

```json
{
  "id": "api-123",
  "name": "Patient Demographics API",
  "description": "Provides access to patient demographic information",
  "version": "1.2.3",
  "status": "pending_approval",
  "createdAt": "2023-05-05T14:30:00Z",
  "validationResults": {
    "valid": true,
    "warnings": [
      {
        "severity": "warning",
        "message": "Missing example for /patients endpoint",
        "location": "paths./patients.get"
      }
    ]
  }
}
```

### Update API

Update an existing API in the marketplace.

```http
PUT /api/v1/apis/{apiId}
Content-Type: application/json
Authorization: Bearer {token}

{
  "name": "Patient Demographics API",
  "description": "Updated description for the Patient Demographics API",
  "version": "1.2.4",
  "owner": "Clinical Data Team",
  "contactEmail": "api-support@example.com",
  "tags": ["patient", "demographics", "clinical", "updated"],
  "categories": ["Clinical", "Patient"],
  "documentationUrl": "https://docs.example.com/patient-api",
  "termsOfServiceUrl": "https://terms.example.com/api-terms",
  "license": "Apache 2.0",
  "specification": {
    "format": "openapi",
    "content": "...Updated OpenAPI specification content..."
  }
}
```

Response:

```json
{
  "id": "api-123",
  "name": "Patient Demographics API",
  "description": "Updated description for the Patient Demographics API",
  "version": "1.2.4",
  "status": "pending_approval",
  "createdAt": "2023-01-15T12:30:45Z",
  "updatedAt": "2023-05-05T14:45:00Z",
  "validationResults": {
    "valid": true,
    "warnings": []
  }
}
```

### Delete API

Delete an API from the marketplace.

```http
DELETE /api/v1/apis/{apiId}
Authorization: Bearer {token}
```

Response:

```http
HTTP/1.1 204 No Content
```

## Governance API

The Governance API enables management of API governance policies and processes.

### List Policies

Retrieve a list of governance policies.

```http
GET /api/v1/policies
Authorization: Bearer {token}
```

Response:

```json
{
  "items": [
    {
      "id": "policy-1",
      "name": "API Naming Convention",
      "description": "Enforces standard naming conventions for APIs",
      "type": "naming",
      "status": "active",
      "severity": "warning",
      "createdAt": "2023-01-10T09:00:00Z",
      "updatedAt": "2023-01-10T09:00:00Z"
    },
    {
      "id": "policy-2",
      "name": "Security Requirements",
      "description": "Enforces security requirements for all APIs",
      "type": "security",
      "status": "active",
      "severity": "error",
      "createdAt": "2023-01-10T09:15:00Z",
      "updatedAt": "2023-03-15T11:30:00Z"
    }
  ]
}
```

### Approve API

Approve an API for publication.

```http
POST /api/v1/apis/{apiId}/approve
Content-Type: application/json
Authorization: Bearer {token}

{
  "comments": "API meets all governance requirements",
  "approverRole": "governance-officer"
}
```

Response:

```json
{
  "id": "api-123",
  "name": "Patient Demographics API",
  "status": "active",
  "approvalDetails": {
    "approvedAt": "2023-05-05T15:00:00Z",
    "approvedBy": "john.doe@example.com",
    "approverRole": "governance-officer",
    "comments": "API meets all governance requirements"
  }
}
```

### Reject API

Reject an API submission.

```http
POST /api/v1/apis/{apiId}/reject
Content-Type: application/json
Authorization: Bearer {token}

{
  "comments": "API does not meet security requirements",
  "rejectionReasons": ["security-requirements", "documentation-incomplete"],
  "approverRole": "security-officer"
}
```

Response:

```json
{
  "id": "api-123",
  "name": "Patient Demographics API",
  "status": "rejected",
  "rejectionDetails": {
    "rejectedAt": "2023-05-05T15:15:00Z",
    "rejectedBy": "jane.smith@example.com",
    "approverRole": "security-officer",
    "comments": "API does not meet security requirements",
    "rejectionReasons": ["security-requirements", "documentation-incomplete"]
  }
}
```

## Analytics API

The Analytics API provides access to API usage and performance metrics.

### Get API Metrics

Retrieve usage metrics for a specific API.

```http
GET /api/v1/apis/{apiId}/metrics?period=30d
Authorization: Bearer {token}
```

Response:

```json
{
  "apiId": "api-123",
  "name": "Patient Demographics API",
  "period": "30d",
  "startDate": "2023-04-05T00:00:00Z",
  "endDate": "2023-05-05T00:00:00Z",
  "metrics": {
    "callVolume": 15420,
    "uniqueConsumers": 8,
    "averageResponseTimeMs": 125,
    "p95ResponseTimeMs": 250,
    "p99ResponseTimeMs": 450,
    "errorRate": 0.5,
    "errorCount": 77,
    "statusCodes": {
      "200": 14500,
      "400": 50,
      "401": 15,
      "403": 5,
      "500": 7
    }
  },
  "dailyTrends": [
    {
      "date": "2023-04-05",
      "callVolume": 450,
      "averageResponseTimeMs": 120,
      "errorRate": 0.4
    },
    // Additional daily data...
  ]
}
```

### Get Consumer Metrics

Retrieve metrics for API consumers.

```http
GET /api/v1/analytics/consumers?period=30d&top=5
Authorization: Bearer {token}
```

Response:

```json
{
  "period": "30d",
  "startDate": "2023-04-05T00:00:00Z",
  "endDate": "2023-05-05T00:00:00Z",
  "topConsumers": [
    {
      "consumerId": "consumer-1",
      "name": "Patient Portal",
      "callVolume": 5200,
      "apisUsed": 3,
      "averageResponseTimeMs": 115,
      "errorRate": 0.3
    },
    // Additional consumers...
  ]
}
```

## Administration API

The Administration API enables management of the API Marketplace platform.

### Manage Users

Create a new user in the API Marketplace.

```http
POST /api/v1/admin/users
Content-Type: application/json
Authorization: Bearer {token}

{
  "email": "new.user@example.com",
  "firstName": "New",
  "lastName": "User",
  "roles": ["api-consumer", "api-provider"],
  "department": "Clinical Systems",
  "sendInvitation": true
}
```

Response:

```json
{
  "id": "user-456",
  "email": "new.user@example.com",
  "firstName": "New",
  "lastName": "User",
  "roles": ["api-consumer", "api-provider"],
  "department": "Clinical Systems",
  "status": "invited",
  "createdAt": "2023-05-05T16:00:00Z"
}
```

### Manage Categories

Create a new API category.

```http
POST /api/v1/admin/categories
Content-Type: application/json
Authorization: Bearer {token}

{
  "name": "Billing",
  "description": "APIs related to billing and claims processing",
  "parentCategory": "Financial"
}
```

Response:

```json
{
  "id": "category-789",
  "name": "Billing",
  "description": "APIs related to billing and claims processing",
  "parentCategory": "Financial",
  "path": "Financial/Billing",
  "createdAt": "2023-05-05T16:15:00Z"
}
```

## Healthcare-Specific APIs

### FHIR API Registration

Register a FHIR API with additional FHIR-specific metadata.

```http
POST /api/v1/apis/fhir
Content-Type: application/json
Authorization: Bearer {token}

{
  "name": "Patient FHIR API",
  "description": "FHIR-compliant API for patient resources",
  "version": "1.0.0",
  "owner": "Clinical Data Team",
  "contactEmail": "fhir-support@example.com",
  "tags": ["fhir", "patient", "clinical"],
  "categories": ["Clinical", "FHIR"],
  "fhirVersion": "4.0.1",
  "supportedResources": ["Patient", "Observation", "Condition"],
  "implementationGuides": ["hl7.fhir.us.core|3.1.1"],
  "capabilityStatement": {
    "format": "json",
    "content": "...FHIR CapabilityStatement content..."
  }
}
```

Response:

```json
{
  "id": "api-fhir-123",
  "name": "Patient FHIR API",
  "description": "FHIR-compliant API for patient resources",
  "version": "1.0.0",
  "status": "pending_approval",
  "fhirVersion": "4.0.1",
  "supportedResources": ["Patient", "Observation", "Condition"],
  "implementationGuides": ["hl7.fhir.us.core|3.1.1"],
  "createdAt": "2023-05-05T16:30:00Z",
  "validationResults": {
    "valid": true,
    "fhirValidation": {
      "valid": true,
      "implementationGuideConformance": true,
      "warnings": []
    }
  }
}
```

## API Client SDKs

The API Marketplace provides client SDKs for common programming languages to simplify integration:

### TypeScript/JavaScript SDK Example

```typescript
import { ApiMarketplaceClient } from '@cmm/api-marketplace-client';

async function searchApis() {
  const client = new ApiMarketplaceClient({
    baseUrl: 'https://api-marketplace.example.com',
    apiKey: 'your-api-key'
  });
  
  // Search for APIs
  const searchResults = await client.apis.search({
    query: 'patient',
    categories: ['Clinical'],
    status: 'active'
  });
  
  console.log(`Found ${searchResults.items.length} APIs`);
  
  // Get API details
  if (searchResults.items.length > 0) {
    const apiDetails = await client.apis.getDetails(searchResults.items[0].id);
    console.log('API Details:', apiDetails);
  }
}

searchApis().catch(console.error);
```

## API Versioning

The API Marketplace APIs follow semantic versioning principles:

- **URI Path Versioning**: Major version in the URI path (e.g., `/api/v1/apis`)
- **Header Versioning**: Minor and patch versions via the `API-Version` header

For detailed information on API versioning, see the [Versioning Policy](../04-governance-compliance/versioning-policy.md).

## Error Handling

All APIs use standard HTTP status codes and return consistent error responses:

```json
{
  "error": {
    "code": "validation_error",
    "message": "The request contains invalid parameters",
    "details": [
      {
        "field": "name",
        "message": "Name is required"
      },
      {
        "field": "contactEmail",
        "message": "Invalid email format"
      }
    ],
    "requestId": "req-abc-123",
    "timestamp": "2023-05-05T17:00:00Z"
  }
}
```

## Rate Limiting

All APIs implement rate limiting to prevent abuse:

```http
HTTP/1.1 429 Too Many Requests
Content-Type: application/json
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1683306000

{
  "error": {
    "code": "rate_limit_exceeded",
    "message": "Rate limit exceeded. Try again in 60 seconds.",
    "requestId": "req-abc-456",
    "timestamp": "2023-05-05T17:15:00Z"
  }
}
```

## Related Documentation

- [API Registration](./api-registration.md)
- [API Discovery](./api-discovery.md)
- [Data Model](./data-model.md)
- [Integration Points](./integration-points.md)
- [Versioning Policy](../04-governance-compliance/versioning-policy.md)
