# FHIR Caching Strategies

## Introduction

Caching is a powerful technique for improving FHIR server performance by storing frequently accessed data in memory or fast storage. This guide explains effective caching strategies for FHIR servers, covering resource-level caching, search result caching, terminology caching, and cache invalidation approaches. By implementing these caching strategies, you can significantly reduce database load and improve response times for your FHIR server.

### Quick Start

1. Implement resource-level caching for frequently accessed resources
2. Add search result caching for common queries
3. Set up terminology caching for code systems and value sets
4. Establish effective cache invalidation strategies
5. Monitor cache performance and adjust as needed

### Related Components

- [FHIR Database Optimization](fhir-database-optimization.md): Optimize database performance
- [FHIR Query Performance](fhir-query-performance.md): Optimize FHIR query patterns
- [FHIR Server Monitoring](fhir-server-monitoring.md): Monitor server performance
- [FHIR Server Configuration](fhir-server-configuration.md) (Coming Soon): Configure server for optimal performance

## Resource-Level Caching

Resource-level caching stores individual FHIR resources in memory for fast retrieval.

### Implementing Resource Cache

```typescript
import { AidboxClient } from '@aidbox/sdk-r4';
import NodeCache from 'node-cache';

const client = new AidboxClient({
  baseUrl: 'http://localhost:8888',
  auth: {
    type: 'basic',
    username: 'root',
    password: 'secret'
  }
});

// Configure resource cache
const resourceCache = new NodeCache({
  stdTTL: 300, // 5 minutes default TTL
  checkperiod: 60, // Check for expired keys every 60 seconds
  maxKeys: 10000 // Maximum number of keys in cache
});

/**
 * Resource cache TTL configuration by resource type
 * Different resource types may have different caching needs
 */
const resourceTTLConfig: Record<string, number> = {
  'Patient': 3600, // 1 hour for Patient resources
  'Practitioner': 3600, // 1 hour for Practitioner resources
  'Organization': 7200, // 2 hours for Organization resources
  'Location': 7200, // 2 hours for Location resources
  'Observation': 300, // 5 minutes for Observation resources
  'Condition': 300, // 5 minutes for Condition resources
  'MedicationRequest': 300 // 5 minutes for MedicationRequest resources
};

/**
 * Determines if a resource type should be cached
 * @param resourceType The resource type to check
 * @returns Whether the resource type should be cached
 */
function isCacheableResourceType(resourceType: string): boolean {
  return resourceType in resourceTTLConfig;
}

/**
 * Gets the appropriate TTL for a resource type
 * @param resourceType The resource type
 * @returns The TTL in seconds
 */
function getResourceTTL(resourceType: string): number {
  return resourceTTLConfig[resourceType] || 300; // Default to 5 minutes
}

/**
 * Generates a cache key for a resource
 * @param resourceType The resource type
 * @param id The resource ID
 * @returns The cache key
 */
function generateResourceCacheKey(resourceType: string, id: string): string {
  return `resource:${resourceType}:${id}`;
}

/**
 * Reads a resource with caching
 * @param resourceType The resource type
 * @param id The resource ID
 * @returns The resource
 */
async function readResourceWithCache<T>(resourceType: string, id: string): Promise<T> {
  const cacheKey = generateResourceCacheKey(resourceType, id);
  
  // Check if resource is in cache
  const cachedResource = resourceCache.get<T>(cacheKey);
  if (cachedResource) {
    console.log(`Cache hit for ${resourceType}/${id}`);
    return cachedResource;
  }
  
  // Resource not in cache, fetch from server
  console.log(`Cache miss for ${resourceType}/${id}`);
  const resource = await client.read<T>({
    resourceType,
    id
  });
  
  // Cache the resource if it's a cacheable type
  if (isCacheableResourceType(resourceType)) {
    const ttl = getResourceTTL(resourceType);
    resourceCache.set(cacheKey, resource, ttl);
    console.log(`Cached ${resourceType}/${id} for ${ttl} seconds`);
  }
  
  return resource;
}

/**
 * Invalidates a resource in the cache
 * @param resourceType The resource type
 * @param id The resource ID
 */
function invalidateResourceCache(resourceType: string, id: string): void {
  const cacheKey = generateResourceCacheKey(resourceType, id);
  resourceCache.del(cacheKey);
  console.log(`Invalidated cache for ${resourceType}/${id}`);
}

/**
 * Updates a resource with cache invalidation
 * @param resource The resource to update
 * @returns The updated resource
 */
async function updateResourceWithCacheInvalidation<T extends { resourceType: string; id?: string }>(resource: T): Promise<T> {
  // Update the resource
  const updatedResource = await client.update<T>(resource);
  
  // Invalidate the cache for this resource
  if (resource.id) {
    invalidateResourceCache(resource.resourceType, resource.id);
  }
  
  return updatedResource;
}
```

### Resource Caching Considerations

| Consideration | Recommendation | Rationale |
|---------------|----------------|----------|
| Cache size | Limit based on available memory | Prevent memory exhaustion |
| TTL (Time to Live) | Vary by resource type and volatility | Balance freshness and performance |
| Versioning | Consider including version in cache key | Ensure correct version retrieval |
| References | Consider pre-fetching common references | Improve performance for related resources |

## Search Result Caching

Search result caching stores the results of common queries to avoid repeated database access.

### Implementing Search Cache

```typescript
import crypto from 'crypto';

// Configure search cache
const searchCache = new NodeCache({
  stdTTL: 60, // 1 minute default TTL
  checkperiod: 30, // Check for expired keys every 30 seconds
  maxKeys: 1000 // Maximum number of search results to cache
});

/**
 * Search cache TTL configuration by resource type
 */
const searchTTLConfig: Record<string, number> = {
  'Patient': 300, // 5 minutes for Patient searches
  'Practitioner': 300, // 5 minutes for Practitioner searches
  'Organization': 600, // 10 minutes for Organization searches
  'ValueSet': 3600, // 1 hour for ValueSet searches
  'CodeSystem': 3600 // 1 hour for CodeSystem searches
};

/**
 * Generates a cache key for a search query
 * @param resourceType The resource type being searched
 * @param params The search parameters
 * @returns The cache key
 */
function generateSearchCacheKey(resourceType: string, params: Record<string, any>): string {
  // Sort parameters for consistent key generation
  const sortedParams = Object.entries(params)
    .sort(([keyA], [keyB]) => keyA.localeCompare(keyB))
    .map(([key, value]) => `${key}=${value}`);
  
  const paramString = sortedParams.join('&');
  
  // Use a hash for long parameter strings
  if (paramString.length > 100) {
    return `search:${resourceType}:${crypto.createHash('md5').update(paramString).digest('hex')}`;
  }
  
  return `search:${resourceType}:${paramString}`;
}

/**
 * Gets the appropriate TTL for a search query
 * @param resourceType The resource type
 * @returns The TTL in seconds
 */
function getSearchTTL(resourceType: string): number {
  return searchTTLConfig[resourceType] || 60; // Default to 1 minute
}

/**
 * Determines if a search should be cached
 * @param resourceType The resource type
 * @param params The search parameters
 * @returns Whether the search should be cached
 */
function isCacheableSearch(resourceType: string, params: Record<string, any>): boolean {
  // Don't cache searches with _count=0 (typically used for counts only)
  if (params._count === '0') return false;
  
  // Don't cache searches with very high _count values
  if (params._count && parseInt(params._count) > 100) return false;
  
  // Don't cache searches that include the _include or _revinclude parameters
  if (params._include || params._revinclude) return false;
  
  // Cache searches for specific resource types that don't change frequently
  return resourceType in searchTTLConfig;
}

/**
 * Performs a search with caching
 * @param resourceType The resource type to search
 * @param params The search parameters
 * @returns The search results
 */
async function searchWithCache<T>(resourceType: string, params: Record<string, any>): Promise<any> {
  const cacheKey = generateSearchCacheKey(resourceType, params);
  
  // Check if search result is in cache
  const cachedResult = searchCache.get(cacheKey);
  if (cachedResult) {
    console.log(`Search cache hit for ${resourceType}`);
    return cachedResult;
  }
  
  // Search result not in cache, perform search
  console.log(`Search cache miss for ${resourceType}`);
  const result = await client.search<T>({
    resourceType,
    params
  });
  
  // Cache the search result if it's cacheable
  if (isCacheableSearch(resourceType, params)) {
    const ttl = getSearchTTL(resourceType);
    searchCache.set(cacheKey, result, ttl);
    console.log(`Cached search for ${resourceType} for ${ttl} seconds`);
  }
  
  return result;
}

/**
 * Invalidates search cache for a resource type
 * @param resourceType The resource type
 */
function invalidateSearchCache(resourceType: string): void {
  // Get all keys in the cache
  const keys = searchCache.keys();
  
  // Filter keys for the specified resource type
  const keysToDelete = keys.filter(key => key.startsWith(`search:${resourceType}:`));
  
  // Delete the keys
  keysToDelete.forEach(key => searchCache.del(key));
  console.log(`Invalidated ${keysToDelete.length} search cache entries for ${resourceType}`);
}
```

### Search Caching Considerations

| Consideration | Recommendation | Rationale |
|---------------|----------------|----------|
| Query complexity | Cache simple, frequent queries | Complex queries may be unique and not worth caching |
| Result size | Limit caching to reasonably sized results | Large results consume too much memory |
| Data volatility | Shorter TTL for frequently changing data | Ensure reasonable freshness |
| Cache invalidation | Invalidate by resource type on updates | Maintain cache consistency |

## Terminology Caching

Terminology caching stores code systems, value sets, and concept maps to improve terminology operations.

### Implementing Terminology Cache

```typescript
// Configure terminology cache
const terminologyCache = new NodeCache({
  stdTTL: 3600, // 1 hour default TTL
  checkperiod: 300, // Check for expired keys every 5 minutes
  maxKeys: 500 // Maximum number of terminology items to cache
});

/**
 * Generates a cache key for a value set
 * @param url The value set URL
 * @returns The cache key
 */
function generateValueSetCacheKey(url: string): string {
  return `terminology:valueset:${url}`;
}

/**
 * Generates a cache key for a code system
 * @param url The code system URL
 * @returns The cache key
 */
function generateCodeSystemCacheKey(url: string): string {
  return `terminology:codesystem:${url}`;
}

/**
 * Generates a cache key for a concept validation
 * @param system The code system URL
 * @param code The code to validate
 * @returns The cache key
 */
function generateConceptValidationCacheKey(system: string, code: string): string {
  return `terminology:validation:${system}:${code}`;
}

/**
 * Retrieves a value set with caching
 * @param url The value set URL
 * @returns The value set
 */
async function getValueSetWithCache(url: string): Promise<any> {
  const cacheKey = generateValueSetCacheKey(url);
  
  // Check if value set is in cache
  const cachedValueSet = terminologyCache.get(cacheKey);
  if (cachedValueSet) {
    console.log(`Terminology cache hit for ValueSet ${url}`);
    return cachedValueSet;
  }
  
  // Value set not in cache, fetch it
  console.log(`Terminology cache miss for ValueSet ${url}`);
  const valueSet = await client.search({
    resourceType: 'ValueSet',
    params: {
      url
    }
  });
  
  // Cache the value set
  if (valueSet.entry && valueSet.entry.length > 0) {
    terminologyCache.set(cacheKey, valueSet.entry[0].resource, 3600); // Cache for 1 hour
    console.log(`Cached ValueSet ${url}`);
  }
  
  return valueSet.entry && valueSet.entry.length > 0 ? valueSet.entry[0].resource : null;
}

/**
 * Validates a code against a code system with caching
 * @param system The code system URL
 * @param code The code to validate
 * @returns The validation result
 */
async function validateCodeWithCache(system: string, code: string): Promise<any> {
  const cacheKey = generateConceptValidationCacheKey(system, code);
  
  // Check if validation result is in cache
  const cachedResult = terminologyCache.get(cacheKey);
  if (cachedResult) {
    console.log(`Terminology cache hit for validation ${system}|${code}`);
    return cachedResult;
  }
  
  // Validation result not in cache, perform validation
  console.log(`Terminology cache miss for validation ${system}|${code}`);
  const validationResult = await client.request({
    method: 'GET',
    url: '/CodeSystem/$validate-code',
    params: {
      system,
      code
    }
  });
  
  // Cache the validation result
  terminologyCache.set(cacheKey, validationResult.data, 3600); // Cache for 1 hour
  console.log(`Cached validation result for ${system}|${code}`);
  
  return validationResult.data;
}
```

### Terminology Caching Considerations

| Consideration | Recommendation | Rationale |
|---------------|----------------|----------|
| Cache scope | Focus on frequently used terminologies | Some code systems are very large |
| Validation results | Cache individual code validations | Avoid repeated validation of the same codes |
| Expansion results | Cache value set expansions | Value set expansion can be expensive |
| TTL | Longer TTL for stable terminologies | Terminologies change infrequently |

## Cache Invalidation Strategies

Effective cache invalidation ensures that cached data remains consistent with the database.

### Time-Based Invalidation

Time-based invalidation uses TTL (Time to Live) to automatically expire cached items.

```typescript
// Configure cache with appropriate TTL values
const cache = new NodeCache({
  stdTTL: 300, // 5 minutes default TTL
  checkperiod: 60 // Check for expired keys every 60 seconds
});

// Set different TTL values for different types of data
cache.set('resource:Patient:123', patientData, 3600); // 1 hour for Patient resources
cache.set('search:Observation:patient=123', observationData, 60); // 1 minute for Observation searches
```

### Event-Based Invalidation

Event-based invalidation removes or updates cached items when the underlying data changes.

```typescript
/**
 * Handles resource update events for cache invalidation
 * @param event The resource update event
 */
function handleResourceUpdateEvent(event: {
  resourceType: string;
  id: string;
  action: 'create' | 'update' | 'delete';
}): void {
  // Invalidate the specific resource cache
  invalidateResourceCache(event.resourceType, event.id);
  
  // Invalidate search cache for this resource type
  invalidateSearchCache(event.resourceType);
  
  // Invalidate related resource caches if needed
  if (event.resourceType === 'Patient') {
    // Patient updates may affect Observation searches
    invalidateSearchCache('Observation');
  }
}

// Example subscription to resource update events
subscribeToResourceEvents(handleResourceUpdateEvent);

/**
 * Example function to subscribe to resource events
 * Implementation would depend on your event system
 */
function subscribeToResourceEvents(handler: Function): void {
  // This is a placeholder for your actual event subscription implementation
  console.log('Subscribed to resource events for cache invalidation');
}
```

### Selective Invalidation

Selective invalidation targets specific cache entries based on dependencies.

```typescript
/**
 * Cache dependency tracker
 */
class CacheDependencyTracker {
  private dependencies: Map<string, Set<string>> = new Map();
  
  /**
   * Adds a dependency relationship
   * @param target The target cache key
   * @param dependency The dependency cache key
   */
  addDependency(target: string, dependency: string): void {
    if (!this.dependencies.has(dependency)) {
      this.dependencies.set(dependency, new Set());
    }
    
    this.dependencies.get(dependency)?.add(target);
  }
  
  /**
   * Gets all cache keys dependent on a key
   * @param key The dependency key
   * @returns Array of dependent cache keys
   */
  getDependents(key: string): string[] {
    return Array.from(this.dependencies.get(key) || []);
  }
  
  /**
   * Invalidates a cache key and all its dependents
   * @param key The key to invalidate
   * @param cache The cache instance
   */
  invalidateWithDependents(key: string, cache: NodeCache): void {
    // Invalidate the key itself
    cache.del(key);
    
    // Invalidate all dependents
    const dependents = this.getDependents(key);
    dependents.forEach(dependent => {
      cache.del(dependent);
      console.log(`Invalidated dependent cache key: ${dependent}`);
      
      // Recursively invalidate nested dependents
      this.invalidateWithDependents(dependent, cache);
    });
  }
}

// Example usage
const dependencyTracker = new CacheDependencyTracker();

// Track dependencies when caching
function cacheWithDependency(cache: NodeCache, key: string, value: any, ttl: number, dependencies: string[]): void {
  cache.set(key, value, ttl);
  
  // Register dependencies
  dependencies.forEach(dependency => {
    dependencyTracker.addDependency(key, dependency);
  });
}

// Invalidate with dependencies
function invalidateWithDependencies(cache: NodeCache, key: string): void {
  dependencyTracker.invalidateWithDependents(key, cache);
}
```

### Cache Invalidation Best Practices

| Best Practice | Implementation | Benefit |
|---------------|----------------|----------|
| Combine strategies | Use TTL with event-based invalidation | Balance consistency and performance |
| Granular invalidation | Target specific cache entries | Minimize unnecessary cache misses |
| Batch invalidations | Group related invalidations | Reduce invalidation overhead |
| Versioning | Include version in cache keys | Simplify invalidation on schema changes |

## Conclusion

Effective caching strategies can significantly improve the performance of your FHIR server by reducing database load and improving response times. By implementing resource-level caching, search result caching, terminology caching, and appropriate cache invalidation strategies, you can create a high-performance FHIR server that provides a better experience for users.

Key takeaways:

1. Implement resource-level caching for frequently accessed resources
2. Use search result caching for common queries to reduce database load
3. Set up terminology caching to improve performance of terminology operations
4. Establish effective cache invalidation strategies to maintain data consistency
5. Monitor cache performance and adjust caching strategies as needed

By following these guidelines, you can create a caching system that balances performance improvements with data freshness and consistency requirements.
