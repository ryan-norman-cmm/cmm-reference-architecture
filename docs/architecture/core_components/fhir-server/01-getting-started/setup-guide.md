# FHIR Server Setup Guide

## Introduction

The FHIR server acts as the system of record for healthcare resources, storing patient data, clinical observations, and administrative information in standardized formats defined by HL7. This guide provides instructions for setting up and configuring the Aidbox FHIR server on your local machine. Aidbox is a powerful FHIR server implementation that provides a comprehensive set of features for healthcare data management and interoperability.

### Quick Start

1. Install Docker and Docker Compose
2. Obtain an Aidbox license from [Aidbox signup page](https://aidbox.app/ui/portal#/signup)
3. Create a `docker-compose.yml` file with the Aidbox configuration
4. Configure environment variables in `.env`
5. Run `docker-compose up -d` to start the Aidbox FHIR server
6. Access the Aidbox UI at `http://localhost:8888`

### Related Components

- [FHIR Client Authentication](fhir-client-authentication.md): Configure secure access to your FHIR server
- [Saving FHIR Resources](saving-fhir-resources.md): Learn how to store data in your FHIR server
- [Architecture Decisions](fhir-server-decisions.md) (Coming Soon): Understand the rationale behind implementation choices

## Prerequisites

Before proceeding with the FHIR server setup, ensure you have the following:

- Docker and Docker Compose (latest stable versions)
- Git (for version control)
- Valid Aidbox developer license

### Obtaining an Aidbox License

For local development, follow these steps to get your personal Aidbox developer license:

1. Go to the [Aidbox signup page](https://aidbox.app/ui/portal#/signup)
2. Fill in your email and create a password
3. Confirm your email by clicking the link sent to your inbox
4. Complete your profile
5. Click on the "New license" button
   - Select the "Dev" Developer License
   - Give it a name (e.g., "FHIR-Local-Dev")
   - Select "Self-Hosted"
   - Click "Create"
6. Copy the License Key for configuration

## Local Development Environment

### Setup Process

1. Create a project directory:

```bash
mkdir aidbox-fhir-server
cd aidbox-fhir-server
```

2. Create a Docker Compose file (`docker-compose.yml`):

```yaml
version: '3.7'

services:
  aidbox:
    image: healthsamurai/aidboxone:latest
    depends_on:
      - devbox-db
    ports:
      - "8888:8888"
    environment:
      AIDBOX_LICENSE: ${AIDBOX_LICENSE}
      AIDBOX_CLIENT_ID: root
      AIDBOX_CLIENT_SECRET: secret
      AIDBOX_ADMIN_ID: admin
      AIDBOX_ADMIN_PASSWORD: password
      AIDBOX_PORT: 8888
      AIDBOX_FHIR_VERSION: 4.0.1
      AIDBOX_VALIDATION_ENGINE: fhir-schema
      PGHOST: devbox-db
      PGPORT: 5432
      PGUSER: postgres
      PGPASSWORD: postgres
      PGDATABASE: aidbox

  devbox-db:
    image: postgres:13
    ports:
      - "5432:5432"
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: aidbox
    volumes:
      - aidbox-pgdata:/var/lib/postgresql/data

volumes:
  aidbox-pgdata:
```

3. Create an environment file (`.env`):

```
AIDBOX_LICENSE=your-license-key-from-aidbox-portal
```

4. Start the Aidbox container:

```bash
docker compose up
```

5. Verify the server is running by accessing the Aidbox UI:

```
http://localhost:8888/
```

Log in with the default credentials:
- Username: `admin`
- Password: `password`

### Key Configuration Parameters

The standard Aidbox development configuration includes:

```
# Aidbox core configuration
AIDBOX_CLIENT_ID=root
AIDBOX_CLIENT_SECRET=secret
AIDBOX_ADMIN_ID=admin
AIDBOX_ADMIN_PASSWORD=password
AIDBOX_PORT=8888
AIDBOX_FHIR_VERSION=4.0.1
AIDBOX_VALIDATION_ENGINE=fhir-schema

# PostgreSQL Configuration
PGPORT=5432
PGUSER=postgres
PGPASSWORD=postgres
PGDATABASE=aidbox
```

> **Important Note:** Never commit sensitive information like license keys to a repository. Always add the `.env` file to your `.gitignore`.

## Working with Aidbox SDK

The Aidbox SDK provides client libraries for interacting with the FHIR server programmatically. This section covers how to install and use the SDK in your applications.

### TypeScript SDK

#### Installation

```bash
# Using npm
npm install @aidbox/sdk-r4
```

#### Basic Usage

```typescript
import { AidboxClient } from '@aidbox/sdk-r4';
import { Patient } from '@aidbox/sdk-r4/types';

// Connect to local development environment
const client = new AidboxClient({
  baseUrl: 'http://localhost:8888',
  auth: {
    type: 'basic',
    username: 'root',
    password: 'secret'
  }
});

// Fetch a patient
async function getPatient(id: string): Promise<Patient> {
  try {
    const patient = await client.read<Patient>({
      resourceType: 'Patient',
      id: id
    });
    return patient;
  } catch (error) {
    console.error('Error fetching patient:', error);
    throw error;
  }
}

// Create a new patient
async function createPatient(patientData: Partial<Patient>): Promise<Patient> {
  try {
    const patient = await client.create<Patient>({
      resourceType: 'Patient',
      ...patientData
    });
    return patient;
  } catch (error) {
    console.error('Error creating patient:', error);
    throw error;
  }
}
```

### TypeScript SDK with React

#### Installation

```bash
npm install @aidbox/sdk-r4 react react-dom
```

#### Basic Usage in React Application

```typescript
import React, { useEffect, useState } from 'react';
import { AidboxClient } from '@aidbox/sdk-r4';
import { Patient } from '@aidbox/sdk-r4/types';

// Configure the Aidbox client
const client = new AidboxClient({
  baseUrl: 'http://localhost:8888',
  auth: {
    type: 'basic',
    username: 'root',
    password: 'secret'
  }
});

// Patient component using the SDK
const PatientDetails: React.FC<{ patientId: string }> = ({ patientId }) => {
  const [patient, setPatient] = useState<Patient | null>(null);
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    const fetchPatient = async () => {
      try {
        setLoading(true);
        const data = await client.read<Patient>({
          resourceType: 'Patient',
          id: patientId
        });
        setPatient(data);
        setError(null);
      } catch (err) {
        setError(err instanceof Error ? err : new Error('Failed to fetch patient'));
        setPatient(null);
      } finally {
        setLoading(false);
      }
    };

    fetchPatient();
  }, [patientId]);

  if (loading) return <div>Loading patient...</div>;
  if (error) return <div>Error loading patient: {error.message}</div>;
  if (!patient) return <div>No patient found</div>;

  const patientName = patient.name?.[0]?.given?.join(' ') || 'Unknown';
  const familyName = patient.name?.[0]?.family || '';

  return (
    <div>
      <h2>Patient: {patientName} {familyName}</h2>
      <p>ID: {patient.id}</p>
      <p>Gender: {patient.gender || 'Not specified'}</p>
      <p>Birth Date: {patient.birthDate || 'Not specified'}</p>
    </div>
  );
};

// App component
const App: React.FC = () => {
  return (
    <div className="App">
      <h1>FHIR Patient Viewer</h1>
      <PatientDetails patientId="123" />
    </div>
  );
};
```

## Implementation Guide Configuration

Aidbox supports FHIR Implementation Guides (IGs) to define profiles, extensions, value sets, and other FHIR artifacts. This section explains how to configure and use IGs in your Aidbox instance.

### Loading Implementation Guides

Aidbox can be configured with various implementation guides, such as:

1. **US Core Implementation Guide** - Defines the minimum conformance requirements for accessing patient data
2. **Da Vinci Prior Authorization Support (PAS)** - Defines the exchange of clinical and administrative information for prior authorization workflows
3. **Da Vinci Coverage Requirements Discovery (CRD)** - Defines how payers can communicate coverage requirements to providers

### Custom Implementation Guide Configuration

To add a custom implementation guide to your Aidbox instance, you can use the Zen project approach:

1. Start your local Aidbox instance
2. Access the Aidbox UI at `http://localhost:8888`
3. Navigate to Configuration → FHIR Implementation Guides
4. Verify that the required IGs are listed as "Active"

### Adding Custom Implementation Guides

To add a custom IG to your local environment for testing:

1. Navigate to Configuration → FHIR Implementation Guides in the Aidbox UI
2. Click on "Add Implementation Guide"
3. Enter the IG canonical URL and version
4. Click "Add" to load the IG

For permanent addition, update the configuration in the `usp-aidbox-config` repository:

1. Edit the `igs.yaml` file in the repository
2. Add the new IG ID to the list
3. Create a pull request for review

## Troubleshooting

### Common Issues and Solutions

#### Local Development Issues

| | Expired tokens | Request new token or refresh token |
| Connection timeout | Network issues | Check network connectivity |
| | Server unreachable | Verify server is running |
| CORS errors in browser | CORS configuration | Configure CORS headers in Aidbox |

### Accessing Logs

To access logs for troubleshooting:

```bash
# View logs for Aidbox container
docker compose logs aidbox

# Follow logs in real-time
docker compose logs -f aidbox
```

### Getting Help

If you encounter issues not covered in this guide:

1. Refer to the [Aidbox documentation](https://docs.aidbox.app/) for more information
2. Join the [Aidbox Community Forum](https://community.aidbox.app/)
3. Check the [Aidbox GitHub repository](https://github.com/Aidbox/Issues) for known issues
