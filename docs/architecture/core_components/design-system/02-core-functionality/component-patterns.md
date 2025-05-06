# Component Patterns

## Introduction

Component patterns in the CMM Reference Architecture Design System define how UI components should be used together to create consistent, effective user experiences. These patterns address common interaction scenarios in healthcare applications, providing guidance on component composition, behavior, and best practices.

## Form Patterns

### Standard Form Layout

Forms are a critical part of healthcare applications, used for everything from patient registration to clinical documentation. Consistent form patterns improve usability and reduce errors.

#### Guidelines:

- Group related fields logically
- Use clear, concise labels positioned above input fields
- Indicate required fields consistently
- Provide helpful validation messages
- Include clear primary and secondary actions

#### Example Implementation:

```jsx
<Card>
  <CardHeader>
    <CardTitle>Patient Registration</CardTitle>
    <CardDescription>Enter patient demographic information</CardDescription>
  </CardHeader>
  <CardContent>
    <form className="space-y-6">
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div className="space-y-2">
          <Label htmlFor="firstName" required>
            First Name
          </Label>
          <Input id="firstName" name="firstName" required />
        </div>
        
        <div className="space-y-2">
          <Label htmlFor="lastName" required>
            Last Name
          </Label>
          <Input id="lastName" name="lastName" required />
        </div>
        
        <div className="space-y-2">
          <Label htmlFor="dateOfBirth" required>
            Date of Birth
          </Label>
          <DatePicker id="dateOfBirth" name="dateOfBirth" required />
        </div>
        
        <div className="space-y-2">
          <Label htmlFor="gender" required>
            Gender
          </Label>
          <Select id="gender" name="gender" required>
            <SelectItem value="female">Female</SelectItem>
            <SelectItem value="male">Male</SelectItem>
            <SelectItem value="other">Other</SelectItem>
            <SelectItem value="unknown">Unknown</SelectItem>
          </Select>
        </div>
      </div>
    </form>
  </CardContent>
  <CardFooter className="flex justify-end space-x-4">
    <Button variant="outline">Cancel</Button>
    <Button type="submit">Save Patient</Button>
  </CardFooter>
</Card>
```

### Progressive Disclosure Forms

For complex forms, progressive disclosure helps manage complexity by showing only relevant fields based on previous selections.

#### Guidelines:

- Show only relevant fields based on context
- Use clear visual indicators for conditional fields
- Maintain logical grouping as fields appear/disappear
- Provide clear navigation between form sections

#### Example Implementation:

```jsx
<Form>
  <FormStep title="Patient Type">
    <RadioGroup name="patientType">
      <RadioItem value="inpatient">Inpatient</RadioItem>
      <RadioItem value="outpatient">Outpatient</RadioItem>
      <RadioItem value="emergency">Emergency</RadioItem>
    </RadioGroup>
  </FormStep>
  
  {patientType === 'inpatient' && (
    <FormStep title="Admission Details">
      {/* Inpatient-specific fields */}
    </FormStep>
  )}
  
  {patientType === 'outpatient' && (
    <FormStep title="Appointment Details">
      {/* Outpatient-specific fields */}
    </FormStep>
  )}
  
  {patientType === 'emergency' && (
    <FormStep title="Emergency Details">
      {/* Emergency-specific fields */}
    </FormStep>
  )}
  
  <FormStep title="Reason for Visit">
    {/* Common fields for all patient types */}
  </FormStep>
</Form>
```

## Search Patterns

### Patient Search

Patient search is a fundamental pattern in healthcare applications, requiring efficient and accurate results.

#### Guidelines:

- Support multiple search criteria (name, DOB, MRN, etc.)
- Provide type-ahead suggestions
- Display sufficient information to identify patients
- Handle common name variations and misspellings
- Include clear indicators for duplicate records

#### Example Implementation:

```jsx
<Card>
  <CardHeader>
    <CardTitle>Patient Search</CardTitle>
  </CardHeader>
  <CardContent>
    <div className="space-y-4">
      <div className="flex space-x-2">
        <Input 
          placeholder="Search by name, MRN, or DOB"
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
          className="flex-1"
        />
        <Button>
          <Search className="h-4 w-4 mr-2" />
          Search
        </Button>
      </div>
      
      <Tabs defaultValue="all">
        <TabsList>
          <TabsTrigger value="all">All Patients</TabsTrigger>
          <TabsTrigger value="recent">Recent Patients</TabsTrigger>
          <TabsTrigger value="scheduled">Today's Schedule</TabsTrigger>
        </TabsList>
      </Tabs>
      
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Name</TableHead>
            <TableHead>DOB</TableHead>
            <TableHead>MRN</TableHead>
            <TableHead>Gender</TableHead>
            <TableHead></TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {searchResults.map((patient) => (
            <TableRow key={patient.id}>
              <TableCell className="font-medium">{patient.name}</TableCell>
              <TableCell>{formatDate(patient.dob)}</TableCell>
              <TableCell>{patient.mrn}</TableCell>
              <TableCell>{patient.gender}</TableCell>
              <TableCell>
                <Button variant="ghost" size="sm">
                  <UserRound className="h-4 w-4 mr-2" />
                  Select
                </Button>
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  </CardContent>
</Card>
```

### Clinical Terminology Search

Searching clinical terminologies (diagnoses, medications, procedures) requires specialized patterns.

#### Guidelines:

- Support code and description search
- Include relevant terminology information (codes, hierarchies)
- Group related terms appropriately
- Provide contextual information for disambiguation
- Support favorites and recent selections

## Dashboard Patterns

### Clinical Dashboard

Clinical dashboards provide at-a-glance views of patient information and workflow tasks.

#### Guidelines:

- Prioritize information by clinical importance
- Group related information logically
- Support customization for different roles
- Provide clear refresh/update indicators
- Include actionable links to detailed views

#### Example Implementation:

```jsx
<div className="grid grid-cols-1 md:grid-cols-3 gap-4">
  <Card className="md:col-span-2">
    <CardHeader className="pb-2">
      <CardTitle>Patient Census</CardTitle>
    </CardHeader>
    <CardContent>
      <Tabs defaultValue="inpatient">
        <TabsList>
          <TabsTrigger value="inpatient">Inpatient</TabsTrigger>
          <TabsTrigger value="emergency">Emergency</TabsTrigger>
          <TabsTrigger value="outpatient">Outpatient</TabsTrigger>
        </TabsList>
        <TabsContent value="inpatient">
          <Table>
            {/* Inpatient census table */}
          </Table>
        </TabsContent>
        {/* Other tab contents */}
      </Tabs>
    </CardContent>
  </Card>
  
  <Card>
    <CardHeader className="pb-2">
      <CardTitle>Tasks</CardTitle>
    </CardHeader>
    <CardContent>
      <div className="space-y-4">
        <div>
          <h4 className="text-sm font-semibold mb-2">Critical</h4>
          <ul className="space-y-2">
            {criticalTasks.map((task) => (
              <li key={task.id} className="flex items-center">
                <Badge variant="destructive" className="mr-2">Critical</Badge>
                <span>{task.description}</span>
              </li>
            ))}
          </ul>
        </div>
        
        <div>
          <h4 className="text-sm font-semibold mb-2">Pending</h4>
          <ul className="space-y-2">
            {pendingTasks.map((task) => (
              <li key={task.id}>{task.description}</li>
            ))}
          </ul>
        </div>
      </div>
    </CardContent>
  </Card>
  
  <Card className="md:col-span-3">
    <CardHeader className="pb-2">
      <CardTitle>Recent Clinical Results</CardTitle>
    </CardHeader>
    <CardContent>
      {/* Recent results content */}
    </CardContent>
  </Card>
</div>
```

### Patient Summary

Patient summaries provide a consolidated view of key patient information.

#### Guidelines:

- Include critical patient identifiers and alerts
- Highlight key clinical information (diagnoses, medications, allergies)
- Provide clear navigation to detailed sections
- Support customization based on clinical context
- Include recent activity and upcoming events

## Workflow Patterns

### Clinical Documentation

Clinical documentation patterns support efficient and accurate documentation workflows.

#### Guidelines:

- Support structured and free-text documentation
- Provide appropriate templates and defaults
- Include relevant clinical context
- Support documentation review and attestation
- Enable efficient navigation between sections

### Order Entry

Order entry patterns support safe and efficient ordering workflows.

#### Guidelines:

- Group related orders logically
- Support common order sets and favorites
- Include appropriate clinical decision support
- Provide clear order review and submission steps
- Support order modification and discontinuation

## Data Visualization Patterns

### Trend Visualization

Trend visualizations display changes in clinical values over time.

#### Guidelines:

- Clearly indicate normal ranges
- Support different time scales
- Include contextual events (medications, procedures)
- Provide appropriate data density
- Support interactive exploration

#### Example Implementation:

```jsx
<Card>
  <CardHeader>
    <CardTitle>Glucose Trend</CardTitle>
    <CardDescription>Last 7 days</CardDescription>
  </CardHeader>
  <CardContent>
    <div className="h-80">
      <LineChart
        data={glucoseData}
        normalRange={{ min: 70, max: 140 }}
        unit="mg/dL"
        events={medicationEvents}
        timeScale="7d"
      />
    </div>
  </CardContent>
  <CardFooter>
    <Select defaultValue="7d">
      <SelectItem value="24h">Last 24 Hours</SelectItem>
      <SelectItem value="7d">Last 7 Days</SelectItem>
      <SelectItem value="30d">Last 30 Days</SelectItem>
      <SelectItem value="90d">Last 90 Days</SelectItem>
    </Select>
  </CardFooter>
</Card>
```

### Results Visualization

Results visualizations display laboratory and diagnostic results.

#### Guidelines:

- Clearly indicate normal ranges and abnormal values
- Support different result types (numeric, categorical, text)
- Include relevant metadata (collection time, status)
- Provide appropriate grouping of related results
- Support trending of repeated tests

## Conclusion

These component patterns provide a foundation for creating consistent, effective user experiences in healthcare applications. By following these patterns, developers can create interfaces that support clinical workflows, improve efficiency, and reduce errors. The patterns are implemented using the components from our design system, ensuring visual consistency while addressing the unique requirements of healthcare applications.
