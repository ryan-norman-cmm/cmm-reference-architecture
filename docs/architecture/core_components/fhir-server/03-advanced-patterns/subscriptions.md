# FHIR Subscription Implementation

## Introduction

FHIR Subscriptions provide a standardized mechanism for clients to receive notifications when resources are created or modified on a FHIR server. This enables real-time updates and event-driven architectures in healthcare applications. This guide explains how to implement and manage FHIR subscriptions, including topic management, notification delivery, and scaling considerations.

### Quick Start

1. Create a Subscription resource specifying criteria, channel type, and endpoint
2. Configure your server to handle subscription notifications
3. Implement appropriate security for subscription endpoints
4. Set up monitoring for subscription status and delivery
5. Consider scaling strategies for high-volume subscriptions

### Related Components

- [Event Processing with FHIR](event-processing-with-fhir.md): Learn about event-driven architecture with FHIR
- [FHIR Server Setup Guide](fhir-server-setup-guide.md): Configure your Aidbox FHIR server
- [Accessing FHIR Resources](accessing-fhir-resources.md): Understand resource retrieval patterns
- [Subscription Architecture Decisions](fhir-subscription-decisions.md) (Coming Soon): Understand subscription design choices

## FHIR Subscription Resources

The Subscription resource in FHIR defines what events to subscribe to and how notifications should be delivered. It consists of several key components:

| Component | Description | Purpose |
|-----------|-------------|----------|
| Criteria | FHIR search query | Defines which resources trigger notifications |
| Channel | Notification delivery method | Specifies how notifications are delivered (REST, WebSocket, etc.) |
| Endpoint | Destination for notifications | URL or other identifier where notifications are sent |
| Status | Current state of subscription | Tracks whether subscription is active, error, etc. |
| Reason | Purpose of subscription | Documents why the subscription exists |
| Error | Error information | Contains details if subscription encounters problems |

### Creating a Subscription Resource

```typescript
import { AidboxClient } from '@aidbox/sdk-r4';
import { Subscription } from '@aidbox/sdk-r4/types';

const client = new AidboxClient({
  baseUrl: 'http://localhost:8888',
  auth: {
    type: 'basic',
    username: 'root',
    password: 'secret'
  }
});

/**
 * Creates a subscription for new or updated Patient resources
 * @param endpoint The URL where notifications should be sent
 * @returns The created Subscription resource
 */
async function createPatientSubscription(endpoint: string): Promise<Subscription> {
  try {
    const subscription: Partial<Subscription> = {
      resourceType: 'Subscription',
      status: 'requested',
      reason: 'Monitor patient demographics updates',
      criteria: 'Patient?_lastUpdated=gt${now}',
      channel: {
        type: 'rest-hook',
        endpoint: endpoint,
        payload: 'application/fhir+json',
        header: ['Authorization: Bearer secret-token-abc']
      }
    };
    
    const result = await client.create<Subscription>(subscription);
    console.log(`Subscription created with ID: ${result.id}`);
    return result;
  } catch (error) {
    console.error('Error creating subscription:', error);
    throw error;
  }
}

/**
 * Updates an existing subscription's status
 * @param id The ID of the subscription to update
 * @param status The new status ('active', 'error', 'off', etc.)
 * @returns The updated Subscription resource
 */
async function updateSubscriptionStatus(id: string, status: 'active' | 'error' | 'off'): Promise<Subscription> {
  try {
    // First, retrieve the current subscription
    const subscription = await client.read<Subscription>({
      resourceType: 'Subscription',
      id
    });
    
    // Update the status
    subscription.status = status;
    
    // Save the updated subscription
    const result = await client.update<Subscription>(subscription);
    console.log(`Subscription ${id} status updated to ${status}`);
    return result;
  } catch (error) {
    console.error(`Error updating subscription ${id}:`, error);
    throw error;
  }
}
```

### Managing Subscription Lifecycle

Subscriptions go through several states during their lifecycle:

1. **Requested**: Initial state when a subscription is created
2. **Active**: The server has activated the subscription and will send notifications
3. **Error**: The subscription encountered an error (e.g., endpoint unreachable)
4. **Off**: The subscription is temporarily disabled
5. **Entered-in-error**: The subscription was created by mistake

```typescript
/**
 * Manages the complete lifecycle of a subscription
 */
class SubscriptionManager {
  private client: AidboxClient;
  
  constructor(baseUrl: string, auth: any) {
    this.client = new AidboxClient({
      baseUrl,
      auth
    });
  }
  
  /**
   * Creates a new subscription
   */
  async createSubscription(criteria: string, endpoint: string, reason: string): Promise<Subscription> {
    const subscription: Partial<Subscription> = {
      resourceType: 'Subscription',
      status: 'requested',
      reason,
      criteria,
      channel: {
        type: 'rest-hook',
        endpoint,
        payload: 'application/fhir+json'
      }
    };
    
    return await this.client.create<Subscription>(subscription);
  }
  
  /**
   * Activates a subscription
   */
  async activateSubscription(id: string): Promise<Subscription> {
    return await this.updateStatus(id, 'active');
  }
  
  /**
   * Pauses a subscription
   */
  async pauseSubscription(id: string): Promise<Subscription> {
    return await this.updateStatus(id, 'off');
  }
  
  /**
   * Deletes a subscription
   */
  async deleteSubscription(id: string): Promise<void> {
    await this.client.delete({
      resourceType: 'Subscription',
      id
    });
    console.log(`Subscription ${id} deleted`);
  }
  
  /**
   * Updates subscription status
   */
  private async updateStatus(id: string, status: 'active' | 'error' | 'off'): Promise<Subscription> {
    const subscription = await this.client.read<Subscription>({
      resourceType: 'Subscription',
      id
    });
    
    subscription.status = status;
    return await this.client.update<Subscription>(subscription);
  }
  
  /**
   * Lists all subscriptions with a given status
   */
  async listSubscriptionsByStatus(status?: 'active' | 'error' | 'off' | 'requested'): Promise<Subscription[]> {
    const params: any = {};
    if (status) {
      params.status = status;
    }
    
    const bundle = await this.client.search<Subscription>({
      resourceType: 'Subscription',
      params
    });
    
    return bundle.entry?.map(entry => entry.resource as Subscription) || [];
  }
}
```

## Topic Management

Effective topic management is crucial for organizing subscriptions in a scalable way. Topics represent logical groupings of subscription criteria.

### Defining Subscription Topics

In Aidbox, you can define subscription topics in your configuration:

```clojure
;; In your Aidbox project.edn file
{:zen/tags #{aidbox/system}
 :subscription-topics
 {:zen/tags #{aidbox/subscription-topics}
  :topics
  {:patient-demographics
   {:description "Patient demographics changes"
    :resource-type "Patient"
    :criteria "Patient?_lastUpdated=gt${now}"}
   
   :medication-requests
   {:description "New medication requests"
    :resource-type "MedicationRequest"
    :criteria "MedicationRequest?status=active&_lastUpdated=gt${now}"}
   
   :observation-vitals
   {:description "New vital signs observations"
    :resource-type "Observation"
    :criteria "Observation?code=http://loinc.org|8867-4,http://loinc.org|8480-6&_lastUpdated=gt${now}"}}}}
```

### Topic-Based Subscription Management

```typescript
/**
 * Creates a subscription based on a predefined topic
 * @param topicId The ID of the topic to subscribe to
 * @param endpoint The URL where notifications should be sent
 * @returns The created Subscription resource
 */
async function subscribeToTopic(topicId: string, endpoint: string): Promise<Subscription> {
  try {
    // First, get the topic definition to include in the subscription
    const topicResponse = await client.request({
      method: 'GET',
      url: `/Subscription/topic/${topicId}`
    });
    
    const topic = topicResponse.data;
    
    const subscription: Partial<Subscription> = {
      resourceType: 'Subscription',
      status: 'requested',
      reason: `Subscription to ${topic.description}`,
      criteria: topic.criteria,
      channel: {
        type: 'rest-hook',
        endpoint: endpoint,
        payload: 'application/fhir+json'
      },
      // Store the topic ID for reference
      extension: [
        {
          url: 'http://example.org/fhir/StructureDefinition/subscription-topic',
          valueString: topicId
        }
      ]
    };
    
    return await client.create<Subscription>(subscription);
  } catch (error) {
    console.error(`Error subscribing to topic ${topicId}:`, error);
    throw error;
  }
}
```

## Notification Delivery

FHIR supports multiple notification delivery mechanisms through different channel types.

### REST Hook Channel

REST hooks deliver notifications via HTTP POST requests to a specified endpoint:

```typescript
import express from 'express';
import bodyParser from 'body-parser';

const app = express();
app.use(bodyParser.json({ type: 'application/fhir+json' }));

// Endpoint to receive subscription notifications
app.post('/fhir/subscription/callback', (req, res) => {
  try {
    const notification = req.body;
    console.log('Received FHIR notification:', JSON.stringify(notification, null, 2));
    
    // Verify the notification is legitimate
    const authHeader = req.headers.authorization;
    if (!authHeader || authHeader !== 'Bearer secret-token-abc') {
      console.error('Unauthorized notification attempt');
      return res.status(401).send('Unauthorized');
    }
    
    // Process the notification based on resource type
    const resourceType = notification.resourceType;
    switch (resourceType) {
      case 'Patient':
        processPatientUpdate(notification);
        break;
      case 'Observation':
        processObservationUpdate(notification);
        break;
      default:
        console.log(`Unhandled resource type: ${resourceType}`);
    }
    
    // Acknowledge receipt of the notification
    res.status(200).send('Notification received');
  } catch (error) {
    console.error('Error processing notification:', error);
    res.status(500).send('Error processing notification');
  }
});

function processPatientUpdate(patient: any): void {
  // Implement patient update processing logic
  console.log(`Processing update for patient ${patient.id}`);
}

function processObservationUpdate(observation: any): void {
  // Implement observation update processing logic
  console.log(`Processing update for observation ${observation.id}`);
}

app.listen(3000, () => {
  console.log('Subscription callback server listening on port 3000');
});
```

### WebSocket Channel

WebSockets provide real-time, bidirectional communication for notifications:

```typescript
import WebSocket from 'ws';

/**
 * Creates a WebSocket-based subscription
 * @param criteria The search criteria for the subscription
 * @returns The created Subscription resource
 */
async function createWebSocketSubscription(criteria: string): Promise<Subscription> {
  try {
    const subscription: Partial<Subscription> = {
      resourceType: 'Subscription',
      status: 'requested',
      reason: 'Real-time updates via WebSocket',
      criteria,
      channel: {
        type: 'websocket',
        payload: 'application/fhir+json'
      }
    };
    
    return await client.create<Subscription>(subscription);
  } catch (error) {
    console.error('Error creating WebSocket subscription:', error);
    throw error;
  }
}

/**
 * Sets up a WebSocket client to receive notifications
 * @param subscriptionId The ID of the subscription to connect to
 */
function setupWebSocketClient(subscriptionId: string): WebSocket {
  // Connect to the WebSocket endpoint
  const ws = new WebSocket(`ws://localhost:8888/fhir/subscription/${subscriptionId}`);
  
  ws.on('open', () => {
    console.log(`WebSocket connection established for subscription ${subscriptionId}`);
  });
  
  ws.on('message', (data) => {
    try {
      const notification = JSON.parse(data.toString());
      console.log('Received WebSocket notification:', notification);
      
      // Process the notification
      const resourceType = notification.resourceType;
      switch (resourceType) {
        case 'Patient':
          processPatientUpdate(notification);
          break;
        case 'Observation':
          processObservationUpdate(notification);
          break;
        default:
          console.log(`Unhandled resource type: ${resourceType}`);
      }
    } catch (error) {
      console.error('Error processing WebSocket notification:', error);
    }
  });
  
  ws.on('error', (error) => {
    console.error('WebSocket error:', error);
  });
  
  ws.on('close', (code, reason) => {
    console.log(`WebSocket connection closed: ${code} - ${reason}`);
  });
  
  return ws;
}
```

### Email Channel

Email notifications can be useful for certain types of alerts:

```typescript
/**
 * Creates an email-based subscription
 * @param criteria The search criteria for the subscription
 * @param email The email address to send notifications to
 * @returns The created Subscription resource
 */
async function createEmailSubscription(criteria: string, email: string): Promise<Subscription> {
  try {
    const subscription: Partial<Subscription> = {
      resourceType: 'Subscription',
      status: 'requested',
      reason: 'Email alerts for critical updates',
      criteria,
      channel: {
        type: 'email',
        endpoint: email,
        payload: 'application/fhir+json'
      }
    };
    
    return await client.create<Subscription>(subscription);
  } catch (error) {
    console.error('Error creating email subscription:', error);
    throw error;
  }
}
```

## Scaling Considerations

As your system grows, managing subscriptions at scale becomes important.

### Performance Optimization

1. **Limit Subscription Criteria**: Use specific criteria to reduce the number of notifications
2. **Batch Notifications**: Group multiple events into a single notification when possible
3. **Rate Limiting**: Implement rate limiting to prevent overwhelming subscribers

```typescript
/**
 * Creates a subscription with rate limiting
 * @param criteria The search criteria for the subscription
 * @param endpoint The URL where notifications should be sent
 * @param maxUpdatesPerMinute Maximum number of notifications per minute
 * @returns The created Subscription resource
 */
async function createRateLimitedSubscription(
  criteria: string,
  endpoint: string,
  maxUpdatesPerMinute: number
): Promise<Subscription> {
  try {
    const subscription: Partial<Subscription> = {
      resourceType: 'Subscription',
      status: 'requested',
      reason: 'Rate-limited subscription',
      criteria,
      channel: {
        type: 'rest-hook',
        endpoint,
        payload: 'application/fhir+json'
      },
      // Add rate limiting extension
      extension: [
        {
          url: 'http://example.org/fhir/StructureDefinition/rate-limit',
          valueInteger: maxUpdatesPerMinute
        }
      ]
    };
    
    return await client.create<Subscription>(subscription);
  } catch (error) {
    console.error('Error creating rate-limited subscription:', error);
    throw error;
  }
}
```

### High Availability

Ensure your subscription handling system is resilient:

1. **Redundant Endpoints**: Provide multiple endpoints for critical subscriptions
2. **Retry Mechanisms**: Implement exponential backoff for failed deliveries
3. **Circuit Breakers**: Temporarily disable problematic subscriptions

```typescript
/**
 * Implements a circuit breaker for subscription endpoints
 */
class SubscriptionCircuitBreaker {
  private failureThreshold: number;
  private resetTimeout: number;
  private failureCounts: Map<string, number> = new Map();
  private breakerStatus: Map<string, 'closed' | 'open'> = new Map();
  private resetTimers: Map<string, NodeJS.Timeout> = new Map();
  
  constructor(failureThreshold: number = 5, resetTimeoutMs: number = 60000) {
    this.failureThreshold = failureThreshold;
    this.resetTimeout = resetTimeoutMs;
  }
  
  /**
   * Records a failed delivery attempt
   * @param endpoint The endpoint that failed
   * @returns Whether the circuit breaker is now open
   */
  recordFailure(endpoint: string): boolean {
    // If breaker is already open, no need to record
    if (this.breakerStatus.get(endpoint) === 'open') {
      return true;
    }
    
    const currentCount = this.failureCounts.get(endpoint) || 0;
    const newCount = currentCount + 1;
    this.failureCounts.set(endpoint, newCount);
    
    if (newCount >= this.failureThreshold) {
      this.openBreaker(endpoint);
      return true;
    }
    
    return false;
  }
  
  /**
   * Records a successful delivery
   * @param endpoint The endpoint that succeeded
   */
  recordSuccess(endpoint: string): void {
    this.failureCounts.set(endpoint, 0);
    if (this.breakerStatus.get(endpoint) === 'open') {
      this.closeBreaker(endpoint);
    }
  }
  
  /**
   * Checks if an endpoint's circuit breaker is open
   * @param endpoint The endpoint to check
   * @returns Whether the circuit breaker is open
   */
  isOpen(endpoint: string): boolean {
    return this.breakerStatus.get(endpoint) === 'open';
  }
  
  /**
   * Opens the circuit breaker for an endpoint
   * @param endpoint The endpoint to open the breaker for
   */
  private openBreaker(endpoint: string): void {
    console.log(`Circuit breaker opened for endpoint: ${endpoint}`);
    this.breakerStatus.set(endpoint, 'open');
    
    // Clear any existing timer
    const existingTimer = this.resetTimers.get(endpoint);
    if (existingTimer) {
      clearTimeout(existingTimer);
    }
    
    // Set timer to reset the breaker
    const timer = setTimeout(() => {
      console.log(`Circuit breaker reset timeout reached for endpoint: ${endpoint}`);
      this.closeBreaker(endpoint);
    }, this.resetTimeout);
    
    this.resetTimers.set(endpoint, timer);
  }
  
  /**
   * Closes the circuit breaker for an endpoint
   * @param endpoint The endpoint to close the breaker for
   */
  private closeBreaker(endpoint: string): void {
    console.log(`Circuit breaker closed for endpoint: ${endpoint}`);
    this.breakerStatus.set(endpoint, 'closed');
    this.failureCounts.set(endpoint, 0);
    
    // Clear the reset timer
    const existingTimer = this.resetTimers.get(endpoint);
    if (existingTimer) {
      clearTimeout(existingTimer);
      this.resetTimers.delete(endpoint);
    }
  }
}
```

### Load Balancing

Distribute subscription processing across multiple servers:

1. **Sharding**: Distribute subscriptions across multiple servers based on criteria
2. **Worker Pools**: Use worker processes to handle notification delivery
3. **Queue-Based Processing**: Use message queues for asynchronous processing

```typescript
import { Worker, isMainThread, parentPort, workerData } from 'worker_threads';

/**
 * Main thread code to distribute notifications to worker threads
 */
if (isMainThread) {
  const workerPool: Worker[] = [];
  const poolSize = 4; // Number of worker threads
  
  // Create worker pool
  for (let i = 0; i < poolSize; i++) {
    const worker = new Worker(__filename, {
      workerData: { workerId: i }
    });
    
    worker.on('message', (message) => {
      console.log(`Worker ${i} processed notification:`, message);
    });
    
    worker.on('error', (error) => {
      console.error(`Worker ${i} error:`, error);
    });
    
    workerPool.push(worker);
  }
  
  /**
   * Distributes a notification to a worker thread
   * @param notification The notification to process
   */
  function distributeNotification(notification: any): void {
    // Simple round-robin distribution based on resource ID
    const resourceId = notification.id || 'unknown';
    const workerIndex = Math.abs(hashString(resourceId) % poolSize);
    workerPool[workerIndex].postMessage(notification);
  }
  
  /**
   * Simple string hash function
   * @param str The string to hash
   * @returns A numeric hash value
   */
  function hashString(str: string): number {
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
      const char = str.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash; // Convert to 32bit integer
    }
    return hash;
  }
  
  // Example: Process incoming notifications
  app.post('/fhir/subscription/callback', (req, res) => {
    const notification = req.body;
    distributeNotification(notification);
    res.status(200).send('Notification received');
  });
}
/**
 * Worker thread code to process notifications
 */
else {
  const { workerId } = workerData;
  
  // Listen for notifications from the main thread
  parentPort?.on('message', (notification) => {
    try {
      console.log(`Worker ${workerId} processing notification for ${notification.resourceType}/${notification.id}`);
      
      // Process the notification based on resource type
      const resourceType = notification.resourceType;
      switch (resourceType) {
        case 'Patient':
          processPatientUpdate(notification);
          break;
        case 'Observation':
          processObservationUpdate(notification);
          break;
        default:
          console.log(`Unhandled resource type: ${resourceType}`);
      }
      
      // Send result back to main thread
      parentPort?.postMessage({
        status: 'success',
        resourceId: notification.id,
        resourceType: notification.resourceType
      });
    } catch (error) {
      console.error(`Worker ${workerId} error processing notification:`, error);
      parentPort?.postMessage({
        status: 'error',
        error: error.message,
        resourceId: notification.id,
        resourceType: notification.resourceType
      });
    }
  });
  
  function processPatientUpdate(patient: any): void {
    // Implement patient update processing logic
    console.log(`Worker ${workerId} processing update for patient ${patient.id}`);
  }
  
  function processObservationUpdate(observation: any): void {
    // Implement observation update processing logic
    console.log(`Worker ${workerId} processing update for observation ${observation.id}`);
  }
}
```

## Monitoring Subscription Health

Implement monitoring to ensure your subscriptions are working correctly:

```typescript
/**
 * Monitors subscription health
 */
class SubscriptionMonitor {
  private client: AidboxClient;
  private checkInterval: NodeJS.Timeout | null = null;
  
  constructor(baseUrl: string, auth: any) {
    this.client = new AidboxClient({
      baseUrl,
      auth
    });
  }
  
  /**
   * Starts periodic subscription health checks
   * @param intervalMs The interval between checks in milliseconds
   */
  startMonitoring(intervalMs: number = 300000): void {
    this.checkInterval = setInterval(() => this.checkSubscriptionHealth(), intervalMs);
    console.log(`Subscription monitoring started with ${intervalMs}ms interval`);
  }
  
  /**
   * Stops subscription health checks
   */
  stopMonitoring(): void {
    if (this.checkInterval) {
      clearInterval(this.checkInterval);
      this.checkInterval = null;
      console.log('Subscription monitoring stopped');
    }
  }
  
  /**
   * Checks the health of all subscriptions
   */
  async checkSubscriptionHealth(): Promise<void> {
    try {
      console.log('Checking subscription health...');
      
      // Get all subscriptions
      const bundle = await this.client.search<Subscription>({
        resourceType: 'Subscription'
      });
      
      const subscriptions = bundle.entry?.map(entry => entry.resource as Subscription) || [];
      console.log(`Found ${subscriptions.length} subscriptions`);
      
      // Check each subscription
      for (const subscription of subscriptions) {
        await this.checkSingleSubscription(subscription);
      }
    } catch (error) {
      console.error('Error checking subscription health:', error);
    }
  }
  
  /**
   * Checks the health of a single subscription
   * @param subscription The subscription to check
   */
  private async checkSingleSubscription(subscription: Subscription): Promise<void> {
    const id = subscription.id;
    const status = subscription.status;
    const channel = subscription.channel;
    
    console.log(`Checking subscription ${id} with status ${status}`);
    
    // Check for error status
    if (status === 'error') {
      console.error(`Subscription ${id} is in error state:`, subscription.error);
      // Attempt to fix or notify administrators
    }
    
    // For REST hook subscriptions, check if endpoint is reachable
    if (channel.type === 'rest-hook' && channel.endpoint) {
      try {
        // Perform a lightweight ping to the endpoint
        const response = await fetch(channel.endpoint, {
          method: 'HEAD',
          headers: {
            'User-Agent': 'FHIR-Subscription-Monitor'
          }
        });
        
        if (response.ok) {
          console.log(`Endpoint ${channel.endpoint} is reachable`);
        } else {
          console.error(`Endpoint ${channel.endpoint} returned status ${response.status}`);
          // Consider updating subscription status to error
        }
      } catch (error) {
        console.error(`Error checking endpoint ${channel.endpoint}:`, error);
        // Consider updating subscription status to error
      }
    }
  }
}
```

## Conclusion

FHIR Subscriptions provide a standardized way to implement event-driven architectures in healthcare applications. By following the patterns described in this guide, you can create robust, scalable subscription systems that deliver real-time updates to interested clients.

Key takeaways:

1. Use the Subscription resource to define what events to subscribe to and how notifications should be delivered
2. Implement appropriate topic management for organizing subscriptions
3. Choose the right notification channel type for your use case
4. Consider scaling strategies for high-volume subscription systems
5. Implement monitoring to ensure subscription health

By implementing FHIR Subscriptions effectively, you can build responsive healthcare applications that react to changes in real-time, improving user experience and enabling more efficient workflows.
