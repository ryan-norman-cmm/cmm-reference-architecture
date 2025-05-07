# Federated Graph API Extension Points

## Introduction
This document outlines the extension points provided by the Federated Graph API. These extension points enable developers to extend and integrate the Federated Graph API's functionality to meet specific business needs, adapt to different environments, and implement custom behaviors. Unlike basic customization options, extension points represent deeper integration possibilities that involve writing custom code, implementing interfaces, or modifying the Federated Graph API's behavior through well-defined hooks and plugins.

## Available Extension Points

### Router Extensions

#### Custom Router Plugins

The Federated Graph API allows you to implement custom router plugins to extend Apollo Router functionality for monitoring, logging, security, and request/response handling.

**When to Use**:
- When you need to add custom request validation logic
- To implement custom authentication or authorization mechanisms
- For enhanced logging or monitoring requirements
- To implement advanced rate limiting or traffic management
- When you need to modify requests or responses globally

**Implementation Example**:

```typescript
import { Plugin } from '@apollo/server';
import { ApolloGateway } from '@apollo/gateway';

// Custom router plugin implementation
export class CustomHealthcarePlugin implements Plugin {
  private readonly trackingEnabled: boolean;
  private readonly sensitiveFieldPatterns: RegExp[];
  
  constructor(config) {
    // Initialize properties
    this.trackingEnabled = config.trackingEnabled ?? true;
    this.sensitiveFieldPatterns = config.sensitiveFieldPatterns ?? [
      /social.*number/i,
      /address\..*/i,
      /phone/i,
      /email/i
    ];
  }
  
  // Implementation of required interface methods
  async serverWillStart() {
    console.log('Healthcare plugin initializing...');
    
    return {
      async serverWillStop() {
        console.log('Healthcare plugin shutting down...');
      }
    };
  }
  
  // Request lifecycle hooks
  async requestDidStart(requestContext) {
    const startTime = Date.now();
    
    // Return object containing lifecycle event handlers
    return {
      async didResolveOperation({ request, operation }) {
        // Analyze operation for sensitive fields
        if (this.trackingEnabled) {
          this.trackSensitiveFieldAccess(operation);
        }
      },
      
      async didEncounterErrors({ errors }) {
        // Log errors with healthcare-specific context
        errors.forEach(error => {
          console.error('GraphQL error:', {
            message: error.message,
            path: error.path,
            domain: this.detectHealthcareDomain(error.path)
          });
        });
      },
      
      async willSendResponse({ response }) {
        // Sanitize sensitive data in development environments
        if (process.env.NODE_ENV !== 'production') {
          this.sanitizeResponse(response);
        }
        
        // Track performance metrics
        const duration = Date.now() - startTime;
        this.recordOperationMetrics(requestContext.request.operationName, duration);
      }
    };
  }
  
  // Helper methods
  private trackSensitiveFieldAccess(operation) {
    // Implementation for tracking access to sensitive fields
    // ...
    
    return;
  }
  
  private sanitizeResponse(response) {
    // Implementation for sanitizing sensitive data in responses
    // ...
    
    return response;
  }
  
  private detectHealthcareDomain(path) {
    // Logic to map GraphQL paths to healthcare domains
    // ...
    
    return 'unknown';
  }
  
  private recordOperationMetrics(operationName, duration) {
    // Implementation for recording operation metrics
    // ...
    
    return;
  }
}

// Usage example
const gateway = new ApolloGateway({
  // Gateway configuration...
});

const server = new ApolloServer({
  gateway,
  plugins: [
    new CustomHealthcarePlugin({
      trackingEnabled: true,
      sensitiveFieldPatterns: [
        /mrn/i,
        /social.*number/i,
        /dob/i,
        /birth.*date/i
      ]
    })
  ]
});
```

#### Custom Authentication Handlers

The Federated Graph API allows you to implement custom authentication handlers to integrate with different identity providers and authentication mechanisms.

**When to Use**:
- When integrating with a custom identity provider
- For implementing specialized authentication flows
- When enforcing custom security policies
- For implementing multi-factor authentication
- To support legacy authentication systems

**Implementation Example**:

```typescript
import { AuthenticationError } from 'apollo-server-errors';
import jwt from 'jsonwebtoken';
import jwksClient from 'jwks-rsa';

// Custom authentication handler implementation
export class HealthcareAuthHandler {
  private readonly jwksUri: string;
  private readonly audience: string;
  private readonly issuer: string;
  private readonly client: any;
  
  constructor(config) {
    // Initialize properties
    this.jwksUri = config.jwksUri;
    this.audience = config.audience;
    this.issuer = config.issuer;
    
    // Initialize JWKS client
    this.client = jwksClient({
      jwksUri: this.jwksUri,
      cache: true,
      cacheMaxEntries: 5,
      cacheMaxAge: 10 * 60 * 1000 // 10 minutes
    });
  }
  
  // Get signing key from JWKS
  private async getSigningKey(kid) {
    return new Promise((resolve, reject) => {
      this.client.getSigningKey(kid, (err, key) => {
        if (err) {
          return reject(err);
        }
        
        const signingKey = key.publicKey || key.rsaPublicKey;
        resolve(signingKey);
      });
    });
  }
  
  // Verify JWT token
  async verifyToken(token) {
    try {
      // Decode token header to get key ID
      const decodedToken = jwt.decode(token, { complete: true });
      
      if (!decodedToken) {
        throw new AuthenticationError('Invalid token');
      }
      
      const kid = decodedToken.header.kid;
      const signingKey = await this.getSigningKey(kid);
      
      // Verify token with signing key
      const verifiedToken = jwt.verify(token, signingKey, {
        audience: this.audience,
        issuer: this.issuer
      });
      
      // Extract healthcare-specific roles and permissions
      const roles = verifiedToken.roles || [];
      const permissions = verifiedToken.permissions || [];
      const organizationId = verifiedToken.organizationId;
      
      // Map healthcare roles to permissions if necessary
      const mappedPermissions = this.mapHealthcareRolesToPermissions(roles, permissions);
      
      return {
        sub: verifiedToken.sub,
        roles,
        permissions: mappedPermissions,
        organizationId,
        isProvider: roles.includes('PROVIDER'),
        isPatient: roles.includes('PATIENT'),
        isAdministrator: roles.includes('ADMIN')
      };
    } catch (error) {
      console.error('Authentication error:', error);
      throw new AuthenticationError('Invalid token: ' + error.message);
    }
  }
  
  // Map healthcare roles to permissions
  private mapHealthcareRolesToPermissions(roles, permissions) {
    // Start with explicitly granted permissions
    const allPermissions = [...permissions];
    
    // Map roles to implied permissions based on healthcare domain
    if (roles.includes('PROVIDER')) {
      allPermissions.push(
        'patient:read',
        'patient:demographics:read',
        'clinical:read',
        'medication:read',
        'appointment:read',
        'appointment:write'
      );
    }
    
    if (roles.includes('PHARMACIST')) {
      allPermissions.push(
        'patient:demographics:read',
        'medication:read',
        'medication:write',
        'prescription:read',
        'prescription:write'
      );
    }
    
    if (roles.includes('PATIENT')) {
      allPermissions.push(
        'self:read',
        'self:demographics:read',
        'self:clinical:read',
        'self:medication:read',
        'self:appointment:read'
      );
    }
    
    if (roles.includes('ADMIN')) {
      allPermissions.push(
        'admin:users:read',
        'admin:users:write',
        'admin:system:read'
      );
    }
    
    // Return deduplicated permissions
    return [...new Set(allPermissions)];
  }
}

// Usage example
const authHandler = new HealthcareAuthHandler({
  jwksUri: 'https://identity.covermymeds.com/.well-known/jwks.json',
  audience: 'https://api.covermymeds.com',
  issuer: 'https://identity.covermymeds.com/'
});

// Use in Apollo Server context function
const server = new ApolloServer({
  gateway,
  context: async ({ req }) => {
    // Extract token from Authorization header
    const authHeader = req.headers.authorization || '';
    
    if (!authHeader.startsWith('Bearer ')) {
      throw new AuthenticationError('Authorization header must start with Bearer');
    }
    
    const token = authHeader.replace('Bearer ', '');
    
    // Verify token and extract user information
    const user = await authHandler.verifyToken(token);
    
    return { user };
  }
});
```

### Subgraph Extensions

#### Custom Directive Implementations

The Federated Graph API allows you to implement custom GraphQL directives to add metadata, modify schema behavior, or implement cross-cutting concerns.

**When to Use**:
- To implement field-level authorization
- For custom input validation logic
- To add domain-specific metadata to schema elements
- For implementing calculated or virtual fields
- To enforce healthcare-specific data policies

**Implementation Example**:

```typescript
import { mapSchema, getDirective, MapperKind } from '@graphql-tools/utils';
import { defaultFieldResolver, GraphQLSchema } from 'graphql';
import { ForbiddenError } from 'apollo-server-errors';

/**
 * Custom directive for implementing HIPAA data category tagging
 * This directive marks fields that contain specific HIPAA data categories
 */
export function hipaaDirectiveTransformer(schema: GraphQLSchema): GraphQLSchema {
  return mapSchema(schema, {
    // Process object fields that have the @hipaa directive
    [MapperKind.OBJECT_FIELD]: (fieldConfig) => {
      // Get directive from field
      const hipaaDirective = getDirective(
        schema,
        fieldConfig,
        'hipaa'
      )?.[0];

      if (hipaaDirective) {
        // Get HIPAA category from directive argument
        const { category, allowedRoles } = hipaaDirective;
        
        // Store original resolver
        const originalResolver = fieldConfig.resolve || defaultFieldResolver;
        
        // Replace resolver with wrapped version that enforces HIPAA access rules
        fieldConfig.resolve = async function (source, args, context, info) {
          const { user } = context;
          
          // Check if user has permission to access this HIPAA data category
          if (!user) {
            throw new ForbiddenError('Authentication required to access PHI data');
          }
          
          // Check if user has any of the allowed roles
          const hasAllowedRole = allowedRoles.some(role => 
            user.roles.includes(role)
          );
          
          if (!hasAllowedRole) {
            throw new ForbiddenError(
              `Access to ${category} PHI requires one of the following roles: ${allowedRoles.join(', ')}`
            );
          }
          
          // Log PHI access for audit purposes
          context.logPHIAccess({
            userId: user.sub,
            hipaaCategory: category,
            fieldPath: info.path,
            timestamp: new Date().toISOString()
          });
          
          // If authorized, execute original resolver
          return originalResolver(source, args, context, info);
        };
        
        return fieldConfig;
      }
    }
  });
}

// GraphQL schema definition with @hipaa directive
const typeDefs = gql`
  directive @hipaa(
    category: HIPAACategory!
    allowedRoles: [String!]! = ["PROVIDER", "ADMIN"]
  ) on FIELD_DEFINITION
  
  enum HIPAACategory {
    DEMOGRAPHIC
    CLINICAL
    BILLING
    GENETIC
    SUBSTANCE_ABUSE
    MENTAL_HEALTH
    HIV_STATUS
    SEXUAL_HEALTH
  }
  
  type Patient @key(fields: "id") {
    id: ID!
    
    # Basic demographic data
    name: HumanName
    gender: Gender
    birthDate: String @hipaa(category: DEMOGRAPHIC)
    
    # More sensitive data with stricter role requirements
    socialSecurityNumber: String @hipaa(
      category: DEMOGRAPHIC, 
      allowedRoles: ["ADMIN", "BILLING"]
    )
    
    # Clinical data
    conditions: [Condition!] @hipaa(category: CLINICAL)
    
    # Mental health data with stricter access controls
    mentalHealthNotes: [ClinicalNote!] @hipaa(
      category: MENTAL_HEALTH,
      allowedRoles: ["MENTAL_HEALTH_PROVIDER", "PSYCHIATRIST"]
    )
  }
`;

// Usage in Apollo Server
import { ApolloServer } from '@apollo/server';
import { buildSubgraphSchema } from '@apollo/subgraph';
import { hipaaDirectiveTransformer } from './hipaa-directive';

const server = new ApolloServer({
  schema: hipaaDirectiveTransformer(
    buildSubgraphSchema([{ typeDefs, resolvers }])
  ),
  context: ({ req }) => {
    // ... authentication logic ...
    
    return {
      user,
      logPHIAccess: (accessLog) => {
        // Implement PHI access logging for HIPAA compliance
        console.log('PHI Access:', accessLog);
        // In production, would write to a secure audit log system
      }
    };
  }
});
```

#### Custom Scalar Types

The Federated Graph API supports custom scalar types for domain-specific data formats and validation.

**When to Use**:
- For healthcare-specific data formats (FHIR resource IDs, CPT codes, etc.)
- To enforce data validation rules at the schema level
- When standard GraphQL scalars don't adequately represent your data
- For implementing specialized serialization/deserialization logic
- To provide better developer experience with domain-specific types

**Implementation Example**:

```typescript
import { GraphQLScalarType, GraphQLError, Kind } from 'graphql';

// Custom scalar for FHIR resource IDs
export const FHIR_ID = new GraphQLScalarType({
  name: 'FHIR_ID',
  description: 'A scalar representing a FHIR resource identifier',
  
  // Serialization: value sent to the client
  serialize(value) {
    // Ensure value is a string
    if (typeof value !== 'string') {
      return String(value);
    }
    return value;
  },
  
  // Value from client for variables
  parseValue(value) {
    if (typeof value !== 'string') {
      throw new GraphQLError('FHIR_ID must be a string');
    }
    
    // Validate FHIR ID format (alphanumeric plus some special chars)
    if (!/^[A-Za-z0-9\-\.]{1,64}$/.test(value)) {
      throw new GraphQLError(
        'Invalid FHIR_ID format. Must be alphanumeric with optional hyphens/dots, max 64 chars.'
      );
    }
    
    return value;
  },
  
  // Value from client in inline arguments
  parseLiteral(ast) {
    if (ast.kind !== Kind.STRING) {
      throw new GraphQLError(
        `FHIR_ID must be a string, but got: ${ast.kind}`
      );
    }
    
    // Validate FHIR ID format
    if (!/^[A-Za-z0-9\-\.]{1,64}$/.test(ast.value)) {
      throw new GraphQLError(
        'Invalid FHIR_ID format. Must be alphanumeric with optional hyphens/dots, max 64 chars.'
      );
    }
    
    return ast.value;
  }
});

// Custom scalar for healthcare codes (CPT, ICD-10, LOINC, etc.)
export const HealthcareCode = new GraphQLScalarType({
  name: 'HealthcareCode',
  description: 'A scalar representing a healthcare code with its coding system',
  
  // Serialization: value sent to the client
  serialize(value) {
    if (typeof value !== 'object' || !value.system || !value.code) {
      throw new GraphQLError('HealthcareCode must have system and code properties');
    }
    
    return `${value.system}|${value.code}`;
  },
  
  // Value from client for variables
  parseValue(value) {
    if (typeof value !== 'string') {
      throw new GraphQLError('HealthcareCode must be a string in format system|code');
    }
    
    const parts = value.split('|');
    
    if (parts.length !== 2) {
      throw new GraphQLError('HealthcareCode must be in format system|code');
    }
    
    const [system, code] = parts;
    
    // Validate system URL
    if (!/^http(s)?:\/\//.test(system)) {
      throw new GraphQLError('HealthcareCode system must be a valid URL');
    }
    
    // Validate code format based on system
    if (system.includes('snomed') && !/^\d+$/.test(code)) {
      throw new GraphQLError('SNOMED CT codes must be numeric');
    }
    
    if (system.includes('loinc') && !/^\d+-\d+$/.test(code)) {
      throw new GraphQLError('LOINC codes must be in format number-number');
    }
    
    return { system, code };
  },
  
  // Value from client in inline arguments
  parseLiteral(ast) {
    if (ast.kind !== Kind.STRING) {
      throw new GraphQLError(`HealthcareCode must be a string, but got: ${ast.kind}`);
    }
    
    const value = ast.value;
    const parts = value.split('|');
    
    if (parts.length !== 2) {
      throw new GraphQLError('HealthcareCode must be in format system|code');
    }
    
    const [system, code] = parts;
    
    // Validate system URL
    if (!/^http(s)?:\/\//.test(system)) {
      throw new GraphQLError('HealthcareCode system must be a valid URL');
    }
    
    // Validate code format based on system
    if (system.includes('snomed') && !/^\d+$/.test(code)) {
      throw new GraphQLError('SNOMED CT codes must be numeric');
    }
    
    if (system.includes('loinc') && !/^\d+-\d+$/.test(code)) {
      throw new GraphQLError('LOINC codes must be in format number-number');
    }
    
    return { system, code };
  }
});

// Usage in schema
const typeDefs = gql`
  scalar FHIR_ID
  scalar HealthcareCode
  
  type Patient {
    id: FHIR_ID!
    identifier: [Identifier!]
    name: HumanName
    # Other fields...
  }
  
  type Condition {
    id: FHIR_ID!
    subject: Reference!
    code: CodeableConcept!
    bodySite: [CodeableConcept!]
    # Other fields...
  }
  
  type CodeableConcept {
    coding: [Coding!]!
    text: String
  }
  
  type Coding {
    system: String!
    version: String
    code: String!
    display: String
    userSelected: Boolean
  }
  
  type Identifier {
    use: IdentifierUse
    type: CodeableConcept
    system: String
    value: String
    period: Period
    assigner: Reference
  }
  
  # Query with healthcare code input
  type Query {
    findPatientsByCondition(conditionCode: HealthcareCode!): [Patient!]
    getResourceById(resourceType: String!, id: FHIR_ID!): Resource
  }
`;

// Resolver implementation
const resolvers = {
  FHIR_ID,
  HealthcareCode,
  
  Query: {
    findPatientsByCondition: async (_, { conditionCode }) => {
      // conditionCode is already parsed to { system, code }
      return fetchPatientsByCondition(conditionCode.system, conditionCode.code);
    },
    
    getResourceById: async (_, { resourceType, id }) => {
      // id is already validated as a valid FHIR ID
      return fetchResourceById(resourceType, id);
    }
  }
};
```

### Integration Extensions

#### Custom Federation Entity Resolvers

The Federated Graph API supports custom entity resolvers for optimizing how entities are resolved across subgraph boundaries.

**When to Use**:
- To optimize entity resolution for performance-critical paths
- When implementing complex entity relationships
- For custom caching or batching strategies
- When integrating with legacy or external systems
- To implement domain-specific entity resolution logic

**Implementation Example**:

```typescript
import { DataSource } from 'apollo-datasource';
import DataLoader from 'dataloader';

/**
 * Custom patient entity resolver with efficient batching and caching
 */
export class PatientEntityResolver extends DataSource {
  private patientLoader: DataLoader<string, any>;
  private patientsByMRNLoader: DataLoader<string, any>;
  private patientsBySSNLoader: DataLoader<string, any>;
  private patientSearchLoader: DataLoader<string, any[]>;
  
  constructor({ patientService }) {
    super();
    this.patientService = patientService;
    
    // Create dataloaders for different patient lookup strategies
    this.patientLoader = new DataLoader(
      async (ids: string[]) => {
        console.log(`Loading ${ids.length} patients by ID`);
        const patients = await this.patientService.getPatientsByIds(ids);
        
        // Map results to maintain order matching the requested IDs
        return ids.map(id => 
          patients.find(patient => patient.id === id) || null
        );
      },
      {
        cache: true,
        maxBatchSize: 100,
        batchScheduleFn: callback => setTimeout(callback, 10)
      }
    );
    
    this.patientsByMRNLoader = new DataLoader(
      async (mrns: string[]) => {
        console.log(`Loading ${mrns.length} patients by MRN`);
        const patients = await this.patientService.getPatientsByMRNs(mrns);
        
        // Map results to maintain order matching the requested MRNs
        return mrns.map(mrn => 
          patients.find(patient => patient.mrn === mrn) || null
        );
      },
      {
        cache: true,
        maxBatchSize: 50,
        batchScheduleFn: callback => setTimeout(callback, 10)
      }
    );
    
    // Other dataloaders...
  }
  
  // Method called by federation to resolve Patient entities
  async __resolveReference({ id, mrn, ssn }) {
    // Determine the best lookup strategy based on available reference fields
    if (id) {
      return this.getPatientById(id);
    } else if (mrn) {
      return this.getPatientByMRN(mrn);
    } else if (ssn) {
      return this.getPatientBySSN(ssn);
    }
    
    return null;
  }
  
  // Public methods used by GraphQL resolvers
  async getPatientById(id: string) {
    return this.patientLoader.load(id);
  }
  
  async getPatientByMRN(mrn: string) {
    return this.patientsByMRNLoader.load(mrn);
  }
  
  async getPatientBySSN(ssn: string) {
    return this.patientsBySSNLoader.load(ssn);
  }
  
  async searchPatients(params: PatientSearchParams) {
    // Generate cache key from search parameters
    const cacheKey = this.generateSearchCacheKey(params);
    
    // Use dataloader to batch and cache similar searches
    return this.patientSearchLoader.load(cacheKey);
  }
  
  // Helper methods
  private generateSearchCacheKey(params: PatientSearchParams): string {
    // Sort parameters to ensure consistent cache keys
    const sortedParams = Object.entries(params)
      .filter(([_, value]) => value !== undefined && value !== null)
      .sort(([keyA], [keyB]) => keyA.localeCompare(keyB));
      
    return JSON.stringify(sortedParams);
  }
}

// Usage in subgraph
import { ApolloServer } from '@apollo/server';
import { buildSubgraphSchema } from '@apollo/subgraph';
import { PatientEntityResolver } from './patient-entity-resolver';
import { PatientService } from './patient-service';

const patientService = new PatientService({
  // Configuration for the patient service
});

const server = new ApolloServer({
  schema: buildSubgraphSchema([{ typeDefs, resolvers }]),
  dataSources: () => ({
    patientResolver: new PatientEntityResolver({ patientService })
  })
});

// Resolver implementation using the entity resolver
const resolvers = {
  Patient: {
    __resolveReference(reference, { dataSources }) {
      return dataSources.patientResolver.__resolveReference(reference);
    },
    
    // Field resolvers
    medicalHistory(patient, _, { dataSources }) {
      // Ensure we have a complete patient object
      if (!patient.id) {
        return null;
      }
      
      return dataSources.medicalHistoryAPI.getHistoryForPatient(patient.id);
    }
  },
  
  Query: {
    patient(_, { id }, { dataSources }) {
      return dataSources.patientResolver.getPatientById(id);
    },
    
    patientByMRN(_, { mrn }, { dataSources }) {
      return dataSources.patientResolver.getPatientByMRN(mrn);
    },
    
    searchPatients(_, { params }, { dataSources }) {
      return dataSources.patientResolver.searchPatients(params);
    }
  }
};
```

#### GraphQL Subscription Handlers

The Federated Graph API allows you to implement custom subscription handlers for real-time data updates, often integrating with the Event Broker.

**When to Use**:
- For real-time clinical alerts and notifications
- To provide live updates on patient data
- For real-time collaboration features
- When implementing dashboards with live data
- For implementing time-sensitive healthcare workflows

**Implementation Example**:

```typescript
import { PubSub } from 'graphql-subscriptions';
import { Kafka } from 'kafkajs';
import { withFilter } from 'graphql-subscriptions';

// Create a PubSub instance for GraphQL subscriptions
const pubsub = new PubSub();

// Connect to Kafka (Event Broker)
const kafka = new Kafka({
  clientId: 'graph-subscription-handler',
  brokers: ['kafka-broker-1:9092', 'kafka-broker-2:9092'],
  ssl: true,
  sasl: {
    mechanism: 'plain',
    username: process.env.KAFKA_USERNAME,
    password: process.env.KAFKA_PASSWORD,
  }
});

// Create a consumer for relevant healthcare event topics
const consumer = kafka.consumer({ groupId: 'graphql-subscriptions-group' });

// Map of topic names to PubSub event types
const TOPIC_EVENT_MAP = {
  'patient-updates': 'PATIENT_UPDATED',
  'medication-events': 'MEDICATION_UPDATED',
  'clinical-alerts': 'CLINICAL_ALERT',
  'appointment-updates': 'APPOINTMENT_UPDATED',
  'auth-decisions': 'AUTH_DECISION'
};

// Connect to Kafka and subscribe to relevant topics
async function startSubscriptionHandler() {
  await consumer.connect();
  
  // Subscribe to all relevant topics
  await consumer.subscribe({ 
    topics: Object.keys(TOPIC_EVENT_MAP),
    fromBeginning: false
  });

  await consumer.run({
    eachMessage: async ({ topic, partition, message }) => {
      try {
        // Parse the Kafka message
        const eventData = JSON.parse(message.value.toString());
        
        // Get the corresponding PubSub event type
        const eventType = TOPIC_EVENT_MAP[topic];
        
        if (!eventType) {
          console.warn(`No mapping defined for topic ${topic}`);
          return;
        }
        
        // Add metadata to event
        const enrichedData = {
          ...eventData,
          _meta: {
            eventTime: new Date(parseInt(message.timestamp)),
            topic,
            partition
          }
        };
        
        // Publish to GraphQL PubSub system
        await pubsub.publish(eventType, {
          [convertEventTypeToFieldName(eventType)]: enrichedData
        });
        
        console.log(`Published ${eventType} event from Kafka topic ${topic}`);
      } catch (error) {
        console.error(`Error processing message from topic ${topic}:`, error);
      }
    }
  });
  
  console.log('Subscription handler started and connected to Kafka');
}

// Helper to convert EVENT_TYPE to eventType for GraphQL fields
function convertEventTypeToFieldName(eventType) {
  return eventType
    .toLowerCase()
    .replace(/_([a-z])/g, g => g[1].toUpperCase());
}

// Start the subscription handler
startSubscriptionHandler().catch(error => {
  console.error('Failed to start subscription handler:', error);
  process.exit(1);
});

// GraphQL schema with subscription definitions
const typeDefs = gql`
  type Subscription {
    patientUpdated(patientId: ID): PatientUpdate!
    medicationUpdated(patientId: ID): MedicationUpdate!
    clinicalAlert(
      patientId: ID, 
      severity: [AlertSeverity!]
    ): ClinicalAlert!
    appointmentUpdated(
      patientId: ID,
      practitionerId: ID
    ): AppointmentUpdate!
    authDecision(authId: ID!): AuthDecision!
  }
  
  type PatientUpdate {
    id: ID!
    updateType: UpdateType!
    timestamp: DateTime!
    updatedFields: [String!]
    patient: Patient
  }
  
  type MedicationUpdate {
    id: ID!
    patientId: ID!
    updateType: UpdateType!
    timestamp: DateTime!
    medication: Medication
  }
  
  type ClinicalAlert {
    id: ID!
    patientId: ID!
    timestamp: DateTime!
    alertType: AlertType!
    severity: AlertSeverity!
    message: String!
    source: String!
    payload: JSON
  }
  
  type AppointmentUpdate {
    id: ID!
    updateType: UpdateType!
    timestamp: DateTime!
    appointment: Appointment
  }
  
  type AuthDecision {
    id: ID!
    timestamp: DateTime!
    status: AuthStatus!
    authType: AuthType!
    provider: String
    patient: Patient
    medication: Medication
    decisionDetails: JSON
  }
  
  enum UpdateType {
    CREATED
    UPDATED
    DELETED
  }
  
  enum AlertType {
    VITAL_SIGN
    LAB_RESULT
    MEDICATION
    APPOINTMENT
    SYSTEM
  }
  
  enum AlertSeverity {
    CRITICAL
    HIGH
    MEDIUM
    LOW
    INFO
  }
  
  enum AuthStatus {
    APPROVED
    DENIED
    PENDING
    CANCELLED
    EXPIRED
  }
  
  enum AuthType {
    PRIOR_AUTHORIZATION
    REFERRAL
    ELIGIBILITY
  }
  
  # Extended scalar types
  scalar DateTime
  scalar JSON
`;

// Resolver implementation with subscription filters
const resolvers = {
  Subscription: {
    patientUpdated: {
      subscribe: withFilter(
        () => pubsub.asyncIterator(['PATIENT_UPDATED']),
        (payload, variables) => {
          // If no patientId filter is provided, return all updates
          if (!variables.patientId) {
            return true;
          }
          
          // Filter updates for the requested patient
          return payload.patientUpdated.id === variables.patientId;
        }
      )
    },
    
    medicationUpdated: {
      subscribe: withFilter(
        () => pubsub.asyncIterator(['MEDICATION_UPDATED']),
        (payload, variables) => {
          // If no patientId filter is provided, return all updates
          if (!variables.patientId) {
            return true;
          }
          
          // Filter updates for the requested patient
          return payload.medicationUpdated.patientId === variables.patientId;
        }
      )
    },
    
    clinicalAlert: {
      subscribe: withFilter(
        () => pubsub.asyncIterator(['CLINICAL_ALERT']),
        (payload, variables) => {
          // If no patientId filter is provided, return all alerts
          if (!variables.patientId && !variables.severity) {
            return true;
          }
          
          const alert = payload.clinicalAlert;
          
          // Check if patientId matches if provided
          if (variables.patientId && alert.patientId !== variables.patientId) {
            return false;
          }
          
          // Check if severity matches if provided
          if (variables.severity && !variables.severity.includes(alert.severity)) {
            return false;
          }
          
          return true;
        }
      )
    },
    
    appointmentUpdated: {
      subscribe: withFilter(
        () => pubsub.asyncIterator(['APPOINTMENT_UPDATED']),
        (payload, variables) => {
          const appointment = payload.appointmentUpdated.appointment;
          
          // If no filters are provided, return all updates
          if (!variables.patientId && !variables.practitionerId) {
            return true;
          }
          
          // Check if patientId matches if provided
          if (variables.patientId && appointment.patientId !== variables.patientId) {
            return false;
          }
          
          // Check if practitionerId matches if provided
          if (variables.practitionerId && appointment.practitionerId !== variables.practitionerId) {
            return false;
          }
          
          return true;
        }
      )
    },
    
    authDecision: {
      subscribe: withFilter(
        () => pubsub.asyncIterator(['AUTH_DECISION']),
        (payload, variables) => {
          // Only return updates for the specific auth being watched
          return payload.authDecision.id === variables.authId;
        }
      )
    }
  }
};

// Client implementation for a real-time alert monitor
import { gql, useSubscription } from '@apollo/client';

const CLINICAL_ALERTS_SUBSCRIPTION = gql`
  subscription WatchClinicalAlerts($patientId: ID!, $severities: [AlertSeverity!]) {
    clinicalAlert(patientId: $patientId, severity: $severities) {
      id
      timestamp
      alertType
      severity
      message
      source
      payload
    }
  }
`;

function PatientAlertMonitor({ patientId }) {
  const { data, loading, error } = useSubscription(
    CLINICAL_ALERTS_SUBSCRIPTION,
    {
      variables: { 
        patientId, 
        severities: ['CRITICAL', 'HIGH'] 
      }
    }
  );
  
  // Process alerts as they arrive
  React.useEffect(() => {
    if (data?.clinicalAlert) {
      const alert = data.clinicalAlert;
      
      // Display alert based on severity
      switch (alert.severity) {
        case 'CRITICAL':
          showCriticalAlert(alert);
          break;
        case 'HIGH':
          showHighPriorityAlert(alert);
          break;
        default:
          showStandardAlert(alert);
      }
    }
  }, [data]);
  
  // Render alert monitoring UI
  return (
    <div className="alert-monitor">
      <h3>Clinical Alerts</h3>
      {loading && <p>Connecting to alert system...</p>}
      {error && <p>Error connecting to alert system: {error.message}</p>}
      {/* Alert display components */}
    </div>
  );
}
```

## Best Practices for Extension Development

### Architecture Guidelines

1. **Follow Single Responsibility Principle**
   - Each extension should have a clear, focused purpose
   - Avoid creating monolithic extensions that try to do too much
   - Design extensions to work together through composition

2. **Use Standardized Interfaces**
   - Follow the existing interface patterns in the Federated Graph API
   - Document the interfaces your extension implements or provides
   - Maintain backward compatibility when updating extensions

3. **Ensure Testability**
   - Design extensions to be easily testable in isolation
   - Include comprehensive unit and integration tests
   - Consider using dependency injection for better testability

4. **Consider Performance Impact**
   - Evaluate the performance implications of your extensions
   - Optimize for the common case
   - Implement caching where appropriate
   - Add metrics to monitor extension performance

### Development Best Practices

1. **Error Handling**
   - Implement robust error handling in all extensions
   - Fail gracefully and provide meaningful error messages
   - Consider the impact of errors on the overall system
   - Include recovery mechanisms where possible

2. **Configuration Management**
   - Make extensions configurable through external configuration
   - Use sensible defaults for all configuration options
   - Validate configuration at startup
   - Document all configuration options

3. **Logging and Monitoring**
   - Include comprehensive logging in all extensions
   - Add metrics for key operations
   - Ensure extensions integrate with the Federated Graph API's monitoring system
   - Make logs and metrics consistent with the broader system

4. **Security Considerations**
   - Follow the principle of least privilege
   - Avoid handling sensitive data unless necessary
   - Implement appropriate authentication and authorization checks
   - Document security implications of your extensions

5. **Documentation**
   - Provide clear documentation on how to install, configure, and use the extension
   - Include examples of common usage patterns
   - Document any assumptions or limitations
   - Keep documentation up to date as the extension evolves

### Healthcare-Specific Extension Guidelines

1. **HIPAA Compliance**
   - Ensure extensions comply with HIPAA requirements for PHI
   - Implement appropriate data protection mechanisms
   - Document compliance considerations for extension users
   - Include audit logging for all PHI access

2. **Data Validation**
   - Validate healthcare data against industry standards (e.g., FHIR)
   - Implement data quality checks appropriate for healthcare data
   - Consider implementing validation against terminology services
   - Document validation requirements and limitations

3. **Interoperability**
   - Design extensions to work with healthcare interoperability standards
   - Consider integration with common healthcare systems
   - Support mapping between different healthcare data formats
   - Document interoperability capabilities and requirements

4. **Clinical Safety**
   - Consider the clinical safety implications of extensions
   - Implement appropriate checks for critical healthcare workflows
   - Document any safety-critical aspects of the extension
   - Provide clear guidance on safe usage patterns

## Related Resources
- [Federated Graph API Advanced Use Cases](./advanced-use-cases.md)
- [Federated Graph API Core APIs](../02-core-functionality/core-apis.md)
- [Federated Graph API Customization](./customization.md)
- [Apollo Federation Extension Documentation](https://www.apollographql.com/docs/federation/extension-points/)
- [GraphQL Schema Extension Points](https://www.apollographql.com/docs/apollo-server/schema/schema-extension)