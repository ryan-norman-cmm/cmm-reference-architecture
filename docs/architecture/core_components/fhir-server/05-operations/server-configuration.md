# FHIR Server Configuration

## Introduction

Proper server configuration is essential for achieving optimal performance in FHIR server implementations. This guide explains key configuration strategies for FHIR servers, covering JVM tuning, connection pooling, thread pool configuration, and memory allocation. By implementing these configuration optimizations, you can significantly improve the performance, stability, and scalability of your FHIR server.

### Quick Start

1. Configure JVM settings appropriate for your FHIR server workload
2. Optimize connection pools for database and HTTP connections
3. Configure thread pools for efficient request handling
4. Implement appropriate memory allocation strategies
5. Tune web server settings for FHIR workloads

### Related Components

- [FHIR Database Optimization](fhir-database-optimization.md): Optimize database performance
- [FHIR Query Performance](fhir-query-performance.md): Optimize FHIR query patterns
- [FHIR Caching Strategies](fhir-caching-strategies.md): Implement caching for performance
- [FHIR Server Monitoring](fhir-server-monitoring.md): Monitor server performance

## JVM Tuning for Java-Based Servers

Many FHIR servers are Java-based and require appropriate JVM tuning for optimal performance.

### Memory Settings

Configure JVM memory settings based on your server's workload and available resources.

```bash
# Example JVM memory settings for a FHIR server

# For a server with 16GB of RAM
JAVA_OPTS="-Xms8G -Xmx8G" # Set initial and maximum heap size to 8GB

# For a server with 32GB of RAM
JAVA_OPTS="-Xms16G -Xmx16G" # Set initial and maximum heap size to 16GB

# For a server with 64GB of RAM
JAVA_OPTS="-Xms32G -Xmx32G" # Set initial and maximum heap size to 32GB
```

### Garbage Collection Settings

Choose and configure the appropriate garbage collector based on your application's needs.

```bash
# For applications prioritizing throughput
JAVA_OPTS="$JAVA_OPTS -XX:+UseParallelGC"

# For applications prioritizing low latency
JAVA_OPTS="$JAVA_OPTS -XX:+UseG1GC"

# For applications with large heaps (>16GB)
JAVA_OPTS="$JAVA_OPTS -XX:+UseG1GC -XX:G1HeapRegionSize=16m"

# For applications requiring very low pause times
JAVA_OPTS="$JAVA_OPTS -XX:+UseZGC"
```

### JVM Tuning Best Practices

| Setting | Recommendation | Rationale |
|---------|----------------|----------|
| Heap size | Set initial and maximum heap to the same value | Avoids resizing pauses |
| Metaspace | Configure based on application needs | Prevents OutOfMemoryError for class metadata |
| GC logging | Enable for performance monitoring | Helps identify GC-related issues |
| Large pages | Enable for large heap sizes | Improves memory access performance |

### Complete JVM Configuration Example

```bash
#!/bin/bash
# Example JVM configuration for a FHIR server

# Memory settings
JAVA_OPTS="-Xms16G -Xmx16G"

# Garbage collector settings (G1GC for balanced throughput and latency)
JAVA_OPTS="$JAVA_OPTS -XX:+UseG1GC -XX:G1HeapRegionSize=4m -XX:+ParallelRefProcEnabled"
JAVA_OPTS="$JAVA_OPTS -XX:+ExplicitGCInvokesConcurrent -XX:MaxGCPauseMillis=200"

# Metaspace settings
JAVA_OPTS="$JAVA_OPTS -XX:MetaspaceSize=256m -XX:MaxMetaspaceSize=512m"

# GC logging
JAVA_OPTS="$JAVA_OPTS -Xlog:gc*=info:file=/var/log/fhir-server/gc.log:time,uptime,level,tags:filecount=5,filesize=100m"

# Large pages (if supported by the OS)
JAVA_OPTS="$JAVA_OPTS -XX:+UseLargePages"

# Network settings
JAVA_OPTS="$JAVA_OPTS -Djava.net.preferIPv4Stack=true"

# Performance optimizations
JAVA_OPTS="$JAVA_OPTS -XX:+OptimizeStringConcat -XX:+UseFastAccessorMethods"

# Start the FHIR server with the configured options
java $JAVA_OPTS -jar fhir-server.jar
```

## Connection Pooling Optimization

Connection pooling improves performance by reusing database and HTTP connections.

### Database Connection Pool

Configure database connection pools for optimal performance.

```java
// Example HikariCP configuration for a FHIR server
HikariConfig config = new HikariConfig();
config.setJdbcUrl("jdbc:postgresql://localhost:5432/fhir");
config.setUsername("fhir_user");
config.setPassword("password");

// Basic pool configuration
config.setPoolName("FHIRConnectionPool");
config.setMinimumIdle(10); // Minimum number of idle connections
config.setMaximumPoolSize(100); // Maximum pool size

// Connection timeout settings
config.setConnectionTimeout(30000); // 30 seconds
config.setIdleTimeout(600000); // 10 minutes
config.setMaxLifetime(1800000); // 30 minutes

// Performance settings
config.addDataSourceProperty("cachePrepStmts", "true");
config.addDataSourceProperty("prepStmtCacheSize", "250");
config.addDataSourceProperty("prepStmtCacheSqlLimit", "2048");

// Create the connection pool
HikariDataSource dataSource = new HikariDataSource(config);
```

### HTTP Client Connection Pool

Configure HTTP client connection pools for external API calls.

```java
// Example Apache HttpClient configuration for a FHIR server
PoolingHttpClientConnectionManager connectionManager = new PoolingHttpClientConnectionManager();

// Set the maximum number of connections
connectionManager.setMaxTotal(200);

// Set the maximum number of connections per route
connectionManager.setDefaultMaxPerRoute(20);

// Configure timeouts
RequestConfig requestConfig = RequestConfig.custom()
    .setConnectTimeout(5000) // 5 seconds
    .setSocketTimeout(30000) // 30 seconds
    .setConnectionRequestTimeout(5000) // 5 seconds
    .build();

// Build the HTTP client
CloseableHttpClient httpClient = HttpClients.custom()
    .setConnectionManager(connectionManager)
    .setDefaultRequestConfig(requestConfig)
    .setKeepAliveStrategy((response, context) -> 30 * 1000) // 30 seconds
    .build();
```

### Connection Pool Sizing Guidelines

| Factor | Recommendation | Example |
|--------|----------------|----------|
| CPU cores | 2-3x number of cores for max pool size | 32 cores = 64-96 connections |
| Database capacity | Consider database connection limits | PostgreSQL default_max_connections = 100 |
| Request patterns | Higher for many short queries, lower for fewer long queries | Read-heavy API = larger pool |
| Memory constraints | Each connection consumes memory | Limited memory = smaller pool |

## Thread Pool Configuration

Proper thread pool configuration ensures efficient request handling.

### Web Server Thread Pool

Configure web server thread pools based on workload characteristics.

```properties
# Example Tomcat thread pool configuration

# Maximum number of threads
server.tomcat.max-threads=200

# Minimum number of idle threads
server.tomcat.min-spare-threads=20

# Maximum queue length
server.tomcat.accept-count=100

# Connection timeout in milliseconds
server.tomcat.connection-timeout=20000
```

```properties
# Example Jetty thread pool configuration

# Minimum number of threads
jetty.threadPool.minThreads=20

# Maximum number of threads
jetty.threadPool.maxThreads=200

# Thread idle timeout in milliseconds
jetty.threadPool.idleTimeout=60000
```

### Asynchronous Task Executors

Configure thread pools for background tasks and asynchronous processing.

```java
// Example Spring Boot async executor configuration
@Configuration
public class AsyncConfig implements AsyncConfigurer {
    
    @Override
    public Executor getAsyncExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        
        // Core pool size (always active)
        executor.setCorePoolSize(10);
        
        // Maximum pool size
        executor.setMaxPoolSize(50);
        
        // Queue capacity
        executor.setQueueCapacity(100);
        
        // Thread name prefix
        executor.setThreadNamePrefix("FHIRAsync-");
        
        // Rejection policy
        executor.setRejectedExecutionHandler(new ThreadPoolExecutor.CallerRunsPolicy());
        
        executor.initialize();
        return executor;
    }
    
    @Override
    public AsyncUncaughtExceptionHandler getAsyncUncaughtExceptionHandler() {
        return new SimpleAsyncUncaughtExceptionHandler();
    }
}
```

### Thread Pool Sizing Guidelines

| Factor | Recommendation | Rationale |
|--------|----------------|----------|
| CPU cores | 2-4x number of cores for web threads | Accounts for I/O-bound operations |
| Request latency | Higher thread count for high-latency operations | Maintains throughput during I/O waits |
| Memory per thread | Consider thread stack size in total memory usage | Prevents excessive memory consumption |
| Request patterns | Adjust based on concurrent user load | Handles peak traffic without excessive resource usage |

## Memory Allocation Strategies

Effective memory allocation is crucial for FHIR server performance.

### Heap Memory Allocation

Configure heap memory allocation based on workload characteristics.

```bash
# Example heap memory allocation for different FHIR server components

# For servers with large in-memory caches
JAVA_OPTS="-Xms16G -Xmx16G -XX:+UseG1GC -XX:G1HeapRegionSize=8m"

# For servers with moderate caching and high throughput
JAVA_OPTS="-Xms8G -Xmx8G -XX:+UseG1GC -XX:MaxGCPauseMillis=200"

# For servers with minimal caching and low memory
JAVA_OPTS="-Xms4G -Xmx4G -XX:+UseG1GC -XX:MaxGCPauseMillis=100"
```

### Off-Heap Memory Strategies

Use off-heap memory for large data structures to reduce garbage collection pressure.

```java
// Example off-heap cache configuration using Caffeine
Caffeine<String, byte[]> offHeapCache = Caffeine.newBuilder()
    .maximumWeight(10_000_000_000L) // 10GB
    .weigher((key, value) -> value.length) // Weight by byte array size
    .executor(Runnable::run) // Use caller thread for maintenance
    .build();

// Example off-heap cache configuration using MapDB
DB db = DBMaker.memoryDirectDB() // Off-heap memory
    .allocateStartSize(1 * 1024 * 1024 * 1024) // 1GB initial size
    .allocateIncrement(512 * 1024 * 1024) // 512MB growth increment
    .closeOnJvmShutdown()
    .make();

HTreeMap<String, byte[]> offHeapMap = db.hashMap("fhirCache")
    .keySerializer(Serializer.STRING)
    .valueSerializer(Serializer.BYTE_ARRAY)
    .create();
```

### Memory Allocation Best Practices

| Best Practice | Implementation | Benefit |
|---------------|----------------|----------|
| Right-size heap | Balance heap size with other system needs | Prevents excessive swapping and GC pauses |
| Monitor GC activity | Use tools like JConsole, VisualVM, or GC logs | Identifies memory-related performance issues |
| Use off-heap for large objects | Direct ByteBuffers or specialized libraries | Reduces GC pressure for large caches |
| Consider memory-mapped files | Use for very large datasets | Efficient access to data larger than available RAM |

## Web Server Configuration

Optimize web server settings for FHIR API workloads.

### HTTP Compression

Configure HTTP compression to reduce bandwidth usage.

```properties
# Example Spring Boot compression settings

# Enable response compression
server.compression.enabled=true

# Minimum response size for compression to be applied
server.compression.min-response-size=2048

# MIME types to compress
server.compression.mime-types=application/fhir+json,application/fhir+xml,application/json,application/xml,text/html,text/xml,text/plain
```

### HTTP/2 Support

Enable HTTP/2 for improved connection efficiency.

```properties
# Example Spring Boot HTTP/2 configuration

# Enable HTTP/2 support
server.http2.enabled=true

# Configure SSL for HTTP/2
server.ssl.enabled=true
server.ssl.key-store=classpath:keystore.jks
server.ssl.key-store-password=password
server.ssl.key-store-type=JKS
server.ssl.key-alias=fhirserver
```

### Request Timeouts

Configure appropriate request timeouts based on operation types.

```properties
# Example timeout configuration

# Connection timeout (how long to wait for a connection to be established)
server.connection-timeout=5000

# Socket timeout (how long to wait for data to be received)
spring.mvc.async.request-timeout=30000

# Custom timeouts for specific operations
fhir.timeout.search=60000
fhir.timeout.transaction=120000
fhir.timeout.export=300000
```

### Web Server Best Practices

| Best Practice | Implementation | Benefit |
|---------------|----------------|----------|
| Enable HTTP compression | Configure for FHIR content types | Reduces bandwidth usage and improves response times |
| Use HTTP/2 | Configure with SSL | Improves connection efficiency and reduces latency |
| Configure appropriate timeouts | Set based on operation types | Prevents resource exhaustion from slow clients |
| Enable connection keep-alive | Configure keep-alive timeout | Reduces connection establishment overhead |

## Conclusion

Proper server configuration is essential for achieving optimal performance in FHIR server implementations. By implementing appropriate JVM tuning, connection pooling optimization, thread pool configuration, and memory allocation strategies, you can significantly improve the performance, stability, and scalability of your FHIR server.

Key takeaways:

1. Configure JVM settings appropriate for your FHIR server workload
2. Optimize connection pools for database and HTTP connections
3. Configure thread pools for efficient request handling
4. Implement appropriate memory allocation strategies
5. Tune web server settings for FHIR workloads

By following these guidelines, you can create a high-performance FHIR server configuration that efficiently utilizes system resources and provides a responsive experience for users.
