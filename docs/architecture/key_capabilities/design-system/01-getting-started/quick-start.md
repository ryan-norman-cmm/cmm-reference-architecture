# Design System Quick Start

This guide provides a step-by-step process to help you quickly get started with the Design System core component, which is built on Storybook, ShadCN UI, Tailwind CSS, and React. Components are published via GitHub Actions and Artifactory.

## Prerequisites
- Access to the CMM platform environment (development, staging, or production)
- Node.js (v18+) and npm or yarn installed
- Access to the internal Artifactory (for private package installs)
- Familiarity with React, Tailwind CSS, and component-driven development

## Step 1: Install the Design System Package
Install the Design System package from Artifactory (replace `<package-name>` and registry URL as appropriate):

```sh
npm config set @your-org:registry=https://artifactory.yourdomain.com/artifactory/api/npm/npm-repo/
npm install @your-org/design-system
```

> For more details, see [Artifactory NPM Registry Setup](https://jfrog.com/help/r/jfrog-artifactory-documentation/npm-registry).

## Step 2: Configure Tailwind and ShadCN UI
- Set up [Tailwind CSS](https://tailwindcss.com/docs/installation) in your project.
- Install and configure [ShadCN UI](https://ui.shadcn.com/docs/installation) if not already present.
- Import or extend the Tailwind config from the design system package if available.

## Step 3: Use Components in Your React App
Example usage:

```tsx
import { Button } from '@your-org/design-system';

export function Example() {
  return <Button variant="primary">Click Me</Button>;
}
```

- For available components and props, refer to the [Storybook documentation](http://localhost:6006) (run locally) or the published Storybook instance if available.

## Step 4: Validate Setup
- Start your app and ensure components render and style correctly.
- Run Storybook locally to browse, test, and validate all components:

```sh
npm run storybook
```

- Access Storybook at [http://localhost:6006](http://localhost:6006) and verify that design system components render as expected.
- If your team has a published Storybook, use that for reference as well.
- For troubleshooting, consult:
  - [Storybook Troubleshooting](https://storybook.js.org/docs/react/get-started/troubleshooting)
  - [Tailwind Troubleshooting](https://tailwindcss.com/docs/installation#troubleshooting)
  - [ShadCN UI Docs](https://ui.shadcn.com/docs/installation)

## Next Steps
- [Explore Advanced Theming & Customization](../03-advanced-topics/theming.md)
- [Integration Guide: Application Shell](../../application-shell/01-getting-started/quick-start.md)
- [Best Practices: Component Design](../03-advanced-topics/component-best-practices.md)
- [Error Handling & Troubleshooting](../03-advanced-topics/error-handling.md)

## Related Resources
- [Storybook: Get Started](https://storybook.js.org/docs/react/get-started/install)
- [ShadCN UI: Installation](https://ui.shadcn.com/docs/installation)
- [Tailwind CSS: Installation](https://tailwindcss.com/docs/installation)
- [React: Getting Started](https://react.dev/learn)
- [GitHub Actions: Documentation](https://docs.github.com/en/actions)
- [Artifactory: NPM Registry](https://jfrog.com/help/r/jfrog-artifactory-documentation/npm-registry)
