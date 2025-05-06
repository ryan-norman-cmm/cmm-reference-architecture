# Design System Data Model

## Introduction

This document describes the data model that underpins the Design System for the CMM Technology Platform. The data model defines the structure, relationships, and properties of the design elements that make up the system. Understanding this data model is essential for developers and designers who need to extend or customize the Design System for healthcare applications.

## Core Data Model

### Design Token Model

Design tokens are the fundamental building blocks of the Design System. They represent the smallest design decisions, such as colors, typography, spacing, and other visual attributes.

```typescript
interface DesignToken {
  id: string;              // Unique identifier
  name: string;            // Human-readable name
  value: string | number;  // Token value
  type: TokenType;         // Type of token
  category: TokenCategory; // Category of token
  description?: string;    // Optional description
  deprecated?: boolean;    // Whether the token is deprecated
}

type TokenType = 
  | 'color'
  | 'spacing'
  | 'typography'
  | 'border'
  | 'shadow'
  | 'opacity'
  | 'z-index'
  | 'animation';

type TokenCategory = 
  | 'global'       // Used across all themes
  | 'theme'        // Theme-specific tokens
  | 'component'    // Component-specific tokens
  | 'clinical'     // Clinical-specific tokens
  | 'patient';     // Patient-specific tokens
```

#### Color Token Model

Color tokens follow a specific structure to support various color formats and themes:

```typescript
interface ColorToken extends DesignToken {
  type: 'color';
  value: string;           // CSS color value
  hsl?: string;            // HSL representation
  rgb?: string;            // RGB representation
  hex?: string;            // HEX representation
  opacity?: number;        // Base opacity
  lightVariant?: string;   // Lighter variant
  darkVariant?: string;    // Darker variant
}
```

#### Typography Token Model

Typography tokens define text styles:

```typescript
interface TypographyToken extends DesignToken {
  type: 'typography';
  fontFamily: string;
  fontSize: string;
  fontWeight: number | string;
  lineHeight: string | number;
  letterSpacing?: string;
  textCase?: 'uppercase' | 'lowercase' | 'capitalize' | 'none';
  textDecoration?: 'none' | 'underline' | 'line-through';
}
```

#### Spacing Token Model

Spacing tokens define consistent spacing throughout the system:

```typescript
interface SpacingToken extends DesignToken {
  type: 'spacing';
  value: string;         // CSS spacing value (e.g., '1rem')
  pixelValue?: number;   // Equivalent in pixels
  scaleFactor?: number;  // Relation to base spacing unit
}
```

### Component Model

Components are the building blocks of the Design System. Each component has a defined structure, properties, and variants.

```typescript
interface Component {
  id: string;                  // Unique identifier
  name: string;                // Component name
  description: string;         // Component description
  category: ComponentCategory; // Component category
  props: ComponentProp[];      // Component properties
  variants: ComponentVariant[]; // Component variants
  examples: ComponentExample[]; // Usage examples
  accessibility: AccessibilityGuidelines; // Accessibility guidelines
  status: ComponentStatus;     // Current status
  version: string;             // Semantic version
  deprecated?: boolean;        // Whether component is deprecated
  replacedBy?: string;         // ID of replacement component if deprecated
}

type ComponentCategory = 
  | 'core'        // Basic building blocks
  | 'layout'      // Layout components
  | 'navigation'  // Navigation components
  | 'feedback'    // Feedback components
  | 'data'        // Data display components
  | 'input'       // Input components
  | 'clinical'    // Clinical-specific components
  | 'patient';    // Patient-facing components

type ComponentStatus = 
  | 'experimental' // Under development
  | 'beta'         // Ready for testing
  | 'stable'       // Production-ready
  | 'deprecated';  // Scheduled for removal
```

#### Component Property Model

Component properties define the configurable aspects of a component:

```typescript
interface ComponentProp {
  name: string;              // Property name
  type: string;              // Property type
  description: string;       // Property description
  required: boolean;         // Whether property is required
  default?: any;             // Default value
  options?: any[];           // Possible values for enum types
  validation?: Validation[]; // Validation rules
}

interface Validation {
  type: 'min' | 'max' | 'pattern' | 'custom';
  value: any;                // Validation value
  message: string;           // Error message
}
```

#### Component Variant Model

Component variants define different visual or behavioral versions of a component:

```typescript
interface ComponentVariant {
  id: string;                // Variant identifier
  name: string;              // Variant name
  description: string;       // Variant description
  props: Record<string, any>; // Default props for this variant
  tokens: Record<string, string>; // Token overrides for this variant
  preview?: string;          // URL to variant preview
}
```

### Pattern Model

Patterns are reusable solutions to common design problems, composed of multiple components:

```typescript
interface Pattern {
  id: string;                // Unique identifier
  name: string;              // Pattern name
  description: string;       // Pattern description
  category: PatternCategory; // Pattern category
  components: string[];      // Component IDs used in this pattern
  examples: PatternExample[]; // Usage examples
  guidelines: string;        // Usage guidelines
  status: PatternStatus;     // Current status
  version: string;           // Semantic version
}

type PatternCategory = 
  | 'form'        // Form patterns
  | 'layout'      // Layout patterns
  | 'navigation'  // Navigation patterns
  | 'data'        // Data display patterns
  | 'workflow'    // Workflow patterns
  | 'clinical'    // Clinical-specific patterns
  | 'patient';    // Patient-facing patterns

type PatternStatus = 
  | 'experimental' // Under development
  | 'beta'         // Ready for testing
  | 'stable'       // Production-ready
  | 'deprecated';  // Scheduled for removal
```

## Healthcare-Specific Data Models

### Clinical Component Model

Clinical components have additional properties specific to healthcare applications:

```typescript
interface ClinicalComponent extends Component {
  category: 'clinical';
  clinicalContext: ClinicalContext[];
  dataRequirements: DataRequirement[];
  regulatoryConsiderations: RegulatoryConsideration[];
}

type ClinicalContext = 
  | 'inpatient'    // Inpatient care
  | 'outpatient'   // Outpatient care
  | 'emergency'    // Emergency care
  | 'telehealth'   // Remote care
  | 'laboratory'   // Laboratory
  | 'pharmacy'     // Pharmacy
  | 'radiology';   // Radiology

interface DataRequirement {
  dataType: string;          // Type of data required
  required: boolean;         // Whether data is required
  format?: string;           // Expected data format
  validation?: Validation[]; // Validation rules
}

interface RegulatoryConsideration {
  regulation: string;        // Regulation name
  description: string;       // Description of consideration
  impact: 'low' | 'medium' | 'high'; // Impact level
}
```

### Patient Component Model

Patient-facing components have additional properties for patient engagement:

```typescript
interface PatientComponent extends Component {
  category: 'patient';
  healthLiteracyLevel: 'basic' | 'intermediate' | 'proficient';
  accessibilityLevel: 'A' | 'AA' | 'AAA'; // WCAG compliance level
  deviceConsiderations: DeviceConsideration[];
  patientContext: PatientContext[];
}

interface DeviceConsideration {
  deviceType: 'mobile' | 'tablet' | 'desktop' | 'assistive';
  description: string;
}

type PatientContext = 
  | 'portal'       // Patient portal
  | 'scheduling'   // Appointment scheduling
  | 'results'      // Results review
  | 'messaging'    // Secure messaging
  | 'education'    // Patient education
  | 'monitoring';  // Remote monitoring
```

## Theme Data Model

Themes define collections of design tokens for different visual styles:

```typescript
interface Theme {
  id: string;                // Unique identifier
  name: string;              // Theme name
  description: string;       // Theme description
  tokens: Record<string, string>; // Token overrides
  baseTheme?: string;        // Base theme ID if extending another theme
  context?: ThemeContext[];  // Contexts where this theme applies
}

type ThemeContext = 
  | 'light'       // Light mode
  | 'dark'        // Dark mode
  | 'high-contrast' // High contrast mode
  | 'print'       // Print mode
  | 'clinical'    // Clinical context
  | 'patient';    // Patient context
```

## Design Token Transformation

The Design System transforms design tokens into various formats for consumption:

### CSS Variables

Design tokens are transformed into CSS variables:

```css
:root {
  /* Color tokens */
  --color-primary: 221.2 83.2% 53.3%;
  --color-primary-foreground: 210 40% 98%;
  
  /* Spacing tokens */
  --spacing-xs: 0.25rem;
  --spacing-sm: 0.5rem;
  --spacing-md: 1rem;
  
  /* Typography tokens */
  --font-family-sans: 'Inter', system-ui, sans-serif;
  --font-size-base: 1rem;
  --line-height-normal: 1.5;
}
```

### Tailwind Configuration

Design tokens are transformed into Tailwind CSS configuration:

```javascript
// tailwind.config.js
module.exports = {
  theme: {
    extend: {
      colors: {
        primary: 'hsl(var(--color-primary))',
        secondary: 'hsl(var(--color-secondary))',
        clinical: 'hsl(var(--color-clinical))',
      },
      spacing: {
        xs: 'var(--spacing-xs)',
        sm: 'var(--spacing-sm)',
        md: 'var(--spacing-md)',
      },
      fontFamily: {
        sans: ['var(--font-family-sans)'],
        mono: ['var(--font-family-mono)'],
      },
    },
  },
};
```

## Component Composition Model

Components can be composed to create more complex interfaces:

```typescript
interface CompositionRelationship {
  parent: string;            // Parent component ID
  child: string;             // Child component ID
  relationship: 'contains' | 'uses' | 'extends';
  required: boolean;         // Whether child is required
  multiplicity: '0..1' | '1' | '0..*' | '1..*'; // Cardinality
}
```

### Example Component Composition

A PatientBanner component might be composed of several other components:

```typescript
const patientBannerComposition: CompositionRelationship[] = [
  {
    parent: 'PatientBanner',
    child: 'Avatar',
    relationship: 'contains',
    required: false,
    multiplicity: '0..1',
  },
  {
    parent: 'PatientBanner',
    child: 'Typography',
    relationship: 'contains',
    required: true,
    multiplicity: '1..*',
  },
  {
    parent: 'PatientBanner',
    child: 'Badge',
    relationship: 'contains',
    required: false,
    multiplicity: '0..*',
  },
  {
    parent: 'PatientBanner',
    child: 'Alert',
    relationship: 'contains',
    required: false,
    multiplicity: '0..*',
  },
];
```

## Versioning and Deprecation Model

The Design System tracks component versions and deprecations:

```typescript
interface VersionHistory {
  componentId: string;       // Component ID
  versions: Version[];       // Version history
}

interface Version {
  version: string;           // Semantic version
  releaseDate: string;       // ISO date string
  changes: Change[];         // Changes in this version
  breaking: boolean;         // Whether version has breaking changes
  deprecated: boolean;       // Whether version is deprecated
  deprecationReason?: string; // Reason for deprecation
  migrationGuide?: string;   // Migration guide URL
}

interface Change {
  type: 'added' | 'changed' | 'deprecated' | 'removed' | 'fixed';
  description: string;       // Description of change
  prUrl?: string;           // Pull request URL
}
```

## Metadata Model

Metadata provides additional information about Design System elements:

```typescript
interface Metadata {
  id: string;                // Element ID
  type: 'component' | 'token' | 'pattern' | 'theme';
  created: string;           // ISO date string
  createdBy: string;         // Author
  modified: string;          // ISO date string
  modifiedBy: string;        // Last modifier
  tags: string[];            // Searchable tags
  searchTerms: string[];     // Additional search terms
  relatedItems: string[];    // Related element IDs
}
```

## Documentation Model

Documentation is structured to provide comprehensive information about Design System elements:

```typescript
interface Documentation {
  id: string;                // Element ID
  type: 'component' | 'token' | 'pattern' | 'theme';
  title: string;             // Documentation title
  description: string;       // Long description
  usage: string;             // Usage guidelines
  bestPractices: string[];   // Best practices
  accessibility: string;     // Accessibility guidelines
  examples: Example[];       // Code examples
  props?: ComponentProp[];   // Component properties (if applicable)
  api?: string;              // API documentation
  faq?: FAQ[];               // Frequently asked questions
}

interface Example {
  title: string;             // Example title
  description: string;       // Example description
  code: string;              // Example code
  preview?: string;          // Preview URL
}

interface FAQ {
  question: string;          // Question
  answer: string;            // Answer
}
```

## Conclusion

The Design System Data Model provides a comprehensive structure for organizing and managing design elements. This model ensures consistency, scalability, and maintainability of the Design System, while also addressing the specific needs of healthcare applications. By understanding this data model, developers and designers can effectively extend and customize the Design System for their specific requirements.

## Related Documentation

- [Design Tokens](./design-tokens.md)
- [Component Patterns](./component-patterns.md)
- [Core APIs](./core-apis.md)
- [Healthcare Guidelines](./healthcare-guidelines.md)
