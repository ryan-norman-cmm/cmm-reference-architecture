# [Component Name] API Sandbox

## Introduction

The **[Component Name]** API Sandbox provides an interactive environment for exploring and testing APIs without writing code. This document guides you through accessing the sandbox environment, authenticating, and using the interactive tools to experiment with the API capabilities.

## Sandbox Environment

The sandbox environment is a fully functional replica of the production environment with the following key differences:

- No real patient data (synthetic test data only)
- Lower rate limits and resource quotas
- Isolated from production systems
- Immediate provisioning (no approval process)
- Reset daily to a clean state

## Accessing the Sandbox

### Authentication

The sandbox uses simplified authentication compared to production:

1. Navigate to the sandbox portal: `https://[component-name]-sandbox.dev.cmm.azure.com`
2. Log in using your CMM Azure AD credentials
3. The system will automatically provision a sandbox account and API keys

**Sandbox API Key Example:**
```
x-cmm-sandbox-api-key: sb_[component_name]_00000000000000000000000000000000
```

### Sandbox Limitations

| Resource | Sandbox Limit | Production Limit |
|----------|---------------|------------------|
| Requests per minute | 60 | 1,000 |
| Concurrent connections | 5 | 100 |
| Maximum payload size | 1 MB | 10 MB |
| Storage allocation | 100 MB | Unlimited |
| Session duration | 24 hours | Unlimited |

## Interactive API Explorer

The sandbox includes an interactive API explorer based on Swagger UI:

1. Navigate to `https://[component-name]-sandbox.dev.cmm.azure.com/explorer`
2. Your sandbox API key is automatically included in requests
3. Explore available endpoints organized by category
4. Try operations directly from the browser UI

### Using the Explorer

![API Explorer Interface](https://placehold.co/600x400?text=API+Explorer+Screenshot)

1. **Browse Operations**: Expand categories in the left navigation
2. **Set Parameters**: Fill in required and optional parameters
3. **Execute Requests**: Click "Try it out" and then "Execute"
4. **View Results**: See complete request/response details
5. **Copy as cURL**: Generate cURL commands for any request

### Sample Requests

The API explorer includes sample requests for common operations:

#### Example 1: [Common Operation]

```json
// Sample request payload
{
  "parameter1": "value1",
  "parameter2": "value2"
}
```

#### Example 2: [Another Common Operation]

```json
// Sample request payload
{
  "parameter1": "value1",
  "arrayParameter": [
    "item1",
    "item2"
  ]
}
```

## Postman Collection

For more advanced testing, a Postman collection is available:

1. Download the [Component Name] Postman collection: [Download Link]
2. Import the collection into Postman
3. Configure the collection variables:
   - `sandbox_url`: `https://[component-name]-sandbox.dev.cmm.azure.com`
   - `api_key`: Your sandbox API key

The collection includes:
- Pre-configured authentication
- Organized request folders by capability
- Example payloads for each endpoint
- Environment variables for easy switching between sandbox and production
- Tests to validate responses

## Mock Servers

For offline development, we provide mock servers that simulate API behavior:

### Docker-based Mock

```bash
# Pull and run the mock server
docker pull covermymeds/[component-name]-mock:latest
docker run -p 8080:8080 covermymeds/[component-name]-mock:latest

# The mock server is available at http://localhost:8080
```

### Static Response Files

Alternatively, download static response files for offline use:
- [JSON Response Pack](https://[component-name]-sandbox.dev.cmm.azure.com/downloads/mock-responses.zip)
- [OpenAPI Specification](https://[component-name]-sandbox.dev.cmm.azure.com/downloads/openapi.yaml)

## Data Generation

The sandbox includes tools to generate synthetic test data:

1. Navigate to `https://[component-name]-sandbox.dev.cmm.azure.com/data-generator`
2. Select the data type you need (patients, claims, providers, etc.)
3. Configure generation parameters
4. Generate synthetic data that conforms to FHIR standards
5. Import the generated data into your sandbox instance

## Testing Webhooks

To test webhooks and event notifications:

1. Navigate to `https://[component-name]-sandbox.dev.cmm.azure.com/webhooks`
2. Register a webhook URL (can be a service like webhook.site for testing)
3. Select the events you want to receive
4. Trigger events using the appropriate API calls
5. View the webhook delivery details and payload

## Troubleshooting

| Issue | Resolution |
|-------|------------|
| Authentication failure | Verify you're using the sandbox API key, not a production key |
| "Resource not found" | Check the URL path - sandbox may have a different structure |
| Sandbox reset | Sandbox environments reset daily at 00:00 UTC |
| Rate limiting | Implement proper backoff strategy (even in sandbox) |

## Next Steps

After exploring the API in the sandbox:

- Review the [Core APIs Documentation](../03-core-functionality/core-apis.md)
- Implement [Common Use Cases](./use-case-examples.md)
- Explore [Client Libraries](./client-libraries.md) for your preferred language
- Set up a [local development environment](./local-setup.md)

## Support

For help with the sandbox environment:

- Chat: Join the Microsoft Teams channel `#[component-name]-sandbox-support`
- Email: [sandbox-support@covermymeds.com](mailto:sandbox-support@covermymeds.com)
- Office Hours: Sandbox support team is available weekdays 9am-5pm ET

## Related Resources

- [Quick Start Guide (Cloud)](./quick-start-cloud.md)
- [Core APIs Documentation](../03-core-functionality/core-apis.md)
- [Vendor Documentation](https://vendor.documentation.link)