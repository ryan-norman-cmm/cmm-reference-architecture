# Identity Provider (Okta)

## Introduction

The Identity Provider (IDP) is a critical component of the CMM Reference Architecture, serving as the central authentication and authorization system. Our implementation uses Okta, a leading enterprise identity platform that provides secure, scalable identity management services. This document provides an overview of how Okta is integrated into our architecture, its key features, and implementation considerations.

## Key Concepts

### What is an Identity Provider?

An Identity Provider (IDP) is a service that creates, maintains, and manages identity information while providing authentication and authorization services. In modern healthcare applications, an IDP is essential for:

- **User Authentication**: Verifying the identity of users attempting to access the system
- **Authorization**: Determining what resources authenticated users can access
- **Single Sign-On (SSO)**: Enabling users to access multiple applications with one set of credentials
- **Multi-Factor Authentication (MFA)**: Adding additional security layers beyond passwords
- **User Lifecycle Management**: Managing the entire lifecycle of user accounts from creation to deactivation

### Why Okta?

Okta was selected as our Identity Provider for several key reasons:

- **Enterprise-Grade Security**: SOC 2 Type II, HIPAA, and FedRAMP certified
- **Healthcare Industry Focus**: Specific features and compliance measures for healthcare organizations
- **Extensive Integration Capabilities**: Pre-built integrations with thousands of applications
- **Scalable Architecture**: Designed to handle millions of users and authentication events
- **Advanced Policy Framework**: Granular control over authentication and authorization rules
- **Developer-Friendly**: Comprehensive APIs, SDKs, and documentation

## Architecture Overview

```mermaid
flowchart TB
    User[User] --> Okta[Okta Identity Provider]
    Okta --> API[API Gateway]
    Okta --> WebApps[Web Applications]
    Okta --> MobileApps[Mobile Applications]
    
    API --> FederatedGraphQL[Federated GraphQL API]
    API --> RESTServices[REST Services]
    
    Okta --> AidboxFHIR[Aidbox FHIR Server]
    
    subgraph Identity Services
        OktaAuth[Authentication]
        OktaMFA[Multi-Factor Auth]
        OktaSSO[Single Sign-On]
        OktaLifecycle[User Lifecycle]
        OktaAPI[Identity APIs]
    end
    
    Okta --- Identity Services
```

## Key Features

### Single Sign-On (SSO)

Okta provides a seamless SSO experience across all applications in the CMM ecosystem. This means users only need to authenticate once to access multiple applications, improving both security and user experience.

### Multi-Factor Authentication (MFA)

Okta supports various MFA methods including:

- SMS and voice verification
- Email verification
- Mobile app authenticators (Okta Verify)
- Security keys (FIDO2/WebAuthn)
- Biometric verification

### User Management

Okta provides comprehensive user management capabilities:

- Self-service registration
- Profile management
- Password policies and self-service password reset
- User deprovisioning and access revocation
- Delegated administration

### API Access Management

Okta secures API access through:

- OAuth 2.0 and OpenID Connect support
- API scopes and fine-grained permissions
- Token validation and introspection
- JWT customization

## Integration Points

Okta integrates with several key components in our architecture:

- **Federated GraphQL API**: For authentication and authorization of API requests
- **Aidbox FHIR Server**: For SMART on FHIR authentication flows
- **Web and Mobile Applications**: For user authentication and SSO
- **Legacy Systems**: Through various authentication protocols (SAML, WS-Fed, etc.)

## Getting Started

To begin working with our Okta implementation:

1. Review the [Setup Guide](setup-guide.md) for environment configuration
2. Understand [Authentication Flows](../02-core-functionality/authentication-flows.md) for different application types
3. Learn about [User Management](../02-core-functionality/user-management.md) for healthcare scenarios
4. Explore [Advanced Security Features](../03-advanced-patterns/advanced-security.md) for healthcare compliance

## Related Components

- [Federated GraphQL API](../../federated-graph-api/01-getting-started/overview.md): Uses Okta for API authentication
- [Aidbox FHIR Server](../../fhir-server/01-getting-started/overview.md): Integrates with Okta for SMART on FHIR authentication
- [Design Component Library](../../design-component-library/01-getting-started/overview.md): Includes authentication UI components

## Next Steps

- [Setup Guide](setup-guide.md): Configure Okta for your environment
- [Authentication Flows](../02-core-functionality/authentication-flows.md): Implement different authentication patterns
- [Integration Patterns](../02-core-functionality/integration-patterns.md): Connect Okta with other systems
