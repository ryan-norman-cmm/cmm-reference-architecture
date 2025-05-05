# Cascade Guide for CMM Reference Architecture Repository

## Introduction

The CMM Reference Architecture Repository serves as the central knowledge base for CoverMyMeds' Modern Technology Platform, providing comprehensive documentation on healthcare modernization architecture patterns. This repository is designed to be published through Backstage TechDocs, offering standardized guidance on implementing FHIR-based healthcare systems, event-driven architecture, and microservices.

### Quick Start

1. Clone the repository: `git clone [repository-url]`
2. Install the techdocs-cli: `npm install -g @techdocs/cli`
3. Preview the documentation locally: `techdocs-cli serve`
4. Access the documentation at http://localhost:3000
5. Add new documentation by creating Markdown files in the appropriate `docs/` subdirectory

### Related Resources

- [Backstage TechDocs Documentation](https://backstage.io/docs/features/techdocs/techdocs-overview)
- [MkDocs Documentation](https://www.mkdocs.org/user-guide/writing-your-docs/)
- [Architecture Decision Records](architecture-decisions.md) (Coming Soon)

## Repository Structure

### Core Configuration Files

The repository is organized around several key configuration files that control how the documentation is structured and presented:

| File | Purpose | Description |
|------|---------|-------------|
| `catalog-info.yaml` | Backstage Integration | Defines the repository as a Backstage entity for the Healthcare Modernization Reference Architecture |
| `mkdocs.yml` | Documentation Structure | Controls navigation hierarchy, theme settings, and plugin configuration |
| `cmm-config.json` | Theme Configuration | Defines brand colors and visual styling for the documentation |
| `README.md` | Repository Information | Provides basic overview and local development instructions |

### Documentation Organization

The documentation follows a structured hierarchy to facilitate navigation and discovery:

- **Home Page** (`docs/index.md`): Introduction to the CoverMyMeds Modern Technology Platform
- **Architecture Overview** (`docs/architecture/overview.md`): Comprehensive explanation of platform architecture
- **Architecture Principles** (`docs/architecture/principles.md`): Core principles guiding design decisions
- **Core Components**:
  - **FHIR Server**: Documentation for setting up and using the FHIR server
  - **Event Broker**: Kafka-based event processing documentation
  - **Federated Graph API**: GraphQL-based API documentation
  - **Business Process Management**: Workflow orchestration documentation

## Architecture Summary

### Platform Layers
1. **Infrastructure Layer**: Base infrastructure components
2. **Platform Capabilities**: Core services including FHIR Server, Event Broker (Confluent Kafka), Federated Graph API, and Business Process Management
3. **Shared Product Capabilities**: Healthcare-specific services like Master Data Services, Forms Management, and Healthcare Workflows
4. **Applications Layer**: End-user applications

### Key Architectural Principles
- **Connectivity**: Seamless data exchange through unified APIs and event-driven patterns
- **Standardization**: Embracing healthcare standards like FHIR and Implementation Guides
- **Reusability**: Creating composable components for diverse healthcare workflows
- **Developer Effectiveness**: Balancing productivity with flexibility
- **Portability**: Clear boundaries between components through standardized interfaces
- **Data Fidelity**: Consistent healthcare data representation using FHIR
- **Patient-Centered Design**: Prioritizing patient access to medications
- **Network First**: Enhancing CoverMyMeds' network advantage

## Healthcare Standards
- FHIR R4
- US Core
- Da Vinci ePA Implementation Guides
- Da Vinci CDex Implementation Guide
- Da Vinci Prior Authorization Support (PAS)
- Da Vinci Coverage Requirements Discovery (CRD)

## Common Implementation Scenarios
- Prior Authorization Submission workflow
- Healthcare data integration patterns
- Authentication models (SMART on FHIR, OAuth 2.0, mTLS)

## Working with This Repository

### Local Development Environment

To work with this documentation repository locally, you'll need to set up a development environment that allows you to preview changes before committing them.

#### Prerequisites

- Node.js (v14 or later)
- npm or yarn package manager
- Git

#### Setup Process

```bash
# Install the Backstage TechDocs CLI tool
npm install -g @techdocs/cli

# Clone the repository (if you haven't already)
git clone [repository-url]
cd cmm-reference-architecture

# Preview the documentation locally
techdocs-cli serve
```

The documentation will be available at http://localhost:3000. The preview server supports hot reloading, so changes to Markdown files will be reflected immediately in the browser.

### Theme Customization

The repository implements a custom theme aligned with CoverMyMeds' brand identity. The theme configuration is defined in `cmm-config.json` and referenced in the MkDocs configuration.

#### Brand Colors

| Color | Hex Code | Usage |
|-------|----------|-------|
| Orange | `#FF8F1D` | Primary action elements, highlights |
| Blue | `#00426A` | Headers, navigation elements |
| Pink | `#E70665` | Accent color, call-to-action elements |

#### Applying Theme Changes

To modify the theme configuration:

1. Edit the color definitions in `cmm-config.json`
2. Update the theme section in `mkdocs.yml` to reference these colors
3. Preview changes using the local development server

Refer to the [MkDocs Material theme documentation](https://squidfunk.github.io/mkdocs-material/setup/changing-the-colors/) for detailed configuration options.

### Documentation Contribution Workflow

#### Adding New Content

1. Create a new Markdown file in the appropriate directory under `docs/`
2. Follow the [Communication Style Guide](#communication-style-guide-for-technical-documentation) for content formatting
3. Include a concise introduction, Quick Start section, and Related Components links
4. Add code examples with proper syntax highlighting and inline comments
5. Update the `mkdocs.yml` file to include the new page in the navigation structure

#### Standardized Documentation Structure

All core components of the Modern Technology Platform should follow a consistent, hierarchical documentation structure to improve navigation and discoverability. The following structure has been established as the standard pattern:

```
docs/
├── index.md                                # Home page
├── architecture/
│   ├── overview.md                        # Architecture overview
│   ├── principles.md                      # Architectural principles
│   └── core_components/                   # Core component documentation
│       ├── component-name/                # Component root folder
│       │   ├── 01-getting-started/       # Introduction and basic concepts
│       │   │   ├── overview.md           # Component overview
│       │   │   ├── benefits-overview.md  # Business benefits
│       │   │   ├── setup-guide.md        # Installation and configuration
│       │   │   └── ...
│       │   ├── 02-core-functionality/    # Essential features
│       │   │   ├── feature-one.md        # Core feature documentation
│       │   │   ├── feature-two.md        # Core feature documentation
│       │   │   └── ...
│       │   ├── 03-advanced-patterns/     # Complex usage patterns
│       │   │   ├── pattern-one.md        # Advanced usage documentation
│       │   │   ├── pattern-two.md        # Advanced usage documentation
│       │   │   └── ...
│       │   ├── 04-data-management/       # Data handling specifics
│       │   │   └── ...
│       │   ├── 05-operations/            # Operational concerns
│       │   │   ├── monitoring.md         # Monitoring documentation
│       │   │   ├── performance-tuning.md # Performance optimization
│       │   │   └── ...
│       │   └── 06-case-studies/          # Real-world implementations
│       │       └── ...
│       ├── another-component/            # Another component folder
│       │   └── ...
│       └── ...
└── ...
```

This structure follows a progressive disclosure model, organizing content from basic concepts to advanced topics. The numbered folders (01-, 02-, etc.) ensure a logical order in file explorers and documentation navigation.

#### Publishing Process

Documentation is automatically published to Backstage TechDocs when changes are pushed to the main branch. The publishing workflow includes:

1. Automatic generation of TechDocs-compatible documentation
2. Deployment to the Backstage TechDocs instance
3. Immediate availability to all developers through the Backstage portal

No manual steps are required beyond merging changes to the main branch.

## Communication Style Guide for Technical Documentation

### Overview
Ensure all documentation is clear, concise, and easy to understand. Break down more complex topics into smaller, digestible chunks and create nested pages instead of one large page.

### Voice & Tone
Write in a voice that balances technical precision with accessibility:

Clear and authoritative without being overly formal
Precise in technical explanations while remaining approachable
Solution-oriented, focusing on practical implementation guidance
Consistent across all documentation artifacts
Technically accurate while avoiding unnecessary jargon

### Structure & Flow

Begin each section with a concise overview of the concept before diving into details
Use progressive disclosure - start with high-level concepts before exploring implementation specifics
Maintain consistent heading hierarchies for easy navigation and reference
Employ a logical progression from problem statement to solution pattern to implementation example
Include clear transition statements between related architectural concepts

### Technical Language & Diagrams

Define technical terms on first use before employing them throughout the documentation
Use standardized terminology aligned with industry conventions (FHIR, HL7, etc.)
Accompany complex concepts with appropriate diagrams (C4 model, BPMN, sequence diagrams)
Include relevant code snippets and configuration examples for concrete implementation guidance
Balance conceptual explanations with practical examples

### Documentation Structure

Organize documentation into logical, discoverable sections with consistent naming
Use descriptive headers that clearly indicate the content's focus
Include a "Quick Start" section for essential implementation patterns
Provide cross-references to related architectural components
Include decision logs explaining key architectural choices and their rationale

### Code Examples & Patterns

Present code examples in a consistent format with proper syntax highlighting
Include inline comments explaining key implementation decisions
Provide complete, working examples rather than fragmented snippets when possible
Demonstrate both "happy path" and error handling scenarios
Showcase integration patterns between multiple system components

### Architecture Diagrams

Maintain consistent visual language across all architectural diagrams
Clearly label components, boundaries and interactions
Include both static structure and dynamic behavior diagrams
Use appropriate levels of abstraction for different audiences (C1-C4 models)
Provide legends explaining notation and symbolism

## Core Component Documentation Structure

All core components of the Modern Technology Platform should follow a standardized documentation structure to ensure consistency, improve navigation, and facilitate knowledge transfer. This section outlines the recommended structure and content organization for documenting core components.

### Standard Category Organization

Each core component's documentation should be organized into the following categories, presented in order of increasing complexity and specialization:

1. **Getting Started**: Introduction and basic concepts
   - Overview of the component
   - Benefits and business value
   - Setup and configuration guides
   - Tutorials for basic usage
   - Comparison with legacy or alternative approaches

2. **Core Functionality**: Essential features and capabilities
   - Authentication and security
   - Basic data operations (create, read, update, delete)
   - Core API documentation
   - Standard usage patterns
   - Implementation guides

3. **Advanced Patterns**: Complex usage scenarios
   - Integration patterns with other components
   - Query optimization and advanced data access
   - Custom extensions and configurations
   - Event-driven patterns

4. **Data Management**: Data handling specifics
   - Data modeling guidelines
   - Data governance and security
   - Master data management
   - Data migration strategies
   - Consent and privacy management

5. **Operations**: Deployment and maintenance
   - Monitoring and alerting
   - Performance tuning
   - Scaling strategies
   - Backup and recovery
   - Configuration management
   - Load testing and capacity planning

6. **Case Studies**: Real-world implementations
   - Success stories
   - Implementation examples
   - Lessons learned
   - Modernization journeys

### Document Structure Guidelines

Each document within these categories should follow a consistent structure:

1. **Introduction**: Begin with a concise overview that explains the purpose and scope of the document
2. **Quick Start**: Provide steps for immediate implementation of the most common use case
3. **Related Components**: List related documents or components with links
4. **Main Content**: Organized in logical sections with clear headings
5. **Code Examples**: Include complete, working examples with both success and error handling
6. **Configuration Examples**: Provide sample configurations for different scenarios
7. **Diagrams**: Use consistent visual language for architectural and flow diagrams
8. **Reference Information**: Include API references, configuration options, etc.

### Implementation Process

To implement this structure for a new or existing component:

1. Create the directory structure with numbered folders (01-getting-started, 02-core-functionality, etc.)
2. Move existing documentation into the appropriate categories
3. Update file names to be concise and descriptive, removing redundant prefixes
4. Update the mkdocs.yml navigation to reflect the new structure
5. Update internal links between documents to maintain proper references
6. Review all documents to ensure they follow the document structure guidelines

Contextual Adjustments

Developer guides: Detailed implementation steps with code examples and configuration guidance
Architecture overviews: Higher-level explanations focusing on system relationships and patterns
API documentation: Precise interface definitions with example requests and responses
Component documentation: Clear explanations of responsibilities, dependencies and interfaces
Reference implementations: Fully documented example code with extensive commenting

Example Transformation
Instead of:
"The FHIR server stores healthcare data in a standardized format."
Write:
"The FHIR server acts as the system of record for healthcare resources, storing patient data, clinical observations, and administrative information in standardized formats defined by HL7. This standardization creates a foundation for interoperability while preserving semantic meaning across integrated systems. For example, a MedicationRequest resource maintains consistent representation whether accessed by a provider EHR, pharmacy system, or patient mobile application."
Remember: Technical documentation should prioritize clarity, accuracy, and practical utility while providing sufficient context for developers to successfully implement the architecture patterns.