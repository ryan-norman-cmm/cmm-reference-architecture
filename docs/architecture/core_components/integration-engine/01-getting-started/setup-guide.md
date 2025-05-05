# Mulesoft Setup Guide

## Introduction

This guide walks you through the process of setting up Mulesoft as your Integration Engine for the CMM Reference Architecture. It covers initial configuration, environment setup, and best practices for healthcare integrations. By following these steps, you'll establish a robust integration foundation that connects your healthcare systems securely and efficiently.

## Prerequisites

Before beginning the Mulesoft setup process, ensure you have:

- A Mulesoft Anypoint Platform account (Enterprise or Trial)
- Administrative access to your Anypoint Platform organization
- Understanding of the systems you need to integrate
- Basic knowledge of API-led connectivity concepts
- Familiarity with healthcare data formats (HL7, FHIR, etc.)
- Java Development Kit (JDK) 8 or 11 installed
- Maven 3.3.9 or later installed

## Setup Process

### 1. Anypoint Platform Organization Setup

#### Configure Your Anypoint Platform Organization

1. **Create or Access Your Anypoint Platform Organization**
   - Navigate to [Anypoint Platform](https://anypoint.mulesoft.com/)
   - Log in with your credentials
   - If needed, create a new business group for your healthcare project

2. **Configure Organization Settings**
   - Navigate to **Access Management u2192 Organization**
   - Set up organization owners and administrators
   - Configure identity provider integration (with Okta)
   - Set up API Manager client provider

3. **Environment Configuration**
   - Navigate to **Access Management u2192 Environments**
   - Create the following environments:
     - `Sandbox`
     - `Development`
     - `QA`
     - `UAT`
     - `Production`
   - Assign appropriate administrators to each environment

### 2. Anypoint Exchange Setup

#### Configure Asset Repository

1. **Set Up Exchange Portal**
   - Navigate to **Exchange**
   - Configure Exchange portal settings
   - Set up asset categories for healthcare assets

2. **Import Healthcare Accelerators**
   - Search for and import the following assets:
     - FHIR R4 Connector
     - HL7 v2 Connector
     - Healthcare Templates
     - FHIR API Specifications

3. **Configure Exchange Contribution Model**
   - Set up contribution guidelines
   - Configure asset lifecycle policies
   - Define asset versioning strategy

### 3. API Manager Configuration

#### Set Up API Management

1. **Configure API Manager Settings**
   - Navigate to **API Manager**
   - Set up API Manager client application
   - Configure default API policies

2. **Create API Client Applications**
   - Create client applications for each consuming system
   - Configure appropriate SLAs and throttling

3. **Set Up API Alerts**
   - Configure alerts for API health and performance
   - Set up notification channels

### 4. Runtime Manager Setup

#### Configure Deployment Environments

1. **Set Up CloudHub or On-Premises Runtime**
   - For CloudHub: Configure VPCs, load balancers, and worker sizes
   - For On-Premises: Set up Runtime Fabric or standalone Mule runtimes

2. **Configure Deployment Strategies**
   - Set up deployment pipelines
   - Configure blue-green deployment settings
   - Set up automatic scaling policies

3. **Monitoring Configuration**
   - Set up Anypoint Monitoring
   - Configure custom dashboards for healthcare metrics
   - Set up alerting thresholds

### 5. Development Environment Setup

#### Configure Local Development Environment

1. **Install Anypoint Studio**
   - Download [Anypoint Studio](https://www.mulesoft.com/lp/dl/studio)
   - Install and configure with appropriate JDK

2. **Configure Maven Settings**
   - Set up `settings.xml` with Anypoint Platform credentials
   - Configure repository references

3. **Install Mulesoft Connectors**
   - Install healthcare-specific connectors
   - Configure connector credentials

### 6. Healthcare Integration Setup

#### Configure Healthcare-Specific Components

1. **Set Up FHIR Integration**
   - Configure FHIR server connection (Aidbox)
   - Set up FHIR resource mappings
   - Configure FHIR validation rules

2. **Configure HL7 Integration (if needed)**
   - Set up HL7 listeners and senders
   - Configure HL7 message validation
   - Set up HL7-to-FHIR transformations

3. **EHR Integration Configuration**
   - Set up EHR-specific connectors
   - Configure authentication with EHR systems
   - Set up data synchronization patterns

## Implementation Examples

### API-Led Connectivity Implementation

#### System API Example (EHR Connection)

```xml
<!-- Example: EHR System API Configuration -->
<mule xmlns="http://www.mulesoft.org/schema/mule/core"
      xmlns:http="http://www.mulesoft.org/schema/mule/http"
      xmlns:ee="http://www.mulesoft.org/schema/mule/ee/core"
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:schemaLocation="
        http://www.mulesoft.org/schema/mule/core http://www.mulesoft.org/schema/mule/core/current/mule.xsd
        http://www.mulesoft.org/schema/mule/http http://www.mulesoft.org/schema/mule/http/current/mule-http.xsd
        http://www.mulesoft.org/schema/mule/ee/core http://www.mulesoft.org/schema/mule/ee/core/current/mule-ee.xsd">

    <!-- API Configuration -->
    <http:listener-config name="api-http-listener-config">
        <http:listener-connection host="0.0.0.0" port="8081" />
    </http:listener-config>
    
    <!-- EHR System Connection -->
    <http:request-config name="ehr-request-config">
        <http:request-connection host="${ehr.host}" port="${ehr.port}">
            <http:authentication>
                <http:basic-authentication username="${ehr.username}" password="${ehr.password}" />
            </http:authentication>
        </http:request-connection>
    </http:request-config>
    
    <!-- API Implementation -->
    <flow name="get-patient-flow">
        <http:listener config-ref="api-http-listener-config" path="/api/patients/{id}" />
        
        <!-- Extract Path Parameters -->
        <set-variable variableName="patientId" value="#[attributes.uriParams.id]" />
        
        <!-- Call EHR System -->
        <http:request method="GET" config-ref="ehr-request-config" path="/patients/#[vars.patientId]">
            <http:headers>
                <![CDATA[#[{
                    'Accept': 'application/json',
                    'X-Correlation-ID': attributes.headers['X-Correlation-ID'] default uuid()
                }]]]>
            </http:headers>
        </http:request>
        
        <!-- Transform Response to Canonical Model -->
        <ee:transform>
            <ee:message>
                <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    id: payload.patientId,
    resourceType: "Patient",
    identifier: [
        {
            system: "http://hospital.example.org",
            value: payload.patientId
        }
    ],
    name: [
        {
            family: payload.lastName,
            given: [payload.firstName, payload.middleName]
        }
    ],
    birthDate: payload.dateOfBirth as String,
    gender: payload.gender,
    address: payload.addresses map {
        line: [$.street],
        city: $.city,
        state: $.state,
        postalCode: $.zip
    }
}]]></ee:set-payload>
            </ee:message>
        </ee:transform>
        
        <!-- Error Handling -->
        <error-handler>
            <on-error-propagate type="HTTP:BAD_REQUEST">
                <ee:transform>
                    <ee:message>
                        <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    error: "Bad Request",
    message: "Invalid patient ID format",
    status: 400
}]]></ee:set-payload>
                    </ee:message>
                    <ee:variables>
                        <ee:set-variable variableName="httpStatus">400</ee:set-variable>
                    </ee:variables>
                </ee:transform>
            </on-error-propagate>
            <on-error-propagate type="HTTP:NOT_FOUND">
                <ee:transform>
                    <ee:message>
                        <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    error: "Not Found",
    message: "Patient not found",
    status: 404
}]]></ee:set-payload>
                    </ee:message>
                    <ee:variables>
                        <ee:set-variable variableName="httpStatus">404</ee:set-variable>
                    </ee:variables>
                </ee:transform>
            </on-error-propagate>
        </error-handler>
    </flow>
</mule>
```

#### Process API Example (Patient Data Orchestration)

```xml
<!-- Example: Patient Process API Configuration -->
<mule xmlns="http://www.mulesoft.org/schema/mule/core"
      xmlns:http="http://www.mulesoft.org/schema/mule/http"
      xmlns:ee="http://www.mulesoft.org/schema/mule/ee/core"
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:schemaLocation="
        http://www.mulesoft.org/schema/mule/core http://www.mulesoft.org/schema/mule/core/current/mule.xsd
        http://www.mulesoft.org/schema/mule/http http://www.mulesoft.org/schema/mule/http/current/mule-http.xsd
        http://www.mulesoft.org/schema/mule/ee/core http://www.mulesoft.org/schema/mule/ee/core/current/mule-ee.xsd">

    <!-- API Configuration -->
    <http:listener-config name="process-api-http-listener-config">
        <http:listener-connection host="0.0.0.0" port="8082" />
    </http:listener-config>
    
    <!-- System API Connections -->
    <http:request-config name="patient-system-api-config">
        <http:request-connection host="${patient.api.host}" port="${patient.api.port}" />
    </http:request-config>
    
    <http:request-config name="clinical-system-api-config">
        <http:request-connection host="${clinical.api.host}" port="${clinical.api.port}" />
    </http:request-config>
    
    <!-- API Implementation -->
    <flow name="get-patient-summary-flow">
        <http:listener config-ref="process-api-http-listener-config" path="/api/patient-summary/{id}" />
        
        <!-- Extract Path Parameters -->
        <set-variable variableName="patientId" value="#[attributes.uriParams.id]" />
        
        <!-- Parallel Request for Patient Data -->
        <scatter-gather>
            <route>
                <!-- Get Patient Demographics -->
                <http:request method="GET" config-ref="patient-system-api-config" path="/api/patients/#[vars.patientId]">
                    <http:headers>
                        <![CDATA[#[{
                            'Accept': 'application/json',
                            'X-Correlation-ID': attributes.headers['X-Correlation-ID'] default uuid()
                        }]]]>
                    </http:headers>
                </http:request>
                <set-variable variableName="patientData" value="#[payload]" />
            </route>
            <route>
                <!-- Get Patient Conditions -->
                <http:request method="GET" config-ref="clinical-system-api-config" path="/api/conditions">
                    <http:query-params>
                        <![CDATA[#[{
                            'patient': vars.patientId
                        }]]]>
                    </http:query-params>
                    <http:headers>
                        <![CDATA[#[{
                            'Accept': 'application/json',
                            'X-Correlation-ID': attributes.headers['X-Correlation-ID'] default uuid()
                        }]]]>
                    </http:headers>
                </http:request>
                <set-variable variableName="conditionsData" value="#[payload]" />
            </route>
            <route>
                <!-- Get Patient Medications -->
                <http:request method="GET" config-ref="clinical-system-api-config" path="/api/medications">
                    <http:query-params>
                        <![CDATA[#[{
                            'patient': vars.patientId
                        }]]]>
                    </http:query-params>
                    <http:headers>
                        <![CDATA[#[{
                            'Accept': 'application/json',
                            'X-Correlation-ID': attributes.headers['X-Correlation-ID'] default uuid()
                        }]]]>
                    </http:headers>
                </http:request>
                <set-variable variableName="medicationsData" value="#[payload]" />
            </route>
        </scatter-gather>
        
        <!-- Combine Results into Patient Summary -->
        <ee:transform>
            <ee:message>
                <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    patient: vars.patientData,
    conditions: vars.conditionsData,
    medications: vars.medicationsData
}]]></ee:set-payload>
            </ee:message>
        </ee:transform>
    </flow>
</mule>
```

#### Experience API Example (Mobile App Integration)

```xml
<!-- Example: Mobile Experience API Configuration -->
<mule xmlns="http://www.mulesoft.org/schema/mule/core"
      xmlns:http="http://www.mulesoft.org/schema/mule/http"
      xmlns:ee="http://www.mulesoft.org/schema/mule/ee/core"
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:schemaLocation="
        http://www.mulesoft.org/schema/mule/core http://www.mulesoft.org/schema/mule/core/current/mule.xsd
        http://www.mulesoft.org/schema/mule/http http://www.mulesoft.org/schema/mule/http/current/mule-http.xsd
        http://www.mulesoft.org/schema/mule/ee/core http://www.mulesoft.org/schema/mule/ee/core/current/mule-ee.xsd">

    <!-- API Configuration -->
    <http:listener-config name="experience-api-http-listener-config">
        <http:listener-connection host="0.0.0.0" port="8083" />
    </http:listener-config>
    
    <!-- Process API Connections -->
    <http:request-config name="patient-process-api-config">
        <http:request-connection host="${patient.process.api.host}" port="${patient.process.api.port}" />
    </http:request-config>
    
    <!-- API Implementation -->
    <flow name="get-mobile-patient-dashboard-flow">
        <http:listener config-ref="experience-api-http-listener-config" path="/api/mobile/dashboard" />
        
        <!-- Extract Query Parameters -->
        <set-variable variableName="patientId" value="#[attributes.queryParams.patientId]" />
        
        <!-- Get Patient Summary -->
        <http:request method="GET" config-ref="patient-process-api-config" path="/api/patient-summary/#[vars.patientId]">
            <http:headers>
                <![CDATA[#[{
                    'Accept': 'application/json',
                    'X-Correlation-ID': attributes.headers['X-Correlation-ID'] default uuid()
                }]]]>
            </http:headers>
        </http:request>
        
        <!-- Transform for Mobile Experience -->
        <ee:transform>
            <ee:message>
                <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    patientName: payload.patient.name[0].given[0] ++ " " ++ payload.patient.name[0].family,
    age: (now() - (payload.patient.birthDate as Date)) / 1000 / 60 / 60 / 24 / 365.25,
    activeMedications: payload.medications filter $.status == "active" map {
        name: $.medicationReference.display,
        dosage: $.dosage[0].text,
        frequency: $.dosage[0].timing.code.text
    },
    activeConditions: payload.conditions filter $.clinicalStatus.coding[0].code == "active" map {
        name: $.code.text,
        onset: $.onsetDateTime as String {format: "MMM d, yyyy"} default "Unknown"
    },
    upcomingAppointments: []
}]]></ee:set-payload>
            </ee:message>
        </ee:transform>
    </flow>
</mule>
```

### HL7 to FHIR Transformation Example

```xml
<!-- Example: HL7 to FHIR Transformation -->
<mule xmlns="http://www.mulesoft.org/schema/mule/core"
      xmlns:hl7="http://www.mulesoft.org/schema/mule/hl7"
      xmlns:http="http://www.mulesoft.org/schema/mule/http"
      xmlns:ee="http://www.mulesoft.org/schema/mule/ee/core"
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:schemaLocation="
        http://www.mulesoft.org/schema/mule/core http://www.mulesoft.org/schema/mule/core/current/mule.xsd
        http://www.mulesoft.org/schema/mule/hl7 http://www.mulesoft.org/schema/mule/hl7/current/mule-hl7.xsd
        http://www.mulesoft.org/schema/mule/http http://www.mulesoft.org/schema/mule/http/current/mule-http.xsd
        http://www.mulesoft.org/schema/mule/ee/core http://www.mulesoft.org/schema/mule/ee/core/current/mule-ee.xsd">

    <!-- HL7 Configuration -->
    <hl7:config name="HL7_Config" doc:name="HL7 Config">
        <hl7:connection host="0.0.0.0" port="8888" />
    </hl7:config>
    
    <!-- FHIR Server Configuration -->
    <http:request-config name="fhir-server-config">
        <http:request-connection host="${fhir.server.host}" port="${fhir.server.port}">
            <http:authentication>
                <http:basic-authentication username="${fhir.server.username}" password="${fhir.server.password}" />
            </http:authentication>
        </http:request-connection>
    </http:request-config>
    
    <!-- HL7 Listener Flow -->
    <flow name="hl7-admission-to-fhir-flow">
        <hl7:listener config-ref="HL7_Config" messageType="ADT" triggerEvent="A01" />
        
        <!-- Parse HL7 Message -->
        <hl7:extract-message-data config-ref="HL7_Config">
            <hl7:segments>
                <hl7:segment segmentName="MSH" />
                <hl7:segment segmentName="PID" />
                <hl7:segment segmentName="PV1" />
            </hl7:segments>
        </hl7:extract-message-data>
        
        <!-- Transform HL7 to FHIR Patient -->
        <ee:transform>
            <ee:message>
                <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    resourceType: "Patient",
    identifier: [
        {
            system: "http://hospital.example.org/mrn",
            value: payload.PID."PID.3"."CX.1"
        }
    ],
    active: true,
    name: [
        {
            family: payload.PID."PID.5"."XPN.1",
            given: [
                payload.PID."PID.5"."XPN.2",
                payload.PID."PID.5"."XPN.3"
            ]
        }
    ],
    telecom: [
        {
            system: "phone",
            value: payload.PID."PID.13"."XTN.1",
            use: "home"
        },
        {
            system: "email",
            value: payload.PID."PID.13"."XTN.4"
        }
    ],
    gender: lower(payload.PID."PID.8") match {
        case "m" -> "male"
        case "f" -> "female"
        else -> "unknown"
    },
    birthDate: payload.PID."PID.7" as String {format: "yyyyMMdd"} as Date {format: "yyyy-MM-dd"},
    address: [
        {
            line: [
                payload.PID."PID.11"."XAD.1",
                payload.PID."PID.11"."XAD.2"
            ],
            city: payload.PID."PID.11"."XAD.3",
            state: payload.PID."PID.11"."XAD.4",
            postalCode: payload.PID."PID.11"."XAD.5",
            country: payload.PID."PID.11"."XAD.6"
        }
    ]
}]]></ee:set-payload>
            </ee:message>
            <ee:variables>
                <ee:set-variable variableName="patientResource"><![CDATA[%dw 2.0
output application/json
---
payload]]></ee:set-variable>
            </ee:variables>
        </ee:transform>
        
        <!-- Create or Update Patient in FHIR Server -->
        <http:request method="PUT" config-ref="fhir-server-config" path="/Patient/#[payload.identifier[0].value]">
            <http:body><![CDATA[#[vars.patientResource]]]></http:body>
            <http:headers>
                <![CDATA[#[{
                    'Content-Type': 'application/fhir+json',
                    'Accept': 'application/fhir+json'
                }]]]>
            </http:headers>
        </http:request>
        
        <!-- Create Encounter Resource -->
        <ee:transform>
            <ee:message>
                <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    resourceType: "Encounter",
    status: "in-progress",
    class: {
        system: "http://terminology.hl7.org/CodeSystem/v3-ActCode",
        code: payload.PV1."PV1.2",
        display: payload.PV1."PV1.2" match {
            case "I" -> "inpatient"
            case "O" -> "outpatient"
            case "E" -> "emergency"
            else -> "unknown"
        }
    },
    subject: {
        reference: "Patient/" ++ vars.patientResource.identifier[0].value
    },
    period: {
        start: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"}
    },
    serviceProvider: {
        reference: "Organization/" ++ payload.MSH."MSH.4"
    }
}]]></ee:set-payload>
            </ee:message>
        </ee:transform>
        
        <!-- Create Encounter in FHIR Server -->
        <http:request method="POST" config-ref="fhir-server-config" path="/Encounter">
            <http:headers>
                <![CDATA[#[{
                    'Content-Type': 'application/fhir+json',
                    'Accept': 'application/fhir+json'
                }]]]>
            </http:headers>
        </http:request>
        
        <!-- Send ACK Response -->
        <hl7:create-acknowledgement config-ref="HL7_Config" />
        <hl7:send config-ref="HL7_Config" />
    </flow>
</mule>
```

## Deployment Considerations

### Production Checklist

- **High Availability**: Configure redundant CloudHub workers or Runtime Fabric nodes
- **Disaster Recovery**: Set up cross-region failover
- **Monitoring**: Configure Anypoint Monitoring dashboards
- **Alerting**: Set up alerts for critical integration points
- **Logging**: Configure centralized logging with appropriate retention
- **Backup**: Schedule regular configuration backups

### Healthcare Compliance

- **PHI Handling**: Ensure PHI is properly secured in transit and at rest
- **Audit Logging**: Configure comprehensive audit logging for all data access
- **Data Validation**: Implement validation for healthcare data formats
- **Error Handling**: Configure dead letter queues for failed messages
- **Security Scanning**: Regularly scan APIs for vulnerabilities

## Troubleshooting

### Common Issues

1. **Connectivity Problems**
   - Check network connectivity to backend systems
   - Verify credentials and certificates
   - Check firewall and security group settings

2. **Data Transformation Issues**
   - Validate input data against expected schema
   - Check DataWeave transformations for errors
   - Verify date and time format handling

3. **Performance Problems**
   - Monitor CPU and memory usage
   - Check for connection pool exhaustion
   - Review thread usage and blocking operations

## Next Steps

- [API-Led Connectivity](../02-core-functionality/api-led-connectivity.md): Implement the three-layer architecture
- [Healthcare Connectors](../02-core-functionality/healthcare-connectors.md): Learn about healthcare-specific connectors
- [Integration Patterns](../03-advanced-patterns/integration-patterns.md): Explore common integration patterns

## Resources

- [Mulesoft Documentation](https://docs.mulesoft.com/)
- [Anypoint Platform Architecture](https://www.mulesoft.com/platform/enterprise-integration)
- [Healthcare Integration Best Practices](https://www.mulesoft.com/resources/api/healthcare-integration)
