#!/bin/bash

# Script to update internal links in FHIR documentation
DOCS_ROOT="/Users/rnorman/Projects/cmm-reference-architecture/docs/architecture/core_components/fhir-server"

# Define mapping of old to new paths
declare -A path_mapping=(
  ["fhir-server-overview.md"]="01-getting-started/overview.md"
  ["fhir-benefits-overview.md"]="01-getting-started/benefits-overview.md"
  ["fhir-server-setup-guide.md"]="01-getting-started/setup-guide.md"
  ["fhir-standards-tutorial.md"]="01-getting-started/standards-tutorial.md"
  ["fhir-vs-legacy-comparison.md"]="01-getting-started/legacy-comparison.md"
  ["fhir-client-authentication.md"]="02-core-functionality/client-authentication.md"
  ["saving-fhir-resources.md"]="02-core-functionality/saving-resources.md"
  ["accessing-fhir-resources.md"]="02-core-functionality/accessing-resources.md"
  ["extending-fhir-resources.md"]="02-core-functionality/extending-resources.md"
  ["fhir-implementation-guides.md"]="02-core-functionality/implementation-guides.md"
  ["fhir-query-optimization.md"]="03-advanced-patterns/query-optimization.md"
  ["graphql-integration.md"]="03-advanced-patterns/graphql-integration.md"
  ["event-processing-with-fhir.md"]="03-advanced-patterns/event-processing.md"
  ["fhir-subscriptions.md"]="03-advanced-patterns/subscriptions.md"
  ["data-tagging-in-fhir.md"]="04-data-management/data-tagging.md"
  ["fhir-entitlement-management.md"]="04-data-management/entitlement-management.md"
  ["fhir-patient-matching.md"]="04-data-management/patient-matching.md"
  ["fhir-golden-records.md"]="04-data-management/golden-records.md"
  ["fhir-identity-linking.md"]="04-data-management/identity-linking.md"
  ["fhir-consent-management.md"]="04-data-management/consent-management.md"
  ["fhir-server-monitoring.md"]="05-operations/server-monitoring.md"
  ["fhir-performance-tuning.md"]="05-operations/performance-tuning.md"
  ["fhir-database-optimization.md"]="05-operations/database-optimization.md"
  ["fhir-query-performance.md"]="05-operations/query-performance.md"
  ["fhir-caching-strategies.md"]="05-operations/caching-strategies.md"
  ["fhir-server-configuration.md"]="05-operations/server-configuration.md"
  ["fhir-load-testing.md"]="05-operations/load-testing.md"
  ["fhir-modernization-case-studies.md"]="06-case-studies/modernization-case-studies.md"
)

# Find all markdown files in the FHIR server documentation
find "$DOCS_ROOT" -name "*.md" -type f | while read -r file; do
  echo "Processing $file"
  
  # For each old path, replace with new path in the file
  for old_path in "${!path_mapping[@]}"; do
    new_path="${path_mapping[$old_path]}"
    # Use sed to replace the old path with the new path in markdown links
    sed -i '' "s|\]($old_path)|\]($new_path)|g" "$file"
  done
done

echo "Link updates complete."
