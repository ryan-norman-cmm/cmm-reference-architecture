# FHIR Database Optimization

## Introduction

Database performance is critical for FHIR server implementations, as it directly impacts response times, throughput, and overall system scalability. This guide explains key database optimization strategies for FHIR servers, covering index optimization, query patterns, database configuration, and partitioning strategies. By implementing these optimizations, you can significantly improve the performance and scalability of your FHIR server.

### Quick Start

1. Identify and create appropriate indexes for common FHIR search parameters
2. Optimize database configuration for FHIR workloads
3. Implement partitioning strategies for large FHIR datasets
4. Regularly analyze and tune query performance
5. Consider database-specific optimizations for your chosen platform

### Related Components

- [FHIR Server Monitoring](fhir-server-monitoring.md): Monitor server performance
- [FHIR Query Optimization](fhir-query-optimization.md): Optimize FHIR query patterns
- [FHIR Backup and Recovery](fhir-backup-recovery.md) (Coming Soon): Implement data protection strategies
- [FHIR Server Setup Guide](fhir-server-setup-guide.md): Configure your FHIR environment

## Index Optimization for FHIR Resources

Proper indexing is essential for efficient FHIR resource retrieval and searching.

### Common FHIR Search Parameters

Identify and index the most commonly used search parameters for each resource type.

| Resource Type | Common Search Parameters | Index Type |
|---------------|--------------------------|------------|
| Patient | identifier, name, birthdate, gender | B-tree |
| Observation | subject, code, date, value-quantity | B-tree, GIN for token searches |
| Encounter | patient, date, status, type | B-tree |
| MedicationRequest | patient, medication, status, authoredon | B-tree |
| Condition | patient, code, onset-date, clinical-status | B-tree, GIN for token searches |

### Index Creation Examples

```sql
-- PostgreSQL index examples for FHIR resources

-- Patient resource indexes
CREATE INDEX idx_patient_identifier ON patient USING GIN (identifier jsonb_path_ops);
CREATE INDEX idx_patient_name ON patient USING GIN ((resource -> 'name') jsonb_path_ops);
CREATE INDEX idx_patient_birthdate ON patient ((resource ->> 'birthDate'));
CREATE INDEX idx_patient_gender ON patient ((resource ->> 'gender'));

-- Observation resource indexes
CREATE INDEX idx_observation_subject ON observation ((resource -> 'subject' ->> 'reference'));
CREATE INDEX idx_observation_code ON observation USING GIN ((resource -> 'code' -> 'coding') jsonb_path_ops);
CREATE INDEX idx_observation_date ON observation ((resource ->> 'effectiveDateTime'));
CREATE INDEX idx_observation_value_quantity ON observation ((resource -> 'valueQuantity' ->> 'value') DESC);

-- Encounter resource indexes
CREATE INDEX idx_encounter_patient ON encounter ((resource -> 'subject' ->> 'reference'));
CREATE INDEX idx_encounter_date ON encounter ((resource -> 'period' ->> 'start'));
CREATE INDEX idx_encounter_status ON encounter ((resource ->> 'status'));
CREATE INDEX idx_encounter_type ON encounter USING GIN ((resource -> 'type') jsonb_path_ops);
```

### Index Maintenance

Regularly maintain indexes to ensure optimal performance.

```sql
-- Analyze tables to update statistics
ANALYZE patient;
ANALYZE observation;
ANALYZE encounter;
ANALYZE medicationrequest;
ANALYZE condition;

-- Rebuild indexes to remove fragmentation
REINDEX INDEX idx_patient_identifier;
REINDEX INDEX idx_observation_subject;
REINDEX INDEX idx_encounter_patient;
```

### Index Usage Monitoring

Monitor index usage to identify unused or inefficient indexes.

```sql
-- PostgreSQL query to identify unused indexes
SELECT
    schemaname || '.' || relname AS table,
    indexrelname AS index,
    pg_size_pretty(pg_relation_size(i.indexrelid)) AS index_size,
    idx_scan AS index_scans
FROM pg_stat_user_indexes ui
JOIN pg_index i ON ui.indexrelid = i.indexrelid
WHERE NOT indisunique AND idx_scan < 50
ORDER BY pg_relation_size(i.indexrelid) DESC;

-- PostgreSQL query to identify missing indexes
SELECT
    relname AS table,
    seq_scan - idx_scan AS too_much_seq,
    CASE
        WHEN seq_scan - idx_scan > 0 THEN 'Missing Index?'
        ELSE 'OK'
    END,
    pg_size_pretty(pg_relation_size(relid)) AS table_size,
    seq_scan, idx_scan
FROM pg_stat_user_tables
WHERE pg_relation_size(relid) > 80000
ORDER BY too_much_seq DESC;
```

## Query Patterns and Performance

Optimize database queries for common FHIR operations.

### Optimizing FHIR Search Queries

```sql
-- Efficient query for finding patients by name
-- Uses index on name and limits results
SELECT resource
FROM patient
WHERE resource -> 'name' @> '[{"family": "Smith"}]'
LIMIT 100;

-- Efficient query for finding observations for a patient
-- Uses index on subject reference
SELECT resource
FROM observation
WHERE resource -> 'subject' ->> 'reference' = 'Patient/123'
ORDER BY resource ->> 'effectiveDateTime' DESC
LIMIT 50;

-- Efficient query for finding active conditions with specific code
-- Uses indexes on clinical status and code
SELECT resource
FROM condition
WHERE resource ->> 'clinicalStatus' = 'active'
AND resource -> 'code' -> 'coding' @> '[{"system": "http://snomed.info/sct", "code": "73211009"}]'
LIMIT 100;
```

### Avoiding Common Query Anti-Patterns

| Anti-Pattern | Problem | Solution |
|--------------|---------|----------|
| Full table scans | Scanning entire table instead of using indexes | Create appropriate indexes for common search parameters |
| Inefficient joins | Joining large tables without proper indexes | Ensure join columns are indexed |
| Unbound queries | Queries without limits that return too many rows | Always use LIMIT clause or pagination |
| Complex JSON operations | Expensive operations on JSON/JSONB columns | Use appropriate JSON operators and indexes |

### Query Optimization Examples

```sql
-- Before: Inefficient query with full table scan
SELECT resource
FROM observation
WHERE resource::text LIKE '%diabetes%';

-- After: Optimized query using proper indexing
SELECT resource
FROM observation
WHERE resource -> 'code' -> 'coding' @> '[{"display": "diabetes"}]';

-- Before: Inefficient query with multiple conditions
SELECT resource
FROM patient
WHERE resource ->> 'birthDate' > '1970-01-01'
AND resource ->> 'gender' = 'male'
AND resource -> 'name' @> '[{"family": "Smith"}]';

-- After: Optimized query using most selective condition first
SELECT resource
FROM patient
WHERE resource -> 'name' @> '[{"family": "Smith"}]'
AND resource ->> 'gender' = 'male'
AND resource ->> 'birthDate' > '1970-01-01';
```

## Database Configuration for FHIR Workloads

Optimize database configuration settings for FHIR workloads.

### PostgreSQL Configuration for FHIR

```ini
# Memory settings
shared_buffers = 4GB          # 25% of available RAM, up to 8GB
work_mem = 64MB               # Increase for complex queries
maintenance_work_mem = 512MB  # Increase for maintenance operations
effective_cache_size = 12GB   # 50-75% of available RAM

# Write settings
wal_buffers = 16MB            # Increase for write-heavy workloads
checkpoint_completion_target = 0.9  # Spread out checkpoint writes
max_wal_size = 2GB            # Increase for write-heavy workloads

# Query optimization
random_page_cost = 1.1        # Lower for SSDs (default is 4.0)
effective_io_concurrency = 200  # Increase for SSDs

# Connection settings
max_connections = 200         # Adjust based on expected concurrent users

# Autovacuum settings
autovacuum = on
autovacuum_vacuum_scale_factor = 0.05  # More aggressive vacuuming
autovacuum_analyze_scale_factor = 0.025  # More aggressive analysis
```

### MySQL/MariaDB Configuration for FHIR

```ini
# Memory settings
innodb_buffer_pool_size = 4G   # 50-75% of available RAM
innodb_log_buffer_size = 64M    # Increase for write-heavy workloads

# InnoDB settings
innodb_flush_log_at_trx_commit = 2  # Better performance, slight durability trade-off
innodb_flush_method = O_DIRECT      # Bypass OS cache for direct disk I/O
innodb_file_per_table = 1           # Separate tablespace files

# Query cache (disable for high-concurrency workloads)
query_cache_type = 0
query_cache_size = 0

# Connection settings
max_connections = 200          # Adjust based on expected concurrent users
thread_cache_size = 16         # Cache for thread reuse

# Temporary tables
tmp_table_size = 64M
max_heap_table_size = 64M
```

### MongoDB Configuration for FHIR

```yaml
storage:
  wiredTiger:
    engineConfig:
      cacheSizeGB: 4  # 50% of available RAM
      journalCompressor: snappy
    collectionConfig:
      blockCompressor: snappy

operationProfiling:
  mode: slowOp
  slowOpThresholdMs: 100

net:
  maxIncomingConnections: 200

setParameter:
  maxTransactionLockRequestTimeoutMillis: 5000
  cursorTimeoutMillis: 600000
```

## Partitioning Strategies for Large Datasets

Implement partitioning to improve performance for large FHIR datasets.

### Partitioning by Resource Type

```sql
-- PostgreSQL partitioning by resource type
CREATE TABLE fhir_resources (
    id UUID PRIMARY KEY,
    resource_type VARCHAR(50) NOT NULL,
    resource JSONB NOT NULL,
    last_updated TIMESTAMP NOT NULL
) PARTITION BY LIST (resource_type);

-- Create partitions for common resource types
CREATE TABLE fhir_resources_patient PARTITION OF fhir_resources
    FOR VALUES IN ('Patient');

CREATE TABLE fhir_resources_observation PARTITION OF fhir_resources
    FOR VALUES IN ('Observation');

CREATE TABLE fhir_resources_encounter PARTITION OF fhir_resources
    FOR VALUES IN ('Encounter');

CREATE TABLE fhir_resources_condition PARTITION OF fhir_resources
    FOR VALUES IN ('Condition');

CREATE TABLE fhir_resources_medication_request PARTITION OF fhir_resources
    FOR VALUES IN ('MedicationRequest');

CREATE TABLE fhir_resources_other PARTITION OF fhir_resources
    DEFAULT;
```

### Partitioning by Date

```sql
-- PostgreSQL partitioning by date (for time-series data like Observations)
CREATE TABLE observations (
    id UUID PRIMARY KEY,
    patient_reference VARCHAR(100) NOT NULL,
    effective_date DATE NOT NULL,
    resource JSONB NOT NULL
) PARTITION BY RANGE (effective_date);

-- Create partitions by month
CREATE TABLE observations_2023_01 PARTITION OF observations
    FOR VALUES FROM ('2023-01-01') TO ('2023-02-01');

CREATE TABLE observations_2023_02 PARTITION OF observations
    FOR VALUES FROM ('2023-02-01') TO ('2023-03-01');

CREATE TABLE observations_2023_03 PARTITION OF observations
    FOR VALUES FROM ('2023-03-01') TO ('2023-04-01');

-- Create indexes on each partition
CREATE INDEX idx_observations_2023_01_patient ON observations_2023_01 (patient_reference);
CREATE INDEX idx_observations_2023_02_patient ON observations_2023_02 (patient_reference);
CREATE INDEX idx_observations_2023_03_patient ON observations_2023_03 (patient_reference);
```

### Partitioning by Patient ID

```sql
-- PostgreSQL partitioning by patient ID hash (for large patient populations)
CREATE TABLE patient_data (
    id UUID PRIMARY KEY,
    patient_id VARCHAR(100) NOT NULL,
    resource_type VARCHAR(50) NOT NULL,
    resource JSONB NOT NULL
) PARTITION BY HASH (patient_id);

-- Create 8 partitions by patient ID hash
CREATE TABLE patient_data_0 PARTITION OF patient_data
    FOR VALUES WITH (MODULUS 8, REMAINDER 0);

CREATE TABLE patient_data_1 PARTITION OF patient_data
    FOR VALUES WITH (MODULUS 8, REMAINDER 1);

-- ... create remaining partitions ...

CREATE TABLE patient_data_7 PARTITION OF patient_data
    FOR VALUES WITH (MODULUS 8, REMAINDER 7);

-- Create indexes on each partition
CREATE INDEX idx_patient_data_0_patient_resource ON patient_data_0 (patient_id, resource_type);
CREATE INDEX idx_patient_data_1_patient_resource ON patient_data_1 (patient_id, resource_type);
-- ... create remaining indexes ...
```

### Partition Maintenance

```sql
-- PostgreSQL partition maintenance

-- Add new date partition
CREATE TABLE observations_2023_04 PARTITION OF observations
    FOR VALUES FROM ('2023-04-01') TO ('2023-05-01');
CREATE INDEX idx_observations_2023_04_patient ON observations_2023_04 (patient_reference);

-- Detach old partition for archiving
ALTER TABLE observations DETACH PARTITION observations_2022_01;

-- Archive old partition
CREATE TABLE observations_archive_2022_01 AS SELECT * FROM observations_2022_01;

-- Drop old partition after archiving
DROP TABLE observations_2022_01;
```

## Conclusion

Optimizing your database for FHIR workloads is essential for achieving good performance and scalability. By implementing appropriate indexing strategies, optimizing queries, configuring your database properly, and using partitioning for large datasets, you can significantly improve the performance of your FHIR server.

Key takeaways:

1. Create appropriate indexes for common FHIR search parameters
2. Optimize database queries for efficient FHIR operations
3. Configure your database settings for FHIR workloads
4. Implement partitioning strategies for large FHIR datasets
5. Regularly maintain indexes and partitions for optimal performance

By following these guidelines, you can create a high-performance database foundation for your FHIR server implementation.
