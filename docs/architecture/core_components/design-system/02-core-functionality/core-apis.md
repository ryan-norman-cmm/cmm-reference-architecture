# Design System Core APIs

## Introduction

This document outlines the core APIs provided by the Design System for the CMM Technology Platform. These APIs enable developers to effectively use, customize, and extend the Design System components in their applications. Understanding these APIs is essential for consistent implementation and integration of the Design System across healthcare applications.

## Component API Structure

### Base Component Pattern

All components in the Design System follow a consistent API pattern:

```typescript
// Example component API structure
export interface ComponentProps
  extends React.HTMLAttributes<HTMLElement>,
    VariantProps<typeof componentVariants> {
  // Component-specific props
}

const Component = React.forwardRef<HTMLElement, ComponentProps>(
  ({ className, variant, size, ...props }, ref) => {
    // Component implementation
  }
)

Component.displayName = 'Component'

export { Component, componentVariants }
```

This pattern ensures:

- **Consistent Props**: All components accept standard HTML attributes
- **Variants**: Components support variant props for different visual styles
- **Ref Forwarding**: Components properly forward refs to the underlying DOM element
- **Display Name**: Components have a display name for debugging
- **Exported Variants**: Variant styles are exported for custom components

## Core Component APIs

### Button API

The Button component is a fundamental building block for user interactions:

```typescript
export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {
  asChild?: boolean
}
```

**Props:**

- `variant`: Appearance style (`default`, `primary`, `secondary`, `destructive`, `outline`, `ghost`, `link`, `clinical`)
- `size`: Button size (`default`, `sm`, `lg`, `icon`)
- `asChild`: Render as a child component (using Radix UI's Slot)

**Example:**

```jsx
<Button variant="clinical" size="lg" onClick={handleClick}>
  Schedule Appointment
</Button>
```

### Input API

The Input component provides a standardized text input field:

```typescript
export interface InputProps
  extends React.InputHTMLAttributes<HTMLInputElement> {
  error?: boolean
  helperText?: string
}
```

**Props:**

- Standard HTML input attributes
- `error`: Whether the input has an error
- `helperText`: Helper text to display below the input

**Example:**

```jsx
<Input 
  type="text" 
  placeholder="Patient ID" 
  error={!!errors.patientId}
  helperText={errors.patientId?.message}
/>
```

### Card API

The Card component provides a container for related content:

```typescript
export interface CardProps extends React.HTMLAttributes<HTMLDivElement> {}
export interface CardHeaderProps extends React.HTMLAttributes<HTMLDivElement> {}
export interface CardTitleProps extends React.HTMLAttributes<HTMLHeadingElement> {}
export interface CardDescriptionProps extends React.HTMLAttributes<HTMLParagraphElement> {}
export interface CardContentProps extends React.HTMLAttributes<HTMLDivElement> {}
export interface CardFooterProps extends React.HTMLAttributes<HTMLDivElement> {}
```

**Example:**

```jsx
<Card>
  <CardHeader>
    <CardTitle>Patient Summary</CardTitle>
    <CardDescription>Basic patient information</CardDescription>
  </CardHeader>
  <CardContent>
    <p>Patient details go here</p>
  </CardContent>
  <CardFooter>
    <Button>View Details</Button>
  </CardFooter>
</Card>
```

## Healthcare-Specific Component APIs

### PatientBanner API

The PatientBanner component displays critical patient information:

```typescript
export interface PatientBannerProps {
  patient: {
    id: string
    name: string
    dateOfBirth: string
    gender: string
    mrn: string
    age?: number
  }
  alerts?: Array<{
    type: 'allergy' | 'infection' | 'warning' | 'info'
    message: string
  }>
  sticky?: boolean
  onClose?: () => void
}
```

**Example:**

```jsx
<PatientBanner
  patient={{
    id: '12345',
    name: 'John Doe',
    dateOfBirth: '1980-01-01',
    gender: 'Male',
    mrn: 'MRN12345',
    age: 43
  }}
  alerts={[
    { type: 'allergy', message: 'Penicillin' },
    { type: 'infection', message: 'COVID-19 Precautions' }
  ]}
  sticky
/>
```

### VitalSigns API

The VitalSigns component displays patient vital signs:

```typescript
export interface VitalSign {
  name: string
  value: number
  unit: string
  timestamp: string
  normalRange?: {
    min: number
    max: number
  }
}

export interface VitalSignsProps {
  vitals: VitalSign[]
  title?: string
  className?: string
}
```

**Example:**

```jsx
<VitalSigns
  vitals={[
    {
      name: 'Heart Rate',
      value: 72,
      unit: 'bpm',
      timestamp: '2023-05-01T14:30:00Z',
      normalRange: { min: 60, max: 100 }
    },
    {
      name: 'Blood Pressure',
      value: 120,
      unit: 'mmHg',
      timestamp: '2023-05-01T14:30:00Z',
      normalRange: { min: 90, max: 130 }
    }
  ]}
/>
```

## Utility APIs

### Design Token API

The Design Token API provides access to design tokens for custom styling:

```typescript
// Access design tokens through CSS variables
const tokens = {
  colors: {
    primary: 'var(--color-primary)',
    secondary: 'var(--color-secondary)',
    // Healthcare-specific colors
    clinical: 'var(--color-clinical)',
    patient: 'var(--color-patient)',
    alert: 'var(--color-alert)',
  },
  spacing: {
    xs: 'var(--spacing-xs)',
    sm: 'var(--spacing-sm)',
    md: 'var(--spacing-md)',
    lg: 'var(--spacing-lg)',
    xl: 'var(--spacing-xl)',
  },
  // Other token categories
}
```

### Theme API

The Theme API allows for theme customization:

```typescript
export interface ThemeProviderProps {
  theme?: 'light' | 'dark' | 'clinical' | 'patient'
  children: React.ReactNode
}

export function ThemeProvider({ theme = 'light', children }: ThemeProviderProps) {
  // Implementation
}
```

**Example:**

```jsx
<ThemeProvider theme="clinical">
  <App />
</ThemeProvider>
```

### cn Utility

The `cn` utility function combines class names using `clsx` and `tailwind-merge`:

```typescript
import { clsx, type ClassValue } from 'clsx'
import { twMerge } from 'tailwind-merge'

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}
```

**Example:**

```jsx
<div className={cn(
  'base-styles',
  variant === 'primary' && 'primary-styles',
  className
)}>
  Content
</div>
```

## Hook APIs

### useMediaQuery

The `useMediaQuery` hook provides responsive design capabilities:

```typescript
export function useMediaQuery(query: string): boolean {
  // Implementation
}
```

**Example:**

```jsx
const isMobile = useMediaQuery('(max-width: 768px)')

return (
  <div>
    {isMobile ? <MobileView /> : <DesktopView />}
  </div>
)
```

### useTheme

The `useTheme` hook provides access to the current theme:

```typescript
export function useTheme(): {
  theme: 'light' | 'dark' | 'clinical' | 'patient'
  setTheme: (theme: 'light' | 'dark' | 'clinical' | 'patient') => void
} {
  // Implementation
}
```

**Example:**

```jsx
const { theme, setTheme } = useTheme()

return (
  <Button onClick={() => setTheme(theme === 'light' ? 'dark' : 'light')}>
    Toggle Theme
  </Button>
)
```

## Context APIs

### ToastContext

The Toast context provides a system for displaying notifications:

```typescript
export interface Toast {
  id: string
  title?: string
  description?: string
  action?: React.ReactNode
  variant?: 'default' | 'destructive' | 'success' | 'warning' | 'info' | 'clinical'
}

export interface ToastContextValue {
  toasts: Toast[]
  addToast: (toast: Omit<Toast, 'id'>) => void
  removeToast: (id: string) => void
}
```

**Example:**

```jsx
const { addToast } = useToast()

function handleSave() {
  saveData()
    .then(() => {
      addToast({
        title: 'Success',
        description: 'Data saved successfully',
        variant: 'success',
      })
    })
    .catch(() => {
      addToast({
        title: 'Error',
        description: 'Failed to save data',
        variant: 'destructive',
      })
    })
}
```

### FormContext

The Form context provides form validation and state management:

```typescript
export interface FormContextValue {
  register: (name: string, options?: RegisterOptions) => {
    name: string
    onChange: (e: React.ChangeEvent<HTMLInputElement>) => void
    onBlur: () => void
    ref: React.RefCallback<HTMLInputElement>
  }
  handleSubmit: (onSubmit: (data: any) => void) => (e: React.FormEvent) => void
  formState: {
    errors: Record<string, { message: string }>
    isSubmitting: boolean
    isDirty: boolean
    isValid: boolean
  }
  watch: (name: string) => any
  setValue: (name: string, value: any) => void
  reset: () => void
}
```

**Example:**

```jsx
const { register, handleSubmit, formState: { errors } } = useForm()

function onSubmit(data) {
  console.log(data)
}

return (
  <form onSubmit={handleSubmit(onSubmit)}>
    <Input
      {...register('name', { required: 'Name is required' })}
      error={!!errors.name}
      helperText={errors.name?.message}
    />
    <Button type="submit">Submit</Button>
  </form>
)
```

## Integration APIs

### Storybook Integration

Components can be integrated with Storybook using the following pattern:

```typescript
import type { Meta, StoryObj } from '@storybook/react'
import { Component } from './component'

const meta: Meta<typeof Component> = {
  title: 'Components/Component',
  component: Component,
  parameters: {
    layout: 'centered',
  },
  argTypes: {
    variant: {
      control: 'select',
      options: ['default', 'primary', 'secondary', 'clinical'],
    },
  },
}

export default meta

type Story = StoryObj<typeof Component>

export const Default: Story = {
  args: {
    children: 'Default Component',
  },
}

export const Clinical: Story = {
  args: {
    variant: 'clinical',
    children: 'Clinical Component',
  },
}
```

### Testing API

Components can be tested using React Testing Library:

```typescript
import { render, screen, fireEvent } from '@testing-library/react'
import { Component } from './component'

describe('Component', () => {
  it('renders correctly', () => {
    render(<Component>Test</Component>)
    expect(screen.getByText('Test')).toBeInTheDocument()
  })

  it('handles click events', () => {
    const handleClick = jest.fn()
    render(<Component onClick={handleClick}>Click Me</Component>)
    fireEvent.click(screen.getByText('Click Me'))
    expect(handleClick).toHaveBeenCalledTimes(1)
  })

  it('applies variants correctly', () => {
    render(<Component variant="clinical">Clinical</Component>)
    expect(screen.getByText('Clinical')).toHaveClass('clinical-styles')
  })
})
```

## Conclusion

The Design System Core APIs provide a comprehensive set of interfaces for working with the Design System components. By following these APIs, developers can ensure consistent implementation and integration of the Design System across healthcare applications. The APIs are designed to be flexible, extensible, and easy to use, while also providing healthcare-specific functionality.

## Related Documentation

- [Component Patterns](./component-patterns.md)
- [Design Tokens](./design-tokens.md)
- [Healthcare Guidelines](./healthcare-guidelines.md)
- [Implementation Resources](./implementation-resources.md)
