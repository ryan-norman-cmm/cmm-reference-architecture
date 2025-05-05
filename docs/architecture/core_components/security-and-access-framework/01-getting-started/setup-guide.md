# Okta Setup Guide

## Introduction

This guide walks you through the process of setting up Okta as your Identity Provider for the CMM Reference Architecture. It covers initial configuration, application integration, and best practices for healthcare environments. By following these steps, you'll establish a secure, compliant identity foundation for your healthcare applications.

## Prerequisites

Before beginning the Okta setup process, ensure you have:

- An Okta developer or enterprise account
- Administrative access to your Okta tenant
- Access to your application codebase
- Basic understanding of OAuth 2.0 and OpenID Connect
- Familiarity with healthcare compliance requirements (HIPAA, etc.)

## Setup Process

### 1. Okta Tenant Configuration

#### Create and Configure Your Okta Tenant

1. **Sign up for an Okta account**
   - Navigate to [Okta Developer](https://developer.okta.com/signup/)
   - Complete the registration process
   - Note your Okta domain (e.g., `dev-123456.okta.com`)

2. **Configure Security Settings**
   - Navigate to **Security → Settings**
   - Enable multi-factor authentication
   - Set password policies appropriate for healthcare (minimum 12 characters, complexity requirements)
   - Configure session timeouts (recommended: 15 minutes for healthcare applications)

3. **Set Up Custom Domains (Optional)**
   - Navigate to **Settings → Customization → Custom Domain**
   - Configure your custom domain (e.g., `auth.yourhealthcare.org`)
   - Upload SSL certificates

### 2. User Directory Configuration

#### Set Up User Groups and Attributes

1. **Create User Groups**
   - Navigate to **Directory → Groups**
   - Create the following standard groups:
     - `Healthcare_Administrators`
     - `Healthcare_Providers`
     - `Healthcare_Staff`
     - `Patients`
     - `System_Integrations`

2. **Configure User Attributes**
   - Navigate to **Directory → Profile Editor**
   - Add healthcare-specific attributes:
     - `npi` (National Provider Identifier)
     - `role` (Clinical role)
     - `department`
     - `facilityIds` (Array of facilities)
     - `patientId` (For patient users)

3. **Set Up Group Rules (Optional)**
   - Navigate to **Directory → Group Rules**
   - Create rules to automatically assign users to groups based on attributes

### 3. Application Registration

#### Register Your Applications

1. **Create OpenID Connect Application**
   - Navigate to **Applications → Applications**
   - Click **Create App Integration**
   - Select **OIDC - OpenID Connect** and the appropriate application type
   - Configure application settings:
     - Name: `CMM Healthcare Portal`
     - Grant types: Authorization Code, Refresh Token
     - Sign-in redirect URIs: `https://your-app-domain.com/callback`
     - Sign-out redirect URIs: `https://your-app-domain.com/logout`
     - Trusted Origins: Your application domains

2. **Configure Application Assignments**
   - Under your application, go to **Assignments**
   - Assign appropriate groups to the application

3. **Configure App-Level MFA (Recommended)**
   - Under your application, go to **Sign On**
   - Configure application sign-on policy with MFA requirements

### 4. API Authorization Server

#### Configure OAuth Scopes and Claims

1. **Create Authorization Server**
   - Navigate to **Security → API**
   - Create a new authorization server:
     - Name: `Healthcare API`
     - Audience: `https://api.yourhealthcare.org`
     - Description: `Authorization server for healthcare APIs`

2. **Define Scopes**
   - In your authorization server, go to **Scopes**
   - Add healthcare-specific scopes:
     - `patient.read`
     - `patient.write`
     - `clinical.read`
     - `clinical.write`
     - `admin.read`
     - `admin.write`

3. **Create Claims**
   - In your authorization server, go to **Claims**
   - Add custom claims to include in tokens:
     - `groups` (User's groups)
     - `npi` (Provider identifier)
     - `role` (Clinical role)
     - `facilityIds` (Authorized facilities)

4. **Configure Access Policies**
   - In your authorization server, go to **Access Policies**
   - Create policies for different client types and user groups
   - Configure appropriate token lifetimes (shorter for healthcare applications)

### 5. Integration with Aidbox FHIR Server

#### Configure SMART on FHIR Authentication

1. **Create SMART on FHIR Application**
   - Register a new application for FHIR access
   - Configure SMART-specific redirect URIs
   - Add SMART on FHIR scopes:
     - `launch/patient`
     - `patient/*.read`
     - `patient/*.write`
     - `user/*.read`
     - `user/*.write`

2. **Configure FHIR-Specific Claims**
   - Add claims for FHIR context:
     - `fhirUser` (FHIR resource reference to user)
     - `patient_id` (Current patient context)

3. **Set Up FHIR Resource Mapping**
   - Create mapping between Okta users and FHIR resources
   - Configure attribute mapping for Patient and Practitioner resources

## Integration Code Examples

### Web Application Integration

```typescript
// Example: React application with Okta integration
import { Security, LoginCallback } from '@okta/okta-react';
import { OktaAuth } from '@okta/okta-auth-js';
import { Route, useHistory } from 'react-router-dom';

const oktaAuth = new OktaAuth({
  issuer: 'https://{yourOktaDomain}/oauth2/default',
  clientId: '{clientId}',
  redirectUri: window.location.origin + '/callback',
  scopes: ['openid', 'profile', 'email', 'patient.read'],
  pkce: true
});

function App() {
  const history = useHistory();
  
  const restoreOriginalUri = async (_oktaAuth: OktaAuth, originalUri: string) => {
    history.replace(originalUri);
  };
  
  return (
    <Security
      oktaAuth={oktaAuth}
      restoreOriginalUri={restoreOriginalUri}
    >
      {/* Your application routes */}
      <Route path='/callback' component={LoginCallback} />
    </Security>
  );
}
```

### API Integration

```typescript
// Example: Express middleware for API authentication
import { expressjwt as jwt } from 'express-jwt';
import jwksRsa from 'jwks-rsa';

// Configure JWT validation middleware
const checkJwt = jwt({
  // Dynamically fetch signing keys from the JWKS endpoint
  secret: jwksRsa.expressJwtSecret({
    cache: true,
    rateLimit: true,
    jwksRequestsPerMinute: 5,
    jwksUri: 'https://{yourOktaDomain}/oauth2/default/v1/keys'
  }),
  
  // Validate audience and issuer
  audience: 'api://default',
  issuer: 'https://{yourOktaDomain}/oauth2/default',
  algorithms: ['RS256']
});

// Check for specific scopes
const checkScopes = (requiredScopes: string[]) => {
  return (req: any, res: any, next: any) => {
    const tokenScopes = req.auth.scp || [];
    const hasRequiredScopes = requiredScopes.every(scope => tokenScopes.includes(scope));
    
    if (!hasRequiredScopes) {
      return res.status(403).json({
        error: 'Insufficient permissions',
        requiredScopes
      });
    }
    
    next();
  };
};

// Use in Express routes
app.get('/api/patients',
  checkJwt,
  checkScopes(['patient.read']),
  (req, res) => {
    // Handle the request
  }
);
```

### SMART on FHIR Integration

```typescript
// Example: SMART on FHIR client registration with Aidbox
import axios from 'axios';

async function registerSmartClient() {
  const aidboxClient = {
    resourceType: 'Client',
    id: 'smart-app-client',
    secret: 'your-secure-client-secret',
    grant_types: ['authorization_code', 'refresh_token'],
    auth: {
      authorization_code: {
        redirect_uri: 'https://your-app-domain.com/smart-callback',
        refresh_token: true
      }
    },
    jwks_uri: 'https://{yourOktaDomain}/oauth2/default/v1/keys',
    access_token_validation: 'jwt-verification'
  };
  
  try {
    const response = await axios.put(
      'https://your-aidbox-server.com/Client/smart-app-client',
      aidboxClient,
      {
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic ' + Buffer.from('admin:password').toString('base64')
        }
      }
    );
    
    console.log('SMART client registered:', response.data);
    return response.data;
  } catch (error) {
    console.error('Error registering SMART client:', error);
    throw error;
  }
}
```

## Deployment Considerations

### Production Checklist

- **Enable High Availability**: Configure for geographic redundancy
- **Implement Rate Limiting**: Protect against brute force attacks
- **Set Up Monitoring**: Configure alerts for suspicious activities
- **Regular Security Reviews**: Schedule quarterly security assessments
- **Backup Procedures**: Ensure regular backups of configuration
- **Disaster Recovery Plan**: Document recovery procedures

### Healthcare Compliance

- **HIPAA Compliance**: Ensure audit logs capture all required information
- **Access Reviews**: Implement quarterly access reviews
- **Emergency Access**: Configure break-glass procedures
- **Privacy Controls**: Implement data minimization in tokens
- **Security Documentation**: Maintain documentation for audits

## Troubleshooting

### Common Issues

1. **Token Validation Failures**
   - Check issuer and audience configuration
   - Verify JWKS endpoint is accessible
   - Ensure clocks are synchronized

2. **MFA Issues**
   - Verify user has enrolled in MFA
   - Check MFA factor status
   - Review MFA enrollment policies

3. **Integration Errors**
   - Validate redirect URI configuration
   - Check scope assignments
   - Review network connectivity

## Next Steps

- [Authentication Flows](../02-core-functionality/authentication-flows.md): Implement different authentication patterns
- [User Management](../02-core-functionality/user-management.md): Learn about user lifecycle management
- [Advanced Security Features](../03-advanced-patterns/advanced-security.md): Implement additional security measures

## Resources

- [Okta Developer Documentation](https://developer.okta.com/docs/)
- [SMART on FHIR Documentation](http://hl7.org/fhir/smart-app-launch/)
- [OAuth 2.0 for Healthcare APIs](https://www.hl7.org/fhir/security.html)
