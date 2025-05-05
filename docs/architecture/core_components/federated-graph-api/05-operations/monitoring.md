# Monitoring and Alerting

## Introduction

Effective monitoring is essential for maintaining a reliable Federated Graph API. This guide explains how to implement comprehensive monitoring and alerting for your GraphQL infrastructure, covering gateway health metrics, subgraph health metrics, query performance monitoring, alerting strategies, and operational dashboards. By implementing these monitoring practices, you can ensure high availability, quickly identify performance bottlenecks, and proactively address issues before they impact users.

## Monitoring and Analytics with Apollo GraphOS

Apollo GraphOS provides robust monitoring, analytics, and alerting for federated GraphQL APIs. By integrating your gateway and subgraphs with GraphOS, you can:
- Visualize real-time and historical query performance, error rates, and usage patterns
- Monitor subgraph and gateway health, including schema composition and service status
- Set up alerts for error spikes, degraded performance, or unusual usage
- Analyze field-level usage to optimize schema and access control
- Audit API activity for compliance and security

### Example: Enabling Monitoring with Apollo GraphOS
- Configure your Apollo Gateway and subgraphs with the GraphOS API key:

```yaml
# .env or deployment config
APOLLO_KEY=service:your-graph@current:YOUR_GRAPHOS_API_KEY
APOLLO_GRAPH_REF=your-graph@current
```

- In your Apollo Server setup:

```javascript
const { ApolloServer } = require('apollo-server');
const { ApolloGateway } = require('@apollo/gateway');

const gateway = new ApolloGateway({ /* ... */ });

const server = new ApolloServer({
  gateway,
  // ...other options,
  apollo: {
    key: process.env.APOLLO_KEY,
    graphRef: process.env.APOLLO_GRAPH_REF,
  }
});
```

- Use the GraphOS UI to monitor query performance, set up alerts, and review field-level analytics.

### Best Practices
- Enable GraphOS monitoring in all environments (at least staging and production).
- Set up alerts for high error rates, slow queries, or schema composition failures.
- Use field-level analytics to identify unused or high-risk fields and optimize the schema.
- Regularly review monitoring dashboards and logs for operational insights.

Reference: [Apollo GraphOS Monitoring and Analytics](https://www.apollographql.com/docs/graphos/metrics/)

---

### Quick Start

1. Set up gateway health monitoring
2. Configure subgraph health checks
3. Implement query performance tracking
4. Create alerting rules for critical metrics
5. Build operational dashboards for visibility

### Related Components

- [Gateway Configuration](../02-core-functionality/gateway-configuration.md): Configure the gateway for monitoring
- [Performance Tuning](performance-tuning.md): Use monitoring data to optimize performance
- [Scaling](scaling.md): Monitor resource usage to inform scaling decisions
- [Deployment](deployment.md): Integrate monitoring into your deployment pipeline

## Gateway Health Metrics

*This section will cover key metrics to monitor at the gateway level, including request rates, error rates, and response times.*

```javascript
// Example: Setting up basic monitoring middleware for Apollo Server
const { ApolloServer } = require('apollo-server');
const { ApolloGateway } = require('@apollo/gateway');
const prometheus = require('prom-client');

// Create metrics
const httpRequestDurationMicroseconds = new prometheus.Histogram({
  name: 'http_request_duration_ms',
  help: 'Duration of HTTP requests in ms',
  labelNames: ['route', 'operation', 'status'],
  buckets: [0.1, 5, 15, 50, 100, 200, 300, 400, 500, 1000, 2000, 5000, 10000]
});

const resolverDurationMicroseconds = new prometheus.Histogram({
  name: 'resolver_duration_ms',
  help: 'Duration of resolver execution in ms',
  labelNames: ['path', 'parentType', 'returnType'],
  buckets: [0.1, 1, 5, 15, 50, 100, 200, 500, 1000, 2000, 5000]
});

// Initialize the gateway
const gateway = new ApolloGateway({
  serviceList: [
    // Your services here
  ],
});

// Initialize the Apollo Server with monitoring
const server = new ApolloServer({
  gateway,
  subscriptions: false,
  plugins: [{
    requestDidStart(requestContext) {
      const startTime = Date.now();
      let operationName = requestContext.request.operationName || 'unknown';
      
      return {
        didEncounterErrors({ errors }) {
          // Record errors
          errors.forEach(error => {
            console.error(`GraphQL Error: ${error.message}`);
          });
        },
        
        willSendResponse({ response }) {
          // Record request duration
          const duration = Date.now() - startTime;
          const status = response.errors ? 'error' : 'success';
          
          httpRequestDurationMicroseconds
            .labels(requestContext.request.query || 'unknown', operationName, status)
            .observe(duration);
        },
        
        executionDidStart() {
          return {
            willResolveField({ info, context }) {
              const startTime = Date.now();
              
              return () => {
                const duration = Date.now() - startTime;
                const fieldPath = `${info.parentType.name}.${info.fieldName}`;
                
                resolverDurationMicroseconds
                  .labels(fieldPath, info.parentType.name, info.returnType.toString())
                  .observe(duration);
              };
            }
          };
        }
      };
    }
  }]
});

// Expose metrics endpoint
server.express.get('/metrics', (req, res) => {
  res.set('Content-Type', prometheus.register.contentType);
  res.end(prometheus.register.metrics());
});

server.listen().then(({ url }) => {
  console.log(`🚀 Gateway ready at ${url}`);
  console.log(`📊 Metrics available at ${url}metrics`);
});
```

## Subgraph Health Metrics

*This section will explain how to monitor the health of individual subgraphs, including availability, error rates, and response times.*

## Query Performance Monitoring

*This section will cover techniques for monitoring query performance, including tracking slow queries, identifying expensive operations, and measuring resolver execution times.*

## Alerting Strategies

*This section will explain how to set up effective alerting based on monitoring data, including threshold-based alerts, anomaly detection, and escalation policies.*

## Operational Dashboards

*This section will cover how to build comprehensive operational dashboards that provide visibility into the health and performance of your Federated Graph API.*

## Conclusion

*This document will be completed in a future update with comprehensive guidance on monitoring and alerting for a federated GraphQL architecture.*
