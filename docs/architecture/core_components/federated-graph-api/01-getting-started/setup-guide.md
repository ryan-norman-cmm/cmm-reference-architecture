# Federated Graph API Setup Guide

## Introduction

Setting up a Federated Graph API requires configuring multiple components, including a gateway and subgraphs. This guide provides step-by-step instructions for setting up a complete federated GraphQL environment, from installing dependencies to configuring the gateway and creating your first subgraph. By following these steps, you'll have a working federated GraphQL API that can be extended with additional subgraphs as your needs evolve.

### Quick Start

1. Install Node.js and npm (or yarn)
2. Set up the Apollo Gateway project
3. Create your first subgraph
4. Configure the gateway to use your subgraph
5. Test your federated graph with GraphQL Playground

### Related Components

- [Federated Graph API Overview](overview.md): Understand the overall architecture
- [Creating Subgraphs](../02-core-functionality/creating-subgraphs.md): Learn how to create additional subgraphs
- [Authentication](../02-core-functionality/authentication.md): Secure your federated graph
- [Deployment](../05-operations/deployment.md): Deploy your federated graph to production

## Prerequisites

Before setting up your Federated Graph API, ensure you have the following prerequisites installed:

- Node.js (v14 or later)
- npm (v6 or later) or yarn
- Git (for version control)

```bash
# Check Node.js version
node --version

# Check npm version
npm --version

# Or if using yarn
yarn --version
```

## Setting Up the Apollo Gateway

The Apollo Gateway is the entry point for your federated GraphQL API. It routes queries to the appropriate subgraphs and combines the results.

### Create a New Gateway Project

```bash
# Create a new directory for your gateway
mkdir federated-healthcare-api
cd federated-healthcare-api

# Initialize a new Node.js project
npm init -y

# Install dependencies
npm install @apollo/gateway apollo-server graphql
```

### Create the Gateway Server

Create a new file named `gateway.js` with the following content:

```javascript
// gateway.js
const { ApolloServer } = require('apollo-server');
const { ApolloGateway } = require('@apollo/gateway');

// Initialize the gateway
const gateway = new ApolloGateway({
  // Define the list of subgraphs that make up your federated graph
  serviceList: [
    // Initially, this can be empty or contain placeholder services
    // You'll add actual services as you create them
  ],
  // Uncomment this to enable managed federation (if using Apollo Studio)
  // managedFederation: true,
});

// Initialize the Apollo Server with the gateway
const server = new ApolloServer({
  gateway,
  // Subscriptions are not currently supported with Apollo Federation
  subscriptions: false,
  context: ({ req }) => {
    // You can set up context that will be passed to all resolvers
    return { 
      // Example: extract auth token from headers
      token: req.headers.authorization || ''
    };
  }
});

// Start the server
server.listen({ port: 4000 }).then(({ url }) => {
  console.log(`🚀 Gateway ready at ${url}`);
});
```

## Creating Your First Subgraph

Subgraphs are individual GraphQL services that contribute to your federated graph. Let's create a simple subgraph to get started.

### Create a Subgraph Project

```bash
# Create a new directory for your subgraph
mkdir -p subgraphs/example-subgraph
cd subgraphs/example-subgraph

# Initialize a new Node.js project
npm init -y

# Install dependencies
npm install apollo-server graphql @apollo/federation
```

### Create the Subgraph Schema

Create a new file named `schema.js` with the following content:

```javascript
// schema.js
const { gql } = require('apollo-server');

const typeDefs = gql`
  # Extend the federation schema
  extend schema @link(url: "https://specs.apollo.dev/federation/v2.0", import: ["@key", "@external"])

  # Define a simple entity
  type Example @key(fields: "id") {
    id: ID!
    name: String!
    description: String
    createdAt: String!
  }

  # Define queries
  type Query {
    example(id: ID!): Example
    examples: [Example!]!
  }

  # Define mutations
  type Mutation {
    createExample(name: String!, description: String): Example!
    updateExample(id: ID!, name: String, description: String): Example!
  }
`;

module.exports = typeDefs;
```

### Create Resolvers

Create a new file named `resolvers.js` with the following content:

```javascript
// resolvers.js
// Simple in-memory data store for the example
const examples = [
  {
    id: '1',
    name: 'Example 1',
    description: 'This is the first example',
    createdAt: new Date().toISOString()
  },
  {
    id: '2',
    name: 'Example 2',
    description: 'This is the second example',
    createdAt: new Date().toISOString()
  }
];

const resolvers = {
  Query: {
    example: (_, { id }) => examples.find(e => e.id === id),
    examples: () => examples
  },
  Mutation: {
    createExample: (_, { name, description }) => {
      const newExample = {
        id: String(examples.length + 1),
        name,
        description,
        createdAt: new Date().toISOString()
      };
      examples.push(newExample);
      return newExample;
    },
    updateExample: (_, { id, name, description }) => {
      const exampleIndex = examples.findIndex(e => e.id === id);
      if (exampleIndex === -1) throw new Error(`Example with ID ${id} not found`);
      
      if (name) examples[exampleIndex].name = name;
      if (description) examples[exampleIndex].description = description;
      
      return examples[exampleIndex];
    }
  },
  Example: {
    __resolveReference: (reference) => {
      return examples.find(e => e.id === reference.id);
    }
  }
};

module.exports = resolvers;
```

### Create the Subgraph Server

Create a new file named `index.js` with the following content:

```javascript
// index.js
const { ApolloServer } = require('apollo-server');
const { buildFederatedSchema } = require('@apollo/federation');

const typeDefs = require('./schema');
const resolvers = require('./resolvers');

// Create the federated schema
const schema = buildFederatedSchema([{ typeDefs, resolvers }]);

// Initialize the Apollo Server with the federated schema
const server = new ApolloServer({ schema });

// Start the server
server.listen({ port: 4001 }).then(({ url }) => {
  console.log(`🚀 Example subgraph ready at ${url}`);
});
```

### Start the Subgraph

```bash
node index.js
```

## Connecting the Gateway to Your Subgraph

Now that you have a subgraph running, update your gateway to use it.

### Update the Gateway Configuration

Modify your `gateway.js` file to include your subgraph:

```javascript
// gateway.js
const { ApolloServer } = require('apollo-server');
const { ApolloGateway } = require('@apollo/gateway');

// Initialize the gateway with your subgraph
const gateway = new ApolloGateway({
  serviceList: [
    { name: 'example', url: 'http://localhost:4001/graphql' },
    // Add more subgraphs as you create them
  ],
});

// Rest of the code remains the same...
```

### Start the Gateway

```bash
node gateway.js
```

## Testing Your Federated Graph

With both your gateway and subgraph running, you can now test your federated graph.

1. Open your browser and navigate to `http://localhost:4000/graphql`
2. You should see the Apollo Studio Explorer or GraphQL Playground
3. Try running a query:

```graphql
query {
  examples {
    id
    name
    description
    createdAt
  }
}
```

4. Try running a mutation:

```graphql
mutation {
  createExample(name: "New Example", description: "This is a new example") {
    id
    name
    description
    createdAt
  }
}
```

## Next Steps

Now that you have a basic federated GraphQL API running, you can:

1. Create additional subgraphs for different domains
2. Implement authentication and authorization
3. Add more complex entity relationships across subgraphs
4. Set up monitoring and observability
5. Deploy your federated graph to a production environment

Refer to the related documentation for guidance on these next steps.

## Troubleshooting

### Common Issues

#### Gateway Cannot Connect to Subgraph

If your gateway cannot connect to your subgraph, check that:

- The subgraph is running and accessible at the specified URL
- There are no network issues or firewalls blocking the connection
- The port is not being used by another application

#### Schema Composition Errors

If you encounter schema composition errors:

- Ensure all entity keys are properly defined
- Check for naming conflicts across subgraphs
- Verify that extended types have the same key fields in all subgraphs

#### Performance Issues

If your federated graph is slow:

- Check individual subgraph performance
- Consider implementing caching
- Review query complexity and implement query optimization techniques

## Conclusion

You now have a working Federated Graph API that you can extend and customize to meet your specific needs. As you add more subgraphs and functionality, refer to the other guides in this documentation for best practices and advanced techniques.
