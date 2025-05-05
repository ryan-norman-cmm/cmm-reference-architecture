# Schema Governance

## Introduction

Schema governance is the set of processes and practices that ensure your federated GraphQL API evolves safely, predictably, and collaboratively. In healthcare and other regulated domains, strong schema governance is essential for maintaining compatibility, preventing breaking changes, and supporting cross-team development.

This document provides actionable guidance for:
- Managing schema versioning and change control
- Identifying and handling breaking vs. non-breaking changes
- Implementing deprecation strategies
- Validating schemas and automating governance workflows

By following these practices, you can maintain a high-quality API that supports innovation while minimizing risk for consumers and providers.

## Schema Governance with Apollo GraphOS

Apollo GraphOS (formerly Apollo Studio/Graph Manager) provides a managed platform for schema governance, change management, and collaboration in federated GraphQL architectures. By leveraging GraphOS, you can:
- Register and compose subgraph schemas centrally
- Validate schema changes and detect breaking changes automatically
- Track schema history, diffs, and changelogs
- Automate schema checks in CI/CD pipelines
- Collaborate across teams and manage approvals

### Example: Schema Checks in CI/CD with GraphOS
```yaml
name: GraphOS Schema Check
on: [pull_request]
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Install Rover
        run: npm install -g @apollo/rover
      - name: Check Schema
        run: |
          rover subgraph check my-graph@current \
            --name patient-subgraph \
            --schema ./schema.graphql
```

- Use the GraphOS web UI to review proposed schema changes, breaking change alerts, and schema diffs before merging.
- Publish and validate all subgraph schemas in GraphOS before deploying to production.
- Use GraphOS changelogs and Explorer to communicate schema updates and support API documentation.
- Reference the official docs for advanced usage: [Apollo GraphOS Documentation](https://www.apollographql.com/docs/graphos/)

---

### Quick Start

1. Establish schema versioning practices
2. Define processes for identifying breaking vs. non-breaking changes
3. Implement deprecation strategies for graceful evolution
4. Set up schema validation workflows
5. Create documentation requirements for schema changes

### Related Components

- [Creating Subgraphs](../02-core-functionality/creating-subgraphs.md): Learn how schema governance affects subgraph development
- [Schema Federation](../03-advanced-patterns/schema-federation.md): Understand federation-specific governance challenges
- [Access Control](access-control.md): Coordinate governance and access control policies
- [Deployment](../05-operations/deployment.md): Integrate schema validation into deployment pipelines

## Schema Versioning

### Overview

Schema versioning is the practice of managing changes to your GraphQL schema in a controlled, traceable manner. In a federated architecture, versioning helps teams coordinate updates, maintain compatibility, and support rollback or migration strategies.

### Rationale
- **Stability**: Prevent breaking changes from disrupting consumers.
- **Traceability**: Track the evolution of your API over time.
- **Collaboration**: Enable multiple teams to contribute safely.

### Implementation Steps
1. Use semantic versioning (e.g., `1.2.0`) for your overall API or for individual subgraphs.
2. Tag schema releases in your version control system (e.g., Git tags).
3. Document schema changes in a changelog or release notes.
4. Use tools like Apollo Studio or Rover to publish and track schema versions.

### Example: Tagging Schema Releases
```bash
# After merging schema changes
npm version minor # or major/patch
# Tag the release in Git
git tag v1.3.0
git push --tags
```

### Example: Publishing Schema Versions with Apollo Rover
```bash
# Publish a new subgraph schema version
rover subgraph publish my-graph@prod \
  --name patient-subgraph \
  --schema ./schema.graphql
```

### Best Practices
- Increment version numbers for every schema change, following semantic versioning.
- Communicate upcoming changes to all stakeholders.
- Maintain a clear changelog for each subgraph and the overall graph.
- Automate versioning and publishing in your CI/CD pipeline.


## Breaking vs. Non-Breaking Changes

### Overview

Understanding the difference between breaking and non-breaking changes is essential for evolving your federated GraphQL schema safely. Breaking changes can disrupt consumers and should be managed carefully, while non-breaking changes can generally be deployed with less risk.

### Rationale
- **Consumer safety**: Prevent unexpected outages or errors for API consumers.
- **Predictability**: Enable teams to plan for and communicate impactful changes.
- **Governance**: Establish clear processes for schema evolution.

### Implementation Guidance

#### Breaking Changes (Require Major Version Bump or Careful Coordination)
- Removing a type, field, or argument
- Changing a field or argument type (e.g., `String` → `Int`)
- Making a nullable field non-nullable
- Renaming types, fields, or arguments

#### Non-Breaking Changes (Safe for Minor/Patch Releases)
- Adding a new type, field, or argument
- Making a non-nullable field nullable
- Adding new enum values (with caution)
- Adding descriptions or deprecation notices

### Example: Breaking vs. Non-Breaking
```graphql
# Breaking: Removing a field
# type Patient {
#   id: ID!
#   name: String!
#   address: String # <-- removed
# }

# Non-breaking: Adding a field
type Patient {
  id: ID!
  name: String!
  email: String # <-- added
}
```

### Best Practices
- Review all schema changes for breaking vs. non-breaking impact before merging.
- Communicate breaking changes well in advance and provide migration guidance.
- Use schema validation tools to detect accidental breaking changes.
- Establish a schema review process involving all relevant teams.


## Deprecation Strategies

### Overview

Deprecation is the process of marking schema fields, types, or operations as outdated, signaling to consumers that they should migrate to alternatives. In a federated GraphQL API, clear deprecation strategies help teams evolve the schema safely without breaking existing clients.

### Rationale
- **Safe evolution**: Allow clients time to migrate before removing features.
- **Transparency**: Communicate planned changes and alternatives.
- **Minimize disruption**: Reduce the risk of breaking dependent applications.

### Implementation Guidance
1. Use the `@deprecated` directive in your schema to mark fields/types as deprecated.
2. Provide a clear reason and, if possible, suggest an alternative.
3. Communicate deprecation timelines and removal dates to all stakeholders.
4. Monitor usage and coordinate removal in a future major version.

### Example: Deprecating a Field
```graphql
type Patient {
  id: ID!
  name: String!
  # Deprecated field with reason
  address: String @deprecated(reason: "Use addressLines instead.")
  addressLines: [String!]
}
```

### Example: Deprecating an Enum Value
```graphql
enum Gender {
  MALE
  FEMALE
  OTHER @deprecated(reason: "Use NON_BINARY instead.")
  NON_BINARY
}
```

### Best Practices
- Always provide a reason and migration path in the deprecation message.
- Announce deprecations in release notes and API documentation.
- Track usage of deprecated fields/types to plan for safe removal.
- Remove deprecated features in major version releases only, after sufficient notice.


## Schema Validation Workflows

### Overview

Schema validation workflows ensure that changes to your federated GraphQL schema are correct, compatible, and safe before they are deployed to production. Automated validation helps catch breaking changes, composition errors, and inconsistencies early in the development process.

### Rationale
- **Quality assurance**: Prevent schema errors from reaching consumers.
- **Automation**: Reduce manual review and speed up development.
- **Continuous improvement**: Integrate validation into CI/CD pipelines for ongoing safety.

### Implementation Steps
1. Use schema validation tools (e.g., Apollo Rover, graphql-inspector) to check for breaking changes and composition errors.
2. Integrate validation checks into your pull request or merge process.
3. Validate both subgraph schemas and the composed federated schema.
4. Block deployments if validation fails.

### Example: Schema Validation in CI/CD with Apollo Rover
```bash
# Validate a subgraph schema against the live federated graph
rover subgraph check my-graph@prod \
  --name patient-subgraph \
  --schema ./schema.graphql
```

### Example: GitHub Actions Workflow for Schema Validation
```yaml
name: Validate Subgraph Schema
on: [pull_request]
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Install Rover
        run: npm install -g @apollo/rover
      - name: Validate Schema
        run: |
          rover subgraph check my-graph@prod \
            --name patient-subgraph \
            --schema ./schema.graphql
```

### Best Practices
- Validate every schema change before merging or deploying.
- Automate validation in your CI/CD pipeline for all subgraphs.
- Review validation results and resolve issues promptly.
- Document your validation workflow and train all contributors.


## Conclusion

Effective schema governance is essential for evolving your federated GraphQL API safely, collaboratively, and predictably. By managing versioning, distinguishing between breaking and non-breaking changes, implementing clear deprecation strategies, and automating schema validation, you can maintain a high-quality API that supports innovation and minimizes risk.

**Key takeaways:**
- Use semantic versioning and changelogs to track schema evolution.
- Identify and communicate breaking changes early, with clear migration paths.
- Deprecate fields/types thoughtfully and provide alternatives.
- Automate schema validation in your CI/CD pipeline to catch issues before production.
- Foster a culture of collaboration and documentation among all schema contributors.

Regularly review and refine your governance processes as your organization and API grow.

