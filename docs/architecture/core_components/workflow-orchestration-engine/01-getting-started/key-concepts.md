# Workflow Orchestration Engine Key Concepts

## Introduction

The Workflow Orchestration Engine is built on several key concepts that enable robust, type-safe workflow orchestration for healthcare applications. This document explains the fundamental concepts, terminology, and patterns used in our TypeScript-based, cloud-native implementation.

## Core Concepts

### Durable Execution

Durable execution is a pattern where workflow state is automatically persisted, allowing workflows to survive process crashes, machine failures, and service restarts. This is essential for healthcare workflows that may run for extended periods.

```typescript
// Example: Durable workflow with TypeScript
import { workflow } from '@temporalio/workflow';

@workflow()
export class DurableWorkflow {
  // State is automatically persisted between workflow task executions
  private state = {
    attempts: 0,
    lastProcessedStep: '',
  };

  @workflow.run
  async run(patientId: string): Promise<string> {
    // This workflow will automatically resume from the last completed step
    // even if the process crashes or the server restarts
    
    this.state.lastProcessedStep = 'starting';
    
    // Step 1: Verify eligibility
    const eligibilityResult = await this.verifyEligibility(patientId);
    this.state.lastProcessedStep = 'eligibility-verified';
    
    // Step 2: Process clinical data
    const clinicalResult = await this.processClinicalData(patientId);
    this.state.lastProcessedStep = 'clinical-processed';
    
    // Step 3: Make determination
    const determination = await this.makeDetermination(eligibilityResult, clinicalResult);
    this.state.lastProcessedStep = 'determination-complete';
    
    return determination;
  }
  
  // Activity methods would be defined here
  private async verifyEligibility(patientId: string): Promise<any> { /* ... */ }
  private async processClinicalData(patientId: string): Promise<any> { /* ... */ }
  private async makeDetermination(eligibility: any, clinical: any): Promise<string> { /* ... */ }
}
```

### Workflow and Activity Separation

The engine separates workflow logic (the orchestration of steps) from activity logic (the actual work performed). This separation enables:

- **Deterministic Workflows**: Workflow code must be deterministic (same inputs produce same outputs)
- **Non-Deterministic Activities**: Activities can contain non-deterministic code (API calls, database queries)
- **Independent Scaling**: Activities can be scaled independently based on their resource requirements

```typescript
// Workflow definition (orchestration logic)
import { workflow, proxyActivities } from '@temporalio/workflow';
import type * as activities from '../activities';

const { checkEligibility, processClaim, notifyProvider } = proxyActivities<typeof activities>({
  startToCloseTimeout: '10 minutes',
});

@workflow()
export class ClaimsProcessingWorkflow {
  @workflow.run
  async run(claimId: string): Promise<string> {
    // Orchestration logic - determines the sequence of activities
    const eligibilityResult = await checkEligibility(claimId);
    
    if (eligibilityResult.eligible) {
      const processResult = await processClaim(claimId);
      await notifyProvider(claimId, processResult.status);
      return processResult.status;
    } else {
      await notifyProvider(claimId, 'DENIED');
      return 'DENIED';
    }
  }
}

// Activity implementations (actual work)
export async function checkEligibility(claimId: string): Promise<{ eligible: boolean }> {
  // Non-deterministic code is allowed in activities
  // This could call external APIs, query databases, etc.
  const response = await fetch(`https://eligibility-api.example.com/claims/${claimId}`);
  const data = await response.json();
  return { eligible: data.status === 'ELIGIBLE' };
}

export async function processClaim(claimId: string): Promise<{ status: string }> {
  // Process the claim in the claims system
  // ...
  return { status: 'APPROVED' };
}

export async function notifyProvider(claimId: string, status: string): Promise<void> {
  // Send notification to provider
  // ...
}
```

### Type-Safe Workflows

The TypeScript implementation provides end-to-end type safety for workflows, activities, and data models.

```typescript
// Type definitions for workflow inputs and outputs
export interface PriorAuthRequest {
  id: string;
  patientId: string;
  providerId: string;
  serviceType: string;
  serviceDate: string;
  diagnosisCodes: string[];
  procedureCodes: string[];
  insuranceInfo: {
    payerId: string;
    memberId: string;
    groupNumber?: string;
  };
}

export interface PriorAuthResult {
  id: string;
  status: 'APPROVED' | 'DENIED' | 'PENDING_REVIEW';
  authorizationNumber?: string;
  expirationDate?: string;
  denialReason?: string;
  reviewDetails?: {
    reviewerId: string;
    reviewDate: string;
    notes: string;
  };
}

// Type-safe workflow implementation
@workflow()
export class PriorAuthorizationWorkflow {
  @workflow.run
  async run(request: PriorAuthRequest): Promise<PriorAuthResult> {
    // Implementation with full type safety
    // ...
  }
}
```

### Saga Pattern

The Saga pattern manages distributed transactions across multiple services, with compensating actions for failures.

```typescript
import { workflow, proxyActivities, CancellationScope } from '@temporalio/workflow';
import type * as activities from '../activities';

const { 
  reserveAppointment, 
  cancelAppointment,
  chargePayment, 
  refundPayment,
  sendConfirmation,
  sendCancellation 
} = proxyActivities<typeof activities>({
  startToCloseTimeout: '5 minutes',
});

@workflow()
export class AppointmentBookingWorkflow {
  @workflow.run
  async run(appointmentData: any): Promise<any> {
    let appointmentId: string | undefined;
    let paymentId: string | undefined;
    
    try {
      // Step 1: Reserve appointment
      appointmentId = await reserveAppointment(appointmentData);
      
      // Step 2: Process payment
      paymentId = await chargePayment(appointmentData.paymentInfo, appointmentData.amount);
      
      // Step 3: Send confirmation
      await sendConfirmation(appointmentId, paymentId);
      
      return { appointmentId, paymentId, status: 'CONFIRMED' };
    } catch (error) {
      // Compensating transactions in reverse order
      if (paymentId) {
        await refundPayment(paymentId);
      }
      
      if (appointmentId) {
        await cancelAppointment(appointmentId);
        await sendCancellation(appointmentId);
      }
      
      throw error;
    }
  }
}
```

### Event-Driven Workflows

Workflows can be triggered by and respond to events from the Event Broker.

```typescript
// Event-driven workflow starter
import { Consumer } from '@cmm/event-broker';
import { Client } from '@temporalio/client';
import { PatientAdmissionEvent } from './event-types';
import { AdmissionWorkflow } from './workflows/admission-workflow';

async function startEventDrivenWorker() {
  // Connect to Temporal
  const client = new Client();
  
  // Set up Kafka consumer
  const consumer = new Consumer({
    bootstrapServers: ['kafka:9092'],
    groupId: 'admission-workflow-starter',
    topics: ['patient-admissions']
  });
  
  // Process events and start workflows
  await consumer.subscribe(async (message) => {
    const event = message.value as PatientAdmissionEvent;
    
    // Start a workflow for each admission event
    await client.workflow.start(AdmissionWorkflow, {
      args: [event],
      taskQueue: 'healthcare-workflows',
      workflowId: `admission-${event.encounterId}`,
    });
    
    // Acknowledge the message
    await message.ack();
  });
}
```

### Signal-Based Communication

Workflows can receive signals to handle external events or user interactions during execution.

```typescript
import { workflow, proxyActivities, defineSignal } from '@temporalio/workflow';
import type * as activities from '../activities';

const { notifyReviewer, processApproval, processDenial } = proxyActivities<typeof activities>({
  startToCloseTimeout: '10 minutes',
});

// Define signals with TypeScript types
const approveSignal = defineSignal<[string]>('approve');
const denySignal = defineSignal<[string, string]>('deny');

@workflow()
export class ClinicalReviewWorkflow {
  private reviewDecision: 'APPROVED' | 'DENIED' | null = null;
  private denialReason: string = '';
  
  @workflow.run
  async run(caseId: string, reviewerId: string): Promise<any> {
    // Register signal handlers
    workflow.setHandler(approveSignal, (notes) => {
      this.reviewDecision = 'APPROVED';
      this.denialReason = '';
    });
    
    workflow.setHandler(denySignal, (reason, notes) => {
      this.reviewDecision = 'DENIED';
      this.denialReason = reason;
    });
    
    // Notify reviewer that a case needs review
    await notifyReviewer(caseId, reviewerId);
    
    // Wait for a decision signal (with timeout)
    await workflow.condition(() => this.reviewDecision !== null, '24 hours');
    
    // Process the decision
    if (this.reviewDecision === 'APPROVED') {
      return await processApproval(caseId);
    } else {
      return await processDenial(caseId, this.denialReason);
    }
  }
}
```

### Child Workflows

Complex processes can be broken down into modular, reusable child workflows.

```typescript
import { workflow, proxyActivities, executeChild } from '@temporalio/workflow';
import { EligibilityWorkflow } from './eligibility-workflow';
import { ClinicalReviewWorkflow } from './clinical-review-workflow';
import { NotificationWorkflow } from './notification-workflow';

@workflow()
export class MasterHealthcareWorkflow {
  @workflow.run
  async run(patientId: string, encounterId: string): Promise<any> {
    // Execute eligibility as a child workflow
    const eligibilityResult = await executeChild(EligibilityWorkflow, {
      args: [patientId],
      workflowId: `eligibility-${encounterId}`,
    });
    
    // If eligible, proceed to clinical review
    if (eligibilityResult.eligible) {
      const reviewResult = await executeChild(ClinicalReviewWorkflow, {
        args: [patientId, encounterId],
        workflowId: `clinical-review-${encounterId}`,
      });
      
      // Send notifications based on the review result
      await executeChild(NotificationWorkflow, {
        args: [patientId, reviewResult],
        workflowId: `notification-${encounterId}`,
      });
      
      return reviewResult;
    } else {
      // Not eligible, send denial notification
      await executeChild(NotificationWorkflow, {
        args: [patientId, { status: 'DENIED', reason: 'Not eligible' }],
        workflowId: `notification-${encounterId}`,
      });
      
      return { status: 'DENIED', reason: 'Not eligible' };
    }
  }
}
```

## Rules Engine Concepts

### Declarative Rule Definitions

Rules are defined declaratively with TypeScript for type safety and validation.

```typescript
import { RuleBuilder, RuleSet } from '@cmm/rules-engine';
import { Patient, Encounter } from 'fhir/r4';

// Define input and output types
interface EligibilityInput {
  patient: Patient;
  encounter: Encounter;
  serviceType: string;
}

interface EligibilityOutput {
  eligible: boolean;
  reason?: string;
  requiresReview: boolean;
}

// Create a typed rule set
const eligibilityRules = new RuleSet<EligibilityInput, EligibilityOutput>('eligibility-rules')
  .addRule(
    new RuleBuilder<EligibilityInput, EligibilityOutput>('age-restriction')
      .when(input => {
        // Calculate age from patient birthDate
        const birthDate = new Date(input.patient.birthDate || '');
        const ageInYears = (new Date().getTime() - birthDate.getTime()) / (1000 * 60 * 60 * 24 * 365);
        return ageInYears < 18;
      })
      .then(input => ({
        eligible: false,
        reason: 'Patient is under 18 years old',
        requiresReview: false
      }))
      .build()
  )
  .addRule(
    new RuleBuilder<EligibilityInput, EligibilityOutput>('service-type-restriction')
      .when(input => {
        const restrictedServices = ['COSMETIC_SURGERY', 'EXPERIMENTAL_TREATMENT'];
        return restrictedServices.includes(input.serviceType);
      })
      .then(input => ({
        eligible: false,
        reason: `Service type ${input.serviceType} is not covered`,
        requiresReview: false
      }))
      .build()
  )
  .addRule(
    new RuleBuilder<EligibilityInput, EligibilityOutput>('high-cost-review')
      .when(input => {
        const highCostServices = ['MRI', 'PET_SCAN', 'SPECIALIZED_SURGERY'];
        return highCostServices.includes(input.serviceType);
      })
      .then(input => ({
        eligible: true,
        requiresReview: true
      }))
      .build()
  )
  .setDefault(() => ({
    eligible: true,
    requiresReview: false
  }));

// Export the rule set
export default eligibilityRules;
```

### Rule Execution

Rules are executed with full type safety and validation.

```typescript
import { RulesEngine } from '@cmm/rules-engine';
import eligibilityRules from './eligibility-rules';
import { Patient, Encounter } from 'fhir/r4';

export class EligibilityService {
  private rulesEngine: RulesEngine;
  
  constructor() {
    this.rulesEngine = new RulesEngine();
    this.rulesEngine.registerRuleSet(eligibilityRules);
  }
  
  async checkEligibility(patient: Patient, encounter: Encounter, serviceType: string): Promise<any> {
    // Execute the rules with type-safe input
    const result = await this.rulesEngine.execute('eligibility-rules', {
      patient,
      encounter,
      serviceType
    });
    
    // Result is type-safe as well
    return result;
  }
}
```

## Event-Driven Concepts

### Typed Event Definitions

Events are defined with TypeScript interfaces for type safety and schema validation.

```typescript
// Event type definitions
export interface BaseEvent {
  id: string;
  timestamp: string;
  source: string;
  type: string;
  version: string;
}

export interface PatientAdmissionEvent extends BaseEvent {
  type: 'patient.admission';
  patientId: string;
  encounterId: string;
  facilityId: string;
  admissionDate: string;
  admittingProvider: string;
  admissionType: 'EMERGENCY' | 'SCHEDULED' | 'TRANSFER';
  diagnosisCodes: string[];
}

export interface PatientDischargeEvent extends BaseEvent {
  type: 'patient.discharge';
  patientId: string;
  encounterId: string;
  facilityId: string;
  dischargeDate: string;
  dischargeDisposition: string;
  lengthOfStay: number;
  followUpRequired: boolean;
}

// Schema registry integration
import { SchemaRegistry } from '@cmm/event-broker';

export async function registerEventSchemas(registry: SchemaRegistry): Promise<void> {
  await registry.registerSchema('patient.admission', {
    type: 'object',
    properties: {
      id: { type: 'string' },
      timestamp: { type: 'string', format: 'date-time' },
      source: { type: 'string' },
      type: { type: 'string', enum: ['patient.admission'] },
      version: { type: 'string' },
      patientId: { type: 'string' },
      encounterId: { type: 'string' },
      facilityId: { type: 'string' },
      admissionDate: { type: 'string', format: 'date-time' },
      admittingProvider: { type: 'string' },
      admissionType: { type: 'string', enum: ['EMERGENCY', 'SCHEDULED', 'TRANSFER'] },
      diagnosisCodes: { type: 'array', items: { type: 'string' } }
    },
    required: ['id', 'timestamp', 'source', 'type', 'version', 'patientId', 'encounterId', 'facilityId', 'admissionDate', 'admissionType']
  });
  
  // Register other event schemas...
}
```

### Event Production and Consumption

Events are produced and consumed with type safety and schema validation.

```typescript
import { Producer, Consumer } from '@cmm/event-broker';
import { PatientAdmissionEvent } from './event-types';

// Producing events
export class AdmissionService {
  private producer: Producer;
  
  constructor(producer: Producer) {
    this.producer = producer;
  }
  
  async admitPatient(admissionData: Omit<PatientAdmissionEvent, 'id' | 'timestamp' | 'source' | 'type' | 'version'>): Promise<void> {
    const event: PatientAdmissionEvent = {
      id: `admission-${Date.now()}`,
      timestamp: new Date().toISOString(),
      source: 'admission-service',
      type: 'patient.admission',
      version: '1.0',
      ...admissionData
    };
    
    await this.producer.produce({
      topic: 'patient-events',
      key: event.patientId,
      value: event
    });
  }
}

// Consuming events
export class AdmissionProcessor {
  private consumer: Consumer;
  
  constructor(consumer: Consumer) {
    this.consumer = consumer;
  }
  
  async start(): Promise<void> {
    await this.consumer.subscribe({
      topics: ['patient-events'],
      handler: async (message) => {
        const event = message.value as PatientAdmissionEvent;
        
        if (event.type === 'patient.admission') {
          // Process admission event with type safety
          await this.processAdmission(event);
        }
        
        // Acknowledge the message
        await message.ack();
      }
    });
  }
  
  private async processAdmission(event: PatientAdmissionEvent): Promise<void> {
    // Process the admission event
    console.log(`Processing admission for patient ${event.patientId} at facility ${event.facilityId}`);
    // ...
  }
}
```

## Observability Concepts

### Distributed Tracing

OpenTelemetry provides distributed tracing across workflow components.

```typescript
import { trace, context } from '@opentelemetry/api';
import { FhirClient } from '@cmm/fhir-client';

export class TracedFhirService {
  private fhirClient: FhirClient;
  private tracer: any;
  
  constructor(fhirClient: FhirClient) {
    this.fhirClient = fhirClient;
    this.tracer = trace.getTracer('fhir-service');
  }
  
  async getPatient(patientId: string): Promise<any> {
    return this.tracer.startActiveSpan('getPatient', async (span: any) => {
      try {
        // Add attributes to the span
        span.setAttribute('patientId', patientId);
        
        // Make the FHIR API call
        const patient = await this.fhirClient.read('Patient', patientId);
        
        // Record successful outcome
        span.setStatus({ code: SpanStatusCode.OK });
        return patient;
      } catch (error) {
        // Record error
        span.setStatus({
          code: SpanStatusCode.ERROR,
          message: error.message
        });
        span.recordException(error);
        throw error;
      } finally {
        // End the span
        span.end();
      }
    });
  }
}
```

### Metrics Collection

Metrics are collected for workflow performance and health monitoring.

```typescript
import { metrics } from '@opentelemetry/api';

export class WorkflowMetrics {
  private workflowStartedCounter: any;
  private workflowCompletedCounter: any;
  private workflowDurationHistogram: any;
  
  constructor() {
    const meter = metrics.getMeter('workflow-metrics');
    
    this.workflowStartedCounter = meter.createCounter('workflow.started', {
      description: 'Number of workflows started',
      unit: '1',
    });
    
    this.workflowCompletedCounter = meter.createCounter('workflow.completed', {
      description: 'Number of workflows completed',
      unit: '1',
    });
    
    this.workflowDurationHistogram = meter.createHistogram('workflow.duration', {
      description: 'Duration of workflow execution',
      unit: 'ms',
    });
  }
  
  recordWorkflowStarted(workflowType: string): void {
    this.workflowStartedCounter.add(1, { workflowType });
  }
  
  recordWorkflowCompleted(workflowType: string, durationMs: number, status: string): void {
    this.workflowCompletedCounter.add(1, { workflowType, status });
    this.workflowDurationHistogram.record(durationMs, { workflowType, status });
  }
}
```

## Conclusion

These key concepts form the foundation of the Workflow Orchestration Engine, providing a robust, type-safe, and cloud-native platform for healthcare workflow automation. By leveraging TypeScript, Temporal.io, and modern cloud-native patterns, the engine delivers reliable, scalable, and maintainable workflow solutions for complex healthcare processes.
