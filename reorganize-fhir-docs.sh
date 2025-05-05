#!/bin/bash

# Create destination directories
DOCS_ROOT="/Users/rnorman/Projects/cmm-reference-architecture/docs/architecture/core_components/fhir-server"

# 01-getting-started
cp "$DOCS_ROOT/fhir-server-overview.md" "$DOCS_ROOT/01-getting-started/overview.md"
cp "$DOCS_ROOT/fhir-benefits-overview.md" "$DOCS_ROOT/01-getting-started/benefits-overview.md"
cp "$DOCS_ROOT/fhir-server-setup-guide.md" "$DOCS_ROOT/01-getting-started/setup-guide.md"
cp "$DOCS_ROOT/fhir-standards-tutorial.md" "$DOCS_ROOT/01-getting-started/standards-tutorial.md"
cp "$DOCS_ROOT/fhir-vs-legacy-comparison.md" "$DOCS_ROOT/01-getting-started/legacy-comparison.md"

# 02-core-functionality
cp "$DOCS_ROOT/fhir-client-authentication.md" "$DOCS_ROOT/02-core-functionality/client-authentication.md"
cp "$DOCS_ROOT/saving-fhir-resources.md" "$DOCS_ROOT/02-core-functionality/saving-resources.md"
cp "$DOCS_ROOT/accessing-fhir-resources.md" "$DOCS_ROOT/02-core-functionality/accessing-resources.md"
cp "$DOCS_ROOT/extending-fhir-resources.md" "$DOCS_ROOT/02-core-functionality/extending-resources.md"
cp "$DOCS_ROOT/fhir-implementation-guides.md" "$DOCS_ROOT/02-core-functionality/implementation-guides.md"

# 03-advanced-patterns
cp "$DOCS_ROOT/fhir-query-optimization.md" "$DOCS_ROOT/03-advanced-patterns/query-optimization.md"
cp "$DOCS_ROOT/graphql-integration.md" "$DOCS_ROOT/03-advanced-patterns/graphql-integration.md"
cp "$DOCS_ROOT/event-processing-with-fhir.md" "$DOCS_ROOT/03-advanced-patterns/event-processing.md"
cp "$DOCS_ROOT/fhir-subscriptions.md" "$DOCS_ROOT/03-advanced-patterns/subscriptions.md"

# 04-data-management
cp "$DOCS_ROOT/data-tagging-in-fhir.md" "$DOCS_ROOT/04-data-management/data-tagging.md"
cp "$DOCS_ROOT/fhir-entitlement-management.md" "$DOCS_ROOT/04-data-management/entitlement-management.md"
cp "$DOCS_ROOT/fhir-patient-matching.md" "$DOCS_ROOT/04-data-management/patient-matching.md"
cp "$DOCS_ROOT/fhir-golden-records.md" "$DOCS_ROOT/04-data-management/golden-records.md"
cp "$DOCS_ROOT/fhir-identity-linking.md" "$DOCS_ROOT/04-data-management/identity-linking.md"
cp "$DOCS_ROOT/fhir-consent-management.md" "$DOCS_ROOT/04-data-management/consent-management.md"

# 05-operations
cp "$DOCS_ROOT/fhir-server-monitoring.md" "$DOCS_ROOT/05-operations/server-monitoring.md"
cp "$DOCS_ROOT/fhir-performance-tuning.md" "$DOCS_ROOT/05-operations/performance-tuning.md"
cp "$DOCS_ROOT/fhir-database-optimization.md" "$DOCS_ROOT/05-operations/database-optimization.md"
cp "$DOCS_ROOT/fhir-query-performance.md" "$DOCS_ROOT/05-operations/query-performance.md"
cp "$DOCS_ROOT/fhir-caching-strategies.md" "$DOCS_ROOT/05-operations/caching-strategies.md"
cp "$DOCS_ROOT/fhir-server-configuration.md" "$DOCS_ROOT/05-operations/server-configuration.md"
cp "$DOCS_ROOT/fhir-load-testing.md" "$DOCS_ROOT/05-operations/load-testing.md"

# 06-case-studies
cp "$DOCS_ROOT/fhir-modernization-case-studies.md" "$DOCS_ROOT/06-case-studies/modernization-case-studies.md"

echo "Files copied to new structure successfully."
