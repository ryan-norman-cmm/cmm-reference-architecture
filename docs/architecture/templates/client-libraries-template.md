# [Component Name] Client Libraries

## Introduction

The **[Component Name]** provides official client libraries for multiple programming languages to simplify integration with our APIs. These libraries handle authentication, request formatting, error handling, and response parsing, allowing you to focus on your application logic rather than API implementation details.

## Supported Languages

| Language | Package Name | Min Version | Latest Version | Status | Documentation |
|----------|--------------|-------------|----------------|--------|---------------|
| TypeScript/JavaScript | @cmm/[component-name] | 10.0.0 | [![npm](https://img.shields.io/npm/v/@cmm/component-name)](https://www.npmjs.com/package/@cmm/component-name) | Stable | [TypeScript Docs](#typescript) |
| Python | cmm-[component-name] | 3.7 | [![PyPI](https://img.shields.io/pypi/v/cmm-component-name)](https://pypi.org/project/cmm-component-name/) | Stable | [Python Docs](#python) |
| Java | com.covermymeds.[component-name] | 8 | [![Maven Central](https://img.shields.io/maven-central/v/com.covermymeds/component-name)](https://search.maven.org/artifact/com.covermymeds/component-name) | Stable | [Java Docs](#java) |
| C# | CoverMyMeds.[ComponentName] | .NET 6.0 | [![NuGet](https://img.shields.io/nuget/v/CoverMyMeds.ComponentName)](https://www.nuget.org/packages/CoverMyMeds.ComponentName) | Stable | [C# Docs](#c-sharp) |
| Ruby | cmm-[component-name] | 2.7 | [![Gem](https://img.shields.io/gem/v/cmm-component-name)](https://rubygems.org/gems/cmm-component-name) | Beta | [Ruby Docs](#ruby) |
| Go | github.com/covermymeds/[component-name]-go | 1.16 | [![Go](https://img.shields.io/github/v/tag/covermymeds/component-name-go)](https://github.com/covermymeds/component-name-go) | Beta | [Go Docs](#go) |

## Installation and Setup

<a name="typescript"></a>
### TypeScript/JavaScript

#### Installation

```bash
# Using npm
npm install @cmm/[component-name]

# Using yarn
yarn add @cmm/[component-name]

# Using pnpm
pnpm add @cmm/[component-name]
```

#### Initialization

```typescript
import { Client } from '@cmm/[component-name]';

// Using API key authentication
const client = new Client({
  apiKey: 'your-api-key',
  environment: 'production' // or 'sandbox' for testing
});

// Using OAuth authentication
const client = new Client({
  clientId: 'your-client-id',
  clientSecret: 'your-client-secret',
  environment: 'production' // or 'sandbox' for testing
});

// Using Azure AD authentication (for internal applications)
const client = new Client({
  azureAuthentication: {
    tenantId: 'your-tenant-id',
    clientId: 'your-client-id',
    clientSecret: 'your-client-secret'
  },
  environment: 'production'
});
```

#### Basic Usage Example

```typescript
// Example: Retrieving a resource
async function getResource(resourceId: string) {
  try {
    const resource = await client.resources.get(resourceId);
    console.log('Resource retrieved:', resource);
    return resource;
  } catch (error) {
    if (error.status === 404) {
      console.error('Resource not found');
    } else {
      console.error('Error retrieving resource:', error.message);
    }
    throw error;
  }
}

// Example: Creating a resource
async function createResource(data: ResourceData) {
  try {
    const newResource = await client.resources.create(data);
    console.log('Resource created:', newResource);
    return newResource;
  } catch (error) {
    console.error('Error creating resource:', error.message);
    throw error;
  }
}
```

#### Advanced Features

```typescript
// Configuring request options
const client = new Client({
  apiKey: 'your-api-key',
  options: {
    timeout: 30000, // 30 seconds
    retries: 3,
    retryDelay: 1000,
    maxRetryDelay: 5000,
    retryCondition: (error) => {
      // Only retry on network errors or 429/5xx responses
      return !error.response || error.response.status >= 429;
    }
  }
});

// Using middleware
client.use(async (req, next) => {
  // Add custom headers
  req.headers['x-custom-header'] = 'custom-value';
  
  // Measure request duration
  const start = Date.now();
  try {
    const response = await next(req);
    const duration = Date.now() - start;
    console.log(`Request to ${req.url} completed in ${duration}ms`);
    return response;
  } catch (error) {
    const duration = Date.now() - start;
    console.error(`Request to ${req.url} failed after ${duration}ms:`, error);
    throw error;
  }
});
```

<a name="python"></a>
### Python

#### Installation

```bash
# Using pip
pip install cmm-[component-name]

# Using poetry
poetry add cmm-[component-name]
```

#### Initialization

```python
from cmm_component_name import Client

# Using API key authentication
client = Client(
    api_key="your-api-key",
    environment="production"  # or "sandbox" for testing
)

# Using OAuth authentication
client = Client(
    client_id="your-client-id",
    client_secret="your-client-secret",
    environment="production"  # or "sandbox" for testing
)

# Using Azure AD authentication (for internal applications)
client = Client(
    azure_authentication={
        "tenant_id": "your-tenant-id",
        "client_id": "your-client-id",
        "client_secret": "your-client-secret"
    },
    environment="production"
)
```

#### Basic Usage Example

```python
# Example: Retrieving a resource
def get_resource(resource_id):
    try:
        resource = client.resources.get(resource_id)
        print(f"Resource retrieved: {resource}")
        return resource
    except Exception as e:
        if hasattr(e, "status_code") and e.status_code == 404:
            print("Resource not found")
        else:
            print(f"Error retrieving resource: {str(e)}")
        raise

# Example: Creating a resource
def create_resource(data):
    try:
        new_resource = client.resources.create(data)
        print(f"Resource created: {new_resource}")
        return new_resource
    except Exception as e:
        print(f"Error creating resource: {str(e)}")
        raise
```

<a name="java"></a>
### Java

#### Installation

Maven:
```xml
<dependency>
    <groupId>com.covermymeds</groupId>
    <artifactId>[component-name]</artifactId>
    <version>1.0.0</version>
</dependency>
```

Gradle:
```groovy
implementation 'com.covermymeds:[component-name]:1.0.0'
```

#### Initialization

```java
import com.covermymeds.componentname.Client;
import com.covermymeds.componentname.ClientConfig;

// Using API key authentication
Client client = Client.builder()
    .apiKey("your-api-key")
    .environment("production") // or "sandbox" for testing
    .build();

// Using OAuth authentication
Client client = Client.builder()
    .clientId("your-client-id")
    .clientSecret("your-client-secret")
    .environment("production") // or "sandbox" for testing
    .build();

// Using Azure AD authentication (for internal applications)
Client client = Client.builder()
    .azureAuthentication(AzureAuthConfig.builder()
        .tenantId("your-tenant-id")
        .clientId("your-client-id")
        .clientSecret("your-client-secret")
        .build())
    .environment("production")
    .build();
```

#### Basic Usage Example

```java
// Example: Retrieving a resource
public Resource getResource(String resourceId) {
    try {
        Resource resource = client.resources().get(resourceId);
        System.out.println("Resource retrieved: " + resource);
        return resource;
    } catch (ResourceNotFoundException e) {
        System.err.println("Resource not found");
        throw e;
    } catch (ApiException e) {
        System.err.println("Error retrieving resource: " + e.getMessage());
        throw e;
    }
}

// Example: Creating a resource
public Resource createResource(ResourceData data) {
    try {
        Resource newResource = client.resources().create(data);
        System.out.println("Resource created: " + newResource);
        return newResource;
    } catch (ApiException e) {
        System.err.println("Error creating resource: " + e.getMessage());
        throw e;
    }
}
```

<a name="c-sharp"></a>
### C#

#### Installation

```bash
# Using .NET CLI
dotnet add package CoverMyMeds.[ComponentName]

# Using Package Manager
Install-Package CoverMyMeds.[ComponentName]
```

#### Initialization

```csharp
using CoverMyMeds.ComponentName;

// Using API key authentication
var client = new Client(new ClientOptions
{
    ApiKey = "your-api-key",
    Environment = Environment.Production // or Environment.Sandbox for testing
});

// Using OAuth authentication
var client = new Client(new ClientOptions
{
    ClientId = "your-client-id",
    ClientSecret = "your-client-secret",
    Environment = Environment.Production // or Environment.Sandbox for testing
});

// Using Azure AD authentication (for internal applications)
var client = new Client(new ClientOptions
{
    AzureAuthentication = new AzureAuthenticationOptions
    {
        TenantId = "your-tenant-id",
        ClientId = "your-client-id",
        ClientSecret = "your-client-secret"
    },
    Environment = Environment.Production
});
```

#### Basic Usage Example

```csharp
// Example: Retrieving a resource
public async Task<Resource> GetResourceAsync(string resourceId)
{
    try
    {
        var resource = await client.Resources.GetAsync(resourceId);
        Console.WriteLine($"Resource retrieved: {resource}");
        return resource;
    }
    catch (ResourceNotFoundException)
    {
        Console.Error.WriteLine("Resource not found");
        throw;
    }
    catch (ApiException ex)
    {
        Console.Error.WriteLine($"Error retrieving resource: {ex.Message}");
        throw;
    }
}

// Example: Creating a resource
public async Task<Resource> CreateResourceAsync(ResourceData data)
{
    try
    {
        var newResource = await client.Resources.CreateAsync(data);
        Console.WriteLine($"Resource created: {newResource}");
        return newResource;
    }
    catch (ApiException ex)
    {
        Console.Error.WriteLine($"Error creating resource: {ex.Message}");
        throw;
    }
}
```

<a name="ruby"></a>
### Ruby

#### Installation

```bash
# Using gem
gem install cmm-[component-name]

# In your Gemfile
gem 'cmm-[component-name]', '~> 1.0'
```

#### Initialization

```ruby
require 'cmm/component_name'

# Using API key authentication
client = CMM::ComponentName::Client.new(
  api_key: 'your-api-key',
  environment: :production # or :sandbox for testing
)

# Using OAuth authentication
client = CMM::ComponentName::Client.new(
  client_id: 'your-client-id',
  client_secret: 'your-client-secret',
  environment: :production # or :sandbox for testing
)
```

#### Basic Usage Example

```ruby
# Example: Retrieving a resource
def get_resource(resource_id)
  begin
    resource = client.resources.get(resource_id)
    puts "Resource retrieved: #{resource}"
    resource
  rescue CMM::ComponentName::ResourceNotFoundError
    puts "Resource not found"
    raise
  rescue CMM::ComponentName::Error => e
    puts "Error retrieving resource: #{e.message}"
    raise
  end
end

# Example: Creating a resource
def create_resource(data)
  begin
    new_resource = client.resources.create(data)
    puts "Resource created: #{new_resource}"
    new_resource
  rescue CMM::ComponentName::Error => e
    puts "Error creating resource: #{e.message}"
    raise
  end
end
```

<a name="go"></a>
### Go

#### Installation

```bash
go get github.com/covermymeds/[component-name]-go
```

#### Initialization

```go
import "github.com/covermymeds/component-name-go"

// Using API key authentication
client, err := componentname.NewClient(&componentname.ClientOptions{
    APIKey:      "your-api-key",
    Environment: componentname.EnvironmentProduction, // or componentname.EnvironmentSandbox for testing
})
if err != nil {
    log.Fatalf("Failed to create client: %v", err)
}

// Using OAuth authentication
client, err := componentname.NewClient(&componentname.ClientOptions{
    ClientID:     "your-client-id",
    ClientSecret: "your-client-secret",
    Environment:  componentname.EnvironmentProduction, // or componentname.EnvironmentSandbox for testing
})
if err != nil {
    log.Fatalf("Failed to create client: %v", err)
}
```

#### Basic Usage Example

```go
// Example: Retrieving a resource
func getResource(resourceID string) (*componentname.Resource, error) {
    resource, err := client.Resources.Get(context.Background(), resourceID)
    if err != nil {
        if componentname.IsResourceNotFound(err) {
            log.Printf("Resource not found")
            return nil, err
        }
        log.Printf("Error retrieving resource: %v", err)
        return nil, err
    }
    log.Printf("Resource retrieved: %+v", resource)
    return resource, nil
}

// Example: Creating a resource
func createResource(data *componentname.ResourceData) (*componentname.Resource, error) {
    newResource, err := client.Resources.Create(context.Background(), data)
    if err != nil {
        log.Printf("Error creating resource: %v", err)
        return nil, err
    }
    log.Printf("Resource created: %+v", newResource)
    return newResource, nil
}
```

## Common Operations

The following sections demonstrate common operations across all supported client libraries. For language-specific examples, see the appropriate language section above.

### Pagination

All client libraries provide consistent pagination helpers for listing resources:

```typescript
// TypeScript example
async function getAllResources() {
  // Option 1: Manual pagination
  let page = 1;
  const pageSize = 100;
  let hasMore = true;
  let allResources = [];
  
  while (hasMore) {
    const response = await client.resources.list({
      page,
      pageSize
    });
    
    allResources = allResources.concat(response.data);
    hasMore = response.pagination.hasNextPage;
    page++;
  }
  
  return allResources;
  
  // Option 2: Using pagination helpers
  const resources = await client.resources.listAll({
    pageSize: 100,
    maxPages: 10 // Optional limit
  });
  
  return resources;
}
```

### Filtering and Sorting

```typescript
// TypeScript example
async function filterResources() {
  const resources = await client.resources.list({
    // Filtering
    filter: {
      status: 'active',
      createdAfter: '2023-01-01T00:00:00Z',
      tags: ['important', 'healthcare']
    },
    // Sorting
    sort: [
      { field: 'createdAt', direction: 'desc' },
      { field: 'name', direction: 'asc' }
    ],
    // Pagination
    page: 1,
    pageSize: 50
  });
  
  return resources;
}
```

### Error Handling

All client libraries provide consistent error types and patterns:

```typescript
// TypeScript example
async function handleErrors() {
  try {
    const result = await client.resources.get('non-existent-id');
    return result;
  } catch (error) {
    // Specific error types
    if (error instanceof ResourceNotFoundError) {
      console.error('Resource not found:', error.message);
      // Handle 404 case
    } else if (error instanceof ValidationError) {
      console.error('Validation error:', error.details);
      // Access structured validation errors
      error.details.forEach(detail => {
        console.error(`- ${detail.field}: ${detail.message}`);
      });
    } else if (error instanceof AuthenticationError) {
      console.error('Authentication error:', error.message);
      // Handle auth issues
    } else if (error instanceof RateLimitError) {
      console.error('Rate limit exceeded:', error.message);
      // Handle rate limiting
      const retryAfter = error.headers['retry-after'];
      console.log(`Retry after ${retryAfter} seconds`);
    } else if (error instanceof ApiError) {
      console.error('API error:', error.message);
      // All other API errors
      console.error('Status:', error.status);
      console.error('Request ID:', error.requestId);
    } else {
      // Network or unexpected errors
      console.error('Unexpected error:', error);
    }
    throw error;
  }
}
```

### Request Customization

All client libraries allow customizing requests:

```typescript
// TypeScript example
async function customizeRequest() {
  // One-time request customization
  const resource = await client.resources.get('resource-id', {
    headers: {
      'x-custom-header': 'custom-value'
    },
    timeout: 5000, // 5 seconds
    retries: 0 // Disable retries for this request
  });
  
  return resource;
}
```

### Mocking and Testing

All client libraries provide mocking capabilities for testing:

```typescript
// TypeScript example - Using the test utilities
import { MockClient } from '@cmm/[component-name]/testing';

describe('Resource Operations', () => {
  let mockClient;
  
  beforeEach(() => {
    // Create a mock client
    mockClient = new MockClient();
    
    // Mock specific responses
    mockClient.resources.get.mockResolvedValue({
      id: 'mock-id',
      name: 'Mock Resource',
      status: 'active'
    });
    
    mockClient.resources.create.mockImplementation(data => ({
      id: 'new-mock-id',
      ...data,
      createdAt: new Date().toISOString()
    }));
  });
  
  test('should retrieve a resource', async () => {
    const resource = await mockClient.resources.get('mock-id');
    expect(resource.id).toBe('mock-id');
    expect(resource.name).toBe('Mock Resource');
    expect(mockClient.resources.get).toHaveBeenCalledWith('mock-id');
  });
  
  test('should create a resource', async () => {
    const data = { name: 'New Resource' };
    const resource = await mockClient.resources.create(data);
    expect(resource.id).toBe('new-mock-id');
    expect(resource.name).toBe('New Resource');
    expect(mockClient.resources.create).toHaveBeenCalledWith(data);
  });
});
```

## Migrating Between Versions

### Migrating from v1.x to v2.x

The v2.x release includes several breaking changes:

1. **Authentication Changes**
   - OAuth flows now require specifying scopes
   - API key format changed from `key_xxxxx` to `cmm_[component]_xxxxx`

2. **API Structure Changes**
   - Resource APIs have moved to `client.resources.*` namespace
   - Response structure now includes metadata

3. **Migration Steps**

```typescript
// Old v1.x code
const client = new Client({
  apiKey: 'key_xxxxx'
});

const resource = await client.getResource('resource-id');

// New v2.x code
const client = new Client({
  apiKey: 'cmm_[component]_xxxxx'
});

const resource = await client.resources.get('resource-id');
```

For a complete migration guide, see the [v2.x Migration Guide](https://docs.covermymeds.com/[component-name]/migration-v2).

## FAQ

### Which library should I choose?

- **TypeScript/JavaScript**: Best for web applications, Node.js services, and serverless functions.
- **Python**: Good choice for data processing, machine learning applications, and scripting.
- **Java**: Ideal for enterprise applications, microservices, and Android applications.
- **C#**: Great for .NET applications, Windows services, and Azure Functions.
- **Ruby**: Well-suited for web applications using Ruby on Rails.
- **Go**: Excellent for high-performance microservices and cloud-native applications.

### How do I report issues with client libraries?

For bugs, feature requests, or documentation improvements:
1. Check existing issues in our GitHub repository
2. Open a new issue with detailed reproduction steps
3. Include client library version, language version, and OS information

GitHub repositories:
- TypeScript: [github.com/covermymeds/[component-name]-js](https://github.com/covermymeds/component-name-js)
- Python: [github.com/covermymeds/[component-name]-python](https://github.com/covermymeds/component-name-python)
- Java: [github.com/covermymeds/[component-name]-java](https://github.com/covermymeds/component-name-java)
- C#: [github.com/covermymeds/[component-name]-dotnet](https://github.com/covermymeds/component-name-dotnet)
- Ruby: [github.com/covermymeds/[component-name]-ruby](https://github.com/covermymeds/component-name-ruby)
- Go: [github.com/covermymeds/[component-name]-go](https://github.com/covermymeds/component-name-go)

### How are client libraries versioned?

All client libraries follow semantic versioning (MAJOR.MINOR.PATCH):
- MAJOR version increases indicate breaking changes
- MINOR version increases add functionality in a backward-compatible manner
- PATCH version increases include backward-compatible bug fixes

Libraries are updated when:
- New API features are released
- Bug fixes are implemented
- Dependencies need security updates
- Performance improvements are made

## Related Resources

- [API Reference Documentation](../03-core-functionality/core-apis.md)
- [Use Case Examples](./use-case-examples.md)
- [API Sandbox](./api-sandbox.md)
- [Troubleshooting Guide](./troubleshooting-guide.md)
- [SDK Release Notes](https://github.com/covermymeds/[component-name]/releases)