# FHIR Interoperability Platform Client Libraries

## Introduction

The **FHIR Interoperability Platform** provides official client libraries for multiple programming languages to simplify integration with our FHIR APIs. These libraries handle authentication, request formatting, error handling, and response parsing, allowing you to focus on your healthcare application logic rather than API implementation details.

## Supported Languages

| Language | Package Name | Min Version | Latest Version | Status | Documentation |
|----------|--------------|-------------|----------------|--------|---------------|
| TypeScript/JavaScript | @cmm/fhir-interop | 10.0.0 | [![npm](https://img.shields.io/npm/v/@cmm/fhir-interop)](https://www.npmjs.com/package/@cmm/fhir-interop) | Stable | [TypeScript Docs](#typescript) |
| Python | cmm-fhir-interop | 3.7 | [![PyPI](https://img.shields.io/pypi/v/cmm-fhir-interop)](https://pypi.org/project/cmm-fhir-interop/) | Stable | [Python Docs](#python) |
| Java | com.covermymeds.fhir-interop | 8 | [![Maven Central](https://img.shields.io/maven-central/v/com.covermymeds/fhir-interop)](https://search.maven.org/artifact/com.covermymeds/fhir-interop) | Stable | [Java Docs](#java) |
| C# | CoverMyMeds.FHIRInterop | .NET 6.0 | [![NuGet](https://img.shields.io/nuget/v/CoverMyMeds.FHIRInterop)](https://www.nuget.org/packages/CoverMyMeds.FHIRInterop) | Stable | [C# Docs](#c-sharp) |
| Ruby | cmm-fhir-interop | 2.7 | [![Gem](https://img.shields.io/gem/v/cmm-fhir-interop)](https://rubygems.org/gems/cmm-fhir-interop) | Beta | [Ruby Docs](#ruby) |
| Go | github.com/covermymeds/fhir-interop-go | 1.16 | [![Go](https://img.shields.io/github/v/tag/covermymeds/fhir-interop-go)](https://github.com/covermymeds/fhir-interop-go) | Beta | [Go Docs](#go) |

## Installation and Setup

<a name="typescript"></a>
### TypeScript/JavaScript

#### Installation

```bash
# Using npm
npm install @cmm/fhir-interop

# Using yarn
yarn add @cmm/fhir-interop

# Using pnpm
pnpm add @cmm/fhir-interop
```

#### Initialization

```typescript
import { FHIRClient } from '@cmm/fhir-interop';

// Using API key authentication
const client = new FHIRClient({
  apiKey: 'your-api-key',
  environment: 'production' // or 'sandbox' for testing
});

// Using OAuth authentication
const client = new FHIRClient({
  clientId: 'your-client-id',
  clientSecret: 'your-client-secret',
  environment: 'production' // or 'sandbox' for testing
});

// Using SMART on FHIR authentication
const client = new FHIRClient({
  smartAuth: {
    clientId: 'your-smart-client-id',
    redirectUri: 'https://your-app/callback',
    scope: 'launch/patient patient/*.read'
  },
  environment: 'production'
});

// Using Azure AD authentication (for internal applications)
const client = new FHIRClient({
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
// Example: Retrieving a patient
async function getPatient(patientId: string) {
  try {
    const patient = await client.resources.Patient.get(patientId);
    console.log('Patient retrieved:', patient);
    return patient;
  } catch (error) {
    if (error.status === 404) {
      console.error('Patient not found');
    } else {
      console.error('Error retrieving patient:', error.message);
    }
    throw error;
  }
}

// Example: Creating a patient
async function createPatient(data: FHIRPatient) {
  try {
    const newPatient = await client.resources.Patient.create(data);
    console.log('Patient created:', newPatient);
    return newPatient;
  } catch (error) {
    console.error('Error creating patient:', error.message);
    throw error;
  }
}

// Example: Performing a FHIR search
async function searchPatients(parameters: object) {
  try {
    const searchResult = await client.resources.Patient.search(parameters);
    console.log(`Found ${searchResult.total} patients`);
    return searchResult.entry.map(entry => entry.resource);
  } catch (error) {
    console.error('Error searching patients:', error.message);
    throw error;
  }
}
```

#### Advanced Features

```typescript
// Configuring request options
const client = new FHIRClient({
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

// Using FHIR operations
async function executePatientEverything(patientId: string) {
  // $everything operation retrieves all available information about a patient
  const result = await client.resources.Patient.operation('$everything', { id: patientId });
  console.log('Patient everything bundle:', result);
  return result;
}
```

<a name="python"></a>
### Python

#### Installation

```bash
# Using pip
pip install cmm-fhir-interop

# Using poetry
poetry add cmm-fhir-interop
```

#### Initialization

```python
from cmm_fhir_interop import FHIRClient

# Using API key authentication
client = FHIRClient(
    api_key="your-api-key",
    environment="production"  # or "sandbox" for testing
)

# Using OAuth authentication
client = FHIRClient(
    client_id="your-client-id",
    client_secret="your-client-secret",
    environment="production"  # or "sandbox" for testing
)

# Using SMART on FHIR authentication
client = FHIRClient(
    smart_auth={
        "client_id": "your-smart-client-id",
        "redirect_uri": "https://your-app/callback",
        "scope": "launch/patient patient/*.read"
    },
    environment="production"
)

# Using Azure AD authentication (for internal applications)
client = FHIRClient(
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
# Example: Retrieving a patient
def get_patient(patient_id):
    try:
        patient = client.resources.Patient.get(patient_id)
        print(f"Patient retrieved: {patient}")
        return patient
    except Exception as e:
        if hasattr(e, "status_code") and e.status_code == 404:
            print("Patient not found")
        else:
            print(f"Error retrieving patient: {str(e)}")
        raise

# Example: Creating a patient
def create_patient(data):
    try:
        new_patient = client.resources.Patient.create(data)
        print(f"Patient created: {new_patient}")
        return new_patient
    except Exception as e:
        print(f"Error creating patient: {str(e)}")
        raise
        
# Example: Performing a FHIR search
def search_patients(parameters):
    try:
        search_result = client.resources.Patient.search(parameters)
        print(f"Found {search_result.total} patients")
        return [entry.resource for entry in search_result.entry]
    except Exception as e:
        print(f"Error searching patients: {str(e)}")
        raise
```

<a name="java"></a>
### Java

#### Installation

Maven:
```xml
<dependency>
    <groupId>com.covermymeds</groupId>
    <artifactId>fhir-interop</artifactId>
    <version>1.0.0</version>
</dependency>
```

Gradle:
```groovy
implementation 'com.covermymeds:fhir-interop:1.0.0'
```

#### Initialization

```java
import com.covermymeds.fhirinterop.FHIRClient;
import com.covermymeds.fhirinterop.FHIRClientConfig;

// Using API key authentication
FHIRClient client = FHIRClient.builder()
    .apiKey("your-api-key")
    .environment("production") // or "sandbox" for testing
    .build();

// Using OAuth authentication
FHIRClient client = FHIRClient.builder()
    .clientId("your-client-id")
    .clientSecret("your-client-secret")
    .environment("production") // or "sandbox" for testing
    .build();

// Using SMART on FHIR authentication
FHIRClient client = FHIRClient.builder()
    .smartAuthentication(SmartAuthConfig.builder()
        .clientId("your-smart-client-id")
        .redirectUri("https://your-app/callback")
        .scope("launch/patient patient/*.read")
        .build())
    .environment("production")
    .build();

// Using Azure AD authentication (for internal applications)
FHIRClient client = FHIRClient.builder()
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
// Example: Retrieving a patient
public Patient getPatient(String patientId) {
    try {
        Patient patient = client.resources().Patient().get(patientId);
        System.out.println("Patient retrieved: " + patient);
        return patient;
    } catch (ResourceNotFoundException e) {
        System.err.println("Patient not found");
        throw e;
    } catch (FHIRException e) {
        System.err.println("Error retrieving patient: " + e.getMessage());
        throw e;
    }
}

// Example: Creating a patient
public Patient createPatient(Patient patientData) {
    try {
        Patient newPatient = client.resources().Patient().create(patientData);
        System.out.println("Patient created: " + newPatient);
        return newPatient;
    } catch (FHIRException e) {
        System.err.println("Error creating patient: " + e.getMessage());
        throw e;
    }
}

// Example: Performing a FHIR search
public List<Patient> searchPatients(Map<String, List<String>> parameters) {
    try {
        Bundle searchResult = client.resources().Patient().search(parameters);
        System.out.println("Found " + searchResult.getTotal() + " patients");
        
        List<Patient> patients = searchResult.getEntry().stream()
            .map(entry -> (Patient) entry.getResource())
            .collect(Collectors.toList());
            
        return patients;
    } catch (FHIRException e) {
        System.err.println("Error searching patients: " + e.getMessage());
        throw e;
    }
}
```

<a name="c-sharp"></a>
### C#

#### Installation

```bash
# Using .NET CLI
dotnet add package CoverMyMeds.FHIRInterop

# Using Package Manager
Install-Package CoverMyMeds.FHIRInterop
```

#### Initialization

```csharp
using CoverMyMeds.FHIRInterop;

// Using API key authentication
var client = new FHIRClient(new FHIRClientOptions
{
    ApiKey = "your-api-key",
    Environment = Environment.Production // or Environment.Sandbox for testing
});

// Using OAuth authentication
var client = new FHIRClient(new FHIRClientOptions
{
    ClientId = "your-client-id",
    ClientSecret = "your-client-secret",
    Environment = Environment.Production // or Environment.Sandbox for testing
});

// Using SMART on FHIR authentication
var client = new FHIRClient(new FHIRClientOptions
{
    SmartAuthentication = new SmartAuthenticationOptions
    {
        ClientId = "your-smart-client-id",
        RedirectUri = "https://your-app/callback",
        Scope = "launch/patient patient/*.read"
    },
    Environment = Environment.Production
});

// Using Azure AD authentication (for internal applications)
var client = new FHIRClient(new FHIRClientOptions
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
// Example: Retrieving a patient
public async Task<Patient> GetPatientAsync(string patientId)
{
    try
    {
        var patient = await client.Resources.Patient.GetAsync(patientId);
        Console.WriteLine($"Patient retrieved: {patient}");
        return patient;
    }
    catch (ResourceNotFoundException)
    {
        Console.Error.WriteLine("Patient not found");
        throw;
    }
    catch (FHIRException ex)
    {
        Console.Error.WriteLine($"Error retrieving patient: {ex.Message}");
        throw;
    }
}

// Example: Creating a patient
public async Task<Patient> CreatePatientAsync(Patient patientData)
{
    try
    {
        var newPatient = await client.Resources.Patient.CreateAsync(patientData);
        Console.WriteLine($"Patient created: {newPatient}");
        return newPatient;
    }
    catch (FHIRException ex)
    {
        Console.Error.WriteLine($"Error creating patient: {ex.Message}");
        throw;
    }
}

// Example: Performing a FHIR search
public async Task<IEnumerable<Patient>> SearchPatientsAsync(Dictionary<string, List<string>> parameters)
{
    try
    {
        var searchResult = await client.Resources.Patient.SearchAsync(parameters);
        Console.WriteLine($"Found {searchResult.Total} patients");
        
        var patients = searchResult.Entry
            .Select(entry => entry.Resource as Patient)
            .Where(patient => patient != null);
            
        return patients;
    }
    catch (FHIRException ex)
    {
        Console.Error.WriteLine($"Error searching patients: {ex.Message}");
        throw;
    }
}
```

<a name="ruby"></a>
### Ruby

#### Installation

```bash
# Using gem
gem install cmm-fhir-interop

# In your Gemfile
gem 'cmm-fhir-interop', '~> 1.0'
```

#### Initialization

```ruby
require 'cmm/fhir_interop'

# Using API key authentication
client = CMM::FHIRInterop::Client.new(
  api_key: 'your-api-key',
  environment: :production # or :sandbox for testing
)

# Using OAuth authentication
client = CMM::FHIRInterop::Client.new(
  client_id: 'your-client-id',
  client_secret: 'your-client-secret',
  environment: :production # or :sandbox for testing
)

# Using SMART on FHIR authentication
client = CMM::FHIRInterop::Client.new(
  smart_auth: {
    client_id: 'your-smart-client-id',
    redirect_uri: 'https://your-app/callback',
    scope: 'launch/patient patient/*.read'
  },
  environment: :production
)
```

#### Basic Usage Example

```ruby
# Example: Retrieving a patient
def get_patient(patient_id)
  begin
    patient = client.resources.Patient.get(patient_id)
    puts "Patient retrieved: #{patient}"
    patient
  rescue CMM::FHIRInterop::ResourceNotFoundError
    puts "Patient not found"
    raise
  rescue CMM::FHIRInterop::Error => e
    puts "Error retrieving patient: #{e.message}"
    raise
  end
end

# Example: Creating a patient
def create_patient(data)
  begin
    new_patient = client.resources.Patient.create(data)
    puts "Patient created: #{new_patient}"
    new_patient
  rescue CMM::FHIRInterop::Error => e
    puts "Error creating patient: #{e.message}"
    raise
  end
end

# Example: Performing a FHIR search
def search_patients(parameters)
  begin
    search_result = client.resources.Patient.search(parameters)
    puts "Found #{search_result.total} patients"
    search_result.entry.map(&:resource)
  rescue CMM::FHIRInterop::Error => e
    puts "Error searching patients: #{e.message}"
    raise
  end
end
```

<a name="go"></a>
### Go

#### Installation

```bash
go get github.com/covermymeds/fhir-interop-go
```

#### Initialization

```go
import "github.com/covermymeds/fhir-interop-go"

// Using API key authentication
client, err := fhirinterop.NewClient(&fhirinterop.ClientOptions{
    APIKey:      "your-api-key",
    Environment: fhirinterop.EnvironmentProduction, // or fhirinterop.EnvironmentSandbox for testing
})
if err != nil {
    log.Fatalf("Failed to create client: %v", err)
}

// Using OAuth authentication
client, err := fhirinterop.NewClient(&fhirinterop.ClientOptions{
    ClientID:     "your-client-id",
    ClientSecret: "your-client-secret",
    Environment:  fhirinterop.EnvironmentProduction, // or fhirinterop.EnvironmentSandbox for testing
})
if err != nil {
    log.Fatalf("Failed to create client: %v", err)
}

// Using SMART on FHIR authentication
client, err := fhirinterop.NewClient(&fhirinterop.ClientOptions{
    SmartAuth: &fhirinterop.SmartAuthOptions{
        ClientID:    "your-smart-client-id",
        RedirectURI: "https://your-app/callback",
        Scope:       "launch/patient patient/*.read",
    },
    Environment: fhirinterop.EnvironmentProduction,
})
if err != nil {
    log.Fatalf("Failed to create client: %v", err)
}
```

#### Basic Usage Example

```go
// Example: Retrieving a patient
func getPatient(patientID string) (*fhirinterop.Patient, error) {
    patient, err := client.Resources.Patient.Get(context.Background(), patientID)
    if err != nil {
        if fhirinterop.IsResourceNotFound(err) {
            log.Printf("Patient not found")
            return nil, err
        }
        log.Printf("Error retrieving patient: %v", err)
        return nil, err
    }
    log.Printf("Patient retrieved: %+v", patient)
    return patient, nil
}

// Example: Creating a patient
func createPatient(patientData *fhirinterop.Patient) (*fhirinterop.Patient, error) {
    newPatient, err := client.Resources.Patient.Create(context.Background(), patientData)
    if err != nil {
        log.Printf("Error creating patient: %v", err)
        return nil, err
    }
    log.Printf("Patient created: %+v", newPatient)
    return newPatient, nil
}

// Example: Performing a FHIR search
func searchPatients(parameters map[string][]string) ([]*fhirinterop.Patient, error) {
    searchResult, err := client.Resources.Patient.Search(context.Background(), parameters)
    if err != nil {
        log.Printf("Error searching patients: %v", err)
        return nil, err
    }
    
    log.Printf("Found %d patients", searchResult.Total)
    
    patients := make([]*fhirinterop.Patient, 0, len(searchResult.Entry))
    for _, entry := range searchResult.Entry {
        patients = append(patients, entry.Resource.(*fhirinterop.Patient))
    }
    
    return patients, nil
}
```

## Common Operations

The following sections demonstrate common FHIR operations across all supported client libraries. For language-specific examples, see the appropriate language section above.

### Pagination

All client libraries provide consistent pagination helpers for listing FHIR resources:

```typescript
// TypeScript example
async function getAllPatients() {
  // Option 1: Manual pagination
  let page = 1;
  const pageSize = 100;
  let hasMore = true;
  let allPatients = [];
  
  while (hasMore) {
    const response = await client.resources.Patient.search({
      _count: pageSize,
      _page: page
    });
    
    allPatients = allPatients.concat(response.entry.map(e => e.resource));
    hasMore = response.link.some(link => link.relation === 'next');
    page++;
  }
  
  return allPatients;
  
  // Option 2: Using pagination helpers
  const patients = await client.resources.Patient.searchAll({
    _count: 100,
    maxPages: 10 // Optional limit
  });
  
  return patients.map(entry => entry.resource);
}
```

### Filtering and Sorting

```typescript
// TypeScript example
async function filterPatients() {
  const searchBundle = await client.resources.Patient.search({
    // Standard FHIR search parameters
    family: 'Smith',
    given: 'John',
    gender: 'male',
    birthdate: 'gt2000-01-01',
    _sort: 'family,given',
    _count: 50
  });
  
  return searchBundle.entry.map(entry => entry.resource);
}
```

### Error Handling

All client libraries provide consistent error types and patterns:

```typescript
// TypeScript example
async function handleErrors() {
  try {
    const result = await client.resources.Patient.get('non-existent-id');
    return result;
  } catch (error) {
    // Specific error types
    if (error instanceof ResourceNotFoundError) {
      console.error('Patient not found:', error.message);
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
    } else if (error instanceof FHIRError) {
      console.error('FHIR error:', error.message);
      // All other FHIR API errors
      console.error('Status:', error.status);
      console.error('Operation outcome:', error.outcome);
      console.error('Request ID:', error.requestId);
    } else {
      // Network or unexpected errors
      console.error('Unexpected error:', error);
    }
    throw error;
  }
}
```

### FHIR Operations

FHIR defines special operations beyond basic CRUD that can be executed on resources:

```typescript
// TypeScript example for $everything operation
async function patientEverything(patientId) {
  const bundle = await client.resources.Patient.operation('$everything', { 
    id: patientId 
  });
  
  return bundle;
}

// TypeScript example for $validate operation
async function validatePatient(patientData) {
  try {
    const result = await client.resources.Patient.operation('$validate', {
      resource: patientData
    });
    
    console.log('Patient data is valid!');
    return true;
  } catch (error) {
    console.error('Patient data validation failed:', error.message);
    if (error.outcome) {
      // Process OperationOutcome for details
      error.outcome.issue.forEach(issue => {
        console.error(`- ${issue.severity}: ${issue.diagnostics}`);
      });
    }
    return false;
  }
}
```

### Request Customization

All client libraries allow customizing requests:

```typescript
// TypeScript example
async function customizeRequest() {
  // One-time request customization
  const patient = await client.resources.Patient.get('patient-id', {
    headers: {
      'x-custom-header': 'custom-value',
      'prefer': 'handling=strict'
    },
    timeout: 5000, // 5 seconds
    retries: 0 // Disable retries for this request
  });
  
  return patient;
}
```

### Mocking and Testing

All client libraries provide mocking capabilities for testing:

```typescript
// TypeScript example - Using the test utilities
import { MockFHIRClient } from '@cmm/fhir-interop/testing';

describe('Patient Operations', () => {
  let mockClient;
  
  beforeEach(() => {
    // Create a mock client
    mockClient = new MockFHIRClient();
    
    // Mock specific responses
    mockClient.resources.Patient.get.mockResolvedValue({
      resourceType: 'Patient',
      id: 'mock-id',
      name: [{
        family: 'Smith',
        given: ['John']
      }],
      gender: 'male',
      birthDate: '1970-01-01'
    });
    
    mockClient.resources.Patient.create.mockImplementation(data => ({
      ...data,
      id: 'new-mock-id',
      meta: {
        versionId: '1',
        lastUpdated: new Date().toISOString()
      }
    }));
  });
  
  test('should retrieve a patient', async () => {
    const patient = await mockClient.resources.Patient.get('mock-id');
    expect(patient.id).toBe('mock-id');
    expect(patient.name[0].family).toBe('Smith');
    expect(mockClient.resources.Patient.get).toHaveBeenCalledWith('mock-id');
  });
  
  test('should create a patient', async () => {
    const data = { 
      resourceType: 'Patient',
      name: [{
        family: 'Doe',
        given: ['Jane']
      }]
    };
    const patient = await mockClient.resources.Patient.create(data);
    expect(patient.id).toBe('new-mock-id');
    expect(patient.name[0].family).toBe('Doe');
    expect(mockClient.resources.Patient.create).toHaveBeenCalledWith(data);
  });
});
```

## Migrating Between Versions

### Migrating from v1.x to v2.x

The v2.x release includes several breaking changes:

1. **Authentication Changes**
   - OAuth flows now require specifying scopes
   - API key format changed from `key_xxxxx` to `cmm_fhir_xxxxx`
   - SMART on FHIR authentication is now the default for healthcare applications

2. **API Structure Changes**
   - Resource APIs have moved to `client.resources.[ResourceType].*` namespace
   - Response structure now includes full FHIR Bundle for search operations
   - Introduction of strong typing for all FHIR resources

3. **Migration Steps**

```typescript
// Old v1.x code
const client = new FHIRClient({
  apiKey: 'key_xxxxx'
});

const patient = await client.getPatient('patient-id');

// New v2.x code
const client = new FHIRClient({
  apiKey: 'cmm_fhir_xxxxx'
});

const patient = await client.resources.Patient.get('patient-id');
```

For a complete migration guide, see the [v2.x Migration Guide](https://docs.covermymeds.com/fhir-interop/migration-v2).

## FAQ

### Which library should I choose?

- **TypeScript/JavaScript**: Best for web applications, SMART on FHIR apps, and serverless functions.
- **Python**: Good choice for data processing, healthcare analytics, and machine learning applications.
- **Java**: Ideal for enterprise applications, EHR integrations, and Android healthcare applications.
- **C#**: Great for .NET applications, Windows services, and Azure healthcare solutions.
- **Ruby**: Well-suited for web applications using Ruby on Rails.
- **Go**: Excellent for high-performance microservices and cloud-native healthcare applications.

### How do I report issues with client libraries?

For bugs, feature requests, or documentation improvements:
1. Check existing issues in our GitHub repository
2. Open a new issue with detailed reproduction steps
3. Include client library version, language version, and OS information

GitHub repositories:
- TypeScript: [github.com/covermymeds/fhir-interop-js](https://github.com/covermymeds/fhir-interop-js)
- Python: [github.com/covermymeds/fhir-interop-python](https://github.com/covermymeds/fhir-interop-python)
- Java: [github.com/covermymeds/fhir-interop-java](https://github.com/covermymeds/fhir-interop-java)
- C#: [github.com/covermymeds/fhir-interop-dotnet](https://github.com/covermymeds/fhir-interop-dotnet)
- Ruby: [github.com/covermymeds/fhir-interop-ruby](https://github.com/covermymeds/fhir-interop-ruby)
- Go: [github.com/covermymeds/fhir-interop-go](https://github.com/covermymeds/fhir-interop-go)

### How are client libraries versioned?

All client libraries follow semantic versioning (MAJOR.MINOR.PATCH):
- MAJOR version increases indicate breaking changes
- MINOR version increases add functionality in a backward-compatible manner
- PATCH version increases include backward-compatible bug fixes

Libraries are updated when:
- New FHIR features are implemented
- New Implementation Guides are supported
- Bug fixes are implemented
- Dependencies need security updates
- Performance improvements are made

## Related Resources

- [FHIR Interoperability Platform Core APIs](../03-core-functionality/core-apis.md)
- [Local Development Setup](./local-setup.md)
- [FHIR Data Model](../03-core-functionality/data-model.md)
- [Troubleshooting Guide](./troubleshooting-guide.md)
- [SDK Release Notes](https://github.com/covermymeds/fhir-interop/releases)
- [HL7 FHIR Specification](https://hl7.org/fhir/)
- [SMART on FHIR Documentation](https://docs.smarthealthit.org/)