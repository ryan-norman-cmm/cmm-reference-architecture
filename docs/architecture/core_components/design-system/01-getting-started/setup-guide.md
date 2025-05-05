# Design Component Library Setup Guide

## Introduction

This guide walks you through the process of setting up the Design Component Library for the CMM Reference Architecture. It covers initial configuration, development environment setup, and best practices for creating and using UI components based on Radix UI and Material-UI (MUI). By following these steps, you'll establish a robust foundation for consistent, accessible, and high-quality user interfaces across all your healthcare applications.

## Prerequisites

Before beginning the Design Component Library setup process, ensure you have:

- Node.js 16.x or later installed
- npm 8.x or later or Yarn 1.22.x or later
- Git for version control
- A GitHub account with access to the organization repositories
- Basic understanding of React and TypeScript
- Familiarity with component-based architecture
- Understanding of accessibility requirements (WCAG 2.1 AA)
- Access to Artifactory for package publishing

## Setup Process

### 1. Repository Setup

#### Clone and Configure the Repository

1. **Clone the Repository**
   ```bash
   git clone https://github.com/your-org/design-component-library.git
   cd design-component-library
   ```

2. **Install Core Dependencies**
   ```bash
   npm install
   # or
   yarn install
   ```

3. **Install Radix UI and Material-UI**
   ```bash
   # Install Radix UI primitives
   npm install @radix-ui/react-dialog @radix-ui/react-dropdown-menu @radix-ui/react-tabs @radix-ui/react-popover @radix-ui/react-select @radix-ui/react-checkbox @radix-ui/react-radio-group @radix-ui/react-tooltip
   
   # Install Material-UI
   npm install @mui/material @mui/icons-material @emotion/react @emotion/styled
   ```

4. **Configure Package Settings**
   - Set up Artifactory access in `.npmrc`
   - Configure package.json with appropriate dependencies

### 2. Development Environment Configuration

#### Set Up Local Development Environment

1. **Configure Environment Variables**
   - Create a `.env.local` file based on `.env.example`
   - Set required environment variables:
     ```
     ARTIFACTORY_URL=https://your-org.jfrog.io/artifactory/api/npm/npm-local/
     ARTIFACTORY_TOKEN=your-token
     STORYBOOK_THEME=healthcare
     ```

2. **Install Recommended Extensions**
   - For VS Code users, install recommended extensions from `.vscode/extensions.json`
   - Configure ESLint and Prettier for code quality

3. **Set Up Tailwind CSS**
   - Review and customize `tailwind.config.js`
   - Configure healthcare-specific color palette and spacing

### 3. Component Library Structure

#### Understand the Library Organization

1. **Review Project Structure**
   ```
   design-component-library/
   ├── examples/                # Application examples
   │   ├── clinical-portal/     # Clinical portal example
   │   └── patient-app/        # Patient-facing app example
   ├── src/                     # Component source code
   │   ├── tokens/              # Design tokens
   │   ├── foundations/         # Foundation components
   │   │   ├── radix/           # Radix UI adaptations
   │   │   └── mui/             # Material-UI adaptations
   │   ├── core/                # Core components
   │   ├── clinical/            # Clinical-specific components
   │   ├── admin/               # Admin interface components
   │   └── patient/             # Patient-facing components
   ├── .storybook/              # Storybook configuration
   ├── scripts/                 # Build and development scripts
   ├── package.json             # Project dependencies
   └── tailwind.config.js       # Tailwind CSS configuration
   ```

2. **Understand Component Categories**
   - **Design Tokens**: Colors, typography, spacing, etc.
   - **Foundation Components**:
     - **Radix UI Adaptations**: Styled Radix primitives with Tailwind
     - **Material-UI Adaptations**: Themed MUI components
   - **Core Components**: Buttons, inputs, typography, etc.
   - **Composite Components**: Forms, cards, dialogs, etc.
   - **Clinical Components**: Patient banners, vital signs, lab results, etc.
   - **Layout Components**: Grids, containers, etc.

### 4. Storybook Configuration

#### Set Up Storybook for Component Development

1. **Start Storybook Development Server**
   ```bash
   npm run storybook
   # or
   yarn storybook
   ```

2. **Configure Storybook Addons**
   - Review and update `.storybook/main.js`
   - Configure accessibility addon
   - Set up viewport addon for responsive testing
   - Configure design token addon

3. **Set Up Storybook Theme**
   - Customize `.storybook/manager.js` for healthcare theme
   - Configure brand colors and logos

### 5. Creating Your First Component

#### Develop a Basic Component

1. **Generate Component Scaffolding**
   ```bash
   nx g @nrwl/react:component Button --project=core --export
   ```

2. **Implement Component with Tailwind CSS**
   ```tsx
   // libs/core/src/lib/button/button.tsx
   import React from 'react';
   
   export interface ButtonProps {
     variant?: 'primary' | 'secondary' | 'tertiary' | 'danger';
     size?: 'small' | 'medium' | 'large';
     disabled?: boolean;
     children: React.ReactNode;
     onClick?: () => void;
   }
   
   export function Button({
     variant = 'primary',
     size = 'medium',
     disabled = false,
     children,
     onClick,
     ...props
   }: ButtonProps) {
     const baseClasses = 'font-medium rounded focus:outline-none focus:ring-2 focus:ring-offset-2';
     
     const variantClasses = {
       primary: 'bg-blue-600 text-white hover:bg-blue-700 focus:ring-blue-500',
       secondary: 'bg-gray-100 text-gray-800 hover:bg-gray-200 focus:ring-gray-500',
       tertiary: 'bg-transparent text-blue-600 hover:bg-blue-50 focus:ring-blue-500',
       danger: 'bg-red-600 text-white hover:bg-red-700 focus:ring-red-500',
     };
     
     const sizeClasses = {
       small: 'py-1 px-3 text-sm',
       medium: 'py-2 px-4 text-base',
       large: 'py-3 px-6 text-lg',
     };
     
     const disabledClasses = disabled ? 'opacity-50 cursor-not-allowed' : 'cursor-pointer';
     
     const classes = `${baseClasses} ${variantClasses[variant]} ${sizeClasses[size]} ${disabledClasses}`;
     
     return (
       <button
         className={classes}
         disabled={disabled}
         onClick={onClick}
         {...props}
       >
         {children}
       </button>
     );
   }
   
   export default Button;
   ```

3. **Create Component Story**
   ```tsx
   // libs/core/src/lib/button/button.stories.tsx
   import { ComponentStory, ComponentMeta } from '@storybook/react';
   import { Button } from './button';
   
   export default {
     title: 'Core/Button',
     component: Button,
     argTypes: {
       variant: {
         control: { type: 'select' },
         options: ['primary', 'secondary', 'tertiary', 'danger'],
       },
       size: {
         control: { type: 'select' },
         options: ['small', 'medium', 'large'],
       },
       disabled: { control: 'boolean' },
       onClick: { action: 'clicked' },
     },
   } as ComponentMeta<typeof Button>;
   
   const Template: ComponentStory<typeof Button> = (args) => <Button {...args} />;
   
   export const Primary = Template.bind({});
   Primary.args = {
     variant: 'primary',
     size: 'medium',
     children: 'Primary Button',
   };
   
   export const Secondary = Template.bind({});
   Secondary.args = {
     variant: 'secondary',
     size: 'medium',
     children: 'Secondary Button',
   };
   
   export const Tertiary = Template.bind({});
   Tertiary.args = {
     variant: 'tertiary',
     size: 'medium',
     children: 'Tertiary Button',
   };
   
   export const Danger = Template.bind({});
   Danger.args = {
     variant: 'danger',
     size: 'medium',
     children: 'Danger Button',
   };
   
   export const Small = Template.bind({});
   Small.args = {
     variant: 'primary',
     size: 'small',
     children: 'Small Button',
   };
   
   export const Large = Template.bind({});
   Large.args = {
     variant: 'primary',
     size: 'large',
     children: 'Large Button',
   };
   
   export const Disabled = Template.bind({});
   Disabled.args = {
     variant: 'primary',
     size: 'medium',
     disabled: true,
     children: 'Disabled Button',
   };
   ```

4. **Test Component**
   ```tsx
   // libs/core/src/lib/button/button.spec.tsx
   import { render, screen, fireEvent } from '@testing-library/react';
   import { Button } from './button';
   
   describe('Button', () => {
     it('renders correctly', () => {
       render(<Button>Test Button</Button>);
       expect(screen.getByText('Test Button')).toBeInTheDocument();
     });
     
     it('handles click events', () => {
       const handleClick = jest.fn();
       render(<Button onClick={handleClick}>Clickable</Button>);
       fireEvent.click(screen.getByText('Clickable'));
       expect(handleClick).toHaveBeenCalledTimes(1);
     });
     
     it('applies variant classes correctly', () => {
       const { rerender } = render(<Button variant="primary">Primary</Button>);
       expect(screen.getByText('Primary')).toHaveClass('bg-blue-600');
       
       rerender(<Button variant="secondary">Secondary</Button>);
       expect(screen.getByText('Secondary')).toHaveClass('bg-gray-100');
       
       rerender(<Button variant="danger">Danger</Button>);
       expect(screen.getByText('Danger')).toHaveClass('bg-red-600');
     });
     
     it('disables the button when disabled prop is true', () => {
       render(<Button disabled>Disabled</Button>);
       expect(screen.getByText('Disabled')).toBeDisabled();
       expect(screen.getByText('Disabled')).toHaveClass('cursor-not-allowed');
     });
   });
   ```

### 6. GitHub Actions CI/CD Setup

#### Configure Automated Workflows

1. **Create GitHub Actions Workflow File**
   ```yaml
   # .github/workflows/ci.yml
   name: CI/CD Pipeline
   
   on:
     push:
       branches: [main]
     pull_request:
       branches: [main]
   
   jobs:
     build-and-test:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v3
         - name: Setup Node.js
           uses: actions/setup-node@v3
           with:
             node-version: '16'
             cache: 'npm'
         - name: Install dependencies
           run: npm ci
         - name: Lint
           run: npm run lint
         - name: Test
           run: npm run test
         - name: Build
           run: npm run build
         - name: Build Storybook
           run: npm run build-storybook
         - name: Upload artifacts
           uses: actions/upload-artifact@v3
           with:
             name: storybook-build
             path: dist/storybook
     
     publish:
       needs: build-and-test
       if: github.event_name == 'push' && github.ref == 'refs/heads/main'
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v3
         - name: Setup Node.js
           uses: actions/setup-node@v3
           with:
             node-version: '16'
             cache: 'npm'
         - name: Install dependencies
           run: npm ci
         - name: Build packages
           run: npm run build
         - name: Configure Artifactory
           run: |
             echo "@your-org:registry=https://your-org.jfrog.io/artifactory/api/npm/npm-local/" > .npmrc
             echo "//your-org.jfrog.io/artifactory/api/npm/npm-local/:_authToken=${{ secrets.ARTIFACTORY_TOKEN }}" >> .npmrc
         - name: Publish to Artifactory
           run: npm run publish
   ```

2. **Configure Storybook Deployment**
   ```yaml
   # .github/workflows/storybook.yml
   name: Deploy Storybook
   
   on:
     push:
       branches: [main]
   
   jobs:
     deploy-storybook:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v3
         - name: Setup Node.js
           uses: actions/setup-node@v3
           with:
             node-version: '16'
             cache: 'npm'
         - name: Install dependencies
           run: npm ci
         - name: Build Storybook
           run: npm run build-storybook
         - name: Deploy to GitHub Pages
           uses: JamesIves/github-pages-deploy-action@v4.4.1
           with:
             branch: gh-pages
             folder: dist/storybook
   ```

### 7. Artifactory Configuration

#### Set Up Package Publishing

1. **Configure Artifactory Connection**
   - Create or update `.npmrc` with Artifactory configuration
   - Set up authentication with Artifactory token

2. **Configure Package Publishing**
   - Update `package.json` with publishing configuration
   - Set up versioning strategy

3. **Create Publishing Script**
   ```js
   // tools/scripts/publish.js
   const { execSync } = require('child_process');
   const { readFileSync, writeFileSync } = require('fs');
   const { join } = require('path');
   
   // Get package info
   const pkgPath = join(process.cwd(), 'package.json');
   const pkg = JSON.parse(readFileSync(pkgPath, 'utf-8'));
   
   // Determine version bump type from commit messages
   const commitMessages = execSync('git log -1 --pretty=%B').toString().trim();
   let bumpType = 'patch';
   
   if (commitMessages.includes('BREAKING CHANGE')) {
     bumpType = 'major';
   } else if (commitMessages.includes('feat:')) {
     bumpType = 'minor';
   }
   
   // Bump version
   console.log(`Bumping ${bumpType} version...`);
   execSync(`npm version ${bumpType} --no-git-tag-version`);
   
   // Update version in package.json
   const updatedPkg = JSON.parse(readFileSync(pkgPath, 'utf-8'));
   console.log(`New version: ${updatedPkg.version}`);
   
   // Publish packages
   console.log('Publishing packages to Artifactory...');
   execSync('nx run-many --target=publish --all', { stdio: 'inherit' });
   ```

## Implementation Examples

### Using Components in a React Application

```tsx
// Example: Using components in a React application
import React from 'react';
import { Button, Card, TextField } from '@your-org/core';
import { PatientBanner } from '@your-org/clinical';

interface PatientFormProps {
  patientId: string;
  onSubmit: (data: any) => void;
}

export function PatientForm({ patientId, onSubmit }: PatientFormProps) {
  const [formData, setFormData] = React.useState({
    firstName: '',
    lastName: '',
    dateOfBirth: '',
    phoneNumber: '',
  });
  
  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
  };
  
  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onSubmit(formData);
  };
  
  return (
    <div className="p-4">
      <PatientBanner patientId={patientId} />
      
      <Card className="mt-4">
        <form onSubmit={handleSubmit}>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <TextField
              label="First Name"
              name="firstName"
              value={formData.firstName}
              onChange={handleChange}
              required
            />
            
            <TextField
              label="Last Name"
              name="lastName"
              value={formData.lastName}
              onChange={handleChange}
              required
            />
            
            <TextField
              label="Date of Birth"
              name="dateOfBirth"
              type="date"
              value={formData.dateOfBirth}
              onChange={handleChange}
              required
            />
            
            <TextField
              label="Phone Number"
              name="phoneNumber"
              type="tel"
              value={formData.phoneNumber}
              onChange={handleChange}
              required
            />
          </div>
          
          <div className="mt-6 flex justify-end space-x-4">
            <Button variant="secondary">Cancel</Button>
            <Button type="submit">Save Patient</Button>
          </div>
        </form>
      </Card>
    </div>
  );
}
```

### Creating a Healthcare-Specific Component

```tsx
// Example: Creating a healthcare-specific component
// libs/clinical/src/lib/vital-signs/vital-signs.tsx
import React from 'react';
import { Card, Text, Icon } from '@your-org/core';

export interface VitalSign {
  name: string;
  value: number;
  unit: string;
  normalRange?: {
    min: number;
    max: number;
  };
  timestamp: string;
}

export interface VitalSignsProps {
  vitals: VitalSign[];
  title?: string;
}

export function VitalSigns({ vitals, title = 'Vital Signs' }: VitalSignsProps) {
  const getStatusColor = (vital: VitalSign) => {
    if (!vital.normalRange) return 'text-gray-500';
    
    if (vital.value < vital.normalRange.min) return 'text-blue-500';
    if (vital.value > vital.normalRange.max) return 'text-red-500';
    return 'text-green-500';
  };
  
  const getStatusIcon = (vital: VitalSign) => {
    if (!vital.normalRange) return null;
    
    if (vital.value < vital.normalRange.min) return <Icon name="arrow-down" className="ml-1" />;
    if (vital.value > vital.normalRange.max) return <Icon name="arrow-up" className="ml-1" />;
    return <Icon name="check-circle" className="ml-1" />;
  };
  
  const formatTime = (timestamp: string) => {
    return new Date(timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  };
  
  return (
    <Card>
      <div className="p-4">
        <Text variant="h3" className="mb-4">{title}</Text>
        
        <div className="space-y-4">
          {vitals.map((vital, index) => (
            <div key={index} className="flex justify-between items-center border-b pb-2">
              <div>
                <Text variant="body-bold">{vital.name}</Text>
                <Text variant="caption" className="text-gray-500">
                  {formatTime(vital.timestamp)}
                </Text>
              </div>
              
              <div className="flex items-center">
                <Text 
                  variant="body-bold" 
                  className={getStatusColor(vital)}
                >
                  {vital.value} {vital.unit}
                  {getStatusIcon(vital)}
                </Text>
                
                {vital.normalRange && (
                  <Text variant="caption" className="ml-2 text-gray-500">
                    ({vital.normalRange.min}-{vital.normalRange.max})
                  </Text>
                )}
              </div>
            </div>
          ))}
        </div>
      </div>
    </Card>
  );
}

export default VitalSigns;
```

## Deployment Considerations

### Production Checklist

- **Versioning Strategy**: Implement semantic versioning
- **Package Publishing**: Configure automated publishing to Artifactory
- **Documentation**: Ensure comprehensive documentation for all components
- **Accessibility Testing**: Verify all components meet WCAG 2.1 AA standards
- **Browser Compatibility**: Test across required browsers
- **Performance**: Monitor bundle size and performance metrics

### Healthcare Compliance

- **Accessibility**: Ensure all components meet healthcare accessibility requirements
- **Color Contrast**: Verify color contrast ratios for clinical applications
- **Error States**: Implement clear error states for clinical data
- **Responsive Design**: Ensure components work across all required devices
- **Print Styling**: Implement print-friendly styles for clinical documents

## Troubleshooting

### Common Issues

1. **Build Failures**
   - Check for TypeScript errors
   - Verify dependency versions
   - Check for circular dependencies

2. **Storybook Issues**
   - Clear Storybook cache
   - Check addon compatibility
   - Verify webpack configuration

3. **Publishing Problems**
   - Verify Artifactory credentials
   - Check package versioning
   - Ensure package.json configuration is correct

## Next Steps

- [Component Catalog](../02-core-functionality/component-catalog.md): Explore available components
- [Contribution Guidelines](../04-operations/contribution-guidelines.md): Learn how to contribute
- [Accessibility Guidelines](../03-advanced-patterns/accessibility.md): Ensure accessible components

## Resources

- [React Documentation](https://reactjs.org/docs/getting-started.html)
- [Tailwind CSS Documentation](https://tailwindcss.com/docs)
- [Storybook Documentation](https://storybook.js.org/docs/react/get-started/introduction)
- [NX Documentation](https://nx.dev/react)
- [WCAG 2.1 Guidelines](https://www.w3.org/TR/WCAG21/)
