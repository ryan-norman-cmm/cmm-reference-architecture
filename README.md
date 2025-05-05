# CMM Reference Architecture Documentation

This repository contains the documentation for our reference architecture, designed to be published through Backstage TechDocs.

## Local Development

To work with this documentation locally:

1. Install the techdocs-cli:
   ```
   npm install -g @techdocs/cli
   ```

2. Preview the documentation:
   ```
   techdocs-cli serve
   ```

3. Access the documentation at http://localhost:3000

## Adding New Documentation

1. Add new Markdown files to the appropriate directory under `docs/`
2. Update the `mkdocs.yml` file to include new pages in the navigation
3. Commit and push your changes

## Publishing

Documentation is automatically published to Backstage TechDocs when changes are pushed to the main branch.

## Structure

- `catalog-info.yaml` - Backstage entity definition
- `mkdocs.yml` - MkDocs configuration
- `docs/` - Documentation source files
  - `index.md` - Home page
  - `architecture/` - Architecture documentation
    - `overview.md` - Architecture overview
    - `principles.md` - Architectural principles