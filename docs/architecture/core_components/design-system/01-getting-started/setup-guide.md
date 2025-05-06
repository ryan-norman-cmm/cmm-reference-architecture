# Design Component Library Setup Guide

## Introduction

This guide walks you through the process of setting up the Design Component Library for the CMM Reference Architecture. It covers initial configuration, development environment setup, and best practices for creating and using UI components based on ShadCN. By following these steps, you'll establish a robust foundation for consistent, accessible, and high-quality user interfaces across all your healthcare applications.

## Prerequisites

Before beginning the Design Component Library setup process, ensure you have:

- Node.js 18.x or later installed
- npm 8.x or later, Yarn 1.22.x or later, or pnpm 8.x or later
- Git for version control
- A GitHub account with access to the organization repositories
- Basic understanding of React and TypeScript
- Component-based architecture
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

3. **Install ShadCN**
   ```bash
   # Add ShadCN CLI
   npx shadcn-ui@latest init
   
   # Follow the CLI prompts with these recommended settings:
   # - Would you like to use TypeScript? Yes
   # - Which style would you like to use? Default
   # - Which color would you like to use as base color? Slate
   # - Where is your global CSS file? src/styles/globals.css
   # - Would you like to use CSS variables for colors? Yes
   # - Where is your tailwind.config.js located? tailwind.config.js
   # - Configure the import alias for components: @/components
   # - Configure the import alias for utils: @/lib/utils
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
   │   ├── styles/              # Global styles
   │   │   └── globals.css      # Global CSS including Tailwind directives
   │   ├── lib/                 # Utility functions
   │   │   └── utils.ts         # ShadCN utility functions
   │   ├── components/          # Component source code
   │   │   ├── ui/              # ShadCN UI components
   │   │   ├── clinical/        # Clinical-specific components
   │   │   ├── admin/           # Admin interface components
   │   │   └── patient/         # Patient-facing components
   │   └── registry/            # Component registry for documentation
   ├── .storybook/              # Storybook configuration
   ├── scripts/                 # Build and development scripts
   ├── package.json             # Project dependencies
   └── tailwind.config.js       # Tailwind CSS configuration
   ```

2. **Understand Component Categories**
   - **ShadCN UI Components**: Pre-styled, accessible components based on Radix UI primitives
     - **Core Components**: Buttons, inputs, typography, etc.
     - **Layout Components**: Cards, sheets, dialogs, etc.
     - **Navigation Components**: Tabs, menus, breadcrumbs, etc.
     - **Data Display Components**: Tables, calendars, etc.
   - **Domain-Specific Components**:
     - **Clinical Components**: Patient banners, vital signs, lab results, etc.
     - **Admin Components**: Dashboards, settings panels, etc.
     - **Patient Components**: Appointment booking, health records, etc.

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

#### Adding ShadCN Components

1. **Add ShadCN Components Using CLI**
   ```bash
   # Add a button component
   npx shadcn-ui@latest add button
   
   # Add other components as needed
   npx shadcn-ui@latest add dialog
   npx shadcn-ui@latest add dropdown-menu
   npx shadcn-ui@latest add tabs
   ```

2. **Customize ShadCN Components**
   ```tsx
   // src/components/ui/button.tsx
   import * as React from 'react'
   import { Slot } from '@radix-ui/react-slot'
   import { cva, type VariantProps } from 'class-variance-authority'
   
   import { cn } from '@/lib/utils'
   
   // Customize the button variants to match healthcare design needs
   const buttonVariants = cva(
     'inline-flex items-center justify-center whitespace-nowrap rounded-md text-sm font-medium ring-offset-background transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50',
     {
       variants: {
         variant: {
           default: 'bg-primary text-primary-foreground hover:bg-primary/90',
           destructive: 'bg-destructive text-destructive-foreground hover:bg-destructive/90',
           outline: 'border border-input bg-background hover:bg-accent hover:text-accent-foreground',
           secondary: 'bg-secondary text-secondary-foreground hover:bg-secondary/80',
           ghost: 'hover:bg-accent hover:text-accent-foreground',
           link: 'text-primary underline-offset-4 hover:underline',
           // Add healthcare-specific variants
           clinical: 'bg-teal-600 text-white hover:bg-teal-700',
           patient: 'bg-blue-600 text-white hover:bg-blue-700',
           admin: 'bg-purple-600 text-white hover:bg-purple-700',
         },
         size: {
           default: 'h-10 px-4 py-2',
           sm: 'h-9 rounded-md px-3',
           lg: 'h-11 rounded-md px-8',
           icon: 'h-10 w-10',
         },
       },
       defaultVariants: {
         variant: 'default',
         size: 'default',
       },
     }
   )
   
   export interface ButtonProps
     extends React.ButtonHTMLAttributes<HTMLButtonElement>,
       VariantProps<typeof buttonVariants> {
     asChild?: boolean
   }
   
   const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
     ({ className, variant, size, asChild = false, ...props }, ref) => {
       const Comp = asChild ? Slot : 'button'
       return (
         <Comp
           className={cn(buttonVariants({ variant, size, className }))}
           ref={ref}
           {...props}
         />
       )
     }
   )
   Button.displayName = 'Button'
   
   export { Button, buttonVariants }
   ```

3. **Create Component Story**
   ```tsx
   // src/components/ui/button.stories.tsx
   import type { Meta, StoryObj } from '@storybook/react';
   import { Button } from './button';
   
   const meta: Meta<typeof Button> = {
     title: 'UI/Button',
     component: Button,
     tags: ['autodocs'],
     argTypes: {
       variant: {
         control: { type: 'select' },
         options: ['default', 'destructive', 'outline', 'secondary', 'ghost', 'link', 'clinical', 'patient', 'admin'],
       },
       size: {
         control: { type: 'select' },
         options: ['default', 'sm', 'lg', 'icon'],
       },
       disabled: { control: 'boolean' },
       onClick: { action: 'clicked' },
     },
   };
   
   export default meta;
   type Story = StoryObj<typeof Button>;
   
   export const Default: Story = {
     args: {
       children: 'Default Button',
     },
   };
   
   export const Secondary: Story = {
     args: {
       variant: 'secondary',
       children: 'Secondary Button',
     },
   };
   
   export const Destructive: Story = {
     args: {
       variant: 'destructive',
       children: 'Destructive Button',
     },
   };
   
   export const Clinical: Story = {
     args: {
       variant: 'clinical',
       children: 'Clinical Button',
     },
   };
   
   export const Small: Story = {
     args: {
       size: 'sm',
       children: 'Small Button',
     },
   };
   
   export const Large: Story = {
     args: {
       size: 'lg',
       children: 'Large Button',
     },
   };
   
   export const Disabled: Story = {
     args: {
       disabled: true,
       children: 'Disabled Button',
     },
   };
   ```

4. **Test Component**
   ```tsx
   // src/components/ui/button.test.tsx
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
       const { rerender } = render(<Button variant="default">Default</Button>);
       expect(screen.getByText('Default')).toHaveClass('bg-primary');
       
       rerender(<Button variant="secondary">Secondary</Button>);
       expect(screen.getByText('Secondary')).toHaveClass('bg-secondary');
       
       rerender(<Button variant="destructive">Destructive</Button>);
       expect(screen.getByText('Destructive')).toHaveClass('bg-destructive');
       
       rerender(<Button variant="clinical">Clinical</Button>);
       expect(screen.getByText('Clinical')).toHaveClass('bg-teal-600');
     });
     
     it('disables the button when disabled prop is true', () => {
       render(<Button disabled>Disabled</Button>);
       expect(screen.getByText('Disabled')).toBeDisabled();
       expect(screen.getByText('Disabled')).toHaveClass('disabled:opacity-50');
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

### 8. ShadCN Theming for Healthcare Applications

#### Customize ShadCN Theme for Healthcare

1. **Update Global CSS Variables**
   ```css
   /* src/styles/globals.css */
   @tailwind base;
   @tailwind components;
   @tailwind utilities;
 
   @layer base {
     :root {
       --background: 0 0% 100%;
       --foreground: 222.2 84% 4.9%;
       
       --card: 0 0% 100%;
       --card-foreground: 222.2 84% 4.9%;
       
       --popover: 0 0% 100%;
       --popover-foreground: 222.2 84% 4.9%;
       
       --primary: 196 100% 47%; /* Healthcare blue */
       --primary-foreground: 210 40% 98%;
       
       --secondary: 210 40% 96.1%;
       --secondary-foreground: 222.2 47.4% 11.2%;
       
       --muted: 210 40% 96.1%;
       --muted-foreground: 215.4 16.3% 46.9%;
       
       --accent: 210 40% 96.1%;
       --accent-foreground: 222.2 47.4% 11.2%;
       
       --destructive: 0 84.2% 60.2%;
       --destructive-foreground: 210 40% 98%;
       
       --clinical: 175 84% 32%; /* Teal for clinical */
       --clinical-foreground: 0 0% 100%;
       
       --patient: 196 100% 47%; /* Blue for patient-facing */
       --patient-foreground: 0 0% 100%;
       
       --admin: 265 84% 50%; /* Purple for admin */
       --admin-foreground: 0 0% 100%;
       
       --border: 214.3 31.8% 91.4%;
       --input: 214.3 31.8% 91.4%;
       --ring: 222.2 84% 4.9%;
       
       --radius: 0.5rem;
     }
     
     .dark {
       --background: 222.2 84% 4.9%;
       --foreground: 210 40% 98%;
       
       --card: 222.2 84% 4.9%;
       --card-foreground: 210 40% 98%;
       
       --popover: 222.2 84% 4.9%;
       --popover-foreground: 210 40% 98%;
       
       --primary: 196 100% 47%;
       --primary-foreground: 222.2 47.4% 11.2%;
       
       --secondary: 217.2 32.6% 17.5%;
       --secondary-foreground: 210 40% 98%;
       
       --muted: 217.2 32.6% 17.5%;
       --muted-foreground: 215 20.2% 65.1%;
       
       --accent: 217.2 32.6% 17.5%;
       --accent-foreground: 210 40% 98%;
       
       --destructive: 0 62.8% 30.6%;
       --destructive-foreground: 210 40% 98%;
       
       --clinical: 175 84% 32%;
       --clinical-foreground: 0 0% 100%;
       
       --patient: 196 100% 47%;
       --patient-foreground: 0 0% 100%;
       
       --admin: 265 84% 50%;
       --admin-foreground: 0 0% 100%;
       
       --border: 217.2 32.6% 17.5%;
       --input: 217.2 32.6% 17.5%;
       --ring: 212.7 26.8% 83.9%;
     }
   }
   
   @layer base {
     * {
       @apply border-border;
     }
     body {
       @apply bg-background text-foreground;
     }
   }
   ```

2. **Update Tailwind Configuration**
   ```js
   // tailwind.config.js
   const { fontFamily } = require("tailwindcss/defaultTheme")
   
   /** @type {import('tailwindcss').Config} */
   module.exports = {
     darkMode: ["class"],
     content: ["./src/**/*.{js,jsx,ts,tsx}"],
     theme: {
       container: {
         center: true,
         padding: "2rem",
         screens: {
           "2xl": "1400px",
         },
       },
       extend: {
         colors: {
           border: "hsl(var(--border))",
           input: "hsl(var(--input))",
           ring: "hsl(var(--ring))",
           background: "hsl(var(--background))",
           foreground: "hsl(var(--foreground))",
           primary: {
             DEFAULT: "hsl(var(--primary))",
             foreground: "hsl(var(--primary-foreground))",
           },
           secondary: {
             DEFAULT: "hsl(var(--secondary))",
             foreground: "hsl(var(--secondary-foreground))",
           },
           destructive: {
             DEFAULT: "hsl(var(--destructive))",
             foreground: "hsl(var(--destructive-foreground))",
           },
           muted: {
             DEFAULT: "hsl(var(--muted))",
             foreground: "hsl(var(--muted-foreground))",
           },
           accent: {
             DEFAULT: "hsl(var(--accent))",
             foreground: "hsl(var(--accent-foreground))",
           },
           popover: {
             DEFAULT: "hsl(var(--popover))",
             foreground: "hsl(var(--popover-foreground))",
           },
           card: {
             DEFAULT: "hsl(var(--card))",
             foreground: "hsl(var(--card-foreground))",
           },
           // Add healthcare-specific colors
           clinical: {
             DEFAULT: "hsl(var(--clinical))",
             foreground: "hsl(var(--clinical-foreground))",
           },
           patient: {
             DEFAULT: "hsl(var(--patient))",
             foreground: "hsl(var(--patient-foreground))",
           },
           admin: {
             DEFAULT: "hsl(var(--admin))",
             foreground: "hsl(var(--admin-foreground))",
           },
         },
         borderRadius: {
           lg: "var(--radius)",
           md: "calc(var(--radius) - 2px)",
           sm: "calc(var(--radius) - 4px)",
         },
         fontFamily: {
           sans: ["var(--font-sans)", ...fontFamily.sans],
         },
         keyframes: {
           // Add any custom animations here
         },
         animation: {
           // Add any custom animations here
         },
       },
     },
     plugins: [require("tailwindcss-animate")],
   }
   ```

3. **Creating Healthcare-Specific Components**
   ```tsx
   // src/components/clinical/patient-banner.tsx
   import * as React from 'react'
   import { Card, CardContent } from '@/components/ui/card'
   import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar'
   import { Badge } from '@/components/ui/badge'
   
   interface PatientBannerProps {
     patientId: string
     className?: string
   }
   
   export function PatientBanner({ patientId, className }: PatientBannerProps) {
     // In a real implementation, you would fetch patient data based on the ID
     const patient = {
       id: patientId,
       name: 'John Smith',
       dob: '1980-05-15',
       mrn: 'MRN12345',
       gender: 'Male',
       alerts: ['Allergy: Penicillin', 'Fall Risk'],
     }
     
     return (
       <Card className={`bg-clinical text-clinical-foreground ${className}`}>
         <CardContent className="p-4 flex items-center gap-4">
           <Avatar className="h-16 w-16 border-2 border-white">
             <AvatarImage src={`https://api.dicebear.com/7.x/initials/svg?seed=${patient.name}`} />
             <AvatarFallback>{patient.name.split(' ').map(n => n[0]).join('')}</AvatarFallback>
           </Avatar>
           
           <div className="flex-1">
             <div className="flex justify-between">
               <h2 className="text-xl font-bold">{patient.name}</h2>
               <div className="text-sm">MRN: {patient.mrn}</div>
             </div>
             
             <div className="flex gap-4 text-sm mt-1">
               <div>DOB: {new Date(patient.dob).toLocaleDateString()}</div>
               <div>Gender: {patient.gender}</div>
               <div>Age: {new Date().getFullYear() - new Date(patient.dob).getFullYear()}</div>
             </div>
             
             <div className="flex gap-2 mt-2">
               {patient.alerts.map((alert, index) => (
                 <Badge key={index} variant="outline" className="bg-white/20 text-white border-white">
                   {alert}
                 </Badge>
               ))}
             </div>
           </div>
         </CardContent>
       </Card>
     )
   }
   ```

## Implementation Examples

### Using ShadCN Components in a React Application

```tsx
// Example: Using ShadCN components in a React application
import React from 'react';
import { Button } from '@/components/ui/button';
import { Card, CardHeader, CardTitle, CardContent, CardFooter } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { PatientBanner } from '@/components/clinical/patient-banner';

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
        <CardHeader>
          <CardTitle>Patient Information</CardTitle>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit}>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="firstName">First Name</Label>
                <Input
                  id="firstName"
                  name="firstName"
                  value={formData.firstName}
                  onChange={handleChange}
                  required
                />
              </div>
              
              <div className="space-y-2">
                <Label htmlFor="lastName">Last Name</Label>
                <Input
                  id="lastName"
                  name="lastName"
                  value={formData.lastName}
                  onChange={handleChange}
                  required
                />
              </div>
              
              <div className="space-y-2">
                <Label htmlFor="dateOfBirth">Date of Birth</Label>
                <Input
                  id="dateOfBirth"
                  name="dateOfBirth"
                  type="date"
                  value={formData.dateOfBirth}
                  onChange={handleChange}
                  required
                />
              </div>
              
              <div className="space-y-2">
                <Label htmlFor="phoneNumber">Phone Number</Label>
                <Input
                  id="phoneNumber"
                  name="phoneNumber"
                  type="tel"
                  value={formData.phoneNumber}
                  onChange={handleChange}
                  required
                />
              </div>
            </div>
            
            <CardFooter className="mt-6 flex justify-end space-x-4 px-0">
              <Button variant="outline">Cancel</Button>
              <Button type="submit" variant="clinical">Save Patient</Button>
            </CardFooter>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}
```

### Creating a Healthcare-Specific Component with ShadCN

```tsx
// Example: Creating a healthcare-specific component
// src/components/clinical/vital-signs.tsx
import React from 'react';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card';
import { cn } from '@/lib/utils';
import { ArrowDown, ArrowUp, CheckCircle } from 'lucide-react';

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
  className?: string;
}

export function VitalSigns({ vitals, title = 'Vital Signs', className }: VitalSignsProps) {
  const getStatusColor = (vital: VitalSign) => {
    if (!vital.normalRange) return 'text-muted-foreground';
    
    if (vital.value < vital.normalRange.min) return 'text-blue-500';
    if (vital.value > vital.normalRange.max) return 'text-destructive';
    return 'text-green-500';
  };
  
  const getStatusIcon = (vital: VitalSign) => {
    if (!vital.normalRange) return null;
    
    if (vital.value < vital.normalRange.min) return <ArrowDown className="ml-1 h-4 w-4" />;
    if (vital.value > vital.normalRange.max) return <ArrowUp className="ml-1 h-4 w-4" />;
    return <CheckCircle className="ml-1 h-4 w-4" />;
  };
  
  const formatTime = (timestamp: string) => {
    return new Date(timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  };
  
  return (
    <Card className={cn("bg-card", className)}>
      <CardHeader className="pb-2">
        <CardTitle>{title}</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="space-y-4">
          {vitals.map((vital, index) => (
            <div key={index} className="flex justify-between items-center border-b pb-2 last:border-0">
              <div>
                <p className="font-medium">{vital.name}</p>
                <p className="text-sm text-muted-foreground">
                  {formatTime(vital.timestamp)}
                </p>
              </div>
              
              <div className="flex items-center">
                <p className={cn("font-medium flex items-center", getStatusColor(vital))}>
                  {vital.value} {vital.unit}
                  {getStatusIcon(vital)}
                </p>
                
                {vital.normalRange && (
                  <p className="ml-2 text-sm text-muted-foreground">
                    ({vital.normalRange.min}-{vital.normalRange.max})
                  </p>
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
