# FHIR Load Testing and Benchmarking

## Introduction

Load testing and benchmarking are essential practices for ensuring that your FHIR server can handle expected workloads and identifying performance bottlenecks. This guide explains how to effectively test and benchmark your FHIR server, covering performance baseline establishment, realistic workload simulation, bottleneck identification, and measuring optimization impact. By implementing these testing strategies, you can ensure your FHIR server meets performance requirements under real-world conditions.

### Quick Start

1. Establish performance baselines for your FHIR server
2. Create realistic test scenarios that reflect actual usage patterns
3. Implement load testing to identify performance bottlenecks
4. Measure the impact of performance optimizations
5. Establish ongoing performance monitoring and benchmarking

### Related Components

- [FHIR Server Monitoring](fhir-server-monitoring.md): Monitor server performance
- [FHIR Database Optimization](fhir-database-optimization.md): Optimize database performance
- [FHIR Query Performance](fhir-query-performance.md): Optimize FHIR query patterns
- [FHIR Server Configuration](fhir-server-configuration.md): Configure server for optimal performance

## Establishing Performance Baselines

Performance baselines provide a reference point for measuring improvements and identifying regressions.

### Key Performance Metrics

Identify and measure the key performance metrics for your FHIR server.

| Metric | Description | Target Range |
|--------|-------------|-------------|
| Response time | Time to process and respond to requests | 95th percentile < 500ms |
| Throughput | Number of requests processed per second | Depends on server capacity |
| Error rate | Percentage of requests resulting in errors | < 0.1% |
| Resource utilization | CPU, memory, disk, and network usage | < 80% during peak load |
| Concurrent users | Number of simultaneous users supported | Depends on requirements |

### Creating a Baseline Test Suite

```typescript
import * as k6 from 'k6';
import { check, sleep } from 'k6';
import http from 'k6/http';

// Configuration
const BASE_URL = 'http://fhir-server.example.com/fhir';
const AUTH_TOKEN = 'Bearer your-token-here';

// Options for the baseline test
export const options = {
  vus: 10, // 10 virtual users
  duration: '5m', // 5 minute test
  thresholds: {
    http_req_duration: ['p95<500'], // 95% of requests should be below 500ms
    http_req_failed: ['rate<0.01'], // Less than 1% error rate
  },
};

// Test scenario
export default function() {
  // Common headers
  const headers = {
    'Content-Type': 'application/fhir+json',
    'Accept': 'application/fhir+json',
    'Authorization': AUTH_TOKEN
  };
  
  // 1. Patient read operation
  let patientResponse = http.get(`${BASE_URL}/Patient/example`, { headers });
  check(patientResponse, {
    'Patient read status is 200': (r) => r.status === 200,
    'Patient read duration < 200ms': (r) => r.timings.duration < 200
  });
  
  sleep(1);
  
  // 2. Patient search operation
  let searchResponse = http.get(`${BASE_URL}/Patient?family=Smith&_count=10`, { headers });
  check(searchResponse, {
    'Patient search status is 200': (r) => r.status === 200,
    'Patient search duration < 300ms': (r) => r.timings.duration < 300
  });
  
  sleep(1);
  
  // 3. Observation search by patient
  let obsResponse = http.get(`${BASE_URL}/Observation?patient=Patient/example&_count=10`, { headers });
  check(obsResponse, {
    'Observation search status is 200': (r) => r.status === 200,
    'Observation search duration < 400ms': (r) => r.timings.duration < 400
  });
  
  sleep(1);
  
  // 4. Create a new Observation
  const newObservation = JSON.stringify({
    resourceType: 'Observation',
    status: 'final',
    code: {
      coding: [{
        system: 'http://loinc.org',
        code: '8867-4',
        display: 'Heart rate'
      }]
    },
    subject: {
      reference: 'Patient/example'
    },
    effectiveDateTime: new Date().toISOString(),
    valueQuantity: {
      value: 80,
      unit: 'beats/min',
      system: 'http://unitsofmeasure.org',
      code: '/min'
    }
  });
  
  let createResponse = http.post(`${BASE_URL}/Observation`, newObservation, { headers });
  check(createResponse, {
    'Observation create status is 201': (r) => r.status === 201,
    'Observation create duration < 500ms': (r) => r.timings.duration < 500
  });
  
  sleep(1);
}
```

### Running Baseline Tests

```bash
# Run the baseline test
k6 run baseline-test.js

# Output results to JSON for later comparison
k6 run --out json=baseline-results.json baseline-test.js

# Run with different virtual user counts to find capacity limits
k6 run --vus 20 --duration 5m baseline-test.js
k6 run --vus 50 --duration 5m baseline-test.js
k6 run --vus 100 --duration 5m baseline-test.js
```

## Simulating Realistic Workloads

Create test scenarios that accurately reflect real-world usage patterns.

### User Journey Simulation

Simulate complete user journeys rather than isolated API calls.

```typescript
// Example user journey: Patient encounter workflow
export function patientEncounterJourney() {
  const headers = {
    'Content-Type': 'application/fhir+json',
    'Accept': 'application/fhir+json',
    'Authorization': AUTH_TOKEN
  };
  
  // 1. Search for patient
  let patientSearchResponse = http.get(
    `${BASE_URL}/Patient?identifier=http://hospital.example.org|123456`, 
    { headers }
  );
  
  check(patientSearchResponse, {
    'Patient search successful': (r) => r.status === 200
  });
  
  // Extract patient ID from search results
  let patientId = 'Patient/example'; // Default fallback
  try {
    const body = JSON.parse(patientSearchResponse.body);
    if (body.entry && body.entry.length > 0) {
      patientId = body.entry[0].resource.id;
      patientId = `Patient/${patientId}`;
    }
  } catch (e) {
    console.error('Failed to parse patient search response');
  }
  
  sleep(2); // Simulate user reviewing search results
  
  // 2. Get patient details
  let patientReadResponse = http.get(
    `${BASE_URL}/${patientId}`, 
    { headers }
  );
  
  check(patientReadResponse, {
    'Patient read successful': (r) => r.status === 200
  });
  
  sleep(3); // Simulate user reviewing patient details
  
  // 3. Create new encounter
  const newEncounter = JSON.stringify({
    resourceType: 'Encounter',
    status: 'in-progress',
    class: {
      system: 'http://terminology.hl7.org/CodeSystem/v3-ActCode',
      code: 'AMB',
      display: 'ambulatory'
    },
    subject: {
      reference: patientId
    },
    period: {
      start: new Date().toISOString()
    },
    serviceType: {
      coding: [{
        system: 'http://terminology.hl7.org/CodeSystem/service-type',
        code: '124',
        display: 'General Practice'
      }]
    }
  });
  
  let encounterResponse = http.post(
    `${BASE_URL}/Encounter`, 
    newEncounter, 
    { headers }
  );
  
  check(encounterResponse, {
    'Encounter creation successful': (r) => r.status === 201
  });
  
  // Extract encounter ID
  let encounterId = 'Encounter/example'; // Default fallback
  try {
    const body = JSON.parse(encounterResponse.body);
    if (body.id) {
      encounterId = `Encounter/${body.id}`;
    }
  } catch (e) {
    console.error('Failed to parse encounter creation response');
  }
  
  sleep(5); // Simulate clinical documentation time
  
  // 4. Create vital signs observation
  const newObservation = JSON.stringify({
    resourceType: 'Observation',
    status: 'final',
    category: [{
      coding: [{
        system: 'http://terminology.hl7.org/CodeSystem/observation-category',
        code: 'vital-signs',
        display: 'Vital Signs'
      }]
    }],
    code: {
      coding: [{
        system: 'http://loinc.org',
        code: '8867-4',
        display: 'Heart rate'
      }]
    },
    subject: {
      reference: patientId
    },
    encounter: {
      reference: encounterId
    },
    effectiveDateTime: new Date().toISOString(),
    valueQuantity: {
      value: 80,
      unit: 'beats/min',
      system: 'http://unitsofmeasure.org',
      code: '/min'
    }
  });
  
  let observationResponse = http.post(
    `${BASE_URL}/Observation`, 
    newObservation, 
    { headers }
  );
  
  check(observationResponse, {
    'Observation creation successful': (r) => r.status === 201
  });
  
  sleep(2);
}
```

### Data Volume and Distribution

Ensure test data reflects realistic volume and distribution patterns.

```typescript
// Example function to generate realistic test data distribution
function generateTestData() {
  // Patient demographics distribution
  const ageGroups = [
    { min: 0, max: 18, weight: 20 },    // 20% pediatric
    { min: 19, max: 64, weight: 60 },   // 60% adult
    { min: 65, max: 100, weight: 20 }   // 20% geriatric
  ];
  
  const genderDistribution = [
    { value: 'male', weight: 49 },
    { value: 'female', weight: 49 },
    { value: 'other', weight: 2 }
  ];
  
  // Resource type distribution
  const resourceDistribution = [
    { type: 'Observation', weight: 50 },     // 50% Observations
    { type: 'Condition', weight: 15 },        // 15% Conditions
    { type: 'MedicationRequest', weight: 15 }, // 15% Medication requests
    { type: 'Procedure', weight: 10 },         // 10% Procedures
    { type: 'AllergyIntolerance', weight: 5 },  // 5% Allergies
    { type: 'Immunization', weight: 5 }         // 5% Immunizations
  ];
  
  // Select based on weighted distribution
  function selectFromDistribution(distribution) {
    const total = distribution.reduce((sum, item) => sum + item.weight, 0);
    let random = Math.random() * total;
    
    for (const item of distribution) {
      random -= item.weight;
      if (random <= 0) {
        return item;
      }
    }
    
    return distribution[0]; // Fallback
  }
  
  // Generate patient data
  function generatePatient() {
    const ageGroup = selectFromDistribution(ageGroups);
    const age = Math.floor(Math.random() * (ageGroup.max - ageGroup.min + 1)) + ageGroup.min;
    const birthYear = new Date().getFullYear() - age;
    const birthMonth = Math.floor(Math.random() * 12) + 1;
    const birthDay = Math.floor(Math.random() * 28) + 1; // Simplified to avoid date validation
    
    const gender = selectFromDistribution(genderDistribution).value;
    
    return {
      resourceType: 'Patient',
      gender: gender,
      birthDate: `${birthYear}-${birthMonth.toString().padStart(2, '0')}-${birthDay.toString().padStart(2, '0')}`,
      // Additional fields would be added here
    };
  }
  
  // Generate a test dataset
  const patients = [];
  for (let i = 0; i < 100; i++) {
    patients.push(generatePatient());
  }
  
  return patients;
}
```

### Realistic Load Patterns

Simulate realistic load patterns including peak usage and daily variations.

```typescript
// Example test with realistic load patterns
export const options = {
  scenarios: {
    // Morning peak (8-10 AM)
    morningPeak: {
      executor: 'ramping-vus',
      startVUs: 10,
      stages: [
        { duration: '15m', target: 50 },  // Ramp up to morning peak
        { duration: '30m', target: 50 },  // Sustain morning peak
        { duration: '15m', target: 20 },  // Ramp down to mid-day
      ],
      gracefulRampDown: '5m',
      exec: 'morningWorkflow'
    },
    
    // Afternoon steady load (11 AM - 3 PM)
    afternoonLoad: {
      executor: 'constant-vus',
      vus: 20,
      duration: '4h',
      startTime: '1h', // Start after morning peak begins
      exec: 'afternoonWorkflow'
    },
    
    // Evening peak (3-5 PM)
    eveningPeak: {
      executor: 'ramping-vus',
      startVUs: 20,
      stages: [
        { duration: '15m', target: 40 },  // Ramp up to evening peak
        { duration: '30m', target: 40 },  // Sustain evening peak
        { duration: '15m', target: 5 },   // Ramp down to evening
      ],
      startTime: '5h', // Start after afternoon load begins
      exec: 'eveningWorkflow'
    },
    
    // Night-time low activity (6 PM - 7 AM)
    nightLoad: {
      executor: 'constant-vus',
      vus: 5,
      duration: '13h',
      startTime: '7h', // Start after evening peak begins
      exec: 'nightWorkflow'
    }
  }
};

// Different workflow functions for different times of day
export function morningWorkflow() {
  // Morning workflows: patient registration, appointment check-ins
  // Implementation here
}

export function afternoonWorkflow() {
  // Afternoon workflows: clinical documentation, order entry
  // Implementation here
}

export function eveningWorkflow() {
  // Evening workflows: discharge summaries, shift handovers
  // Implementation here
}

export function nightWorkflow() {
  // Night workflows: emergency cases, batch processing
  // Implementation here
}
```

## Identifying Performance Bottlenecks

Use load testing to identify and diagnose performance bottlenecks.

### Gradual Load Increase

Increase load gradually to identify breaking points.

```typescript
// Example test with gradual load increase
export const options = {
  stages: [
    { duration: '5m', target: 10 },   // Start with 10 users
    { duration: '5m', target: 20 },   // Ramp up to 20 users
    { duration: '5m', target: 30 },   // Ramp up to 30 users
    { duration: '5m', target: 40 },   // Ramp up to 40 users
    { duration: '5m', target: 50 },   // Ramp up to 50 users
    { duration: '5m', target: 60 },   // Ramp up to 60 users
    { duration: '5m', target: 70 },   // Ramp up to 70 users
    { duration: '5m', target: 80 },   // Ramp up to 80 users
    { duration: '5m', target: 90 },   // Ramp up to 90 users
    { duration: '5m', target: 100 },  // Ramp up to 100 users
    { duration: '10m', target: 100 }, // Stay at 100 users for 10 minutes
    { duration: '5m', target: 0 }     // Ramp down to 0 users
  ],
  thresholds: {
    http_req_duration: ['p95<500'], // 95% of requests should be below 500ms
    http_req_failed: ['rate<0.01'],  // Less than 1% error rate
  }
};
```

### Resource Utilization Monitoring

Monitor system resources during load tests to identify bottlenecks.

```bash
# Run load test while monitoring system resources

# Start resource monitoring in one terminal
top -b -d 1 > cpu_memory_log.txt &
iostat -xm 5 > disk_io_log.txt &
netstat -s 5 > network_stats_log.txt &

# Run the load test in another terminal
k6 run load-test.js

# After the test completes, stop the monitoring
killall top
killall iostat
killall netstat

# Analyze the logs to identify bottlenecks
grep -A 5 "load average" cpu_memory_log.txt | less
grep "await" disk_io_log.txt | less
grep "retransmitted" network_stats_log.txt | less
```

### Database Query Analysis

Analyze database query performance during load tests.

```sql
-- PostgreSQL query to identify slow queries during load test
SELECT
    query,
    calls,
    total_time,
    mean_time,
    rows,
    100.0 * shared_blks_hit / nullif(shared_blks_hit + shared_blks_read, 0) AS hit_percent
FROM pg_stat_statements
ORDER BY total_time DESC
LIMIT 20;

-- PostgreSQL query to identify missing indexes
SELECT
    relname AS table_name,
    seq_scan - idx_scan AS too_much_seq,
    CASE
        WHEN seq_scan - idx_scan > 0 THEN 'Missing Index?'
        ELSE 'OK'
    END AS index_recommendation,
    pg_size_pretty(pg_relation_size(relid)) AS table_size,
    seq_scan, idx_scan
FROM pg_stat_user_tables
WHERE pg_relation_size(relid) > 80000
ORDER BY too_much_seq DESC;
```

## Measuring Optimization Impact

Measure the impact of performance optimizations to validate improvements.

### Before and After Comparison

Compare performance metrics before and after optimization.

```typescript
// Example script to compare before and after test results
import fs from 'fs';

// Load test results
const beforeResults = JSON.parse(fs.readFileSync('before-optimization.json', 'utf8'));
const afterResults = JSON.parse(fs.readFileSync('after-optimization.json', 'utf8'));

// Compare key metrics
function compareMetrics() {
  const metrics = [
    'http_req_duration',
    'http_reqs',
    'http_req_failed',
    'iteration_duration'
  ];
  
  console.log('Performance Comparison: Before vs After Optimization');
  console.log('=================================================');
  
  for (const metric of metrics) {
    const before = beforeResults.metrics[metric];
    const after = afterResults.metrics[metric];
    
    if (before && after) {
      // For duration metrics
      if (metric.includes('duration')) {
        const beforeAvg = before.values.avg;
        const afterAvg = after.values.avg;
        const improvement = ((beforeAvg - afterAvg) / beforeAvg) * 100;
        
        console.log(`${metric}:`);
        console.log(`  Before: ${beforeAvg.toFixed(2)}ms`);
        console.log(`  After:  ${afterAvg.toFixed(2)}ms`);
        console.log(`  Improvement: ${improvement.toFixed(2)}%`);
      }
      // For rate metrics
      else if (metric.includes('failed')) {
        const beforeRate = before.values.rate;
        const afterRate = after.values.rate;
        const improvement = ((beforeRate - afterRate) / beforeRate) * 100;
        
        console.log(`${metric}:`);
        console.log(`  Before: ${(beforeRate * 100).toFixed(2)}%`);
        console.log(`  After:  ${(afterRate * 100).toFixed(2)}%`);
        console.log(`  Improvement: ${improvement.toFixed(2)}%`);
      }
      // For count metrics
      else {
        const beforeCount = before.values.count;
        const afterCount = after.values.count;
        const improvement = ((afterCount - beforeCount) / beforeCount) * 100;
        
        console.log(`${metric}:`);
        console.log(`  Before: ${beforeCount}`);
        console.log(`  After:  ${afterCount}`);
        console.log(`  Improvement: ${improvement.toFixed(2)}%`);
      }
      
      console.log('--------------------------------------------------');
    }
  }
}

compareMetrics();
```

### Incremental Optimization Testing

Test each optimization individually to measure its specific impact.

```bash
# Example workflow for incremental optimization testing

# 1. Run baseline test
k6 run --out json=baseline.json load-test.js

# 2. Apply first optimization (e.g., database indexing)
# ... apply database indexing changes ...

# 3. Run test with first optimization
k6 run --out json=optimization1.json load-test.js

# 4. Apply second optimization (e.g., caching)
# ... implement caching ...

# 5. Run test with first and second optimizations
k6 run --out json=optimization2.json load-test.js

# 6. Apply third optimization (e.g., connection pooling)
# ... configure connection pooling ...

# 7. Run test with all optimizations
k6 run --out json=optimization3.json load-test.js

# 8. Compare results
node compare-results.js baseline.json optimization1.json
node compare-results.js optimization1.json optimization2.json
node compare-results.js optimization2.json optimization3.json
node compare-results.js baseline.json optimization3.json
```

## Conclusion

Effective load testing and benchmarking are essential for ensuring that your FHIR server can handle expected workloads and identifying performance bottlenecks. By establishing performance baselines, simulating realistic workloads, identifying bottlenecks, and measuring optimization impact, you can create a high-performance FHIR server that meets your organization's needs.

Key takeaways:

1. Establish performance baselines to measure improvements and identify regressions
2. Create realistic test scenarios that reflect actual usage patterns
3. Use gradual load increases to identify breaking points and bottlenecks
4. Monitor system resources during load tests to pinpoint constraints
5. Measure the impact of each optimization to validate improvements

By following these guidelines, you can ensure that your FHIR server performs well under real-world conditions and can scale to meet future demands.
