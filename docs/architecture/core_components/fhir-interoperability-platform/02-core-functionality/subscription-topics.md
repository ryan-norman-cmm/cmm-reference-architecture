# FHIR Subscription Topics

## Overview

FHIR Subscription Topics define the events and data that can be subscribed to within the FHIR Interoperability Platform. They provide a standardized way to filter and categorize events that clients may want to receive notifications about. This document covers the creation, management, and usage of FHIR Subscription Topics in healthcare interoperability scenarios.

## Key Concepts

Subscription Topics in FHIR R5 formalize what was previously an implementation-specific aspect of FHIR subscriptions. A Topic:

- Defines a specific category of events (e.g., patient admissions, medication orders)
- Specifies the resource types that are relevant to the topic
- Provides filtering criteria to determine which events match the topic
- Can include transformation rules for notification payloads

## Creating Subscription Topics

### Basic Topic Structure

```json
{
  "resourceType": "SubscriptionTopic",
  "id": "encounter-start",
  "url": "http://example.org/fhir/SubscriptionTopic/encounter-start",
  "status": "active",
  "title": "Encounter Start",
  "description": "Notification when an encounter begins",
  "resourceTrigger": [
    {
      "description": "Encounter status changes to in-progress",
      "resource": "Encounter",
      "supportedInteraction": [
        "create",
        "update"
      ],
      "queryCriteria": {
        "current": "status=in-progress"
      },
      "fhirPathCriteria": "status = 'in-progress'"
    }
  ],
  "canFilterBy": [
    {
      "description": "Filter by patient",
      "resource": "Encounter",
      "filterParameter": "patient"
    },
    {
      "description": "Filter by encounter type",
      "resource": "Encounter",
      "filterParameter": "type"
    }
  ]
}
```

### Healthcare-Specific Topic Examples

#### Patient Demographics Update

```json
{
  "resourceType": "SubscriptionTopic",
  "id": "patient-demographics-update",
  "url": "http://example.org/fhir/SubscriptionTopic/patient-demographics-update",
  "status": "active",
  "title": "Patient Demographics Update",
  "description": "Notification when patient demographics are updated",
  "resourceTrigger": [
    {
      "description": "Patient resource is updated",
      "resource": "Patient",
      "supportedInteraction": [
        "update"
      ]
    }
  ],
  "canFilterBy": [
    {
      "description": "Filter by managing organization",
      "resource": "Patient",
      "filterParameter": "organization"
    }
  ]
}
```

#### Medication Order

```json
{
  "resourceType": "SubscriptionTopic",
  "id": "medication-order",
  "url": "http://example.org/fhir/SubscriptionTopic/medication-order",
  "status": "active",
  "title": "Medication Order",
  "description": "Notification when a medication is ordered",
  "resourceTrigger": [
    {
      "description": "MedicationRequest is created with status active",
      "resource": "MedicationRequest",
      "supportedInteraction": [
        "create",
        "update"
      ],
      "queryCriteria": {
        "current": "status=active"
      }
    }
  ],
  "canFilterBy": [
    {
      "description": "Filter by patient",
      "resource": "MedicationRequest",
      "filterParameter": "patient"
    },
    {
      "description": "Filter by medication",
      "resource": "MedicationRequest",
      "filterParameter": "medication"
    },
    {
      "description": "Filter by requester",
      "resource": "MedicationRequest",
      "filterParameter": "requester"
    }
  ]
}
```

## Managing Subscription Topics

### Topic Registration

Topics must be registered in the FHIR Interoperability Platform before they can be used. This can be done through the FHIR API:

```bash
# Register a new subscription topic
curl -X POST https://fhir-platform.example.org/fhir/SubscriptionTopic \
  -H "Content-Type: application/fhir+json" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -d @topic-definition.json
```

### Topic Discovery

Clients can discover available topics through the FHIR API:

```bash
# Get all available subscription topics
curl https://fhir-platform.example.org/fhir/SubscriptionTopic \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"

# Get details of a specific topic
curl https://fhir-platform.example.org/fhir/SubscriptionTopic/medication-order \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### Topic Versioning

As healthcare workflows evolve, subscription topics may need to be updated. The platform supports topic versioning through:

1. **URL Versioning**: Each version has a unique URL (e.g., `.../medication-order-v2`)
2. **Status Management**: Older versions can be marked as `retired` while newer versions are `active`
3. **Version Metadata**: The `version` element tracks the topic version

```json
{
  "resourceType": "SubscriptionTopic",
  "id": "medication-order-v2",
  "url": "http://example.org/fhir/SubscriptionTopic/medication-order-v2",
  "version": "2.0",
  "status": "active",
  "title": "Medication Order (v2)",
  "description": "Enhanced notification when a medication is ordered",
  "derivedFrom": [
    "http://example.org/fhir/SubscriptionTopic/medication-order"
  ],
  "resourceTrigger": [ ... ]
}
```

## Using Topics in Subscriptions

Subscription Topics are referenced in Subscription resources:

```json
{
  "resourceType": "Subscription",
  "id": "pharmacy-med-orders",
  "status": "active",
  "reason": "Notify pharmacy of new medication orders",
  "topic": "http://example.org/fhir/SubscriptionTopic/medication-order",
  "filterBy": [
    {
      "filterParameter": "patient",
      "value": "Patient/123"
    }
  ],
  "channel": {
    "type": "rest-hook",
    "endpoint": "https://pharmacy.example.org/fhir/medication-hooks",
    "payload": "application/fhir+json"
  }
}
```

## Best Practices

### Topic Design

1. **Granularity**: Create topics with appropriate granularity—too broad and subscribers receive unwanted notifications; too narrow and they need many subscriptions
2. **Filtering Options**: Include common filtering parameters that subscribers might need
3. **Clear Descriptions**: Provide clear descriptions of what events the topic covers
4. **Consistent Naming**: Use consistent naming conventions across topics

### Healthcare-Specific Considerations

1. **PHI Protection**: Consider what PHI is included in notifications and ensure appropriate security
2. **Clinical Workflow Alignment**: Design topics that align with clinical workflows
3. **Integration Points**: Consider how topics integrate with other systems (EHRs, pharmacy systems, etc.)
4. **Regulatory Compliance**: Ensure topics and their usage comply with relevant regulations

## Troubleshooting

### Common Issues

1. **Topic Not Triggering**: Verify the trigger criteria match the expected events
2. **Filtering Not Working**: Check that filter parameters are correctly specified
3. **Performance Issues**: Topics that are too broad can cause excessive notifications

### Diagnostic Steps

```bash
# Test if a resource would trigger a topic
curl -X POST https://fhir-platform.example.org/fhir/$subscription-test \
  -H "Content-Type: application/fhir+json" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -d '{
    "resourceType": "Parameters",
    "parameter": [
      {
        "name": "topic",
        "valueUri": "http://example.org/fhir/SubscriptionTopic/medication-order"
      },
      {
        "name": "resource",
        "resource": {
          "resourceType": "MedicationRequest",
          "status": "active",
          "intent": "order",
          "subject": { "reference": "Patient/123" }
        }
      }
    ]
  }'
```

## Related Documentation

- [FHIR Subscriptions](subscriptions.md): How to create and manage subscriptions
- [FHIR Server APIs](server-apis.md): API endpoints for managing subscription topics
- [Event Processing](../03-advanced-patterns/event-processing.md): Advanced event processing patterns
