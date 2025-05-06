# FHIR Interoperability Platform Quick Start

This guide provides a step-by-step process to help you quickly get started with the FHIR Interoperability Platform core component.

## Prerequisites
- Access to the CMM platform environment (development, staging, or production)
- Provisioned credentials for the FHIR server (Aidbox username/password or API key)
- Network access to the FHIR Interoperability Platform endpoints
- Familiarity with HL7 FHIR concepts (resources, operations, REST/GraphQL APIs)

## Step 1: Run Aidbox Locally & Prepare Development Environment

> **Recommended:** Follow the official Aidbox guide for running Aidbox locally: [Aidbox - Run Locally (Official Docs)](https://docs.aidbox.app/getting-started/run-aidbox-locally)

### Install Docker
Aidbox is distributed as a Docker container. Install Docker Desktop from [https://www.docker.com/products/docker-desktop/](https://www.docker.com/products/docker-desktop/).

### Generate Your Aidbox Developer License
- Go to [Aidbox Portal Signup](https://aidbox.app/ui/portal#/signup) and create an account.
- Confirm your email and complete your profile.
- On the Licenses page, click **New license** → select **Dev** Developer License → choose **Self-Hosted** → click **Create**.
- Copy the license key and set it as the `AIDBOX_LICENSE` environment variable in your `.env` file.

### Create a Docker Compose File
Create a `docker-compose.yml` file as described in the [official docs](https://docs.aidbox.app/getting-started/run-aidbox-locally#docker-compose-example):

```yaml
version: '3.7'
services:
  aidbox:
    image: healthsamurai/aidboxone:latest
    ports:
      - "8888:8080"
    env_file:
      - .env
```

### Create a `.env` File
Add your license and a secure password to `.env`:

```env
AIDBOX_LICENSE=your-license-key-here
AIDBOX_PROJECT_ID=your-project-id
AIDBOX_ADMIN_PASSWORD=your-strong-password
```

> For more environment variables and options, see [Aidbox Environment Reference](https://docs.aidbox.app/reference/environment-variables).

### Start Aidbox
Run:
```sh
docker-compose up
```
Aidbox will be available at [http://localhost:8888](http://localhost:8888) by default.

For troubleshooting, advanced configuration, and more, refer to [the official Aidbox getting started guide](https://docs.aidbox.app/getting-started/run-aidbox-locally).

## Step 2: Install Dependencies
Install the Aidbox SDK for TypeScript (FHIR R4):

```sh
npm install @aidbox/sdk-r4
```

## Step 3: Connect to the FHIR Server
Use the provided credentials and endpoint to connect to the Aidbox FHIR server (R4) as a client:

```typescript
import { AidboxClient } from '@aidbox/sdk-r4';

const client = new AidboxClient({
  url: 'https://YOUR_AIDBOX_SERVER_URL',
  auth: {
    username: 'YOUR_USERNAME',
    password: 'YOUR_PASSWORD',
  },
});
```

## Step 4: Perform a Basic Operation
Read a Patient resource (TypeScript example):

```typescript
const patient = await client.fhirRead('Patient', 'example-patient-id');
console.log(patient);
```

Create a Patient resource:

```typescript
const newPatient = await client.fhirCreate('Patient', {
  resourceType: 'Patient',
  name: [{ given: ['John'], family: 'Doe' }],
  gender: 'male',
  birthDate: '1980-01-01',
});
console.log(newPatient);
```

## Step 5: Validate Setup
- Ensure you can read and create resources without errors using your client or integration tests.
- Access the Aidbox Admin UI at [http://localhost:8888](http://localhost:8888) (or your configured endpoint) and log in with your admin credentials.
- In the Admin UI, navigate to the "Resources" section to verify that your Patient resource (or other test data) appears and is correct.
- Review Aidbox logs and dashboard for any errors or issues.
- Troubleshoot authentication, permission, or network issues as needed. See [Aidbox troubleshooting docs](https://docs.aidbox.app/troubleshooting) for more guidance.

## Next Steps
- [Explore Advanced FHIR Operations](../03-advanced-topics/advanced-fhir-operations.md)
- [Integration Guide: Event Broker](../../event-broker/01-getting-started/quick-start.md)
- [Integration Guide: Federated Graph API](../../federated-graph-api/01-getting-started/quick-start.md)
- [Integration Guide: API Marketplace](../../api-marketplace/01-getting-started/quick-start.md)
- [Best Practices: FHIR Resource Design](../03-advanced-topics/resource-design.md)
- [Error Handling & Troubleshooting](../03-advanced-topics/error-handling.md)

## Related Resources
- [HL7 FHIR Documentation](https://hl7.org/fhir/)
- [Aidbox Platform Overview](https://docs.aidbox.app/overview)
- [FHIR Interoperability Platform Overview](./overview.md)
- [FHIR Interoperability Platform Architecture](./architecture.md)
- [FHIR Interoperability Platform Key Concepts](./key-concepts.md)
