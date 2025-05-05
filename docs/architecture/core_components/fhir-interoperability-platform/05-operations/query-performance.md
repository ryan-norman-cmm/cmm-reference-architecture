# FHIR Query Performance Optimization

## Introduction

Query performance is a critical aspect of FHIR server implementations that directly impacts user experience and system scalability. This guide explains strategies for optimizing FHIR query performance, covering search parameter optimization, efficient include patterns, pagination strategies, and handling complex queries. By implementing these optimizations, you can significantly improve the response times and throughput of your FHIR server.

### Quick Start

1. Optimize search parameter usage in FHIR queries
2. Implement efficient include and revinclude patterns
3. Use appropriate pagination strategies for large result sets
4. Optimize complex queries with composite parameters and chained searches
5. Implement server-side query optimization techniques

### Related Components

- [FHIR Database Optimization](fhir-database-optimization.md): Optimize database performance
- [FHIR Server Monitoring](fhir-server-monitoring.md): Monitor server performance
- [FHIR Caching Strategies](fhir-caching-strategies.md) (Coming Soon): Implement caching for performance
- [FHIR Server Configuration](fhir-server-configuration.md) (Coming Soon): Configure server for optimal performance

## Optimizing Search Parameters

Efficient use of search parameters is essential for good query performance.

### Search Parameter Selection

Choose the most selective search parameters to minimize the result set size.

| Search Approach | Performance Impact | Example |
|-----------------|-------------------|----------|
| Using unique identifiers | Excellent - direct lookup | `Patient?identifier=http://hospital.example.org|123456` |
| Using highly selective parameters | Very good - small result set | `Patient?family=Smith&given=John&birthdate=1970-01-01` |
| Using moderately selective parameters | Good - moderate result set | `Patient?family=Smith&gender=male` |
| Using non-selective parameters | Poor - large result set | `Patient?gender=male` |
| Using no parameters | Very poor - full resource scan | `Patient` |

### Implementing Efficient Search Parameter Usage

```typescript
import { AidboxClient } from '@aidbox/sdk-r4';
import { Bundle, Patient } from '@aidbox/sdk-r4/types';

const client = new AidboxClient({
  baseUrl: 'http://localhost:8888',
  auth: {
    type: 'basic',
    username: 'root',
    password: 'secret'
  }
});

/**
 * Demonstrates efficient search parameter usage
 */
async function demonstrateEfficientSearches(): Promise<void> {
  try {
    // Most efficient: Search by unique identifier
    console.time('Search by identifier');
    const identifierSearch = await client.search<Patient>({
      resourceType: 'Patient',
      params: {
        'identifier': 'http://hospital.example.org|123456'
      }
    });
    console.timeEnd('Search by identifier');
    console.log(`Found ${identifierSearch.entry?.length || 0} patients by identifier`);
    
    // Very efficient: Search by multiple selective parameters
    console.time('Search by multiple selective parameters');
    const selectiveSearch = await client.search<Patient>({
      resourceType: 'Patient',
      params: {
        'family': 'Smith',
        'given': 'John',
        'birthdate': '1970-01-01'
      }
    });
    console.timeEnd('Search by multiple selective parameters');
    console.log(`Found ${selectiveSearch.entry?.length || 0} patients by selective parameters`);
    
    // Less efficient: Search by less selective parameters
    console.time('Search by less selective parameters');
    const lessSelectiveSearch = await client.search<Patient>({
      resourceType: 'Patient',
      params: {
        'family': 'Smith',
        'gender': 'male'
      }
    });
    console.timeEnd('Search by less selective parameters');
    console.log(`Found ${lessSelectiveSearch.entry?.length || 0} patients by less selective parameters`);
    
    // Inefficient: Search by non-selective parameter
    console.time('Search by non-selective parameter');
    const nonSelectiveSearch = await client.search<Patient>({
      resourceType: 'Patient',
      params: {
        'gender': 'male'
      }
    });
    console.timeEnd('Search by non-selective parameter');
    console.log(`Found ${nonSelectiveSearch.entry?.length || 0} patients by non-selective parameter`);
  } catch (error) {
    console.error('Error demonstrating efficient searches:', error);
  }
}
```

### Search Parameter Modifiers

Use appropriate modifiers to make searches more efficient.

| Modifier | Purpose | Performance Impact | Example |
|----------|---------|-------------------|----------|
| `:exact` | Exact string match | Improves performance for text searches | `Patient?name:exact=John` |
| `:contains` | Substring match | Can be slow, use carefully | `Patient?name:contains=oh` |
| `:missing` | Check if parameter exists | Can be efficient with proper indexing | `Patient?telecom:missing=true` |
| `:not` | Negation | Often less efficient than positive searches | `Patient?gender:not=male` |
| `:above`, `:below` | Hierarchy navigation | Depends on terminology service efficiency | `Condition?code:below=http://snomed.info/sct|73211009` |

## Efficient Include and Revinclude Patterns

Optimize the use of `_include` and `_revinclude` to retrieve related resources efficiently.

### Optimizing Include Patterns

```typescript
/**
 * Demonstrates efficient include patterns
 */
async function demonstrateEfficientIncludes(): Promise<void> {
  try {
    // Efficient: Include only necessary references
    console.time('Specific include');
    const specificInclude = await client.search<Bundle>({
      resourceType: 'MedicationRequest',
      params: {
        'patient': 'Patient/example',
        '_include': 'MedicationRequest:medication'
      }
    });
    console.timeEnd('Specific include');
    console.log(`Retrieved ${specificInclude.entry?.length || 0} resources with specific include`);
    
    // Less efficient: Include multiple references
    console.time('Multiple includes');
    const multipleIncludes = await client.search<Bundle>({
      resourceType: 'MedicationRequest',
      params: {
        'patient': 'Patient/example',
        '_include': ['MedicationRequest:medication', 'MedicationRequest:requester', 'MedicationRequest:encounter']
      }
    });
    console.timeEnd('Multiple includes');
    console.log(`Retrieved ${multipleIncludes.entry?.length || 0} resources with multiple includes`);
    
    // Inefficient: Include with iterations (recursive includes)
    console.time('Recursive includes');
    const recursiveIncludes = await client.search<Bundle>({
      resourceType: 'MedicationRequest',
      params: {
        'patient': 'Patient/example',
        '_include': 'MedicationRequest:medication',
        '_include:iterate': 'Medication:manufacturer'
      }
    });
    console.timeEnd('Recursive includes');
    console.log(`Retrieved ${recursiveIncludes.entry?.length || 0} resources with recursive includes`);
  } catch (error) {
    console.error('Error demonstrating efficient includes:', error);
  }
}
```

### Optimizing Revinclude Patterns

```typescript
/**
 * Demonstrates efficient revinclude patterns
 */
async function demonstrateEfficientRevincludes(): Promise<void> {
  try {
    // Efficient: Specific revinclude with additional filtering
    console.time('Specific revinclude with filtering');
    const specificRevinclude = await client.search<Bundle>({
      resourceType: 'Patient',
      params: {
        '_id': 'example',
        '_revinclude': 'Observation:subject',
        '_revinclude:Observation:date': 'ge2023-01-01'
      }
    });
    console.timeEnd('Specific revinclude with filtering');
    console.log(`Retrieved ${specificRevinclude.entry?.length || 0} resources with specific revinclude`);
    
    // Less efficient: Multiple revinclude types
    console.time('Multiple revinclude types');
    const multipleRevincludes = await client.search<Bundle>({
      resourceType: 'Patient',
      params: {
        '_id': 'example',
        '_revinclude': ['Observation:subject', 'Condition:subject', 'MedicationRequest:subject']
      }
    });
    console.timeEnd('Multiple revinclude types');
    console.log(`Retrieved ${multipleRevincludes.entry?.length || 0} resources with multiple revinclude types`);
    
    // Inefficient: Revinclude with iterations
    console.time('Revinclude with iterations');
    const revincludeWithIterations = await client.search<Bundle>({
      resourceType: 'Patient',
      params: {
        '_id': 'example',
        '_revinclude': 'Observation:subject',
        '_revinclude:iterate': 'DiagnosticReport:result'
      }
    });
    console.timeEnd('Revinclude with iterations');
    console.log(`Retrieved ${revincludeWithIterations.entry?.length || 0} resources with revinclude iterations`);
  } catch (error) {
    console.error('Error demonstrating efficient revincludes:', error);
  }
}
```

### Include/Revinclude Best Practices

| Best Practice | Rationale | Example |
|---------------|-----------|----------|
| Limit the number of includes | Each include adds database joins and processing | Use only essential includes |
| Avoid deep include chains | Recursive includes can be very expensive | Limit to one level of iteration |
| Add filtering to revinclude targets | Reduces the number of included resources | Filter by date, status, or type |
| Consider separate queries for rarely needed references | May be more efficient than complex includes | Fetch related data only when needed |

## Pagination and Result Limiting

Implement effective pagination strategies to handle large result sets efficiently.

### Implementing Efficient Pagination

```typescript
/**
 * Demonstrates efficient pagination strategies
 */
async function demonstrateEfficientPagination(): Promise<void> {
  try {
    // Efficient: Use _count parameter to limit results
    console.time('Pagination with _count');
    const firstPage = await client.search<Bundle>({
      resourceType: 'Observation',
      params: {
        'patient': 'Patient/example',
        '_count': '50',
        '_sort': '-date'
      }
    });
    console.timeEnd('Pagination with _count');
    console.log(`Retrieved ${firstPage.entry?.length || 0} observations in first page`);
    
    // Continue pagination using next link if available
    if (firstPage.link?.find(link => link.relation === 'next')) {
      const nextLink = firstPage.link.find(link => link.relation === 'next');
      if (nextLink?.url) {
        console.time('Pagination with next link');
        const secondPage = await client.request({
          method: 'GET',
          url: nextLink.url
        });
        console.timeEnd('Pagination with next link');
        console.log(`Retrieved ${secondPage.data.entry?.length || 0} observations in second page`);
      }
    }
    
    // Efficient: Use search parameter continuation for specific resource types
    console.time('Pagination with search parameter continuation');
    const initialSearch = await client.search<Bundle>({
      resourceType: 'Observation',
      params: {
        'patient': 'Patient/example',
        '_count': '50',
        '_sort': 'date'
      }
    });
    
    // Get the date of the last observation in the first page
    const lastObservation = initialSearch.entry?.[initialSearch.entry.length - 1]?.resource as any;
    const lastDate = lastObservation?.effectiveDateTime;
    
    if (lastDate) {
      // Continue search from where we left off
      const continuationSearch = await client.search<Bundle>({
        resourceType: 'Observation',
        params: {
          'patient': 'Patient/example',
          'date': `gt${lastDate}`,
          '_count': '50',
          '_sort': 'date'
        }
      });
      console.timeEnd('Pagination with search parameter continuation');
      console.log(`Retrieved ${continuationSearch.entry?.length || 0} observations in continuation page`);
    }
  } catch (error) {
    console.error('Error demonstrating efficient pagination:', error);
  }
}
```

### Pagination Strategies Comparison

| Strategy | Advantages | Disadvantages | Best For |
|----------|------------|---------------|----------|
| Page-based (`_count` and `page`) | Simple to implement and understand | Less efficient for deep pages | User interfaces with page navigation |
| Cursor-based (next/previous links) | Efficient for large datasets | Requires maintaining server state | Sequential access to large datasets |
| Search parameter continuation | Very efficient | More complex to implement | High-performance API access |
| Snapshot-based pagination | Consistent results across pages | Higher server resource usage | Data that changes frequently |

## Handling Complex Queries

Optimize complex queries to maintain good performance.

### Composite Parameters

Use composite parameters to improve query efficiency.

```typescript
/**
 * Demonstrates efficient use of composite parameters
 */
async function demonstrateCompositeParameters(): Promise<void> {
  try {
    // Less efficient: Multiple separate parameters
    console.time('Separate parameters');
    const separateParams = await client.search<Bundle>({
      resourceType: 'Observation',
      params: {
        'code': 'http://loinc.org|8867-4',
        'value-quantity': 'gt100',
        'value-quantity': 'lt120'
      }
    });
    console.timeEnd('Separate parameters');
    console.log(`Retrieved ${separateParams.entry?.length || 0} observations with separate parameters`);
    
    // More efficient: Composite parameter
    console.time('Composite parameter');
    const compositeParam = await client.search<Bundle>({
      resourceType: 'Observation',
      params: {
        'code-value-quantity': 'http://loinc.org|8867-4$gt100$lt120'
      }
    });
    console.timeEnd('Composite parameter');
    console.log(`Retrieved ${compositeParam.entry?.length || 0} observations with composite parameter`);
  } catch (error) {
    console.error('Error demonstrating composite parameters:', error);
  }
}
```

### Chained Search Optimization

Optimize chained searches for better performance.

```typescript
/**
 * Demonstrates efficient chained search strategies
 */
async function demonstrateChainedSearches(): Promise<void> {
  try {
    // Less efficient: Deeply chained search
    console.time('Deeply chained search');
    const deeplyChained = await client.search<Bundle>({
      resourceType: 'DiagnosticReport',
      params: {
        'subject:Patient.organization:Organization.name': 'Health Hospital'
      }
    });
    console.timeEnd('Deeply chained search');
    console.log(`Retrieved ${deeplyChained.entry?.length || 0} reports with deeply chained search`);
    
    // More efficient: Break into multiple queries
    console.time('Multiple targeted queries');
    
    // Step 1: Find the organization
    const organizations = await client.search<Bundle>({
      resourceType: 'Organization',
      params: {
        'name': 'Health Hospital'
      }
    });
    
    if (organizations.entry && organizations.entry.length > 0) {
      const organizationId = organizations.entry[0].resource.id;
      
      // Step 2: Find patients in that organization
      const patients = await client.search<Bundle>({
        resourceType: 'Patient',
        params: {
          'organization': `Organization/${organizationId}`
        }
      });
      
      const patientIds = patients.entry?.map(entry => entry.resource.id) || [];
      
      if (patientIds.length > 0) {
        // Step 3: Find diagnostic reports for those patients
        const patientReferences = patientIds.map(id => `Patient/${id}`).join(',');
        const reports = await client.search<Bundle>({
          resourceType: 'DiagnosticReport',
          params: {
            'subject': patientReferences
          }
        });
        
        console.timeEnd('Multiple targeted queries');
        console.log(`Retrieved ${reports.entry?.length || 0} reports with multiple targeted queries`);
      }
    }
  } catch (error) {
    console.error('Error demonstrating chained searches:', error);
  }
}
```

### Complex Query Best Practices

| Best Practice | Rationale | Example |
|---------------|-----------|----------|
| Limit chain depth | Each level adds significant processing overhead | Limit to 1-2 levels of chaining |
| Use reverse chains when possible | Often more efficient than forward chains | `Patient?_has:Observation:subject:code=8867-4` |
| Break complex queries into simpler ones | Can be more efficient for very complex queries | Multiple targeted queries |
| Use composite parameters | More efficient than multiple separate parameters | `Observation?code-value-quantity=8867-4$gt100` |

## Server-Side Query Optimization

Implement server-side optimizations to improve query performance.

### Query Plan Caching

Implement query plan caching to avoid repeated query parsing and planning.

```typescript
// Example query plan cache implementation
class QueryPlanCache {
  private cache: Map<string, any> = new Map();
  private maxSize: number;
  
  constructor(maxSize: number = 1000) {
    this.maxSize = maxSize;
  }
  
  /**
   * Get a cached query plan
   * @param key The query key
   * @returns The cached query plan or undefined
   */
  get(key: string): any {
    return this.cache.get(key);
  }
  
  /**
   * Store a query plan in the cache
   * @param key The query key
   * @param plan The query plan to cache
   */
  put(key: string, plan: any): void {
    // Evict oldest entry if cache is full
    if (this.cache.size >= this.maxSize) {
      const oldestKey = this.cache.keys().next().value;
      this.cache.delete(oldestKey);
    }
    
    this.cache.set(key, plan);
  }
  
  /**
   * Generate a cache key from search parameters
   * @param resourceType The resource type being searched
   * @param params The search parameters
   * @returns A cache key string
   */
  static generateKey(resourceType: string, params: Record<string, any>): string {
    const sortedParams = Object.entries(params)
      .sort(([keyA], [keyB]) => keyA.localeCompare(keyB))
      .map(([key, value]) => `${key}=${value}`);
    
    return `${resourceType}?${sortedParams.join('&')}`;
  }
}

// Usage example
const queryPlanCache = new QueryPlanCache();

/**
 * Execute a search with query plan caching
 * @param resourceType The resource type to search
 * @param params The search parameters
 * @returns The search results
 */
async function executeSearchWithPlanCaching<T>(resourceType: string, params: Record<string, any>): Promise<Bundle> {
  const cacheKey = QueryPlanCache.generateKey(resourceType, params);
  let queryPlan = queryPlanCache.get(cacheKey);
  
  if (!queryPlan) {
    // Generate a new query plan (this would be server-specific)
    queryPlan = { /* query plan details */ };
    queryPlanCache.put(cacheKey, queryPlan);
  }
  
  // Execute the search using the query plan
  return await client.search<Bundle>({
    resourceType,
    params
  });
}
```

### Query Optimization Techniques

| Technique | Description | Implementation |
|-----------|-------------|----------------|
| Query plan caching | Cache execution plans for repeated queries | In-memory cache of query plans |
| Result set caching | Cache results for frequently used queries | In-memory or distributed cache |
| Prepared statements | Pre-compile queries for repeated execution | Database prepared statements |
| Query rewriting | Rewrite queries for better performance | Server middleware for query optimization |
| Asynchronous processing | Process complex queries asynchronously | Background workers and notification mechanisms |

## Conclusion

Optimizing FHIR query performance is essential for creating responsive and scalable healthcare applications. By implementing efficient search parameter usage, optimizing include and revinclude patterns, using appropriate pagination strategies, and handling complex queries effectively, you can significantly improve the performance of your FHIR server.

Key takeaways:

1. Use selective search parameters to minimize result set size
2. Implement efficient include and revinclude patterns to retrieve related resources
3. Use appropriate pagination strategies for large result sets
4. Optimize complex queries with composite parameters and targeted searches
5. Implement server-side optimizations like query plan caching

By following these guidelines, you can create high-performance FHIR queries that provide a better experience for users and reduce the load on your server.
