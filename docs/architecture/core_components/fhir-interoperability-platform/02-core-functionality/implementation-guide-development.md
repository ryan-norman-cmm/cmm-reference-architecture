# FHIR Implementation Guide Development

## Overview

This guide walks you through the process of developing custom FHIR Implementation Guides (IGs) for the FHIR Interoperability Platform. Implementation Guides provide a structured way to define how FHIR should be used in specific contexts, including profiles, extensions, value sets, and examples. Creating your own Implementation Guides allows you to standardize FHIR usage within your organization or for specific healthcare domains.

## Implementation Guide Basics

A FHIR Implementation Guide typically includes:

- **Profiles**: Constraints on FHIR resources for specific use cases
- **Extensions**: Additional data elements not in the base FHIR specification
- **Value Sets**: Sets of codes that can be used in specific elements
- **Examples**: Sample resources that conform to the profiles
- **Documentation**: Narrative content explaining the implementation guide

## Development Tools

### FHIR Shorthand and IG Publisher

The recommended approach for developing Implementation Guides is using FHIR Shorthand (FSH) and the IG Publisher:

1. **FHIR Shorthand**: A domain-specific language for defining FHIR artifacts
2. **SUSHI**: A compiler that converts FSH files to FHIR JSON
3. **IG Publisher**: A tool that creates a complete, publishable Implementation Guide

#### Installation

```bash
# Install Node.js (prerequisite)
brew install node

# Install SUSHI globally
npm install -g fsh-sushi

# Install Jekyll (required for IG Publisher)
brew install ruby
gem install jekyll

# Download the IG Publisher
mkdir -p ~/fhir/publisher
curl -L https://github.com/HL7/fhir-ig-publisher/releases/latest/download/publisher.jar -o ~/fhir/publisher/publisher.jar
```

## Creating a New Implementation Guide

### 1. Initialize a New IG Project

```bash
# Create a new directory for your IG
mkdir my-healthcare-ig
cd my-healthcare-ig

# Initialize a new FHIR Shorthand project
sushi --init
```

This will prompt you for basic information about your Implementation Guide:

- **IG Name**: A short name (e.g., "MyHealthcareIG")
- **IG Title**: A descriptive title (e.g., "My Healthcare Organization FHIR Implementation Guide")
- **IG Description**: A brief description of the purpose
- **IG Publisher**: Your organization name
- **IG Version**: Starting version (e.g., "0.1.0")
- **FHIR Version**: The FHIR version to use (e.g., "4.0.1")

### 2. Define Profiles and Extensions

Create FSH files in the `input/fsh` directory to define your profiles and extensions:

```fsh
// input/fsh/PatientProfile.fsh
Profile: MyHealthcarePatient
Parent: Patient
Id: my-healthcare-patient
Title: "My Healthcare Patient Profile"
Description: "Patient profile for My Healthcare Organization"

* identifier 1..*
* identifier ^slicing.discriminator.type = #pattern
* identifier ^slicing.discriminator.path = "system"
* identifier ^slicing.rules = #open

* identifier contains
    MRN 1..1 and
    SSN 0..1

* identifier[MRN].system = "http://myhealthcare.org/fhir/identifier/mrn"
* identifier[MRN].value 1..1

* identifier[SSN].system = "http://hl7.org/fhir/sid/us-ssn"
* identifier[SSN].value 1..1

* extension contains
    PatientPreferredPharmacy named preferredPharmacy 0..1

// Define an extension
Extension: PatientPreferredPharmacy
Id: patient-preferred-pharmacy
Title: "Patient Preferred Pharmacy"
Description: "Reference to a patient's preferred pharmacy"

* value[x] only Reference(Organization)
* valueReference.display 1..1
```

### 3. Define Value Sets

```fsh
// input/fsh/ValueSets.fsh
ValueSet: MyHealthcareServiceTypes
Id: my-healthcare-service-types
Title: "My Healthcare Service Types"
Description: "Service types provided by My Healthcare Organization"

* include codes from system http://terminology.hl7.org/CodeSystem/service-type where concept descendent-of #124 "General Practice"
* include codes from system http://terminology.hl7.org/CodeSystem/service-type where concept is-a #393 "Pediatrics"
* include codes from system http://terminology.hl7.org/CodeSystem/service-type where concept is-a #394 "Pediatric Cardiology"
```

### 4. Create Examples

```fsh
// input/fsh/Examples.fsh
Instance: PatientExample
InstanceOf: MyHealthcarePatient
Title: "Example Patient"
Description: "Example of a patient conforming to the MyHealthcarePatient profile"

* identifier[MRN].value = "12345"
* identifier[MRN].system = "http://myhealthcare.org/fhir/identifier/mrn"
* identifier[SSN].value = "123-45-6789"
* identifier[SSN].system = "http://hl7.org/fhir/sid/us-ssn"
* name.given[0] = "John"
* name.family = "Smith"
* gender = #male
* birthDate = "1970-01-01"
* extension[preferredPharmacy].valueReference = Reference(Organization/pharmacy-123)
* extension[preferredPharmacy].valueReference.display = "Main Street Pharmacy"
```

### 5. Add Implementation Guide Pages

Create Markdown files in the `input/pagecontent` directory:

```markdown
<!-- input/pagecontent/index.md -->
# My Healthcare Organization FHIR Implementation Guide

This implementation guide defines the FHIR profiles, extensions, and value sets used by My Healthcare Organization.

## Profiles

This IG defines the following profiles:

* [MyHealthcarePatient](StructureDefinition-my-healthcare-patient.html): Profile for patient resources

## Extensions

This IG defines the following extensions:

* [PatientPreferredPharmacy](StructureDefinition-patient-preferred-pharmacy.html): Extension for a patient's preferred pharmacy
```

### 6. Build and Validate the Implementation Guide

```bash
# Generate the IG structure with SUSHI
sushi .

# Run the IG Publisher
java -jar ~/fhir/publisher/publisher.jar -ig .
```

The publisher will generate a complete Implementation Guide in the `output` directory, which you can view by opening `output/index.html` in a browser.

## Testing and Validation

### Validate Profiles Against Examples

```bash
# Validate an example against a profile
java -jar ~/fhir/validator/validator_cli.jar input/examples/patient-example.json -profile http://myhealthcare.org/fhir/StructureDefinition/my-healthcare-patient
```

### Integration Testing with the FHIR Interoperability Platform

1. **Install the IG**: Follow the [Implementation Guide Installation](implementation-guide-installation.md) guide to install your custom IG

2. **Test Resource Validation**:
   ```bash
   # Create a resource that should conform to your profile
   curl -X POST https://fhir-platform.example.org/fhir/Patient \
     -H "Content-Type: application/fhir+json" \
     -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
     -d '{
       "resourceType": "Patient",
       "meta": {
         "profile": ["http://myhealthcare.org/fhir/StructureDefinition/my-healthcare-patient"]
       },
       "identifier": [{
         "system": "http://myhealthcare.org/fhir/identifier/mrn",
         "value": "12345"
       }],
       "name": [{
         "given": ["John"],
         "family": "Smith"
       }],
       "gender": "male",
       "birthDate": "1970-01-01"
     }'
   ```

## Publishing and Distribution

### Internal Distribution

1. **Host the IG on an Internal Web Server**:
   ```bash
   # Copy the output directory to your web server
   cp -r output/* /var/www/html/fhir-igs/my-healthcare-ig/
   ```

2. **Register the IG with the FHIR Interoperability Platform**:
   ```bash
   # Register the IG with the FHIR server
   curl -X POST https://fhir-platform.example.org/fhir/ImplementationGuide \
     -H "Content-Type: application/fhir+json" \
     -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
     -d '{
       "resourceType": "ImplementationGuide",
       "url": "http://myhealthcare.org/fhir/ImplementationGuide/my-healthcare-ig",
       "version": "0.1.0",
       "name": "MyHealthcareIG",
       "title": "My Healthcare Organization FHIR Implementation Guide",
       "status": "draft",
       "publisher": "My Healthcare Organization",
       "packageId": "myhealthcare.fhir.ig",
       "fhirVersion": ["4.0.1"]
     }'
   ```

### Public Distribution

For publicly available Implementation Guides:

1. **Publish to a Public Repository**:
   - GitHub Pages
   - AWS S3 with static website hosting
   - Azure Blob Storage with static website hosting

2. **Register with the FHIR Registry**:
   - Submit to the [HL7 FHIR Registry](https://registry.fhir.org/) for wider discovery

## Best Practices

### Implementation Guide Design

1. **Start Small**: Begin with a minimal set of profiles and extensions
2. **Reuse Existing Work**: Leverage US Core or other established IGs where possible
3. **Document Thoroughly**: Include clear explanations of design decisions
4. **Version Carefully**: Follow semantic versioning principles

### Healthcare-Specific Considerations

1. **Regulatory Compliance**: Ensure profiles support regulatory requirements
2. **Clinical Workflow Alignment**: Design profiles that align with clinical workflows
3. **Terminology Binding**: Use standard terminologies where possible
4. **Data Quality**: Include appropriate constraints to ensure data quality

## Troubleshooting

### Common Issues

1. **IG Publisher Errors**:
   - Check Java version (requires Java 8 or later)
   - Verify that all referenced resources exist
   - Check for syntax errors in FSH files

2. **Profile Validation Failures**:
   - Verify cardinality constraints
   - Check value set bindings
   - Ensure required elements are present

### Diagnostic Steps

```bash
# Run SUSHI with debug output
sushi -s .

# Run IG Publisher with debug output
java -jar ~/fhir/publisher/publisher.jar -ig . -debug
```

## Related Documentation

- [Implementation Guide Installation](implementation-guide-installation.md): How to install Implementation Guides
- [FHIR Server APIs](server-apis.md): API endpoints for managing Implementation Guides
- [FHIR RBAC](rbac.md): Role-based access control for Implementation Guide management
