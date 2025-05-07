# FHIR Interoperability Platform Local Setup

This guide provides step-by-step instructions for setting up a local development environment for the FHIR Interoperability Platform based on Aidbox.

## Prerequisites

- [Docker](https://www.docker.com/products/docker-desktop/) and Docker Compose installed
- [Node.js](https://nodejs.org/) 18.x or higher
- [PostgreSQL](https://www.postgresql.org/download/) client tools (optional for direct DB access)
- Basic knowledge of HL7 FHIR® (Fast Healthcare Interoperability Resources)
- AWS credentials with appropriate permissions (for production integrations)
- Access to CoverMyMeds Artifactory for container images

## Step 1: Set Up Local Environment

Create a project directory and configuration files for the FHIR Interoperability Platform:

```bash
# Create project directory
mkdir fhir-platform && cd fhir-platform

# Create configuration files directory
mkdir -p config/aidbox
```

Create an environment file for Aidbox configuration:

```bash
# Create .env file with configuration
cat > .env << EOF
AIDBOX_LICENSE_KEY=your_aidbox_license_key
AIDBOX_FHIR_VERSION=4.0.1
AIDBOX_CLIENT_ID=root
AIDBOX_CLIENT_SECRET=secret
AIDBOX_ADMIN_PASSWORD=password

# Database configuration
PGPORT=5432
PGUSER=postgres
PGPASSWORD=postgres
PGDATABASE=aidbox
PGHOST=database
EOF
```

## Step 2: Configure Docker Compose

Create a Docker Compose file to set up the local environment:

```bash
# Create docker-compose.yml file
cat > docker-compose.yml << EOF
version: '3.8'

services:
  database:
    image: postgres:13
    ports:
      - "5432:5432"
    environment:
      POSTGRES_USER: \${PGUSER}
      POSTGRES_PASSWORD: \${PGPASSWORD}
      POSTGRES_DB: \${PGDATABASE}
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

  aidbox:
    image: healthsamurai/aidboxone:stable
    depends_on:
      database:
        condition: service_healthy
    ports:
      - "8888:8888"
    environment:
      PGPORT: \${PGPORT}
      PGUSER: \${PGUSER}
      PGPASSWORD: \${PGPASSWORD}
      PGDATABASE: \${PGDATABASE}
      PGHOST: \${PGHOST}
      AIDBOX_LICENSE_KEY: \${AIDBOX_LICENSE_KEY}
      AIDBOX_FHIR_VERSION: \${AIDBOX_FHIR_VERSION}
      AIDBOX_CLIENT_ID: \${AIDBOX_CLIENT_ID}
      AIDBOX_CLIENT_SECRET: \${AIDBOX_CLIENT_SECRET}
      AIDBOX_PORT: 8888
      AIDBOX_ADMIN_PASSWORD: \${AIDBOX_ADMIN_PASSWORD}
      BOX_FEATURES_SMART_ON_FHIR: "true"
    volumes:
      - ./config/aidbox:/aidbox

  # Optional: Event integration service for Kafka connectivity
  event-integration:
    image: cmm-docker.artifactory.aws.cmm.io/fhir-event-integration:latest
    depends_on:
      - aidbox
    environment:
      FHIR_BASE_URL: http://aidbox:8888
      FHIR_CLIENT_ID: \${AIDBOX_CLIENT_ID}
      FHIR_CLIENT_SECRET: \${AIDBOX_CLIENT_SECRET}
      KAFKA_BOOTSTRAP_SERVERS: kafka:9092
      KAFKA_TOPIC_PREFIX: fhir.
    ports:
      - "3000:3000"

volumes:
  pgdata:
EOF
```

## Step 3: Start the Environment

Launch the Docker Compose environment:

```bash
# Start the services
docker compose up -d

# Check if services are running
docker compose ps
```

Wait for all services to be healthy before proceeding. The Aidbox service may take a minute or two to fully initialize.

## Step 4: Configure FHIR Resources

Create a TypeScript script to initialize necessary FHIR resources:

```typescript
// setup-resources.ts
import axios from 'axios';

// Configuration
const config = {
  baseUrl: 'http://localhost:8888',
  clientId: 'root',
  clientSecret: 'secret',
};

/**
 * Initializes the FHIR server with required resources
 */
async function setupFhirResources(): Promise<void> {
  try {
    // Authenticate
    const authResponse = await axios.post(`${config.baseUrl}/auth/token`, {
      client_id: config.clientId,
      client_secret: config.clientSecret,
      grant_type: 'client_credentials',
    });
    
    const token = authResponse.data.access_token;
    
    // Client for authorized requests
    const client = axios.create({
      baseURL: config.baseUrl,
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
    });
    
    // Create example Patient resource
    await client.post('/fhir/Patient', {
      resourceType: 'Patient',
      id: 'example',
      name: [
        {
          family: 'Smith',
          given: ['John'],
        },
      ],
      gender: 'male',
      birthDate: '1970-01-01',
    });
    
    // Create example Organization resource
    await client.post('/fhir/Organization', {
      resourceType: 'Organization',
      id: 'cmm',
      name: 'CoverMyMeds',
      active: true,
    });
    
    console.log('Resources created successfully');
  } catch (error) {
    if (axios.isAxiosError(error)) {
      console.error('Error creating resources:', error.response?.data || error.message);
    } else {
      console.error('Unexpected error:', error);
    }
  }
}

// Run setup
setupFhirResources();
```

Install dependencies and run the script:

```bash
# Initialize a Node.js project
npm init -y

# Install required dependencies
npm install axios typescript ts-node @types/node

# Add TypeScript configuration
npx tsc --init

# Run the setup script
npx ts-node setup-resources.ts
```

## Step 5: Validate Setup

### Test Aidbox REST API

Create a script to validate the FHIR API is working correctly:

```typescript
// test-fhir-api.ts
import axios from 'axios';

/**
 * Tests the FHIR API by fetching a Patient resource
 */
async function testFhirApi(): Promise<void> {
  try {
    // Authenticate
    const authResponse = await axios.post('http://localhost:8888/auth/token', {
      client_id: 'root',
      client_secret: 'secret',
      grant_type: 'client_credentials',
    });
    
    const token = authResponse.data.access_token;
    
    // Test Patient endpoint
    const patientResponse = await axios.get('http://localhost:8888/fhir/Patient/example', {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    });
    
    console.log('Patient resource retrieved successfully:');
    console.log(JSON.stringify(patientResponse.data, null, 2));
    
    // Test search functionality
    const searchResponse = await axios.get('http://localhost:8888/fhir/Patient?family=Smith', {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    });
    
    console.log(`Found ${searchResponse.data.total} patients with family name Smith`);
    
    console.log('FHIR API is working correctly!');
  } catch (error) {
    if (axios.isAxiosError(error)) {
      console.error('API test failed:', error.response?.data || error.message);
    } else {
      console.error('Unexpected error:', error);
    }
  }
}

// Run test
testFhirApi();
```

Run the test script:

```bash
npx ts-node test-fhir-api.ts
```

### Access the Aidbox UI

The Aidbox admin UI is available at http://localhost:8888/. Log in using the configured credentials:

- Username: root
- Password: secret (or the value you set for AIDBOX_CLIENT_SECRET)

In the Aidbox UI, you can:
- Browse and edit FHIR resources
- Use the REST console to test API calls
- Configure access policies and SMART on FHIR applications
- Monitor server logs and performance

## Reference Vendor Quick Start

This setup is based on Health Samurai's Aidbox, a commercial FHIR server implementation. For more detailed configuration options and official documentation, refer to:

- [Aidbox Getting Started Guide](https://docs.aidbox.app/getting-started)
- [Aidbox Configuration Reference](https://docs.aidbox.app/reference/configuration)
- [Aidbox FHIR API Documentation](https://docs.aidbox.app/api-1/fhir-api)
- [SMART on FHIR Implementation](https://docs.aidbox.app/security-and-access-control-1/smart-on-fhir)

## Setup SMART on FHIR Client

To configure a SMART on FHIR client application, create the client registration:

```typescript
// setup-smart-client.ts
import axios from 'axios';

async function setupSmartClient(): Promise<void> {
  try {
    // Authenticate
    const authResponse = await axios.post('http://localhost:8888/auth/token', {
      client_id: 'root',
      client_secret: 'secret',
      grant_type: 'client_credentials',
    });
    
    const token = authResponse.data.access_token;
    
    // Create SMART on FHIR client
    const client = {
      resourceType: 'Client',
      id: 'example-smart-app',
      secret: 'smart-secret',
      grant_types: ['authorization_code', 'refresh_token'],
      auth: {
        authorization_code: {
          redirect_uri: [
            'http://localhost:4000/callback',
          ],
        },
      },
      first_party: true,
      smart: {
        launch_uri: 'http://localhost:4000/launch.html',
      },
    };
    
    await axios.put(
      'http://localhost:8888/Client/example-smart-app',
      client,
      {
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
      }
    );
    
    console.log('SMART on FHIR client registered successfully');
  } catch (error) {
    if (axios.isAxiosError(error)) {
      console.error('Error registering SMART client:', error.response?.data || error.message);
    } else {
      console.error('Unexpected error:', error);
    }
  }
}

// Run setup
setupSmartClient();
```

## Configure Event-Driven Integration

To integrate with the Event-Driven Architecture, configure FHIR Subscription resources that will trigger events when resources change:

```typescript
// setup-subscriptions.ts
import axios from 'axios';

async function setupSubscriptions(): Promise<void> {
  try {
    // Authenticate
    const authResponse = await axios.post('http://localhost:8888/auth/token', {
      client_id: 'root',
      client_secret: 'secret',
      grant_type: 'client_credentials',
    });
    
    const token = authResponse.data.access_token;
    
    // Create a subscription for Patient resources
    const subscription = {
      resourceType: 'Subscription',
      status: 'active',
      reason: 'Monitor all patient activity',
      criteria: 'Patient?_format=application/fhir+json',
      channel: {
        type: 'rest-hook',
        endpoint: 'http://event-integration:3000/fhir-events',
        payload: 'application/fhir+json',
        header: ['Authorization: Bearer ${token}'],
      },
    };
    
    await axios.post(
      'http://localhost:8888/fhir/Subscription',
      subscription,
      {
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
      }
    );
    
    console.log('FHIR Subscription configured successfully');
  } catch (error) {
    if (axios.isAxiosError(error)) {
      console.error('Error configuring subscription:', error.response?.data || error.message);
    } else {
      console.error('Unexpected error:', error);
    }
  }
}

// Run setup
setupSubscriptions();
```

## Troubleshooting

### Common Issues

1. **Database Connection Failures**
   - Check PostgreSQL container is running: `docker compose ps database`
   - Verify connection parameters in `.env` file
   - Review logs: `docker compose logs database`

2. **Aidbox License Issues**
   - Ensure you have a valid Aidbox license key
   - Check license expiration in Aidbox logs: `docker compose logs aidbox`

3. **API Authentication Failures**
   - Verify client credentials match those in `.env` file
   - Ensure you're using the correct token in Authorization header
   - Check for API errors in the Aidbox logs

4. **SMART on FHIR Configuration**
   - Validate redirect URIs match your application configuration
   - Ensure client registration includes all required grant types
   - Check SMART launch context parameters

If you encounter persistent issues, review the [Aidbox Troubleshooting Guide](https://docs.aidbox.app/getting-started/troubleshooting).

## Next Steps

- Explore the [Core APIs](../03-core-functionality/core-apis.md) to understand available endpoints
- Learn about the [Data Model](../03-core-functionality/data-model.md) to understand FHIR resource structure
- Implement [Advanced Use Cases](../04-advanced-patterns/advanced-use-cases.md) such as clinical workflows
- Set up [Access Controls](../05-governance-compliance/access-controls.md) for securing your FHIR resources

## Related Resources

- [FHIR Interoperability Platform Overview](../01-overview/overview.md)
- [FHIR Interoperability Platform Architecture](../01-overview/architecture.md)
- [FHIR Interoperability Platform Key Concepts](../01-overview/key-concepts.md)
- [Event-Driven Architecture Integration Points](../../event-driven-architecture/01-overview/integration-points.md)
- [HL7 FHIR Specification](https://hl7.org/fhir/)
- [Aidbox Documentation](https://docs.aidbox.app/)