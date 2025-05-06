# API Marketplace Quick Start

This guide provides a step-by-step process to help you quickly get started with the API Marketplace core component, focusing on registering an API using MuleSoft Anypoint Platform.

## Prerequisites
- Access to the CMM platform environment (development, staging, or production)
- MuleSoft Anypoint Platform account ([sign up here](https://anypoint.mulesoft.com/login/))
- API definition (RAML, OAS/Swagger, or WSDL)
- API implementation or endpoint URL (optional for initial registration)
- Familiarity with API management concepts

## Step 1: Access MuleSoft Anypoint Platform
- Go to [MuleSoft Anypoint Platform](https://anypoint.mulesoft.com/).
- Log in with your credentials.

## Step 2: Register an API in Exchange
> **Recommended:** Follow the official MuleSoft guide: [Publish an API to Exchange](https://docs.mulesoft.com/exchange/publish-api-to-exchange)

1. In the Anypoint Platform, navigate to **Exchange**.
2. Click **Publish new asset** > **API**.
3. Fill in the API details:
   - Name, version, and description
   - Upload or reference your API definition (RAML, OAS/Swagger, or WSDL)
   - Select the asset type (REST API, SOAP API, etc.)
4. Click **Publish** to register the API in Exchange.

## Step 3: Manage Your API in API Manager
1. Go to **API Manager** in Anypoint Platform.
2. Click **Add API** > **Add new API**.
3. Select the API asset you published in Exchange.
4. Configure the API endpoint, implementation URL, and policies as needed.
5. Click **Save** to register and manage your API.

## Step 4: Validate Setup
- Ensure your API appears in Exchange and API Manager.
- Use the built-in API Console in Exchange to test endpoints and view documentation.
- Check API Manager for applied policies, monitoring, and analytics.
- For troubleshooting, see [MuleSoft troubleshooting docs](https://docs.mulesoft.com/exchange/troubleshooting-exchange) and [API Manager troubleshooting](https://docs.mulesoft.com/api-manager/troubleshooting-api-manager).

## Reference Vendor Quick Start
- [MuleSoft: Publish an API to Exchange](https://docs.mulesoft.com/exchange/publish-api-to-exchange)
- [MuleSoft: API Manager Getting Started](https://docs.mulesoft.com/api-manager/getting-started)
- [MuleSoft: Exchange Documentation](https://docs.mulesoft.com/exchange/)
- [MuleSoft: API Manager Documentation](https://docs.mulesoft.com/api-manager/)

## Next Steps
- [Explore Advanced API Policies](../03-advanced-topics/policies.md)
- [Integration Guide: Event Broker](../../event-broker/01-getting-started/quick-start.md)
- [Integration Guide: Federated Graph API](../../federated-graph-api/01-getting-started/quick-start.md)
- [Integration Guide: FHIR Interoperability Platform](../../fhir-interoperability-platform/01-getting-started/quick-start.md)
- [Best Practices: API Design](../03-advanced-topics/api-design.md)
- [Error Handling & Troubleshooting](../03-advanced-topics/error-handling.md)

## Related Resources
- [MuleSoft Documentation](https://docs.mulesoft.com/)
- [MuleSoft Anypoint Platform Overview](https://www.mulesoft.com/platform/enterprise-integration)
- [API Marketplace Overview](./overview.md)
- [API Marketplace Architecture](./architecture.md)
- [API Marketplace Key Concepts](./key-concepts.md)
