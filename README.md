# Spaarke Icons

Canonical icon library for all Spaarke applications. All icons are sourced from [Fluent UI System Icons](https://github.com/microsoft/fluentui-system-icons) and standardized to **20px Regular** style.

## Structure

```
icons/
  nav/        Navigation / sitemap icons (15 icons)
  entity/     Dataverse entity record type icons (33 icons)
  cmd/        Command bar, toolbar, and UI chrome icons (36 icons)
  status/     Status indicator icons (9 icons)
```

**93 total icons** across 4 categories.

## Usage

### Dataverse / Power Platform

Icons are deployed as **web resources** in the Spaarke Dataverse solution. The `icon-manifest.json` file maps each icon to its:

- **Entity logical name** (e.g., `sprk_matter`, `sprk_project`)
- **Web resource path** (e.g., `sprk_/icons/entity/matter.svg`)
- **Usage type** (entity, navigation, command, status)

Use the manifest to generate `customizations.xml` entries and sitemap icon references for PAC CLI packaging.

### React / Web Applications

Import icons directly from `@fluentui/react-icons` using the component name listed in the manifest's `fluentComponent` field:

```tsx
import { Briefcase20Regular } from '@fluentui/react-icons';
```

Or reference the SVG files directly from this repository for non-React applications.

### Prototype

The Spaarke UX prototype (`spaarke-prototype`) maintains a copy of these icons under `projects/spaarke-navigation-icons/src/assets/icons/` for visual testing and the Icon Manager tool.

## Icon Standard

| Property | Value |
|----------|-------|
| Size | 20px |
| Style | Regular |
| Format | SVG |
| Source | Fluent UI System Icons |
| Color | Inherits from context (currentColor) |

## Manifest (v2.0.0)

`icon-manifest.json` is the **single source of truth** for all icon metadata. It contains:
- Fluent UI component names (for React imports)
- Fluent UI SVG filenames (for MCP/CDN lookup)
- Dataverse web resource paths
- Entity logical names
- Usage type classification
- **Status** — lifecycle state (Draft, Approved, Deployed, Rejected)

The manifest is consumed by:
- The **Icon Manager** prototype app (reads at build time, persists status changes to localStorage)
- The **PowerShell deployment script** (`deploy/Import-SpaarkeIcons.ps1`)

## Deployment

Deploy icons to a Dataverse environment using the PowerShell script:

```bash
# Preview (no changes)
pwsh deploy/Import-SpaarkeIcons.ps1 -EnvironmentUrl "https://orgname.crm.dynamics.com" -WhatIf

# Execute
pwsh deploy/Import-SpaarkeIcons.ps1 -EnvironmentUrl "https://orgname.crm.dynamics.com"
```

**Requirements:** PowerShell 7+, MSAL.PS module (auto-installed). Uses OAuth2 device code flow for authentication.

See `spaarke-prototype/projects/spaarke-navigation-icons/GUIDE.md` for the complete deployment walkthrough.

## Updating Icons

1. Use the **Spaarke Icon Manager** experiment in the prototype to search, select, and approve icons
2. Export approved icons and copy SVGs to this repository
3. In the Icon Manager Export tab, click **Download Manifest** to get the updated `icon-manifest.json` with current statuses
4. Copy the downloaded manifest here, replacing the existing file
5. Commit and push to make available across all applications

For detailed instructions on adding new icons, managing the lifecycle, and using Claude Code to orchestrate the process, see the **[Complete Guide](../spaarke-prototype/projects/spaarke-navigation-icons/GUIDE.md)**.
