# Custom Directives

## Introduction

Custom directives are a powerful feature of GraphQL that allow you to extend schema functionality in a declarative, reusable way. In a federated architecture, custom directives can be used to enforce authorization, validate inputs, transform data, and implement organization-wide policies directly at the schema level.

This guide provides practical patterns and implementation guidance for:
- Implementing authorization directives for security
- Creating transformation and validation directives
- Integrating custom directives in a federated schema
- Writing directive resolvers for cross-cutting concerns

By using custom directives, you can keep your schema expressive, maintainable, and aligned with your organization’s requirements.

### Quick Start

1. Understand the role of directives in GraphQL schemas
2. Implement authorization directives for security
3. Create transformation directives for data formatting
4. Add validation directives for input validation
5. Learn how to implement directive resolvers

### Related Components

- [Creating Subgraphs](../02-core-functionality/creating-subgraphs.md): Learn how to integrate directives in subgraphs
- [Authentication](../02-core-functionality/authentication.md): Combine directives with authentication
- [Schema Federation](schema-federation.md): Use directives in federated schemas
- [Schema Governance](../04-data-management/schema-governance.md): Manage directive usage across teams

## Authorization Directives

### Overview

Authorization directives enable you to enforce access control policies directly in your GraphQL schema, making security requirements explicit and maintainable. In a federated architecture, these directives can be applied consistently across subgraphs to ensure robust, organization-wide security.

### Rationale
- **Declarative security**: Define access requirements at the schema level, close to the data model.
- **Reusability**: Apply the same directive to multiple fields or types.
- **Consistency**: Enforce the same rules across all subgraphs and teams.

### Implementation Steps
1. Define custom directives in your schema (e.g., `@requireAuth`, `@requireRole`).
2. Implement directive resolvers to enforce authorization logic at runtime.
3. Apply directives to fields or types that require protection.

### Example: Defining and Using an Authorization Directive
```graphql
directive @requireRole(role: String!) on FIELD_DEFINITION | OBJECT

type Patient @requireRole(role: "clinician") {
  id: ID!
  name: String!
  birthDate: String
}

extend type Query {
  patient(id: ID!): Patient @requireRole(role: "clinician")
}
```

### Example: Implementing a Directive Resolver (Apollo Server)
```javascript
const { SchemaDirectiveVisitor, ForbiddenError } = require('apollo-server');
const { defaultFieldResolver } = require('graphql');

class RequireRoleDirective extends SchemaDirectiveVisitor {
  visitFieldDefinition(field) {
    const { resolve = defaultFieldResolver } = field;
    const { role } = this.args;
    field.resolve = async function (source, args, context, info) {
      const user = context.user;
      if (!user || !user.roles.includes(role)) {
        throw new ForbiddenError(`You need the ${role} role to access this field`);
      }
      return resolve.call(this, source, args, context, info);
    };
  }
}

const schemaDirectives = {
  requireRole: RequireRoleDirective
};
```

### Best Practices
- Use descriptive directive names and document their usage.
- Combine directives for layered security (e.g., `@requireAuth` and `@requireRole`).
- Test directive behavior for both authorized and unauthorized scenarios.
- Review and update authorization logic as roles and policies evolve.


## Transformation Directives

### Overview

Transformation directives allow you to modify or format data at the schema level before it is returned to clients. This can include masking sensitive data, formatting dates, or applying custom business logic. In a federated architecture, transformation directives can be used to ensure consistent data presentation across subgraphs.

### Rationale
- **Consistency**: Apply the same transformation logic across multiple fields or types.
- **Reusability**: Encapsulate formatting and transformation logic in a directive.
- **Security**: Mask or redact sensitive fields as needed.

### Implementation Steps
1. Define a transformation directive in your schema (e.g., `@mask`, `@formatDate`).
2. Implement a directive resolver to apply the transformation at runtime.
3. Apply the directive to fields or types that require transformation.

### Example: Masking Sensitive Data
```graphql
directive @mask(maskWith: String = "****") on FIELD_DEFINITION

type Patient {
  id: ID!
  name: String!
  ssn: String @mask(maskWith: "XXX-XX-****")
}
```

### Example: Implementing a Masking Directive Resolver
```javascript
const { SchemaDirectiveVisitor } = require('apollo-server');
const { defaultFieldResolver } = require('graphql');

class MaskDirective extends SchemaDirectiveVisitor {
  visitFieldDefinition(field) {
    const { resolve = defaultFieldResolver } = field;
    const { maskWith } = this.args;
    field.resolve = async function (source, args, context, info) {
      const value = await resolve.call(this, source, args, context, info);
      if (!value) return value;
      // Simple masking logic (customize as needed)
      return maskWith;
    };
  }
}

const schemaDirectives = {
  mask: MaskDirective
};
```

### Best Practices
- Use transformation directives for cross-cutting concerns like formatting, masking, or localization.
- Document the behavior and intended use of each directive.
- Avoid complex business logic in directives—keep them focused and testable.
- Coordinate directive usage across subgraphs for consistent client experience.


## Validation Directives

### Overview

Validation directives allow you to enforce input validation rules at the schema level, ensuring that data meets business requirements before it is processed. In a federated architecture, validation directives help maintain data quality and consistency across subgraphs.

### Rationale
- **Data integrity**: Prevent invalid or malformed data from entering your system.
- **Declarative rules**: Express validation logic close to the data model.
- **Reusability**: Apply the same validation rule to multiple fields or types.

### Implementation Steps
1. Define a validation directive in your schema (e.g., `@isEmail`, `@minLength`).
2. Implement a directive resolver to perform validation at runtime.
3. Apply the directive to input fields or arguments that require validation.

### Example: Email Validation Directive
```graphql
directive @isEmail on ARGUMENT_DEFINITION | INPUT_FIELD_DEFINITION

input CreateUserInput {
  email: String! @isEmail
  name: String!
}
```

### Example: Implementing an Email Validation Directive Resolver
```javascript
const { SchemaDirectiveVisitor, UserInputError } = require('apollo-server');
const { defaultFieldResolver } = require('graphql');

class IsEmailDirective extends SchemaDirectiveVisitor {
  visitInputFieldDefinition(field) {
    const { resolve = defaultFieldResolver } = field;
    field.resolve = async function (source, args, context, info) {
      const value = args[field.name];
      if (value && !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(value)) {
        throw new UserInputError(`${field.name} must be a valid email address`);
      }
      return resolve.call(this, source, args, context, info);
    };
  }
}

const schemaDirectives = {
  isEmail: IsEmailDirective
};
```

### Best Practices
- Use validation directives for common input checks (e.g., email, length, regex).
- Combine multiple validation directives for complex rules.
- Provide clear, actionable error messages for validation failures.
- Test directive behavior with both valid and invalid inputs.


## Implementing Directive Resolvers

### Overview

Directive resolvers are the logic that powers custom directives in your GraphQL schema. They intercept field resolution at runtime, allowing you to enforce authorization, validate inputs, or transform data as specified by your directive’s arguments. In a federated architecture, directive resolvers should be implemented in each subgraph that uses the directive.

### Rationale
- **Separation of concerns**: Move cross-cutting logic out of resolvers and into reusable directive resolvers.
- **Consistency**: Apply the same logic across multiple fields, types, or subgraphs.
- **Maintainability**: Centralize and document business rules and policies.

### Implementation Steps
1. Define the directive in your schema and specify where it can be applied (e.g., `FIELD_DEFINITION`, `OBJECT`, `INPUT_FIELD_DEFINITION`).
2. Extend `SchemaDirectiveVisitor` (Apollo Server) or use a similar approach to implement the directive resolver.
3. Register the directive resolver in your server configuration.
4. Apply the directive in your schema where needed.

### Example: Logging Directive Resolver
```graphql
directive @log(message: String) on FIELD_DEFINITION

type Query {
  patient(id: ID!): Patient @log(message: "Fetching patient data")
}
```

```javascript
const { SchemaDirectiveVisitor } = require('apollo-server');
const { defaultFieldResolver } = require('graphql');

class LogDirective extends SchemaDirectiveVisitor {
  visitFieldDefinition(field) {
    const { resolve = defaultFieldResolver } = field;
    const { message } = this.args;
    field.resolve = async function (source, args, context, info) {
      console.log(message || `Accessed field ${info.fieldName}`);
      return resolve.call(this, source, args, context, info);
    };
  }
}

const schemaDirectives = {
  log: LogDirective
};
```

### Best Practices
- Keep directive resolvers focused and testable—avoid mixing unrelated logic.
- Document the directive’s purpose, arguments, and usage in your schema docs.
- Ensure directive resolvers are implemented in all subgraphs that use the directive.
- Test directive behavior in both “happy path” and error scenarios.


## Conclusion

Custom directives empower you to add powerful, reusable logic to your GraphQL schema—enabling declarative authorization, data transformation, validation, and more. In a federated architecture, directives promote consistency and maintainability across subgraphs and teams.

**Key takeaways:**
- Use custom directives to express cross-cutting concerns directly in your schema.
- Implement directive resolvers for authorization, transformation, and validation logic.
- Document and test directives to ensure clarity and reliability.
- Coordinate directive usage across subgraphs for a unified developer experience.

Continue to evolve your directive library as your organization’s needs grow, and revisit directive implementations regularly to maintain security, performance, and usability.

