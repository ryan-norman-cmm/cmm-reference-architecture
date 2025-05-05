#!/bin/bash

# Remove original FHIR documentation files
DOCS_ROOT="/Users/rnorman/Projects/cmm-reference-architecture/docs/architecture/core_components/fhir-server"

# List of original files to remove
FILES=(
  "$DOCS_ROOT/fhir-server-overview.md"
  "$DOCS_ROOT/fhir-benefits-overview.md"
  "$DOCS_ROOT/fhir-server-setup-guide.md"
  "$DOCS_ROOT/fhir-standards-tutorial.md"
  "$DOCS_ROOT/fhir-vs-legacy-comparison.md"
  "$DOCS_ROOT/fhir-client-authentication.md"
  "$DOCS_ROOT/saving-fhir-resources.md"
  "$DOCS_ROOT/accessing-fhir-resources.md"
  "$DOCS_ROOT/extending-fhir-resources.md"
  "$DOCS_ROOT/fhir-implementation-guides.md"
  "$DOCS_ROOT/fhir-query-optimization.md"
  "$DOCS_ROOT/graphql-integration.md"
  "$DOCS_ROOT/event-processing-with-fhir.md"
  "$DOCS_ROOT/fhir-subscriptions.md"
  "$DOCS_ROOT/data-tagging-in-fhir.md"
  "$DOCS_ROOT/fhir-entitlement-management.md"
  "$DOCS_ROOT/fhir-patient-matching.md"
  "$DOCS_ROOT/fhir-golden-records.md"
  "$DOCS_ROOT/fhir-identity-linking.md"
  "$DOCS_ROOT/fhir-consent-management.md"
  "$DOCS_ROOT/fhir-server-monitoring.md"
  "$DOCS_ROOT/fhir-performance-tuning.md"
  "$DOCS_ROOT/fhir-database-optimization.md"
  "$DOCS_ROOT/fhir-query-performance.md"
  "$DOCS_ROOT/fhir-caching-strategies.md"
  "$DOCS_ROOT/fhir-server-configuration.md"
  "$DOCS_ROOT/fhir-load-testing.md"
  "$DOCS_ROOT/fhir-modernization-case-studies.md"
)

# Remove each file
for file in "${FILES[@]}"; do
  if [ -f "$file" ]; then
    rm "$file"
    echo "Removed: $file"
  else
    echo "File not found: $file"
  fi
done

echo "Original files removal complete."
