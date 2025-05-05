# Query Optimization

## Introduction

Optimizing GraphQL queries is essential for maintaining performance in a federated architecture. This guide explains techniques for optimizing query execution across subgraphs, including batching, caching, dataloader patterns, and query planning. By implementing these optimization strategies, you can ensure your Federated Graph API remains responsive even as it scales to handle complex healthcare data queries.

### Quick Start

1. Implement DataLoader for batching and caching related queries
2. Configure appropriate caching strategies at the gateway and subgraph levels
3. Use query complexity analysis to prevent resource-intensive queries
4. Optimize resolver implementations for performance
5. Monitor query performance and identify bottlenecks

### Related Components

- [Querying the Federated Graph](../02-core-functionality/querying.md): Learn about basic query patterns
- [Gateway Configuration](../02-core-functionality/gateway-configuration.md): Configure the gateway for optimal performance
- [Performance Tuning](../05-operations/performance-tuning.md): Overall performance optimization strategies
- [Monitoring](../05-operations/monitoring.md): Monitor query performance

## Query Planning and Execution

### Overview

The Apollo Gateway automatically plans how to break up incoming queries and route sub-queries to the appropriate subgraphs. Efficient query planning is vital for minimizing round-trips, reducing latency, and optimizing overall performance in a federated architecture.

### Optimization Strategies
- **Review query plans**: Use GraphOS Explorer to visualize and analyze query plans for complex operations.
- **Reduce cross-subgraph joins**: Design schemas to minimize the number of required cross-subgraph fetches.
- **Leverage @requires and @provides**: Use federation directives to optimize data fetching and reduce unnecessary calls.
- **Monitor execution**: Use GraphOS performance analytics to identify slow query plans and optimize accordingly.

### Example: Visualizing Query Plans
GraphOS Explorer provides a graphical view of query plans, helping teams identify bottlenecks and excessive subgraph hops.

### Best Practices
- Regularly review and optimize query plans for high-traffic and complex queries.
- Collaborate across teams to align schema design with query optimization goals.
- Use GraphOS analytics to monitor the impact of schema or resolver changes on query execution.


## Batching and DataLoader Patterns

### Overview

The N+1 query problem occurs when resolvers make repeated, inefficient calls to databases or services. Batching and caching with [DataLoader](https://github.com/graphql/dataloader) solves this by grouping related requests and caching results within a single request cycle.

### Implementation
- Use DataLoader in subgraph resolvers to batch and cache database or API calls.
- Integrate DataLoader instances into the GraphQL context for per-request caching.

### Example: Using DataLoader in a Resolver
```javascript
const DataLoader = require('dataloader');

// Batch load function
async function batchGetPatients(ids) {
  return db.patients.findMany({ where: { id: { $in: ids } } });
}

// In context
const context = {
  patientLoader: new DataLoader(batchGetPatients)
};

// In resolver
const resolvers = {
  Query: {
    patients: async (_, { ids }, context) => {
      return context.patientLoader.loadMany(ids);
    }
  }
};
```

### Best Practices
- Create a new DataLoader instance per request to avoid cross-user caching.
- Batch and cache calls at the data source layer for maximum efficiency.
- Use GraphOS analytics to monitor resolver performance and detect N+1 issues.


## Caching Strategies

### Overview

Caching is critical for reducing latency and backend load in federated GraphQL. Caching can be implemented at multiple layers: gateway, subgraph, resolver, and client.

### Gateway-Level Caching
- Use Apollo Gateway’s response caching plugin or integrate with a distributed cache (e.g., Redis).
- Configure cache hints in your schema using the `@cacheControl` directive.

### Subgraph and Resolver-Level Caching
- Implement caching in data sources or resolvers for frequently accessed data.
- Use DataLoader for per-request caching of database/API calls.

### Example: Gateway Response Caching
```javascript
const responseCachePlugin = require('apollo-server-plugin-response-cache');

const server = new ApolloServer({
  gateway,
  plugins: [responseCachePlugin()],
  cacheControl: {
    defaultMaxAge: 30,
    calculateHttpHeaders: true,
  },
});
```

### Example: Resolver-Level Caching
```javascript
const resolvers = {
  Query: {
    patient: async (_, { id }, { cache, dataSources }) => {
      const cacheKey = `patient:${id}`;
      let patient = await cache.get(cacheKey);
      if (patient) return JSON.parse(patient);
      patient = await dataSources.patientAPI.getPatientById(id);
      if (patient) {
        await cache.set(cacheKey, JSON.stringify(patient), 'EX', 60);
      }
      return patient;
    }
  }
};
```

### Best Practices
- Set cache TTLs based on data volatility and business requirements.
- Use GraphOS field-level analytics to identify high-traffic fields for targeted caching.
- Regularly review cache hit/miss rates and tune configuration for optimal performance.


## Query Complexity Analysis

### Overview

Query complexity analysis helps protect your federated GraphQL API from resource exhaustion and denial-of-service attacks by analyzing and limiting the cost of incoming queries. This ensures that expensive or malicious queries do not degrade system performance.

### Rationale
- **Security**: Prevent abuse and denial-of-service by limiting query depth and cost.
- **Stability**: Ensure backend resources are not overwhelmed by complex queries.
- **Visibility**: Use analytics to monitor which queries are most expensive.

### Implementation Steps
1. Use libraries like `graphql-query-complexity` to calculate the cost of incoming queries.
2. Set maximum allowed complexity and depth thresholds at the gateway.
3. Reject or throttle queries that exceed defined limits.
4. Use Apollo GraphOS analytics to monitor query patterns and identify problematic operations.

### Example: Enforcing Query Complexity Limits
```javascript
const { ApolloServer } = require('apollo-server');
const queryComplexity = require('graphql-query-complexity').default;

const server = new ApolloServer({
  schema,
  plugins: [
    {
      requestDidStart: () => ({
        didResolveOperation({ request, document, schema }) {
          const complexity = getQueryComplexity({
            schema,
            query: document,
            variables: request.variables,
            estimators: [getComplexity({})],
          });
          if (complexity > MAX_COMPLEXITY) {
            throw new Error(`Query is too complex: ${complexity}`);
          }
        }
      })
    }
  ]
});
```

### Example: Monitoring Expensive Queries with GraphOS
- Use the GraphOS Explorer and Metrics dashboards to identify queries with high complexity or execution time.
- Set up alerts in GraphOS for queries that exceed defined cost or latency thresholds.

### Best Practices
- Set reasonable defaults for maximum query complexity and depth.
- Regularly review GraphOS analytics to tune limits and identify abuse patterns.
- Communicate complexity limits to API consumers and document best practices for efficient querying.


## Resolver Optimization Techniques

### Overview

Optimizing resolver implementations is critical for ensuring fast, efficient data fetching and minimizing backend load in federated GraphQL APIs. Poorly optimized resolvers can cause latency spikes, N+1 query problems, and strain on healthcare systems with large datasets or complex access patterns.

### Rationale
- **Performance**: Fast resolvers reduce end-to-end query latency and improve user experience.
- **Scalability**: Efficient resolvers enable your API to handle more concurrent users and complex queries.
- **Resource Management**: Minimizing unnecessary database/API calls reduces infrastructure costs and risk of overload.

### Implementation Steps
1. **Batch and Cache Data Fetches**: Use DataLoader or equivalent patterns to batch and cache requests within a query cycle.
2. **Minimize Overfetching**: Only fetch the fields and records required by the query.
3. **Avoid Blocking Operations**: Use asynchronous, non-blocking I/O for all data access.
4. **Optimize Database Queries**: Use indexed queries, pagination, and projections to speed up data retrieval.
5. **Leverage Federation Directives**: Use `@requires`, `@provides`, and `@external` to optimize cross-subgraph data fetching.
6. **Monitor Resolver Performance**: Use Apollo GraphOS field-level analytics to identify slow or high-frequency resolvers.

### Example: Efficient Resolver with DataLoader and Pagination
```javascript
const resolvers = {
  Query: {
    patients: async (_, { page, pageSize }, { dataSources, patientLoader }) => {
      // Fetch only the IDs for the requested page
      const ids = await dataSources.patientAPI.getPatientIds({ page, pageSize });
      // Use DataLoader to batch and cache patient record fetches
      return patientLoader.loadMany(ids);
    }
  }
};
```

### Example: Using GraphOS to Monitor Resolver Performance
- Use the GraphOS Explorer and Metrics dashboards to:
  - Identify slowest resolvers and most frequently accessed fields
  - Drill down into resolver timings to find bottlenecks
  - Correlate resolver performance with query patterns and user behavior

### Best Practices
- Profile and benchmark resolver performance regularly, especially for high-traffic or critical operations.
- Use DataLoader and batching for all entity fetches that may be requested in bulk.
- Avoid synchronous/blocking calls and long-running computations in resolvers.
- Document resolver logic and optimization strategies for maintainability and onboarding.
- Collaborate with database and backend teams to ensure efficient data access patterns.
- Continuously monitor resolver performance using GraphOS and tune as needed.


## Conclusion

Optimizing queries is essential for delivering a responsive, scalable, and secure federated GraphQL API—especially in complex, high-stakes domains like healthcare. By leveraging batching, caching, query planning, and complexity analysis, you can ensure your API meets demanding performance and compliance requirements.

**Key takeaways:**
- Use Apollo GraphOS to continuously monitor query performance, identify bottlenecks, and guide optimization efforts.
- Implement DataLoader and batching patterns to eliminate N+1 query issues and reduce backend load.
- Apply caching strategies at the gateway, subgraph, and resolver levels, tuning TTLs and cache hints based on real-world usage.
- Enforce query complexity and depth limits to protect against abuse and resource exhaustion.
- Regularly review query plans and collaborate across teams to optimize schema design and resolver logic.

**Next steps:**
- Integrate query analytics and alerting into your operational workflows using GraphOS.
- Document and communicate query optimization best practices to all API consumers and contributors.
- Continuously revisit and refine optimization strategies as your federated graph grows and your healthcare requirements evolve.

By making query optimization an ongoing, collaborative process, you will deliver a federated GraphQL API that is robust, efficient, and ready to support the next generation of healthcare applications.
