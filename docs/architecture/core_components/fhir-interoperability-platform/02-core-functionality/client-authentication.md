# FHIR Client Authentication and Authorization

## Introduction

Securing access to healthcare data is a critical requirement for any FHIR implementation. This guide explains how to configure your Aidbox FHIR client with proper authentication and authorization mechanisms. It covers OAuth 2.0 authentication flows, scope configuration, and Role-Based Access Control (RBAC) to ensure secure access to FHIR resources.

### Quick Start

1. Register an OAuth client in Aidbox UI at `http://localhost:8888`
2. Configure your client application with appropriate authentication method:
   - Basic authentication for development
   - Client credentials for server-to-server communication
   - Authorization code flow for user context applications
3. Define appropriate scopes to limit access to necessary resources
4. Set up RBAC to control permissions based on user roles
5. Implement token refresh mechanisms for long-running applications

### Related Components

- [FHIR Server Setup Guide](fhir-server-setup-guide.md): Configure your Aidbox FHIR server
- [Accessing FHIR Resources](accessing-fhir-resources.md): Learn how to retrieve data securely
- [Security Architecture Decisions](fhir-security-decisions.md) (Coming Soon): Understand security implementation choices

## OAuth 2.0 Authentication

OAuth 2.0 is the recommended authentication protocol for FHIR clients in production environments. It provides secure delegated access to FHIR resources without sharing credentials.

### Setting Up OAuth Client in Aidbox

Before configuring your client, you need to register an OAuth client in Aidbox:

1. Access the Aidbox UI at `http://localhost:8888` (or your server URL)
2. Navigate to the "Access Control" section
3. Select "Clients" and click "Create"
4. Configure the client with the following settings:

```json
{
  "resourceType": "Client",
  "id": "example-client",
  "secret": "your-secure-client-secret",
  "grant_types": [
    "client_credentials",
    "authorization_code",
    "refresh_token"
  ],
  "auth": {
    "authorization_code": {
      "redirect_uri": "https://your-app.example.org/callback"
    }
  },
  "first_party": true
}
```

### Client Credentials Flow

The client credentials flow is suitable for server-to-server communication where a user context is not required:

```typescript
import { AidboxClient } from '@aidbox/sdk-r4';

const client = new AidboxClient({
  baseUrl: 'http://localhost:8888',
  auth: {
    type: 'client_credentials',
    client_id: 'example-client',
    client_secret: 'your-secure-client-secret',
    tokenUrl: 'http://localhost:8888/auth/token'
  }
});

// Use the client to access resources
async function fetchPatients() {
  try {
    const bundle = await client.search({
      resourceType: 'Patient',
      params: {
        _count: '10'
      }
    });
    return bundle;
  } catch (error) {
    console.error('Error fetching patients:', error);
    throw error;
  }
}
```

### Authorization Code Flow

The authorization code flow is appropriate for applications that need to access resources on behalf of a user:

```typescript
import { AidboxClient } from '@aidbox/sdk-r4';

// Step 1: Redirect the user to the authorization endpoint
function initiateLogin() {
  const authUrl = new URL('http://localhost:8888/auth/authorize');
  authUrl.searchParams.append('response_type', 'code');
  authUrl.searchParams.append('client_id', 'example-client');
  authUrl.searchParams.append('redirect_uri', 'https://your-app.example.org/callback');
  authUrl.searchParams.append('scope', 'user/*.read user/*.write');
  authUrl.searchParams.append('state', generateRandomState());
  
  window.location.href = authUrl.toString();
}

// Step 2: Handle the callback and exchange the code for tokens
async function handleCallback(code: string) {
  try {
    const tokenResponse = await fetch('http://localhost:8888/auth/token', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      body: new URLSearchParams({
        grant_type: 'authorization_code',
        code,
        client_id: 'example-client',
        client_secret: 'your-secure-client-secret',
        redirect_uri: 'https://your-app.example.org/callback'
      })
    });
    
    const tokenData = await tokenResponse.json();
    
    // Store tokens securely
    localStorage.setItem('access_token', tokenData.access_token);
    localStorage.setItem('refresh_token', tokenData.refresh_token);
    localStorage.setItem('token_expiry', (Date.now() + tokenData.expires_in * 1000).toString());
    
    // Initialize client with the access token
    initializeClient(tokenData.access_token);
  } catch (error) {
    console.error('Error exchanging code for tokens:', error);
    throw error;
  }
}

// Initialize the client with an access token
function initializeClient(accessToken: string) {
  const client = new AidboxClient({
    baseUrl: 'http://localhost:8888',
    auth: {
      type: 'bearer',
      token: accessToken
    }
  });
  
  return client;
}

// Refresh the access token when it expires
async function refreshAccessToken(refreshToken: string) {
  try {
    const tokenResponse = await fetch('http://localhost:8888/auth/token', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      body: new URLSearchParams({
        grant_type: 'refresh_token',
        refresh_token: refreshToken,
        client_id: 'example-client',
        client_secret: 'your-secure-client-secret'
      })
    });
    
    const tokenData = await tokenResponse.json();
    
    // Update stored tokens
    localStorage.setItem('access_token', tokenData.access_token);
    localStorage.setItem('refresh_token', tokenData.refresh_token || refreshToken);
    localStorage.setItem('token_expiry', (Date.now() + tokenData.expires_in * 1000).toString());
    
    return tokenData.access_token;
  } catch (error) {
    console.error('Error refreshing token:', error);
    throw error;
  }
}
```

## OAuth Scopes

OAuth scopes define the level of access granted to a client. Aidbox supports standard FHIR scopes as well as custom scopes.

### Standard FHIR Scopes

- `user/*.read`: Read access to all resources for the authenticated user
- `user/*.write`: Write access to all resources for the authenticated user
- `user/Patient.read`: Read access to Patient resources
- `user/Patient.write`: Write access to Patient resources
- `system/*.read`: Read access to all resources at the system level
- `system/*.write`: Write access to all resources at the system level

### Configuring Scopes in the Client

When requesting authorization, specify the scopes your application needs:

```typescript
function initiateLogin() {
  const authUrl = new URL('http://localhost:8888/auth/authorize');
  authUrl.searchParams.append('response_type', 'code');
  authUrl.searchParams.append('client_id', 'example-client');
  authUrl.searchParams.append('redirect_uri', 'https://your-app.example.org/callback');
  
  // Request specific scopes
  authUrl.searchParams.append('scope', 'user/Patient.read user/MedicationRequest.read user/Observation.read');
  
  authUrl.searchParams.append('state', generateRandomState());
  
  window.location.href = authUrl.toString();
}
```

### SMART on FHIR Scopes

For healthcare applications, SMART on FHIR defines additional scopes:

- `launch`: Indicates the app is launched from an EHR context
- `launch/patient`: Request permission to obtain the current patient context
- `launch/encounter`: Request permission to obtain the current encounter context
- `patient/*.read`: Read access to all resources for the current patient
- `offline_access`: Request a refresh token for offline access

```typescript
function initiateSMARTLogin() {
  const authUrl = new URL('http://localhost:8888/auth/authorize');
  authUrl.searchParams.append('response_type', 'code');
  authUrl.searchParams.append('client_id', 'example-client');
  authUrl.searchParams.append('redirect_uri', 'https://your-app.example.org/callback');
  
  // SMART on FHIR scopes
  authUrl.searchParams.append('scope', 'launch/patient patient/*.read offline_access');
  
  authUrl.searchParams.append('state', generateRandomState());
  authUrl.searchParams.append('aud', 'http://localhost:8888');
  
  window.location.href = authUrl.toString();
}
```

## Role-Based Access Control (RBAC)

Aidbox provides RBAC to control access to FHIR resources based on user roles.

### Defining Roles in Aidbox

Create roles in Aidbox with specific permissions:

```json
{
  "resourceType": "Role",
  "id": "practitioner-role",
  "name": "Practitioner",
  "description": "Role for healthcare practitioners",
  "policy": [
    {
      "engine": "allow",
      "resource_type": "Patient",
      "actions": ["read", "search"]
    },
    {
      "engine": "allow",
      "resource_type": "MedicationRequest",
      "actions": ["read", "search", "create", "update"]
    },
    {
      "engine": "allow",
      "resource_type": "Observation",
      "actions": ["read", "search", "create"]
    }
  ]
}
```

### Assigning Roles to Users

Assign roles to users in Aidbox:

```json
{
  "resourceType": "User",
  "id": "practitioner-1",
  "email": "doctor@example.org",
  "password": "hashed-password",
  "roles": ["practitioner-role"]
}
```

### Role-Based Client Configuration

When a user authenticates, the client will have the permissions assigned to their role:

```typescript
// After user authentication, the access token will contain the user's roles and permissions
const client = new AidboxClient({
  baseUrl: 'http://localhost:8888',
  auth: {
    type: 'bearer',
    token: userAccessToken // This token contains the user's roles and permissions
  }
});

// The client can now access resources according to the user's role permissions
async function createMedicationRequest() {
  try {
    // This will succeed if the user has the practitioner-role
    const medicationRequest = await client.create({
      resourceType: 'MedicationRequest',
      status: 'active',
      intent: 'order',
      subject: {
        reference: 'Patient/123'
      },
      medicationCodeableConcept: {
        coding: [
          {
            system: 'http://www.nlm.nih.gov/research/umls/rxnorm',
            code: '1234',
            display: 'Medication Name'
          }
        ]
      }
    });
    return medicationRequest;
  } catch (error) {
    // This will fail if the user doesn't have permission to create MedicationRequest resources
    console.error('Error creating medication request:', error);
    throw error;
  }
}
```

## Advanced Authorization Patterns

### Compartment-Based Access

Aidbox supports FHIR compartments, which restrict access to resources related to a specific patient or practitioner:

```json
{
  "resourceType": "AccessPolicy",
  "id": "patient-compartment",
  "engine": "allow",
  "link": ["Patient", "subject", "performer"],
  "resource_type": "*",
  "actions": ["read", "search"]
}
```

This policy allows access only to resources linked to the patient through the "subject" or "performer" references.

### JWT-Based Authorization

For more complex authorization scenarios, Aidbox supports JWT tokens with custom claims:

```typescript
// The JWT token contains claims about the user and their permissions
const client = new AidboxClient({
  baseUrl: 'http://localhost:8888',
  auth: {
    type: 'bearer',
    token: jwtToken // This JWT contains custom claims about the user's permissions
  }
});

// Aidbox will validate the JWT and enforce access based on its claims
```

## Best Practices

1. **Use HTTPS**: Always use HTTPS in production environments to protect tokens and data in transit.

2. **Secure Token Storage**: Store tokens securely, preferably in memory for single-page applications or in secure HTTP-only cookies for server-rendered applications.

3. **Implement Token Refresh**: Automatically refresh access tokens before they expire to maintain a seamless user experience.

4. **Request Minimal Scopes**: Only request the scopes your application needs to follow the principle of least privilege.

5. **Validate Tokens**: Implement token validation on your server to prevent token forgery.

6. **Implement Logout**: Provide a way for users to log out, which should revoke tokens on the server.

## Troubleshooting

### Common Authentication Issues

1. **Invalid Client**: Ensure your client_id and client_secret are correct.

2. **Invalid Redirect URI**: The redirect_uri must exactly match the one registered with the client.

3. **Invalid Scope**: Ensure the requested scopes are allowed for your client.

4. **Token Expired**: Implement proper token refresh logic to handle expired tokens.

### Debugging Authentication

```typescript
// Add logging to debug authentication issues
const client = new AidboxClient({
  baseUrl: 'http://localhost:8888',
  auth: {
    type: 'client_credentials',
    client_id: 'example-client',
    client_secret: 'your-secure-client-secret',
    tokenUrl: 'http://localhost:8888/auth/token'
  },
  onError: (error) => {
    console.error('Aidbox client error:', error);
    if (error.status === 401) {
      console.error('Authentication failed. Check credentials and token validity.');
    } else if (error.status === 403) {
      console.error('Authorization failed. Check user permissions and scopes.');
    }
  }
});
```

## Conclusion

Properly configuring your Aidbox FHIR client with OAuth authentication, appropriate scopes, and RBAC is essential for building secure healthcare applications. By following the patterns and practices outlined in this guide, you can ensure that your application securely accesses FHIR resources while adhering to the principle of least privilege.
