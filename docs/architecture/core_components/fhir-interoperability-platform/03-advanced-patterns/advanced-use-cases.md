# FHIR Interoperability Platform Advanced Use Cases

## Introduction

This document outlines advanced use cases for the FHIR Interoperability Platform that go beyond basic CRUD operations. These scenarios demonstrate how to leverage the platform's capabilities for complex healthcare workflows, analytics, and integrations.

## Population Health Management

### Cohort Identification and Analysis

Identify and analyze patient cohorts based on clinical criteria for population health management.

**Implementation Pattern:**
- Use FHIR Search API with complex parameters to identify cohorts
- Leverage Bulk Data API for efficient data extraction
- Process data with analytics tools for population insights

```typescript
// Example: Identifying patients with uncontrolled diabetes
import { FhirClient } from '../services/fhir-client';
import { BulkDataClient } from '../services/bulk-data-client';

async function identifyUncontrolledDiabetesPatients(fhirClient: FhirClient, bulkClient: BulkDataClient) {
  // Step 1: Find patients with diabetes diagnosis
  const diabetesPatients = await fhirClient.search('Patient', {
    '_has:Condition:patient:code': 'http://snomed.info/sct|73211009',
    '_count': '1000'
  });
  
  // Step 2: Extract patient IDs
  const patientIds = diabetesPatients.entry
    ?.map(entry => entry.resource?.id)
    .filter(Boolean) as string[];
  
  // Step 3: Find recent A1C observations for these patients
  const uncontrolledPatients = [];
  
  for (const batchIds of chunk(patientIds, 50)) {
    const a1cObservations = await fhirClient.search('Observation', {
      'code': 'http://loinc.org|4548-4', // HbA1c
      'patient': batchIds.map(id => `Patient/${id}`).join(','),
      'date': 'ge2023-01-01',
      '_sort': '-date',
      '_count': '1000'
    });
    
    // Group observations by patient
    const patientObservations = groupByPatient(a1cObservations);
    
    // Find patients with A1C > 8.0% in their most recent result
    for (const [patientId, observations] of Object.entries(patientObservations)) {
      if (observations.length > 0) {
        const latestA1c = observations[0];
        const a1cValue = latestA1c.valueQuantity?.value;
        
        if (a1cValue && a1cValue > 8.0) {
          uncontrolledPatients.push(patientId);
        }
      }
    }
  }
  
  // Step 4: Use Bulk Data API to export comprehensive data for these patients
  if (uncontrolledPatients.length > 0) {
    const exportUrl = await bulkClient.startPatientExport(uncontrolledPatients, [
      'Patient', 'Condition', 'Observation', 'MedicationRequest', 'Encounter'
    ]);
    
    // Monitor export status and download results when complete
    return { patientCount: uncontrolledPatients.length, exportUrl };
  }
  
  return { patientCount: 0 };
}

// Helper function to chunk array into batches
function chunk<T>(array: T[], size: number): T[][] {
  return Array.from({ length: Math.ceil(array.length / size) }, (_, i) =>
    array.slice(i * size, i * size + size)
  );
}

// Helper function to group observations by patient
function groupByPatient(bundle: any) {
  const result: Record<string, any[]> = {};
  
  bundle.entry?.forEach((entry: any) => {
    const resource = entry.resource;
    const patientId = resource.subject?.reference?.split('/')[1];
    
    if (patientId) {
      if (!result[patientId]) {
        result[patientId] = [];
      }
      result[patientId].push(resource);
    }
  });
  
  return result;
}
```

## Clinical Decision Support

### SMART on FHIR CDS Hooks Integration

Implement clinical decision support using SMART on FHIR and CDS Hooks standards.

**Implementation Pattern:**
- Register CDS services with the platform
- Process hook events (patient-view, medication-prescribe, etc.)
- Return cards with recommendations

```typescript
// Example: CDS Hooks service for medication interactions
import express from 'express';
import { FhirClient } from '../services/fhir-client';

const app = express();
app.use(express.json());

// CDS Service discovery endpoint
app.get('/cds-services', (req, res) => {
  res.json({
    'services': [
      {
        'id': 'medication-interaction-check',
        'hook': 'medication-prescribe',
        'title': 'Medication Interaction Checker',
        'description': 'Checks for potential medication interactions',
        'prefetch': {
          'patient': 'Patient/{{context.patientId}}',
          'medications': 'MedicationRequest?patient={{context.patientId}}&status=active'
        }
      }
    ]
  });
});

// CDS Service endpoint for medication interaction checking
app.post('/cds-services/medication-interaction-check', async (req, res) => {
  try {
    const hook = req.body.hook;
    const context = req.body.context;
    const prefetch = req.body.prefetch || {};
    
    // Get patient and current medications from prefetch or fetch if needed
    const patient = prefetch.patient || await fetchPatient(context.patientId);
    const medications = prefetch.medications || await fetchMedications(context.patientId);
    
    // Get the medication being prescribed
    const draftMedication = context.draftOrders?.MedicationRequest[0];
    
    if (!draftMedication) {
      return res.json({ cards: [] });
    }
    
    // Check for interactions
    const interactions = await checkInteractions(medications, draftMedication);
    
    if (interactions.length === 0) {
      return res.json({ cards: [] });
    }
    
    // Return cards with interaction warnings
    const cards = interactions.map(interaction => ({
      summary: 'Potential medication interaction detected',
      indicator: interaction.severity === 'severe' ? 'critical' : 'warning',
      detail: `Potential ${interaction.severity} interaction between ${interaction.medication1} and ${interaction.medication2}: ${interaction.description}`,
      source: {
        label: 'Medication Knowledge Base',
        url: 'https://example.org/medication-knowledge-base'
      },
      suggestions: [
        {
          label: 'Cancel prescription',
          action: {
            type: 'delete',
            description: 'Remove this prescription'
          }
        },
        {
          label: 'Modify dosage',
          action: {
            type: 'update',
            description: 'Reduce dosage to avoid interaction',
            resource: {
              ...draftMedication,
              dosageInstruction: [
                {
                  ...draftMedication.dosageInstruction[0],
                  doseAndRate: [
                    {
                      doseQuantity: {
                        value: draftMedication.dosageInstruction[0].doseAndRate[0].doseQuantity.value / 2,
                        unit: draftMedication.dosageInstruction[0].doseAndRate[0].doseQuantity.unit
                      }
                    }
                  ]
                }
              ]
            }
          }
        }
      ]
    }));
    
    res.json({ cards });
  } catch (error) {
    console.error('Error in CDS service:', error);
    res.status(500).json({
      cards: [{
        summary: 'Error processing medication interaction check',
        indicator: 'warning',
        detail: 'An error occurred while checking for medication interactions.'
      }]
    });
  }
});

// Helper functions for fetching data and checking interactions
async function fetchPatient(patientId: string) {
  // Implementation details
}

async function fetchMedications(patientId: string) {
  // Implementation details
}

async function checkInteractions(currentMedications: any[], draftMedication: any) {
  // Implementation details
  return [];
}

app.listen(3000, () => {
  console.log('CDS Hooks service running on port 3000');
});
```

## Healthcare Research

### De-identified Data Export for Research

Export de-identified FHIR data for research purposes while maintaining compliance with privacy regulations.

**Implementation Pattern:**
- Use Bulk Data API for efficient export
- Apply de-identification algorithms to exported data
- Maintain audit trail of all exports

```typescript
// Example: De-identified data export for research
import { BulkDataClient } from '../services/bulk-data-client';
import { DeidentificationService } from '../services/deidentification-service';
import { AuditService } from '../services/audit-service';

async function exportDeidentifiedDataForResearch(
  bulkClient: BulkDataClient,
  deidentificationService: DeidentificationService,
  auditService: AuditService,
  studyId: string,
  resourceTypes: string[],
  criteria: Record<string, string>,
  requestedBy: string
) {
  try {
    // Step 1: Log the export request
    const auditEntry = await auditService.logExportRequest({
      studyId,
      resourceTypes,
      criteria,
      requestedBy,
      timestamp: new Date().toISOString(),
      status: 'initiated'
    });
    
    // Step 2: Start the bulk data export
    const exportUrl = await bulkClient.startSystemExport(resourceTypes, criteria);
    
    // Step 3: Monitor export status until complete
    let status = 'in-progress';
    let outputFiles;
    
    while (status === 'in-progress') {
      await new Promise(resolve => setTimeout(resolve, 5000)); // Wait 5 seconds
      const statusResult = await bulkClient.checkExportStatus(exportUrl);
      status = statusResult.status;
      
      if (status === 'complete') {
        outputFiles = statusResult.output;
      } else if (status === 'error') {
        throw new Error(`Export failed: ${statusResult.error}`);
      }
    }
    
    // Step 4: Download and de-identify each output file
    const deidentifiedFiles = [];
    
    for (const file of outputFiles) {
      // Download the file
      const data = await bulkClient.downloadExportFile(file.url);
      
      // De-identify the data
      const deidentifiedData = await deidentificationService.deidentify(data, {
        resourceType: file.type,
        studyId,
        keepDates: true,
        dateShiftStrategy: 'random-shift',
        maxShiftDays: 30,
        hashIdentifiers: true,
        removeNarratives: true,
        zipCodes: 'first-3-digits',
        ages: 'truncate-90-plus'
      });
      
      // Save the de-identified data
      const savedFile = await deidentificationService.saveDeidentifiedData(deidentifiedData, {
        studyId,
        resourceType: file.type,
        format: 'ndjson'
      });
      
      deidentifiedFiles.push(savedFile);
    }
    
    // Step 5: Update the audit log
    await auditService.updateExportRequest(auditEntry.id, {
      status: 'completed',
      completedAt: new Date().toISOString(),
      outputFiles: deidentifiedFiles.map(file => file.url),
      recordCount: deidentifiedFiles.reduce((sum, file) => sum + file.recordCount, 0)
    });
    
    return {
      status: 'success',
      studyId,
      files: deidentifiedFiles,
      totalRecords: deidentifiedFiles.reduce((sum, file) => sum + file.recordCount, 0)
    };
  } catch (error) {
    // Log the error and update audit entry
    await auditService.updateExportRequest(auditEntry.id, {
      status: 'failed',
      error: error.message
    });
    
    throw error;
  }
}
```

## Care Coordination

### Multi-Organization Care Planning

Implement collaborative care planning across multiple healthcare organizations.

**Implementation Pattern:**
- Use FHIR CarePlan and related resources
- Implement subscription-based notifications
- Apply consent-based access controls

```typescript
// Example: Creating and sharing a care plan across organizations
import { FhirClient } from '../services/fhir-client';
import { NotificationService } from '../services/notification-service';
import { ConsentService } from '../services/consent-service';

async function createCollaborativeCarePlan(
  fhirClient: FhirClient,
  notificationService: NotificationService,
  consentService: ConsentService,
  patientId: string,
  primaryOrganizationId: string,
  collaboratingOrganizationIds: string[],
  carePlanDetails: any
) {
  // Step 1: Verify patient consent for sharing data with collaborating organizations
  const consentCheck = await consentService.checkDataSharingConsent(
    patientId,
    collaboratingOrganizationIds
  );
  
  if (!consentCheck.allConsentsGranted) {
    throw new Error(`Missing consent for organizations: ${consentCheck.missingConsentFor.join(', ')}`);
  }
  
  // Step 2: Create the CarePlan resource
  const carePlan = {
    resourceType: 'CarePlan',
    status: 'active',
    intent: 'plan',
    subject: {
      reference: `Patient/${patientId}`
    },
    created: new Date().toISOString(),
    author: {
      reference: `Organization/${primaryOrganizationId}`
    },
    careTeam: [
      {
        reference: `CareTeam/${carePlanDetails.careTeamId}`
      }
    ],
    addresses: carePlanDetails.addresses.map((condition: string) => ({
      reference: `Condition/${condition}`
    })),
    goal: carePlanDetails.goals.map((goal: string) => ({
      reference: `Goal/${goal}`
    })),
    activity: carePlanDetails.activities.map((activity: any) => ({
      reference: activity.reference,
      detail: activity.detail
    })),
    note: [
      {
        text: 'This is a collaborative care plan shared across multiple organizations.'
      }
    ]
  };
  
  // Step 3: Save the CarePlan
  const savedCarePlan = await fhirClient.create('CarePlan', carePlan);
  
  // Step 4: Create CarePlan access permissions for collaborating organizations
  for (const orgId of collaboratingOrganizationIds) {
    await consentService.grantAccessToResource(
      savedCarePlan.id,
      'CarePlan',
      orgId,
      ['read', 'update']
    );
  }
  
  // Step 5: Notify collaborating organizations
  for (const orgId of collaboratingOrganizationIds) {
    await notificationService.sendCarePlanNotification({
      organizationId: orgId,
      patientId,
      carePlanId: savedCarePlan.id,
      notificationType: 'new-care-plan',
      message: `A new collaborative care plan has been created for patient ${patientId}`,
      sender: primaryOrganizationId
    });
  }
  
  // Step 6: Set up subscriptions for updates to the care plan
  const subscription = {
    resourceType: 'Subscription',
    status: 'active',
    reason: 'Collaborative care plan monitoring',
    criteria: `CarePlan?_id=${savedCarePlan.id}`,
    channel: {
      type: 'rest-hook',
      endpoint: 'https://care-coordination.example.org/fhir/subscription-callback',
      payload: 'application/fhir+json'
    }
  };
  
  await fhirClient.create('Subscription', subscription);
  
  return {
    carePlanId: savedCarePlan.id,
    collaboratingOrganizations: collaboratingOrganizationIds,
    accessPermissionsGranted: true
  };
}
```

## Related Resources

- [FHIR Interoperability Platform Overview](../01-getting-started/overview.md)
- [Core APIs](../02-core-functionality/core-apis.md)
- [Integration Points](../02-core-functionality/integration-points.md)
- [Extension Points](extension-points.md)
- [Customization](customization.md)
