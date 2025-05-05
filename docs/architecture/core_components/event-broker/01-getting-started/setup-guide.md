# Event Broker Setup Guide

## Introduction

This guide walks you through the process of setting up the Event Broker for the CMM Reference Architecture. It covers the installation and configuration of Confluent Kafka, the implementation of healthcare-specific event schemas, and the integration with other core components. By following these steps, you'll establish a robust foundation for event-driven healthcare applications that enable real-time data exchange and workflow automation.

The setup process is organized into logical sections that progress from basic infrastructure setup to advanced configuration. Each section builds upon the previous ones, allowing for incremental implementation and testing. While this guide provides a comprehensive approach, you can adapt it to your specific environment and requirements.

## Prerequisites

Before beginning the Event Broker setup process, ensure you have:

### Hardware Requirements

- **Development Environment**:
  - Minimum: 3 servers (16GB RAM, 4 vCPUs, 100GB SSD each)
  - Recommended: 5 servers (32GB RAM, 8 vCPUs, 250GB SSD each)

- **Production Environment**:
  - Minimum: 5 servers (32GB RAM, 8 vCPUs, 500GB SSD each)
  - Recommended: 9+ servers (64GB RAM, 16 vCPUs, 1TB SSD each)
  - Network: 10 Gbps between broker nodes

### Software Requirements

- **Operating System**: Linux (RHEL 8+, Ubuntu 20.04+, or similar)
- **Java**: OpenJDK 11 or later
- **Confluent Platform**: Version 7.0 or later
- **Docker**: Version 20.10 or later (for containerized deployment)
- **Kubernetes**: Version 1.21 or later (for cloud-native deployment)

### Network Requirements

- Dedicated subnet for Kafka cluster communication
- Open ports for Kafka (9092), ZooKeeper (2181), Schema Registry (8081)
- Network security groups configured for cluster communication
- Load balancer for client connectivity (optional but recommended)

### Security Prerequisites

- TLS certificates for encrypted communication
- Authentication credentials (LDAP, Kerberos, or mTLS)
- Access to security policies and compliance requirements
- Data classification guidelines for healthcare information

### Knowledge Prerequisites

- Basic understanding of event-driven architecture
- Familiarity with Linux system administration
- Knowledge of healthcare data formats (FHIR, HL7)
- Understanding of security and compliance requirements in healthcare

## Infrastructure Setup

This section covers the installation and configuration of the core Confluent Kafka infrastructure, including brokers, ZooKeeper, and supporting services. We'll provide instructions for both on-premises and cloud deployments.

### Deployment Options

Choose the deployment approach that best fits your environment:

#### Option 1: On-Premises Deployment

Traditional deployment on dedicated servers or virtual machines.

1. **Prepare Servers**
   ```bash
   # Update system packages
   sudo apt-get update && sudo apt-get upgrade -y
   
   # Install Java
   sudo apt-get install -y openjdk-11-jdk
   
   # Create Kafka user
   sudo useradd -r -d /opt/kafka -s /bin/false kafka
   
   # Create necessary directories
   sudo mkdir -p /opt/kafka /var/lib/kafka/data /var/log/kafka
   sudo chown -R kafka:kafka /opt/kafka /var/lib/kafka /var/log/kafka
   ```

2. **Download and Install Confluent Platform**
   ```bash
   # Download Confluent Platform
   curl -O https://packages.confluent.io/archive/7.0/confluent-7.0.1.tar.gz
   
   # Extract the archive
   sudo tar -xzf confluent-7.0.1.tar.gz -C /opt/kafka --strip-components=1
   sudo chown -R kafka:kafka /opt/kafka
   ```

3. **Configure ZooKeeper**
   
   Create `/opt/kafka/etc/kafka/zookeeper.properties`:
   ```properties
   # Basic ZooKeeper configuration
   dataDir=/var/lib/kafka/zookeeper
   clientPort=2181
   maxClientCnxns=0
   admin.enableServer=true
   admin.serverPort=9990
   
   # Cluster configuration (for multi-node setup)
   initLimit=5
   syncLimit=2
   server.1=zk1.example.com:2888:3888
   server.2=zk2.example.com:2888:3888
   server.3=zk3.example.com:2888:3888
   ```
   
   Create a myid file on each ZooKeeper node:
   ```bash
   # On first node (replace with appropriate ID for each node)
   echo "1" | sudo tee /var/lib/kafka/zookeeper/myid
   ```

4. **Configure Kafka Brokers**
   
   Create `/opt/kafka/etc/kafka/server.properties`:
   ```properties
   # Broker basics
   broker.id=1  # Unique for each broker
   listeners=PLAINTEXT://broker1.example.com:9092,INTERNAL://broker1.example.com:9093
   advertised.listeners=PLAINTEXT://broker1.example.com:9092
   listener.security.protocol.map=PLAINTEXT:PLAINTEXT,INTERNAL:PLAINTEXT
   inter.broker.listener.name=INTERNAL
   
   # Log configuration
   log.dirs=/var/lib/kafka/data
   num.partitions=8
   default.replication.factor=3
   min.insync.replicas=2
   
   # ZooKeeper configuration
   zookeeper.connect=zk1.example.com:2181,zk2.example.com:2181,zk3.example.com:2181
   
   # Topic deletion
   delete.topic.enable=true
   
   # Performance tuning
   num.network.threads=8
   num.io.threads=16
   socket.send.buffer.bytes=102400
   socket.receive.buffer.bytes=102400
   socket.request.max.bytes=104857600
   num.recovery.threads.per.data.dir=2
   
   # Log retention (adjust based on compliance requirements)
   log.retention.hours=168  # 7 days
   log.segment.bytes=1073741824
   log.retention.check.interval.ms=300000
   ```

5. **Create Systemd Service Files**
   
   Create `/etc/systemd/system/zookeeper.service`:
   ```ini
   [Unit]
   Description=Apache ZooKeeper
   Documentation=http://zookeeper.apache.org
   Requires=network.target remote-fs.target
   After=network.target remote-fs.target
   
   [Service]
   Type=simple
   User=kafka
   Group=kafka
   Environment="KAFKA_HEAP_OPTS=-Xmx2G -Xms2G"
   ExecStart=/opt/kafka/bin/zookeeper-server-start /opt/kafka/etc/kafka/zookeeper.properties
   ExecStop=/opt/kafka/bin/zookeeper-server-stop
   Restart=on-failure
   
   [Install]
   WantedBy=multi-user.target
   ```
   
   Create `/etc/systemd/system/kafka.service`:
   ```ini
   [Unit]
   Description=Apache Kafka
   Documentation=http://kafka.apache.org
   Requires=zookeeper.service
   After=zookeeper.service
   
   [Service]
   Type=simple
   User=kafka
   Group=kafka
   Environment="KAFKA_HEAP_OPTS=-Xmx8G -Xms8G"
   Environment="KAFKA_JVM_PERFORMANCE_OPTS=-server -XX:+UseG1GC -XX:MaxGCPauseMillis=20 -XX:InitiatingHeapOccupancyPercent=35 -XX:+ExplicitGCInvokesConcurrent -Djava.awt.headless=true"
   ExecStart=/opt/kafka/bin/kafka-server-start /opt/kafka/etc/kafka/server.properties
   ExecStop=/opt/kafka/bin/kafka-server-stop
   Restart=on-failure
   
   [Install]
   WantedBy=multi-user.target
   ```

6. **Start Services**
   ```bash
   # Reload systemd
   sudo systemctl daemon-reload
   
   # Enable and start ZooKeeper
   sudo systemctl enable zookeeper
   sudo systemctl start zookeeper
   
   # Enable and start Kafka
   sudo systemctl enable kafka
   sudo systemctl start kafka
   ```

7. **Verify Installation**
   ```bash
   # Check ZooKeeper status
   sudo systemctl status zookeeper
   
   # Check Kafka status
   sudo systemctl status kafka
   
   # Create a test topic
   /opt/kafka/bin/kafka-topics --create --topic test-topic --bootstrap-server localhost:9092 --partitions 3 --replication-factor 3
   
   # List topics
   /opt/kafka/bin/kafka-topics --list --bootstrap-server localhost:9092
   ```

#### Option 2: Containerized Deployment with Docker Compose

For development or smaller environments, Docker Compose provides a simpler setup.

1. **Create Docker Compose File**
   
   Create `docker-compose.yml`:
   ```yaml
   ---
   version: '3'
   services:
     zookeeper:
       image: confluentinc/cp-zookeeper:7.0.1
       hostname: zookeeper
       container_name: zookeeper
       ports:
         - "2181:2181"
       environment:
         ZOOKEEPER_CLIENT_PORT: 2181
         ZOOKEEPER_TICK_TIME: 2000
       volumes:
         - ./data/zookeeper/data:/var/lib/zookeeper/data
         - ./data/zookeeper/log:/var/lib/zookeeper/log
       healthcheck:
         test: ["CMD", "bash", "-c", "echo ruok | nc localhost 2181 | grep imok"]
         interval: 10s
         timeout: 5s
         retries: 5
   
     broker1:
       image: confluentinc/cp-server:7.0.1
       hostname: broker1
       container_name: broker1
       depends_on:
         - zookeeper
       ports:
         - "9092:9092"
         - "9101:9101"
       environment:
         KAFKA_BROKER_ID: 1
         KAFKA_ZOOKEEPER_CONNECT: 'zookeeper:2181'
         KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT
         KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://broker1:29092,PLAINTEXT_HOST://localhost:9092
         KAFKA_METRIC_REPORTERS: io.confluent.metrics.reporter.ConfluentMetricsReporter
         KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
         KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS: 0
         KAFKA_CONFLUENT_LICENSE_TOPIC_REPLICATION_FACTOR: 1
         KAFKA_CONFLUENT_BALANCER_TOPIC_REPLICATION_FACTOR: 1
         KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: 1
         KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: 1
         KAFKA_JMX_PORT: 9101
         KAFKA_JMX_HOSTNAME: localhost
         CONFLUENT_METRICS_REPORTER_BOOTSTRAP_SERVERS: broker1:29092
         CONFLUENT_METRICS_REPORTER_TOPIC_REPLICAS: 1
         CONFLUENT_METRICS_ENABLE: 'true'
         CONFLUENT_SUPPORT_CUSTOMER_ID: 'anonymous'
       volumes:
         - ./data/broker1/data:/var/lib/kafka/data
   
     schema-registry:
       image: confluentinc/cp-schema-registry:7.0.1
       hostname: schema-registry
       container_name: schema-registry
       depends_on:
         - broker1
       ports:
         - "8081:8081"
       environment:
         SCHEMA_REGISTRY_HOST_NAME: schema-registry
         SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS: 'broker1:29092'
         SCHEMA_REGISTRY_LISTENERS: http://0.0.0.0:8081
   
     connect:
       image: confluentinc/cp-kafka-connect:7.0.1
       hostname: connect
       container_name: connect
       depends_on:
         - broker1
         - schema-registry
       ports:
         - "8083:8083"
       environment:
         CONNECT_BOOTSTRAP_SERVERS: 'broker1:29092'
         CONNECT_REST_ADVERTISED_HOST_NAME: connect
         CONNECT_REST_PORT: 8083
         CONNECT_GROUP_ID: compose-connect-group
         CONNECT_CONFIG_STORAGE_TOPIC: docker-connect-configs
         CONNECT_CONFIG_STORAGE_REPLICATION_FACTOR: 1
         CONNECT_OFFSET_FLUSH_INTERVAL_MS: 10000
         CONNECT_OFFSET_STORAGE_TOPIC: docker-connect-offsets
         CONNECT_OFFSET_STORAGE_REPLICATION_FACTOR: 1
         CONNECT_STATUS_STORAGE_TOPIC: docker-connect-status
         CONNECT_STATUS_STORAGE_REPLICATION_FACTOR: 1
         CONNECT_KEY_CONVERTER: org.apache.kafka.connect.storage.StringConverter
         CONNECT_VALUE_CONVERTER: io.confluent.connect.avro.AvroConverter
         CONNECT_VALUE_CONVERTER_SCHEMA_REGISTRY_URL: http://schema-registry:8081
         CONNECT_PLUGIN_PATH: "/usr/share/java,/usr/share/confluent-hub-components"
         CONNECT_LOG4J_LOGGERS: org.apache.zookeeper=ERROR,org.I0Itec.zkclient=ERROR,org.reflections=ERROR
   
     control-center:
       image: confluentinc/cp-enterprise-control-center:7.0.1
       hostname: control-center
       container_name: control-center
       depends_on:
         - broker1
         - schema-registry
         - connect
       ports:
         - "9021:9021"
       environment:
         CONTROL_CENTER_BOOTSTRAP_SERVERS: 'broker1:29092'
         CONTROL_CENTER_CONNECT_CONNECT-DEFAULT_CLUSTER: 'connect:8083'
         CONTROL_CENTER_SCHEMA_REGISTRY_URL: "http://schema-registry:8081"
         CONTROL_CENTER_REPLICATION_FACTOR: 1
         CONTROL_CENTER_INTERNAL_TOPICS_PARTITIONS: 1
         CONTROL_CENTER_MONITORING_INTERCEPTOR_TOPIC_PARTITIONS: 1
         CONFLUENT_METRICS_TOPIC_REPLICATION: 1
         PORT: 9021
   ```

2. **Start the Containers**
   ```bash
   # Create data directories
   mkdir -p data/zookeeper/data data/zookeeper/log data/broker1/data
   
   # Start the containers
   docker-compose up -d
   ```

3. **Verify Installation**
   ```bash
   # Check container status
   docker-compose ps
   
   # Create a test topic
   docker-compose exec broker1 kafka-topics --create --topic test-topic --bootstrap-server broker1:29092 --partitions 1 --replication-factor 1
   
   # List topics
   docker-compose exec broker1 kafka-topics --list --bootstrap-server broker1:29092
   ```

4. **Access Control Center**
   
   Open a web browser and navigate to `http://localhost:9021` to access the Confluent Control Center interface.

#### Option 3: Kubernetes Deployment with Confluent Operator

For production-grade, cloud-native deployments, use the Confluent Operator on Kubernetes.

1. **Install Helm**
   ```bash
   curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
   ```

2. **Add Confluent Helm Repository**
   ```bash
   helm repo add confluentinc https://packages.confluent.io/helm
   helm repo update
   ```

3. **Create Namespace**
   ```bash
   kubectl create namespace kafka
   ```

4. **Install Confluent Operator**
   ```bash
   helm install operator confluentinc/confluent-operator --namespace kafka
   ```

5. **Create Configuration File**
   
   Create `values.yaml`:
   ```yaml
   ---
   global:
     provider:
       name: aws  # or azure, gcp
       region: us-east-1
       kubernetes:
         deployment:
           zones:
             - us-east-1a
             - us-east-1b
             - us-east-1c
         storage:
           provisioner: kubernetes.io/aws-ebs
           reclaimPolicy: Delete
   
   zookeeper:
     replicas: 3
     resources:
       requests:
         cpu: 200m
         memory: 512Mi
   
   kafka:
     replicas: 3
     resources:
       requests:
         cpu: 1000m
         memory: 4Gi
     loadBalancer:
       enabled: true
       domain: example.com
     tls:
       enabled: true
     metricReporter:
       enabled: true
   
   schemaRegistry:
     replicas: 2
     tls:
       enabled: true
   
   connect:
     replicas: 2
     tls:
       enabled: true
     loadBalancer:
       enabled: true
   
   controlcenter:
     replicas: 1
     resources:
       requests:
         cpu: 1000m
         memory: 4Gi
     loadBalancer:
       enabled: true
       domain: example.com
     tls:
       enabled: true
   ```

6. **Deploy Confluent Platform**
   ```bash
   helm install confluent-platform confluentinc/confluent-for-kubernetes --values values.yaml --namespace kafka
   ```

7. **Verify Deployment**
   ```bash
   # Check pod status
   kubectl get pods -n kafka
   
   # Check services
   kubectl get services -n kafka
   ```

8. **Access Control Center**
   
   Get the Control Center URL:
   ```bash
   kubectl get service controlcenter -n kafka
   ```
   
   Access the Control Center using the external IP or domain name.

### Schema Registry Setup

The Schema Registry is essential for maintaining data quality and compatibility in healthcare event streams.

1. **Configure Schema Registry** (for on-premises deployment)
   
   Create `/opt/kafka/etc/schema-registry/schema-registry.properties`:
   ```properties
   # Schema Registry configuration
   listeners=http://0.0.0.0:8081
   host.name=schema-registry.example.com
   
   # Kafka bootstrap servers
   kafkastore.bootstrap.servers=PLAINTEXT://broker1.example.com:9092,PLAINTEXT://broker2.example.com:9092,PLAINTEXT://broker3.example.com:9092
   
   # Topic for storing schemas
   kafkastore.topic=_schemas
   
   # Schema compatibility settings
   schema.compatibility.level=FORWARD
   ```

2. **Create Systemd Service File** (for on-premises deployment)
   
   Create `/etc/systemd/system/schema-registry.service`:
   ```ini
   [Unit]
   Description=Confluent Schema Registry
   Documentation=http://docs.confluent.io/
   Requires=network.target
   After=network.target kafka.service
   
   [Service]
   Type=simple
   User=kafka
   Group=kafka
   Environment="SCHEMA_REGISTRY_HEAP_OPTS=-Xmx1G -Xms1G"
   ExecStart=/opt/kafka/bin/schema-registry-start /opt/kafka/etc/schema-registry/schema-registry.properties
   ExecStop=/opt/kafka/bin/schema-registry-stop
   Restart=on-failure
   
   [Install]
   WantedBy=multi-user.target
   ```

3. **Start Schema Registry** (for on-premises deployment)
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable schema-registry
   sudo systemctl start schema-registry
   ```

4. **Verify Schema Registry**
   ```bash
   # Check status
   curl -X GET http://localhost:8081/subjects
   
   # Should return an empty array: []
   ```

### Kafka Connect Setup

Kafka Connect enables integration with external systems, crucial for healthcare data integration.

1. **Configure Kafka Connect** (for on-premises deployment)
   
   Create `/opt/kafka/etc/kafka/connect-distributed.properties`:
   ```properties
   # Basic configuration
   bootstrap.servers=broker1.example.com:9092,broker2.example.com:9092,broker3.example.com:9092
   group.id=connect-cluster
   
   # REST interface
   rest.host.name=connect.example.com
   rest.port=8083
   
   # Converters
   key.converter=org.apache.kafka.connect.storage.StringConverter
   value.converter=io.confluent.connect.avro.AvroConverter
   value.converter.schema.registry.url=http://schema-registry.example.com:8081
   
   # Internal topics for storing connector state
   config.storage.topic=connect-configs
   offset.storage.topic=connect-offsets
   status.storage.topic=connect-status
   
   # Internal topic configuration
   config.storage.replication.factor=3
   offset.storage.replication.factor=3
   status.storage.replication.factor=3
   
   # Plugin path for connectors
   plugin.path=/opt/kafka/share/java,/opt/connectors
   ```

2. **Install Healthcare Connectors**
   ```bash
   # Create connectors directory
   sudo mkdir -p /opt/connectors
   sudo chown kafka:kafka /opt/connectors
   
   # Install Confluent Hub Client
   sudo apt-get install -y confluent-hub-client
   
   # Install JDBC Connector (for database integration)
   sudo confluent-hub install --no-prompt confluentinc/kafka-connect-jdbc:10.2.2
   
   # Install HTTP Connector (for API integration)
   sudo confluent-hub install --no-prompt confluentinc/kafka-connect-http:1.5.0
   
   # Install HL7 Connector (for healthcare integration)
   # Note: This is an example, actual connector may vary
   sudo confluent-hub install --no-prompt example/kafka-connect-hl7:1.0.0
   ```

3. **Create Systemd Service File** (for on-premises deployment)
   
   Create `/etc/systemd/system/kafka-connect.service`:
   ```ini
   [Unit]
   Description=Kafka Connect
   Documentation=http://docs.confluent.io/
   Requires=network.target kafka.service
   After=network.target kafka.service
   
   [Service]
   Type=simple
   User=kafka
   Group=kafka
   Environment="KAFKA_HEAP_OPTS=-Xmx2G -Xms2G"
   ExecStart=/opt/kafka/bin/connect-distributed /opt/kafka/etc/kafka/connect-distributed.properties
   Restart=on-failure
   
   [Install]
   WantedBy=multi-user.target
   ```

4. **Start Kafka Connect** (for on-premises deployment)
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable kafka-connect
   sudo systemctl start kafka-connect
   ```

5. **Verify Kafka Connect**
   ```bash
   # Check status
   curl -X GET http://localhost:8083/connectors
   
   # Should return an empty array: []
   ```

### Confluent Control Center Setup

Control Center provides a web-based interface for managing and monitoring the Kafka ecosystem.

1. **Configure Control Center** (for on-premises deployment)
   
   Create `/opt/kafka/etc/confluent-control-center/control-center.properties`:
   ```properties
   # Basic configuration
   bootstrap.servers=broker1.example.com:9092,broker2.example.com:9092,broker3.example.com:9092
   zookeeper.connect=zk1.example.com:2181,zk2.example.com:2181,zk3.example.com:2181
   
   # Confluent Control Center configuration
   confluent.controlcenter.id=1
   confluent.controlcenter.data.dir=/var/lib/confluent/control-center
   
   # Web UI
   confluent.controlcenter.rest.listeners=http://0.0.0.0:9021
   
   # Connect cluster
   confluent.controlcenter.connect.cluster=http://connect.example.com:8083
   
   # Schema Registry
   confluent.controlcenter.schema.registry.url=http://schema-registry.example.com:8081
   
   # Internal topics
   confluent.controlcenter.internal.topics.replication=3
   confluent.controlcenter.command.topic.replication=3
   confluent.metrics.topic.replication=3
   
   # License
   confluent.license=<your-license-here>  # Optional, for Confluent Platform Enterprise
   ```

2. **Create Systemd Service File** (for on-premises deployment)
   
   Create `/etc/systemd/system/control-center.service`:
   ```ini
   [Unit]
   Description=Confluent Control Center
   Documentation=http://docs.confluent.io/
   Requires=network.target kafka.service
   After=network.target kafka.service
   
   [Service]
   Type=simple
   User=kafka
   Group=kafka
   Environment="CONTROL_CENTER_HEAP_OPTS=-Xmx6G -Xms6G"
   ExecStart=/opt/kafka/bin/control-center-start /opt/kafka/etc/confluent-control-center/control-center.properties
   ExecStop=/opt/kafka/bin/control-center-stop
   Restart=on-failure
   
   [Install]
   WantedBy=multi-user.target
   ```

3. **Start Control Center** (for on-premises deployment)
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable control-center
   sudo systemctl start control-center
   ```

4. **Access Control Center**
   
   Open a web browser and navigate to `http://control-center.example.com:9021` or the appropriate URL for your environment.

## Security Configuration

This section covers the security configuration of your Event Broker deployment, including authentication, authorization, encryption, and audit logging. Proper security is essential for protecting sensitive healthcare data and meeting compliance requirements.

### Authentication Setup

Authentication verifies the identity of clients connecting to the Kafka cluster.

#### SASL/SCRAM Authentication

SASL/SCRAM provides username/password authentication with salted passwords.

1. **Configure Broker Properties**
   
   Update `/opt/kafka/etc/kafka/server.properties` on each broker:
   ```properties
   # Enable SASL authentication
   listeners=SASL_PLAINTEXT://broker1.example.com:9092,SASL_SSL://broker1.example.com:9093
   advertised.listeners=SASL_PLAINTEXT://broker1.example.com:9092,SASL_SSL://broker1.example.com:9093
   listener.security.protocol.map=SASL_PLAINTEXT:SASL_PLAINTEXT,SASL_SSL:SASL_SSL
   inter.broker.listener.name=SASL_PLAINTEXT
   
   # SASL configuration
   sasl.enabled.mechanisms=SCRAM-SHA-512
   sasl.mechanism.inter.broker.protocol=SCRAM-SHA-512
   ```

2. **Create JAAS Configuration**
   
   Create `/opt/kafka/etc/kafka/kafka_server_jaas.conf`:
   ```
   KafkaServer {
     org.apache.kafka.common.security.scram.ScramLoginModule required
     username="admin"
     password="admin-secret";
   };
   ```

3. **Set Environment Variable**
   
   Update `/etc/systemd/system/kafka.service`:
   ```ini
   [Service]
   # Add this line to the Service section
   Environment="KAFKA_OPTS=-Djava.security.auth.login.config=/opt/kafka/etc/kafka/kafka_server_jaas.conf"
   ```

4. **Create Users**
   ```bash
   # Create admin user
   /opt/kafka/bin/kafka-configs --bootstrap-server localhost:9092 
     --alter --add-config 'SCRAM-SHA-512=[password=admin-secret]' 
     --entity-type users --entity-name admin
   
   # Create application users
   /opt/kafka/bin/kafka-configs --bootstrap-server localhost:9092 
     --alter --add-config 'SCRAM-SHA-512=[password=app1-secret]' 
     --entity-type users --entity-name app1
   ```

5. **Configure Client Properties**
   
   Create a client properties file for applications:
   ```properties
   # SASL configuration
   security.protocol=SASL_PLAINTEXT
   sasl.mechanism=SCRAM-SHA-512
   sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="app1" password="app1-secret";
   ```

#### OAuth 2.0 Authentication with Security Framework

Integrate with the Security and Access Framework for OAuth-based authentication.

1. **Install OAuth Plugin**
   ```bash
   # Download OAuth plugin
   curl -O https://github.com/confluentinc/kafka-oauth/releases/download/v0.6.0/kafka-oauth-0.6.0.tar.gz
   
   # Extract to Kafka libs directory
   sudo tar -xzf kafka-oauth-0.6.0.tar.gz -C /opt/kafka/libs/
   ```

2. **Configure OAuth in Broker Properties**
   
   Update `/opt/kafka/etc/kafka/server.properties`:
   ```properties
   # OAuth configuration
   listeners=OAUTHBEARER://broker1.example.com:9092,SASL_SSL://broker1.example.com:9093
   advertised.listeners=OAUTHBEARER://broker1.example.com:9092,SASL_SSL://broker1.example.com:9093
   listener.security.protocol.map=OAUTHBEARER:SASL_PLAINTEXT,SASL_SSL:SASL_SSL
   inter.broker.listener.name=OAUTHBEARER
   
   # SASL configuration
   sasl.enabled.mechanisms=OAUTHBEARER
   sasl.mechanism.inter.broker.protocol=OAUTHBEARER
   ```

3. **Create JAAS Configuration for OAuth**
   
   Create `/opt/kafka/etc/kafka/kafka_server_jaas.conf`:
   ```
   KafkaServer {
     org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required
     oauth.client.id="kafka-broker"
     oauth.client.secret="broker-secret"
     oauth.token.endpoint.uri="https://auth.example.com/oauth2/token"
     oauth.jwks.endpoint.uri="https://auth.example.com/oauth2/jwks"
     oauth.scope="kafka"
     oauth.audience="kafka-cluster";
   };
   ```

4. **Configure Client Properties for OAuth**
   
   Create a client properties file for applications:
   ```properties
   # OAuth configuration
   security.protocol=SASL_PLAINTEXT
   sasl.mechanism=OAUTHBEARER
   sasl.jaas.config=org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required 
     oauth.client.id="kafka-client" 
     oauth.client.secret="client-secret" 
     oauth.token.endpoint.uri="https://auth.example.com/oauth2/token" 
     oauth.scope="kafka" 
     oauth.audience="kafka-cluster";
   sasl.login.callback.handler.class=org.apache.kafka.common.security.oauthbearer.secured.OAuthBearerLoginCallbackHandler;
   ```

### Authorization Configuration

Authorization controls what operations authenticated clients can perform.

#### ACL-Based Authorization

1. **Enable ACLs in Broker Properties**
   
   Update `/opt/kafka/etc/kafka/server.properties`:
   ```properties
   # Enable ACL authorization
   authorizer.class.name=kafka.security.authorizer.AclAuthorizer
   
   # Allow Super Users
   super.users=User:admin;User:kafka
   ```

2. **Create ACLs for Applications**
   ```bash
   # Allow app1 to read from a topic
   /opt/kafka/bin/kafka-acls --bootstrap-server localhost:9092 
     --command-config admin-client.properties 
     --add --allow-principal User:app1 
     --operation Read --topic patient-events
   
   # Allow app1 to write to a topic
   /opt/kafka/bin/kafka-acls --bootstrap-server localhost:9092 
     --command-config admin-client.properties 
     --add --allow-principal User:app1 
     --operation Write --topic patient-events
   
   # Allow app1 to join a consumer group
   /opt/kafka/bin/kafka-acls --bootstrap-server localhost:9092 
     --command-config admin-client.properties 
     --add --allow-principal User:app1 
     --operation Read --group patient-processor
   ```

3. **Create Healthcare-Specific ACLs**
   ```bash
   # Clinical data access - restricted to clinical applications
   /opt/kafka/bin/kafka-acls --bootstrap-server localhost:9092 
     --command-config admin-client.properties 
     --add --allow-principal User:clinical-app 
     --operation Read --topic clinical-data
   
   # Administrative data access - available to billing applications
   /opt/kafka/bin/kafka-acls --bootstrap-server localhost:9092 
     --command-config admin-client.properties 
     --add --allow-principal User:billing-app 
     --operation Read --topic billing-events
   ```

### Encryption Configuration

Encryption protects data in transit and at rest.

#### TLS Encryption for In-Transit Data

1. **Generate SSL Certificates**
   ```bash
   # Create a directory for certificates
   mkdir -p /opt/kafka/ssl
   cd /opt/kafka/ssl
   
   # Create a CA key and certificate
   openssl req -new -x509 -keyout ca-key -out ca-cert -days 365 -subj "/CN=Kafka-CA/OU=Healthcare/O=Example/L=City/ST=State/C=US" -nodes
   
   # Create a keystore for each broker
   keytool -keystore kafka.broker1.keystore.jks -alias broker1 -validity 365 -genkey -keyalg RSA 
     -dname "CN=broker1.example.com, OU=Healthcare, O=Example, L=City, ST=State, C=US" 
     -storepass kafka-password -keypass kafka-password
   
   # Export the certificate from the keystore
   keytool -keystore kafka.broker1.keystore.jks -alias broker1 -certreq -file broker1.csr 
     -storepass kafka-password -keypass kafka-password
   
   # Sign the certificate with the CA
   openssl x509 -req -CA ca-cert -CAkey ca-key -in broker1.csr -out broker1-signed.crt 
     -days 365 -CAcreateserial
   
   # Import the CA certificate into the keystore
   keytool -keystore kafka.broker1.keystore.jks -alias CARoot -import -file ca-cert 
     -storepass kafka-password -keypass kafka-password -noprompt
   
   # Import the signed certificate into the keystore
   keytool -keystore kafka.broker1.keystore.jks -alias broker1 -import -file broker1-signed.crt 
     -storepass kafka-password -keypass kafka-password -noprompt
   
   # Create a truststore for clients
   keytool -keystore kafka.truststore.jks -alias CARoot -import -file ca-cert 
     -storepass kafka-password -keypass kafka-password -noprompt
   ```

2. **Configure SSL in Broker Properties**
   
   Update `/opt/kafka/etc/kafka/server.properties`:
   ```properties
   # SSL configuration
   listeners=SSL://broker1.example.com:9093,SASL_SSL://broker1.example.com:9094
   advertised.listeners=SSL://broker1.example.com:9093,SASL_SSL://broker1.example.com:9094
   listener.security.protocol.map=SSL:SSL,SASL_SSL:SASL_SSL
   inter.broker.listener.name=SSL
   
   # SSL keystore configuration
   ssl.keystore.location=/opt/kafka/ssl/kafka.broker1.keystore.jks
   ssl.keystore.password=kafka-password
   ssl.key.password=kafka-password
   ssl.truststore.location=/opt/kafka/ssl/kafka.truststore.jks
   ssl.truststore.password=kafka-password
   
   # SSL client authentication
   ssl.client.auth=required
   ```

3. **Configure Client Properties for SSL**
   
   Create a client properties file for applications:
   ```properties
   # SSL configuration
   security.protocol=SSL
   ssl.truststore.location=/path/to/kafka.truststore.jks
   ssl.truststore.password=kafka-password
   
   # For mutual TLS
   ssl.keystore.location=/path/to/client.keystore.jks
   ssl.keystore.password=client-password
   ssl.key.password=client-password
   ```

#### Encryption for Data at Rest

1. **Configure Disk Encryption**
   
   For Linux systems, use LUKS (Linux Unified Key Setup) to encrypt Kafka data directories:
   ```bash
   # Create an encrypted volume
   sudo cryptsetup luksFormat /dev/sdb
   
   # Open the encrypted volume
   sudo cryptsetup luksOpen /dev/sdb kafka-data
   
   # Create a file system
   sudo mkfs.ext4 /dev/mapper/kafka-data
   
   # Mount the volume
   sudo mount /dev/mapper/kafka-data /var/lib/kafka/data
   
   # Update fstab for persistence
   echo "/dev/mapper/kafka-data /var/lib/kafka/data ext4 defaults 0 0" | sudo tee -a /etc/fstab
   ```

2. **Configure Automatic Unlocking**
   
   Create a key file for automatic unlocking:
   ```bash
   # Create a key file
   sudo dd if=/dev/urandom of=/root/kafka-keyfile bs=1024 count=4
   sudo chmod 0400 /root/kafka-keyfile
   
   # Add the key to LUKS
   sudo cryptsetup luksAddKey /dev/sdb /root/kafka-keyfile
   
   # Update crypttab
   echo "kafka-data /dev/sdb /root/kafka-keyfile luks" | sudo tee -a /etc/crypttab
   ```

### Audit Logging Configuration

Audit logging tracks access and operations for compliance and security monitoring.

1. **Configure Broker Logging**
   
   Update `/opt/kafka/etc/kafka/log4j.properties`:
   ```properties
   # Audit logging configuration
   log4j.appender.AUDIT=org.apache.log4j.RollingFileAppender
   log4j.appender.AUDIT.File=${kafka.logs.dir}/kafka-audit.log
   log4j.appender.AUDIT.layout=org.apache.log4j.PatternLayout
   log4j.appender.AUDIT.layout.ConversionPattern=[%d] %p %m (%c)%n
   log4j.appender.AUDIT.MaxFileSize=100MB
   log4j.appender.AUDIT.MaxBackupIndex=10
   
   # Audit logger
   log4j.logger.kafka.authorizer.logger=INFO, AUDIT
   log4j.additivity.kafka.authorizer.logger=false
   ```

2. **Enable Request Logging**
   
   Update `/opt/kafka/etc/kafka/server.properties`:
   ```properties
   # Request logging
   request.timeout.ms=30000
   log.message.timestamp.type=LogAppendTime
   log.message.timestamp.difference.max.ms=5000
   ```

3. **Configure Centralized Logging**
   
   Install and configure Filebeat to ship logs to a central logging system:
   ```yaml
   # /etc/filebeat/filebeat.yml
   filebeat.inputs:
   - type: log
     enabled: true
     paths:
       - /var/log/kafka/kafka-audit.log
     fields:
       type: kafka-audit
       environment: production
     fields_under_root: true
     json.keys_under_root: true
     json.add_error_key: true
   
   output.elasticsearch:
     hosts: ["elasticsearch.example.com:9200"]
     index: "kafka-audit-%{+yyyy.MM.dd}"
   ```

### Healthcare-Specific Security Considerations

1. **PHI Data Classification**
   
   Create a topic naming convention for PHI data:
   ```bash
   # Create topics with PHI classification
   /opt/kafka/bin/kafka-topics --create --topic phi.patient-demographics 
     --bootstrap-server localhost:9092 --partitions 3 --replication-factor 3
   
   # Create topics with de-identified data
   /opt/kafka/bin/kafka-topics --create --topic deidentified.research-data 
     --bootstrap-server localhost:9092 --partitions 3 --replication-factor 3
   ```

2. **Data Masking for PHI**
   
   Implement data masking for sensitive fields using Kafka Streams:
   ```java
   // Example Kafka Streams application for data masking
   StreamsBuilder builder = new StreamsBuilder();
   
   // Create a stream from the source topic
   KStream<String, PatientRecord> patientStream = builder.stream(
       "phi.patient-demographics",
       Consumed.with(Serdes.String(), patientRecordSerde)
   );
   
   // Apply masking to sensitive fields
   KStream<String, PatientRecord> maskedStream = patientStream.mapValues(record -> {
       // Create a copy of the record with masked fields
       PatientRecord maskedRecord = new PatientRecord();
       maskedRecord.setPatientId(record.getPatientId());  // Keep the ID
       maskedRecord.setName(maskName(record.getName()));  // Mask the name
       maskedRecord.setDateOfBirth(maskDateOfBirth(record.getDateOfBirth()));  // Mask DOB
       maskedRecord.setZipCode(maskZipCode(record.getZipCode()));  // Mask ZIP code
       return maskedRecord;
   });
   
   // Write the masked data to a new topic
   maskedStream.to(
       "deidentified.research-data",
       Produced.with(Serdes.String(), patientRecordSerde)
   );
   ```

3. **Consent Management**
   
   Implement consent-based access control using Kafka Streams:
   ```java
   // Example Kafka Streams application for consent management
   StreamsBuilder builder = new StreamsBuilder();
   
   // Create a stream from the source topic
   KStream<String, PatientData> patientDataStream = builder.stream(
       "phi.patient-data",
       Consumed.with(Serdes.String(), patientDataSerde)
   );
   
   // Create a table of patient consents
   KTable<String, PatientConsent> consentTable = builder.table(
       "patient-consents",
       Consumed.with(Serdes.String(), patientConsentSerde)
   );
   
   // Join data with consents and filter based on consent
   KStream<String, PatientDataWithConsent> consentFilteredStream = patientDataStream
       .join(
           consentTable,
           (data, consent) -> new PatientDataWithConsent(data, consent),
           Joined.with(Serdes.String(), patientDataSerde, patientConsentSerde)
       )
       .filter((patientId, dataWithConsent) -> 
           // Only include records where consent is granted
           dataWithConsent.getConsent().isDataSharingConsent()
       );
   
   // Write the filtered data to a new topic
   consentFilteredStream.to(
       "consented.patient-data",
       Produced.with(Serdes.String(), patientDataWithConsentSerde)
   );
   ```

## Topic Design and Management

This section covers the essential topic configuration for healthcare event streams. Proper topic design is critical for organizing healthcare data and ensuring appropriate scaling and retention.

### Basic Topic Creation

1. **Create Healthcare Domain Topics**
   ```bash
   # Clinical events topic
   /opt/kafka/bin/kafka-topics --create --topic clinical-events \
     --bootstrap-server localhost:9092 \
     --partitions 8 --replication-factor 3 \
     --config retention.ms=604800000 \
     --config cleanup.policy=delete
   
   # Patient demographics topic
   /opt/kafka/bin/kafka-topics --create --topic patient-demographics \
     --bootstrap-server localhost:9092 \
     --partitions 4 --replication-factor 3 \
     --config retention.ms=1209600000 \
     --config cleanup.policy=compact
   
   # Medication events topic
   /opt/kafka/bin/kafka-topics --create --topic medication-events \
     --bootstrap-server localhost:9092 \
     --partitions 6 --replication-factor 3 \
     --config retention.ms=604800000 \
     --config cleanup.policy=delete
   ```

2. **Verify Topic Creation**
   ```bash
   # List all topics
   /opt/kafka/bin/kafka-topics --list --bootstrap-server localhost:9092
   
   # Describe a specific topic
   /opt/kafka/bin/kafka-topics --describe --topic clinical-events \
     --bootstrap-server localhost:9092
   ```

### Configure Topic Settings

1. **Update Topic Configurations**
   ```bash
   # Increase retention for clinical events
   /opt/kafka/bin/kafka-configs --bootstrap-server localhost:9092 \
     --alter --entity-type topics --entity-name clinical-events \
     --add-config retention.ms=1209600000
   
   # Set cleanup policy for reference data
   /opt/kafka/bin/kafka-configs --bootstrap-server localhost:9092 \
     --alter --entity-type topics --entity-name reference-data \
     --add-config cleanup.policy=compact
   ```

2. **Configure Topic Partitioning**
   ```bash
   # Increase partitions for a high-volume topic
   /opt/kafka/bin/kafka-topics --bootstrap-server localhost:9092 \
     --alter --topic medication-events --partitions 12
   ```

## Next Steps

Now that you have completed the basic setup of your Event Broker, you can:

1. Review the [Event Schemas](../02-core-functionality/event-schemas.md) documentation for healthcare data modeling
2. Explore [Stream Processing](../03-advanced-patterns/stream-processing.md) for real-time data transformation
3. Learn about [Connectors](../02-core-functionality/connectors.md) for integrating with healthcare systems

## Troubleshooting

### Common Issues

1. **Connection Problems**
   - Verify network connectivity between clients and brokers
   - Check firewall rules for required ports (9092, 2181, 8081)
   - Ensure DNS resolution is working correctly

2. **Authentication Failures**
   - Verify credentials in client configuration
   - Check that JAAS configuration is correct
   - Ensure SSL certificates are valid and trusted

3. **Performance Issues**
   - Monitor broker CPU, memory, and disk usage
   - Check for adequate disk space in data directories
   - Verify that JVM heap size is appropriately configured

### Diagnostic Commands

```bash
# Check broker status
sudo systemctl status kafka

# View broker logs
sudo tail -f /var/log/kafka/server.log

# Test producer functionality
/opt/kafka/bin/kafka-console-producer --bootstrap-server localhost:9092 \
  --topic test-topic

# Test consumer functionality
/opt/kafka/bin/kafka-console-consumer --bootstrap-server localhost:9092 \
  --topic test-topic --from-beginning
```

## Resources

- [Confluent Kafka Documentation](https://docs.confluent.io/)
- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [Kafka Monitoring Tools](https://docs.confluent.io/platform/current/control-center/index.html)
- [Healthcare Integration Patterns](https://www.confluent.io/blog/apache-kafka-for-healthcare-use-cases/)
