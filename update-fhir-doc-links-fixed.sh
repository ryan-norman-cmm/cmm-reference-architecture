#!/bin/bash

# Script to update internal links in FHIR documentation
DOCS_ROOT="/Users/rnorman/Projects/cmm-reference-architecture/docs/architecture/core_components/fhir-server"

# Find all markdown files in the FHIR server documentation
find "$DOCS_ROOT" -name "*.md" -type f | while read -r file; do
  echo "Processing $file"
  
  # Update links for each file pattern
  sed -i '' 's|\]\(fhir-server-overview\.md\)|\](01-getting-started/overview.md)|g' "$file"
  sed -i '' 's|\]\(fhir-benefits-overview\.md\)|\](01-getting-started/benefits-overview.md)|g' "$file"
  sed -i '' 's|\]\(fhir-server-setup-guide\.md\)|\](01-getting-started/setup-guide.md)|g' "$file"
  sed -i '' 's|\]\(fhir-standards-tutorial\.md\)|\](01-getting-started/standards-tutorial.md)|g' "$file"
  sed -i '' 's|\]\(fhir-vs-legacy-comparison\.md\)|\](01-getting-started/legacy-comparison.md)|g' "$file"
  
  sed -i '' 's|\]\(fhir-client-authentication\.md\)|\](02-core-functionality/client-authentication.md)|g' "$file"
  sed -i '' 's|\]\(saving-fhir-resources\.md\)|\](02-core-functionality/saving-resources.md)|g' "$file"
  sed -i '' 's|\]\(accessing-fhir-resources\.md\)|\](02-core-functionality/accessing-resources.md)|g' "$file"
  sed -i '' 's|\]\(extending-fhir-resources\.md\)|\](02-core-functionality/extending-resources.md)|g' "$file"
  sed -i '' 's|\]\(fhir-implementation-guides\.md\)|\](02-core-functionality/implementation-guides.md)|g' "$file"
  
  sed -i '' 's|\]\(fhir-query-optimization\.md\)|\](03-advanced-patterns/query-optimization.md)|g' "$file"
  sed -i '' 's|\]\(graphql-integration\.md\)|\](03-advanced-patterns/graphql-integration.md)|g' "$file"
  sed -i '' 's|\]\(event-processing-with-fhir\.md\)|\](03-advanced-patterns/event-processing.md)|g' "$file"
  sed -i '' 's|\]\(fhir-subscriptions\.md\)|\](03-advanced-patterns/subscriptions.md)|g' "$file"
  
  sed -i '' 's|\]\(data-tagging-in-fhir\.md\)|\](04-data-management/data-tagging.md)|g' "$file"
  sed -i '' 's|\]\(fhir-entitlement-management\.md\)|\](04-data-management/entitlement-management.md)|g' "$file"
  sed -i '' 's|\]\(fhir-patient-matching\.md\)|\](04-data-management/patient-matching.md)|g' "$file"
  sed -i '' 's|\]\(fhir-golden-records\.md\)|\](04-data-management/golden-records.md)|g' "$file"
  sed -i '' 's|\]\(fhir-identity-linking\.md\)|\](04-data-management/identity-linking.md)|g' "$file"
  sed -i '' 's|\]\(fhir-consent-management\.md\)|\](04-data-management/consent-management.md)|g' "$file"
  
  sed -i '' 's|\]\(fhir-server-monitoring\.md\)|\](05-operations/server-monitoring.md)|g' "$file"
  sed -i '' 's|\]\(fhir-performance-tuning\.md\)|\](05-operations/performance-tuning.md)|g' "$file"
  sed -i '' 's|\]\(fhir-database-optimization\.md\)|\](05-operations/database-optimization.md)|g' "$file"
  sed -i '' 's|\]\(fhir-query-performance\.md\)|\](05-operations/query-performance.md)|g' "$file"
  sed -i '' 's|\]\(fhir-caching-strategies\.md\)|\](05-operations/caching-strategies.md)|g' "$file"
  sed -i '' 's|\]\(fhir-server-configuration\.md\)|\](05-operations/server-configuration.md)|g' "$file"
  sed -i '' 's|\]\(fhir-load-testing\.md\)|\](05-operations/load-testing.md)|g' "$file"
  
  sed -i '' 's|\]\(fhir-modernization-case-studies\.md\)|\](06-case-studies/modernization-case-studies.md)|g' "$file"
done

echo "Link updates complete."
